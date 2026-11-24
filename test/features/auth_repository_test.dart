import 'package:astro_connect/core/errors/app_exception.dart';
import 'package:astro_connect/core/network/api_client.dart';
import 'package:astro_connect/core/storage/auth_token_provider.dart';
import 'package:astro_connect/core/storage/session_storage.dart';
import 'package:astro_connect/features/auth/data/auth_repository_impl.dart';
import 'package:astro_connect/features/auth/data/phone_auth_gateway.dart';
import 'package:astro_connect/features/auth/domain/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeApi extends ApiClient {
  FakeApi(this.phoneAuth) : super(Dio());

  final String phoneAuth;
  final calls = <String>[];
  final bodies = <String, Object?>{};
  AppException? checkPhoneError;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    calls.add('GET $path');
    return {'phoneAuth': phoneAuth} as T;
  }

  @override
  Future<T> post<T>(String path, [Object? body]) async {
    calls.add('POST $path');
    bodies[path] = body;
    if (path == '/auth/check-phone' && checkPhoneError != null) throw checkPhoneError!;
    if (path == '/auth/send-otp') return {'resendIn': 30, 'devOtp': '123456'} as T;
    if (path == '/auth/verify-otp' || path == '/auth/firebase') {
      return {
        'token': 'server-token',
        'user': {'id': 'u1', 'phone': '9876543210', 'name': 'Asha'},
      } as T;
    }
    return <String, dynamic>{} as T;
  }
}

class FakeGateway implements PhoneAuthGateway {
  FakeGateway({this.available = true});

  final bool available;
  @override
  bool get isAvailable => available;

  final sentTo = <String>[];
  String? confirmed;

  @override
  Future<void> sendCode(String phone) async => sentTo.add(phone);

  @override
  Future<String> confirmCode(String code) async {
    confirmed = code;
    return 'firebase-id-token';
  }
}

void main() {
  late ProviderContainer container;

  Future<AuthRepository> build(FakeApi api, FakeGateway gateway) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer.test(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      apiClientProvider.overrideWithValue(api),
      phoneAuthGatewayProvider.overrideWithValue(gateway),
    ]);
    return container.read(authRepositoryProvider);
  }

  test('demo server: uses the on-screen OTP endpoints', () async {
    final api = FakeApi('demo');
    final gateway = FakeGateway();
    final repo = await build(api, gateway);

    final ticket = await repo.sendOtp('9876543210', OtpPurpose.signup);
    expect(ticket.devOtp, '123456');
    expect(gateway.sentTo, isEmpty);

    await repo.verifyOtp(
        phone: '9876543210', otp: '123456', purpose: OtpPurpose.signup, name: 'Asha');
    expect(api.calls, contains('POST /auth/verify-otp'));
    expect(container.read(authTokenProvider), 'server-token');
  });

  test('firebase server: checks the number, sends SMS, exchanges the ID token', () async {
    final api = FakeApi('firebase');
    final gateway = FakeGateway();
    final repo = await build(api, gateway);

    final ticket = await repo.sendOtp('9876543210', OtpPurpose.signup);
    expect(ticket.devOtp, isNull);
    // Server is asked first; the demo OTP endpoint is never used.
    expect(api.calls, ['GET /config', 'POST /auth/check-phone']);
    expect(gateway.sentTo, ['9876543210']);

    await repo.verifyOtp(
        phone: '9876543210', otp: '654321', purpose: OtpPurpose.signup, name: 'Asha');
    expect(gateway.confirmed, '654321');
    expect(api.bodies['/auth/firebase'],
        {'idToken': 'firebase-id-token', 'purpose': 'signup', 'name': 'Asha'});
    expect(api.calls, isNot(contains('POST /auth/verify-otp')));
    expect(container.read(authTokenProvider), 'server-token');
  });

  test('firebase server: no SMS when the account check fails', () async {
    final api = FakeApi('firebase')
      ..checkPhoneError =
          const AppException('No account', code: 'account_not_found', statusCode: 404);
    final gateway = FakeGateway();
    final repo = await build(api, gateway);

    await expectLater(
      repo.sendOtp('9876543210', OtpPurpose.login),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'account_not_found')),
    );
    expect(gateway.sentTo, isEmpty);
  });

  test('firebase server but app has no Firebase config: clear error', () async {
    final repo = await build(FakeApi('firebase'), FakeGateway(available: false));
    await expectLater(
      repo.sendOtp('9876543210', OtpPurpose.login),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'firebase_not_configured')),
    );
  });
}
