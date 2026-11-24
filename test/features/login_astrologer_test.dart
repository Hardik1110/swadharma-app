import 'package:astro_connect/core/errors/app_exception.dart';
import 'package:astro_connect/features/astrologers/domain/astrologer.dart';
import 'package:astro_connect/features/astrologers/presentation/providers/astrologer_providers.dart';
import 'package:astro_connect/features/auth/data/auth_repository_impl.dart';
import 'package:astro_connect/features/auth/presentation/pages/login_page.dart';
import 'package:astro_connect/features/auth/presentation/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../golden/harness.dart';
import '../helpers.dart';

void main() {
  List<Override> overrides(FakeAuthRepository repo,
          {String phoneAuth = 'demo', String? astrologerAuth}) =>
      [
        authRepositoryProvider.overrideWithValue(repo),
        appConfigProvider.overrideWith((ref) async => AppConfig(
            callsEnabled: true,
            expertise: const [],
            phoneAuth: phoneAuth,
            astrologerAuth: astrologerAuth)),
      ];

  List<GoRoute> routes() => [GoRoute(path: '/', builder: (_, _) => const LoginPage())];

  testWidgets('astrologer mode: separate sign-in with demo numbers', (tester) async {
    final repo = FakeAuthRepository();
    final c = await pumpRouted(tester, routes(), overrides: overrides(repo));

    // Customers see Log in / Sign up and a quiet link for astrologers.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('astrologer_login')), findsOneWidget);

    await tester.tap(find.byKey(const Key('astrologer_login')));
    await tester.pumpAndSettle();

    expect(find.text('Astrologer sign in'), findsOneWidget);
    expect(find.text('Sign up'), findsNothing, reason: 'astrologers do not sign up');
    expect(find.byKey(const Key('name_field')), findsNothing);
    expect(find.text('Demo astrologers (tap to fill)'), findsOneWidget);

    // Tapping a demo number fills the field; the OTP request goes out as "astrologer".
    await tester.tap(find.byKey(const Key('demo_9100000001')));
    await tester.pump();
    expect(find.text('9100000001'), findsOneWidget);
    await tester.tap(find.byKey(const Key('send_otp')));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(repo.lastPurpose, 'astrologer');
    expect(find.text('Verify your number'), findsOneWidget);

    // Verifying signs in as an astrologer.
    await tester.tap(find.textContaining('Demo code'));
    await tester.pump();
    final user = c.read(authProvider).value;
    expect(user?.isAstrologer, isTrue);
    expect(user?.name, 'Pt. Raghav Sharma');
    await disposeScreen(tester, c);
  });

  testWidgets('can go back to the customer login', (tester) async {
    final c = await pumpRouted(tester, routes(), overrides: overrides(FakeAuthRepository()));
    await tester.tap(find.byKey(const Key('astrologer_login')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('back_to_customer')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
    await disposeScreen(tester, c);
  });

  testWidgets('real-SMS servers do not advertise demo numbers', (tester) async {
    final c = await pumpRouted(tester, routes(),
        overrides: overrides(FakeAuthRepository(), phoneAuth: 'firebase'));
    await tester.tap(find.byKey(const Key('astrologer_login')));
    await tester.pumpAndSettle();
    expect(find.text('Astrologer sign in'), findsOneWidget);
    expect(find.text('Demo astrologers (tap to fill)'), findsNothing);
    await disposeScreen(tester, c);
  });

  testWidgets('unknown astrologer numbers show the server\'s message', (tester) async {
    final repo = FakeAuthRepository();
    final c = await pumpRouted(tester, routes(), overrides: overrides(repo));
    await tester.tap(find.byKey(const Key('astrologer_login')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('phone_field')), '9876500000');
    repo.sendError = const AppException('No astrologer is registered with this number.',
        code: 'astrologer_not_found', statusCode: 404);
    await tester.tap(find.byKey(const Key('send_otp')));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('No astrologer is registered with this number.'), findsOneWidget);
    expect(find.text('Astrologer sign in'), findsOneWidget, reason: 'stays on the form');
    await disposeScreen(tester, c);
  });

  testWidgets('demo numbers still show when the server config could not be loaded', (tester) async {
    // The failed first request is cached by the provider; the screen must not
    // hide the numbers because of it.
    final c = await pumpRouted(tester, routes(), overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      appConfigProvider.overrideWith((ref) async => throw Exception('server unreachable')),
    ]);
    await tester.tap(find.byKey(const Key('astrologer_login')));
    await tester.pumpAndSettle();
    expect(find.text('Demo astrologers (tap to fill)'), findsOneWidget);
    expect(find.byKey(const Key('demo_9100000002')), findsOneWidget);
    await disposeScreen(tester, c);
  });

  testWidgets('demo numbers sit above the Get OTP button so they are seen', (tester) async {
    final c = await pumpRouted(tester, routes(), overrides: overrides(FakeAuthRepository()));
    await tester.tap(find.byKey(const Key('astrologer_login')));
    await tester.pumpAndSettle();
    final chips = tester.getTopLeft(find.byKey(const Key('demo_9100000001'))).dy;
    final button = tester.getTopLeft(find.byKey(const Key('send_otp'))).dy;
    expect(chips, lessThan(button));
    await disposeScreen(tester, c);
  });

  testWidgets('login screen shows which server it uses and opens Server settings', (tester) async {
    final c = await pumpRouted(tester, routes(), overrides: overrides(FakeAuthRepository()));
    final link = find.byKey(const Key('server_settings'));
    await tester.ensureVisible(link);
    expect(find.textContaining('Server: '), findsOneWidget);

    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Server settings'), findsOneWidget);
    expect(find.byKey(const Key('server_url_field')), findsOneWidget);
    await disposeScreen(tester, c);
  });

  testWidgets('scrolled login content never slides under the status bar', (tester) async {
    // A phone with a 48-point status bar.
    tester.view.padding = const FakeViewPadding(top: 96); // 48 logical at 2x
    addTearDown(tester.view.resetPadding);
    final c = await pumpRouted(tester, routes(), overrides: overrides(FakeAuthRepository()));

    await tester.tap(find.byKey(const Key('astrologer_login')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -700));
    await tester.pumpAndSettle();

    // A solid cover of exactly the status-bar height is drawn over the scrolling
    // form, so nothing shows through behind the clock and battery icons.
    final cover = find.byKey(const Key('status_bar_cover'));
    expect(tester.getSize(cover).height, 48);
    expect(tester.getTopLeft(cover).dy, 0);
    // It is painted last (above the scroll view), not hidden beneath it.
    final stack = tester.widget<Stack>(find.ancestor(of: cover, matching: find.byType(Stack)).first);
    expect(stack.children.last.key, const Key('status_bar_cover'));
    await disposeScreen(tester, c);
  });

  testWidgets('customers on Firebase, astrologers on the demo code: numbers still shown', (tester) async {
    final c = await pumpRouted(tester, routes(),
        overrides: overrides(FakeAuthRepository(), phoneAuth: 'firebase', astrologerAuth: 'demo'));
    await tester.tap(find.byKey(const Key('astrologer_login')));
    await tester.pumpAndSettle();
    expect(find.text('Demo astrologers (tap to fill)'), findsOneWidget);
    await disposeScreen(tester, c);
  });

  testWidgets('astrologers on Firebase: no demo numbers', (tester) async {
    final c = await pumpRouted(tester, routes(),
        overrides: overrides(FakeAuthRepository(), phoneAuth: 'firebase', astrologerAuth: 'firebase'));
    await tester.tap(find.byKey(const Key('astrologer_login')));
    await tester.pumpAndSettle();
    expect(find.text('Demo astrologers (tap to fill)'), findsNothing);
    await disposeScreen(tester, c);
  });
}
