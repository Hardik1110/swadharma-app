import 'dart:convert';
import 'dart:io';

import 'package:astro_server/astro_server.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';

import 'test_keys.dart';

const projectId = 'astro-test';

String makeToken({
  String phone = '+919876543210',
  String provider = 'phone',
  String? aud,
  String? iss,
  String kid = 'k1',
  Duration expiresIn = const Duration(hours: 1),
  TestKeyPair? signedBy,
}) =>
    JWT(
      {
        'phone_number': phone,
        'firebase': {'sign_in_provider': provider},
      },
      subject: 'firebase-uid-1',
      audience: Audience([aud ?? projectId]),
      issuer: iss ?? 'https://securetoken.google.com/$projectId',
      header: {'kid': kid},
    ).sign((signedBy ?? goodKeys).signing,
        algorithm: JWTAlgorithm.RS256, expiresIn: expiresIn);

FirebaseTokenVerifier verifier({TestKeyPair? trusting}) =>
    FirebaseTokenVerifier(
      projectId: projectId,
      fetcher: () async => FirebaseKeys(
        {'k1': (trusting ?? goodKeys).verifying},
        DateTime.now().add(const Duration(hours: 1)),
      ),
    );

Future<ApiError> rejection(Future<void> Function() fn) async {
  try {
    await fn();
  } on ApiError catch (e) {
    return e;
  }
  fail('expected ApiError');
}

void main() {
  group('FirebaseTokenVerifier', () {
    test('accepts a valid phone token', () async {
      final id = await verifier().verify(makeToken());
      expect(id.phone, '9876543210');
      expect(id.uid, 'firebase-uid-1');
    });

    test('rejects a token signed with a different key', () async {
      final e = await rejection(() =>
          verifier().verify(makeToken(signedBy: otherKeys)));
      expect(e.code, 'invalid_token');
    });

    test('rejects wrong project, issuer and expired tokens', () async {
      expect((await rejection(() => verifier().verify(makeToken(aud: 'someone-else')))).code,
          'invalid_token');
      expect(
          (await rejection(() => verifier()
                  .verify(makeToken(iss: 'https://securetoken.google.com/other'))))
              .code,
          'invalid_token');
      expect(
          (await rejection(() => verifier()
                  .verify(makeToken(expiresIn: const Duration(seconds: -120)))))
              .code,
          'token_expired');
    });

    test('rejects non-phone providers, foreign numbers and garbage', () async {
      expect((await rejection(() => verifier().verify(makeToken(provider: 'google.com')))).code,
          'invalid_token');
      expect((await rejection(() => verifier().verify(makeToken(phone: '+14155550123')))).code,
          'invalid_token');
      expect((await rejection(() => verifier().verify('not.a.jwt'))).code, 'invalid_token');
      expect((await rejection(() => verifier().verify(''))).code, 'invalid_token');
    });

    test('unknown kid is rejected after a refresh', () async {
      var fetches = 0;
      final v = FirebaseTokenVerifier(
        projectId: projectId,
        fetcher: () async {
          fetches++;
          return FirebaseKeys({'k1': goodKeys.verifying},
              DateTime.now().add(const Duration(hours: 1)));
        },
      );
      final e = await rejection(() => v.verify(makeToken(kid: 'rotated')));
      expect(e.code, 'invalid_token');
      expect(fetches, 2); // initial load + one refresh
    });
  });

  group('API in Firebase mode', () {
    late HttpServer server;
    late ConsultationService consultations;
    late String base;

    setUp(() async {
      final store = Store();
      await store.load();
      final hub = Hub();
      consultations = ConsultationService(
          store, hub, const ConsultationConfig(simulatePresence: false));
      server = await io.serve(
          Api(store, hub, consultations, firebase: verifier()).handler, 'localhost', 0);
      base = 'http://localhost:${server.port}';
    });

    tearDown(() async {
      consultations.dispose();
      await server.close(force: true);
    });

    Future<(int, dynamic)> post(String path, Object body) async {
      final res = await http.post(Uri.parse('$base$path'),
          headers: {'content-type': 'application/json'}, body: jsonEncode(body));
      return (res.statusCode, jsonDecode(res.body));
    }

    test('config advertises firebase and demo OTP is disabled', () async {
      final cfg = jsonDecode((await http.get(Uri.parse('$base/config'))).body);
      expect(cfg['phoneAuth'], 'firebase');

      final (s1, r1) = await post('/auth/send-otp', {'phone': '9876543210', 'purpose': 'signup'});
      expect(s1, 400);
      expect(r1['error']['code'], 'use_firebase');
      final (s2, _) = await post('/auth/verify-otp', {'phone': '9876543210', 'otp': '123456'});
      expect(s2, 400);
    });

    test('sign up with a Firebase token, then log in again', () async {
      final (cs, _) = await post('/auth/check-phone', {'phone': '9876543210', 'purpose': 'signup'});
      expect(cs, 200);

      final (ls, lr) = await post('/auth/firebase', {'idToken': makeToken(), 'purpose': 'login'});
      expect(ls, 404);
      expect(lr['error']['code'], 'account_not_found');

      final (ns, nr) = await post('/auth/firebase',
          {'idToken': makeToken(), 'purpose': 'signup', 'name': 'Asha Verma'});
      expect(ns, 200);
      expect(nr['isNewUser'], true);
      expect(nr['user']['phone'], '9876543210');
      expect(nr['token'], isNotEmpty);

      final (ds, dr) = await post('/auth/check-phone', {'phone': '9876543210', 'purpose': 'signup'});
      expect(ds, 409);
      expect(dr['error']['code'], 'account_exists');

      final (ls2, lr2) = await post('/auth/firebase', {'idToken': makeToken(), 'purpose': 'login'});
      expect(ls2, 200);
      expect(lr2['isNewUser'], false);
      expect(lr2['user']['name'], 'Asha Verma');

      final me = await http.get(Uri.parse('$base/me'),
          headers: {'authorization': 'Bearer ${lr2['token']}'});
      expect(me.statusCode, 200);
    });

    test('forged tokens and missing names are rejected', () async {
      final (fs, fr) = await post('/auth/firebase',
          {'idToken': makeToken(signedBy: otherKeys), 'purpose': 'login'});
      expect(fs, 401);
      expect(fr['error']['code'], 'invalid_token');

      final (ns, nr) = await post('/auth/firebase',
          {'idToken': makeToken(), 'purpose': 'signup', 'name': ''});
      expect(ns, 400);
      expect(nr['error']['code'], 'invalid_name');
    });
  });
}
