import 'package:agora_token_service/agora_token_service.dart';

/// Issues Agora RTC join tokens.
///
/// Needed when the Agora project has its **App Certificate** enabled (the
/// "secured" mode): then joining with only an App ID fails with
/// `CAN_NOT_GET_GATEWAY_SERVER ... dynamic use static key`. The certificate
/// stays on the server; clients only ever receive a short-lived token.
class RtcTokenService {
  RtcTokenService({
    required this.appId,
    required this.appCertificate,
    this.lifetime = const Duration(hours: 4),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String appId;
  final String appCertificate;

  /// How long a token stays valid. A consultation is shorter than this.
  final Duration lifetime;
  final DateTime Function() _clock;

  /// A token for [channel] that either participant can use (uid 0 lets the SDK
  /// pick the user id).
  String tokenFor(String channel) => RtcTokenBuilder.build(
        appId: appId,
        appCertificate: appCertificate,
        channelName: channel,
        uid: '', // empty = any uid
        role: RtcRole.publisher,
        expireTimestamp: _clock().add(lifetime).millisecondsSinceEpoch ~/ 1000,
      );
}
