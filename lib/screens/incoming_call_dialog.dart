// ─────────────────────────────────────────────────────────────────────────────
// IncomingCallDialog — shown as a full-screen overlay when a call arrives.
// Plays a ringtone while the dialog is open; stops on accept or reject.
//
// FIX: eliminated "BuildContext used across async gap" by:
//   1. Capturing Navigator reference BEFORE any await call.
//   2. Never touching context after await — only the pre-captured navigator.
//   3. Calling acceptCall() AFTER navigation, not before, so the CallScreen
//      is already in the stack when the WebRTC stream arrives.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hestia/l10n/l10n.dart';
import 'package:hestia/services/call_service.dart';
import 'package:hestia/services/diagnostic_service.dart';
import 'package:hestia/screens/call_screen.dart';
import 'package:hestia/widgets/ui_kit.dart';
import 'package:hestia/widgets/motion.dart';

class IncomingCallDialog extends StatefulWidget {
  final IncomingCallInfo info;
  const IncomingCallDialog({super.key, required this.info});

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog> {
  AudioPlayer? _player;
  late final void Function(CallState) _dialogStateHandler;
  Future<void>? _stopRingtoneFuture;
  bool _closing = false;
  bool _ringtoneStarted = false;
  bool get _disableAudioplayers =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia;
  bool get _desktopSignalingOnly =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia;

  @override
  void initState() {
    super.initState();
    _dialogStateHandler = (state) {
      if ((state == CallState.idle ||
              state == CallState.ended ||
              state == CallState.failed) &&
          mounted) {
        unawaited(_closeDialog());
      }
    };
    CallService.instance.addStateListener(_dialogStateHandler);
    unawaited(_startRingtone());
  }

  Future<void> _startRingtone() async {
    if (_disableAudioplayers) {
      DiagnosticService.instance.log(
        'incoming ringtone skipped on Desktop due to audioplayers platform limitation callId=${_shortId(widget.info.callId)}',
      );
      return;
    }
    if (_ringtoneStarted) {
      return;
    }
    _ringtoneStarted = true;
    final player = _player ??= AudioPlayer();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource('audio/ringtone.mp3'));
    DiagnosticService.instance.log(
      'ringtone started callId=${_shortId(widget.info.callId)}',
    );
  }

