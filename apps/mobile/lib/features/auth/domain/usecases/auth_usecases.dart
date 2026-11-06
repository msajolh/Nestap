import '../../../../core/error/failures.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _phone = RegExp(r'^\+?[0-9]{8,15}$');

String _normalise(String target) => target.trim().replaceAll(RegExp(r'[\s-]'), '');

class RequestOtp {
  const RequestOtp(this._repository);

  final AuthRepository _repository;

  Future<void> call(String target) async {
    final value = _normalise(target);
    if (!_email.hasMatch(value) && !_phone.hasMatch(value)) {
      throw const ValidationFailure('Enter a valid email or phone number.');
    }
    return _repository.requestOtp(value);
  }
}

class VerifyOtp {
  const VerifyOtp(this._repository);

  final AuthRepository _repository;

  Future<User> call({required String target, required String code}) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) {
      throw const ValidationFailure('Enter the 6-digit code.');
    }
    return _repository.verifyOtp(target: _normalise(target), code: code.trim());
  }
}

class RestoreSession {
  const RestoreSession(this._repository);

  final AuthRepository _repository;

  Future<User?> call() => _repository.restoreSession();
}

class SignOut {
  const SignOut(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.signOut();
}
