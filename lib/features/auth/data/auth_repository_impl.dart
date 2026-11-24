import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_token_provider.dart';
import '../../../core/storage/session_storage.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/user.dart';
import 'phone_auth_gateway.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepositoryImpl(
      ref.watch(apiClientProvider),
      ref.watch(sessionStorageProvider),
      ref.read(authTokenProvider.notifier),
      ref.watch(phoneAuthGatewayProvider),
    ));

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, this._storage, this._token, this._phoneAuth);

  final ApiClient _api;
  final SessionStorage _storage;
  final AuthTokenNotifier _token;
  final PhoneAuthGateway _phoneAuth;

  /// Whether the OTP currently in flight was sent by Firebase (real SMS).
  bool _viaFirebase = false;

  @override
  User? cachedUser() {
    final json = _storage.userJson;
    if (_storage.token == null || json == null) return null;
    try {
      return User.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<User> fetchMe() async {
    final json = await _api.get<Map<String, dynamic>>('/me');
    return _cache(User.fromJson(json));
  }

  @override
  Future<OtpTicket> sendOtp(String phone, OtpPurpose purpose) async {
    final config = await _api.get<Map<String, dynamic>>('/config');
    final serverUsesFirebase = config['phoneAuth'] == 'firebase';

    if (serverUsesFirebase) {
      if (!_phoneAuth.isAvailable) {
        throw const AppException(
          'This server uses SMS login, but Firebase is not set up in this app build.',
          code: 'firebase_not_configured',
        );
      }
      // Don't text a number that is on the wrong flow (no account / already
      // registered).
      await _api.post<dynamic>(
          '/auth/check-phone', {'phone': phone, 'purpose': purpose.name});
      await _phoneAuth.sendCode(phone);
      _viaFirebase = true;
      return const OtpTicket(resendIn: Duration(seconds: 60));
    }

    _viaFirebase = false;
    final res = await _api.post<Map<String, dynamic>>(
        '/auth/send-otp', {'phone': phone, 'purpose': purpose.name});
    return OtpTicket(
      resendIn: Duration(seconds: (res['resendIn'] as num?)?.toInt() ?? 30),
      devOtp: res['devOtp'] as String?,
    );
  }

  @override
  Future<User> verifyOtp({
    required String phone,
    required String otp,
    required OtpPurpose purpose,
    String? name,
  }) async {
    final Map<String, dynamic> res;
    if (_viaFirebase) {
      final idToken = await _phoneAuth.confirmCode(otp);
      res = await _api.post<Map<String, dynamic>>('/auth/firebase', {
        'idToken': idToken,
        'purpose': purpose.name,
        'name': ?name,
      });
    } else {
      res = await _api.post<Map<String, dynamic>>(
          '/auth/verify-otp', {'phone': phone, 'otp': otp, 'name': ?name});
    }
    final user = User.fromJson(res['user'] as Map<String, dynamic>);
    await _cache(user);
    await _token.set(res['token'] as String);
    return user;
  }

  @override
  Future<User> updateProfile(ProfileInput input) async {
    final json = await _api.put<Map<String, dynamic>>('/me', input.toJson());
    return _cache(User.fromJson(json));
  }

  @override
  Future<void> logout() async {
    try {
      await _api.post<dynamic>('/auth/logout');
    } catch (_) {
      // Best effort: the local session is cleared regardless.
    }
    await _token.clear();
  }

  Future<User> _cache(User user) async {
    await _storage.saveUserJson(user.toJson());
    return user;
  }
}
