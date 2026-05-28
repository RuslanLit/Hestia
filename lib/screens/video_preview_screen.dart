import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n/l10n.dart';
import '../services/diagnostic_service.dart';
import '../widgets/motion.dart';

class VideoPreviewScreen extends StatefulWidget {
  const VideoPreviewScreen({super.key});

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  MediaStream? _stream;
  String? _error;
  bool _loading = true;
  bool _closing = false;
  bool _rendererInitialized = false;

  bool get _canSwitchCamera =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    unawaited(_startPreview());
  }

  Future<void> _startPreview() async {
    DiagnosticService.instance.log('video preview start');
    try {
      await _renderer.initialize();
      _rendererInitialized = true;
      DiagnosticService.instance.log(
        'video preview renderer initialized textureId=${_renderer.textureId}',
      );
      final camera = await Permission.camera.request();
      final microphone = await Permission.microphone.request();
      if (!camera.isGranted || !microphone.isGranted) {
        throw Exception('camera_microphone_permissions_required');
      }
      DiagnosticService.instance.log('video preview getUserMedia start');
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640, 'max': 640},
          'height': {'ideal': 360, 'max': 360},
          'frameRate': {'ideal': 24, 'max': 24},
        },
      }).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('camera_preview_timed_out'),
      );
      _stream = stream;
      await _renderer.setSrcObject(stream: stream);
      DiagnosticService.instance.log(
        'video preview getUserMedia end videoTracks=${stream.getVideoTracks().length} '
        'audioTracks=${stream.getAudioTracks().length}',
      );
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (error) {
      DiagnosticService.instance.log('video preview failed error=$error');
      await _disposePreviewResources();
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _cameraErrorMessage(error);
        });
      }
    }
  }

  String _cameraErrorMessage(Object error) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia) {
      return context.l10n.cameraUnavailableCheckPermissions;
    }
    final message = error.toString();
    if (message.contains('camera_microphone_permissions_required')) {
      return context.l10n.cameraMicPermissionsRequired;
    }
    if (message.contains('camera_preview_timed_out')) {
      return context.l10n.cameraPreviewTimedOut;
    }
    return context.l10n.cameraUnavailableCheckPermissions;
  }

  Future<void> _switchCamera() async {
    final stream = _stream;
    if (stream == null) {
      return;
    }
    final tracks = stream.getVideoTracks();
    if (tracks.isEmpty) {
      return;
    }
    HestiaMotion.lightImpact();
    try {
      DiagnosticService.instance.log('video preview switch camera start');
      await Helper.switchCamera(tracks.first);
      DiagnosticService.instance.log('video preview switch camera end');
    } catch (error) {
      DiagnosticService.instance
          .log('video preview switch camera failed $error');
    }
  }

  Future<void> _close() async {
    if (_closing) {
      return;
    }
    _closing = true;
    HestiaMotion.lightImpact();
    await _disposePreviewResources();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _disposePreviewResources() async {
    DiagnosticService.instance.log('video preview cleanup start');
    final stream = _stream;
    _stream = null;
    try {
      _renderer.srcObject = null;
    } catch (error) {
      DiagnosticService.instance
          .log('video preview renderer detach ignored error=$error');
    }
    if (stream != null) {
      var stopped = 0;
      for (final track in stream.getTracks()) {
        try {
          track.stop();
          stopped++;
        } catch (error) {
          DiagnosticService.instance
              .log('video preview track stop ignored error=$error');
        }
      }
      DiagnosticService.instance
          .log('video preview tracks stopped count=$stopped');
      try {
        await stream.dispose().timeout(const Duration(seconds: 3));
        DiagnosticService.instance.log('video preview stream disposed');
      } catch (error) {
        DiagnosticService.instance
            .log('video preview stream dispose ignored error=$error');
      }
    }
    DiagnosticService.instance.log('video preview cleanup end');
  }

  @override
  void dispose() {
    unawaited(_disposePreviewResources().whenComplete(() async {
      if (!_rendererInitialized) {
        return;
      }
      try {
        await _renderer.dispose().timeout(const Duration(seconds: 3));
        DiagnosticService.instance.log('video preview renderer disposed');
      } catch (error) {
        DiagnosticService.instance
            .log('video preview renderer dispose ignored error=$error');
      }
    }));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.l10n.videoPreview),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_canSwitchCamera && _stream != null && _error == null)
            IconButton(
              tooltip: context.l10n.switchCamera,
              onPressed: _switchCamera,
              icon: const Icon(Icons.cameraswitch),
            ),
          IconButton(
            tooltip: context.l10n.close,
            onPressed: _close,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                )
              : _loading
                  ? const CircularProgressIndicator()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        RTCVideoView(
                          _renderer,
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 24,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: scheme.error,
                                  foregroundColor: scheme.onError,
                                ),
                                onPressed: _close,
                                icon: const Icon(Icons.close),
                                label: Text(context.l10n.close),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
