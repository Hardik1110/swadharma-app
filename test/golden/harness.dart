import 'package:astro_connect/core/storage/session_storage.dart';
import 'package:astro_connect/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'load_fonts.dart';

/// Renders [home] as a phone-sized PNG in test/golden/out/.
Future<void> snapshot(
  WidgetTester tester,
  String name,
  Widget home, {
  List<Override> overrides = const [],
  Size size = const Size(390, 844),
  Future<void> Function(WidgetTester)? interact,
  Duration settle = const Duration(milliseconds: 600),
}) async {
  await loadAppFonts();
  debugDisableShadows = false;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final container = ProviderContainer.test(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    ...overrides,
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: home,
    ),
  ));
  await tester.pump(settle);
  if (interact != null) await interact(tester);
  await tester.pump(settle);
  try {
    // Only write images when asked (`flutter test --update-goldens`); a plain
    // run just checks that every screen builds and lays out without errors.
    if (autoUpdateGoldenFiles) {
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
    }
  } finally {
    // Flutter's test invariants require this to be restored before teardown.
    debugDisableShadows = true;
  }

  // Tear down timers (resend countdowns, animations) cleanly.
  await tester.pumpWidget(const SizedBox());
  container.dispose();
  await tester.pump(const Duration(milliseconds: 10));
}


/// Pumps [routes] inside a real router (so `context.push` works) and returns
/// the provider container. Call [disposeScreen] at the end of the test.
Future<ProviderContainer> pumpRouted(
  WidgetTester tester,
  List<GoRoute> routes, {
  List<Override> overrides = const [],
  Size size = const Size(390, 844),
}) async {
  await loadAppFonts();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);

  final container = ProviderContainer.test(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    ...overrides,
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: GoRouter(routes: routes),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 600));
  return container;
}

Future<void> disposeScreen(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(const SizedBox());
  container.dispose();
  await tester.pump(const Duration(milliseconds: 10));
}
