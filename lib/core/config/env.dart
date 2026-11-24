import 'dart:io';

/// Where the app finds the backend.
///
/// Order of precedence: an address saved from the in-app *Server settings*,
/// then `--dart-define=API_BASE_URL=...`, then a default for the platform.
class Env {
  static const _define = String.fromEnvironment('API_BASE_URL');

  /// Set from saved preferences / the Server settings screen.
  static String? _saved;

  static void setSavedUrl(String? url) =>
      _saved = (url == null || url.trim().isEmpty) ? null : url.trim();

  /// Android emulators reach the host machine through 10.0.2.2; everything
  /// else on the same machine uses localhost. A physical phone needs the
  /// computer's address instead (set it in Server settings).
  static String get defaultBaseUrl {
    if (_define.isNotEmpty) return _define;
    return Platform.isAndroid ? 'http://10.0.2.2:8787' : 'http://localhost:8787';
  }

  static String get apiBaseUrl => _saved ?? defaultBaseUrl;

  static Uri webSocketUri(String token) {
    final base = Uri.parse(apiBaseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws',
      queryParameters: {'token': token},
    );
  }

  /// Turns what a person types ("192.168.1.20", "10.0.60.234:8787",
  /// "https://api.example.com") into a base URL, or null if it can't be one.
  static String? normalizeServerUrl(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;
    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(text);
    if (!hasScheme) text = 'http://$text';
    final uri = Uri.tryParse(text);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (!RegExp(r'^[A-Za-z0-9.-]+$').hasMatch(uri.host)) return null;
    // A bare address means our own server's port.
    final port = uri.hasPort ? uri.port : (hasScheme ? null : 8787);
    return Uri(scheme: uri.scheme, host: uri.host, port: port).toString();
  }
}
