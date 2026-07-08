sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// No connectivity or request timed out.
class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Network error; check your connection',
  ]);
}

/// API returned an error response (4xx / 5xx).
class ApiException extends AppException {
  const ApiException(this.statusCode, super.message);
  final int statusCode;
}

/// 401 that could not be recovered by token refresh.
class AuthException extends AppException {
  const AuthException([super.message = 'Session expired; please log in again']);
}
