/// Common package exception
class OpenStoreException implements Exception {
  String cause;
  OpenStoreException(this.cause);
}

/// This exception was thrown when page in store can't be launchd
class CantLaunchPageException extends OpenStoreException {
  CantLaunchPageException(String cause) : super(cause);
}
