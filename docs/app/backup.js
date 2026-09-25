// Encrypted backups. The passphrase never leaves the device and is never stored.
// Format 1: PBKDF2-SHA256 (600,000 iterations) derives an AES-256-GCM key.
// The same format is readable by the iOS and Android apps.

const enc = new TextEncoder();
const dec = new TextDecoder();
const ITERATIONS = 600000;

function toB64(u8) {
  let s = '';
  for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
  return btoa(s);
}

function fromB64(b64) {
  const s = atob(b64);
  const u = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) u[i] = s.charCodeAt(i);
  return u;
}

async function keyFrom(pass, salt, iterations) {
  const base = await crypto.subtle.importKey('raw', enc.encode(pass), 'PBKDF2', false, ['deriveKey']);
  return crypto.subtle.deriveKey(
    { name: 'PBKDF2', hash: 'SHA-256', salt, iterations },
    base,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt'],
  );
}

export async function encryptBackup(payload, pass) {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await keyFrom(pass, salt, ITERATIONS);
  const data = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, enc.encode(JSON.stringify(payload))));
  return { app: 'nokhatha', format: 1, kdf: 'PBKDF2-SHA256', iterations: ITERATIONS, cipher: 'AES-256-GCM', salt: toB64(salt), iv: toB64(iv), data: toB64(data) };
}

// Throws Error('format') for a file that is not a Nokhatha backup,
// Error('pass') when the passphrase is wrong or the file was altered.
export async function decryptBackup(file, pass) {
  if (!file || file.app !== 'nokhatha' || file.format !== 1 || !file.salt || !file.iv || !file.data) throw new Error('format');
  const key = await keyFrom(pass, fromB64(file.salt), file.iterations || ITERATIONS);
  let plain;
  try {
    plain = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: fromB64(file.iv) }, key, fromB64(file.data));
  } catch {
    throw new Error('pass');
  }
  return JSON.parse(dec.decode(plain));
}

export async function blobToB64(blob) {
  return toB64(new Uint8Array(await blob.arrayBuffer()));
}

export function b64ToBlob(b64, type) {
  return new Blob([fromB64(b64)], { type: type || 'image/jpeg' });
}
