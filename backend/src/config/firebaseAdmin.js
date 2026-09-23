import { applicationDefault, cert, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

function resolveCredential() {
  const serviceAccountEnv = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (serviceAccountEnv) {
    try {
      const raw = serviceAccountEnv.trim();
      const parsed = raw.startsWith('{')
        ? JSON.parse(raw)
        : JSON.parse(Buffer.from(raw, 'base64').toString('utf8'));
      return cert(parsed);
    } catch (err) {
      console.error('Failed to parse FIREBASE_SERVICE_ACCOUNT:', err.message);
    }
  }
  // Local development fallback: uses GOOGLE_APPLICATION_CREDENTIALS
  return applicationDefault();
}

function firebaseAdminApp() {
  if (getApps().length === 0) {
    initializeApp({ credential: resolveCredential() });
  }
  return getApps()[0];
}

export function verifyFirebaseIdToken(idToken) {
  return getAuth(firebaseAdminApp()).verifyIdToken(idToken);
}
