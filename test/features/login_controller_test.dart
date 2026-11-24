import 'package:astro_connect/core/storage/session_storage.dart';
import 'package:astro_connect/features/auth/data/auth_repository_impl.dart';
import 'package:astro_connect/features/auth/domain/auth_repository.dart';
import 'package:astro_connect/features/auth/presentation/providers/auth_providers.dart';
import 'package:astro_connect/features/auth/presentation/providers/login_controller.dart';
import 'package:astro_connect/core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

void main() {
  late FakeAuthRepository repo;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repo = FakeAuthRepository();
    container = ProviderContainer.test(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(repo),
    ]);
    container.listen(loginControllerProvider, (_, _) {});
  });

  LoginController ctrl() => container.read(loginControllerProvider.notifier);
  LoginState state() => container.read(loginControllerProvider);

  test('rejects invalid phone numbers without calling the API', () async {
    await ctrl().requestOtp(phone: '12345');
    expect(state().error?.code, 'validation');
    expect(repo.lastPurpose, isNull);
  });

  test('sign up requires a name', () async {
    ctrl().setPurpose(OtpPurpose.signup);
    await ctrl().requestOtp(phone: '9876543210', name: ' ');
    expect(state().error?.message, contains('name'));
  });

  test('OTP flow: send, wrong code, right code signs in', () async {
    ctrl().setPurpose(OtpPurpose.signup);
    await ctrl().requestOtp(phone: '9876543210', name: 'Asha Verma');
    expect(repo.lastPurpose, 'signup');
    expect(state().step, LoginStep.otp);
    expect(state().devOtp, '482913');
    expect(state().resendIn, 30);

    await ctrl().verify('111111');
    expect(state().error?.code, 'otp_invalid');

    await ctrl().verify('482913');
    final user = container.read(authProvider).value;
    expect(user?.name, 'Asha Verma');
    expect(user?.profileComplete, isFalse);
  });

  test('login with an unknown number switches to sign up', () async {
    repo.sendError =
        const AppException('No account', code: 'account_not_found', statusCode: 404);
    await ctrl().requestOtp(phone: '9876543210');
    expect(state().purpose, OtpPurpose.signup);
    expect(state().step, LoginStep.details);
    expect(state().phone, '9876543210');
    expect(state().error?.message, contains('sign up'));
    expect(state().loading, isFalse);
  });

  test('other server errors surface with their code', () async {
    repo.sendError = const AppException('Slow down', code: 'too_many_requests', statusCode: 429);
    await ctrl().requestOtp(phone: '9876543210');
    expect(state().error?.code, 'too_many_requests');
    expect(state().step, LoginStep.details);
    expect(state().loading, isFalse);
  });
}