  Future<void> _stopRingtone() async {
    if (_disableAudioplayers) {
      return;
    }
    if (!_ringtoneStarted) {
      return;
    }
    final existing = _stopRingtoneFuture;
    if (existing != null) {
      await existing;
      return;
    }
    _ringtoneStarted = false;
    DiagnosticService.instance.log(
      'stop ringtone start callId=${_shortId(widget.info.callId)}',
    );
    final player = _player;
    if (player == null) {
      DiagnosticService.instance.log(
        'stop ringtone skipped no_player callId=${_shortId(widget.info.callId)}',
      );
      return;
    }
    final future = player.stop().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        DiagnosticService.instance.log(
          'stop ringtone timeout callId=${_shortId(widget.info.callId)}',
        );
      },
    );
    _stopRingtoneFuture = future;
    try {
      await future;
      DiagnosticService.instance.log(
        'stop ringtone end callId=${_shortId(widget.info.callId)}',
      );
    } finally {
      _stopRingtoneFuture = null;
    }
  }

  @override
  void dispose() {
    CallService.instance.removeStateListener(_dialogStateHandler);
    final player = _player;
    if (player == null) {
      super.dispose();
      return;
    }
    final stop = _stopRingtoneFuture;
    if (stop != null) {
      unawaited(stop.whenComplete(player.dispose));
    } else if (_ringtoneStarted) {
      unawaited(_stopRingtone().whenComplete(player.dispose));
    } else {
      unawaited(player.dispose());
    }
    super.dispose();
  }

  String _shortId(String value) =>
      value.length <= 8 ? value : '${value.substring(0, 8)}...';

  // ── Reject ─────────────────────────────────────────────────────────────────
  Future<void> _closeDialog() async {
    if (_closing) {
      return;
    }
    _closing = true;
    await _stopRingtone();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _onReject() {
    HestiaMotion.lightImpact();
    if (!CallService.instance.beginIncomingDecline(
      widget.info.callId,
      source: 'in-app',
    )) {
      unawaited(_closeDialog());
      return;
    }
    unawaited(_stopRingtone());
    CallService.instance.rejectCall();
    unawaited(_closeDialog());
  }

  // ── Accept ─────────────────────────────────────────────────────────────────
  // KEY FIX:
  //   1. Capture navigator BEFORE any await (context is still valid here).
  //   2. Pop the dialog immediately — synchronously, no await needed.
  //   3. Push CallScreen onto the stack synchronously.
  //   4. Only THEN call acceptCall() so WebRTC initialises while
  //      CallScreen is already visible and listening for state changes.
  Future<void> _onAccept() async {
    HestiaMotion.lightImpact();
    if (_desktopSignalingOnly) {
      final nav = Navigator.of(context);
      final activeIncoming = CallService.instance.incomingCall;
      if (CallService.instance.state != CallState.incoming ||
          activeIncoming?.callId != widget.info.callId ||
          activeIncoming?.isExpired == true) {
        CallService.instance.onError?.call('Call expired');
        unawaited(_closeDialog());
        return;
      }
      if (!CallService.instance.beginIncomingAccept(
        widget.info.callId,
        source: 'in-app',
      )) {
        unawaited(_closeDialog());
        return;
      }
      final nickname = widget.info.fromNickname;
      await _stopRingtone();
      _closing = true;
      nav.pop();
      nav.push(HestiaMotion.route(
        (_) => CallScreen(peerNickname: nickname),
      ));
      unawaited(
          CallService.instance.acceptIncomingDesktopMicrophoneProbeOnly());
      return;
    }

    // Capture navigator reference synchronously — safe, no async gap yet
    final nav = Navigator.of(context);
    final activeIncoming = CallService.instance.incomingCall;
    if (CallService.instance.state != CallState.incoming ||
        activeIncoming?.callId != widget.info.callId ||
        activeIncoming?.isExpired == true) {
      CallService.instance.onError?.call('Call expired');
      if (activeIncoming?.callId == widget.info.callId) {
        unawaited(CallService.instance.acceptCall());
      }
      unawaited(_closeDialog());
      return;
    }
    if (!CallService.instance.beginIncomingAccept(
      widget.info.callId,
      source: 'in-app',
    )) {
      unawaited(_closeDialog());
      return;
    }
    final nickname = widget.info.fromNickname;
    await _stopRingtone();

    // Close the dialog (sync)
    _closing = true;
    nav.pop();

    // Open CallScreen (sync) — it is now in the stack before any await
    nav.push(HestiaMotion.route(
      (_) => CallScreen(peerNickname: nickname),
    ));

    // Start WebRTC AFTER navigation so CallScreen receives onStateChange events
    unawaited(CallService.instance.acceptCall());
  }

  @override
  Widget build(BuildContext context) {
    if (_desktopSignalingOnly) {
      return HestiaFadeScale(
        beginScale: 0.96,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(
            widget.info.video
                ? context.l10n.incomingVideoCallNotification
                : context.l10n.incomingCall,
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HestiaAvatar(label: widget.info.fromNickname, radius: 36),
              const SizedBox(height: 16),
              Text(
                widget.info.fromNickname,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HestiaCircleAction(
                    icon: Icons.call_end,
                    color: Theme.of(context).colorScheme.error,
                    onTap: _onReject,
                  ),
                  const SizedBox(width: 40),
                  HestiaCircleAction(
                    icon: widget.info.video ? Icons.videocam : Icons.call,
                    color: Colors.green,
                    onTap: _onAccept,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      context.l10n.rejectCall,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: 40),
                  SizedBox(
                    width: 72,
                    child: Text(
                      context.l10n.accept,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return HestiaFadeScale(
      beginScale: 0.96,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          context.l10n.incomingCall,
          textAlign: TextAlign.center,
        ),
        content: HestiaIncomingCallCard(
          callerName: widget.info.fromNickname,
          callType: widget.info.video
              ? context.l10n.videoCall
              : context.l10n.voiceCall,
          video: widget.info.video,
          framed: false,
          onAccept: _onAccept,
          onDecline: _onReject,
        ),
      ),
    );
  }
}
