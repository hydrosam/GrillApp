class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, {this.cause});

  @override
  String toString() {
    if (cause == null) {
      return 'AppException: $message';
    }
    return 'AppException: $message ($cause)';
  }
}

class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause});
}

class StorageException extends AppException {
  const StorageException(super.message, {super.cause});
}

class NotificationException extends AppException {
  const NotificationException(super.message, {super.cause});
}
