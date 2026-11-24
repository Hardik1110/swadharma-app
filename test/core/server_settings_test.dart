import 'package:astro_connect/core/config/env.dart';
import 'package:astro_connect/core/config/server_settings.dart';
import 'package:astro_connect/core/errors/app_exception.dart';
import 'package:astro_connect/core/network/api_client.dart';
import 'package:astro_connect/core/storage/session_storage.dart';
import 'package:astro_connect/core/theme/app_theme.dart';
import 'package:astro_connect/features/auth/presentation/widgets/server_settings_sheet.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/load_fonts.dart';

void main() {
  tearDown(() => Env.setSavedUrl(null));

  group('normalizeServerUrl', () {
    test('accepts what people actually type', () {
      expect(Env.normalizeServerUrl('10.0.60.234'), 'http://10.0.60.234:8787',
          reason: 'a bare address means our own port');
      expect(Env.normalizeServerUrl('10.0.60.234:8787'), 'http://10.0.60.234:8787');
      expect(Env.normalizeServerUrl('  http://192.168.1.20:9000/ '), 'http://192.168.1.20:9000');
      expect(Env.normalizeServerUrl('https://api.example.com'), 'https://api.example.com');
      expect(Env.normalizeServerUrl('http://my-mac.local:8787'), 'http://my-mac.local:8787');
    });

    test('rejects things that cannot be a server', () {
      for (final bad in ['', '   ', 'http://', 'ftp://host', 'not a host!', 'http://:8787']) {
        expect(Env.normalizeServerUrl(bad), isNull, reason: '"$bad"');
      }
    });

    test('websocket address follows the same server', () {
      Env.setSavedUrl('http://10.0.60.234:8787');
      expect(Env.webSocketUri('tok').toString(), 'ws://10.0.60.234:8787/ws?token=tok');
      Env.setSavedUrl('https://api.example.com');
      expect(Env.webSocketUri('tok').scheme, 'wss');
    });
  });

  group('serverUrlProvider', () {
    late ProviderContainer container;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer.test(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    });

    test('saving applies at once: the API client talks to the new server', () async {
      final before = container.read(apiClientProvider).baseUrl;
      await container.read(serverUrlProvider.notifier).save('10.0.60.234');

      expect(container.read(serverUrlProvider), 'http://10.0.60.234:8787');
      expect(container.read(apiClientProvider).baseUrl, 'http://10.0.60.234:8787');
      expect(Env.apiBaseUrl, 'http://10.0.60.234:8787');
      expect(before, isNot('http://10.0.60.234:8787'));
    });

    test('is remembered across launches', () async {
      await container.read(serverUrlProvider.notifier).save('10.0.60.234');
      expect(prefs.getString('server_url'), 'http://10.0.60.234:8787');

      Env.setSavedUrl(null); // fresh process
      restoreServerUrl(prefs);
      expect(Env.apiBaseUrl, 'http://10.0.60.234:8787');
    });

    test('rejects an unusable address and keeps the old one', () async {
      final old = container.read(serverUrlProvider);
      await expectLater(container.read(serverUrlProvider.notifier).save('not a host!'),
          throwsA(isA<AppException>().having((e) => e.code, 'code', 'invalid_url')));
      expect(container.read(serverUrlProvider), old);
      expect(prefs.getString('server_url'), isNull);
    });

    test('reset returns to the default', () async {
      await container.read(serverUrlProvider.notifier).save('10.0.60.234');
      await container.read(serverUrlProvider.notifier).reset();
      expect(container.read(serverUrlProvider), Env.defaultBaseUrl);
      expect(prefs.getString('server_url'), isNull);
    });
  });

  test('"can\'t reach" errors name the address that was tried', () {
    final e = AppException.fromDio(DioException(
      requestOptions: RequestOptions(baseUrl: 'http://localhost:8787', path: '/config'),
      type: DioExceptionType.connectionError,
    ));
    expect(e.isNetwork, isTrue);
    expect(e.message, contains('http://localhost:8787'));
    expect(e.message, contains('same network'));
  });

  group('Server settings screen', () {
    Future<(ProviderContainer, SharedPreferences)> open(
      WidgetTester tester, {
      ServerCheck check = const ServerCheck.ok(),
    }) async {
      await loadAppFonts();
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer.test(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        serverCheckProvider.overrideWithValue((url) async => check),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(onPressed: () => showServerSettings(context), child: const Text('open')),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return (container, prefs);
    }

    testWidgets('tests the connection and says it works', (tester) async {
      await open(tester);
      await tester.enterText(find.byKey(const Key('server_url_field')), '10.0.60.234');
      await tester.tap(find.byKey(const Key('server_test')));
      await tester.pumpAndSettle();
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('explains a failed test in plain words', (tester) async {
      await open(tester,
          check: const ServerCheck.failed('No answer. Is the server running, and is this device on the same Wi-Fi?'));
      await tester.enterText(find.byKey(const Key('server_url_field')), '10.0.60.99');
      await tester.tap(find.byKey(const Key('server_test')));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const Key('server_result')), matching: find.textContaining('same Wi-Fi')),
          findsOneWidget);
    });

    testWidgets('saves the address and confirms', (tester) async {
      final (container, prefs) = await open(tester);
      await tester.enterText(find.byKey(const Key('server_url_field')), '10.0.60.234');
      await tester.tap(find.byKey(const Key('server_save')));
      await tester.pumpAndSettle();

      expect(container.read(serverUrlProvider), 'http://10.0.60.234:8787');
      expect(prefs.getString('server_url'), 'http://10.0.60.234:8787');
      expect(find.text('Server set to http://10.0.60.234:8787'), findsOneWidget);
    });

    testWidgets('an invalid address shows an error and is not saved', (tester) async {
      final (_, prefs) = await open(tester);
      await tester.enterText(find.byKey(const Key('server_url_field')), 'not a host!');
      await tester.tap(find.byKey(const Key('server_save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter an address like'), findsOneWidget);
      expect(prefs.getString('server_url'), isNull);
    });
  });
}
