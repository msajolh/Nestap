import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../auth_providers.dart';
import '../../domain/entities/user.dart';

sealed class AuthState {
  const AuthState();
}

/// Still reading the stored session (splash screen).
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

final class Unauthenticated extends AuthState {
  const Unauthenticated();
}

final class Authenticated extends AuthState {
  const Authenticated(this.user);

  final User user;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Single source of truth for "who is signed in". The router redirects on it.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final expired = ref
        .watch(authRepositoryProvider)
        .sessionExpired
        .listen((_) => state = const Unauthenticated());
    ref.onDispose(expired.cancel);

    unawaited(_restore());
    return const AuthUnknown();
  }

  Future<void> _restore() async {
    AuthState next;
    try {
      final user = await ref.read(restoreSessionProvider)();
      next = user == null ? const Unauthenticated() : Authenticated(user);
    } on Failure {
      next = const Unauthenticated();
    }
    if (ref.mounted) state = next;
  }

  Future<void> requestOtp(String target) => ref.read(requestOtpProvider)(target);

  Future<void> verifyOtp({required String target, required String code}) async {
    final user = await ref.read(verifyOtpProvider)(target: target, code: code);
    if (ref.mounted) state = Authenticated(user);
  }

  Future<void> signOut() async {
    await ref.read(signOutProvider)();
    if (ref.mounted) state = const Unauthenticated();
  }
}

/// The signed-in user; only read this below the auth redirect.
final currentUserProvider = Provider<User?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is Authenticated ? auth.user : null;
});
