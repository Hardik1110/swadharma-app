import 'package:astro_connect/features/auth/data/auth_repository_impl.dart';
import 'package:astro_connect/features/auth/presentation/pages/login_page.dart';
import 'package:astro_connect/features/auth/presentation/pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'harness.dart';

void main() {
  final auth = [authRepositoryProvider.overrideWithValue(FakeAuthRepository())];

  testWidgets('splash', (t) => snapshot(t, 'splash', const SplashPage()));

  testWidgets('login', (t) => snapshot(t, 'login', const LoginPage(), overrides: auth));

  testWidgets('signup', (t) => snapshot(t, 'signup', const LoginPage(), overrides: auth,
      interact: (t) async {
        await t.tap(find.text('Sign up'));
        await t.pump(const Duration(milliseconds: 400));
        await t.enterText(find.byKey(const Key('name_field')), 'Hardik Dagli');
        await t.enterText(find.byKey(const Key('phone_field')), '98765');
      }));

  testWidgets('otp', (t) => snapshot(t, 'otp', const LoginPage(), overrides: auth,
      interact: (t) async {
        await t.enterText(find.byKey(const Key('phone_field')), '9876543210');
        await t.tap(find.byKey(const Key('send_otp')));
        await t.pump(const Duration(milliseconds: 800));
        await t.enterText(find.byKey(const Key('otp_field')), '482');
      }));
}
