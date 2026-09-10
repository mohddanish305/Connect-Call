import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState()) {
    init();
  }

  Future<void> init() async {
    state = state.copyWith(isLoading: true);
    try {
      await _authService.init();
      state = state.copyWith(user: _authService.currentUser, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<bool> signIn({required String emailOrPhone, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _authService.signIn(emailOrPhone: emailOrPhone, password: password);
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString().replaceAll('Exception: ', ''), isLoading: false);
      return false;
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _authService.signUp(
        name: name,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      );
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString().replaceAll('Exception: ', ''), isLoading: false);
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    await _authService.signOut();
    state = const AuthState();
  }

  Future<bool> updateProfile({required String name, String? photoUrl}) async {
    try {
      final updated = await _authService.updateProfile(name: name, photoUrl: photoUrl);
      state = state.copyWith(user: updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authNotifierProvider).user;
});
