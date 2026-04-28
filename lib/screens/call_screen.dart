// ─────────────────────────────────────────────────────────────────────────────
// CallScreen — shown during an active call
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:hestia/l10n/l10n.dart';
import 'package:hestia/services/call_service.dart';
import 'package:hestia/widgets/motion.dart';

class CallScreen extends StatefulWidget {
  final String peerNickname;
  const CallScreen({super.key, required this.peerNickname});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _call = CallService.instance;

  @override
  void initState() {
    super.initState();
    _call.onStateChange = (s) {
      if (s == CallState.idle || s == CallState.ended) {
        if (mounted) Navigator.of(context).pop();
      } else {
        if (mounted) setState(() {});
      }
    };
  }

  @override
  void dispose() {
    _call.onStateChange = null;
    super.dispose();
  }

  // FIX 1: use the public toggleMute() method instead of accessing
  // _localStream directly (private fields are not accessible from outside
  // the library that defines them in Dart).
  void _toggleMute() {
    _call.toggleMute();
    setState(() {});
  }

  String _stateLabel(BuildContext context) {
    switch (_call.state) {
      case CallState.calling:
        return context.l10n.calling;
      case CallState.connected:
        return context.l10n.connected;
      default:
        return '';
    }
  }

  Widget _buildAudioCallBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: scheme.primary,
            child: Text(
              widget.peerNickname.isNotEmpty
                  ? widget.peerNickname[0].toUpperCase()
                  : '?',
              style: TextStyle(fontSize: 40, color: scheme.onPrimary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            widget.peerNickname,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _stateLabel(context),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _call.isVideoEnabled
                  ? RTCVideoView(
                      _call.remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : _buildAudioCallBody(context),
            ),
            if (_call.isVideoEnabled)
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
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),
            if (kDebugMode)
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: ValueListenableBuilder<List<String>>(
                  valueListenable: _call.debugEvents,
                  builder: (context, events, _) {
                    if (events.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          events.join('\n'),
                          maxLines: 12,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            height: 1.2,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
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
                        ? context.l10n.unmuteCall
                        : context.l10n.muteCall,
                  ),
                  _buildRoundButton(
                    icon: Icons.call_end,
                    color: scheme.error,
                    iconColor: scheme.onError,
                    onTap: _call.endCall,
                    label: context.l10n.endCall,
                    size: 72,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
