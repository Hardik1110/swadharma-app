import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() with the initialised instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider'),
);

final sessionStorageProvider =
    Provider((ref) => SessionStorage(ref.watch(sharedPreferencesProvider)));

/// Persists the auth token and the last known user JSON.
class SessionStorage {
  SessionStorage(this._prefs);

  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';
  final SharedPreferences _prefs;

  String? get token => _prefs.getString(_tokenKey);

  Map<String, dynamic>? get userJson {
    final raw = _prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveToken(String token) => _prefs.setString(_tokenKey, token);

  Future<void> saveUserJson(Map<String, dynamic> json) =>
      _prefs.setString(_userKey, jsonEncode(json));

  Future<void> clear() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_userKey);
  }
}
