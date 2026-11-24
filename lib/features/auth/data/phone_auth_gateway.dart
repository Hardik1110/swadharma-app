import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';

/// Sends and checks SMS codes. Abstracted so the repository can be tested
/// without Firebase.
abstract class PhoneAuthGateway {
  /// False when this build has no Firebase configuration.
  bool get isAvailable;

  /// Sends (or re-sends) a code to a 10-digit Indian mobile number.
  Future<void> sendCode(String phone);

  /// Checks [code] and returns a Firebase ID token for the verified number.
  Future<String> confirmCode(String code);
}

/// True when Firebase initialised from the native config files
/// (google-services.json / GoogleService-Info.plist). Set in main().
final firebaseReadyProvider = Provider<bool>((ref) => false);

final phoneAuthGatewayProvider = Provider<PhoneAuthGateway>(
    (ref) => FirebasePhoneAuthGateway(ref.watch(firebaseReadyProvider)));

/// Initialises Firebase from the platform config files. Returns false (and the
/// app falls back to demo OTP) when they are missing.
Future<bool> initFirebase() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
    return true;
  } catch (e) {
    debugPrint('Firebase not configured, using demo OTP: $e');
    return false;
  }
}

class FirebasePhoneAuthGateway implements PhoneAuthGateway {
  FirebasePhoneAuthGateway(this._ready);

  final bool _ready;
  String? _verificationId;
  int? _resendToken;

  @override
  bool get isAvailable => _ready;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  Future<void> sendCode(String phone) async {
    final sent = Completer<void>();
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        // Android may verify instantly; we still let the user type the code
        // so there is one path through the UI.
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          if (!sent.isCompleted) sent.completeError(mapFirebaseError(e));
        },
        codeSent: (id, token) {
          _verificationId = id;
          _resendToken = token;
          if (!sent.isCompleted) sent.complete();
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
      await sent.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw const AppException(
            'Could not send the code. Check your connection and try again.',
            code: 'network'),
      );
    } on FirebaseAuthException catch (e) {
      throw mapFirebaseError(e);
    }
  }

  @override
  Future<String> confirmCode(String code) async {
    final id = _verificationId;
    if (id == null) {
      throw const AppException('Please request a new code.', code: 'session-expired');
    }
    try {
      final cred = await _auth.signInWithCredential(
          PhoneAuthProvider.credential(verificationId: id, smsCode: code));
      final token = await cred.user?.getIdToken();
      // The app uses its own server session from here on.
      await _auth.signOut();
      if (token == null) {
        throw const AppException('Verification failed. Please try again.');
      }
      _verificationId = null;
      _resendToken = null;
      return token;
    } on FirebaseAuthException catch (e) {
      throw mapFirebaseError(e);
    }
  }
}

@visibleForTesting
AppException mapFirebaseError(FirebaseAuthException e) {
  debugPrint('Firebase auth error: ${e.code} - ${e.message}');
  final message = switch (e.code) {
    'invalid-phone-number' => 'That mobile number looks invalid.',
    'invalid-verification-code' => 'Incorrect code. Please check the SMS and try again.',
    'session-expired' || 'code-expired' => 'That code expired. Request a new one.',
    'too-many-requests' =>
      'Too many attempts. Please wait a few minutes and try again.',
    'quota-exceeded' => 'SMS limit reached for now. Please try again later.',
    'network-request-failed' =>
      'Can\'t reach the server. Check your internet connection.',
    'captcha-check-failed' || 'missing-client-identifier' || 'app-not-authorized' =>
      'This app build isn\'t registered with Firebase (check SHA keys / bundle id).',
    // Firebase uses this one code for several causes (provider disabled, SMS
    // region blocked, billing...), so show its own explanation.
    'operation-not-allowed' =>
      'Firebase refused this request: ${e.message ?? 'operation-not-allowed'}',
    _ => e.message ?? 'Verification failed. Please try again.',
  };
  return AppException(message,
      code: e.code == 'network-request-failed' ? 'network' : e.code);
}
