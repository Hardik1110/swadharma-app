import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:astro_server/astro_server.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

/// A 007-shaped token with a made-up signature: enough for the server to read
/// the channel and expiry, which is all it ever does with it.
String fakeToken({
  String appId = 'appid0123456789abcdef0123456789ab',
  String channel = 'demo-channel',
  String uid = '',
  DateTime? issuedAt,
  Duration lifetime = const Duration(hours: 24),
}) {
  final out = BytesBuilder();
  void u16(int v) => out.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  void u32(int v) => out.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void str(String v) {
    final b = utf8.encode(v);
    u16(b.length);
    out.add(b);
  }

  str(String.fromCharCodes(List.filled(32, 7))); // "signature"
  str(appId);
  u32((issuedAt ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000);
  u32(lifetime.inSeconds);
  u32(12345); // salt
  u16(1); // one service: RTC
  u16(1); // type
  u16(1); // one privilege
  u16(1);
  u32(lifetime.inSeconds);
  str(channel);
  str(uid);
  return '007${base64.encode(ZLibCodec().encode(out.toBytes()))}';
}

void main() {
  group('AgoraTokenInfo', () {
    test('reads the channel, user id and expiry', () {
      final issued = DateTime.now().subtract(const Duration(hours: 1));
      final info = AgoraTokenInfo.parse(fakeToken(issuedAt: issued, channel: 'room-7'))!;
      expect(info.appId, 'appid0123456789abcdef0123456789ab');
      expect(info.channel, 'room-7');
      expect(info.uid, isEmpty);
      expect(info.expiresAt.difference(info.issuedAt), const Duration(hours: 24));
      expect(info.isExpired(), isFalse);
      expect(info.isExpired(issued.add(const Duration(hours: 25))), isTrue);
    });

    test('a token locked to one user id says so', () {
      expect(AgoraTokenInfo.parse(fakeToken(uid: '42'))!.uid, '42');
    });

    test('rejects anything that is not a 007 RTC token', () {
      expect(AgoraTokenInfo.parse(''), isNull);
      expect(AgoraTokenInfo.parse('not a token'), isNull);
      expect(AgoraTokenInfo.parse('006abc'), isNull);
      expect(AgoraTokenInfo.parse('007@@@@'), isNull);
      expect(AgoraTokenInfo.parse('007${base64.encode([1, 2, 3])}'), isNull);
    });
  });

  group('calls with a fixed demo token', () {
    late HttpServer server;
    late ConsultationService consultations;
    late String base;

    Future<void> start(String token) async {
      final store = Store();
      await store.load();
      final hub = Hub();
      consultations = ConsultationService(
        store,
        hub,
        ConsultationConfig(
          agoraAppId: 'appid0123456789abcdef0123456789ab',
          agoraStaticToken: token,
          simulatePresence: false,
        ),
      );
      server = await io.serve(Api(store, hub, consultations).handler, 'localhost', 0);
      base = 'http://localhost:${server.port}';
    }

    tearDown(() async {
      consultations.dispose();
      await server.close(force: true);
    });

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

    Future<String> customer(String phone) async {
      final (_, otp) = await call('POST', '/auth/send-otp', body: {'phone': phone, 'purpose': 'signup'});
      final (_, login) = await call('POST', '/auth/verify-otp',
          body: {'phone': phone, 'otp': otp['devOtp'], 'name': 'Asha Verma'});
      final token = login['token'] as String;
      await call('PUT', '/me', token: token, body: {
        'name': 'Asha Verma',
        'dob': '1995-08-15',
        'birthTime': '06:30',
        'birthPlace': 'Pune',
      });
      return token;
    }

    Future<void> liveConsole(String astrologerId) async {
      final ws = IOWebSocketChannel.connect(
          Uri.parse('ws://localhost:${server.port}/ws?astrologerId=$astrologerId'));
      await ws.ready;
      addTearDown(() => ws.sink.close());
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }

    test('every call uses the token\'s channel and the token itself', () async {
      final token = fakeToken(channel: 'demo-channel');
      await start(token);
      final user = await customer('9000000401');
      await liveConsole('a2');

      final (status, created) = await call('POST', '/sessions',
          token: user, body: {'astrologerId': 'a2', 'type': 'voice'});
      expect(status, 201);
      expect(created['rtc']['channel'], 'demo-channel');
      expect(created['rtc']['token'], token);
      expect(created['rtc']['appId'], 'appid0123456789abcdef0123456789ab');
    });

    test('only one call at a time; chat is unaffected', () async {
      await start(fakeToken());
      final first = await customer('9000000402');
      final second = await customer('9000000403');
      await liveConsole('a2');
      await liveConsole('a4');

      final (s1, _) = await call('POST', '/sessions',
          token: first, body: {'astrologerId': 'a2', 'type': 'voice'});
      expect(s1, 201);

      final (s2, r2) = await call('POST', '/sessions',
          token: second, body: {'astrologerId': 'a4', 'type': 'video'});
      expect(s2, 409);
      expect(r2['error']['code'], 'call_line_busy');
      expect(r2['error']['message'], contains('chat instead'));

      final (s3, _) = await call('POST', '/sessions',
          token: second, body: {'astrologerId': 'a4', 'type': 'chat'});
      expect(s3, 201, reason: 'chat does not use the call line');
    });

    test('the line is free again once the call ends', () async {
      await start(fakeToken());
      final first = await customer('9000000404');
      final second = await customer('9000000405');
      await liveConsole('a2');
      await liveConsole('a4');

      final (_, created) = await call('POST', '/sessions',
          token: first, body: {'astrologerId': 'a2', 'type': 'voice'});
      await call('POST', '/sessions/${created['id']}/cancel', token: first);

      final (s, _) = await call('POST', '/sessions',
          token: second, body: {'astrologerId': 'a4', 'type': 'voice'});
      expect(s, 201);
    });

    test('an expired token fails fast with a clear message', () async {
      await start(fakeToken(issuedAt: DateTime.now().subtract(const Duration(days: 2))));
      final user = await customer('9000000406');
      await liveConsole('a2');

      final (status, res) = await call('POST', '/sessions',
          token: user, body: {'astrologerId': 'a2', 'type': 'voice'});
      expect(status, 503);
      expect(res['error']['code'], 'call_token_expired');
      expect(res['error']['message'], contains('expired'));
    });
  });
}
