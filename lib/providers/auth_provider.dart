import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

// ---------------------------------------------------------------------------
// Firebase Auth stream provider — single source of truth for auth state.
// Reacts to sign-in, sign-out, and session restoration automatically.
// ---------------------------------------------------------------------------

final firebaseAuthStateProvider = StreamProvider<User?>((ref) {
  try {
    return FirebaseAuth.instance.authStateChanges();
  } catch (_) {
    return const Stream.empty();
  }
});

// ---------------------------------------------------------------------------
// AuthService provider
// ---------------------------------------------------------------------------

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// ---------------------------------------------------------------------------
// AuthState
// ---------------------------------------------------------------------------

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

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

// ---------------------------------------------------------------------------
// AuthNotifier
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  StreamSubscription<User?>? _authSubscription;

  AuthNotifier(this._authService) : super(const AuthState(isLoading: true)) {
    _initAuthListener();
  }

  void _initAuthListener() {
    _authSubscription = _authService.authStateChanges().listen((fbUser) async {
      if (fbUser == null) {
        state = const AuthState();
      } else if (state.user?.id != fbUser.uid) {
        await init();
      }
    });
    init();
  }

  /// Restore Firebase Auth session on startup.
  Future<void> init() async {
    try {
      await _authService.init();
      state = state.copyWith(user: _authService.currentUser, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Could not restore session. Please sign in.',
        isLoading: false,
      );
    }
  }

  Future<bool> signIn({
    required String emailOrPhone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _authService.signIn(
        emailOrPhone: emailOrPhone,
        password: password,
      );
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(error: _mapAuthError(e), isLoading: false);
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _authService.signInWithGoogle();
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(error: _mapAuthError(e), isLoading: false);
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
      state = state.copyWith(error: _mapAuthError(e), isLoading: false);
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
      final updated = await _authService.updateProfile(
        name: name,
        photoUrl: photoUrl,
      );
      state = state.copyWith(user: updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: _mapAuthError(e));
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Maps all Firebase Auth error codes + generic Exception messages
  /// to user-friendly strings. AuthService already maps FirebaseAuthException
  /// codes before throwing, so this handles the outer Exception wrapper.
  String _mapAuthError(Object error) {
    final msg = error.toString().replaceAll('Exception: ', '').toLowerCase();

    // Network / connectivity
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('timeout') ||
        msg.contains('connection')) {
      return 'No internet connection. Please check your network and try again.';
    }
    // Email issues
    if (msg.contains('valid email') || msg.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    // Password missing
    if (msg.contains('enter your password') || msg.contains('empty password')) {
      return 'Please enter your password.';
    }
    // Wrong credentials
    if (msg.contains('wrong-password') ||
        msg.contains('user-not-found') ||
        msg.contains('invalid-credential') ||
        msg.contains('invalid email or password')) {
      return 'Invalid email or password.';
    }
    // Account already exists
    if (msg.contains('email-already-in-use') ||
        msg.contains('already exists with this email')) {
      return 'An account already exists with this email.';
    }
    // Passwords mismatch
    if (msg.contains('passwords do not match')) {
      return 'Passwords do not match.';
    }
    // Weak password
    if (msg.contains('weak-password') || msg.contains('6 characters')) {
      return 'Password must be at least 6 characters.';
    }
    // Too many attempts
    if (msg.contains('too-many-requests') || msg.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    // Not found
    if (msg.contains('no account found')) {
      return 'No account found with this email. Please register first.';
    }
    // Disabled
    if (msg.contains('user-disabled') || msg.contains('disabled')) {
      return 'This account has been disabled. Please contact support.';
    }
    // Generic — surface the already-friendly message from AuthService
    final cleaned = error.toString().replaceAll('Exception: ', '');
    if (cleaned.length < 120) return cleaned;
    return 'Authentication failed. Please try again.';
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authNotifierProvider).user;
});
