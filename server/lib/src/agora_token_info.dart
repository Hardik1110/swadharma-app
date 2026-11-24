import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// What an Agora "007" RTC token says about itself. Read-only: the signature
/// is never touched, and no secret is needed to read these fields.
class AgoraTokenInfo {
  const AgoraTokenInfo({
    required this.appId,
    required this.issuedAt,
    required this.expiresAt,
    required this.channel,
    required this.uid,
  });

  final String appId;
  final DateTime issuedAt;
  final DateTime expiresAt;

  /// The only channel the token can join.
  final String channel;

  /// Empty means any user id may use it (needed so two people can join).
  final String uid;

  bool isExpired([DateTime? now]) => !(now ?? DateTime.now()).isBefore(expiresAt);

  /// Reads a token such as the one from the Agora console's "temp token"
  /// generator. Returns null if it isn't a well-formed 007 RTC token.
  static AgoraTokenInfo? parse(String token) {
    try {
      if (!token.startsWith('007')) return null;
      final raw = Uint8List.fromList(ZLibCodec().decode(base64.decode(token.substring(3))));
      final data = ByteData.sublistView(raw);
      var o = 0;
      int u16() {
        final v = data.getUint16(o, Endian.little);
        o += 2;
        return v;
      }

      int u32() {
        final v = data.getUint32(o, Endian.little);
        o += 4;
        return v;
      }

      String str() {
        final n = u16();
        final v = utf8.decode(raw.sublist(o, o + n));
        o += n;
        return v;
      }

      final signatureLength = u16();
      o += signatureLength; // skip the signature
      final appId = str();
      final issued = u32();
      final expire = u32();
      u32(); // salt
      final services = u16();
      String? channel;
      String? uid;
      for (var i = 0; i < services; i++) {
        final type = u16();
        final privileges = u16();
        o += privileges * 6; // (uint16 key + uint32 value) each
        if (type == 1) {
          channel = str();
          uid = str();
        }
      }
      if (channel == null || uid == null) return null;
      final issuedAt = DateTime.fromMillisecondsSinceEpoch(issued * 1000);
      return AgoraTokenInfo(
        appId: appId,
        issuedAt: issuedAt,
        expiresAt: issuedAt.add(Duration(seconds: expire)),
        channel: channel,
        uid: uid,
      );
    } catch (_) {
      return null;
    }
  }
}
