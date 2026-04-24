// ─────────────────────────────────────────────────────────────────────────────
// CallService — WebRTC signaling + peer connection
//
// Security note:
//   WebRTC encrypts all media automatically using DTLS-SRTP.
//   We do NOT encrypt manually — the standard handles it.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum CallState { idle, calling, incoming, connected, ended }

class IncomingCallInfo {
  final String fromUserId;
  final String fromNickname;
  final String callId;
  final bool video;

  const IncomingCallInfo({
    required this.fromUserId,
    required this.fromNickname,
    required this.callId,
    required this.video,
  });
}

class CallService {
  CallService._();
  static final CallService instance = CallService._();

  void Function(Map<String, dynamic>)? sendSignal;

  CallState _state = CallState.idle;
  CallState get state => _state;

  IncomingCallInfo? incomingCall;
  String? _activeCallId;
  String? _remotePeerId;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  bool _remoteDescriptionSet = false;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  // Remote audio renderer — routes incoming audio to the earpiece/speaker
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _rendererInitialized = false;
  bool _videoEnabled = false;

  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  bool get isVideoEnabled => _videoEnabled;

  // Public mute state + toggle so CallScreen doesn't touch _localStream
  bool _muted = false;
  bool get isMuted => _muted;

  void toggleMute() {
    _muted = !_muted;
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !_muted);
  }

  void Function(CallState)? onStateChange;
  void Function(IncomingCallInfo)? onIncomingCall;
  void Function(String)? onError;

  static const _defaultIceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];
  static const _defaultVideoWidth = 640;
  static const _defaultVideoHeight = 360;
  static const _defaultVideoFrameRate = 24;
  static const _defaultVideoMaxBitrateKbps = 900;

  List<Map<String, dynamic>> _iceServers = List<Map<String, dynamic>>.from(
    _defaultIceServers,
  );
  int _videoWidth = _defaultVideoWidth;
  int _videoHeight = _defaultVideoHeight;
  int _videoFrameRate = _defaultVideoFrameRate;
  int _videoMaxBitrateKbps = _defaultVideoMaxBitrateKbps;

  void setIceServers(List<Map<String, dynamic>> iceServers) {
    if (iceServers.isEmpty) return;
    _iceServers = iceServers;
  }

  void setMediaConfig(Map<String, dynamic> config) {
    final video = config['video'];
    if (video is! Map) {
      return;
    }
    _videoWidth = _positiveInt(video['width'], _defaultVideoWidth);
    _videoHeight = _positiveInt(video['height'], _defaultVideoHeight);
    _videoFrameRate = _positiveInt(
      video['frameRate'],
      _defaultVideoFrameRate,
    );
    _videoMaxBitrateKbps = _positiveInt(
      video['maxBitrateKbps'],
      _defaultVideoMaxBitrateKbps,
    );
  }

  Map<String, dynamic> get _iceConfig => {
        'iceServers': [
          ..._iceServers,
        ],
        'iceTransportPolicy': 'all',
        'sdpSemantics': 'unified-plan',
      };

  // ── Outgoing call ─────────────────────────────────────────────────────────
  Future<void> startCall(String toUserId, String toNickname,
      {bool video = false}) async {
    if (_state != CallState.idle) return;
    _activeCallId = _generateId();
    _remotePeerId = toUserId;
    _videoEnabled = video;
    _setState(CallState.calling);
    try {
      await _initPeerConnection(isOffer: true, video: video);
      sendSignal?.call({
        'type': 'call_offer_init',
        'callId': _activeCallId,
        'toUserId': toUserId,
        'video': video,
      });
    } catch (e) {
      _handleError('Failed to start call: $e');
    }
  }

  // ── Accept incoming call ──────────────────────────────────────────────────
  Future<void> acceptCall() async {
    if (_state != CallState.incoming || incomingCall == null) return;
    _activeCallId = incomingCall!.callId;
    _remotePeerId = incomingCall!.fromUserId;
    _videoEnabled = incomingCall!.video;
    _setState(CallState.connected);
    try {
      await _initPeerConnection(isOffer: false, video: _videoEnabled);
      sendSignal?.call({
        'type': 'call_accepted',
        'callId': _activeCallId,
        'toUserId': _remotePeerId,
        'video': _videoEnabled,
      });
    } catch (e) {
      _handleError('Failed to accept call: $e');
    }
  }

  // ── Reject incoming call ──────────────────────────────────────────────────
  void rejectCall() {
    if (_state != CallState.incoming || incomingCall == null) return;
    sendSignal?.call({
      'type': 'call_rejected',
      'callId': incomingCall!.callId,
      'toUserId': incomingCall!.fromUserId,
    });
    _reset();
  }

  // ── End active call ───────────────────────────────────────────────────────
  void endCall() {
    if (_remotePeerId != null && _activeCallId != null) {
      sendSignal?.call({
        'type': 'call_ended',
        'callId': _activeCallId,
        'toUserId': _remotePeerId,
      });
    }
    _reset();
  }

  // ── Handle signaling messages from WebSocket ──────────────────────────────
  Future<void> handleSignal(Map<String, dynamic> msg) async {
    final type = msg['type'] as String? ?? '';
    if (kDebugMode) {
      debugPrint('[CallService] handleSignal: $type');
    }

    switch (type) {
      case 'call_offer_init':
        if (_state != CallState.idle) {
          sendSignal?.call({
            'type': 'call_rejected',
            'callId': msg['callId'],
            'toUserId': msg['fromUserId'],
          });
          return;
        }
        incomingCall = IncomingCallInfo(
          fromUserId: msg['fromUserId'] as String,
          fromNickname: msg['fromNickname'] as String? ?? '?',
          callId: msg['callId'] as String,
          video: msg['video'] as bool? ?? false,
        );
        _setState(CallState.incoming);
        onIncomingCall?.call(incomingCall!);
        break;

      case 'call_accepted':
        if (_state != CallState.calling) return;
        _setState(CallState.connected);
        await _createAndSendOffer();
        break;

      case 'call_sdp_offer':
        if (_pc == null) return;
        final sdp = msg['sdp'] as String;
        await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
        _remoteDescriptionSet = true;
        await _flushPendingRemoteCandidates();
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        sendSignal?.call({
          'type': 'call_sdp_answer',
          'callId': _activeCallId,
          'toUserId': _remotePeerId,
          'sdp': answer.sdp,
        });
        break;

      case 'call_sdp_answer':
        if (_pc == null) return;
        await _pc!.setRemoteDescription(
            RTCSessionDescription(msg['sdp'] as String, 'answer'));
        _remoteDescriptionSet = true;
        await _flushPendingRemoteCandidates();
        await _applyVideoSenderBitrate();
        break;

      case 'call_ice':
        if (_pc == null) return;
        await _addRemoteCandidate(RTCIceCandidate(
          msg['candidate'] as String,
          msg['sdpMid'] as String? ?? '',
          (msg['sdpMLineIndex'] as num?)?.toInt() ?? 0,
        ));
        break;

      case 'call_rejected':
        onError?.call('Call was rejected');
        _reset();
        break;

      case 'call_ended':
        _reset();
        break;

      case 'call_unavailable':
        onError?.call(msg['message'] as String? ?? 'User is unavailable');
        _reset();
        break;
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────
  Future<void> _initPeerConnection(
      {required bool isOffer, required bool video}) async {
    // Initialise the renderer once — it routes remote audio to the speaker
    if (!_rendererInitialized) {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      _rendererInitialized = true;
    }

    _pc = await createPeerConnection(_iceConfig);
    _remoteDescriptionSet = false;
    _pendingRemoteCandidates.clear();

    // Capture local microphone with noise/echo cancellation
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': _videoWidth, 'max': _videoWidth},
              'height': {'ideal': _videoHeight, 'max': _videoHeight},
              'frameRate': {'ideal': _videoFrameRate, 'max': _videoFrameRate},
            }
          : false,
    });

    _localRenderer.srcObject = _localStream;

    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
    }

    // KEY FIX: receive remote audio and route it to the device speaker.
    // Without this handler Android never plays the incoming audio stream.
    _pc!.onTrack = (RTCTrackEvent event) {
      if (kDebugMode) {
        debugPrint('[CallService] onTrack: ${event.track.kind}');
      }
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
      } else if (kDebugMode) {
        debugPrint('[CallService] onTrack without stream');
      }
    };

    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      sendSignal?.call({
        'type': 'call_ice',
        'callId': _activeCallId,
        'toUserId': _remotePeerId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    _pc!.onConnectionState = (s) {
      if (kDebugMode) {
        debugPrint('[CallService] PC state: $s');
      }
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _reset();
      }
    };
  }

  Future<void> _createAndSendOffer() async {
    if (_pc == null) return;
    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': _videoEnabled,
    });
    await _pc!.setLocalDescription(offer);
    await _applyVideoSenderBitrate();
    sendSignal?.call({
      'type': 'call_sdp_offer',
      'callId': _activeCallId,
      'toUserId': _remotePeerId,
      'sdp': offer.sdp,
    });
  }

  void _reset() {
    if (_rendererInitialized) {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    }
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _localStream = null;
    _pc?.close();
    _pc = null;
    _pendingRemoteCandidates.clear();
    _remoteDescriptionSet = false;
    _activeCallId = null;
    _remotePeerId = null;
    incomingCall = null;
    _muted = false;
    _videoEnabled = false;
    _setState(CallState.idle);
  }

  void _setState(CallState s) {
    _state = s;
    onStateChange?.call(s);
  }

  void _handleError(String msg) {
    if (kDebugMode) {
      debugPrint('[CallService] ERROR: $msg');
    }
    onError?.call(msg);
    _reset();
  }

  String _generateId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(16);

  int _positiveInt(Object? value, int fallback) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : fallback;
  }

  Future<void> _applyVideoSenderBitrate() async {
    if (_pc == null || !_videoEnabled) {
      return;
    }
    for (final sender in await _pc!.getSenders()) {
      if (sender.track?.kind != 'video') {
        continue;
      }
      final parameters = sender.parameters;
      final encodings = parameters.encodings;
      if (encodings == null || encodings.isEmpty) {
        parameters.encodings = [
          RTCRtpEncoding(maxBitrate: _videoMaxBitrateKbps * 1000),
        ];
      } else {
        for (final encoding in encodings) {
          encoding.maxBitrate = _videoMaxBitrateKbps * 1000;
        }
      }
      await sender.setParameters(parameters);
    }
  }

  Future<void> _addRemoteCandidate(RTCIceCandidate candidate) async {
    if (_pc == null) {
      return;
    }
    if (!_remoteDescriptionSet) {
      _pendingRemoteCandidates.add(candidate);
      if (kDebugMode) {
        debugPrint('[CallService] queued ICE candidate before remote SDP');
      }
      return;
    }
    try {
      await _pc!.addCandidate(candidate);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[CallService] addIceCandidate failed: $error');
      }
    }
  }

  Future<void> _flushPendingRemoteCandidates() async {
    if (_pc == null || !_remoteDescriptionSet) {
      return;
    }
    final candidates = List<RTCIceCandidate>.from(_pendingRemoteCandidates);
    _pendingRemoteCandidates.clear();
    for (final candidate in candidates) {
      await _addRemoteCandidate(candidate);
    }
  }
}
