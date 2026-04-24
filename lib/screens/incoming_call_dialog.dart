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
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hestia/l10n/l10n.dart';
import 'package:hestia/services/call_service.dart';
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
  final _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startRingtone();
  }

  Future<void> _startRingtone() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('audio/ringtone.mp3'));
  }

  Future<void> _stopRingtone() async {
    await _player.stop();
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  // ── Reject ─────────────────────────────────────────────────────────────────
  void _onReject() {
    HestiaMotion.lightImpact();
    _stopRingtone();
    CallService.instance.rejectCall();
    Navigator.of(context).pop();
  }

  // ── Accept ─────────────────────────────────────────────────────────────────
  // KEY FIX:
  //   1. Capture navigator BEFORE any await (context is still valid here).
  //   2. Pop the dialog immediately — synchronously, no await needed.
  //   3. Push CallScreen onto the stack synchronously.
  //   4. Only THEN call acceptCall() so WebRTC initialises while
  //      CallScreen is already visible and listening for state changes.
  void _onAccept() {
    HestiaMotion.lightImpact();
    _stopRingtone();

    // Capture navigator reference synchronously — safe, no async gap yet
    final nav = Navigator.of(context);
    final nickname = widget.info.fromNickname;

    // Close the dialog (sync)
    nav.pop();

    // Open CallScreen (sync) — it is now in the stack before any await
    nav.push(HestiaMotion.route(
      (_) => CallScreen(peerNickname: nickname),
    ));

    // Start WebRTC AFTER navigation so CallScreen receives onStateChange events
    CallService.instance.acceptCall();
  }

  @override
  Widget build(BuildContext context) {
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
