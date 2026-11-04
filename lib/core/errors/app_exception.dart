class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  AppException(this.message, {this.code, this.details});

  @override
  String toString() => message;
}

class AuthException extends AppException {
  AuthException(super.message, {super.code, super.details});
}

class DatabaseException extends AppException {
  DatabaseException(super.message, {super.code, super.details});
}

class NetworkException extends AppException {
  NetworkException(super.message, {super.code, super.details});
}

class CallException extends AppException {
  CallException(super.message, {super.code, super.details});
}

class StorageException extends AppException {
  StorageException(super.message, {super.code, super.details});
}
