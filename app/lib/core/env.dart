class Env {
  Env._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://minhnhat05.xyz/api',
  );
}
