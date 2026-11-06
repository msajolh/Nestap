import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/datasources/auth_remote_data_source.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/usecases/auth_usecases.dart';

/// Wiring for the auth feature: data → domain.
/// Presentation code depends only on the use cases.

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    remote: AuthRemoteDataSource(
      ref.watch(apiClientProvider),
      ref.watch(dioProvider),
    ),
    tokens: ref.watch(tokenStoreProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  ),
);

final requestOtpProvider = Provider((ref) => RequestOtp(ref.watch(authRepositoryProvider)));
final verifyOtpProvider = Provider((ref) => VerifyOtp(ref.watch(authRepositoryProvider)));
final restoreSessionProvider = Provider((ref) => RestoreSession(ref.watch(authRepositoryProvider)));
final signOutProvider = Provider((ref) => SignOut(ref.watch(authRepositoryProvider)));
