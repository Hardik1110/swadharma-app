import 'dart:io';

import 'package:astro_server/astro_server.dart';
import 'package:shelf/shelf_io.dart' as io;

/// Environment:
///   PORT           (default 8787)
///   AGORA_APP_ID   Agora App ID; enables calls
///   AGORA_TOKEN    A temporary Agora token (console "temp token"). All calls then
///                  use that token's channel, one call at a time. For demos.
///   AGORA_APP_CERTIFICATE  Agora App Certificate. Required if the project has
///                  the certificate enabled (secured mode); leave unset for a
///                  testing-mode project (App ID only)
///   DATA_FILE      JSON persistence file (default data/db.json, "" = memory only)
///   DEV_MODE       "false" hides the OTP from API responses
///   PUBLIC_DIR     folder with console.html and demo/ (default: next to bin/)
///   ENABLE_CONSOLE "false" disables the unauthenticated browser console
///   FIREBASE_PROJECT_ID  enables Firebase phone login (real SMS) and turns
///                        the demo OTP off
Future<void> main() async {
  final env = Platform.environment;
  final port = int.tryParse(env['PORT'] ?? '') ?? 8787;
  final dataFile = env['DATA_FILE'] ?? 'data/db.json';
  final scriptDir = File.fromUri(Platform.script).parent.parent.path;

  final store = Store(file: dataFile.isEmpty ? null : File(dataFile));
  await store.load();
  final hub = Hub();
  final config = ConsultationConfig(
    agoraAppId: env['AGORA_APP_ID'] ?? '',
    agoraAppCertificate: env['AGORA_APP_CERTIFICATE'] ?? '',
    agoraStaticToken: (env['AGORA_TOKEN'] ?? '').trim(),
  );
  final consultations = ConsultationService(store, hub, config);
  final projectId = env['FIREBASE_PROJECT_ID'] ?? '';
  final api = Api(store, hub, consultations,
      devMode: env['DEV_MODE'] != 'false',
      publicDir: env['PUBLIC_DIR'] ?? '$scriptDir/public',
      enableConsole: env['ENABLE_CONSOLE'] != 'false',
      firebase:
          projectId.isEmpty ? null : FirebaseTokenVerifier(projectId: projectId));

  final server = await io.serve(api.handler, InternetAddress.anyIPv4, port);
  stdout
    ..writeln('Swadharma server on http://${server.address.host}:${server.port}')
    ..writeln(api.enableConsole
        ? 'Astrologer console: http://localhost:${server.port}/console'
        : 'Astrologer console: disabled')
    ..writeln(projectId.isEmpty
        ? 'Login: demo OTP (set FIREBASE_PROJECT_ID for real SMS)'
        : 'Login: Firebase phone auth, project $projectId')
    ..writeln(config.usesStaticToken
        ? 'Voice/video calls enabled (Agora, fixed demo token)'
        : config.usesTokens
        ? 'Voice/video calls enabled (Agora, signed tokens)'
        : config.callsEnabled
        ? 'Voice/video calls enabled (Agora, App ID only: project must be in testing mode)'
        : 'Voice/video calls DISABLED - set AGORA_APP_ID to enable');

  final staticNote = _describeStaticToken(config, env['AGORA_APP_ID'] ?? '');
  if (staticNote.isNotEmpty) stdout.writeln(staticNote);

  ProcessSignal.sigint.watch().listen((_) async {
    await store.save();
    consultations.dispose();
    await server.close(force: true);
    exit(0);
  });
}

/// Startup summary (and sanity checks) for a static demo token.
String _describeStaticToken(ConsultationConfig config, String appId) {
  if (!config.usesStaticToken) return '';
  final info = config.staticTokenInfo;
  if (info == null) return 'WARNING: AGORA_TOKEN is not a valid Agora 007 RTC token; calls will fail.';
  final problems = [
    if (info.appId != appId) 'it belongs to a different App ID',
    if (info.isExpired()) 'it has EXPIRED',
    if (info.uid.isNotEmpty) 'it is locked to user id "${info.uid}", so two people cannot both join',
  ];
  return 'Calls use the fixed demo channel "${info.channel}" (one call at a time), '
      'token valid until ${info.expiresAt}'
      '${problems.isEmpty ? '' : '\nWARNING: ${problems.join('; ')}'}';
}
