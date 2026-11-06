/// Errors the domain and presentation layers understand.
///
/// The data layer converts transport errors (Dio, platform channels) into one
/// of these, so nothing above it ever sees a `DioException`.
sealed class Failure implements Exception {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No connection. Check your internet and try again.',
  ]);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([
    super.message = 'Your session has expired. Please sign in again.',
  ]);
}

final class DeviceOfflineFailure extends Failure {
  const DeviceOfflineFailure([
    super.message = 'The device is offline. Check its power and Wi-Fi.',
  ]);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.code});

  /// API error code, e.g. `RATE_LIMITED`.
  final String? code;
}

final class PairingFailure extends Failure {
  const PairingFailure(super.message);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong. Please try again.']);
}
