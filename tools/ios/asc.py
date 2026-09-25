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


def bundle_id():
    found = call('GET', '/bundleIds', params={'filter[identifier]': BUNDLE, 'limit': 5})['data']
    exact = [b for b in found if b['attributes']['identifier'] == BUNDLE]
    if exact:
        log('bundle id exists', BUNDLE)
        return exact[0]['id']
    log('registering bundle id', BUNDLE)
    return call('POST', '/bundleIds', {'data': {'type': 'bundleIds', 'attributes': {
        'identifier': BUNDLE, 'name': 'Nokhatha', 'platform': 'IOS'}}})['data']['id']


def certificate():
    certs = []
    for kind in ('DISTRIBUTION', 'IOS_DISTRIBUTION'):
        certs += call('GET', '/certificates', params={'filter[certificateType]': kind, 'limit': 200})['data']
    for c in certs:
        if c['attributes'].get('serialNumber', '').upper().lstrip('0') == SERIAL:
            log('distribution certificate', c['attributes'].get('name'), c['attributes'].get('expirationDate'))
            return c['id']
    sys.exit('the imported certificate was not found in the team, serial ' + SERIAL)


def profile(bundle, cert):
    existing = call('GET', '/profiles', params={'filter[name]': PROFILE_NAME, 'filter[profileState]': 'ACTIVE',
                                                'include': 'certificates,bundleId', 'limit': 20})
    for p in existing.get('data', []):
        rel = p.get('relationships', {})
        certs = [c['id'] for c in rel.get('certificates', {}).get('data', [])]
        b = rel.get('bundleId', {}).get('data', {}).get('id')
        if cert in certs and b == bundle and p['attributes']['profileType'] == 'IOS_APP_STORE':
            log('reusing profile', p['attributes']['name'])
            return p['attributes']['profileContent']
        log('removing stale profile', p['id'])
        call('DELETE', f"/profiles/{p['id']}")
    log('creating profile', PROFILE_NAME)
    return call('POST', '/profiles', {'data': {'type': 'profiles', 'attributes': {'name': PROFILE_NAME, 'profileType': 'IOS_APP_STORE'},
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
    print(install(profile(bundle_id(), certificate())))
