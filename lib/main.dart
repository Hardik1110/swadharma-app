import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/server_settings.dart';
import 'core/network/api_client.dart';
import 'core/storage/session_storage.dart';
import 'features/auth/data/phone_auth_gateway.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  restoreServerUrl(prefs);
  final firebaseReady = await initFirebase();
  runApp(ProviderScope(
    // Riverpod 3 retries failed providers with growing delays and reports
    // "loading" in between. Our screens already show an error with a Retry
    // button, so show it straight away instead.
    retry: (retryCount, error) => null,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      firebaseReadyProvider.overrideWithValue(firebaseReady),
      // Any 401 outside the auth endpoints signs the user out.
      unauthorizedHandlerProvider.overrideWith(
          (ref) => () => ref.read(authProvider.notifier).sessionExpired()),
    ],
    child: const AstroApp(),
  ));
}
