import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth_interceptor.dart';
import '../core/secure_storage.dart';
import '../core/api_client.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<User?> {
  late AuthService _auth;
  late SecureStorage _storage;

  @override
  Future<User?> build() async {
    _auth = ref.read(authServiceProvider);
    _storage = ref.read(secureStorageProvider);

    // When interceptor fires forced logout, clear state
    ref.listen<int>(forceLogoutSignalProvider, (_, __) {
      state = const AsyncData(null);
    });

    // Restore session from SecureStorage
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return null;

    final userJson = await _storage.getUserJson();
    if (userJson == null) return null;

    try {
      final result = await _auth.refresh(refreshToken);
      setAccessToken(result.accessToken);
      if (result.refreshToken != null) {
        await _storage.saveRefreshToken(result.refreshToken!);
      }
      return User.fromJson(userJson);
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final result = await _auth.login(email, password);
      setAccessToken(result.accessToken);
      await _storage.saveRefreshToken(result.refreshToken);
      await _storage.saveUserJson(result.user.toJson());
      state = AsyncData(result.user);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> register(String email, String password, String fullName) async {
    state = const AsyncLoading();
    try {
      await _auth.register(email, password, fullName);
      // Auto-login after register
      await login(email, password);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    setAccessToken(null);
    await _storage.clear();
    state = const AsyncData(null);
  }
}
