#!/usr/bin/env python3
"""Prepares App Store signing for Nokhatha from CI with the App Store Connect API key.

Registers the bundle id if it is missing, finds the Apple Distribution certificate that
matches the one imported into the build keychain (by serial number), reuses or creates the
App Store provisioning profile for it, and installs the profile. Prints the profile UUID.

Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, CERT_SERIAL, BUNDLE_ID
Needs: pip install pyjwt cryptography requests
"""
import base64
import json
import os
import plistlib
import subprocess
import sys
import tempfile
import time

import jwt
import requests

API = 'https://api.appstoreconnect.apple.com/v1'
KEY_ID = os.environ['ASC_KEY_ID']
ISSUER = os.environ['ASC_ISSUER_ID']
KEY = os.environ['ASC_KEY_P8']
SERIAL = os.environ['CERT_SERIAL'].strip().upper().lstrip('0')
BUNDLE = os.environ.get('BUNDLE_ID', 'com.eworldq8.nokhatha')
PROFILE_NAME = os.environ.get('PROFILE_NAME', 'Nokhatha App Store')
WIDGET_BUNDLE = BUNDLE + '.widget'
WIDGET_PROFILE_NAME = PROFILE_NAME + ' Widget'
GROUP = 'group.' + BUNDLE


def token():
    now = int(time.time())
    return jwt.encode({'iss': ISSUER, 'iat': now, 'exp': now + 900, 'aud': 'appstoreconnect-v1'}, KEY,
                      algorithm='ES256', headers={'kid': KEY_ID, 'typ': 'JWT'})


def call(method, path, body=None, params=None):
    r = requests.request(method, API + path, params=params, json=body, timeout=60,
                         headers={'Authorization': f'Bearer {token()}', 'Content-Type': 'application/json'})
    if r.status_code >= 400:
        sys.exit(f'{method} {path} failed {r.status_code}: {r.text[:800]}')
    return r.json() if r.text else {}


def log(*a):
    print(*a, file=sys.stderr)


def bundle_id(identifier=BUNDLE, name='Nokhatha'):
    found = call('GET', '/bundleIds', params={'filter[identifier]': identifier, 'limit': 5})['data']
    exact = [b for b in found if b['attributes']['identifier'] == identifier]
    if exact:
        log('bundle id exists', identifier)
        return exact[0]['id']
    log('registering bundle id', identifier)
    return call('POST', '/bundleIds', {'data': {'type': 'bundleIds', 'attributes': {
        'identifier': identifier, 'name': name, 'platform': 'IOS'}}})['data']['id']


def app_group():
    """The App Group the app and its widget share, registered once."""
    found = call('GET', '/appGroups', params={'filter[identifier]': GROUP, 'limit': 5}).get('data', [])
    exact = [g for g in found if g['attributes']['identifier'] == GROUP]
    if exact:
        log('app group exists', GROUP)
        return exact[0]['id']
    log('registering app group', GROUP)
    return call('POST', '/appGroups', {'data': {'type': 'appGroups', 'attributes': {'identifier': GROUP, 'name': 'Nokhatha'}}})['data']['id']


def enable_group(bundle, group):
    """The App Groups capability on a bundle id, pointed at our group; a no-op when already there."""
    caps = call('GET', f'/bundleIds/{bundle}/bundleIdCapabilities', params={'limit': 50}).get('data', [])
    for c in caps:
        if c['attributes'].get('capabilityType') == 'APP_GROUPS':
            log('app groups already on', bundle)
            return
    log('enabling app groups on', bundle)
    call('POST', '/bundleIdCapabilities', {'data': {'type': 'bundleIdCapabilities', 'attributes': {'capabilityType': 'APP_GROUPS'},
                                                   'relationships': {'bundleId': {'data': {'type': 'bundleIds', 'id': bundle}},
                                                                     'appGroups': {'data': [{'type': 'appGroups', 'id': group}]}}}})


def certificate():
    certs = []
    for kind in ('DISTRIBUTION', 'IOS_DISTRIBUTION'):
        certs += call('GET', '/certificates', params={'filter[certificateType]': kind, 'limit': 200})['data']
    for c in certs:
        if c['attributes'].get('serialNumber', '').upper().lstrip('0') == SERIAL:
            log('distribution certificate', c['attributes'].get('name'), c['attributes'].get('expirationDate'))
            return c['id']
    sys.exit('the imported certificate was not found in the team, serial ' + SERIAL)


def profile(bundle, cert, name=PROFILE_NAME):
    existing = call('GET', '/profiles', params={'filter[name]': name, 'include': 'certificates,bundleId', 'limit': 50})
    for p in existing.get('data', []):
        if p['attributes'].get('profileState') != 'ACTIVE':
            log('removing invalid profile', p['id'])
            call('DELETE', f"/profiles/{p['id']}")
            continue
        rel = p.get('relationships', {})
        certs = [c['id'] for c in rel.get('certificates', {}).get('data', [])]
        b = rel.get('bundleId', {}).get('data', {}).get('id')
        if cert in certs and b == bundle and p['attributes']['profileType'] == 'IOS_APP_STORE':
            log('reusing profile', p['attributes']['name'])
            return p['attributes']['profileContent']
        log('removing stale profile', p['id'])
        call('DELETE', f"/profiles/{p['id']}")
    log('creating profile', name)
    return call('POST', '/profiles', {'data': {'type': 'profiles', 'attributes': {'name': name, 'profileType': 'IOS_APP_STORE'},
                                               'relationships': {'bundleId': {'data': {'type': 'bundleIds', 'id': bundle}},
                                                                 'certificates': {'data': [{'type': 'certificates', 'id': cert}]}}}})['data']['attributes']['profileContent']


def install(content):
    raw = base64.b64decode(content)
    with tempfile.NamedTemporaryFile(suffix='.mobileprovision', delete=False) as f:
        f.write(raw)
    plist = plistlib.loads(subprocess.run(['security', 'cms', '-D', '-i', f.name], capture_output=True, check=True).stdout)
    uuid = plist['UUID']
    folder = os.path.expanduser('~/Library/MobileDevice/Provisioning Profiles')
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, uuid + '.mobileprovision'), 'wb') as out:
        out.write(raw)
    log('installed profile', plist.get('Name'), 'expires', plist.get('ExpirationDate'))
    return uuid


if __name__ == '__main__':
    # The App Group makes an existing profile stale (its entitlements change), so a profile made before
    # the group was enabled is removed by profile() when its bundle or certificate no longer match; when
    # only the entitlements changed, FORCE_NEW_PROFILES=1 recreates both.
    cert = certificate()
    app = bundle_id()
    print(install(profile(app, cert)))
    # The widget needs an App Group, and App Groups have no App Store Connect API endpoint: the group
    # group.com.eworldq8.nokhatha is created once by hand in the developer portal, after which
    # NOKHATHA_WIDGET=1 adds the capability to both bundle ids and signs the widget too.
    if os.environ.get('NOKHATHA_WIDGET') == '1':
        widget = bundle_id(WIDGET_BUNDLE, 'Nokhatha Widget')
        group = app_group()
        enable_group(app, group)
        enable_group(widget, group)
        if os.environ.get('FORCE_NEW_PROFILES'):
            for name in (PROFILE_NAME, WIDGET_PROFILE_NAME):
                for p in call('GET', '/profiles', params={'filter[name]': name, 'limit': 20}).get('data', []):
                    log('removing profile', name)
                    call('DELETE', f"/profiles/{p['id']}")
        print(install(profile(widget, cert, WIDGET_PROFILE_NAME)))
