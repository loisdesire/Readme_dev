// Emulator-backed tests: real Admin SDK calls against the local Auth +
// Firestore emulators (started by `firebase emulators:exec`, which sets
// FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST for us). Run via
// `npm run test:emulator`, never directly with plain `jest`.
module.exports = {
  testMatch: ['<rootDir>/lib/__tests__/emulator/**/*.test.js'],
  testTimeout: 20000,
};
