import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import 'models.dart';

/// Who a verified Firebase ID token belongs to.
class FirebaseIdentity {
  const FirebaseIdentity({required this.uid, required this.phone});

  final String uid;

  /// 10-digit Indian mobile number (without +91).
  final String phone;
}

class FirebaseKeys {
  const FirebaseKeys(this.keys, this.expiresAt);

  /// Signing keys by `kid`.
  final Map<String, JWTKey> keys;
  final DateTime expiresAt;
}

typedef KeyFetcher = Future<FirebaseKeys> Function();

const _certUrl =
    'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';

/// Downloads Google's current Firebase signing certificates.
Future<FirebaseKeys> fetchGoogleKeys() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final res = await (await client.getUrl(Uri.parse(_certUrl))).close();
    if (res.statusCode != 200) {
      throw ApiError(503, 'auth_unavailable', 'Could not load Firebase signing keys');
    }
    final body = await res.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final maxAge = RegExp(r'max-age=(\d+)')
        .firstMatch(res.headers.value('cache-control') ?? '')
        ?.group(1);
    return FirebaseKeys(
      json.map((kid, pem) => MapEntry(kid, RSAPublicKey.cert(pem as String))),
      DateTime.now().add(Duration(seconds: int.tryParse(maxAge ?? '') ?? 3600)),
    );
  } on SocketException {
    throw ApiError(503, 'auth_unavailable', 'Could not reach Firebase to verify login');
  } finally {
    client.close();
  }
}

/// Verifies Firebase Auth ID tokens issued after phone sign-in.
///
/// Checks the RS256 signature against Google's published keys, the issuer,
/// audience (your Firebase project id), expiry and that the sign-in provider
/// is `phone`.
class FirebaseTokenVerifier {
  FirebaseTokenVerifier({required this.projectId, KeyFetcher? fetcher})
      : _fetcher = fetcher ?? fetchGoogleKeys;

  final String projectId;
  final KeyFetcher _fetcher;
  FirebaseKeys? _cache;

  Future<FirebaseIdentity> verify(String idToken) async {
    if (idToken.isEmpty) throw _invalid('Missing login token');

    final JWT decoded;
    try {
      decoded = JWT.decode(idToken);
    } on JWTException {
      throw _invalid('Malformed login token');
    }
    final header = decoded.header ?? const {};
    final kid = header['kid'];
    if (header['alg'] != 'RS256' || kid is! String) {
      throw _invalid('Unsupported login token');
    }

    final key = await _keyFor(kid);
    if (key == null) throw _invalid('Unknown signing key');

    final JWT jwt;
    try {
      jwt = JWT.verify(
        idToken,
        key,
        issuer: 'https://securetoken.google.com/$projectId',
        audience: Audience([projectId]),
      );
    } on JWTExpiredException {
      throw ApiError(401, 'token_expired', 'Login expired. Please try again.');
    } on JWTException {
      throw _invalid('Login could not be verified');
    }

    final payload = jwt.payload as Map<String, dynamic>;
    final uid = payload['sub'];
    final provider = (payload['firebase'] as Map?)?['sign_in_provider'];
    final phoneClaim = payload['phone_number'];
    if (uid is! String || uid.isEmpty || provider != 'phone' || phoneClaim is! String) {
      throw _invalid('Only phone sign-in is supported');
    }
    final match = RegExp(r'^\+91([6-9]\d{9})$').firstMatch(phoneClaim);
    if (match == null) throw _invalid('Only Indian mobile numbers are supported');
    return FirebaseIdentity(uid: uid, phone: match.group(1)!);
  }

  Future<JWTKey?> _keyFor(String kid) async {
    var cache = _cache;
    if (cache == null || DateTime.now().isAfter(cache.expiresAt)) {
      cache = _cache = await _fetcher();
    }
    if (!cache.keys.containsKey(kid)) {
      // Keys rotate: refresh once before giving up.
      cache = _cache = await _fetcher();
    }
    return cache.keys[kid];
  }

  ApiError _invalid(String message) => ApiError(401, 'invalid_token', message);
}
