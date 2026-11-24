import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:astro_server/astro_server.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  late Store store;
  late HttpServer server;
  late ConsultationService consultations;
  late String base;

  setUp(() async {
    store = Store();
    await store.load();
    final hub = Hub();
    consultations = ConsultationService(
      store,
      hub,
      const ConsultationConfig(
        agoraAppId: 'test-app',
        botAcceptDelay: Duration(milliseconds: 100),
        botTypingDelay: Duration(milliseconds: 50),
        requestTimeout: Duration(seconds: 10),
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

  Future<(int, dynamic)> call(String method, String path, {Object? body, String? token}) async {
    final req = http.Request(method, Uri.parse('$base$path'));
    if (token != null) req.headers['authorization'] = 'Bearer $token';
    if (body != null) {
      req.headers['content-type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final res = await http.Response.fromStream(await req.send());
    return (res.statusCode, jsonDecode(res.body));
  }

  Future<String> astrologerLogin(String phone) async {
    final (_, otp) = await call('POST', '/auth/send-otp', body: {'phone': phone, 'purpose': 'astrologer'});
    final (status, res) = await call('POST', '/auth/verify-otp', body: {'phone': phone, 'otp': otp['devOtp']});
    expect(status, 200);
    expect(res['role'], 'astrologer');
    return res['token'] as String;
  }

  Future<String> readyUser(String phone) async {
    final (_, otp) = await call('POST', '/auth/send-otp', body: {'phone': phone, 'purpose': 'signup'});
    final (_, res) = await call('POST', '/auth/verify-otp',
        body: {'phone': phone, 'otp': otp['devOtp'], 'name': 'Asha Verma'});
    final token = res['token'] as String;
    await call('PUT', '/me', token: token, body: {
      'name': 'Asha Verma',
      'dob': '1995-08-15',
      'birthTime': '06:30',
      'birthPlace': 'Pune, Maharashtra',
    });
    return token;
  }

  Stream<Map<String, dynamic>> listen(IOWebSocketChannel ws) => ws.stream
      .map((e) => jsonDecode(e as String) as Map<String, dynamic>)
      .asBroadcastStream();

  group('astrologer login', () {
    test('a registered number signs in and comes online', () async {
      expect(store.astrologers['a5']!.status, AstrologerStatus.offline);
      final (_, otp) = await call('POST', '/auth/send-otp', body: {'phone': '9100000005', 'purpose': 'astrologer'});
      final (status, res) = await call('POST', '/auth/verify-otp', body: {'phone': '9100000005', 'otp': otp['devOtp']});
      expect(status, 200);
      expect(res['role'], 'astrologer');
      expect(res['user']['name'], 'Swami Anand Giri');
      expect(res['user']['role'], 'astrologer');
      expect(res['user']['profileComplete'], true);
      expect(store.astrologers['a5']!.status, AstrologerStatus.online);

      final (ms, me) = await call('GET', '/me', token: res['token'] as String);
      expect(ms, 200);
      expect(me['astrologerId'], 'a5');
    });

    test('unknown numbers and consumer numbers are not astrologers', () async {
      final (s1, r1) = await call('POST', '/auth/send-otp', body: {'phone': '9876500000', 'purpose': 'astrologer'});
      expect(s1, 404);
      expect(r1['error']['code'], 'astrologer_not_found');

      await readyUser('9000000201');
      final (s2, _) = await call('POST', '/auth/send-otp', body: {'phone': '9000000201', 'purpose': 'astrologer'});
      expect(s2, 404);
    });

    test('astrologer phone numbers are never exposed to consumers', () async {
      final token = await readyUser('9000000202');
      final (_, list) = await call('GET', '/astrologers', token: token);
      final (_, one) = await call('GET', '/astrologers/a1', token: token);
      expect(jsonEncode(list), isNot(contains('9100000001')));
      expect(jsonEncode(one), isNot(contains('9100000001')));
      expect(one.containsKey('phone'), isFalse);
    });

    test('roles are kept apart', () async {
      final astro = await astrologerLogin('9100000001');
      final user = await readyUser('9000000203');

      final (s1, r1) = await call('GET', '/sessions', token: astro);
      expect(s1, 403);
      expect(r1['error']['code'], 'wrong_role');
      final (s2, r2) = await call('GET', '/astrologer/sessions', token: user);
      expect(s2, 403);
      expect(r2['error']['code'], 'wrong_role');
      final (s3, _) = await call('GET', '/astrologer/me');
      expect(s3, 401);
    });

    test('logout works for astrologers', () async {
      final astro = await astrologerLogin('9100000001');
      final (s, _) = await call('POST', '/auth/logout', token: astro);
      expect(s, 200);
      final (s2, _) = await call('GET', '/astrologer/me', token: astro);
      expect(s2, 401);
    });
  });

  group('astrologer app', () {
    test('profile, stats and availability', () async {
      final astro = await astrologerLogin('9100000002');
      final (_, me) = await call('GET', '/astrologer/me', token: astro);
      expect(me['profile']['name'], 'Tara Mehta');
      expect(me['stats']['totalConsultations'], 0);
      expect(me['stats']['share'], 0.7);

      final (s1, off) = await call('PUT', '/astrologer/status', token: astro, body: {'status': 'offline'});
      expect(s1, 200);
      expect(off['status'], 'offline');

      // Customers can't book someone who is offline.
      final user = await readyUser('9000000204');
      final (s2, r2) = await call('POST', '/sessions',
          token: user, body: {'astrologerId': 'a2', 'type': 'chat'});
      expect(s2, 409);
      expect(r2['error']['code'], 'astrologer_offline');

      final (s3, _) = await call('PUT', '/astrologer/status', token: astro, body: {'status': 'busy'});
      expect(s3, 400);
    });

    test('a full two-sided consultation: no bot, real astrologer', () async {
      final user = await readyUser('9000000205');
      final astro = await astrologerLogin('9100000002'); // Tara Mehta, chat 20/min

      final astroWs = IOWebSocketChannel.connect(Uri.parse('ws://localhost:${server.port}/ws?token=$astro'));
      final userWs = IOWebSocketChannel.connect(Uri.parse('ws://localhost:${server.port}/ws?token=$user'));
      final astroEvents = listen(astroWs);
      final userEvents = listen(userWs);
      await astroWs.ready;
      await userWs.ready;
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // The astrologer app is told about the request live.
      final incoming = astroEvents.firstWhere(
          (e) => e['type'] == 'session.updated' && e['data']['status'] == 'requested');
      final (cs, created) = await call('POST', '/sessions',
          token: user, body: {'astrologerId': 'a2', 'type': 'chat'});
      expect(cs, 201);
      final id = created['id'] as String;
      final pushed = (await incoming.timeout(const Duration(seconds: 2)))['data'];
      expect(pushed['id'], id);
      expect(pushed['user']['birthPlace'], 'Pune, Maharashtra');

      // No bot: the request waits for a person.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      var (_, list) = await call('GET', '/astrologer/sessions', token: astro);
      expect((list as List).single['status'], 'requested');
      expect(list.single['user']['name'], 'Asha Verma');
      expect(list.single['user']['dob'], '1995-08-15');

      // Accept: the first minute is charged to the user.
      final (as_, accepted) = await call('POST', '/astrologer/sessions/$id/accept', token: astro);
      expect(as_, 200);
      expect(accepted['status'], 'ongoing');
      expect(store.userByToken(user)!.balance, 80);

      // Astrologer -> user over WebSocket.
      final toUser = userEvents.firstWhere((e) =>
          e['type'] == 'chat.message' && e['data']['sender'] == 'astrologer');
      astroWs.sink.add(jsonEncode({
        'type': 'chat.send',
        'data': {'sessionId': id, 'text': 'Namaste Asha, tell me about your question.', 'clientId': 'c1'},
      }));
      expect((await toUser.timeout(const Duration(seconds: 2)))['data']['text'], contains('Namaste Asha'));

      // User -> astrologer over REST fallback.
      final toAstro = astroEvents.firstWhere((e) =>
          e['type'] == 'chat.message' && e['data']['sender'] == 'user');
      await call('POST', '/sessions/$id/messages', token: user, body: {'text': 'Will I change jobs?'});
      expect((await toAstro.timeout(const Duration(seconds: 2)))['data']['text'], 'Will I change jobs?');

      // The bot never spoke.
      final (_, msgs) = await call('GET', '/astrologer/sessions/$id/messages', token: astro);
      expect((msgs as List).where((m) => m['text'].toString().contains('Namaste Asha, I am')), isEmpty);

      // Astrologer ends it; earnings show up.
      final (es, ended) = await call('POST', '/astrologer/sessions/$id/end', token: astro);
      expect(es, 200);
      expect(ended['status'], 'completed');
      expect(ended['endReason'], 'astrologer_ended');
      expect(ended['earning'], 14); // 70% of 20

      final (_, me) = await call('GET', '/astrologer/me', token: astro);
      expect(me['stats']['totalConsultations'], 1);
      expect(me['stats']['totalEarnings'], 14);
      expect(me['stats']['todayEarnings'], 14);

      await astroWs.sink.close();
      await userWs.sink.close();
    });

    test('a connected astrologer makes voice and video available', () async {
      final user = await readyUser('9000000206');
      final astro = await astrologerLogin('9100000002');

      // Not connected yet: calls are unavailable.
      final (s0, r0) = await call('POST', '/sessions',
          token: user, body: {'astrologerId': 'a2', 'type': 'voice'});
      expect(s0, 409);
      expect(r0['error']['code'], 'astrologer_not_live');

      final ws = IOWebSocketChannel.connect(Uri.parse('ws://localhost:${server.port}/ws?token=$astro'));
      await ws.ready;
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final (s1, r1) = await call('POST', '/sessions',
          token: user, body: {'astrologerId': 'a2', 'type': 'voice'});
      expect(s1, 201);
      expect(r1['status'], 'requested');
      expect(r1['rtc']['channel'], startsWith('astro_'));

      // The astrologer declines.
      final (s2, r2) = await call('POST', '/astrologer/sessions/${r1['id']}/reject', token: astro);
      expect(s2, 200);
      expect(r2['status'], 'rejected');
      await ws.sink.close();
    });

    test("astrologers can't touch each other's consultations", () async {
      final user = await readyUser('9000000207');
      final a2 = await astrologerLogin('9100000002');
      final a1 = await astrologerLogin('9100000001');
      final ws = IOWebSocketChannel.connect(Uri.parse('ws://localhost:${server.port}/ws?token=$a2'));
      await ws.ready;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final (_, created) = await call('POST', '/sessions',
          token: user, body: {'astrologerId': 'a2', 'type': 'chat'});

      final (s, r) = await call('POST', '/astrologer/sessions/${created['id']}/accept', token: a1);
      expect(s, 404);
      expect(r['error']['code'], 'not_found');
      final (s2, _) = await call('GET', '/astrologer/sessions/${created['id']}/messages', token: a1);
      expect(s2, 404);
      await ws.sink.close();
    });

    test('going offline is blocked during a consultation', () async {
      final user = await readyUser('9000000208');
      final astro = await astrologerLogin('9100000004');
      final (_, created) = await call('POST', '/sessions',
          token: user, body: {'astrologerId': 'a4', 'type': 'chat'});
      await Future<void>.delayed(const Duration(milliseconds: 400)); // bot accepts (no app connected)

      final (_, s) = await call('GET', '/sessions/${created['id']}', token: user);
      expect(s['status'], 'ongoing');
      final (code, res) = await call('PUT', '/astrologer/status', token: astro, body: {'status': 'offline'});
      expect(code, 409);
      expect(res['error']['code'], 'session_active');
    });
  });
}
