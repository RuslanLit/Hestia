// ─────────────────────────────────────────────────────────────────────────────
// CallScreen — shown during an active call
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hestia/l10n/l10n.dart';
import 'package:hestia/services/call_service.dart';
import 'package:hestia/services/diagnostic_service.dart';
import 'package:hestia/services/platform_capabilities.dart';
import 'package:hestia/widgets/motion.dart';

class CallScreen extends StatefulWidget {
  final String peerNickname;
  const CallScreen({super.key, required this.peerNickname});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _call = CallService.instance;
  AudioPlayer? _ringbackPlayer;
  late final void Function(CallState) _stateListener;
  late final VoidCallback _mediaListener;
  bool? _lastReportedRendererMounted;
  bool? _lastReportedRendererVisible;
  String? _lastVideoUiMetrics;
  Future<void>? _stopRingbackFuture;
  bool _ringbackStarted = false;

  bool get _needsDesktopAudioRenderer =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.fuchsia &&
      !_call.isVideoEnabled &&
      (_call.remoteAudioTrackCount > 0 ||
          _call.state == CallState.active ||
          _call.state == CallState.connected);
  bool get _needsBrowserAudioRenderer =>
      kIsWeb &&
      !_call.isVideoEnabled &&
      (_call.remoteAudioTrackCount > 0 ||
          _call.state == CallState.active ||
          _call.state == CallState.connected);
  bool get _disableAudioplayers =>
      !PlatformCapabilities.supportsAutomaticRingtonePlayback ||
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia);
  bool get _isDesktopVideoCall =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.fuchsia &&
      _call.isVideoEnabled;

  @override
  void initState() {
    super.initState();
    _stateListener = (s) {
      _syncRingback(s);
      if (s == CallState.idle || s == CallState.ended) {
        if (mounted) Navigator.of(context).pop();
      } else {
        if (mounted) setState(() {});
      }
    };
    _mediaListener = () {
      if (!mounted) {
        return;
      }
      DiagnosticService.instance.log('webrtc setState after attach');
      setState(() {});
    };
    _call.addStateListener(_stateListener);
    _call.addMediaListener(_mediaListener);
    _syncRingback(_call.state);
  }

  @override
  void dispose() {
    _call.reportRemoteRendererView(
      mounted: false,
      visible: false,
      reason: 'CallScreen.dispose',
    );
    _call.removeStateListener(_stateListener);
    _call.removeMediaListener(_mediaListener);
    final player = _ringbackPlayer;
    if (player == null) {
      super.dispose();
      return;
    }
    final stop = _stopRingbackFuture;
    if (stop != null) {
      unawaited(stop.whenComplete(player.dispose));
    } else if (_ringbackStarted) {
      unawaited(_stopRingback('dispose').whenComplete(player.dispose));
    } else {
      unawaited(player.dispose());
    }
    super.dispose();
  }

  void _toggleMute() {
    _call.toggleMute();
    setState(() {});
  }

  void _toggleCamera() {
    _call.toggleCamera();
    setState(() {});
  }

  String _stateLabel(BuildContext context) {
    switch (_call.state) {
      case CallState.calling:
        return context.l10n.calling;
      case CallState.ringing:
        return context.l10n.callProgressWaitingForAnswer;
      case CallState.connecting:
        return context.l10n.callProgressConnecting;
      case CallState.active:
      case CallState.connected:
        return context.l10n.callProgressInCall;
      case CallState.ended:
        return context.l10n.callProgressEnded;
      case CallState.failed:
        return context.l10n.callProgressNetworkFailed;
      default:
        return '';
    }
  }

  void _syncRingback(CallState state) {
    final shouldPlay = _call.isOutgoingCall && state == CallState.ringing;
    if (shouldPlay) {
      _startRingback('waiting_for_answer');
    } else {
      _stopRingback('state_${state.name}');
    }
  }

  Future<void> _startRingback(String reason) async {
    if (_disableAudioplayers) {
      if (kIsWeb) {
        debugPrint(
            '[WebVoice] ringback skipped reason=browser_autoplay_not_guaranteed');
        return;
      }
      DiagnosticService.instance.log(
        'ringback skipped on Desktop due to audioplayers platform limitation reason=$reason',
      );
      return;
    }
    if (_ringbackStarted) {
      return;
    }
    _ringbackStarted = true;
    DiagnosticService.instance.log('ringback started reason=$reason');
    try {
      final player = _ringbackPlayer ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('audio/ringback.mp3'));
    } catch (error) {
      DiagnosticService.instance
          .log('ringback failed reason=$reason error=$error');
    }
  }

  Future<void> _stopRingback(String reason) async {
    if (_disableAudioplayers) {
      return;
    }
    if (!_ringbackStarted) {
      return;
    }
    final existing = _stopRingbackFuture;
    if (existing != null) {
      await existing;
      return;
    }
    _ringbackStarted = false;
    DiagnosticService.instance.log('ringback stop start reason=$reason');
    final player = _ringbackPlayer;
    if (player == null) {
      DiagnosticService.instance
          .log('ringback stop skipped no_player reason=$reason');
      return;
    }
    final future = player.stop().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        DiagnosticService.instance.log('ringback stop timeout reason=$reason');
      },
    );
    _stopRingbackFuture = future;
    try {
      await future;
      DiagnosticService.instance.log('ringback stop end reason=$reason');
    } catch (error) {
      DiagnosticService.instance
          .log('ringback stop failed reason=$reason error=$error');
    } finally {
      _stopRingbackFuture = null;
    }
  }

  Widget _buildAudioCallBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compactWebHeight = kIsWeb && MediaQuery.sizeOf(context).height < 520;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: compactWebHeight ? 36 : 48,
            backgroundColor: scheme.primary,
            child: Text(
              widget.peerNickname.isNotEmpty
                  ? widget.peerNickname[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: compactWebHeight ? 30 : 40,
                color: scheme.onPrimary,
              ),
            ),
          ),
          SizedBox(height: compactWebHeight ? 12 : 20),
          Text(
            widget.peerNickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compactWebHeight ? 22 : 26,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          SizedBox(height: compactWebHeight ? 4 : 8),
          Text(
            _stateLabel(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    required String label,
    double size = 56,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HestiaPressable(
          onTap: onTap,
          haptic: true,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: size * 0.5),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRemoteVideoBody(BuildContext context) {
    DiagnosticService.instance.log('webrtc video UI branch selected');
    return LayoutBuilder(
      builder: (context, constraints) {
        final srcObjectPresent = _call.remoteRendererHasSrcObject;
        final frameWidth = _call.inboundVideoFrameWidth;
        final frameHeight = _call.inboundVideoFrameHeight;
        final hasDecodedFrames = _call.inboundVideoFramesDecoded > 0 &&
            frameWidth > 0 &&
            frameHeight > 0;
        final videoKey = ValueKey(
          'desktop-remote-video-${_call.remoteRendererTextureId}-${_call.remoteVideoViewRevisionMs}-${frameWidth}x$frameHeight',
        );
        DiagnosticService.instance.log('webrtc desktop video view built');
        DiagnosticService.instance.log(
          'webrtc video view key=${videoKey.value}',
        );
        DiagnosticService.instance.log(
          'webrtc renderer textureId=${_call.remoteRendererTextureId}',
        );
        DiagnosticService.instance.log(
          'webrtc frameWidth/frameHeight ${frameWidth}x$frameHeight',
        );
        if (hasDecodedFrames) {
          DiagnosticService.instance.log('webrtc placeholder removed');
        }
        final metrics =
            'remote video widget size ${constraints.maxWidth.toStringAsFixed(0)}x${constraints.maxHeight.toStringAsFixed(0)} '
            'renderer srcObject present ${srcObjectPresent ? 'yes' : 'no'} '
            'remoteVideo count ${_call.remoteVideoTrackCount}';
        if (_lastVideoUiMetrics != metrics) {
          _lastVideoUiMetrics = metrics;
          DiagnosticService.instance.log('webrtc $metrics');
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.black,
              child: SizedBox.expand(
                child: RTCVideoView(
                  _call.remoteRenderer,
                  key: videoKey,
                  mirror: false,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                ),
              ),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: IgnorePointer(
                child: _buildRemoteVideoInfo(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRemoteVideoInfo() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          context.l10n.videoDiagnosticsOverlay(
            _call.remoteRendererTextureId,
            _call.inboundVideoFrameWidth,
            _call.inboundVideoFrameHeight,
            _call.inboundVideoFramesDecoded,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compactWebHeight = kIsWeb && MediaQuery.sizeOf(context).height < 520;
    final showDesktopAudioRenderer =
        !_isDesktopVideoCall && _needsDesktopAudioRenderer;
    final showBrowserAudioRenderer = _needsBrowserAudioRenderer;
    _reportRemoteRendererViewForCurrentFrame();
    return Scaffold(
      backgroundColor: _call.isVideoEnabled ? Colors.black : scheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // flutter_webrtc on Desktop needs a real painted RTCVideoView to
            // keep remote audio playout alive for audio-only calls.
            if (showDesktopAudioRenderer || showBrowserAudioRenderer)
              Positioned(
                left: 8,
                top: 8,
                width: 24,
                height: 24,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.01,
                    alwaysIncludeSemantics: false,
                    child: ColoredBox(
                      color: Colors.black,
                      child: RTCVideoView(_call.remoteRenderer),
                    ),
                  ),
                ),
              ),
            if (kIsWeb && _call.browserAudioUnlockRecommended)
              Positioned(
                left: 24,
                right: 24,
                top: 24,
                child: Center(
                  child: FilledButton.icon(
                    onPressed: () {
                      unawaited(_call.requestBrowserAudioUnlock());
                    },
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Click to enable audio'),
                  ),
                ),
              ),
            Positioned.fill(
              child: _call.isVideoEnabled
                  ? _buildRemoteVideoBody(context)
                  : _buildAudioCallBody(context),
            ),
            if (_call.showLocalVideoPreview)
              Positioned(
                right: 16,
                top: 16,
                width: 120,
                height: 170,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: RTCVideoView(
                      _call.localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: compactWebHeight ? 20 : 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRoundButton(
                    icon: _call.isMuted ? Icons.mic_off : Icons.mic,
                    color: _call.isMuted
                        ? scheme.error
                        : scheme.secondaryContainer,
                    iconColor: _call.isMuted
                        ? scheme.onError
                        : scheme.onSecondaryContainer,
                    onTap: _toggleMute,
                    label: _call.isMuted
                        ? context.l10n.muteCall
                        : context.l10n.unmuteCall,
                    size: compactWebHeight ? 48 : 56,
                  ),
                  if (_call.showLocalVideoPreview)
                    _buildRoundButton(
                      icon: _call.isCameraEnabled
                          ? Icons.videocam
                          : Icons.videocam_off,
                      color: _call.isCameraEnabled
                          ? scheme.secondaryContainer
                          : scheme.error,
                      iconColor: _call.isCameraEnabled
                          ? scheme.onSecondaryContainer
                          : scheme.onError,
                      onTap: _toggleCamera,
                      label: _call.isCameraEnabled
                          ? context.l10n.cameraOn
                          : context.l10n.cameraOff,
                      size: compactWebHeight ? 48 : 56,
                    ),
                  _buildRoundButton(
                    icon: Icons.call_end,
                    color: scheme.error,
                    iconColor: scheme.onError,
                    onTap: _call.endCall,
                    label: context.l10n.endCall,
                    size: compactWebHeight ? 60 : 72,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _reportRemoteRendererViewForCurrentFrame() {
    final rendererMounted = _call.isVideoEnabled ||
        _needsDesktopAudioRenderer ||
        _needsBrowserAudioRenderer;
    final visible = _call.isVideoEnabled ||
        _needsDesktopAudioRenderer ||
        _needsBrowserAudioRenderer;
    if (_lastReportedRendererMounted == rendererMounted &&
        _lastReportedRendererVisible == visible) {
      return;
    }
    _lastReportedRendererMounted = rendererMounted;
    _lastReportedRendererVisible = visible;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _call.reportRemoteRendererView(
        mounted: rendererMounted,
        visible: visible,
        reason: _call.isVideoEnabled
            ? 'video-call-view'
            : _needsBrowserAudioRenderer
                ? 'browser-audio-painted-24px-view'
                : _needsDesktopAudioRenderer
                    ? 'desktop-audio-painted-24px-view'
                    : 'audio-no-renderer-view',
      );
    });
  }
}
