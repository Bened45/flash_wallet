import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'flash_api.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final String? error;
  final String? userId;
  final String? tag;
  final String? name;
  final String? email;
  final String? whatsapp;

  const AuthState({
    this.status = AuthStatus.initial,
    this.error,
    this.userId,
    this.tag,
    this.name,
    this.email,
    this.whatsapp,
  });

  // Lightning Address calculée depuis le tag
  String get lightningAddress =>
      tag != null && tag!.isNotEmpty ? '$tag@bitcoinflash.xyz' : '';

  // Initiales pour l'avatar
  String get initials {
    if (name == null || name!.isEmpty) return '??';
    final parts = name!.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name!.substring(0, 2).toUpperCase();
  }

  AuthState copyWith({
    AuthStatus? status,
    String? error,
    String? userId,
    String? tag,
    String? name,
    String? email,
    String? whatsapp,
  }) {
    return AuthState(
      status: status ?? this.status,
      error: error,
      userId: userId ?? this.userId,
      tag: tag ?? this.tag,
      name: name ?? this.name,
      email: email ?? this.email,
      whatsapp: whatsapp ?? this.whatsapp,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final FlashApi _api;

  AuthNotifier(this._api) : super(const AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final isLogged = await _api.isLoggedIn();
    if (isLogged) {
      final info = await _api.getUserInfo();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        userId: info['id'],
        tag: info['tag'],
        name: info['name'],
        email: info['email'],
        whatsapp: info['whatsapp'],
      );
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final res = await _api.login(email: email, password: password);
      final user = res['data']['user'];
      state = state.copyWith(
        status: AuthStatus.authenticated,
        userId: user['id'],
        tag: user['tag'],
        name: user['name'],
        email: user['email'],
        whatsapp: user['whatsapp'],
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: _parseError(e),
      );
      return false;
    }
  }

  Future<Map<String, dynamic>?> register({
    required String name,
    required String email,
    required String password,
    required String whatsapp,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final res = await _api.register(
        name: name,
        email: email,
        password: password,
        whatsapp: whatsapp,
      );
      final user = res['data']['user'];
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        userId: user['id'],
        tag: user['tag'],
        name: user['name'],
        email: user['email'],
      );
      return res;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: _parseError(e),
      );
      return null;
    }
  }

  Future<bool> verifyOtp(String userId, String code) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _api.verifyOtp(userId: userId, code: code);
      // Après OTP, connecter automatiquement
      state = state.copyWith(status: AuthStatus.authenticated);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: _parseError(e),
      );
      return false;
    }
  }

  Future<bool> regenerateOtp(String userId) async {
    try {
      await _api.regenerateOtp(userId: userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _parseError(dynamic e) {
    if (e is Exception) {
      final msg = e.toString().replaceAll('Exception: ', '');
      return msg;
    }
    return 'Une erreur est survenue';
  }
}

// Providers
final flashApiProvider = Provider<FlashApi>((ref) {
  final api = FlashApi();
  api.init();
  return api;
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(flashApiProvider));
});