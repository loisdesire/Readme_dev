// Default `npm test`: fast, pure-function tests only. Emulator-backed
// tests live under lib/__tests__/emulator and run via `npm run test:emulator`
// (see jest.emulator.config.js), since they need the Auth + Firestore
// emulators up first.
module.exports = {
  testPathIgnorePatterns: ['/node_modules/', '<rootDir>/lib/__tests__/emulator/'],
};
