import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'notification_service.dart';

/// AuthService — Firebase Authentication source of truth.
///
/// Identity is exclusively based on FirebaseAuth.instance.currentUser.uid.
/// SharedPreferences is no longer used for authentication identity.
/// Local demo user IDs (user_1 … user_5) are not used for Firestore operations.
class AuthService {
  final FirebaseAuth? _firebaseAuth;
  final FirebaseFirestore? _firestore;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  AuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? _safeGetFirebaseAuth(),
        _firestore = firestore ?? _safeGetFirestore();

  static FirebaseAuth? _safeGetFirebaseAuth() {
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      debugPrint('[AuthService] FirebaseAuth not available: $e');
      return null;
    }
  }

  static FirebaseFirestore? _safeGetFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('[AuthService] Firestore not available: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Initialization — restore session from Firebase Auth persistent state
  // ---------------------------------------------------------------------------

  /// Stream of Firebase Auth user state changes safely wrapped
  Stream<User?> authStateChanges() {
    return _firebaseAuth?.authStateChanges() ?? const Stream.empty();
  }

  /// Called once at app startup by AuthNotifier.
  /// Reads the Firebase Auth persistent session — no SharedPreferences needed.
  Future<void> init() async {
    try {
      final fbUser = _firebaseAuth?.currentUser;
      if (fbUser != null) {
        debugPrint('[Firebase] projectId=connectcall-01');
        debugPrint('[Auth] Restored session uid=${fbUser.uid} email=${fbUser.email}');
        _currentUser = await _loadOrCreateProfile(fbUser);
        NotificationService().syncTokenToFirestore(fbUser.uid);
        debugPrint(
          '[AUTH DEBUG]\n'
          'enteredEmail=${fbUser.email}\n'
          'firebaseCurrentUid=${fbUser.uid}\n'
          'firebaseCurrentEmail=${fbUser.email}\n'
          'userDocumentUid=${_currentUser?.id}',
        );
      } else {
        debugPrint('[Auth] No active Firebase session.');
        _currentUser = null;
      }
    } catch (e) {
      debugPrint('[AuthService] init error: $e');
      _currentUser = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Sign Up — creates a real Firebase Auth user
  // ---------------------------------------------------------------------------

  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    // Client-side validation
    if (name.trim().isEmpty) {
      throw Exception('Please enter your full name.');
    }
    if (!email.contains('@') || !email.contains('.') || email.trim().length < 5) {
      throw Exception('Please enter a valid email address.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters long.');
    }
    if (password != confirmPassword) {
      throw Exception('Passwords do not match.');
    }

    final auth = _firebaseAuth;
    if (auth == null) throw Exception('Firebase Authentication is not available.');

    try {
      // 1. Create Firebase Auth account
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final fbUser = credential.user!;

      // 2. Set display name on Firebase Auth profile
      await fbUser.updateDisplayName(name.trim());
      // Reload to ensure displayName is populated on currentUser
      await fbUser.reload();

      debugPrint('[Auth] Registered new user uid=${fbUser.uid} email=${fbUser.email}');

      // 3. Build UserModel using Firebase UID as canonical ID
      final newUser = UserModel(
        id: fbUser.uid,
        name: name.trim(),
        email: email.trim(),
        phone: '',
        photoUrl: fbUser.photoURL,
        isOnline: true,
        lastSeen: DateTime.now(),
        createdAt: DateTime.now(),
      );

      // 4. Write users/{uid} to Firestore
      await _syncToFirestore(newUser, isOnline: true);

      _currentUser = newUser;
      NotificationService().syncTokenToFirestore(fbUser.uid);
      debugPrint(
        '[AUTH DEBUG]\n'
        'enteredEmail=${email.trim()}\n'
        'firebaseCurrentUid=${fbUser.uid}\n'
        'firebaseCurrentEmail=${fbUser.email}\n'
        'userDocumentUid=${newUser.id}',
      );
      debugPrint('[Firestore] users/${fbUser.uid} profile synced (sign-up)');
      return newUser;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Sign In — authenticates an existing Firebase Auth user
  // ---------------------------------------------------------------------------

  Future<UserModel> signIn({
    required String emailOrPhone,
    required String password,
  }) async {
    if (emailOrPhone.trim().isEmpty) {
      throw Exception('Please enter your email address.');
    }
    if (password.isEmpty) {
      throw Exception('Please enter your password.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final auth = _firebaseAuth;
    if (auth == null) throw Exception('Firebase Authentication is not available.');

    try {
      // Firebase Auth sign in — requires email (not phone for now)
      final credential = await auth.signInWithEmailAndPassword(
        email: emailOrPhone.trim(),
        password: password,
      );

      final fbUser = credential.user!;
      debugPrint('[Auth] Signed in uid=${fbUser.uid} email=${fbUser.email}');

      // Load or create Firestore profile for this user
      final user = await _loadOrCreateProfile(fbUser);
      await _syncToFirestore(user, isOnline: true);

      _currentUser = user;
      NotificationService().syncTokenToFirestore(fbUser.uid);
      debugPrint(
        '[AUTH DEBUG]\n'
        'enteredEmail=${emailOrPhone.trim()}\n'
        'firebaseCurrentUid=${fbUser.uid}\n'
        'firebaseCurrentEmail=${fbUser.email}\n'
        'userDocumentUid=${user.id}',
      );
      debugPrint('[Firestore] users/${fbUser.uid} presence updated (sign-in)');
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthError(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Sign In with Google
  // ---------------------------------------------------------------------------

  Future<UserModel> signInWithGoogle() async {
    try {
      // 1. Trigger Google Sign In flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      
      if (googleUser == null) {
        throw Exception('Google sign in was aborted.');
      }

      // 2. Obtain auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final auth = _firebaseAuth;
      if (auth == null) throw Exception('Firebase Authentication is not available.');

      // 4. Sign in to Firebase with the credential
      final UserCredential userCredential = await auth.signInWithCredential(credential);
      final fbUser = userCredential.user!;

      debugPrint('[Auth] Signed in with Google uid=${fbUser.uid} email=${fbUser.email}');

      // 5. Load or create Firestore profile
      final user = await _loadOrCreateProfile(fbUser);
      
      // Sync online presence
      await _syncToFirestore(user, isOnline: true);

      _currentUser = user;
      NotificationService().syncTokenToFirestore(fbUser.uid);
      debugPrint(
        '[AUTH DEBUG]\n'
        'enteredEmail=${fbUser.email}\n'
        'firebaseCurrentUid=${fbUser.uid}\n'
        'firebaseCurrentEmail=${fbUser.email}\n'
        'userDocumentUid=${user.id}',
      );
      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthError(e));
    } catch (e) {
      debugPrint('[AuthService] Google Sign-In error: $e');
      throw Exception('Failed to sign in with Google: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Sign Out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    final user = _currentUser;

    // 1. Mark offline and clear push notification registration in Firestore before signing out
    if (user != null) {
      try {
        await NotificationService().clearToken(user.id);
        await _syncToFirestore(user, isOnline: false);
        debugPrint('[Firestore] users/${user.id} marked offline (sign-out)');
      } catch (e) {
        debugPrint('[AuthService] Notice updating offline presence: $e');
      }
    }

    // 2. Disconnect Google Sign In if active
    try {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
        debugPrint('[Auth] Google Sign In signed out.');
      }
    } catch (e) {
      debugPrint('[AuthService] GoogleSignIn signOut notice: $e');
    }

    // 3. Sign out from Firebase Auth — clears persistent session
    try {
      await _firebaseAuth?.signOut();
      debugPrint('[Auth] Firebase Auth signed out.');
    } catch (e) {
      debugPrint('[AuthService] signOut notice: $e');
    }

    _currentUser = null;
    debugPrint(
      '[AUTH DEBUG]\n'
      'enteredEmail=null\n'
      'firebaseCurrentUid=null\n'
      'firebaseCurrentEmail=null\n'
      'userDocumentUid=null',
    );
  }

  // ---------------------------------------------------------------------------
  // Update Profile
  // ---------------------------------------------------------------------------

  Future<UserModel> updateProfile({required String name, String? photoUrl}) async {
    if (_currentUser == null) throw Exception('No active session.');

    final fbUser = _firebaseAuth?.currentUser;
    if (fbUser == null) throw Exception('Not authenticated.');

    // Update Firebase Auth profile
    if (name.trim().isNotEmpty && name.trim() != fbUser.displayName) {
      await fbUser.updateDisplayName(name.trim());
    }
    if (photoUrl != null && photoUrl != fbUser.photoURL) {
      await fbUser.updatePhotoURL(photoUrl);
    }

    final updatedUser = _currentUser!.copyWith(
      name: name.trim().isNotEmpty ? name.trim() : _currentUser!.name,
      photoUrl: photoUrl ?? _currentUser!.photoUrl,
    );

    await _syncToFirestore(updatedUser, isOnline: true);
    _currentUser = updatedUser;
    debugPrint('[Firestore] users/${updatedUser.id} profile updated');
    return updatedUser;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Load Firestore profile for a Firebase Auth user, or construct a default.
  Future<UserModel> _loadOrCreateProfile(User fbUser) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final doc = await firestore
            .collection('users')
            .doc(fbUser.uid)
            .get()
            .timeout(const Duration(seconds: 5));

        if (doc.exists && doc.data() != null) {
          return UserModel.fromMap(doc.data()!);
        }
      } catch (e) {
        debugPrint('[AuthService] Could not load Firestore profile, using Auth data: $e');
      }
    }

    // Fallback: build from Firebase Auth data
    return UserModel(
      id: fbUser.uid,
      name: fbUser.displayName ?? fbUser.email?.split('@').first ?? 'User',
      email: fbUser.email ?? '',
      phone: fbUser.phoneNumber ?? '',
      photoUrl: fbUser.photoURL,
      isOnline: true,
      lastSeen: DateTime.now(),
      createdAt: fbUser.metadata.creationTime ?? DateTime.now(),
    );
  }

  /// Write the user's profile + presence to Firestore users/{uid}.
  Future<void> _syncToFirestore(UserModel user, {required bool isOnline}) async {
    final firestore = _firestore;
    if (firestore == null || user.id.isEmpty) return;
    try {
      await firestore.collection('users').doc(user.id).set({
        'id': user.id,
        'uid': user.id,
        'name': user.name,
        'displayName': user.name,
        'email': user.email,
        'phone': user.phone,
        'photoUrl': user.photoUrl,
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
        'createdAt': (user.createdAt != null)
            ? Timestamp.fromDate(user.createdAt!)
            : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AuthService] Notice syncing to Firestore: $e');
    }
  }

  /// Translate Firebase Auth error codes to user-friendly messages.
  String _mapFirebaseAuthError(FirebaseAuthException e) {
    debugPrint('[Auth] FirebaseAuthException code=${e.code} message=${e.message}');
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email. Please register first.';
      case 'wrong-password':
        return 'Invalid email or password.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. Please contact support.';
      case 'requires-recent-login':
        return 'Please sign in again to complete this action.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // Legacy compatibility — kept so callers don't break (returns empty list)
  // ---------------------------------------------------------------------------

  /// Returns an empty list — contacts come from Firestore via UserService.
  Future<List<UserModel>> getAllUsers() async => [];
}
