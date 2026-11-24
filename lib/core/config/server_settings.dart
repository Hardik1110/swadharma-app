import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../errors/app_exception.dart';
import '../storage/session_storage.dart';
import 'env.dart';

const _prefKey = 'server_url';

/// Loads an address saved from Server settings. Call once at startup.
void restoreServerUrl(SharedPreferences prefs) => Env.setSavedUrl(prefs.getString(_prefKey));

/// The backend address in use. Changing it rebuilds the API client, and with
/// it every repository.
final serverUrlProvider = NotifierProvider<ServerUrlNotifier, String>(ServerUrlNotifier.new);

class ServerUrlNotifier extends Notifier<String> {
  @override
  String build() => Env.apiBaseUrl;

  /// Validates, saves and applies [input]. Throws [AppException] if it isn't
  /// a usable address.
  Future<void> save(String input) async {
    final url = Env.normalizeServerUrl(input);
    if (url == null) {
      throw const AppException(
          'Enter an address like http://192.168.1.20:8787', code: 'invalid_url');
    }
    await ref.read(sharedPreferencesProvider).setString(_prefKey, url);
    Env.setSavedUrl(url);
    state = url;
  }

  /// Back to the built-in default.
  Future<void> reset() async {
    await ref.read(sharedPreferencesProvider).remove(_prefKey);
    Env.setSavedUrl(null);
    state = Env.apiBaseUrl;
  }
}

/// Result of probing a server address.
class ServerCheck {
  const ServerCheck.ok() : ok = true, message = 'Connected';
  const ServerCheck.failed(this.message) : ok = false;

  final bool ok;
  final String message;
}

/// Asks `GET <url>/health`. Overridable in tests.
final serverCheckProvider = Provider<Future<ServerCheck> Function(String url)>((ref) {
  return (String url) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));
    try {
      final res = await dio.get<dynamic>('$url/health');
      final body = res.data;
      return body is Map && body['ok'] == true
          ? const ServerCheck.ok()
          : const ServerCheck.failed('Something answered, but it is not the Swadharma server');
    } on DioException catch (e) {
      return ServerCheck.failed(e.response != null
          ? 'Something answered (HTTP ${e.response?.statusCode}), but it is not the Swadharma server'
          : 'No answer. Is the server running, and is this device on the same Wi-Fi?');
    } finally {
      dio.close();
    }
  };
});
