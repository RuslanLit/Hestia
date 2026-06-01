// ─────────────────────────────────────────────────────────────────────────────
// CallService — WebRTC signaling + peer connection
//
// Security note:
//   WebRTC encrypts all media automatically using DTLS-SRTP.
//   We do NOT encrypt manually — the standard handles it.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';
import 'diagnostic_service.dart';
import 'platform_capabilities.dart';
import 'push_service.dart';

enum CallState {
  idle,
  calling,
  ringing,
  incoming,
  connecting,
  active,
  connected,
  ended,
  failed,
}

enum IncomingCallDisposition {
  ringing,
  accepting,
  connecting,
  active,
  declined,
  cancelled,
  missed,
  ended,
}

class IncomingCallInfo {
  final String fromUserId;
  final String fromNickname;
  final String callId;
  final bool video;
  final int callCreatedAtMs;
  final int offerReceivedAtMs;
  final int callOfferTtlMs;

  const IncomingCallInfo({
    required this.fromUserId,
    required this.fromNickname,
    required this.callId,
    required this.video,
    required this.callCreatedAtMs,
    required this.offerReceivedAtMs,
    this.callOfferTtlMs = CallService.callOfferTtlMs,
  });

  int get ageMs => DateTime.now().millisecondsSinceEpoch - offerReceivedAtMs;
  bool get isExpired => ageMs > callOfferTtlMs;
}

class CallHistoryEvent {
  final String callId;
  final String peerUserId;
  final String peerNickname;
  final CallDirection direction;
  final CallStatus status;
  final bool isVideo;
  final int timestampMs;
  final int? durationSeconds;

  const CallHistoryEvent({
    required this.callId,
    required this.peerUserId,
    required this.peerNickname,
    required this.direction,
    required this.status,
    required this.isVideo,
    required this.timestampMs,
    this.durationSeconds,
  });
}

class CallService {
  CallService._();
  static final CallService instance = CallService._();

  void Function(Map<String, dynamic>)? sendSignal;
  Future<void> Function()? refreshBackendIceConfig;

  CallState _state = CallState.idle;
  CallState get state => _state;

