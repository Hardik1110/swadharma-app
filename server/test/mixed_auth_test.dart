import 'dart:convert';
import 'dart:io';

import 'package:astro_server/astro_server.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';

import 'test_keys.dart';

const projectId = 'demo-project';

String firebaseToken(String phone) => JWT(
      {
        'phone_number': phone,
        'firebase': {'sign_in_provider': 'phone'},
      },
      subject: 'uid-1',
      audience: Audience([projectId]),
      issuer: 'https://securetoken.google.com/$projectId',
      header: {'kid': 'k1'},
    ).sign(goodKeys.signing,
        algorithm: JWTAlgorithm.RS256, expiresIn: const Duration(hours: 1));

void main() {
  late HttpServer server;
  late ConsultationService consultations;
  late String base;

  Future<void> start({required bool astrologerDemoLogin}) async {
    final store = Store();
    await store.load();
    final hub = Hub();
    consultations = ConsultationService(
        store, hub, const ConsultationConfig(simulatePresence: false));
    final verifier = FirebaseTokenVerifier(
      projectId: projectId,
      fetcher: () async => FirebaseKeys(
        {'k1': goodKeys.verifying},
        DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    server = await io.serve(
        Api(store, hub, consultations,
                firebase: verifier, astrologerDemoLogin: astrologerDemoLogin)
            .handler,
        'localhost',
        0);
    base = 'http://localhost:${server.port}';
  }

  tearDown(() async {
    consultations.dispose();
    await server.close(force: true);
  });

  Future<(int, dynamic)> post(String path, Object body) async {
    final res = await http.post(Uri.parse('$base$path'),
        headers: {'content-type': 'application/json'}, body: jsonEncode(body));
    return (res.statusCode, jsonDecode(res.body));
  }

  group('Firebase for customers, demo code for astrologers (default)', () {
    setUp(() => start(astrologerDemoLogin: true));

    test('config tells the app which login each role uses', () async {
      final cfg = jsonDecode((await http.get(Uri.parse('$base/config'))).body);
      expect(cfg['phoneAuth'], 'firebase');
      expect(cfg['astrologerAuth'], 'demo');
    });

    test('customers cannot use the demo code', () async {
      for (final purpose in ['login', 'signup']) {
        final (s, r) = await post('/auth/send-otp', {'phone': '9876543210', 'purpose': purpose});
        expect(s, 400, reason: purpose);
        expect(r['error']['code'], 'use_firebase');
      }
    });

    test('an astrologer signs in with the on-screen code', () async {
      final (_, otp) = await post('/auth/send-otp', {'phone': '9100000002', 'purpose': 'astrologer'});
      expect(otp['devOtp'], isNotNull);
      final (s, res) = await post('/auth/verify-otp', {'phone': '9100000002', 'otp': otp['devOtp']});
      expect(s, 200);
      expect(res['role'], 'astrologer');
      expect(res['user']['name'], 'Tara Mehta');
    });

    test('"astrologer" is no back door: only registered astrologer numbers qualify', () async {
      final (s, r) = await post('/auth/send-otp', {'phone': '9876543210', 'purpose': 'astrologer'});
      expect(s, 404);
      expect(r['error']['code'], 'astrologer_not_found');
    });

    test('customers still sign up with a Firebase token', () async {
      final (s, r) = await post('/auth/firebase', {
        'idToken': firebaseToken('+919876543210'),
        'purpose': 'signup',
        'name': 'Asha Verma',
      });
      expect(s, 200);
      expect(r['user']['role'] ?? 'user', 'user');
      expect(r['user']['balance'], 100);
    });
  });

  group('Firebase for everyone (ASTROLOGER_LOGIN=firebase)', () {
    setUp(() => start(astrologerDemoLogin: false));

    test('config says astrologers use Firebase too', () async {
      final cfg = jsonDecode((await http.get(Uri.parse('$base/config'))).body);
      expect(cfg['astrologerAuth'], 'firebase');
    });

    test('the demo code is off for astrologers', () async {
      final (s, r) = await post('/auth/send-otp', {'phone': '9100000002', 'purpose': 'astrologer'});
      expect(s, 400);
      expect(r['error']['code'], 'use_firebase');
    });

    test('an astrologer signs in with a Firebase token for their number', () async {
      final (s, res) = await post('/auth/firebase',
          {'idToken': firebaseToken('+919100000002'), 'purpose': 'astrologer'});
      expect(s, 200);
      expect(res['role'], 'astrologer');
      expect(res['user']['astrologerId'], 'a2');
    });

    test('a Firebase-verified customer number cannot claim to be an astrologer', () async {
      final (s, r) = await post('/auth/firebase',
          {'idToken': firebaseToken('+919876543210'), 'purpose': 'astrologer'});
      expect(s, 404);
      expect(r['error']['code'], 'astrologer_not_found');
    });
  });
}
