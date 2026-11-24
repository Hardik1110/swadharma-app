import 'package:astro_connect/core/storage/session_storage.dart';
import 'package:astro_connect/features/auth/data/auth_repository_impl.dart';
import 'package:astro_connect/features/auth/presentation/pages/login_page.dart';
import 'package:astro_connect/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';

void main() {
  testWidgets('sign up flow reaches OTP and signs in with the demo code', (tester) async {
    // Phone-sized window (the default 800x600 is shorter than the login sheet).
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = FakeAuthRepository();
    final container = ProviderContainer.test(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(repo),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LoginPage()),
    ));

    // Validation
    await tester.tap(find.byKey(const Key('send_otp')));
    await tester.pump();
    expect(find.text('Enter a valid 10-digit mobile number'), findsOneWidget);

    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name_field')), 'Asha Verma');
    await tester.enterText(find.byKey(const Key('phone_field')), '9876543210');
    await tester.tap(find.byKey(const Key('send_otp')));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.text('Verify your number'), findsOneWidget);
    expect(find.textContaining('Demo code 482913'), findsOneWidget);

    await tester.tap(find.textContaining('Demo code'));
    await tester.pump();
    expect(container.read(authProvider).value?.name, 'Asha Verma');

    // Tear down providers (cancels the resend countdown) and flush timers.
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 10));
  });
}
