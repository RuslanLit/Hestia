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
import 'package:permission_handler/permission_handler.dart';

import 'diagnostic_service.dart';

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
  Timer? _iceConnectionTimer;
  Timer? _iceDisconnectedTimer;
  bool _iceConnected = false;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  // Remote audio renderer — routes incoming audio to the earpiece/speaker
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _rendererInitialized = false;
  bool _videoEnabled = false;
  final ValueNotifier<List<String>> debugEvents = ValueNotifier<List<String>>(
    const [],
  );

  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  bool get isVideoEnabled => _videoEnabled;
  String get connectionState => _connectionState;
  String get iceConnectionState => _iceConnectionState;
  String get lastCallEventSent => _lastCallEventSent;
  String get lastCallEventReceived => _lastCallEventReceived;
  String get lastError => _lastError;
  int get localAudioTrackCount => _localAudioTrackCount;
  int get localVideoTrackCount => _localVideoTrackCount;
  int get remoteAudioTrackCount => _remoteAudioTrackCount;
  int get remoteVideoTrackCount => _remoteVideoTrackCount;

  // Public mute state + toggle so CallScreen doesn't touch _localStream
  bool _muted = false;
  bool get isMuted => _muted;
  String _connectionState = 'not_created';
  String _iceConnectionState = 'not_created';
  String _lastCallEventSent = 'none';
  String _lastCallEventReceived = 'none';
  String _lastError = 'none';
  int _localAudioTrackCount = 0;
  int _localVideoTrackCount = 0;
  int _remoteAudioTrackCount = 0;
  int _remoteVideoTrackCount = 0;

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
  static const _defaultVideoHeight = 480;
  static const _defaultVideoFrameRate = 24;
  static const _defaultVideoMaxBitrateKbps = 700;
  static const _iceConnectionTimeout = Duration(seconds: 25);
  static const _iceDisconnectedGrace = Duration(seconds: 8);

  List<Map<String, dynamic>> _iceServers = List<Map<String, dynamic>>.from(
    _defaultIceServers,
  );
  bool _iceConfigHasTurn = false;
  int _videoWidth = _defaultVideoWidth;
  int _videoHeight = _defaultVideoHeight;
  int _videoFrameRate = _defaultVideoFrameRate;
  int _videoMaxBitrateKbps = _defaultVideoMaxBitrateKbps;

  void setIceServers(List<Map<String, dynamic>> iceServers) {
    final sanitized = iceServers
        .map(_sanitizeIceServer)
        .whereType<Map<String, dynamic>>()
        .toList();
    if (sanitized.isEmpty) {
      _iceServers = List<Map<String, dynamic>>.from(_defaultIceServers);
      _iceConfigHasTurn = false;
      _debug('ICE config fallback: using default STUN servers');
      return;
    }
    _iceServers = sanitized;
    _iceConfigHasTurn = _iceServers.any(_iceServerHasTurn);
    _debug(
      'ICE config loaded servers=${_iceServers.length} hasTurn=$_iceConfigHasTurn',
    );
  }

  void setMediaConfig(Map<String, dynamic> config) {
    final video = config['video'];
    if (video is! Map) {
      return;
    }
    _videoWidth = _boundedInt(video['width'], _defaultVideoWidth, 320, 1280);
    _videoHeight = _boundedInt(video['height'], _defaultVideoHeight, 240, 720);
    _videoFrameRate = _boundedInt(
      video['frameRate'],
      _defaultVideoFrameRate,
      15,
      30,
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
      _sendSignal({
        'type': 'call_offer_init',
        'callId': _activeCallId,
        'toUserId': toUserId,
        'video': video,
      });
      _debug('offer init sent video=$video');
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
      _sendSignal({
        'type': 'call_accepted',
        'callId': _activeCallId,
        'toUserId': _remotePeerId,
        'video': _videoEnabled,
      });
      _debug('call accepted sent video=$_videoEnabled');
    } catch (e) {
      _handleError('Failed to accept call: $e');
    }
  }

  // ── Reject incoming call ──────────────────────────────────────────────────
  void rejectCall() {
    if (_state != CallState.incoming || incomingCall == null) return;
    _sendSignal({
      'type': 'call_rejected',
      'callId': incomingCall!.callId,
      'toUserId': incomingCall!.fromUserId,
    });
    _reset();
  }

  // ── End active call ───────────────────────────────────────────────────────
  void endCall() {
    if (_remotePeerId != null && _activeCallId != null) {
      _sendSignal({
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
    _lastCallEventReceived = _safeCallEvent(msg);
    DiagnosticService.instance.log('call received $_lastCallEventReceived');
    if (kDebugMode) {
      debugPrint('[CallService] handleSignal: $type');
    }

    switch (type) {
      case 'call_offer_init':
        if (_state != CallState.idle) {
          _sendSignal({
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
        _debug('offer received/set');
        await _flushPendingRemoteCandidates();
        final answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);
        _sendSignal({
          'type': 'call_sdp_answer',
          'callId': _activeCallId,
          'toUserId': _remotePeerId,
          'sdp': answer.sdp,
        });
        _debug('answer created/sent');
        break;

      case 'call_sdp_answer':
        if (_pc == null) return;
        await _pc!.setRemoteDescription(
            RTCSessionDescription(msg['sdp'] as String, 'answer'));
        _remoteDescriptionSet = true;
        _debug('answer received/set');
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
    await _closePeerConnection();
    _muted = false;

    // Initialise the renderer once — it routes remote audio to the speaker
    if (!_rendererInitialized) {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      _rendererInitialized = true;
    }

    await _ensureMediaPermissions(video: video);
    await _enableAudioOutput();
    _iceConfigHasTurn = _iceServers.any(_iceServerHasTurn);
    _debug(
      'creating peer connection iceServers=${_iceServers.length} hasTurn=$_iceConfigHasTurn',
    );
    _pc = await createPeerConnection(_iceConfig);
    _connectionState = 'created';
    _iceConnectionState = 'created';
    _iceConnected = false;
    _remoteDescriptionSet = false;
    _pendingRemoteCandidates.clear();
    _startIceConnectionTimer();

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
    final localAudioTracks = _localStream!.getAudioTracks();
    final localVideoTracks = _localStream!.getVideoTracks();
    _localAudioTrackCount = localAudioTracks.length;
    _localVideoTrackCount = localVideoTracks.length;
    for (final track in localAudioTracks) {
      track.enabled = true;
    }
    for (final track in localVideoTracks) {
      track.enabled = true;
    }
    _debug('local stream created');
    _debug('audio tracks count=${localAudioTracks.length}');
    _debug('video tracks count=${localVideoTracks.length}');

    for (final track in _localStream!.getTracks()) {
      await _pc!.addTrack(track, _localStream!);
      _debug('local ${track.kind} track added enabled=${track.enabled}');
    }

    // KEY FIX: receive remote audio and route it to the device speaker.
    // Without this handler Android never plays the incoming audio stream.
    _pc!.onTrack = (RTCTrackEvent event) {
      if (kDebugMode) {
        debugPrint('[CallService] onTrack: ${event.track.kind}');
      }
      event.track.enabled = true;
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
        _debug('remote stream received');
        final remoteAudioTracks = event.streams[0].getAudioTracks();
        final remoteVideoTracks = event.streams[0].getVideoTracks();
        _remoteAudioTrackCount = remoteAudioTracks.length;
        _remoteVideoTrackCount = remoteVideoTracks.length;
        _debug('remote audio tracks count=${remoteAudioTracks.length}');
        _debug('remote video tracks count=${remoteVideoTracks.length}');
        for (final track in remoteAudioTracks) {
          track.enabled = true;
          _debug('remote audio track enabled=${track.enabled}');
        }
      } else if (kDebugMode) {
        debugPrint('[CallService] onTrack without stream');
      }
    };

    _pc!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _sendSignal({
        'type': 'call_ice',
        'callId': _activeCallId,
        'toUserId': _remotePeerId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
      _debug('ICE candidate sent mid=${candidate.sdpMid ?? ''}');
    };

    _pc!.onConnectionState = (s) {
      if (kDebugMode) {
        debugPrint('[CallService] PC state: $s');
      }
      _connectionState = s.name;
      _debug('connectionState=$s');
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _markIceConnected();
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _failActiveCall(_callConnectionFailedMessage());
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _startIceDisconnectedTimer();
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _cancelIceTimers();
      }
    };
    _pc!.onIceConnectionState = (s) {
      _iceConnectionState = s.name;
      _debug('iceConnectionState=$s');
      switch (s) {
        case RTCIceConnectionState.RTCIceConnectionStateChecking:
          _startIceConnectionTimer();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _markIceConnected();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          _startIceDisconnectedTimer();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _failActiveCall(_callConnectionFailedMessage());
          break;
        case RTCIceConnectionState.RTCIceConnectionStateClosed:
          _cancelIceTimers();
          break;
        case RTCIceConnectionState.RTCIceConnectionStateNew:
        case RTCIceConnectionState.RTCIceConnectionStateCount:
          break;
      }
    };
    _pc!.onIceGatheringState = (s) {
      _debug('iceGatheringState=$s');
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
    _sendSignal({
      'type': 'call_sdp_offer',
      'callId': _activeCallId,
      'toUserId': _remotePeerId,
      'sdp': offer.sdp,
    });
    _debug('offer created/sent');
  }

  void _reset() {
    _cancelIceTimers();
    if (_rendererInitialized) {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    }
    unawaited(_closePeerConnection());
    _pendingRemoteCandidates.clear();
    _remoteDescriptionSet = false;
    _connectionState = 'not_created';
    _iceConnectionState = 'not_created';
    _iceConnected = false;
    _localAudioTrackCount = 0;
    _localVideoTrackCount = 0;
    _remoteAudioTrackCount = 0;
    _remoteVideoTrackCount = 0;
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
    _lastError = msg;
    DiagnosticService.instance.log('call error $msg');
    if (kDebugMode) {
      debugPrint('[CallService] ERROR: $msg');
    }
    onError?.call(msg);
    _reset();
  }

  void _failActiveCall(String message) {
    if (_state == CallState.idle || _state == CallState.ended) {
      return;
    }
    _handleError(message);
  }

  String _callConnectionFailedMessage() => _iceConfigHasTurn
      ? 'Call connection failed. Please check network or server TURN configuration.'
      : 'Call connection failed. Network may block peer-to-peer calls.';

  void _startIceConnectionTimer() {
    if (_iceConnected || _state == CallState.idle || _state == CallState.ended) {
      return;
    }
    _iceConnectionTimer?.cancel();
    _iceConnectionTimer = Timer(_iceConnectionTimeout, () {
      if (_iceConnected || _pc == null) {
        return;
      }
      _debug(
        'ICE connection timeout after ${_iceConnectionTimeout.inSeconds}s; TURN server may be required',
      );
      _failActiveCall(_callConnectionFailedMessage());
    });
  }

  void _startIceDisconnectedTimer() {
    if (_state == CallState.idle || _state == CallState.ended) {
      return;
    }
    _iceDisconnectedTimer?.cancel();
    _iceDisconnectedTimer = Timer(_iceDisconnectedGrace, () {
      if (_pc == null) {
        return;
      }
      _debug(
        'ICE disconnected for ${_iceDisconnectedGrace.inSeconds}s; ending call',
      );
      _failActiveCall(_callConnectionFailedMessage());
    });
  }

  void _markIceConnected() {
    _iceConnected = true;
    _iceConnectionTimer?.cancel();
    _iceConnectionTimer = null;
    _iceDisconnectedTimer?.cancel();
    _iceDisconnectedTimer = null;
  }

  void _cancelIceTimers() {
    _iceConnectionTimer?.cancel();
    _iceConnectionTimer = null;
    _iceDisconnectedTimer?.cancel();
    _iceDisconnectedTimer = null;
  }

  String _generateId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(16);

  int _positiveInt(Object? value, int fallback) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return parsed != null && parsed > 0 ? parsed : fallback;
  }

  int _boundedInt(Object? value, int fallback, int min, int max) {
    final parsed = _positiveInt(value, fallback);
    return parsed.clamp(min, max).toInt();
  }

  Future<void> _ensureMediaPermissions({required bool video}) async {
    final microphone = await Permission.microphone.request();
    if (!microphone.isGranted) {
      throw Exception('Microphone permission is required for calls.');
    }
    if (video) {
      final camera = await Permission.camera.request();
      if (!camera.isGranted) {
        throw Exception('Camera permission is required for video calls.');
      }
    }
  }

  Future<void> _enableAudioOutput() async {
    try {
      await Helper.setSpeakerphoneOn(true);
      _debug('speaker output enabled');
    } catch (error) {
      _debug('speaker output unchanged: $error');
    }
  }

  Future<void> _closePeerConnection() async {
    _cancelIceTimers();
    final stream = _localStream;
    _localStream = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
      await stream.dispose();
    }
    final pc = _pc;
    _pc = null;
    if (pc != null) {
      await pc.close();
      await pc.dispose();
    }
  }

  void _debug(String message) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '$stamp $message';
    if (kDebugMode) {
      debugPrint('[CallService] $message');
    }
    DiagnosticService.instance.log('webrtc $message');
    final next = [...debugEvents.value, entry];
    debugEvents.value = next.length > 12 ? next.sublist(next.length - 12) : next;
  }

  void _sendSignal(Map<String, dynamic> message) {
    _lastCallEventSent = _safeCallEvent(message);
    DiagnosticService.instance.log('call sent $_lastCallEventSent');
    sendSignal?.call(message);
  }

  String _safeCallEvent(Map<String, dynamic> message) {
    final type = message['type']?.toString() ?? 'unknown';
    final callId = message['callId']?.toString() ?? '';
    final peer = message['toUserId']?.toString() ??
        message['fromUserId']?.toString() ??
        '';
    return [
      type,
      if (callId.isNotEmpty) 'callId=${_short(callId)}',
      if (peer.isNotEmpty) 'peer=${_short(peer)}',
    ].join(' ');
  }

  String _short(String value) =>
      value.length <= 8 ? value : '${value.substring(0, 8)}...';

  Map<String, dynamic>? _sanitizeIceServer(Map<String, dynamic> server) {
    final urls = server['urls'];
    if (!_validIceUrls(urls)) {
      return null;
    }
    final sanitized = <String, dynamic>{'urls': urls};
    final username = server['username'];
    final credential = server['credential'];
    if (username is String && username.isNotEmpty) {
      sanitized['username'] = username;
    }
    if (credential is String && credential.isNotEmpty) {
      sanitized['credential'] = credential;
    }
    return sanitized;
  }

  bool _validIceUrls(Object? urls) {
    if (urls is String) {
      return _validIceUrl(urls);
    }
    if (urls is List) {
      return urls.isNotEmpty && urls.every((url) => _validIceUrl(url));
    }
    return false;
  }

  bool _validIceUrl(Object? url) {
    if (url is! String || url.trim().isEmpty) {
      return false;
    }
    final lower = url.toLowerCase();
    return lower.startsWith('stun:') ||
        lower.startsWith('turn:') ||
        lower.startsWith('turns:');
  }

  bool _iceServerHasTurn(Map<String, dynamic> server) {
    final urls = server['urls'];
    if (urls is String) {
      return _urlIsTurn(urls);
    }
    if (urls is List) {
      return urls.any(_urlIsTurn);
    }
    return false;
  }

  bool _urlIsTurn(Object? url) {
    if (url is! String) {
      return false;
    }
    final lower = url.toLowerCase();
    return lower.startsWith('turn:') || lower.startsWith('turns:');
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
    _debug('ICE candidate received mid=${candidate.sdpMid}');
    if (!_remoteDescriptionSet) {
      _pendingRemoteCandidates.add(candidate);
      _debug('ICE candidate queued before remoteDescription');
      if (kDebugMode) {
        debugPrint('[CallService] queued ICE candidate before remote SDP');
      }
      return;
    }
    try {
      await _pc!.addCandidate(candidate);
      _debug('ICE candidate added mid=${candidate.sdpMid}');
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[CallService] addIceCandidate failed: $error');
      }
      _debug('ICE candidate add failed: $error');
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