  IncomingCallInfo? incomingCall;
  String? _activeCallId;
  String? _remotePeerId;
  String? _remotePeerNickname;
  CallDirection? _activeCallDirection;
  int? _activeCallTimestampMs;
  int? _connectedAtMs;
  String _appLifecycleState = 'unknown';
  String _routeDialogState = 'unknown';

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  final Set<String> _finishedCallIds = <String>{};
  final Set<String> _pendingIncomingCallIds = <String>{};
  final Set<String> _handledIncomingCallIds = <String>{};
  final Set<String> _missedIncomingCallIds = <String>{};
  final Map<String, IncomingCallDisposition> _incomingCallStates =
      <String, IncomingCallDisposition>{};
  bool _remoteDescriptionSet = false;
  bool _acceptedSignalHandled = false;
  bool _localOfferInProgress = false;
  bool _localOfferSent = false;
  bool _remoteAnswerApplied = false;
  int _callGeneration = 0;
  bool _callTerminating = false;
  Future<void>? _cleanupFuture;
  String? _desktopPendingOfferCallId;
  String? _desktopPendingOfferSdp;
  Completer<String>? _desktopOfferCompleter;
  final Set<String> _disposedStreamIds = <String>{};
  Timer? _iceConnectionTimer;
  Timer? _iceDisconnectedTimer;
  Timer? _callAnswerTimer;
  Timer? _incomingOfferTimer;
  Timer? _playbackStatsTimer;
  int? _lastInboundAudioBytes;
  int? _lastOutboundAudioBytes;
  int? _lastInboundVideoBytes;
  DateTime? _outboundAudioZeroSince;
  bool _outboundAudioZeroWarningLogged = false;
  bool _iceConnected = false;
  bool _firstLocalIceCandidateLogged = false;
  bool _firstRemoteIceCandidateLogged = false;
  bool _desktopIncomingMicActivationAfterIceScheduled = false;
  bool _desktopIncomingAnswerSent = false;
  bool _turnWarningShownForCall = false;
  bool _browserAudioUnlockRecommended = false;
  DateTime? _webInboundAudioZeroSince;
  bool _webInboundAudioHintLogged = false;

  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  // Remote audio renderer — routes incoming audio to the earpiece/speaker
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _rendererInitialized = false;
  bool _localRendererDisposed = false;
  bool _remoteRendererDisposed = false;
  bool _remoteRendererViewMounted = false;
  bool _remoteRendererViewVisible = false;
  bool _videoEnabled = false;
  bool _receiveVideoOnly = false;
  Future<void>? _remotePlaybackAttachFuture;
  MediaStream? _remotePlaybackAttachLatestStream;
  String? _remotePlaybackAttachCallId;
  String? _remotePlaybackAttachStreamId;
  String? _remotePlaybackAttachedCallId;
  String? _remotePlaybackAttachedStreamId;
  bool _remoteVideoRendererAttachedLogged = false;
  int _remoteVideoViewRevisionMs = 0;
  int _inboundVideoFramesDecoded = 0;
  int _inboundVideoFramesReceived = 0;
  int _inboundVideoFrameWidth = 0;
  int _inboundVideoFrameHeight = 0;
  final ValueNotifier<List<String>> debugEvents = ValueNotifier<List<String>>(
    const [],
  );

  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  bool get isVideoEnabled => _videoEnabled || _receiveVideoOnly;
  bool get showLocalVideoPreview => _videoEnabled && !_receiveVideoOnly;
  String get connectionState => _connectionState;
  String get iceConnectionState => _iceConnectionState;
  String get lastCallEventSent => _lastCallEventSent;
  String get lastCallEventReceived => _lastCallEventReceived;
  String get lastError => _lastError;
  String get currentCallId => _activeCallId ?? incomingCall?.callId ?? '';
  bool get isAlreadyInCall => _state != CallState.idle;
  bool get isCleanupInProgress => _cleanupFuture != null;
  bool get isOutgoingCall => _activeCallDirection == CallDirection.outgoing;
  bool get _isDesktopReceiveVideoOnlyActive =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.fuchsia &&
      _receiveVideoOnly;
  bool get _supportsWebForegroundVideoCalls =>
      kIsWeb &&
      defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS;
  bool get _supportsRealVideoCalls =>
      _supportsWebForegroundVideoCalls ||
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);
  bool get _supportsIncomingVideoReceiveOnly =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia;
  String get appLifecycleState => _appLifecycleState;
  String get routeDialogState => _routeDialogState;

  bool get isAppForegroundForCallUi =>
      _appLifecycleState == 'resumed' || _appLifecycleState == 'inactive';

  IncomingCallDisposition? incomingDispositionFor(String callId) =>
      _incomingCallStates[callId];

  bool canShowIncomingCallNotification(String callId,
      {required String source}) {
    final state = _incomingCallStates[callId];
    _debug(
        'show call notification requested callId=${_short(callId)} source=$source');
    if (isAppForegroundForCallUi) {
      _debug(
          'show call notification suppressed callId=${_short(callId)} reason=foreground_app');
      return false;
    }
    if (state == IncomingCallDisposition.accepting ||
        state == IncomingCallDisposition.connecting ||
        state == IncomingCallDisposition.active) {
      _debug(
          'show call notification suppressed callId=${_short(callId)} reason=already_accepting_or_active');
      return false;
    }
    return state == null || state == IncomingCallDisposition.ringing;
  }

  void markIncomingCallState(
    String callId,
    IncomingCallDisposition state, {
    required String source,
  }) {
    if (callId.isEmpty) {
      return;
    }
    final old = _incomingCallStates[callId];
    if (old == state) {
      return;
    }
    _incomingCallStates[callId] = state;
    _debug(
      'call state transition callId=${_short(callId)} old=${old?.name ?? 'absent'} new=${state.name} source=$source',
    );
    unawaited(FirebasePushService.instance.updateAndroidCallState(
      callId,
      state.name,
      source: source,
    ));
  }

  int get localAudioTrackCount => _localAudioTrackCount;
  int get localVideoTrackCount => _localVideoTrackCount;
  int get remoteAudioTrackCount => _remoteAudioTrackCount;
  int get remoteVideoTrackCount => _remoteVideoTrackCount;
  int get remoteRendererTextureId => _remoteRenderer.textureId ?? -1;
  String get remoteStreamId => _remoteStream?.id ?? '';
  int get remoteVideoViewRevisionMs => _remoteVideoViewRevisionMs;
  int get inboundVideoFramesDecoded => _inboundVideoFramesDecoded;
  int get inboundVideoFrameWidth => _inboundVideoFrameWidth;
  int get inboundVideoFrameHeight => _inboundVideoFrameHeight;
  bool get remoteRendererHasSrcObject {
    try {
      return !_remoteRendererDisposed && _remoteRenderer.srcObject != null;
    } catch (_) {
      return false;
    }
  }

  // Public mute state + toggle so CallScreen doesn't touch _localStream
  bool _muted = false;
  bool get isMuted => _muted;
  bool _cameraEnabled = true;
  bool get isCameraEnabled => _cameraEnabled;
  String _connectionState = 'not_created';
  String _iceConnectionState = 'not_created';
  String _lastCallEventSent = 'none';
  String _lastCallEventReceived = 'none';
  String _lastError = 'none';
  int _localAudioTrackCount = 0;
  int _localVideoTrackCount = 0;
  int _remoteAudioTrackCount = 0;
  int _remoteVideoTrackCount = 0;
  bool get browserAudioUnlockRecommended => _browserAudioUnlockRecommended;

  void _webVoice(String message) {
    if (kIsWeb) {
      debugPrint('[WebVoice] $message');
    }
  }

  void _webVideo(String message) {
    if (kIsWeb) {
      debugPrint('[WebVideo] $message');
    }
  }

  void _callStopFix(String message) {
    if (kIsWeb) {
      debugPrint('[CallStopFix] $message');
    }
  }

  void _safeReportCallError(String message) {
    try {
      onError?.call(message);
    } catch (error, stack) {
      _callStopFix('error callback failed error=$error');
      DiagnosticService.instance.log(
        'call error callback failed message=$message error=$error '
        'stack=${_firstStackLine(stack)}',
      );
    }
  }

  String _iceServerSchemeSummary() {
    final schemes = <String>{};
    for (final server in _iceServers) {
      final urls = server['urls'];
      final values =
          urls is List ? urls.whereType<String>() : [if (urls is String) urls];
      for (final url in values) {
        final separator = url.indexOf(':');
        if (separator > 0) {
          schemes.add(url.substring(0, separator).toLowerCase());
        }
      }
    }
    final ordered = ['stun', 'turn', 'turns']
        .where(schemes.contains)
        .followedBy(schemes.where((scheme) =>
            scheme != 'stun' && scheme != 'turn' && scheme != 'turns'))
        .toList();
    return ordered.isEmpty ? 'none' : ordered.join(',');
  }

  int _iceServerSchemeEntryCount(bool Function(String scheme) matches) {
    var count = 0;
    for (final server in _iceServers) {
      final urls = server['urls'];
      final values =
          urls is List ? urls.whereType<String>() : [if (urls is String) urls];
      final serverSchemes = <String>{};
      for (final url in values) {
        final separator = url.indexOf(':');
        if (separator > 0) {
          serverSchemes.add(url.substring(0, separator).toLowerCase());
        }
      }
      if (serverSchemes.any(matches)) {
        count += 1;
      }
    }
    return count;
  }

  void _resetWebVoiceCallDiagnostics() {
    _turnWarningShownForCall = false;
    _browserAudioUnlockRecommended = false;
    _webInboundAudioZeroSince = null;
    _webInboundAudioHintLogged = false;
  }

  void _recommendBrowserAudioUnlock(String reason) {
    if (!kIsWeb || _browserAudioUnlockRecommended) {
      return;
    }
    _browserAudioUnlockRecommended = true;
    _webVoice('browser audio unlock recommended reason=$reason');
    _notifyMediaListeners();
  }

  Future<void> requestBrowserAudioUnlock() async {
    if (!kIsWeb) {
      return;
    }
    _webVoice('browser audio unlock requested');
    try {
      await _ensureRenderersReady('browser audio unlock');
      final stream = _remoteStream;
      if (stream != null) {
        await _remoteRenderer.setSrcObject(stream: stream);
      }
      await _remoteRenderer.setVolume(1.0);
      _browserAudioUnlockRecommended = false;
      _webInboundAudioZeroSince = null;
      _webInboundAudioHintLogged = false;
      _notifyMediaListeners();
      _webVoice('browser audio unlock success');
      unawaited(_logPlaybackStats());
    } catch (error) {
      _webVoice('browser audio unlock failure error=$error');
      _safeReportCallError(
          'Could not enable browser audio. Check tab audio permissions.');
    }
  }

  void reportRemoteRendererView({
    required bool mounted,
    required bool visible,
    required String reason,
  }) {
    if (_remoteRendererViewMounted == mounted &&
        _remoteRendererViewVisible == visible) {
      return;
    }
    _remoteRendererViewMounted = mounted;
    _remoteRendererViewVisible = visible;
    _trace(
      'remoteRendererView mounted=$mounted visible=$visible reason=$reason '
      '${_rendererStateSummary()}',
    );
  }

  void toggleMute() {
    _muted = !_muted;
    final enabled = !_muted;
    final localTracks = _localStream?.getAudioTracks() ?? const [];
    for (final track in localTracks) {
      final before = track.enabled;
      track.enabled = enabled;
      _debug(
        'local audio track enabled before/after toggle $before->$enabled '
        'id=${_short(track.id ?? '')}',
      );
    }
    _outboundAudioZeroSince = null;
    _outboundAudioZeroWarningLogged = false;
    _trace(
      'mute toggled muted=$_muted localAudioTracks=${localTracks.length}',
    );
    unawaited(_applyMuteToAudioSenders(enabled));
  }

  void toggleCamera() {
    if (!_videoEnabled || _localStream == null) {
      return;
    }
    _cameraEnabled = !_cameraEnabled;
    final enabled = _cameraEnabled;
    final localTracks = _localStream?.getVideoTracks() ?? const [];
    for (final track in localTracks) {
      final before = track.enabled;
      track.enabled = enabled;
      _debug(
        'local video track enabled before/after toggle $before->$enabled '
        'id=${_short(track.id ?? '')}',
      );
    }
    _webVideo(enabled ? 'camera enabled' : 'camera disabled');
    _notifyMediaListeners();
  }

  Future<void> _applyMuteToAudioSenders(bool enabled) async {
    final pc = _pc;
    if (pc == null) {
      _trace('audio sender enabled update skipped reason=no_peer_connection');
      return;
    }
    try {
      final senders = await pc.getSenders();
      final audioSenders =
          senders.where((sender) => sender.track?.kind == 'audio').toList();
      _trace('mute toggle audio sender count=${audioSenders.length}');
      for (final sender in audioSenders) {
        final track = sender.track;
        if (track == null) {
          continue;
        }
        final before = track.enabled;
        track.enabled = enabled;
        _debug(
          'audio sender track enabled before/after toggle $before->$enabled '
          'id=${_short(track.id ?? '')}',
        );
      }
    } catch (error) {
      _trace('audio sender enabled update failed: $error');
    }
  }

  void Function(CallState)? onStateChange;
  final List<void Function(CallState)> _stateListeners = [];
  final List<void Function()> _mediaListeners = [];
  void Function(IncomingCallInfo)? onIncomingCall;
  void Function(IncomingCallInfo, String reason)? onMissedCall;
  void Function(CallHistoryEvent event)? onCallHistoryEvent;
  void Function(String)? onError;
  static const callOfferTtlMs = 45000;

  static const _defaultIceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];
  static const _defaultVideoWidth = 640;
  static const _defaultVideoHeight = 360;
  static const _defaultVideoFrameRate = 24;
  static const _defaultVideoMaxBitrateKbps = 800;
  static const _minVideoMaxBitrateKbps = 800;
  static const _maxVideoMaxBitrateKbps = 900;
  static const _iceConnectionTimeout = Duration(seconds: 25);
  static const _iceDisconnectedGrace = Duration(seconds: 8);
  static const _callAnswerTimeout = Duration(seconds: 45);
  static const _desktopWebRtcStepTimeout = Duration(seconds: 12);
  static const _desktopCleanupStepTimeout = Duration(milliseconds: 800);

  void addStateListener(void Function(CallState) listener) {
    _stateListeners.add(listener);
  }

  void removeStateListener(void Function(CallState) listener) {
    _stateListeners.remove(listener);
  }

  void addMediaListener(void Function() listener) {
    _mediaListeners.add(listener);
  }

  void removeMediaListener(void Function() listener) {
    _mediaListeners.remove(listener);
  }

  List<Map<String, dynamic>> _iceServers = List<Map<String, dynamic>>.from(
    _defaultIceServers,
  );
  bool _iceConfigHasTurn = false;
  String _iceConfigSource = 'default';
  int _videoWidth = _defaultVideoWidth;
  int _videoHeight = _defaultVideoHeight;
  int _videoFrameRate = _defaultVideoFrameRate;
  int _videoMaxBitrateKbps = _defaultVideoMaxBitrateKbps;

  Future<bool> isVideoCallAvailableOnThisDevice() async {
    if (_supportsWebForegroundVideoCalls) {
      return true;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return true;
    }
    return false;
  }

  Future<String> runDesktopAudioEnumerationDiagnostic() async {
    final lines = <String>[
      'Desktop microphone diagnostic',
      'startedAt: ${DateTime.now().toIso8601String()}',
      'platform: $defaultTargetPlatform',
    ];
    if (!PlatformCapabilities.supportsIoFilePaths) {
      lines.add('skipped: browser platform');
      return lines.join('\n');
    }
    lines.addAll([
      'operatingSystem: ${Platform.operatingSystem}',
      'operatingSystemVersion: ${Platform.operatingSystemVersion}',
      'flutter_webrtc: 1.4.1',
    ]);

    void add(String message) {
      lines.add(message);
      _debug('desktop audio diagnostic $message');
    }

    if (defaultTargetPlatform != TargetPlatform.fuchsia) {
      add('skipped: not Desktop');
      return lines.join('\n');
    }

    add('runningElevatedAdmin: ${await _isRunningElevatedAdmin()}');
    await _logDesktopAudioDevices('before permission request', add);

    add('microphone permission request start');
    try {
      final microphone = await Permission.microphone.request();
      add(
        'microphone permission result granted=${microphone.isGranted} '
        'denied=${microphone.isDenied} permanentlyDenied=${microphone.isPermanentlyDenied}',
      );
    } catch (error) {
      add('microphone permission request exception=$error');
    }

    await _logDesktopAudioDevices('after permission request', add);

    MediaStream? stream;
    try {
      add('getUserMedia(audio:true) start');
      stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      }).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException(
          'getUserMedia(audio:true) timed out after 8s',
        ),
      );
      final audioTracks = stream.getAudioTracks();
      add('getUserMedia(audio:true) success audioTracks=${audioTracks.length}');
      for (final track in audioTracks) {
        add(
          'captured audio track id=${_short(track.id ?? '')} '
          'enabled=${track.enabled} muted=${track.muted} '
          'readyState=${_trackReadyState(track)}',
        );
      }
    } catch (error, stack) {
      add('getUserMedia(audio:true) exception=$error');
      add('getUserMedia(audio:true) exceptionType=${error.runtimeType}');
      add('getUserMedia(audio:true) stackFirstLine=${_firstStackLine(stack)}');
    } finally {
      if (stream != null) {
        final stopped = _stopStreamTracks(stream, 'desktop mic diagnostic');
        add('diagnostic stream tracks stopped=$stopped');
        final disposed =
            await _safeDisposeStream(stream, 'desktop mic diagnostic');
        add('diagnostic stream disposed=$disposed');
      }
    }

    add('completedAt: ${DateTime.now().toIso8601String()}');
    return lines.join('\n');
  }

  void setIceServers(
    List<Map<String, dynamic>> iceServers, {
    String source = 'backend',
    String fallbackReason = 'backend_unavailable',
  }) {
    final sanitized = iceServers
        .map(_sanitizeIceServer)
        .whereType<Map<String, dynamic>>()
        .toList();
    if (sanitized.isEmpty) {
      _iceServers = List<Map<String, dynamic>>.from(_defaultIceServers);
      _iceConfigHasTurn = false;
      _iceConfigSource = 'default';
      _trace('ICE config fallback: using default STUN servers');
      final stunEntries = _iceServerSchemeEntryCount(
        (scheme) => scheme == 'stun',
      );
      _webVoice('fallback reason=$fallbackReason');
      _webVoice(
        'config source=$_iceConfigSource '
        'parsed ICE servers count=${_iceServers.length} '
        'TURN entries count=0 STUN entries count=$stunEntries '
        'schemes detected=${_iceServerSchemeSummary()} hasTurn=false',
      );
      return;
    }
    _iceServers = sanitized;
    _iceConfigHasTurn = _iceServers.any(_iceServerHasTurn);
    _iceConfigSource = source;
    final turnEntries = _iceServerSchemeEntryCount(
      (scheme) => scheme == 'turn' || scheme == 'turns',
    );
    final stunEntries = _iceServerSchemeEntryCount(
      (scheme) => scheme == 'stun',
    );
    _trace(
      'ICE config loaded servers=${_iceServers.length} hasTurn=$_iceConfigHasTurn',
    );
    _webVoice(
      'backend ICE applied source=$_iceConfigSource '
      'TURN count=$turnEntries STUN count=$stunEntries '
      'hasTurn=$_iceConfigHasTurn',
    );
    _webVoice(
      'config source=$_iceConfigSource '
      'parsed ICE servers count=${_iceServers.length} '
      'TURN entries count=$turnEntries '
      'STUN entries count=$stunEntries '
      'schemes detected=${_iceServerSchemeSummary()} hasTurn=$_iceConfigHasTurn',
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
    _videoMaxBitrateKbps = _boundedInt(
      video['maxBitrateKbps'],
      _defaultVideoMaxBitrateKbps,
      _minVideoMaxBitrateKbps,
      _maxVideoMaxBitrateKbps,
    );
    _debug(
      'video media config width=$_videoWidth height=$_videoHeight '
      'frameRate=$_videoFrameRate maxBitrateKbps=$_videoMaxBitrateKbps',
    );
  }

  void setRecipientUiDiagnostics({
    String? appLifecycleState,
    String? routeDialogState,
  }) {
    if (appLifecycleState != null) {
      _appLifecycleState = appLifecycleState;
    }
    if (routeDialogState != null) {
      _routeDialogState = routeDialogState;
    }
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
    if (_cleanupFuture != null) {
      _debug('call blocked reason=cleanup_in_progress');
      return;
    }
    if (_state != CallState.idle) return;
    _callStopFix(video ? 'start video call enabled' : 'start voice call');
    _callGeneration++;
    _callTerminating = false;
    _pendingRemoteCandidates.clear();
    _remoteDescriptionSet = false;
    _acceptedSignalHandled = false;
    _localOfferInProgress = false;
    _localOfferSent = false;
    _remoteAnswerApplied = false;
    _lastInboundAudioBytes = null;
    _lastOutboundAudioBytes = null;
    _lastInboundVideoBytes = null;
    _resetWebVoiceCallDiagnostics();
    if (video) {
      _webVideo('video call requested direction=outgoing');
    }
    final requestedVideo = video;
    video = video && _supportsRealVideoCalls;
    if (requestedVideo && !video) {
      _webVideo('fallback to audio reason=video_unsupported');
      _callStopFix('start video call blocked reason=video_unsupported');
    }
    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    _activeCallId = _generateId();
    _remotePeerId = toUserId;
    _remotePeerNickname = toNickname;
    _activeCallDirection = CallDirection.outgoing;
    _activeCallTimestampMs = startedAtMs;
    _videoEnabled = video;
    _receiveVideoOnly = false;
    _setState(CallState.calling);
    _debug(
      'new call allowed after cleanup callId=${_short(_activeCallId ?? '')} '
      'generation=$_callGeneration',
    );
    _emitCallHistory(
      status: CallStatus.outgoingRinging,
      timestampMs: startedAtMs,
    );
    _debug(
      'outgoing call start callId=${_short(_activeCallId ?? '')} '
      'toUserId=${_short(toUserId)} peer=$toNickname video=$video '
      'event=call_offer_init',
    );
    if (video) {
      _debug(
        'video call start direction=outgoing width=$_videoWidth '
        'height=$_videoHeight frameRate=$_videoFrameRate '
        'maxBitrateKbps=$_videoMaxBitrateKbps',
      );
    }
    try {
      await _initPeerConnection(isOffer: true, video: video);
      _sendSignal({
        'type': 'call_offer_init',
        'callId': _activeCallId,
        'toUserId': toUserId,
        'video': _videoEnabled,
        'callCreatedAt': startedAtMs,
      });
      _setState(CallState.ringing);
      _startCallAnswerTimer();
      _trace('offer init sent video=$_videoEnabled');
    } catch (e) {
      _callStopFix('error caught step=startCall error=$e');
      _emitCallHistory(status: CallStatus.failedNetwork);
      _handleError('Failed to start call: $e');
    }
  }

  // ── Accept incoming call ──────────────────────────────────────────────────
  bool beginIncomingAccept(String callId, {required String source}) {
    if (callId.isEmpty) {
      return false;
    }
    final sourceLabel = source == 'notification' ? 'notification' : 'in-app';
    if (_handledIncomingCallIds.contains(callId)) {
      _debug('accept already handled ignored callId=${_short(callId)}');
      return false;
    }
    _pendingIncomingCallIds.add(callId);
    _handledIncomingCallIds.add(callId);
    markIncomingCallState(
      callId,
      IncomingCallDisposition.accepting,
      source: source,
    );
    _debug('$sourceLabel accept action callId=${_short(callId)}');
    _debug('accept flow started callId=${_short(callId)}');
    unawaited(FirebasePushService.instance.cancelCallNotifications(callId));
    return true;
  }

  bool beginIncomingDecline(String callId, {required String source}) {
    if (callId.isEmpty) {
      return false;
    }
    final sourceLabel = source == 'notification' ? 'notification' : 'in-app';
    if (_handledIncomingCallIds.contains(callId)) {
      _debug('duplicate ignored callId=${_short(callId)}');
      return false;
    }
    _pendingIncomingCallIds.add(callId);
    _handledIncomingCallIds.add(callId);
    markIncomingCallState(
      callId,
      IncomingCallDisposition.declined,
      source: source,
    );
    _debug('$sourceLabel decline callId=${_short(callId)}');
    unawaited(FirebasePushService.instance.cancelCallNotifications(callId));
    return true;
  }

  void closePendingIncomingCall(String callId, String reason) {
    if (callId.isEmpty) {
      return;
    }
    unawaited(FirebasePushService.instance.cancelCallNotifications(callId));
    _pendingIncomingCallIds.remove(callId);
    markIncomingCallState(
      callId,
      reason == 'remote_hangup'
          ? IncomingCallDisposition.cancelled
          : IncomingCallDisposition.ended,
      source: reason,
    );
    _rememberFinishedCallId(callId);
    if (_state == CallState.incoming && incomingCall?.callId == callId) {
      _debug('in-app dialog dismissed callId=${_short(callId)} reason=$reason');
      _reset();
    }
  }

  Future<void> acceptCall() async {
    if (_state != CallState.incoming || incomingCall == null) return;
    if (!_handledIncomingCallIds.contains(incomingCall!.callId)) {
      beginIncomingAccept(incomingCall!.callId, source: 'in-app');
    }
    _debug(
      'accept start callId=${_short(incomingCall!.callId)} '
      'platform=$defaultTargetPlatform',
    );
    if (incomingCall!.isExpired) {
      final expiredCall = incomingCall!;
      _debug(
        'incoming call accept blocked reason=expired callId=${_short(expiredCall.callId)} ageMs=${expiredCall.ageMs}',
      );
      _emitMissedIncomingOnce(expiredCall, 'expired_on_accept');
      _sendSignal({
        'type': 'call_reject',
        'callId': expiredCall.callId,
        'toUserId': expiredCall.fromUserId,
        'reason': 'expired',
      });
      _safeReportCallError('Call expired');
      _reset();
      return;
    }
    final callId = incomingCall?.callId;
    _cancelIncomingOfferTimer();
    if (callId != null) {
      unawaited(FirebasePushService.instance.cancelCallNotifications(callId));
    }
    _callGeneration++;
    _callTerminating = false;
    _activeCallId = incomingCall!.callId;
    _remotePeerId = incomingCall!.fromUserId;
    _remotePeerNickname = incomingCall!.fromNickname;
    _activeCallDirection = CallDirection.incoming;
    _activeCallTimestampMs = incomingCall!.callCreatedAtMs;
    _videoEnabled = incomingCall!.video && _supportsRealVideoCalls;
    if (incomingCall!.video) {
      _webVideo('video call requested direction=incoming');
    }
    if (incomingCall!.video && !_videoEnabled) {
      _webVideo('fallback to audio reason=video_unsupported');
    }
    _receiveVideoOnly = false;
    _resetWebVoiceCallDiagnostics();
    _setState(CallState.connecting);
    if (_videoEnabled) {
      _debug(
        'video call start direction=incoming width=$_videoWidth '
        'height=$_videoHeight frameRate=$_videoFrameRate '
        'maxBitrateKbps=$_videoMaxBitrateKbps',
      );
    }
    _emitCallHistory(
      status: CallStatus.connected,
      timestampMs: incomingCall!.callCreatedAtMs,
    );
    try {
      _debug('create peer connection flow start direction=incoming');
      await _initPeerConnection(isOffer: false, video: _videoEnabled);
      _debug('create peer connection flow end direction=incoming');
      _debug('send call_answer start');
      _sendSignal({
        'type': 'call_answer',
        'callId': _activeCallId,
        'toUserId': _remotePeerId,
        'video': _videoEnabled,
      });
      _debug('send call_answer end');
      _debug('call accepted sent video=$_videoEnabled');
    } catch (e) {
      _emitCallHistory(status: CallStatus.failedNetwork);
      _handleError('Failed to accept call: $e');
    }
  }

  // ── Reject incoming call ──────────────────────────────────────────────────
  Future<void> acceptIncomingDesktopMicrophoneProbeOnly() async {
    if (_state != CallState.incoming || incomingCall == null) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.fuchsia) return;
    if (!_handledIncomingCallIds.contains(incomingCall!.callId)) {
      beginIncomingAccept(incomingCall!.callId, source: 'in-app');
    }
    final info = incomingCall!;
    _debug('desktop remote offer probe start callId=${_short(info.callId)}');
    if (info.isExpired) {
      _debug(
        'desktop remote offer probe blocked reason=expired callId=${_short(info.callId)} ageMs=${info.ageMs}',
      );
      _emitMissedIncomingOnce(info, 'expired_on_desktop_offer_probe');
      _reset();
      return;
    }

    _cancelIncomingOfferTimer();
    _callGeneration++;
    _callTerminating = false;
    _activeCallId = info.callId;
    _remotePeerId = info.fromUserId;
    _remotePeerNickname = info.fromNickname;
    _activeCallDirection = CallDirection.incoming;
    _activeCallTimestampMs = info.callCreatedAtMs;
    _videoEnabled = false;
    _receiveVideoOnly = info.video;
    _muted = false;
    _resetWebVoiceCallDiagnostics();
    _outboundAudioZeroSince = null;
    _outboundAudioZeroWarningLogged = false;
    _desktopIncomingMicActivationAfterIceScheduled = false;
    _desktopIncomingAnswerSent = false;
    _setState(CallState.connecting);
    _debug('call state connecting');
    _debug('real incoming Desktop call mode enabled');
    _debug('initial muted state=$_muted');
    if (_receiveVideoOnly) {
      _debug('incoming video call on Desktop');
      _debug('Desktop receive-video-only mode enabled');
      _debug('Desktop camera capture skipped');
      _debug('video call initial micMuted=$_muted');
    }

    MediaStream? stream;
    RTCPeerConnection? pc;
    var realCallActive = false;
    var microphoneUnavailable = false;
    try {
      try {
        stream = await _captureDesktopIncomingMicrophone();
        _localStream = stream;
        _localAudioTrackCount = stream?.getAudioTracks().length ?? 0;
        _localVideoTrackCount = 0;
        microphoneUnavailable = _localAudioTrackCount == 0;
        if (stream != null && stream.getAudioTracks().isNotEmpty) {
          _debug(
            'incoming local audio stream created tracks=${stream.getAudioTracks().length}',
          );
          await _attachDesktopIncomingMicStreamLikeVoiceCall(stream);
        }
      } catch (error) {
        microphoneUnavailable = true;
        _debug('local audio track skipped reason=mic_unavailable');
        _trace('desktop incoming microphone setup failed: $error');
      }
      _debug('local video track skipped');
      pc = await createPeerConnection(_iceConfig);
      _debug('desktop remote offer probe pc created');
      _pc = pc;
      _connectionState = 'created';
      _iceConnectionState = 'created';
      _iceConnected = false;
      _firstLocalIceCandidateLogged = false;
      _firstRemoteIceCandidateLogged = false;
      _remoteDescriptionSet = false;
      _pendingRemoteCandidates.clear();
      final generation = _callGeneration;
      _installDesktopIncomingPeerHandlers(pc, generation);
      if (stream != null && stream.getTracks().isNotEmpty) {
        for (final track in stream.getTracks()) {
          if (_receiveVideoOnly && track.kind == 'video') continue;
          track.enabled = !_muted;
          final sender = await _awaitWebRtcStep(
            'add audio track',
            () => pc!.addTrack(track, stream!),
          );
          if (track.kind == 'audio') {
            final enabled = !_muted;
            track.enabled = enabled;
            sender.track?.enabled = enabled;
            _debug(
              'incoming local audio track added before createAnswer '
              'id=${_short(track.id ?? '')} enabled=${track.enabled}',
            );
            _debug(
              'local audio track added incoming call id=${_short(track.id ?? '')} '
              'enabled=${track.enabled}',
            );
            if (_receiveVideoOnly) {
              _debug('desktop video mic initialized enabled=true');
            }
          } else {
            _debug(
              'desktop remote offer probe local ${track.kind} track added '
              'id=${_short(track.id ?? '')}',
            );
          }
        }
        await _logIncomingAudioSenderCountAfterAddTrack();
        unawaited(_logAudioSenders('incoming call after local tracks added'));
      }
      final micSenderPresent =
          stream != null && stream.getAudioTracks().isNotEmpty;
      if (_receiveVideoOnly) {
        await _addDesktopReceiveOnlyTransceivers(
          pc,
          includeAudio: !micSenderPresent,
        );
        if (micSenderPresent) {
          _debug('recvonly fallback skipped reason=mic_sender_present');
        }
      } else if (!micSenderPresent) {
        await _addDesktopReceiveOnlyTransceivers(pc);
      } else {
        _debug('incoming voice recvonly fallback skipped reason=mic_captured');
      }
      _debug('desktop answer probe send accept notification start');
      _sendSignal({
        'type': 'call_answer',
        'callId': _activeCallId,
        'toUserId': _remotePeerId,
        'video': false,
      });
      _debug('desktop answer probe send accept notification end');
      final offerSdp = await _awaitDesktopOfferSdp(info.callId);
      _debug('desktop remote offer probe setRemoteDescription offer start');
      await _awaitWebRtcStep(
        'setRemoteDescription offer',
        () =>
            pc!.setRemoteDescription(RTCSessionDescription(offerSdp, 'offer')),
      );
      _remoteDescriptionSet = true;
      _debug('desktop remote offer probe setRemoteDescription offer end');
      final answer = await _awaitWebRtcStep(
        'createAnswer',
        () => pc!.createAnswer(),
      );
      _debug(
        'desktop remote offer probe answer created hasSdp=${answer.sdp?.isNotEmpty == true}',
      );
      _debug(
        'answer created generation=$_callGeneration micSender=${!microphoneUnavailable}',
      );
      _debug('desktop remote offer probe setLocalDescription answer start');
      await _awaitWebRtcStep(
        'setLocalDescription answer',
        () => pc!.setLocalDescription(answer),
        timeout: const Duration(seconds: 5),
      );
      _debug('desktop remote offer probe setLocalDescription answer end');
      final answerSdp = answer.sdp ?? '';
      _debug('answer sdp length=${answerSdp.length}');
      if (_activeCallId == info.callId &&
          _remotePeerId != null &&
          identical(_pc, pc) &&
          answerSdp.isNotEmpty) {
        _debug('sending call_answer start');
        _sendSignal({
          'type': 'call_answer',
          'callId': _activeCallId,
          'toUserId': _remotePeerId,
          'sdp': answerSdp,
          'video': false,
        });
        _debug('sending call_answer end');
        _desktopIncomingAnswerSent = true;
        await _forceDesktopIncomingAudioSenderEnabled('after answer sent');
        _scheduleDesktopIncomingMicActivationAfterIce();
        _scheduleDesktopIncomingOutboundAudioDeltaCheck(generation);
        await _flushPendingRemoteCandidates();
        realCallActive = true;
        if (microphoneUnavailable) {
          _safeReportCallError(
            'Microphone unavailable. You can watch/listen only.',
          );
        }
        _debug('answer sent, keeping call alive');
      } else {
        _debug(
          'sending call_answer skipped reason=stale_or_cleaned callId=${_short(_activeCallId ?? '')}',
        );
      }
    } catch (error) {
      _debug('desktop remote offer probe failed error=$error');
      final text = error.toString();
      if (text.contains('Microphone unavailable')) {
        _debug('microphone unavailable handled safely');
      }
      _safeReportCallError(
        text.startsWith('Exception: ')
            ? text.substring('Exception: '.length)
            : 'Desktop voice call setup failed.',
      );
    } finally {
      if (realCallActive) {
        _debug('cleanup skipped reason=real_call_active');
      } else {
        if (identical(_pc, pc)) {
          _pc = null;
        }
        if (identical(_localStream, stream)) {
          _localStream = null;
        }
        if (pc != null) {
          try {
            await _awaitCleanupStep(
                'desktop remote offer probe pc.close', pc.close);
          } catch (_) {}
          try {
            await _awaitCleanupStep(
                'desktop remote offer probe pc.dispose', pc.dispose);
          } catch (_) {}
        }
        if (stream != null) {
          final stopped =
              _stopStreamTracks(stream, 'desktop remote offer probe local');
          _debug(
              'desktop remote offer probe local tracks stopped count=$stopped');
          await _safeDisposeStream(stream, 'desktop remote offer probe local');
        }
        _reset();
      }
    }
  }

  void rejectCall() {
    if (_state != CallState.incoming || incomingCall == null) return;
    if (!_handledIncomingCallIds.contains(incomingCall!.callId) &&
        !beginIncomingDecline(incomingCall!.callId, source: 'in-app')) {
      return;
    }
    _debug('incoming call rejected callId=${_short(incomingCall!.callId)}');
    onCallHistoryEvent?.call(CallHistoryEvent(
      callId: incomingCall!.callId,
      peerUserId: incomingCall!.fromUserId,
      peerNickname: incomingCall!.fromNickname,
      direction: CallDirection.incoming,
      status: CallStatus.rejectedByRecipient,
      isVideo: incomingCall!.video,
      timestampMs: incomingCall!.callCreatedAtMs,
    ));
    _sendSignal({
      'type': 'call_reject',
      'callId': incomingCall!.callId,
      'toUserId': incomingCall!.fromUserId,
    });
    _reset();
  }

  // ── End active call ───────────────────────────────────────────────────────
  void endCall() {
    _debug('call hangup requested callId=${_short(_activeCallId ?? '')}');
    _emitCallEndHistory();
    if (_remotePeerId != null && _activeCallId != null) {
      _sendSignal({
        'type': 'call_hangup',
        'callId': _activeCallId,
        'toUserId': _remotePeerId,
      });
    }
    _reset();
  }

  // ── Handle signaling messages from WebSocket ──────────────────────────────
  Future<void> runDesktopMicStabilityProbe() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.fuchsia) {
      return;
    }
    _debug('desktop mic probe start cycles=10');
    for (var i = 1; i <= 10; i++) {
      MediaStream? stream;
      _debug('desktop mic probe iteration=$i enumerate start');
      try {
        final inputs = await Helper.enumerateDevices('audioinput');
        final labels = inputs
            .map((device) =>
                '${_short(device.deviceId)}:${device.label.isEmpty ? 'no_label' : device.label}')
            .join(', ');
        _debug(
          'desktop mic probe iteration=$i enumerate end audio input count=${inputs.length} labels=[$labels]',
        );
        final constraints = <String, dynamic>{
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        };
        _debug('desktop getUserMedia default audio constraints');
        _debug('no sourceId/deviceId used');
        _debug('desktop mic probe iteration=$i getUserMedia start');
        stream = await navigator.mediaDevices.getUserMedia({
          'audio': constraints,
          'video': false,
        }).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw TimeoutException(
            'desktop mic probe iteration=$i getUserMedia timed out',
          ),
        );
        final tracks = stream.getAudioTracks();
        _debug(
          'desktop mic probe iteration=$i getUserMedia end audioTracks=${tracks.length}',
        );
        await Future<void>.delayed(const Duration(seconds: 1));
        var stopped = 0;
        for (final track in tracks) {
          try {
            track.stop();
            stopped++;
          } catch (error) {
            _trace('desktop mic probe iteration=$i track stop failed: $error');
          }
        }
        _debug('desktop mic probe iteration=$i stop tracks count=$stopped');
        _debug('desktop mic probe iteration=$i dispose stream start');
        await stream.dispose().timeout(
              const Duration(seconds: 5),
              onTimeout: () => throw TimeoutException(
                'desktop mic probe iteration=$i stream dispose timed out',
              ),
            );
        _debug('desktop mic probe iteration=$i dispose stream end');
      } catch (error) {
        _debug('desktop mic probe iteration=$i failed error=$error');
        if (stream != null) {
          try {
            for (final track in stream.getTracks()) {
              track.stop();
            }
            await stream.dispose().timeout(const Duration(seconds: 2));
            _debug('desktop mic probe iteration=$i cleanup after failure done');
          } catch (cleanupError) {
            _trace(
              'desktop mic probe iteration=$i cleanup after failure ignored: $cleanupError',
            );
          }
        }
      }
    }
    _debug('desktop mic probe completed cycles=10');
  }

  Future<void> handleSignal(Map<String, dynamic> msg) async {
    final type = msg['type'] as String? ?? '';
    _lastCallEventReceived = _safeCallEvent(msg);
    DiagnosticService.instance.log('call received $_lastCallEventReceived');
    if (kDebugMode) {
      debugPrint('[CallService] handleSignal: $type');
    }

    switch (type) {
      case 'call_offer_init':
      case 'call_offer':
      case 'call_sdp_offer':
        _debug(
          'desktop incoming call_offer inspect type=$type '
          'callId=${_short(msg['callId'] as String? ?? '')} '
          'hasSdp=${msg['sdp'] is String} hasOffer=${msg['offer'] is String} '
          'keys=${msg.keys.join(',')}',
        );
        if (msg['sdp'] is! String) {
          final callId = msg['callId'] as String? ?? '';
          final fromUserId = msg['fromUserId'] as String? ?? '';
          final fromNickname = msg['fromNickname'] as String? ?? '?';
          final video = msg['video'] == true;
          final createdAtMs = _callCreatedAtMs(msg);
          final receivedAtMs = DateTime.now().millisecondsSinceEpoch;
          final ttlMs = _positiveInt(
            msg['ttlMs'] ?? msg['callOfferTtlMs'],
            callOfferTtlMs,
          );
          // Relax the TTL verification to tolerate up to 5 minutes of clock drift
          final effectiveTtlMs = ttlMs > 300000 ? ttlMs : 300000;
          final ageMs = receivedAtMs - createdAtMs;
          _debug(
            'incoming call offer received type=$type callId=${_short(callId)} '
            'fromUserId=${_short(fromUserId)} from=$fromNickname video=$video '
            'callCreatedAt=$createdAtMs serverTimestamp=${msg['serverTimestamp'] ?? 'none'} '
            'offerReceivedAtMs=$receivedAtMs ageMs=$ageMs '
            'appLifecycleState=$_appLifecycleState isAlreadyInCall=$isAlreadyInCall '
            'currentCallId=${_short(currentCallId)} routeDialogState=$_routeDialogState',
          );
          if (callId.isEmpty) {
            _debug('incoming call ignored reason=callId_missing type=$type');
            return;
          }
          if (fromUserId.isEmpty) {
            _debug(
                'incoming call ignored reason=fromUserId_missing callId=${_short(callId)}');
            return;
          }
          final existingDisposition = _incomingCallStates[callId];
          if (existingDisposition == IncomingCallDisposition.accepting ||
              existingDisposition == IncomingCallDisposition.connecting ||
              existingDisposition == IncomingCallDisposition.active) {
            _debug(
              'duplicate call_offer ignored reason=already_accepting callId=${_short(callId)}',
            );
            debugPrint(
              '[HestiaIncomingUi] duplicate call_offer ignored reason=already_accepting callId=${_short(callId)} source=$type',
            );
            return;
          }
          if (_state == CallState.incoming && incomingCall?.callId == callId) {
            _debug(
              'duplicate call_offer ignored callId=${_short(callId)}',
            );
            return;
          }
          if (ageMs > effectiveTtlMs) {
            _debug(
              'incoming call expired ageMs=$ageMs ttlMs=$ttlMs '
              'effectiveTtlMs=$effectiveTtlMs callId=${_short(callId)}',
            );
            _emitMissedIncomingOnce(
              IncomingCallInfo(
                fromUserId: fromUserId,
                fromNickname: fromNickname,
                callId: callId,
                video: video &&
                    (_supportsRealVideoCalls ||
                        _supportsIncomingVideoReceiveOnly),
                callCreatedAtMs: createdAtMs,
                offerReceivedAtMs: receivedAtMs,
                callOfferTtlMs: ttlMs,
              ),
              'expired',
            );
            return;
          }
          if (_finishedCallIds.contains(callId)) {
            _debug(
              'stale signal ignored oldCallId=${_short(callId)} '
              'newCallId=${_short(_activeCallId ?? incomingCall?.callId ?? '')}',
            );
            return;
          }
          final activeOrIncomingCallId = _activeCallId ?? incomingCall?.callId;
          if (_state != CallState.idle) {
            if (activeOrIncomingCallId == callId) {
              _debug(
                'incoming call offer for active call ignored callId=${_short(callId)} state=$_state',
              );
              return;
            }
            _debug(
              'incoming call rejected reason=busy state=$_state callId=${_short(callId)}',
            );
            _sendSignal({
              'type': 'call_reject',
              'callId': callId,
              'toUserId': fromUserId,
              'reason': 'busy',
            });
            return;
          }
          final canAcceptIncomingVideo =
              _supportsRealVideoCalls || _supportsIncomingVideoReceiveOnly;
          if (video &&
              _supportsIncomingVideoReceiveOnly &&
              !_supportsRealVideoCalls) {
            _debug(
              'incoming video call on Desktop callId=${_short(callId)}',
            );
          }
          if (video && !canAcceptIncomingVideo) {
            _debug(
                'incoming call rejected reason=video_disabled callId=${_short(callId)}');
            _sendSignal({
              'type': 'call_reject',
              'callId': callId,
              'toUserId': fromUserId,
              'reason': 'video_disabled',
            });
            _safeReportCallError('Video calls are disabled.');
            return;
          }
          incomingCall = IncomingCallInfo(
            fromUserId: fromUserId,
            fromNickname: fromNickname,
            callId: callId,
            video: video && canAcceptIncomingVideo,
            callCreatedAtMs: createdAtMs,
            offerReceivedAtMs: receivedAtMs,
            callOfferTtlMs: effectiveTtlMs,
          );
          _pendingIncomingCallIds.add(callId);
          markIncomingCallState(
            callId,
            IncomingCallDisposition.ringing,
            source: type,
          );
          _debug('pending call created callId=${_short(callId)}');
          _setState(CallState.incoming);
          _startIncomingOfferTimer(incomingCall!);
          _debug(
            'incoming call accepted for UI callId=${_short(callId)} fromUserId=${_short(fromUserId)}',
          );
          onIncomingCall?.call(incomingCall!);
          break;
        }
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia) {
          _handleDesktopOfferSdpForProbe(msg);
          break;
        }
        final sdpCallId = msg['callId'] as String? ?? '';
        if (sdpCallId.isNotEmpty &&
            (_activeCallId == sdpCallId || incomingCall?.callId == sdpCallId)) {
          _debug(
              'sdp call_offer merged into existing callId=${_short(sdpCallId)}');
        }
        if (_pc == null) return;
        final sdp = msg['sdp'] as String;
        await _awaitWebRtcStep(
          'setRemoteDescription offer',
          () => _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer')),
        );
        _remoteDescriptionSet = true;
        _trace('offer received/set');
        await _flushPendingRemoteCandidates();
        final answer = await _awaitWebRtcStep(
          'createAnswer',
          () => _pc!.createAnswer(),
        );
        await _awaitWebRtcStep(
          'setLocalDescription answer',
          () => _pc!.setLocalDescription(answer),
        );
        _debug('send call_answer sdp start');
        _sendSignal({
          'type': 'call_answer',
          'callId': _activeCallId,
          'toUserId': _remotePeerId,
          'sdp': answer.sdp,
        });
        _debug('send call_answer sdp end');
        await _applyVideoSenderBitrate();
        _trace('answer created/sent');
        break;

      case 'call_answer':
      case 'call_sdp_answer':
      case 'call_accepted':
        if (!_messageMatchesActiveCall(msg)) {
          _debug('call answer ignored reason=stale_call');
          return;
        }
        if (msg['sdp'] is! String) {
          if (_acceptedSignalHandled) {
            _debug('call answer accepted ignored reason=duplicate_accept');
            return;
          }
          if (_localOfferInProgress || _localOfferSent) {
            _debug(
              'call answer accepted ignored reason=offer_already_started '
              'offerInProgress=$_localOfferInProgress localOfferSent=$_localOfferSent',
            );
            _acceptedSignalHandled = true;
            return;
          }
          if (_state != CallState.calling && _state != CallState.ringing) {
            _debug('call answer ignored reason=not_calling state=$_state');
            return;
          }
          _acceptedSignalHandled = true;
          _cancelCallAnswerTimer();
          _setState(CallState.connecting);
          await _createAndSendOffer();
          break;
        }
        if (_remoteAnswerApplied) {
          _debug('call answer ignored reason=duplicate_sdp_answer');
          return;
        }
        if (_pc == null) {
          _debug('call answer ignored reason=peer_connection_missing');
          return;
        }
        if (_activeCallDirection != CallDirection.outgoing) {
          _debug('call answer ignored reason=not_caller');
          return;
        }
        if (!_localOfferSent) {
          _debug(
            'call answer ignored reason=local_offer_not_sent '
            'offerInProgress=$_localOfferInProgress state=$_state',
          );
          return;
        }
        if (_state != CallState.connecting &&
            _state != CallState.ringing &&
            _state != CallState.calling) {
          _debug('call answer ignored reason=invalid_state state=$_state');
          return;
        }
        final sdp = msg['sdp'] as String;
        _remoteAnswerApplied = true;
        _debug(
          'setRemoteDescription answer validated '
          'state=$_state localOfferSent=$_localOfferSent',
        );
        try {
          await _awaitWebRtcStep(
            'setRemoteDescription answer',
            () =>
                _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'answer')),
          );
          _remoteDescriptionSet = true;
          _trace('answer received/set');
          await _flushPendingRemoteCandidates();
          await _applyVideoSenderBitrate();
        } catch (error) {
          _debug(
              'call setup failed at setRemoteDescription answer error=$error');
          _failActiveCall('Call setup failed');
        }
        break;

      case 'call_ice_candidate':
      case 'call_ice':
        if (!_messageMatchesActiveCall(msg)) {
          _trace('ICE candidate ignored reason=stale_call');
          return;
        }
        if (_pc == null) return;
        await _addRemoteCandidate(RTCIceCandidate(
          msg['candidate'] as String,
          msg['sdpMid'] as String? ?? '',
          (msg['sdpMLineIndex'] as num?)?.toInt() ?? 0,
        ));
        break;

      case 'call_reject':
      case 'call_rejected':
        if (!_messageMatchesActiveCall(msg)) {
          _debug('call reject ignored reason=stale_call');
          return;
        }
        if (_state == CallState.incoming && incomingCall != null) {
          _debug(
            'incoming call missed reason=call_reject callId=${_short(incomingCall!.callId)}',
          );
          _emitMissedIncomingOnce(incomingCall!, 'call_reject');
        } else {
          _emitCallHistory(status: CallStatus.rejectedByRecipient);
          _safeReportCallError('Call was rejected');
        }
        _debug('call UI closed by reject/timeout type=$type');
        _reset();
        break;

      case 'call_hangup':
      case 'call_ended':
        if (!_messageMatchesActiveCall(msg)) {
          _debug('call hangup ignored reason=stale_call');
          return;
        }
        if (_state == CallState.incoming && incomingCall != null) {
          _debug(
            'incoming call missed reason=caller_hangup callId=${_short(incomingCall!.callId)}',
          );
          _emitMissedIncomingOnce(incomingCall!, 'caller_hangup');
        } else {
          _emitCallEndHistory();
        }
        _debug('call UI closed by hangup/timeout type=$type');
        _reset();
        break;

      case 'call_unavailable':
        final callId = msg['callId']?.toString() ?? '';
        final reason = msg['reason']?.toString() ?? 'none';
        final message = msg['message'] as String?;
        _debug(
          'call unavailable received callId=${_short(callId)} '
          'activeCallId=${_short(_activeCallId ?? '')} reason=$reason '
          'message=${message ?? 'none'}',
        );
        if (callId.isEmpty || !_messageMatchesActiveCall(msg)) {
          _debug(
            'call unavailable ignored reason=stale_call '
            'callId=${_short(callId)} activeCallId=${_short(_activeCallId ?? '')}',
          );
          return;
        }
        _safeReportCallError(
          message == null || message == 'User is unavailable.'
              ? _userUnavailableMessage()
              : message,
        );
        _emitCallHistory(status: CallStatus.failedTimeout);
        _reset();
        break;

      default:
        _debug('incoming call ignored reason=unknown_event type=$type');
        break;
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────
  Future<T> _awaitWebRtcStep<T>(
    String label,
    Future<T> Function() action, {
    Duration? timeout,
  }) async {
    _debug('$label start');
    try {
      final future = action();
      final result =
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia)
              ? await future.timeout(
                  timeout ?? _desktopWebRtcStepTimeout,
                  onTimeout: () => throw TimeoutException(
                    '$label timed out after '
                    '${(timeout ?? _desktopWebRtcStepTimeout).inSeconds}s',
                  ),
                )
              : await future;
      _debug('$label end');
      return result;
    } catch (error) {
      _debug('$label failed error=$error');
      _callStopFix('error caught step=$label error=$error');
      rethrow;
    }
  }

  Future<void> _initPeerConnection(
      {required bool isOffer, required bool video}) async {
    final pendingCleanup = _cleanupFuture;
    if (pendingCleanup != null) {
      _debug('call blocked reason=cleanup_in_progress');
      await pendingCleanup;
      _debug('new call allowed after cleanup');
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia) {
      if (_pc != null || _localStream != null || _remoteStream != null) {
        unawaited(_closePeerConnection());
      }
    } else {
      await _awaitWebRtcStep(
        'close previous peer connection',
        _closePeerConnection,
      );
    }
    _muted = false;
    _cameraEnabled = true;
    _outboundAudioZeroSince = null;
    _outboundAudioZeroWarningLogged = false;
    _callTerminating = false;

    // Initialise the renderer once — it routes remote audio to the speaker
    await _ensureRenderersReady('peer connection init');

    await _awaitWebRtcStep(
      'media permission check',
      () => _ensureMediaPermissions(video: video),
    );
    await _awaitWebRtcStep('enable audio output', _enableMobileAudioOutput);
    final refresh = refreshBackendIceConfig;
    if (refresh == null) {
      _webVoice('fallback reason=backend_refresh_hook_missing');
    } else {
      await _awaitWebRtcStep(
        'refresh backend ICE config',
        refresh,
      );
    }
    _iceConfigHasTurn = _iceServers.any(_iceServerHasTurn);
    _debug(
      'creating peer connection iceServers=${_iceServers.length} hasTurn=$_iceConfigHasTurn',
    );
    final turnEntries = _iceServerSchemeEntryCount(
      (scheme) => scheme == 'turn' || scheme == 'turns',
    );
    final stunEntries = _iceServerSchemeEntryCount(
      (scheme) => scheme == 'stun',
    );
    _webVoice(
      'parsed ICE servers count=${_iceServers.length} '
      'TURN entries count=$turnEntries '
      'STUN entries count=$stunEntries '
      'schemes detected=${_iceServerSchemeSummary()} hasTurn=$_iceConfigHasTurn',
    );
    _webVoice(
      'final peer config TURN count=$turnEntries '
      'STUN count=$stunEntries source=$_iceConfigSource '
      'hasTurn=$_iceConfigHasTurn',
    );
    if (kIsWeb && !_iceConfigHasTurn && !_turnWarningShownForCall) {
      _turnWarningShownForCall = true;
      _safeReportCallError(
        'TURN is not configured; calls may fail on some networks.',
      );
    }
    _callStopFix(
      'before peer create iceServers=${_iceServers.length} '
      'hasTurn=$_iceConfigHasTurn source=$_iceConfigSource '
      'video=$video localStream=${_localStream != null} '
      'localRendererDisposed=$_localRendererDisposed '
      'remoteRendererDisposed=$_remoteRendererDisposed',
    );
    _pc = await _awaitWebRtcStep(
      'create peer connection',
      () => createPeerConnection(_iceConfig),
    );
    _callStopFix('after peer create pcNull=${_pc == null}');
    _webVoice('peer connection created hasTurn=$_iceConfigHasTurn');
    _connectionState = 'created';
    _iceConnectionState = 'created';
    _iceConnected = false;
    _firstLocalIceCandidateLogged = false;
    _firstRemoteIceCandidateLogged = false;
    _remoteDescriptionSet = false;
    _acceptedSignalHandled = false;
    _localOfferInProgress = false;
    _localOfferSent = false;
    _remoteAnswerApplied = false;
    _pendingRemoteCandidates.clear();
    _startIceConnectionTimer();
    final generation = _callGeneration;
    final desktopVoiceCall = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.fuchsia &&
        !video &&
        !_receiveVideoOnly;

    // Capture local microphone with noise/echo cancellation.
    var activeVideo = video;
    try {
      final audioConstraints = await _awaitWebRtcStep(
        'audio input selection',
        _audioConstraints,
      );
      final videoConstraints = activeVideo
          ? await _awaitWebRtcStep('video input selection', _videoConstraints)
          : false;
      if (desktopVoiceCall) {
        _debug('enumerateDevices diagnostic only');
        _debug('getUserMedia fallback attempt');
      }
      _webVideo(
          'getUserMedia requested constraints audio=true video=$activeVideo');
      _localStream = await _awaitWebRtcStep(
        'getUserMedia',
        () => navigator.mediaDevices.getUserMedia({
          'audio': audioConstraints,
          'video': videoConstraints,
        }),
      );
      if (desktopVoiceCall) {
        _debug('getUserMedia success');
      }
      _webVoice(
        'local audio track created count=${_localStream?.getAudioTracks().length ?? 0}',
      );
      if (activeVideo) {
        _debug('camera getUserMedia completed');
      }
    } catch (error) {
      if (kIsWeb && activeVideo) {
        _webVideo('camera permission denied error=$error');
        _webVideo('fallback to audio reason=camera_unavailable');
        _safeReportCallError(
          'Camera unavailable. Continuing with audio.',
        );
        activeVideo = false;
        _videoEnabled = false;
        _cameraEnabled = false;
        final audioConstraints = await _awaitWebRtcStep(
          'audio input selection fallback',
          _audioConstraints,
        );
        _localStream = await _awaitWebRtcStep(
          'getUserMedia audio fallback',
          () => navigator.mediaDevices.getUserMedia({
            'audio': audioConstraints,
            'video': false,
          }),
        );
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia) {
        if (desktopVoiceCall) {
          _debug('getUserMedia failure error=$error');
        }
        _debug('desktop getUserMedia failed video=$video error=$error');
        if (video) {
          throw Exception(
            'Could not start Desktop camera. It may be busy or blocked by privacy settings.',
          );
        }
        throw Exception(
          'Microphone unavailable. Check Desktop microphone permissions.',
        );
      } else if (video &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        _debug('android video getUserMedia failed error=$error');
        throw Exception(
          'Could not start camera or microphone. Check Android camera and microphone permissions.',
        );
      } else {
        rethrow;
      }
    }

    await _ensureRenderersReady('local stream attach');
    await _localRenderer.setSrcObject(stream: _localStream);
    _trace(
      'local stream attached to localRenderer '
      '${_rendererSummary(_localRenderer, 'localRenderer')} '
      '${_rendererSummary(_remoteRenderer, 'remoteRenderer')}',
    );
    await _awaitWebRtcStep('select audio output', _selectDesktopAudioOutput);
    final localAudioTracks = _localStream!.getAudioTracks();
    final localVideoTracks = _localStream!.getVideoTracks();
    _localAudioTrackCount = localAudioTracks.length;
    _localVideoTrackCount = localVideoTracks.length;
    if (localAudioTracks.isEmpty &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.fuchsia) {
      if (desktopVoiceCall) {
        _debug('getUserMedia failure reason=no_audio_track');
      }
      throw Exception(
        'Microphone unavailable. Check Desktop microphone permissions.',
      );
    }
    for (final track in localAudioTracks) {
      track.enabled = true;
    }
    for (final track in localVideoTracks) {
      track.enabled = true;
    }
    _trace('local stream created');
    _trace('audio tracks count=${localAudioTracks.length}');
    _trace('video tracks count=${localVideoTracks.length}');
    if (activeVideo && kIsWeb && localVideoTracks.isEmpty) {
      activeVideo = false;
      _videoEnabled = false;
      _cameraEnabled = false;
      _webVideo('fallback to audio reason=no_camera_video_track');
      _safeReportCallError('Camera unavailable. Continuing with audio.');
    }
    if (activeVideo) {
      _debug('camera track created count=${localVideoTracks.length}');
      _debug('local video track created count=${localVideoTracks.length}');
      _webVideo('camera permission granted');
      _webVideo('local video track created count=${localVideoTracks.length}');
      _webVideo('local preview attached');
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.fuchsia &&
          localVideoTracks.isEmpty) {
        throw Exception('no_camera_video_track');
      }
    }
    for (final track in localAudioTracks) {
      _trace(
        'local audio track id=${_short(track.id ?? '')} '
        'enabled=${track.enabled} muted=${track.muted} '
        'settings=${_safeTrackSettings(track)}',
      );
    }

    for (final track in _localStream!.getTracks()) {
      await _awaitWebRtcStep(
        'add ${track.kind} track',
        () => _pc!.addTrack(track, _localStream!),
      );
      if (track.kind == 'audio') {
        _debug(
          'local audio track added id=${_short(track.id ?? '')} '
          'enabled=${track.enabled}',
        );
      }
      if (track.kind == 'video') {
        _debug('video track added id=${_short(track.id ?? '')}');
        _debug('local video track added id=${_short(track.id ?? '')}');
        _webVideo('local video track added id=${_short(track.id ?? '')}');
      }
      _trace(
        'local ${track.kind} track added id=${_short(track.id ?? '')} '
        'enabled=${track.enabled} muted=${track.muted}',
      );
    }
    unawaited(_logAudioSenders('after local tracks added'));

    // KEY FIX: receive remote audio and route it to the device speaker.
    // Without this handler Android never plays the incoming audio stream.
    _pc!.onTrack = (RTCTrackEvent event) {
      if (!_isCurrentCallGeneration(generation, 'onTrack')) {
        return;
      }
      if (kDebugMode) {
        debugPrint('[CallService] onTrack: ${event.track.kind}');
      }
      event.track.enabled = true;
      if (event.track.kind == 'audio') {
        _webVoice('remote track received muted=${event.track.muted}');
        if (event.track.muted == true) {
          _recommendBrowserAudioUnlock('remote_track_muted');
        }
      } else if (event.track.kind == 'video') {
        _webVideo('remote video track received');
      }
      _trace(
        'onTrack kind=${event.track.kind} id=${_short(event.track.id ?? '')} '
        'enabled=${event.track.enabled} muted=${event.track.muted} '
        'streams=${event.streams.length}',
      );
      if (kIsWeb) {
        final streamId =
            event.streams.isNotEmpty ? _short(event.streams[0].id) : 'none';
        _webVideo(
          'onTrack kind=${event.track.kind} '
          'track=${_short(event.track.id ?? '')} '
          'enabled=${event.track.enabled} muted=${event.track.muted} '
          'stream=$streamId',
        );
      }
      if (event.streams.isNotEmpty) {
        if (kIsWeb && event.track.kind == 'video') {
          _installRemoteVideoTrackDiagnostics(
            event.track,
            event.streams[0],
            generation,
          );
        }
        if (_receiveVideoOnly) {
          _remoteStream = event.streams[0];
          _debug('remote renderer attach skipped reason=sdp_only_step1');
          _startPlaybackStatsTimer();
        } else {
          unawaited(
              _attachRemoteStreamForPlayback(event.streams[0], generation));
        }
        final remoteAudioTracks = event.streams[0].getAudioTracks();
        final remoteVideoTracks = event.streams[0].getVideoTracks();
        _remoteAudioTrackCount = remoteAudioTracks.length;
        _remoteVideoTrackCount = remoteVideoTracks.length;
        _webVideo(
          'remote stream tracks stream=${_short(event.streams[0].id)} '
          'audio=${remoteAudioTracks.length} video=${remoteVideoTracks.length}',
        );
        _trace('remote audio tracks count=${remoteAudioTracks.length}');
        _trace('remote video tracks count=${remoteVideoTracks.length}');
        if (remoteVideoTracks.isNotEmpty) {
          _debug(
              'remote video track received count=${remoteVideoTracks.length}');
          _webVideo(
              'remote video track received count=${remoteVideoTracks.length}');
        }
        for (final track in remoteAudioTracks) {
          track.enabled = true;
          if (track.muted == true) {
            _recommendBrowserAudioUnlock('remote_audio_track_muted');
          }
          _trace(
            'remote audio track id=${_short(track.id ?? '')} '
            'enabled=${track.enabled} muted=${track.muted} '
            'readyState=${_trackReadyState(track)}',
          );
        }
      } else {
        _trace('onTrack without stream kind=${event.track.kind}');
      }
    };

    _pc!.onIceCandidate = (candidate) {
      if (!_isCurrentCallGeneration(generation, 'onIceCandidate')) {
        return;
      }
      if (candidate.candidate == null) return;
      if (!_firstLocalIceCandidateLogged) {
        _firstLocalIceCandidateLogged = true;
        _debug('first ICE candidate local');
      }
      _sendSignal({
        'type': 'call_ice_candidate',
        'callId': _activeCallId,
        'toUserId': _remotePeerId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
      _trace('ICE candidate sent mid=${candidate.sdpMid ?? ''}');
    };

    _pc!.onConnectionState = (s) {
      if (!_isCurrentCallGeneration(generation, 'onConnectionState')) {
        return;
      }
      if (kDebugMode) {
        debugPrint('[CallService] PC state: $s');
      }
      _connectionState = s.name;
      _debug('peerConnectionState=$s');
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _debug('ICE connected');
        _markIceConnected();
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _debug('ICE failed');
        _failActiveCall(_callConnectionFailedMessage());
      } else if (s ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _startIceDisconnectedTimer();
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _cancelIceTimers();
      }
    };
    _pc!.onIceConnectionState = (s) {
      if (!_isCurrentCallGeneration(generation, 'onIceConnectionState')) {
        return;
      }
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
      if (!_isCurrentCallGeneration(generation, 'onIceGatheringState')) {
        return;
      }
      _trace('iceGatheringState=$s');
    };
    _pc!.onSignalingState = (s) {
      if (!_isCurrentCallGeneration(generation, 'onSignalingState')) {
        return;
      }
      _trace('signalingState=$s');
    };
  }

  Future<void> _createAndSendOffer() async {
    if (_pc == null) {
      _debug('createOffer ignored reason=peer_connection_missing');
      return;
    }
    if (_localOfferSent) {
      _debug('createOffer ignored reason=local_offer_already_sent');
      return;
    }
    if (_localOfferInProgress) {
      _debug('createOffer ignored reason=local_offer_in_progress');
      return;
    }
    _localOfferInProgress = true;
    try {
      final offer = await _awaitWebRtcStep(
        'createOffer',
        () => _pc!.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': _videoEnabled,
        }),
      );
      await _awaitWebRtcStep(
        'setLocalDescription offer',
        () => _pc!.setLocalDescription(offer),
      );
      _localOfferSent = true;
      await _applyVideoSenderBitrate();
      _debug('send call_offer start');
      _sendSignal({
        'type': 'call_offer',
        'callId': _activeCallId,
        'toUserId': _remotePeerId,
        'sdp': offer.sdp,
      });
      _debug('send call_offer end');
      _trace('offer created/sent');
    } finally {
      _localOfferInProgress = false;
    }
  }

  Future<MediaStream?> _captureDesktopIncomingMicrophone() async {
    _debug('incoming call mic capture start');
    if (_receiveVideoOnly) {
      _debug('desktop video receive-only mic capture start');
    }
    try {
      await _ensureMediaPermissions(video: false);
      final audioConstraints = await _audioConstraints();
      final stream = await _awaitWebRtcStep(
        'getUserMedia',
        () => navigator.mediaDevices.getUserMedia({
          'audio': audioConstraints,
          'video': false,
        }),
      );
      final audioTracks = stream.getAudioTracks();
      _webVoice('local audio track created count=${audioTracks.length}');
      if (audioTracks.isEmpty) {
        _debug('getUserMedia audio failure reason=no_audio_track');
        _debug('local audio track skipped reason=mic_unavailable');
        await _safeDisposeStream(stream, 'desktop incoming empty mic');
        return null;
      }
      _muted = false;
      for (final track in audioTracks) {
        track.enabled = true;
        _trace(
          'desktop incoming local audio track id=${_short(track.id ?? '')} '
          'enabled=${track.enabled} muted=${track.muted} '
          'settings=${_safeTrackSettings(track)}',
        );
      }
      _debug('getUserMedia audio success tracks=${audioTracks.length}');
      return stream;
    } catch (error) {
      _debug('getUserMedia audio failure error=$error');
      _debug('local audio track skipped reason=mic_unavailable');
      _trace('desktop incoming microphone setup failed: $error');
      return null;
    }
  }

  Future<void> _attachDesktopIncomingMicStreamLikeVoiceCall(
    MediaStream stream,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.fuchsia) {
      return;
    }
    try {
      await _ensureRenderersReady('desktop incoming mic local stream attach');
      await _localRenderer.setSrcObject(stream: stream);
      _debug(
        'desktop incoming mic stream attached like voice call '
        'audioTracks=${stream.getAudioTracks().length} '
        '${_rendererSummary(_localRenderer, 'localRenderer')}',
      );
      await _awaitWebRtcStep('select audio output', _selectDesktopAudioOutput);
    } catch (error) {
      _trace('desktop incoming mic local stream attach failed: $error');
    }
  }

  Future<void> _logIncomingAudioSenderCountAfterAddTrack() async {
    final pc = _pc;
    if (pc == null) {
      _trace('audio sender count after addTrack skipped reason=no_pc');
      return;
    }
    try {
      final senders = await pc.getSenders();
      final audioSenders =
          senders.where((sender) => sender.track?.kind == 'audio').toList();
      _debug('audio sender count after addTrack=${audioSenders.length}');
    } catch (error) {
      _trace('audio sender count after addTrack failed: $error');
    }
  }

  Future<void> _addDesktopReceiveOnlyTransceivers(RTCPeerConnection pc,
      {bool includeAudio = true}) async {
    if (includeAudio) {
      await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: RTCRtpTransceiverInit(
          direction: TransceiverDirection.RecvOnly,
        ),
      );
      _debug('receive-only audio transceiver added');
    }
    await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(
        direction: TransceiverDirection.RecvOnly,
      ),
    );
    _debug('receive-only video transceiver added');
  }

  void _installDesktopIncomingPeerHandlers(
    RTCPeerConnection pc,
    int generation,
  ) {
    pc.onTrack = (RTCTrackEvent event) {
      if (!_isCurrentCallGeneration(generation, 'onTrack')) {
        return;
      }
      if (kDebugMode) {
        debugPrint('[CallService] onTrack: ${event.track.kind}');
      }
      event.track.enabled = true;
      _trace(
        'onTrack kind=${event.track.kind} id=${_short(event.track.id ?? '')} '
        'enabled=${event.track.enabled} muted=${event.track.muted} '
        'streams=${event.streams.length}',
      );
      if (kIsWeb) {
        final streamId =
            event.streams.isNotEmpty ? _short(event.streams[0].id) : 'none';
        _webVideo(
          'onTrack kind=${event.track.kind} '
          'track=${_short(event.track.id ?? '')} '
          'enabled=${event.track.enabled} muted=${event.track.muted} '
          'stream=$streamId',
        );
      }
      if (event.streams.isNotEmpty) {
        if (kIsWeb && event.track.kind == 'video') {
          _installRemoteVideoTrackDiagnostics(
            event.track,
            event.streams[0],
            generation,
          );
        }
        unawaited(_attachRemoteStreamForPlayback(event.streams[0], generation));
        final remoteAudioTracks = event.streams[0].getAudioTracks();
        final remoteVideoTracks = event.streams[0].getVideoTracks();
        _remoteAudioTrackCount = remoteAudioTracks.length;
        _remoteVideoTrackCount = remoteVideoTracks.length;
        _webVideo(
          'remote stream tracks stream=${_short(event.streams[0].id)} '
          'audio=${remoteAudioTracks.length} video=${remoteVideoTracks.length}',
        );
        if (remoteAudioTracks.isNotEmpty) {
          _debug(
              'remote audio track received count=${remoteAudioTracks.length}');
        }
        if (remoteVideoTracks.isNotEmpty) {
          _debug(
              'remote video track received count=${remoteVideoTracks.length}');
        }
        for (final track in remoteAudioTracks) {
          track.enabled = true;
          _trace(
            'remote audio track id=${_short(track.id ?? '')} '
            'enabled=${track.enabled} muted=${track.muted} '
            'readyState=${_trackReadyState(track)}',
          );
        }
      } else {
        _trace('onTrack without stream kind=${event.track.kind}');
      }
    };
    pc.onIceCandidate = (candidate) {
      if (!_isCurrentCallGeneration(generation, 'onIceCandidate')) {
        return;
      }
      if (candidate.candidate == null) return;
      if (!_firstLocalIceCandidateLogged) {
        _firstLocalIceCandidateLogged = true;
        _debug('first ICE candidate local');
      }
      _sendSignal({
        'type': 'call_ice_candidate',
        'callId': _activeCallId,
        'toUserId': _remotePeerId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
      _trace('ICE candidate sent mid=${candidate.sdpMid ?? ''}');
    };
    pc.onConnectionState = (s) {
      if (!_isCurrentCallGeneration(generation, 'onConnectionState')) {
        return;
      }
      if (kDebugMode) {
        debugPrint('[CallService] PC state: $s');
      }
      _connectionState = s.name;
      _debug('peerConnectionState=$s');
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _debug('ICE connected');
        _markIceConnected();
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _debug('ICE failed');
        _failActiveCall(_callConnectionFailedMessage());
      } else if (s ==
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _startIceDisconnectedTimer();
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _cancelIceTimers();
      }
    };
    pc.onIceConnectionState = (s) {
      if (!_isCurrentCallGeneration(generation, 'onIceConnectionState')) {
        return;
      }
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
  }

  Future<void> _forceDesktopIncomingAudioSenderEnabled(String label) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.fuchsia) {
      return;
    }
    _muted = false;
    final localTracks = _localStream?.getAudioTracks() ?? const [];
    for (final track in localTracks) {
      final before = track.enabled;
      track.enabled = true;
      _debug(
        'desktop incoming mic local track enabled $before->true label=$label '
        'id=${_short(track.id ?? '')}',
      );
    }
    final pc = _pc;
    if (pc == null) {
      _trace(
          'incoming call audio sender verify skipped reason=no_peer_connection');
      return;
    }
    try {
      final senders = await pc.getSenders();
      final audioSenders =
          senders.where((sender) => sender.track?.kind == 'audio').toList();
      _debug('incoming call audio sender count=${audioSenders.length}');
      for (final sender in audioSenders) {
        final track = sender.track;
        if (track == null) {
          continue;
        }
        final before = track.enabled;
        track.enabled = true;
        _debug(
          'incoming call audio sender enabled=${track.enabled} before=$before '
          'id=${_short(track.id ?? '')}',
        );
      }
    } catch (error) {
      _trace('incoming call audio sender verify failed: $error');
    }
  }

  void _scheduleDesktopIncomingMicActivationAfterIce() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.fuchsia) {
      return;
    }
    if (_activeCallDirection != CallDirection.incoming) {
      _trace('mic activation pulse skipped reason=not_incoming_call');
      return;
    }
    if (_desktopIncomingMicActivationAfterIceScheduled) {
      _trace('mic activation pulse skipped reason=already_scheduled');
      return;
    }
    final generation = _callGeneration;
    if (!_desktopIncomingAnswerSent) {
      _trace('mic activation pulse skipped reason=answer_not_sent');
      return;
    }
    if (!_iceConnected) {
      _trace('mic activation pulse skipped reason=ice_not_connected');
      return;
    }
    if (!_isCurrentCallGeneration(generation, 'schedule mic pulse after ICE')) {
      _trace('mic activation pulse skipped reason=stale_call');
      return;
    }
    _desktopIncomingMicActivationAfterIceScheduled = true;
    _debug('mic activation pulse scheduled after ICE connected');
    unawaited(_runDesktopIncomingMicActivationAfterIce(generation));
  }

  Future<void> _runDesktopIncomingMicActivationAfterIce(int generation) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!_isCurrentCallGeneration(generation, 'mic pulse after ICE')) {
      _trace('mic activation pulse skipped reason=stale_call');
      return;
    }
    if (_state == CallState.idle ||
        _state == CallState.ended ||
        _state == CallState.failed ||
        _callTerminating) {
      _trace('mic activation pulse skipped reason=stale_call');
      return;
    }
    final localTracks = _localStream?.getAudioTracks() ?? const [];
    if (localTracks.isEmpty) {
      _trace('mic activation pulse skipped reason=no_track');
      return;
    }
    if (_muted) {
      _trace('mic activation pulse skipped reason=user_muted');
      return;
    }
    _debug('mic activation pulse executed');
    final baseline = await _currentOutboundAudioBytes();
    final senders = await _desktopAudioSendersForWarmup();
    for (final track in localTracks) {
      track.enabled = false;
    }
    for (final sender in senders) {
      final track = sender.track;
      if (track != null) {
        track.enabled = false;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!_isCurrentCallGeneration(generation, 'mic pulse after ICE enable')) {
      _trace('mic activation pulse skipped reason=stale_call');
      return;
    }
    if (_muted) {
      _trace('mic activation pulse skipped reason=user_muted');
      return;
    }
    for (final track in localTracks) {
      final before = track.enabled;
      track.enabled = true;
      _debug(
        'track enabled false->true after ICE before=$before id=${_short(track.id ?? '')}',
      );
    }
    final refreshedSenders = await _desktopAudioSendersForWarmup();
    for (final sender in refreshedSenders) {
      final track = sender.track;
      if (track == null) {
        continue;
      }
      final before = track.enabled;
      track.enabled = true;
      _debug(
        'sender track enabled false->true after ICE before=$before id=${_short(track.id ?? '')}',
      );
    }
    unawaited(_logDesktopIncomingAfterIceOutboundDelta(generation, baseline));
  }

  Future<void> _logDesktopIncomingAfterIceOutboundDelta(
    int generation,
    int? baseline,
  ) async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!_isCurrentCallGeneration(
      generation,
      'desktop incoming mic after ICE outbound check',
    )) {
      _trace('mic activation pulse skipped reason=stale_call');
      return;
    }
    final outboundBytes = await _currentOutboundAudioBytes();
    final delta = outboundBytes == null || baseline == null
        ? 0
        : outboundBytes - baseline;
    _debug(
      'outboundAudio bytes delta after 3s bytes=${outboundBytes ?? 0} '
      'delta=$delta',
    );
    _debug(
      'outboundAudio bytes after pulse bytes=${outboundBytes ?? 0} '
      'delta=$delta',
    );
    _debug(
      'outboundAudio bytes after ICE pulse bytes=${outboundBytes ?? 0} '
      'delta=$delta',
    );
    if (delta <= 0 && !_muted) {
      _debug(
          'outbound audio not flowing after ICE pulse despite enabled track');
    }
  }

  Future<List<RTCRtpSender>> _desktopAudioSendersForWarmup() async {
    final pc = _pc;
    if (pc == null) {
      return const [];
    }
    try {
      final senders = await pc.getSenders();
      return senders.where((sender) => sender.track?.kind == 'audio').toList();
    } catch (error) {
      _trace('desktop incoming mic after ICE sender lookup failed: $error');
      return const [];
    }
  }

  void _scheduleDesktopIncomingOutboundAudioDeltaCheck(int generation) {
    unawaited(Future<void>(() async {
      final baseline = await _currentOutboundAudioBytes();
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!_isCurrentCallGeneration(
        generation,
        'desktop incoming outbound audio 3s check',
      )) {
        return;
      }
      if (kIsWeb ||
          defaultTargetPlatform != TargetPlatform.fuchsia ||
          _muted ||
          _pc == null) {
        return;
      }
      try {
        final outboundBytes = await _currentOutboundAudioBytes();
        final delta = outboundBytes == null || baseline == null
            ? 0
            : outboundBytes - baseline;
        _debug(
          'outboundAudio bytes delta after 3s bytes=${outboundBytes ?? 0} '
          'delta=$delta',
        );
        _updateOutboundAudioFlowWatch(delta: delta);
      } catch (error) {
        _trace('outboundAudio bytes delta after 3s failed: $error');
      }
    }));
  }

  Future<int?> _currentOutboundAudioBytes() async {
    final pc = _pc;
    if (pc == null) {
      return null;
    }
    final stats = await pc.getStats();
    int? outboundBytes;
    for (final report in stats) {
      if (report.type != 'outbound-rtp') {
        continue;
      }
      final values = report.values;
      final kind = values['kind'] ?? values['mediaType'];
      if (kind != 'audio') {
        continue;
      }
      outboundBytes = _asInt(values['bytesSent']) ?? outboundBytes;
    }
    return outboundBytes;
  }

  void _reset() {
    final callId = _activeCallId ?? incomingCall?.callId;
    if (callId != null) {
      unawaited(FirebasePushService.instance.cancelCallNotifications(callId));
    }
    _rememberFinishedCallId(callId);
    _callTerminating = true;
    _callGeneration++;
    _cancelIceTimers();
    _cancelCallAnswerTimer();
    _cancelIncomingOfferTimer();
    _stopPlaybackStatsTimer();
    _debug('UI released');
    _pendingRemoteCandidates.clear();
    _remoteDescriptionSet = false;
    _acceptedSignalHandled = false;
    _localOfferInProgress = false;
    _localOfferSent = false;
    _remoteAnswerApplied = false;
    final desktopOfferCompleter = _desktopOfferCompleter;
    if (desktopOfferCompleter != null && !desktopOfferCompleter.isCompleted) {
      desktopOfferCompleter.completeError(StateError('call reset'));
    }
    _desktopOfferCompleter = null;
    _desktopPendingOfferCallId = null;
    _desktopPendingOfferSdp = null;
    _remoteStream = null;
    _remotePlaybackAttachFuture = null;
    _remotePlaybackAttachLatestStream = null;
    _remotePlaybackAttachCallId = null;
    _remotePlaybackAttachStreamId = null;
    _remotePlaybackAttachedCallId = null;
    _remotePlaybackAttachedStreamId = null;
    _remoteVideoRendererAttachedLogged = false;
    _remoteVideoViewRevisionMs = 0;
    _inboundVideoFramesDecoded = 0;
    _inboundVideoFramesReceived = 0;
    _inboundVideoFrameWidth = 0;
    _inboundVideoFrameHeight = 0;
    _connectionState = 'not_created';
    _iceConnectionState = 'not_created';
    _iceConnected = false;
    _desktopIncomingMicActivationAfterIceScheduled = false;
    _desktopIncomingAnswerSent = false;
    _resetWebVoiceCallDiagnostics();
    _localAudioTrackCount = 0;
    _localVideoTrackCount = 0;
    _remoteAudioTrackCount = 0;
    _remoteVideoTrackCount = 0;
    _activeCallId = null;
    _remotePeerId = null;
    _remotePeerNickname = null;
    _activeCallDirection = null;
    _activeCallTimestampMs = null;
    _connectedAtMs = null;
    incomingCall = null;
    _muted = false;
    _videoEnabled = false;
    _receiveVideoOnly = false;
    _remoteRendererViewMounted = false;
    _remoteRendererViewVisible = false;
    debugEvents.value = const [];
    _setState(CallState.idle);
    unawaited(_closePeerConnection());
  }

  void _setState(CallState s) {
    if (_state == s) {
      return;
    }
    final old = _state;
    _state = s;
    DiagnosticService.instance
        .log('call state transition ${old.name} -> ${s.name}');
    if (s == CallState.connecting ||
        s == CallState.active ||
        s == CallState.connected) {
      final callId = _activeCallId ?? incomingCall?.callId;
      if (callId != null && callId.isNotEmpty) {
        markIncomingCallState(
          callId,
          s == CallState.connecting
              ? IncomingCallDisposition.connecting
              : IncomingCallDisposition.active,
          source: 'call_service_${s.name}',
        );
        if (s == CallState.active || s == CallState.connected) {
          _debug('active call state entered callId=${_short(callId)}');
        }
        _debug(
            'active call entered, incoming notification cancelled callId=${_short(callId)}');
        unawaited(FirebasePushService.instance.cancelCallNotifications(callId));
      }
    }
    onStateChange?.call(s);
    for (final listener in List<void Function(CallState)>.from(
      _stateListeners,
    )) {
      listener(s);
    }
  }

  void _notifyMediaListeners() {
    for (final listener in List<void Function()>.from(_mediaListeners)) {
      listener();
    }
  }

  void _rememberFinishedCallId(String? callId) {
    if (callId == null || callId.isEmpty) {
      return;
    }
    final current = _incomingCallStates[callId];
    if (current != IncomingCallDisposition.active &&
        current != IncomingCallDisposition.ended &&
        current != IncomingCallDisposition.declined &&
        current != IncomingCallDisposition.cancelled &&
        current != IncomingCallDisposition.missed) {
      markIncomingCallState(
        callId,
        IncomingCallDisposition.ended,
        source: 'reset',
      );
    }
    _finishedCallIds.add(callId);
    _pendingIncomingCallIds.remove(callId);
    if (_finishedCallIds.length > 24) {
      final oldest = _finishedCallIds.first;
      _finishedCallIds.remove(oldest);
      _handledIncomingCallIds.remove(oldest);
      _missedIncomingCallIds.remove(oldest);
      _incomingCallStates.remove(oldest);
    }
  }

  void _emitMissedIncomingOnce(IncomingCallInfo info, String reason) {
    if (_missedIncomingCallIds.contains(info.callId)) {
      _debug('duplicate ignored callId=${_short(info.callId)}');
      return;
    }
    _missedIncomingCallIds.add(info.callId);
    _pendingIncomingCallIds.remove(info.callId);
    markIncomingCallState(
      info.callId,
      IncomingCallDisposition.missed,
      source: reason,
    );
    onMissedCall?.call(info, reason);
  }

  void _handleError(String msg) {
    _lastError = msg;
    DiagnosticService.instance.log('call error $msg');
    if (kDebugMode) {
      debugPrint('[CallService] ERROR: $msg');
    }
    try {
      _safeReportCallError(msg);
    } finally {
      _reset();
      _callStopFix('state reset after failure');
      _callStopFix('ready for next call');
    }
  }

  void _failActiveCall(
    String message, {
    CallStatus status = CallStatus.failedNetwork,
  }) {
    if (_state == CallState.idle ||
        _state == CallState.ended ||
        _state == CallState.failed) {
      return;
    }
    _callTerminating = true;
    _callGeneration++;
    _emitCallHistory(status: status);
    _setState(CallState.failed);
    _handleError(message);
  }

  String _callConnectionFailedMessage() => _iceConfigHasTurn
      ? 'Call connection failed. Please check network or server TURN configuration.'
      : 'Call connection failed. Network may block peer-to-peer calls or TURN is required.';

  String _userUnavailableMessage() =>
      'User is unavailable. Open Hestia on the other device to receive calls.';

  void _startIceConnectionTimer() {
    if (_iceConnected ||
        _state == CallState.idle ||
        _state == CallState.ended) {
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
    _webVoice('ICE connected');
    _connectedAtMs ??= DateTime.now().millisecondsSinceEpoch;
    _emitCallHistory(status: CallStatus.connected);
    _iceConnectionTimer?.cancel();
    _iceConnectionTimer = null;
    _iceDisconnectedTimer?.cancel();
    _iceDisconnectedTimer = null;
    if (_state == CallState.connecting || _state == CallState.connected) {
      _setState(CallState.active);
      _debug(_receiveVideoOnly ? 'call active receive-only' : 'call active');
    }
    unawaited(_logAudioSenders('media path connected'));
    _scheduleDesktopIncomingMicActivationAfterIce();
    _startPlaybackStatsTimer();
  }

  void _cancelIceTimers() {
    _iceConnectionTimer?.cancel();
    _iceConnectionTimer = null;
    _iceDisconnectedTimer?.cancel();
    _iceDisconnectedTimer = null;
  }

  void _startPlaybackStatsTimer() {
    if (kDebugMode || kIsWeb) {
      unawaited(_logPlaybackStats());
    }
    final shouldPollStats = kIsWeb || _isDesktopReceiveVideoOnlyActive;
    if (!shouldPollStats || _playbackStatsTimer != null) {
      return;
    }
    _playbackStatsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_logPlaybackStats());
    });
  }

  void _stopPlaybackStatsTimer() {
    _playbackStatsTimer?.cancel();
    _playbackStatsTimer = null;
    _lastInboundAudioBytes = null;
    _lastOutboundAudioBytes = null;
    _lastInboundVideoBytes = null;
    _outboundAudioZeroSince = null;
    _outboundAudioZeroWarningLogged = false;
    _webInboundAudioZeroSince = null;
    _webInboundAudioHintLogged = false;
  }

  void _emitCallEndHistory() {
    if (_activeCallId == null || _remotePeerId == null) {
      return;
    }
    final wasConnected = _connectedAtMs != null ||
        _state == CallState.active ||
        _state == CallState.connected;
    final status =
        wasConnected ? CallStatus.completed : CallStatus.canceledByCaller;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final durationSeconds = wasConnected
        ? ((nowMs - (_connectedAtMs ?? nowMs)) / 1000).round().clamp(0, 86400)
        : null;
    _emitCallHistory(
      status: status,
      timestampMs: _activeCallTimestampMs ?? nowMs,
      durationSeconds: durationSeconds,
    );
  }

  void _emitCallHistory({
    required CallStatus status,
    int? timestampMs,
    int? durationSeconds,
  }) {
    final callId = _activeCallId;
    final peerUserId = _remotePeerId;
    final direction = _activeCallDirection;
    if (callId == null || peerUserId == null || direction == null) {
      return;
    }
    onCallHistoryEvent?.call(CallHistoryEvent(
      callId: callId,
      peerUserId: peerUserId,
      peerNickname: _remotePeerNickname ?? '',
      direction: direction,
      status: status,
      isVideo: isVideoEnabled,
      timestampMs: timestampMs ??
          _activeCallTimestampMs ??
          DateTime.now().millisecondsSinceEpoch,
      durationSeconds: durationSeconds,
    ));
  }

  void _startCallAnswerTimer() {
    _callAnswerTimer?.cancel();
    _callAnswerTimer = Timer(_callAnswerTimeout, () {
      if (_state != CallState.calling && _state != CallState.ringing) {
        return;
      }
      _debug(
        'call answer timeout after ${_callAnswerTimeout.inSeconds}s; recipient unavailable',
      );
      if (_remotePeerId != null && _activeCallId != null) {
        _sendSignal({
          'type': 'call_hangup',
          'callId': _activeCallId,
          'toUserId': _remotePeerId,
          'reason': 'timeout',
        });
      }
      _failActiveCall(
        _userUnavailableMessage(),
        status: CallStatus.failedTimeout,
      );
    });
  }

  void _cancelCallAnswerTimer() {
    _callAnswerTimer?.cancel();
    _callAnswerTimer = null;
  }

  void _startIncomingOfferTimer(IncomingCallInfo info) {
    _incomingOfferTimer?.cancel();
    final remainingMs = info.callOfferTtlMs - info.ageMs;
    final delay = Duration(
      milliseconds: remainingMs.clamp(0, info.callOfferTtlMs).toInt(),
    );
    _incomingOfferTimer = Timer(delay, () {
      if (_state != CallState.incoming || incomingCall?.callId != info.callId) {
        return;
      }
      _debug('incoming call timeout callId=${_short(info.callId)}');
      _emitMissedIncomingOnce(info, 'expired');
      _sendSignal({
        'type': 'call_reject',
        'callId': info.callId,
        'toUserId': info.fromUserId,
        'reason': 'expired',
      });
      _reset();
    });
  }

  void _cancelIncomingOfferTimer() {
    _incomingOfferTimer?.cancel();
    _incomingOfferTimer = null;
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
    _debug('microphone permission request start video=$video');
    _webVoice('mic permission requested');
    final microphone = await Permission.microphone.request();
    _debug(
      'microphone permission result granted=${microphone.isGranted} '
      'denied=${microphone.isDenied} permanentlyDenied=${microphone.isPermanentlyDenied}',
    );
    _webVoice(
      microphone.isGranted ? 'mic permission granted' : 'mic permission denied',
    );
    if (!microphone.isGranted) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia) {
        throw Exception(
          'Microphone unavailable. Check Desktop microphone permissions.',
        );
      }
      if (microphone.isPermanentlyDenied) {
        throw Exception(
          'Microphone permission is disabled. Enable microphone access in Android settings.',
        );
      }
      throw Exception('microphone_permission_required_for_calls');
    }
    if (video) {
      if (kIsWeb) {
        _webVideo('camera permission requested');
        return;
      }
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia) {
        await _ensureDesktopCameraAvailable();
        return;
      }
      _debug('camera permission request start');
      final camera = await Permission.camera.request();
      _debug(
        'camera permission result granted=${camera.isGranted} '
        'denied=${camera.isDenied} permanentlyDenied=${camera.isPermanentlyDenied}',
      );
      if (!camera.isGranted) {
        if (camera.isPermanentlyDenied) {
          throw Exception(
            'Camera permission is disabled. Enable camera access in Android settings.',
          );
        }
        throw Exception('camera_permission_required_for_video_calls');
      }
    }
  }

  Future<void> _ensureDesktopCameraAvailable() async {
    final cameras = await _enumerateDesktopCamerasWithRetry();
    if (cameras.isEmpty) {
      throw Exception('no_camera_found');
    }
  }

  Future<void> _logDesktopAudioDevices(
    String phase,
    void Function(String message) add,
  ) async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      add('enumerateDevices phase="$phase" total=${devices.length}');
      final audioInputs =
          devices.where((device) => device.kind == 'audioinput').toList();
      final audioOutputs =
          devices.where((device) => device.kind == 'audiooutput').toList();
      final labelsEmpty = devices.every((device) => device.label.isEmpty);
      add('labelsEmpty phase="$phase" value=$labelsEmpty');
      add('audioInputCount phase="$phase" count=${audioInputs.length}');
      add('audioOutputCount phase="$phase" count=${audioOutputs.length}');
      add(
        'defaultCommunicationsDeviceExists phase="$phase" value=${audioInputs.isNotEmpty ? 'unknown_has_audioinput' : 'no_audioinput_visible'}',
      );
      for (var i = 0; i < devices.length; i++) {
        final device = devices[i];
        add(
          'device[$i] phase="$phase" kind=${device.kind} '
          'label=${device.label.isEmpty ? '<empty>' : device.label} '
          'deviceId=${_short(device.deviceId)}',
        );
      }
      final helperInputs = await Helper.enumerateDevices('audioinput');
      add('Helper.enumerateDevices(audioinput) count=${helperInputs.length}');
      final helperOutputs = await Helper.audiooutputs;
      add('Helper.audiooutputs count=${helperOutputs.length}');
    } catch (error) {
      add('enumerateDevices phase="$phase" exception=$error');
    }
  }

  Future<String> _isRunningElevatedAdmin() async {
    if (defaultTargetPlatform != TargetPlatform.fuchsia) {
      return 'not_desktop';
    }
    try {
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-Command',
          r'$p=[Security.Principal.DesktopPrincipal][Security.Principal.DesktopIdentity]::GetCurrent(); $p.IsInRole([Security.Principal.DesktopBuiltInRole]::Administrator)',
        ],
      ).timeout(const Duration(seconds: 4));
      final stdout = result.stdout.toString().trim();
      final stderr = result.stderr.toString().trim();
      if (result.exitCode == 0 && stdout.isNotEmpty) {
        return stdout;
      }
      return 'unknown exitCode=${result.exitCode} stderr=$stderr';
    } catch (error) {
      return 'unknown error=$error';
    }
  }

  String _firstStackLine(StackTrace stack) {
    final text = stack.toString().trim();
    if (text.isEmpty) {
      return 'none';
    }
    final newline = text.indexOf('\n');
    return newline == -1 ? text : text.substring(0, newline);
  }

  Future<Object> _audioConstraints() async {
    final constraints = <String, dynamic>{
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    };
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.fuchsia) {
      return constraints;
    }
    unawaited(_logDesktopAudioInputDiagnostics());
    _debug('desktop getUserMedia default audio constraints');
    _debug('no sourceId/deviceId used');
    return constraints;
  }

  Future<Object> _videoConstraints() async {
    final constraints = <String, dynamic>{
      'facingMode': 'user',
      'width': {'ideal': _videoWidth, 'max': _videoWidth},
      'height': {'ideal': _videoHeight, 'max': _videoHeight},
      'frameRate': {'ideal': _videoFrameRate, 'max': _videoFrameRate},
    };
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.fuchsia) {
      return constraints;
    }
    final camera = await _selectDesktopCamera();
    if (camera == null || camera.deviceId.isEmpty) {
      throw Exception('no_camera_found');
    }
    constraints['optional'] = [
      {'sourceId': camera.deviceId},
    ];
    return constraints;
  }

  Future<MediaDeviceInfo?> _selectDesktopCamera() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.fuchsia) {
      return null;
    }
    final cameras = await _enumerateDesktopCamerasWithRetry();
    if (cameras.isEmpty) {
      _debug('selected camera none reason=no_camera');
      return null;
    }
    final camera = cameras.first;
    _debug(
      'selected camera id=${_short(camera.deviceId)} '
      'label=${camera.label.isEmpty ? 'no_label' : camera.label}',
    );
    return camera;
  }

  Future<List<MediaDeviceInfo>> _enumerateDesktopCamerasWithRetry() async {
    var cameras = await Helper.enumerateDevices('videoinput');
    _debug('Desktop camera devices count=${cameras.length}');
    if (cameras.isNotEmpty) {
      return cameras;
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
    cameras = await Helper.enumerateDevices('videoinput');
    _debug('Desktop camera devices count=${cameras.length}');
    return cameras;
  }

  Future<void> _logDesktopAudioInputDiagnostics() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.fuchsia) {
      return;
    }
    try {
      final inputs = await _enumerateDesktopAudioInputsWithRetry();
      if (inputs.isEmpty) {
        _debug('enumerateDevices diagnostic only');
        return;
      }
      _debug(
        'enumerateDevices diagnostic only audioInputCount=${inputs.length}',
      );
    } catch (error) {
      _debug(
        'desktop audio input diagnostic skipped reason=enumerate_failed error=$error',
      );
    }
  }

  Future<List<MediaDeviceInfo>> _enumerateDesktopAudioInputsWithRetry() async {
    var inputs = await Helper.enumerateDevices('audioinput');
    _trace('desktop audio inputs count=${inputs.length}');
    if (inputs.isNotEmpty) {
      _debug('audio devices recovered yes inputCount=${inputs.length}');
      return inputs;
    }
    _debug('audio devices retry count=1 type=input');
    await Future<void>.delayed(const Duration(milliseconds: 800));
    inputs = await Helper.enumerateDevices('audioinput');
    _trace('desktop audio inputs count=${inputs.length}');
    _debug(
        'audio devices recovered ${inputs.isNotEmpty ? 'yes' : 'no'} inputCount=${inputs.length}');
    return inputs;
  }

  Future<void> _enableMobileAudioOutput() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.fuchsia) {
      _trace('speaker output skipped platform=$defaultTargetPlatform');
      return;
    }
    try {
      await Helper.setSpeakerphoneOn(true);
      _trace('speaker output enabled');
    } catch (error) {
      _trace('speaker output unchanged: $error');
    }
  }

  Future<void> _selectDesktopAudioOutput() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.fuchsia) {
      return;
    }
    try {
      final outputs = await Helper.audiooutputs;
      _trace('desktop audio outputs count=${outputs.length}');
      if (outputs.isEmpty) {
        _debug('audio devices retry count=1 type=output');
        await Future<void>.delayed(const Duration(milliseconds: 800));
      }
      final retriedOutputs =
          outputs.isEmpty ? await Helper.audiooutputs : outputs;
      _trace('desktop audio outputs count=${retriedOutputs.length}');
      _debug(
          'audio devices recovered ${retriedOutputs.isNotEmpty ? 'yes' : 'no'} outputCount=${retriedOutputs.length}');
      if (retriedOutputs.isEmpty) {
        _trace('desktop audio output select skipped: no devices');
        return;
      }
      final device = retriedOutputs.first;
      await Helper.selectAudioOutput(device.deviceId);
      _trace('desktop audio output selected');
    } catch (error) {
      _trace('desktop audio output select failed: $error');
    }
  }

  Future<void> _ensureRenderersReady(String reason) async {
    if (_isDesktopReceiveVideoOnlyActive) {
      await _ensureRemoteRendererReady(reason);
      return;
    }
    if (_localRendererDisposed) {
      _debug('renderer recreated reason=disposed target=local source=$reason');
      _localRenderer = RTCVideoRenderer();
      _localRendererDisposed = false;
      _rendererInitialized = false;
    }
    if (_remoteRendererDisposed) {
      _debug('renderer recreated reason=disposed target=remote source=$reason');
      _remoteRenderer = RTCVideoRenderer();
      _remoteRendererDisposed = false;
      _rendererInitialized = false;
    }
    if (_rendererInitialized) {
      _trace('renderers reused ${_rendererStateSummary()}');
      return;
    }

    await _awaitWebRtcStep(
        'local renderer initialize', _localRenderer.initialize);
    _trace('local renderer initialized textureId=${_localRenderer.textureId}');
    await _awaitWebRtcStep(
      'remote renderer initialize',
      _remoteRenderer.initialize,
    );
    _trace(
        'remote renderer initialized textureId=${_remoteRenderer.textureId}');
    _debug(
        'renderer initialized target=remote textureId=${_remoteRenderer.textureId}');
    _localRendererDisposed = false;
    _remoteRendererDisposed = false;
    _rendererInitialized = true;
  }

  Future<void> _ensureRemoteRendererReady(String reason) async {
    if (_remoteRendererDisposed) {
      _debug('renderer recreated reason=disposed target=remote source=$reason');
      _remoteRenderer = RTCVideoRenderer();
      _remoteRendererDisposed = false;
      _rendererInitialized = false;
    }
    if (!_remoteRendererDisposed && _remoteRenderer.textureId != null) {
      _debug('remote renderer init skipped reason=already_initialized');
      return;
    }
    _debug('local renderer skipped reason=desktop_receive_video_only');
    await _awaitWebRtcStep(
      'remote renderer initialize',
      _remoteRenderer.initialize,
    );
    _trace(
        'remote renderer initialized textureId=${_remoteRenderer.textureId}');
    _debug(
        'renderer initialized target=remote textureId=${_remoteRenderer.textureId}');
    _remoteRendererDisposed = false;
    _rendererInitialized = true;
  }

  Future<void> _closePeerConnection() {
    final runningCleanup = _cleanupFuture;
    if (runningCleanup != null) {
      _debug('cleanup already running ignored');
      return runningCleanup;
    }
    final cleanup = _closePeerConnectionBody();
    _cleanupFuture = cleanup;
    unawaited(cleanup.whenComplete(() {
      if (identical(_cleanupFuture, cleanup)) {
        _cleanupFuture = null;
        _debug('new call allowed after cleanup');
      }
    }));
    return cleanup;
  }

  Future<void> _closePeerConnectionBody() async {
    _debug('cleanup started generation=$_callGeneration');
    _debug('cleanup begin generation=$_callGeneration');
    _cancelIceTimers();
    _stopPlaybackStatsTimer();
    final localStream = _localStream;
    final remoteStream = _remoteStream;
    final pc = _pc;
    _localStream = null;
    _remoteStream = null;
    _pc = null;
    var stoppedTracks = 0;
    var disposedStreams = 0;
    if (localStream != null) {
      final hadLocalCameraTrack = localStream.getVideoTracks().isNotEmpty;
      stoppedTracks += _stopStreamTracks(localStream, 'local');
      _debug('local tracks stopped count=$stoppedTracks');
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        _debug('camera/mic tracks stopped count=$stoppedTracks');
      }
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.fuchsia &&
          hadLocalCameraTrack) {
        _debug('camera cleanup completed');
      }
      if (await _safeDisposeStream(localStream, 'local')) {
        disposedStreams++;
      }
    }
    if (_rendererInitialized) {
      _safeDetachRenderers('cleanup');
    }
    if (remoteStream != null && !identical(remoteStream, localStream)) {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia) {
        _debug('desktop remote stream dispose skipped reason=platform_safety');
      } else {
        stoppedTracks += _stopStreamTracks(remoteStream, 'remote');
        if (await _safeDisposeStream(remoteStream, 'remote')) {
          disposedStreams++;
        }
      }
    }
    if (pc != null) {
      try {
        pc.onTrack = null;
        pc.onIceCandidate = null;
        pc.onConnectionState = null;
        pc.onIceConnectionState = null;
        pc.onIceGatheringState = null;
        pc.onSignalingState = null;
      } catch (error) {
        _trace('pc callback detach failed: $error');
      }
      try {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          _debug('cleanup safe close start');
          final closed = await _awaitCleanupStep('pc.close', pc.close);
          _debug('cleanup safe close end');
          if (!closed) {
            _debug('pc close timeout/failed ignored');
          }
          await Future<void>.delayed(const Duration(milliseconds: 30));
        } else {
          final closed = await _awaitCleanupStep('pc.close', pc.close);
          _debug(closed ? 'pc close ok' : 'pc close timeout/failed ignored');
        }
      } catch (error) {
        _trace('pc close failed: $error');
      }
      try {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia) {
          _debug('cleanup safe dispose start');
          final disposed = await _awaitCleanupStep('pc.dispose', pc.dispose);
          _debug('cleanup safe dispose end');
          if (!disposed) {
            _debug('pc dispose timeout/failed ignored');
          }
        } else {
          final disposed = await _awaitCleanupStep('pc.dispose', pc.dispose);
          _debug(
              disposed ? 'pc dispose ok' : 'pc dispose timeout/failed ignored');
        }
      } catch (error) {
        _trace('pc dispose failed: $error');
      }
    }
    _debug(
      'cleanup end tracksStopped=$stoppedTracks streamsDisposed=$disposedStreams',
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _debug('camera/mic cleanup completed');
    }
    if (kIsWeb) {
      _webVideo('video cleanup completed');
    }
    _debug('call cleanup completed');
    _debug('cleanup completed');
  }

  void _handleDesktopOfferSdpForProbe(Map<String, dynamic> msg) {
    final callId = msg['callId'] as String? ?? '';
    final sdp = (msg['sdp'] as String?) ?? (msg['offer'] as String?) ?? '';
    if (callId.isEmpty || sdp.isEmpty) {
      _debug('desktop remote offer probe ignored reason=missing_sdp_or_callId');
      return;
    }
    _debug(
      'desktop remote offer probe received callId=${_short(callId)} stored incoming SDP offer yes',
    );
    final completer = _desktopOfferCompleter;
    if (completer != null &&
        !completer.isCompleted &&
        currentCallId == callId) {
      completer.complete(sdp);
      return;
    }
    _desktopPendingOfferCallId = callId;
    _desktopPendingOfferSdp = sdp;
    _debug('desktop remote offer probe stored incoming SDP offer yes');
  }

  Future<String> _awaitDesktopOfferSdp(String callId) async {
    if (_desktopPendingOfferCallId == callId &&
        _desktopPendingOfferSdp != null) {
      final sdp = _desktopPendingOfferSdp!;
      _desktopPendingOfferCallId = null;
      _desktopPendingOfferSdp = null;
      _debug('desktop remote offer probe using buffered offer');
      return sdp;
    }
    final completer = Completer<String>();
    _desktopOfferCompleter = completer;
    try {
      _debug(
        'desktop remote offer probe stored incoming SDP offer no; waiting for SDP offer',
      );
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException(
          'desktop remote offer probe timed out waiting for SDP offer',
        ),
      );
    } finally {
      if (identical(_desktopOfferCompleter, completer)) {
        _desktopOfferCompleter = null;
      }
    }
  }

  void _safeDetachRenderers(String reason) {
    if (_localRendererDisposed || _remoteRendererDisposed) {
      _debug(
        'renderer detach skipped reason=disposed source=$reason '
        'localDisposed=$_localRendererDisposed remoteDisposed=$_remoteRendererDisposed',
      );
      return;
    }
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia) {
        _trace('$reason detach renderers start');
        _localRenderer.srcObject = null;
        _remoteRenderer.srcObject = null;
        _trace('$reason detach renderers end');
        return;
      }
      _trace(
        '$reason detach renderers before '
        '${_rendererSummary(_localRenderer, 'localRenderer')} '
        '${_rendererSummary(_remoteRenderer, 'remoteRenderer')}',
      );
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
      _trace(
        '$reason detach renderers after '
        '${_rendererSummary(_localRenderer, 'localRenderer')} '
        '${_rendererSummary(_remoteRenderer, 'remoteRenderer')}',
      );
    } catch (error) {
      _trace('$reason renderer detach failed: $error');
    }
  }

  Future<bool> _awaitCleanupStep(
    String label,
    Future<void> Function() action,
  ) async {
    try {
      final future = action();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia) {
        await future.timeout(
          _desktopCleanupStepTimeout,
          onTimeout: () => throw TimeoutException(
            '$label timed out after ${_desktopCleanupStepTimeout.inMilliseconds}ms',
          ),
        );
      } else {
        await future;
      }
      return true;
    } on TimeoutException catch (error) {
      _debug('cleanup step timeout ignored label=$label error=$error');
      return false;
    } catch (error) {
      _trace('cleanup step failed label=$label error=$error');
      return false;
    }
  }

  int _stopStreamTracks(MediaStream stream, String label) {
    var stopped = 0;
    try {
      for (final track in stream.getTracks()) {
        try {
          track.stop();
          stopped++;
        } catch (error) {
          _trace('$label track stop failed: $error');
        }
      }
    } catch (error) {
      _trace('$label stream getTracks failed: $error');
    }
    return stopped;
  }

  Future<bool> _safeDisposeStream(MediaStream stream, String label) async {
    final streamId = stream.id;
    if (_disposedStreamIds.contains(streamId)) {
      _debug(
        'stream dispose ignored reason=already_disposed label=$label stream=${_short(streamId)}',
      );
      return false;
    }
    _debug('stream dispose start label=$label stream=${_short(streamId)}');
    try {
      final disposed =
          await _awaitCleanupStep('$label stream dispose', stream.dispose);
      if (disposed) {
        _disposedStreamIds.add(streamId);
        _debug('stream dispose end label=$label stream=${_short(streamId)}');
        return true;
      }
      _debug(
        'stream dispose ignored reason=timeout_or_failed label=$label stream=${_short(streamId)}',
      );
      return false;
    } catch (error) {
      final text = error.toString();
      if (text.contains('MediaStreamDisposeFailed') ||
          text.toLowerCase().contains('not found')) {
        _disposedStreamIds.add(streamId);
        _debug(
          'stream dispose ignored reason=not_found label=$label stream=${_short(streamId)}',
        );
        return false;
      }
      _trace('$label stream dispose failed: $error');
      return false;
    }
  }

  bool _isCurrentCallGeneration(int generation, String label) {
    final stale = generation != _callGeneration ||
        _callTerminating ||
        _state == CallState.idle ||
        _state == CallState.ended ||
        _state == CallState.failed;
    if (stale) {
      _debug(
        'late callback ignored reason=stale_call label=$label '
        'generation=$generation current=$_callGeneration state=$_state '
        'terminating=$_callTerminating',
      );
      return false;
    }
    return true;
  }

  void _debug(String message) {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '$stamp $message';
    if (kDebugMode) {
      debugPrint('[CallService] $message');
    }
    DiagnosticService.instance.log('webrtc $message');
    final next = [...debugEvents.value, entry];
    debugEvents.value =
        next.length > 12 ? next.sublist(next.length - 12) : next;
  }

  void _trace(String message) {
    if (kDebugMode) {
      debugPrint('[CallService] $message');
    }
  }

  Future<void> _attachRemoteStreamForPlayback(
    MediaStream stream,
    int generation,
  ) async {
    if (!_isCurrentCallGeneration(generation, 'remote stream attach')) {
      return;
    }
    if (kIsWeb && stream.getVideoTracks().isNotEmpty) {
      await _attachRemoteStreamForWebVideo(stream, generation);
      return;
    }
    if (_isDesktopReceiveVideoOnlyActive) {
      final callId = currentCallId;
      final streamId = stream.id;
      _remotePlaybackAttachLatestStream = stream;
      final runningAttach = _remotePlaybackAttachFuture;
      if (runningAttach != null &&
          _remotePlaybackAttachCallId == callId &&
          _remotePlaybackAttachStreamId == streamId) {
        _debug('remote attach skipped reason=already_in_progress');
        try {
          await runningAttach;
        } catch (_) {}
        if (_remoteRenderer.textureId != null) {
          _debug('remote renderer init skipped reason=already_initialized');
        }
        final videoTracks = stream.getVideoTracks();
        if (videoTracks.isNotEmpty && !_remoteVideoRendererAttachedLogged) {
          _remoteVideoRendererAttachedLogged = true;
          _debug('remote video renderer attached once');
        }
        return;
      }
      if (_remotePlaybackAttachedCallId == callId &&
          _remotePlaybackAttachedStreamId == streamId) {
        _remoteStream = stream;
        _debug('remote renderer init skipped reason=already_initialized');
        final videoTracks = stream.getVideoTracks();
        if (videoTracks.isNotEmpty && !_remoteVideoRendererAttachedLogged) {
          _remoteVideoRendererAttachedLogged = true;
          _debug('remote video renderer attached once');
        }
        return;
      }
      final attach = _attachRemoteStreamForPlaybackBody(
        stream,
        generation,
        coalesceTracks: true,
      );
      _remotePlaybackAttachFuture = attach;
      _remotePlaybackAttachCallId = callId;
      _remotePlaybackAttachStreamId = streamId;
      try {
        await attach;
      } finally {
        if (identical(_remotePlaybackAttachFuture, attach)) {
          _remotePlaybackAttachFuture = null;
          _remotePlaybackAttachCallId = null;
          _remotePlaybackAttachStreamId = null;
        }
      }
      return;
    }
    await _attachRemoteStreamForPlaybackBody(stream, generation);
  }

  void _installRemoteVideoTrackDiagnostics(
    MediaStreamTrack track,
    MediaStream stream,
    int generation,
  ) {
    if (!kIsWeb) {
      return;
    }
    final trackId = _short(track.id ?? '');
    final streamId = _short(stream.id);
    _webVideo(
      'remote video track diagnostics installed '
      'track=$trackId enabled=${track.enabled} muted=${track.muted} '
      'stream=$streamId readyState=${_trackReadyState(track)}',
    );
    track.onMute = () {
      _webVideo('remote video track muted track=$trackId stream=$streamId');
    };
    track.onUnMute = () {
      _webVideo('remote video track unmuted track=$trackId stream=$streamId');
      unawaited(_attachRemoteStreamForWebVideo(stream, generation));
    };
    track.onEnded = () {
      _webVideo('remote video track ended track=$trackId stream=$streamId');
    };
  }

  Future<void> _attachRemoteStreamForWebVideo(
    MediaStream stream,
    int generation,
  ) async {
    if (!kIsWeb ||
        !_isCurrentCallGeneration(generation, 'web video stream attach')) {
      return;
    }
    final videoTracks = stream.getVideoTracks();
    if (videoTracks.isEmpty) {
      _webVideo(
        'remote renderer refresh skipped reason=no_video_track '
        'stream=${_short(stream.id)}',
      );
      await _attachRemoteStreamForPlaybackBody(stream, generation);
      return;
    }
    _remoteStream = stream;
    _remoteAudioTrackCount = stream.getAudioTracks().length;
    _remoteVideoTrackCount = videoTracks.length;
    _webVideo(
      'remote renderer refresh start stream=${_short(stream.id)} '
      'audio=$_remoteAudioTrackCount video=$_remoteVideoTrackCount '
      'viewMounted=$_remoteRendererViewMounted '
      'viewVisible=$_remoteRendererViewVisible '
      '${_rendererSummary(_remoteRenderer, 'remoteRenderer')}',
    );
    for (final track in videoTracks) {
      track.enabled = true;
      _webVideo(
        'remote video track state track=${_short(track.id ?? '')} '
        'enabled=${track.enabled} muted=${track.muted} '
        'readyState=${_trackReadyState(track)}',
      );
    }
    try {
      await _ensureRenderersReady('web video remote stream attach');
      await _selectDesktopAudioOutput();
      if (!_isCurrentCallGeneration(generation, 'web video renderer detach')) {
        return;
      }
      _webVideo(
        'remoteRenderer srcObject assign phase=detach '
        'hadSrcObject=${_remoteRenderer.srcObject != null} '
        'viewMounted=$_remoteRendererViewMounted '
        'viewVisible=$_remoteRendererViewVisible',
      );
      _remoteRenderer.srcObject = null;
      _remoteVideoViewRevisionMs = DateTime.now().millisecondsSinceEpoch;
      _notifyMediaListeners();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!_isCurrentCallGeneration(
          generation, 'web video renderer reattach')) {
        return;
      }
      _webVideo(
        'remoteRenderer srcObject assign phase=reattach '
        'stream=${_short(stream.id)} video=${videoTracks.length} '
        'viewMounted=$_remoteRendererViewMounted '
        'viewVisible=$_remoteRendererViewVisible',
      );
      _remoteRenderer.srcObject = stream;
      await _remoteRenderer.setVolume(1.0);
      _remoteVideoViewRevisionMs = DateTime.now().millisecondsSinceEpoch;
      _notifyMediaListeners();
      _webVideo(
        'remote renderer refreshed stream=${_short(stream.id)} '
        '${_rendererSummary(_remoteRenderer, 'remoteRenderer')}',
      );
      unawaited(Future<void>.delayed(const Duration(milliseconds: 100), () {
        if (!_isCurrentCallGeneration(
            generation, 'web video delayed rebuild')) {
          return;
        }
        _remoteVideoViewRevisionMs = DateTime.now().millisecondsSinceEpoch;
        _webVideo('remote renderer delayed rebuild after refresh');
        _notifyMediaListeners();
      }));
    } catch (error) {
      _webVideo('remote renderer refresh failed error=$error');
      _recommendBrowserAudioUnlock('web_video_remote_attach_failed');
    }
    if (_isCurrentCallGeneration(generation, 'start playback stats')) {
      _startPlaybackStatsTimer();
    }
  }

  Future<void> _attachRemoteStreamForPlaybackBody(
    MediaStream stream,
    int generation, {
    bool coalesceTracks = false,
  }) async {
    if (coalesceTracks) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!_isCurrentCallGeneration(generation, 'remote stream attach')) {
        return;
      }
      stream = _remotePlaybackAttachLatestStream ?? stream;
    }
    _remoteStream = stream;
    final audioTracks = stream.getAudioTracks();
    final videoTracks = stream.getVideoTracks();
    _trace(
      'remote playback attach start stream=${_short(stream.id)} '
      'audio=${audioTracks.length} video=${videoTracks.length} '
      '${_rendererSummary(_remoteRenderer, 'remoteRenderer')}',
    );
    for (final track in audioTracks) {
      _trace(
        'remote playback audio track id=${_short(track.id ?? '')} '
        'enabled=${track.enabled} muted=${track.muted} '
        'readyState=${_trackReadyState(track)}',
      );
    }
    try {
      await _ensureRenderersReady('remote stream attach');
      await _selectDesktopAudioOutput();
      if (!_isCurrentCallGeneration(
          generation, 'remote renderer setSrcObject')) {
        return;
      }
      _webVideo(
        'remoteRenderer srcObject assign phase=playback '
        'stream=${_short(stream.id)} audio=${audioTracks.length} '
        'video=${videoTracks.length} viewMounted=$_remoteRendererViewMounted '
        'viewVisible=$_remoteRendererViewVisible',
      );
      await _remoteRenderer.setSrcObject(stream: stream);
      if (_isDesktopReceiveVideoOnlyActive) {
        _remotePlaybackAttachedCallId = currentCallId;
        _remotePlaybackAttachedStreamId = stream.id;
        _remoteVideoViewRevisionMs = DateTime.now().millisecondsSinceEpoch;
        _debug('RTCVideoView attached');
        _debug('renderer textureId=${_remoteRenderer.textureId}');
      }
      _notifyMediaListeners();
      if (_isDesktopReceiveVideoOnlyActive) {
        unawaited(Future<void>.delayed(const Duration(milliseconds: 100), () {
          if (!_isCurrentCallGeneration(
              generation, 'remote video delayed rebuild')) {
            return;
          }
          if (_remotePlaybackAttachedStreamId != stream.id) {
            return;
          }
          _remoteVideoViewRevisionMs = DateTime.now().millisecondsSinceEpoch;
          _debug('setState after attach delayed');
          _notifyMediaListeners();
        }));
      }
      try {
        if (!_isCurrentCallGeneration(
            generation, 'remote renderer setVolume')) {
          return;
        }
        await _remoteRenderer.setVolume(1.0);
        _trace('remote renderer volume set=1.0');
      } catch (error) {
        _trace('remote renderer volume set failed: $error');
      }
      _trace(
        'remote stream attached to remoteRenderer stream=${_short(stream.id)} '
        '${_rendererSummary(_localRenderer, 'localRenderer')} '
        '${_rendererSummary(_remoteRenderer, 'remoteRenderer')}',
      );
      if (videoTracks.isNotEmpty) {
        _webVideo('remote video attached');
        if (_isDesktopReceiveVideoOnlyActive) {
          if (!_remoteVideoRendererAttachedLogged) {
            _remoteVideoRendererAttachedLogged = true;
            _debug('remote video renderer attached once');
          }
        } else {
          _debug(
            'remote video renderer attached stream=${_short(stream.id)} '
            'videoTracks=${videoTracks.length}',
          );
        }
      }
    } catch (error) {
      _trace('remote playback attach failed: $error');
      _webVoice('browser audio unlock failure error=$error');
      _recommendBrowserAudioUnlock('remote_playback_attach_failed');
    }
    if (_isCurrentCallGeneration(generation, 'start playback stats')) {
      _startPlaybackStatsTimer();
    }
  }

  Future<void> _logPlaybackStats() async {
    final pc = _pc;
    if (pc == null ||
        _state == CallState.idle ||
        _state == CallState.failed ||
        _state == CallState.ended) {
      return;
    }
    try {
      await _logAudioSenders('playback stats');
      final stats = await pc.getStats();
      int? inboundBytes;
      int? packetsReceived;
      int? packetsLost;
      int? outboundBytes;
      int? packetsSent;
      Object? outboundAudioLevel;
      Object? outboundAudioEnergy;
      for (final report in stats) {
        if (report.type != 'inbound-rtp' && report.type != 'outbound-rtp') {
          continue;
        }
        final values = report.values;
        final kind = values['kind'] ?? values['mediaType'];
        if (kind != 'audio') {
          continue;
        }
        if (report.type == 'inbound-rtp') {
          inboundBytes = _asInt(values['bytesReceived']) ?? inboundBytes;
          packetsReceived =
              _asInt(values['packetsReceived']) ?? packetsReceived;
          packetsLost = _asInt(values['packetsLost']) ?? packetsLost;
        } else {
          outboundBytes = _asInt(values['bytesSent']) ?? outboundBytes;
          packetsSent = _asInt(values['packetsSent']) ?? packetsSent;
          outboundAudioLevel = values['audioLevel'] ?? outboundAudioLevel;
          outboundAudioEnergy =
              values['totalAudioEnergy'] ?? outboundAudioEnergy;
        }
      }
      if (inboundBytes == null) {
        _trace('playback stats no inbound audio ${_rendererStateSummary()}');
        _webVoice('inboundAudio bytes=0');
        _updateBrowserInboundAudioFlowWatch(delta: null);
      } else {
        final previous = _lastInboundAudioBytes;
        final delta = previous == null ? 0 : inboundBytes - previous;
        _lastInboundAudioBytes = inboundBytes;
        _webVoice('inboundAudio bytes=$inboundBytes');
        _updateBrowserInboundAudioFlowWatch(delta: delta);
        _trace(
          'playback stats inboundAudio bytes=$inboundBytes delta=$delta '
          'packets=$packetsReceived lost=$packetsLost '
          '${_rendererStateSummary()}',
        );
      }
      if (outboundBytes == null) {
        _trace('send stats no outbound audio');
        _webVoice('outboundAudio bytes=0');
        _updateOutboundAudioFlowWatch(delta: null);
      } else {
        final previous = _lastOutboundAudioBytes;
        final delta = previous == null ? 0 : outboundBytes - previous;
        _lastOutboundAudioBytes = outboundBytes;
        _webVoice('outboundAudio bytes=$outboundBytes');
        _trace(
          'send stats outboundAudio bytes=$outboundBytes delta=$delta '
          'packets=$packetsSent audioLevel=$outboundAudioLevel '
          'totalAudioEnergy=$outboundAudioEnergy',
        );
        _updateOutboundAudioFlowWatch(delta: delta);
      }
      if (kIsWeb || _isDesktopReceiveVideoOnlyActive) {
        _logInboundVideoDiagnostics(stats);
      }
    } catch (error) {
      _trace('playback stats unavailable: $error');
    }
  }

  void _updateBrowserInboundAudioFlowWatch({required int? delta}) {
    if (!kIsWeb ||
        _state == CallState.idle ||
        _state == CallState.ended ||
        _remoteAudioTrackCount == 0) {
      _webInboundAudioZeroSince = null;
      _webInboundAudioHintLogged = false;
      return;
    }
    if (delta != null && delta > 0) {
      _webInboundAudioZeroSince = null;
      _webInboundAudioHintLogged = false;
      if (_browserAudioUnlockRecommended) {
        _browserAudioUnlockRecommended = false;
        _notifyMediaListeners();
      }
      return;
    }
    final now = DateTime.now();
    _webInboundAudioZeroSince ??= now;
    if (!_webInboundAudioHintLogged &&
        now.difference(_webInboundAudioZeroSince!) >=
            const Duration(seconds: 5)) {
      _webInboundAudioHintLogged = true;
      _recommendBrowserAudioUnlock('inbound_audio_not_flowing');
    }
  }

  void _logInboundVideoDiagnostics(List<StatsReport> stats) {
    int? bytesReceived;
    int? framesDecoded;
    int? framesReceived;
    int? framesDropped;
    int? frameWidth;
    int? frameHeight;
    int? packetsReceived;
    int? packetsLost;
    Object? jitter;
    for (final report in stats) {
      if (report.type != 'inbound-rtp') {
        continue;
      }
      final values = report.values;
      final kind = values['kind'] ?? values['mediaType'];
      if (kind != 'video') {
        continue;
      }
      bytesReceived = _asInt(values['bytesReceived']) ?? bytesReceived;
      framesDecoded = _asInt(values['framesDecoded']) ?? framesDecoded;
      framesReceived = _asInt(values['framesReceived']) ?? framesReceived;
      framesDropped = _asInt(values['framesDropped']) ?? framesDropped;
      frameWidth = _asInt(values['frameWidth']) ?? frameWidth;
      frameHeight = _asInt(values['frameHeight']) ?? frameHeight;
      packetsReceived = _asInt(values['packetsReceived']) ?? packetsReceived;
      packetsLost = _asInt(values['packetsLost']) ?? packetsLost;
      jitter = values['jitter'] ?? jitter;
    }
    final previous = _lastInboundVideoBytes;
    if (bytesReceived != null) {
      _lastInboundVideoBytes = bytesReceived;
    }
    final previousFramesDecoded = _inboundVideoFramesDecoded;
    final previousFramesReceived = _inboundVideoFramesReceived;
    final previousFrameWidth = _inboundVideoFrameWidth;
    final previousFrameHeight = _inboundVideoFrameHeight;
    if (framesDecoded != null) {
      _inboundVideoFramesDecoded = framesDecoded;
    }
    if (framesReceived != null) {
      _inboundVideoFramesReceived = framesReceived;
    }
    if (frameWidth != null) {
      _inboundVideoFrameWidth = frameWidth;
    }
    if (frameHeight != null) {
      _inboundVideoFrameHeight = frameHeight;
    }
    if ((_inboundVideoFramesDecoded > 0 && previousFramesDecoded == 0) ||
        (_inboundVideoFramesReceived > 0 && previousFramesReceived == 0) ||
        _inboundVideoFrameWidth != previousFrameWidth ||
        _inboundVideoFrameHeight != previousFrameHeight) {
      _remoteVideoViewRevisionMs = DateTime.now().millisecondsSinceEpoch;
      _notifyMediaListeners();
    }
    final delta = bytesReceived == null || previous == null
        ? 0
        : bytesReceived - previous;
    final srcObjectPresent = remoteRendererHasSrcObject;
    final remoteVideoTracks = _remoteStream?.getVideoTracks() ?? const [];
    final trackStates = remoteVideoTracks.isEmpty
        ? 'none'
        : remoteVideoTracks
            .map((track) => 'enabled=${track.enabled} muted=${track.muted}')
            .join(',');
    final message =
        'inboundVideo bytesReceived=${bytesReceived ?? 0} delta=$delta '
        'framesDecoded=${framesDecoded ?? 0} '
        'framesReceived=${framesReceived ?? 0} '
        'framesDropped=${framesDropped ?? 0} '
        'frameWidth=${frameWidth ?? 0} frameHeight=${frameHeight ?? 0} '
        'packetsReceived=${packetsReceived ?? 0} '
        'packetsLost=${packetsLost ?? 0} jitter=${jitter ?? 0} '
        'remoteRenderer srcObject=${srcObjectPresent ? 'true' : 'false'} '
        'renderVideo=${_remoteRendererDisposed ? false : _remoteRenderer.renderVideo} '
        'streamAudio=${_remoteStream?.getAudioTracks().length ?? 0} '
        'streamVideo=${_remoteStream?.getVideoTracks().length ?? 0} '
        'remoteVideo=${remoteVideoTracks.length} '
        'viewMounted=$_remoteRendererViewMounted '
        'viewVisible=$_remoteRendererViewVisible '
        'remoteVideo track $trackStates';
    _debug(message);
    _webVideo(message);
  }

  void _updateOutboundAudioFlowWatch({required int? delta}) {
    if (!_isDesktopReceiveVideoOnlyActive || _muted) {
      _outboundAudioZeroSince = null;
      _outboundAudioZeroWarningLogged = false;
      return;
    }
    final hasEnabledLocalAudio =
        (_localStream?.getAudioTracks() ?? const []).any((track) {
      return track.enabled;
    });
    if (!hasEnabledLocalAudio) {
      _outboundAudioZeroSince = null;
      _outboundAudioZeroWarningLogged = false;
      return;
    }
    if (delta != null && delta > 0) {
      _outboundAudioZeroSince = null;
      _outboundAudioZeroWarningLogged = false;
      return;
    }
    final now = DateTime.now();
    _outboundAudioZeroSince ??= now;
    if (!_outboundAudioZeroWarningLogged &&
        now.difference(_outboundAudioZeroSince!) >=
            const Duration(seconds: 5)) {
      _outboundAudioZeroWarningLogged = true;
      _debug('outbound audio not flowing despite enabled track');
    }
  }

  Future<void> _logAudioSenders(String label) async {
    final pc = _pc;
    if (pc == null) {
      return;
    }
    try {
      final senders = await pc.getSenders();
      final audioSenders =
          senders.where((sender) => sender.track?.kind == 'audio').toList();
      _trace('$label audio senders=${audioSenders.length}');
      if (audioSenders.isEmpty) {
        return;
      }
      for (final sender in audioSenders) {
        final track = sender.track;
        _trace(
          '$label audio sender track=${_short(track?.id ?? '')} '
          'enabled=${track?.enabled} muted=${track?.muted} '
          'settings=${track == null ? 'none' : _safeTrackSettings(track)}',
        );
      }
    } catch (error) {
      _trace('$label audio sender inspect failed: $error');
    }
  }

  String _rendererStateSummary() {
    return _rendererSummary(_remoteRenderer, 'remoteRenderer');
  }

  String _rendererSummary(RTCVideoRenderer renderer, String name) {
    final disposed = name == 'localRenderer'
        ? _localRendererDisposed
        : _remoteRendererDisposed;
    if (disposed) {
      return '$name('
          'rendererInitialized=$_rendererInitialized '
          'rendererDisposed=true '
          'textureId=null '
          'srcObject=false '
          'remoteHeld=${_remoteStream != null} '
          'viewMounted=$_remoteRendererViewMounted '
          'viewVisible=$_remoteRendererViewVisible'
          ')';
    }
    MediaStream? stream;
    MediaStream? targetStream;
    try {
      stream = _remoteRendererDisposed ? null : _remoteRenderer.srcObject;
      targetStream = renderer.srcObject;
    } catch (error) {
      return '$name(rendererSummaryUnavailable error=$error)';
    }
    final audioCount = stream?.getAudioTracks().length ?? 0;
    final videoCount = stream?.getVideoTracks().length ?? 0;
    final targetAudioCount = targetStream?.getAudioTracks().length ?? 0;
    final targetVideoCount = targetStream?.getVideoTracks().length ?? 0;
    return '$name('
        'rendererInitialized=$_rendererInitialized '
        'rendererDisposed=$disposed '
        'textureId=${renderer.textureId} '
        'srcObject=${targetStream != null} '
        'renderVideo=${renderer.renderVideo} '
        'streamAudio=$targetAudioCount streamVideo=$targetVideoCount '
        'remoteHeld=${_remoteStream != null} '
        'remoteAudio=$audioCount remoteVideo=$videoCount '
        'viewMounted=$_remoteRendererViewMounted '
        'viewVisible=$_remoteRendererViewVisible'
        ')';
  }

  String _trackReadyState(MediaStreamTrack track) {
    try {
      final settings = track.getSettings();
      final readyState = settings['readyState'];
      if (readyState != null) {
        return '$readyState';
      }
    } catch (_) {
      // The native Desktop map has readyState, but the Dart interface may not.
    }
    return 'not_exposed';
  }

  String _safeTrackSettings(MediaStreamTrack track) {
    try {
      final settings = Map<String, dynamic>.from(track.getSettings());
      settings.remove('deviceId');
      settings.remove('groupId');
      return settings.toString();
    } catch (_) {
      return 'unavailable';
    }
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
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
    final reason = message['reason']?.toString() ?? '';
    final eventMessage = message['message']?.toString() ?? '';
    return [
      type,
      if (callId.isNotEmpty) 'callId=${_short(callId)}',
      if (peer.isNotEmpty) 'peer=${_short(peer)}',
      if (reason.isNotEmpty) 'reason=$reason',
      if (eventMessage.isNotEmpty) 'message=$eventMessage',
    ].join(' ');
  }

  String _short(String value) =>
      value.length <= 8 ? value : '${value.substring(0, 8)}...';

  int _callCreatedAtMs(Map<String, dynamic> message) {
    final value = message['serverTimestamp'] ?? message['callCreatedAt'];
    if (value is int) return _normalizeTimestampMs(value);
    if (value is num) return _normalizeTimestampMs(value.toInt());
    if (value is String) {
      final millis = int.tryParse(value);
      if (millis != null) return _normalizeTimestampMs(millis);
      return DateTime.tryParse(value)?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch;
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  int _normalizeTimestampMs(int value) {
    return value > 0 && value < 100000000000 ? value * 1000 : value;
  }

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
    var applied = false;
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
      try {
        await sender.setParameters(parameters);
        applied = true;
      } catch (error) {
        _debug('video bitrate applied no error=$error');
      }
    }
    _debug(
      'video bitrate applied ${applied ? 'yes' : 'no'} '
      'maxBitrateKbps=$_videoMaxBitrateKbps',
    );
  }

  Future<void> _addRemoteCandidate(RTCIceCandidate candidate) async {
    if (_pc == null) {
      return;
    }
    if (!_firstRemoteIceCandidateLogged) {
      _firstRemoteIceCandidateLogged = true;
      _debug('first ICE candidate remote');
    }
    _trace('ICE candidate received mid=${candidate.sdpMid}');
    if (!_remoteDescriptionSet) {
      _pendingRemoteCandidates.add(candidate);
      _trace('ICE candidate queued before remoteDescription');
      if (kDebugMode) {
        debugPrint('[CallService] queued ICE candidate before remote SDP');
      }
      return;
    }
    try {
      await _awaitWebRtcStep(
        'add remote ICE candidate',
        () => _pc!.addCandidate(candidate),
      );
      _trace('ICE candidate added mid=${candidate.sdpMid}');
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[CallService] addIceCandidate failed: $error');
      }
      _trace('ICE candidate add failed: $error');
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

  bool _messageMatchesActiveCall(Map<String, dynamic> message) {
    final callId = message['callId']?.toString() ?? '';
    if (callId.isEmpty) {
      return true;
    }
    if (_finishedCallIds.contains(callId)) {
      _debug(
        'stale signal ignored oldCallId=${_short(callId)} '
        'newCallId=${_short(_activeCallId ?? incomingCall?.callId ?? '')}',
      );
      return false;
    }
    final matches = callId == _activeCallId || callId == incomingCall?.callId;
    if (!matches) {
      _debug(
        'stale signal ignored oldCallId=${_short(callId)} '
        'newCallId=${_short(_activeCallId ?? incomingCall?.callId ?? '')}',
      );
    }
    return matches;
  }
}
