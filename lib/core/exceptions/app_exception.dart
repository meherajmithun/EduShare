/// app_exception.dart — Typed exceptions for the EduShare HTTP layer
///
/// Thrown by [ApiClient] and caught in screens/services to display
/// user-friendly error messages without leaking raw HTTP internals.

/// Base class for all EduShare exceptions.
abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// No internet connectivity or server unreachable.
class NetworkException extends AppException {
  const NetworkException([String message = 'No internet connection. Please check your network.'])
      : super(message);
}

/// HTTP 401 — token missing, invalid, or expired.
class UnauthorizedException extends AppException {
  const UnauthorizedException([String message = 'Session expired. Please log in again.'])
      : super(message);
}

/// HTTP 403 — authenticated but not allowed.
class ForbiddenException extends AppException {
  const ForbiddenException([String message = 'You do not have permission to perform this action.'])
      : super(message);
}

/// HTTP 404 — resource not found.
class NotFoundException extends AppException {
  const NotFoundException([String message = 'The requested resource was not found.'])
      : super(message);
}

/// HTTP 400 / 409 — validation or duplicate errors from the server.
class ValidationException extends AppException {
  const ValidationException(String message) : super(message);
}

/// HTTP 5xx — internal server error.
class ServerException extends AppException {
  const ServerException([String message = 'Server error. Please try again later.'])
      : super(message);
}

/// File upload failed (network or Cloudinary error).
class UploadException extends AppException {
  const UploadException([String message = 'File upload failed. Please try again.'])
      : super(message);
}
