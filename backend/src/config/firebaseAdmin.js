import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

// Local development must set GOOGLE_APPLICATION_CREDENTIALS to an absolute
// service-account JSON path. Keep credentials outside source control.
function firebaseAdminApp() {
  if (getApps().length === 0) {
    initializeApp({credential: applicationDefault()});
  }
  return getApps()[0];
}

export function verifyFirebaseIdToken(idToken) {
  return getAuth(firebaseAdminApp()).verifyIdToken(idToken);
}
