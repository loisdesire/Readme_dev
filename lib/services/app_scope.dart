/// Lightweight scoping for Firestore queries that should be isolated to this app.
///
/// This helps prevent cross-app/test data from appearing in features like the
/// leaderboard when multiple apps share a Firebase project or collection.
class AppScope {
  static const String namespace = String.fromEnvironment(
    'APP_NAMESPACE',
    defaultValue: 'readme_dev',
  );

  static const String userNamespaceField = 'appNamespace';
}
