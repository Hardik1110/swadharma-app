import 'dart:convert';
import 'dart:io';

import 'package:astro_server/astro_server.dart';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

void main() {
  late Directory publicDir;

  setUp(() {
    publicDir = Directory.systemTemp.createTempSync('astro_public');
    File('${publicDir.path}/console.html').writeAsStringSync('<html>console</html>');
    Directory('${publicDir.path}/demo').createSync();
    File('${publicDir.path}/demo/clip.wav').writeAsBytesSync([1, 2, 3]);
  });
  tearDown(() => publicDir.deleteSync(recursive: true));

  Future<(HttpServer, ConsultationService)> start({required bool console}) async {
    final store = Store();
    await store.load();
    final hub = Hub();
    final service = ConsultationService(store, hub, const ConsultationConfig(simulatePresence: false));
    final server = await io.serve(
        Api(store, hub, service, publicDir: publicDir.path, enableConsole: console).handler,
        'localhost',
        0);
    return (server, service);
  }

  test('console enabled: page, API, demo clip and id-only sockets work', () async {
    final (server, service) = await start(console: true);
    addTearDown(() async {
      service.dispose();
      await server.close(force: true);
    });
    final base = 'http://localhost:${server.port}';

    expect((await http.get(Uri.parse('$base/console'))).statusCode, 200);
    expect((await http.get(Uri.parse('$base/console/astrologers'))).statusCode, 200);
    expect((await http.get(Uri.parse('$base/demo/clip.wav'))).statusCode, 200);
    final ws = IOWebSocketChannel.connect(Uri.parse('ws://localhost:${server.port}/ws?astrologerId=a1'));
    await ws.ready;
    await ws.sink.close();
  });

  test('console disabled: all of it is gone, the real API is untouched', () async {
    final (server, service) = await start(console: false);
    addTearDown(() async {
      service.dispose();
      await server.close(force: true);
    });
    final base = 'http://localhost:${server.port}';

    for (final path in ['/console', '/console/astrologers', '/console/sessions/x/accept', '/demo/clip.wav']) {
      final res = await http.get(Uri.parse('$base$path'));
      expect(res.statusCode, 404, reason: path);
    }
    final post = await http.post(Uri.parse('$base/console/sessions/x/accept'));
    expect(post.statusCode, 404);

    // Anyone could otherwise claim to be an astrologer by id.
    await expectLater(
      () async {
        final ws = IOWebSocketChannel.connect(Uri.parse('ws://localhost:${server.port}/ws?astrologerId=a1'));
        await ws.ready;
      }(),
      throwsA(anything),
    );

    // Everything the apps use still works.
    expect(jsonDecode((await http.get(Uri.parse('$base/config'))).body)['phoneAuth'], 'demo');
    expect((await http.get(Uri.parse('$base/health'))).statusCode, 200);
    final bad = await http.get(Uri.parse('$base/astrologers'));
    expect(bad.statusCode, 401, reason: 'real endpoints still require a login');
  });
}
