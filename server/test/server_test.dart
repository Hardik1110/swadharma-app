import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:astro_server/astro_server.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  late HttpServer server;
  late ConsultationService consultations;
  late String base;

  setUp(() async {
    final store = Store();
    await store.load();
    final hub = Hub();
    consultations = ConsultationService(
      store,
      hub,
      const ConsultationConfig(
        agoraAppId: 'test-app',
        botAcceptDelay: Duration(milliseconds: 100),
        botTypingDelay: Duration(milliseconds: 50),
        requestTimeout: Duration(seconds: 2),
        disconnectGrace: Duration(milliseconds: 200),
        simulatePresence: false,
      ),
    );
    server = await io.serve(Api(store, hub, consultations).handler, 'localhost', 0);
    base = 'http://localhost:${server.port}';
  });

  tearDown(() async {
    consultations.dispose();
    await server.close(force: true);
  });

  Future<(int, dynamic)> call(String method, String path,
      {Object? body, String? token}) async {
    final req = http.Request(method, Uri.parse('$base$path'));
    if (token != null) req.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final res = await http.Response.fromStream(await req.send());
    return (res.statusCode, jsonDecode(res.body));
  }

  Future<String> signUp(String phone) async {
    final (_, otp) = await call('POST', '/auth/send-otp',
        body: {'phone': phone, 'purpose': 'signup'});
    final (status, res) = await call('POST', '/auth/verify-otp',
        body: {'phone': phone, 'otp': otp['devOtp'], 'name': 'Asha Verma'});
    expect(status, 200);
    return res['token'] as String;
  }

  Future<void> completeProfile(String token) async {
    final (status, _) = await call('PUT', '/me', token: token, body: {
      'name': 'Asha Verma',
      'dob': '1995-08-15',
      'birthTime': '06:30',
      'birthPlace': 'Pune, Maharashtra',
    });
    expect(status, 200);
  }

  test('login requires an existing account, signup rejects duplicates', () async {
    final (s1, r1) = await call('POST', '/auth/send-otp',
        body: {'phone': '9876543210', 'purpose': 'login'});
    expect(s1, 404);
    expect(r1['error']['code'], 'account_not_found');

    await signUp('9876543210');
    final (s2, r2) = await call('POST', '/auth/send-otp',
        body: {'phone': '9876543210', 'purpose': 'signup'});
    expect(s2, 409);
    expect(r2['error']['code'], 'account_exists');
  });

  test('wrong OTP is rejected with attempts left', () async {
    await call('POST', '/auth/send-otp', body: {'phone': '9000000001', 'purpose': 'signup'});
    final (status, res) = await call('POST', '/auth/verify-otp',
        body: {'phone': '9000000001', 'otp': '000000'});
    expect(status, 400);
    expect(res['error']['code'], 'otp_invalid');
  });

  test('astrologer search and filters', () async {
    final token = await signUp('9000000002');
    final (_, all) = await call('GET', '/astrologers', token: token);
    expect((all as List).length, 12);

    final (_, tarot) = await call('GET', '/astrologers?expertise=Tarot', token: token);
    expect((tarot as List).every((a) => (a['expertise'] as List).contains('Tarot')), isTrue);

    final (_, online) = await call('GET', '/astrologers?onlineOnly=true', token: token);
    expect((online as List).every((a) => a['status'] == 'online'), isTrue);

    final (_, byName) = await call('GET', '/astrologers?q=tara', token: token);
    expect((byName as List).single['name'], 'Tara Mehta');
  });

  test('consultation needs a complete profile', () async {
    final token = await signUp('9000000003');
    final (status, res) = await call('POST', '/sessions',
        token: token, body: {'astrologerId': 'a1', 'type': 'chat'});
    expect(status, 400);
    expect(res['error']['code'], 'profile_incomplete');
  });

  test('busy astrologers cannot be booked', () async {
    final token = await signUp('9000000004');
    await completeProfile(token);
    final (status, res) = await call('POST', '/sessions',
        token: token, body: {'astrologerId': 'a3', 'type': 'chat'});
    expect(status, 409);
    expect(res['error']['code'], 'astrologer_busy');
  });

  test('full chat consultation over REST + WebSocket', () async {
    final token = await signUp('9000000005');
    await completeProfile(token);

    final ws = IOWebSocketChannel.connect(
        Uri.parse('ws://localhost:${server.port}/ws?token=$token'));
    final events = ws.stream
        .map((e) => jsonDecode(e as String) as Map<String, dynamic>)
        .asBroadcastStream();

    final (status, created) = await call('POST', '/sessions',
        token: token, body: {'astrologerId': 'a1', 'type': 'chat'});
    expect(status, 201);
    expect(created['status'], 'requested');
    final id = created['id'] as String;

    // Bot accepts, then greets.
    await events.firstWhere((e) =>
        e['type'] == 'session.updated' && e['data']['status'] == 'ongoing');
    final greeting = await events.firstWhere((e) =>
        e['type'] == 'chat.message' && e['data']['sender'] == 'astrologer');
    expect(greeting['data']['text'], contains('Asha'));

    // Second request while active is refused.
    final (dup, _) = await call('POST', '/sessions',
        token: token, body: {'astrologerId': 'a2', 'type': 'chat'});
    expect(dup, 409);

    ws.sink.add(jsonEncode({
      'type': 'chat.send',
      'data': {'sessionId': id, 'text': 'How is my career?', 'clientId': 'c1'},
    }));
    final echo = await events.firstWhere((e) =>
        e['type'] == 'chat.message' && e['data']['clientId'] == 'c1');
    expect(echo['data']['sender'], 'user');
    await events.firstWhere((e) =>
        e['type'] == 'chat.message' &&
        e['data']['sender'] == 'astrologer' &&
        e['data']['id'] != greeting['data']['id']);

    final (_, ended) = await call('POST', '/sessions/$id/end', token: token);
    expect(ended['status'], 'completed');
    expect(ended['endReason'], 'user_ended');
    expect(ended['cost'], greaterThanOrEqualTo(25));

    final (rs, reviewed) = await call('POST', '/sessions/$id/review',
        token: token, body: {'rating': 5, 'comment': 'Great'});
    expect(rs, 200);
    expect(reviewed['rating'], 5);

    final (_, history) = await call('GET', '/sessions', token: token);
    expect((history as List).single['id'], id);
    await ws.sink.close();
  });

  test('calls need a live astrologer; chat does not', () async {
    final token = await signUp('9000000008');
    await completeProfile(token);

    // No console connected for a2: the bot can't take a call.
    for (final type in ['voice', 'video']) {
      final (status, res) = await call('POST', '/sessions',
          token: token, body: {'astrologerId': 'a2', 'type': type});
      expect(status, 409, reason: type);
      expect(res['error']['code'], 'astrologer_not_live');
      expect(res['error']['message'], contains('chat'));
    }

    // Chat is still fine.
    final (cs, chat) = await call('POST', '/sessions',
        token: token, body: {'astrologerId': 'a2', 'type': 'chat'});
    expect(cs, 201);
    await call('POST', '/sessions/${chat['id']}/cancel', token: token);
  });

  test('voice session with a live astrologer carries RTC details; disconnect ends it',
      () async {
    final token = await signUp('9000000006');
    await completeProfile(token);

    // A person is on the console for a2.
    final console = IOWebSocketChannel.connect(
        Uri.parse('ws://localhost:${server.port}/ws?astrologerId=a2'));
    await console.ready;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final ws = IOWebSocketChannel.connect(
        Uri.parse('ws://localhost:${server.port}/ws?token=$token'));
    await ws.ready;

    final (_, created) = await call('POST', '/sessions',
        token: token, body: {'astrologerId': 'a2', 'type': 'voice'});
    expect(created['status'], 'requested');
    expect(created['rtc']['appId'], 'test-app');
    expect(created['rtc']['channel'], 'astro_${created['id']}');

    // The bot must not accept a call on the astrologer's behalf.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final (_, waiting) = await call('GET', '/sessions/${created['id']}', token: token);
    expect(waiting['status'], 'requested');

    final (_, accepted) =
        await call('POST', '/console/sessions/${created['id']}/accept');
    expect(accepted['status'], 'ongoing');

    await ws.sink.close();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final (_, s) = await call('GET', '/sessions/${created['id']}', token: token);
    expect(s['status'], 'completed');
    expect(s['endReason'], 'user_disconnected');
    await console.sink.close();
  });

  test('demo clip is served as a static file when a public dir is configured', () async {
    final dir = Directory.systemTemp.createTempSync('astro_public');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/demo').createSync();
    File('${dir.path}/demo/clip.wav').writeAsBytesSync([82, 73, 70, 70, 1, 2, 3]);

    final store = Store();
    await store.load();
    final hub = Hub();
    final service = ConsultationService(
        store, hub, const ConsultationConfig(simulatePresence: false));
    final srv = await io.serve(
        Api(store, hub, service, publicDir: dir.path).handler, 'localhost', 0);
    addTearDown(() async {
      service.dispose();
      await srv.close(force: true);
    });

    final ok = await http.get(Uri.parse('http://localhost:${srv.port}/demo/clip.wav'));
    expect(ok.statusCode, 200);
    expect(ok.bodyBytes.length, 7);
    final missing = await http.get(Uri.parse('http://localhost:${srv.port}/demo/nope.wav'));
    expect(missing.statusCode, 404);
  });

  test('console can decline a pending request', () async {
    final token = await signUp('9000000007');
    await completeProfile(token);
    // Console connected -> bot does not auto-accept.
    final console = IOWebSocketChannel.connect(
        Uri.parse('ws://localhost:${server.port}/ws?astrologerId=a4'));
    await console.ready;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final (_, created) = await call('POST', '/sessions',
        token: token, body: {'astrologerId': 'a4', 'type': 'chat'});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final (_, still) = await call('GET', '/sessions/${created['id']}', token: token);
    expect(still['status'], 'requested');

    final (_, rejected) =
        await call('POST', '/console/sessions/${created['id']}/reject');
    expect(rejected['status'], 'rejected');
    await console.sink.close();
  });
}
