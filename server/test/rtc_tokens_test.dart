import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:astro_server/astro_server.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

/// Plain CRC-32 (same algorithm Agora uses to bind a token to its channel).
int crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final b in bytes) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

void main() {
  const appId = '0123456789abcdef0123456789abcdef';
  const certificate = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';

  group('RtcTokenService', () {
    final service = RtcTokenService(appId: appId, appCertificate: certificate);

    test('token carries the app id and is bound to its channel', () {
      final token = service.tokenFor('astro_abc123');
      expect(token, startsWith('006$appId'));

      // version(3) + appId(32) + base64(content)
      final content = base64.decode(token.substring(3 + 32));
      final data = ByteData.sublistView(Uint8List.fromList(content));
      final sigLen = data.getUint16(0, Endian.little);
      expect(sigLen, 32, reason: 'HMAC-SHA256 signature');
      final crcChannel = data.getUint32(2 + sigLen, Endian.little);
      final crcUid = data.getUint32(2 + sigLen + 4, Endian.little);
      expect(crcChannel, crc32(utf8.encode('astro_abc123')));
      expect(crcUid, crc32(const []), reason: 'empty uid = any user id may join');
    });

    test('different channels and different certificates give different tokens', () {
      final a = service.tokenFor('astro_one');
      final b = service.tokenFor('astro_two');
      expect(a, isNot(b));
      final other = RtcTokenService(appId: appId, appCertificate: 'ffffffffffffffffffffffffffffffff');
      expect(other.tokenFor('astro_one'), isNot(a));
    });

    test('token lifetime follows the clock', () {
      final early = RtcTokenService(
        appId: appId,
        appCertificate: certificate,
        lifetime: const Duration(minutes: 1),
        clock: () => DateTime.utc(2026, 1, 1),
      ).tokenFor('c');
      final late = RtcTokenService(
        appId: appId,
        appCertificate: certificate,
        lifetime: const Duration(minutes: 1),
        clock: () => DateTime.utc(2030, 1, 1),
      ).tokenFor('c');
      expect(early, isNot(late));
    });
  });

  group('sessions carry RTC details', () {
    late HttpServer server;
    late ConsultationService consultations;
    late String base;

    Future<void> start(ConsultationConfig config) async {
      final store = Store();
      await store.load();
      final hub = Hub();
      consultations = ConsultationService(store, hub, config);
      server = await io.serve(Api(store, hub, consultations).handler, 'localhost', 0);
      base = 'http://localhost:${server.port}';
    }

    tearDown(() async {
      consultations.dispose();
      await server.close(force: true);
    });

    Future<Map<String, dynamic>> voiceSession() async {
      Future<(int, dynamic)> call(String m, String p, {Object? body, String? token}) async {
        final req = http.Request(m, Uri.parse('$base$p'));
        if (token != null) req.headers['authorization'] = 'Bearer $token';
        if (body != null) {
          req.headers['content-type'] = 'application/json';
          req.body = jsonEncode(body);
        }
        final res = await http.Response.fromStream(await req.send());
        return (res.statusCode, jsonDecode(res.body));
      }

      final (_, otp) = await call('POST', '/auth/send-otp', body: {'phone': '9000000301', 'purpose': 'signup'});
      final (_, login) = await call('POST', '/auth/verify-otp',
          body: {'phone': '9000000301', 'otp': otp['devOtp'], 'name': 'Asha Verma'});
      final token = login['token'] as String;
      await call('PUT', '/me', token: token, body: {
        'name': 'Asha Verma',
        'dob': '1995-08-15',
        'birthTime': '06:30',
        'birthPlace': 'Pune',
      });
      // A person must be on the console for a call to be offered.
      final console = IOWebSocketChannel.connect(
          Uri.parse('ws://localhost:${server.port}/ws?astrologerId=a2'));
      await console.ready;
      addTearDown(() => console.sink.close());
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final (status, created) = await call('POST', '/sessions',
          token: token, body: {'astrologerId': 'a2', 'type': 'voice'});
      expect(status, 201);
      return created as Map<String, dynamic>;
    }

    test('with an App Certificate: a signed token for that session\'s channel', () async {
      await start(const ConsultationConfig(
        agoraAppId: appId,
        agoraAppCertificate: certificate,
        simulatePresence: false,
      ));
      final rtc = (await voiceSession())['rtc'] as Map<String, dynamic>;
      expect(rtc['appId'], appId);
      expect(rtc['token'], startsWith('006$appId'));
      // The certificate itself is never sent to clients.
      expect(jsonEncode(rtc), isNot(contains(certificate)));
    });

    test('testing-mode project (no certificate): no token', () async {
      await start(const ConsultationConfig(agoraAppId: appId, simulatePresence: false));
      final rtc = (await voiceSession())['rtc'] as Map<String, dynamic>;
      expect(rtc['appId'], appId);
      expect(rtc['token'], isNull);
    });
  });
}
