import '../entities/user.dart';

abstract interface class AuthRepository {
  /// Sends a one-time code to an email address or phone number.
  Future<void> requestOtp(String target);

  Future<User> verifyOtp({required String target, required String code});

  /// The signed-in user from a previous launch, or null.
  Future<User?> restoreSession();

  Future<void> signOut();

  /// Emits when the server ends the session (refresh token rejected).
  Stream<void> get sessionExpired;
}
