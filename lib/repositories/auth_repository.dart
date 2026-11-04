import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/errors/app_exception.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import 'user_repository.dart';

class AuthRepository extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepository = UserRepository();

  UserModel? _currentUser;
  bool _isLoading = false;

  // Phone verification state
  String? _verificationId;
  int? _resendToken;
  ConfirmationResult? _webConfirmationResult;
  String? _lastPhoneNumber;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _auth.currentUser != null;
  String? get currentUid => _auth.currentUser?.uid;
  User? get currentFirebaseUser => _auth.currentUser;

  AuthRepository() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      notifyListeners();
    } else {
      await fetchCurrentUserData();
    }
  }

  /// Fetch user profile from Firestore or auto-recover if missing
  Future<UserModel?> fetchCurrentUserData() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    try {
      final profile = await _userRepository.ensureUserProfile(firebaseUser);
      _currentUser = profile;

      // Sync FCM token if available
      try {
        final fcmToken = await NotificationService().getFCMToken();
        if (fcmToken != null && fcmToken.isNotEmpty && fcmToken != profile.fcmToken) {
          await _userRepository.updateUserProfile(
            uid: firebaseUser.uid,
            fcmToken: fcmToken,
          );
          _currentUser = _currentUser?.copyWith(fcmToken: fcmToken);
        }
      } catch (e) {
        if (kDebugMode) print('FCM token fetch warning: $e');
      }

      notifyListeners();
      return _currentUser;
    } catch (e) {
      if (kDebugMode) print('fetchCurrentUserData error: $e');
      return null;
    }
  }

  /// Register new user with email, password, and profile fields
  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
    required String name,
    String? username,
    String phone = '',
    String photoURL = '',
    String bio = 'Hello! I am using Cosmic ✨',
  }) async {
    _setLoading(true);
    try {
      // 1. Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw AuthException('Registration failed. Please try again.');
      }

      // 2. Fetch FCM token safely (non-blocking)
      String? fcmToken;
      try {
        fcmToken = await NotificationService().getFCMToken();
      } catch (_) {}

      // 3. Create Firestore document at canonical path users/{uid}
      final trimmedName = name.trim();
      final effectiveUsername = (username != null && username.trim().isNotEmpty)
          ? username.trim().toLowerCase()
          : email.trim().toLowerCase().split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_.]'), '_');

      final newUser = await _userRepository.createUserProfile(
        uid: firebaseUser.uid,
        name: trimmedName,
        email: email.trim().toLowerCase(),
        phone: phone.trim(),
        photoURL: photoURL,
        bio: bio,
        username: effectiveUsername,
        authProvider: 'password',
        fcmToken: fcmToken,
      );

      // 4. Update Firebase Auth display name
      try {
        await firebaseUser.updateDisplayName(trimmedName);
      } catch (e) {
        if (kDebugMode) print('Could not update Firebase Auth display name: $e');
      }

      _currentUser = newUser;
      notifyListeners();
      return newUser;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Login with email and password
  Future<UserModel> loginWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      // 1. Authenticate with Firebase Authentication
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw AuthException('Login failed. Please check your credentials.');
      }

      // 2. Retrieve or safely recover profile from Firestore
      final profile = await _userRepository.ensureUserProfile(firebaseUser);
      _currentUser = profile;

      // 3. Update online status
      await _userRepository.updateUserProfile(
        uid: firebaseUser.uid,
        isOnline: true,
      );

      notifyListeners();
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Login error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Phone number OTP Verification - Step 1: Send OTP
  /// Works across Flutter Web (signInWithPhoneNumber) and Mobile (verifyPhoneNumber)
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required Function(String verificationIdOrPhone) onCodeSent,
    required Function(String error) onError,
  }) async {
    _setLoading(true);
    _lastPhoneNumber = phoneNumber.trim();

    try {
      if (kIsWeb) {
        // Flutter Web: Uses signInWithPhoneNumber with reCAPTCHA
        final confirmationResult = await _auth.signInWithPhoneNumber(
          _lastPhoneNumber!,
        );
        _webConfirmationResult = confirmationResult;
        _setLoading(false);
        onCodeSent(_lastPhoneNumber!);
      } else {
        // Mobile (Android / iOS): Uses verifyPhoneNumber
        await _auth.verifyPhoneNumber(
          phoneNumber: _lastPhoneNumber!,
          timeout: const Duration(seconds: 60),
          forceResendingToken: _resendToken,
          verificationCompleted: (PhoneAuthCredential credential) async {
            try {
              final userCredential = await _auth.signInWithCredential(credential);
              final firebaseUser = userCredential.user;
              if (firebaseUser != null) {
                final profile = await _userRepository.ensureUserProfile(
                  firebaseUser,
                  defaultPhone: _lastPhoneNumber,
                );
                _currentUser = profile;
                notifyListeners();
              }
            } catch (e) {
              if (kDebugMode) print('Auto-verification error: $e');
            } finally {
              _setLoading(false);
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            _setLoading(false);
            onError(_mapFirebaseAuthError(e));
          },
          codeSent: (String verificationId, int? resendToken) {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _setLoading(false);
            onCodeSent(verificationId);
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      onError(_mapFirebaseAuthError(e));
    } catch (e) {
      _setLoading(false);
      onError('Failed to send verification code: $e');
    }
  }

  /// Phone number OTP Verification - Step 2: Verify OTP
  Future<UserModel> verifyPhoneOtp({
    required String smsCode,
    String? displayName,
    String? username,
  }) async {
    _setLoading(true);
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        if (_webConfirmationResult == null) {
          throw AuthException('Verification session expired. Please request a new OTP.');
        }
        userCredential = await _webConfirmationResult!.confirm(smsCode.trim());
      } else {
        if (_verificationId == null) {
          throw AuthException('Verification session expired. Please request a new OTP.');
        }
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: smsCode.trim(),
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw AuthException('Phone authentication failed.');
      }

      // Automatically create or safely recover user profile without duplicates
      final profile = await _userRepository.ensureUserProfile(
        firebaseUser,
        defaultName: displayName,
        defaultPhone: firebaseUser.phoneNumber ?? _lastPhoneNumber,
        defaultUsername: username,
      );

      if (displayName != null && displayName.trim().isNotEmpty) {
        try {
          await firebaseUser.updateDisplayName(displayName.trim());
        } catch (_) {}
      }

      _currentUser = profile;
      notifyListeners();
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Verification error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update current user profile
  Future<void> updateUserProfile({
    String? name,
    String? displayName,
    String? bio,
    String? phone,
    String? photoURL,
    String? profilePhoto,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _userRepository.updateUserProfile(
      uid: uid,
      name: name,
      displayName: displayName,
      bio: bio,
      phone: phone,
      photoURL: photoURL,
      profilePhoto: profilePhoto,
    );

    await fetchCurrentUserData();
  }

  /// Forgot Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseAuthError(e));
    } finally {
      _setLoading(false);
    }
  }

  /// Check whether a username is already taken (authenticated or safe check)
  Future<bool> isUsernameTaken(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty) return false;
    try {
      final results = await _userRepository.searchUsers(cleanUsername, currentUserId: currentUid ?? '');
      return results.any((u) => u.username.toLowerCase() == cleanUsername);
    } catch (_) {
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _userRepository.updateUserProfile(
          uid: uid,
          isOnline: false,
        );
      } catch (_) {}
    }
    await _auth.signOut();
    _currentUser = null;
    _verificationId = null;
    _webConfirmationResult = null;
    _resendToken = null;
    notifyListeners();
  }

  /// User-friendly Firebase Auth error messages
  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'operation-not-allowed':
        return 'Phone Authentication is disabled for this Firebase project. Please enable "Phone" under Authentication > Sign-in method in Firebase Console.';
      case 'invalid-phone-number':
        return 'The phone number provided is invalid. Please enter a valid number with country code.';
      case 'invalid-verification-code':
        return 'The verification code entered is invalid. Please try again.';
      case 'invalid-verification-id':
      case 'session-expired':
        return 'The verification session has expired. Please request a new OTP code.';
      case 'quota-exceeded':
        return 'SMS quota exceeded for this project. Please try again later.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment before trying again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No user found with this email. Please create an account.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please verify your credentials.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection.';
      default:
        final msg = e.message ?? e.code;
        if (msg.contains('disabled for this Firebase project')) {
          return 'Phone Authentication is disabled for this Firebase project. Please enable "Phone" under Authentication > Sign-in method in Firebase Console.';
        }
        return msg;
    }
  }
}
