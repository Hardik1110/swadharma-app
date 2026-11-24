import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/consultation.dart';

enum CallPhase { idle, joining, connected, reconnecting, failed, left }

class CallState extends Equatable {
  const CallState({
    this.phase = CallPhase.idle,
    this.remoteUid,
    this.remoteVideoOn = false,
    this.remoteLeft = false,
    this.micMuted = false,
    this.speakerOn = false,
    this.cameraOn = true,
    this.frontCamera = true,
    this.error,
    this.permissionDenied = false,
  });

  final CallPhase phase;
  final int? remoteUid;
  final bool remoteVideoOn;

  /// The astrologer was in the channel and dropped out.
  final bool remoteLeft;
  final bool micMuted;
  final bool speakerOn;
  final bool cameraOn;
  final bool frontCamera;
  final String? error;
  final bool permissionDenied;

  bool get remoteJoined => remoteUid != null;

  CallState copyWith({
    CallPhase? phase,
    int? Function()? remoteUid,
    bool? remoteVideoOn,
    bool? remoteLeft,
    bool? micMuted,
    bool? speakerOn,
    bool? cameraOn,
    bool? frontCamera,
    String? Function()? error,
    bool? permissionDenied,
  }) =>
      CallState(
        phase: phase ?? this.phase,
        remoteUid: remoteUid != null ? remoteUid() : this.remoteUid,
        remoteVideoOn: remoteVideoOn ?? this.remoteVideoOn,
        remoteLeft: remoteLeft ?? this.remoteLeft,
        micMuted: micMuted ?? this.micMuted,
        speakerOn: speakerOn ?? this.speakerOn,
        cameraOn: cameraOn ?? this.cameraOn,
        frontCamera: frontCamera ?? this.frontCamera,
        error: error != null ? error() : this.error,
        permissionDenied: permissionDenied ?? this.permissionDenied,
      );

  @override
  List<Object?> get props => [
        phase, remoteUid, remoteVideoOn, remoteLeft, micMuted,
        speakerOn, cameraOn, frontCamera, error, permissionDenied,
      ];
}

final callControllerProvider = NotifierProvider.autoDispose
    .family<CallController, CallState, String>(CallController.new);

/// Wraps the Agora RTC engine for one consultation call.
class CallController extends Notifier<CallState> {
  CallController(this.sessionId);

  final String sessionId;

  static const joinTimeout = Duration(seconds: 20);

  RtcEngine? _engine;
  RtcInfo? _rtc;
  Timer? _joinTimer;
  bool _released = false;

  RtcEngine? get engine => _engine;
  String? get channel => _rtc?.channel;

  @override
  CallState build() {
    ref.onDispose(_release);
    return const CallState();
  }

  /// Ensures mic (and camera for video) permissions. Returns false if denied.
  static Future<bool> ensurePermissions({required bool video}) async {
    final perms = [Permission.microphone, if (video) Permission.camera];
    final statuses = await perms.request();
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  Future<void> join(RtcInfo rtc, {required bool video}) async {
    if (state.phase != CallPhase.idle && state.phase != CallPhase.failed) return;
    _rtc = rtc;
    state = CallState(phase: CallPhase.joining, speakerOn: video, cameraOn: video);

    if (!await ensurePermissions(video: video)) {
      _fail(video
          ? 'Camera and microphone access are needed for video calls.'
          : 'Microphone access is needed for voice calls.',
          permissionDenied: true);
      return;
    }

    try {
      final engine = _engine ??= createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(
        appId: rtc.appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));
      engine.registerEventHandler(_handler());
      await engine.enableAudio();
      if (video) {
        await engine.enableVideo();
        await engine.startPreview();
      }
      await engine.setDefaultAudioRouteToSpeakerphone(video);
      await engine.joinChannel(
        token: rtc.token ?? '',
        channelId: rtc.channel,
        uid: 0,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishMicrophoneTrack: true,
          publishCameraTrack: video,
          autoSubscribeAudio: true,
          autoSubscribeVideo: video,
        ),
      );
      _joinTimer = Timer(joinTimeout, () {
        if (state.phase == CallPhase.joining) {
          _fail('Could not connect the call. Check your internet connection.');
        }
      });
    } on AgoraRtcException catch (e) {
      debugPrint('agora join failed: ${e.code} ${e.message}');
      _fail('Could not start the call (error ${e.code}).');
    } catch (e) {
      debugPrint('agora join failed: $e');
      _fail('Could not start the call.');
    }
  }

  RtcEngineEventHandler _handler() => RtcEngineEventHandler(
        onJoinChannelSuccess: (_, _) {
          _joinTimer?.cancel();
          _update((s) => s.copyWith(phase: CallPhase.connected, error: () => null));
        },
        onUserJoined: (_, uid, _) => _update((s) =>
            s.copyWith(remoteUid: () => uid, remoteLeft: false)),
        onUserOffline: (_, uid, _) {
          if (uid != state.remoteUid) return;
          _update((s) => s.copyWith(
              remoteUid: () => null, remoteVideoOn: false, remoteLeft: true));
        },
        onRemoteVideoStateChanged: (_, uid, videoState, _, _) {
          if (uid != state.remoteUid) return;
          final on = videoState == RemoteVideoState.remoteVideoStateDecoding ||
              videoState == RemoteVideoState.remoteVideoStateStarting;
          _update((s) => s.copyWith(remoteVideoOn: on));
        },
        onConnectionStateChanged: (_, connState, reason) {
          switch (connState) {
            case ConnectionStateType.connectionStateReconnecting:
              _update((s) => s.copyWith(phase: CallPhase.reconnecting));
            case ConnectionStateType.connectionStateConnected:
              _update((s) => s.copyWith(phase: CallPhase.connected));
            case ConnectionStateType.connectionStateFailed:
              _fail('The call connection was lost ($reason).');
            default:
              break;
          }
        },
        onError: (err, msg) => debugPrint('agora error $err $msg'),
      );

  Future<void> toggleMic() async {
    final muted = !state.micMuted;
    await _engine?.muteLocalAudioStream(muted);
    _update((s) => s.copyWith(micMuted: muted));
  }

  Future<void> toggleSpeaker() async {
    final on = !state.speakerOn;
    await _engine?.setEnableSpeakerphone(on);
    _update((s) => s.copyWith(speakerOn: on));
  }

  Future<void> toggleCamera() async {
    final on = !state.cameraOn;
    await _engine?.enableLocalVideo(on);
    await _engine?.muteLocalVideoStream(!on);
    _update((s) => s.copyWith(cameraOn: on));
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
    _update((s) => s.copyWith(frontCamera: !s.frontCamera));
  }

  Future<void> leave() async {
    _joinTimer?.cancel();
    try {
      await _engine?.leaveChannel();
    } catch (_) {}
    _update((s) => s.copyWith(phase: CallPhase.left));
  }

  void _fail(String message, {bool permissionDenied = false}) {
    _joinTimer?.cancel();
    _update((s) => s.copyWith(
        phase: CallPhase.failed,
        error: () => message,
        permissionDenied: permissionDenied));
  }

  void _update(CallState Function(CallState) fn) {
    if (ref.mounted) state = fn(state);
  }

  Future<void> _release() async {
    if (_released) return;
    _released = true;
    _joinTimer?.cancel();
    final engine = _engine;
    _engine = null;
    if (engine == null) return;
    try {
      await engine.leaveChannel();
      await engine.release();
    } catch (e) {
      debugPrint('agora release failed: $e');
    }
  }
}
