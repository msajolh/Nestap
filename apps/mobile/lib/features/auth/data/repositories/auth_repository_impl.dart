import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/storage/token_store.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_dto.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this._remote,
    required this._tokens,
    required this._prefs,
  });

  static const _kCachedUser = 'auth.cached_user';

  final AuthRemoteDataSource _remote;
  final TokenStore _tokens;
  final SharedPreferences _prefs;

  @override
  Stream<void> get sessionExpired => _tokens.onSessionExpired;

  @override
  Future<void> requestOtp(String target) => _remote.requestOtp(target);

  @override
  Future<User> verifyOtp({required String target, required String code}) async {
    await _tokens.save(await _remote.exchangeOtp(target, code));
    return _loadProfile();
  }

  @override
  Future<User?> restoreSession() async {
    if (await _tokens.read() == null) return null;
    try {
      return await _loadProfile();
    } on NetworkFailure {
      // Offline start: trust the cached profile; the token is checked on
      // the next request.
      return _cachedUser();
    } on UnauthorizedFailure {
      await _tokens.clear();
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _remote.logout();
    } on Failure {
      // Signing out locally must always work, even offline.
    }
    await _tokens.clear();
    await _prefs.remove(_kCachedUser);
  }

  Future<User> _loadProfile() async {
    final user = (await _remote.me()).toDomain();
    await _prefs.setString(_kCachedUser, jsonEncode(UserDto.fromDomain(user)));
    return user;
  }

  User? _cachedUser() {
    final raw = _prefs.getString(_kCachedUser);
    if (raw == null) return null;
    return UserDto(jsonDecode(raw) as Map<String, dynamic>).toDomain();
  }
}
