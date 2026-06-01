import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/call_service.dart';
import '../services/attachment_policy.dart';
import '../services/browser_attachment_preview.dart';
import '../services/chat_service.dart';
import '../services/diagnostic_service.dart';
import '../services/local_data_service.dart';
import '../services/micro_onboarding_service.dart';
import '../services/platform_capabilities.dart';
import '../services/retention_service.dart';
import '../widgets/app_background.dart';
import '../widgets/micro_hint.dart';
import '../widgets/motion.dart';
import '../widgets/notifications.dart';
import '../widgets/ui_kit.dart';
import 'call_screen.dart';
import 'video_preview_screen.dart';

class ChatScreen extends StatefulWidget {
  final String peerUserId;
  final String peerNickname;

  const ChatScreen({
    super.key,
    required this.peerUserId,
    required this.peerNickname,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chat = ChatService.instance;
  final _messageController = TextEditingController();
  final _messageFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  bool _sendingFile = false;
  ChatMessage? _replyTo;
  String? _lastVideoButtonVisibilityLog;
  bool _desktopCameraAvailable = false;
  bool _desktopCameraCheckPending = false;

  String get _conversationId {
    final myId = _chat.profile?.userId ?? '';
    return makeConversationId(myId, widget.peerUserId);
  }

  List<ChatMessage> get _messages => _chat.messagesFor(_conversationId);

  @override
  void initState() {
    super.initState();
    _chat.addListener(_onMessagesChanged);
    _messageController.addListener(_refreshComposer);
    _messageFocusNode.addListener(_refreshComposer);
    unawaited(_refreshConfigForChatOpen());
    unawaited(_refreshDesktopCameraAvailability());
  }

  @override
  void dispose() {
    _chat.removeListener(_onMessagesChanged);
    _messageController.removeListener(_refreshComposer);
    _messageFocusNode.removeListener(_refreshComposer);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refreshComposer() {
    if (mounted) setState(() {});
  }

  void _onMessagesChanged() {
    if (!mounted) {
      return;
    }
    _chat.markConversationRead(_conversationId);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _refreshConfigForChatOpen() async {
    DiagnosticService.instance.log(
      'chat header refresh config start peerUserId=${_shortId(widget.peerUserId)}',
    );
    await _chat.loadBackendConfig();
    if (!mounted) {
      return;
    }
    DiagnosticService.instance.log(
      'chat header videoCalls config value=${AppConfig.enableVideoCalls}',
    );
    await _refreshDesktopCameraAvailability();
    setState(() {});
  }

  Future<void> _refreshDesktopCameraAvailability() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.fuchsia) {
      return;
    }
    setState(() {
      _desktopCameraAvailable = false;
      _desktopCameraCheckPending = false;
    });
  }

  Future<void> _sendText() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    try {
      await _chat.sendText(
        peerUserId: widget.peerUserId,
        peerNickname: widget.peerNickname,
        text: text,
        replyTo: _replyTo,
      );
      _messageController.clear();
      HestiaMotion.lightImpact();
      setState(() {
        _replyTo = null;
      });
      final firstMessage = await RetentionService.instance
          .markSeen(RetentionMoment.firstMessageSent);
      if (firstMessage && mounted) {
        _chat.sendRetentionEvent(RetentionMoment.firstMessageSent);
        showHestiaSnackBar(
          context,
          context.l10n.retentionFirstMessageSent,
          tone: HestiaStatusTone.info,
        );
      } else {
        await RetentionService.instance.updateState(hasSentMessage: true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      showHestiaSnackBar(
        context,
        context.l10n.messageSendFailed(context.localizedError(error)),
        tone: HestiaStatusTone.error,
      );
    }
  }

  Future<void> _sendFile() async {
    setState(() {
      _sendingFile = true;
    });

    try {
      await _chat.sendPickedFile(
        peerUserId: widget.peerUserId,
        peerNickname: widget.peerNickname,
        replyTo: _replyTo,
      );
      if (mounted) {
        setState(() {
          _replyTo = null;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      showHestiaSnackBar(
        context,
        context.l10n.fileSendFailed(context.localizedError(error)),
        tone: HestiaStatusTone.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingFile = false;
        });
      }
    }
  }

  Future<void> _startCall({required bool video}) async {
    final webDesktopVideoCall = video &&
        kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS;
    final realVideoCall =
        video && ((!kIsWeb && Platform.isAndroid) || webDesktopVideoCall);
    if (video && !realVideoCall) {
      DiagnosticService.instance.log(
        'video call pressed ignored reason=unsupported_platform peerUserId=${_shortId(widget.peerUserId)}',
      );
      Navigator.of(context).push(
        HestiaMotion.route((_) => const VideoPreviewScreen()),
      );
      return;
    }
    if (video) {
      DiagnosticService.instance.log(
        'video call pressed peerUserId=${_shortId(widget.peerUserId)}',
      );
    }
    try {
      _chat.ensureCanCall(widget.peerUserId);
    } catch (error) {
      showHestiaSnackBar(
        context,
        context.l10n.callFailed(context.localizedError(error)),
        tone: HestiaStatusTone.error,
      );
      return;
    }
    if (CallService.instance.isCleanupInProgress) {
      DiagnosticService.instance.log('call blocked reason=cleanup_in_progress');
      showHestiaSnackBar(
        context,
        context.l10n.finishingPreviousCall,
        tone: HestiaStatusTone.warning,
      );
      return;
    }
    if (CallService.instance.state != CallState.idle) {
      showHestiaSnackBar(
        context,
        context.l10n.anotherCallActive,
        tone: HestiaStatusTone.warning,
      );
      return;
    }

    await CallService.instance.startCall(
      widget.peerUserId,
      widget.peerNickname,
      video: video,
    );

    if (!mounted) {
      return;
    }

    if (CallService.instance.state == CallState.idle) {
      return;
    }

    final firstCall = await RetentionService.instance
        .markSeen(RetentionMoment.firstCallStarted);
    if (firstCall) {
      _chat.sendRetentionEvent(RetentionMoment.firstCallStarted);
    }
    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      HestiaMotion.route((_) => CallScreen(peerNickname: widget.peerNickname)),
    );
  }

  Future<void> _showKeyInfo() async {
    final initialInfo =
        _chat.peerKeyInfo(widget.peerUserId, widget.peerNickname);

    await showDialog<void>(
      context: context,
      builder: (context) => _KeyFingerprintDialog(
        initialInfo: initialInfo,
        onTrust: () =>
            _chat.trustPeerKey(widget.peerUserId, widget.peerNickname),
        onRemoveTrust: () => _chat.removePeerKeyTrust(widget.peerUserId),
      ),
    );
  }

  void _startReply(ChatMessage message) {
    setState(() {
      _replyTo = message;
    });
  }

  void _clearReply() {
    setState(() {
      _replyTo = null;
    });
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: Text(context.l10n.reply),
              onTap: () {
                Navigator.of(context).pop();
                _startReply(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: Text(context.l10n.forward),
              onTap: () {
                Navigator.of(context).pop();
                _showForwardTargets(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showForwardTargets(ChatMessage message) async {
    final targets = _forwardTargets();
    if (targets.isEmpty) {
      showHestiaSnackBar(
        context,
        context.l10n.noForwardTargets,
        tone: HestiaStatusTone.warning,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(context.l10n.forwardTo),
            ),
            for (final target in targets)
              ListTile(
                leading: CircleAvatar(
                  child: Text(_avatarLetter(target.nickname)),
                ),
                title: Text(target.nickname),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _forwardMessage(message, target);
                },
              ),
          ],
        ),
      ),
    );
  }

  List<_ForwardTarget> _forwardTargets() {
    final targets = <String, _ForwardTarget>{};
    for (final conversation in _chat.conversations) {
      if (conversation.peerUserId == widget.peerUserId) {
        targets[conversation.peerUserId] = _ForwardTarget(
          userId: conversation.peerUserId,
          nickname: conversation.peerNickname,
        );
      } else if (_chat.isActiveContact(conversation.peerUserId)) {
        targets[conversation.peerUserId] = _ForwardTarget(
          userId: conversation.peerUserId,
          nickname: conversation.peerNickname,
        );
      }
    }
    for (final contact in _chat.contacts) {
      targets[contact.peerUserId] = _ForwardTarget(
        userId: contact.peerUserId,
        nickname: contact.username,
      );
    }
    targets.remove(_chat.profile?.userId);
    return targets.values.toList()
      ..sort((a, b) => a.nickname.toLowerCase().compareTo(
            b.nickname.toLowerCase(),
          ));
  }

  Future<void> _forwardMessage(
      ChatMessage message, _ForwardTarget target) async {
    try {
      await _chat.forwardMessage(
        source: message,
        peerUserId: target.userId,
        peerNickname: target.nickname,
      );
      if (!mounted) {
        return;
      }
      showHestiaSnackBar(
        context,
        context.l10n.forwardedTo(target.nickname),
        tone: HestiaStatusTone.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showHestiaSnackBar(
        context,
        context.l10n.forwardFailed(context.localizedError(error)),
        tone: HestiaStatusTone.error,
      );
    }
  }

  void _scrollToMessage(String? messageId) {
    if (messageId == null) {
      return;
    }
    final context = _messageKeys[messageId]?.currentContext;
    if (context == null) {
      showHestiaSnackBar(
        this.context,
        this.context.l10n.originalMessageUnavailable,
        tone: HestiaStatusTone.warning,
      );
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: 0.35,
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;
    final currentUserId = _chat.profile?.userId ?? '';
    final keyInfo = _chat.peerKeyInfo(widget.peerUserId, widget.peerNickname);
    final l10n = context.l10n;
    final showVideoCallEntry = _shouldShowVideoCallEntry();
    final videoButtonDisabledReason = _videoButtonDisabledReason(context);
    _chat.markConversationRead(_conversationId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildChatAppBar(
        context: context,
        keyInfo: keyInfo,
        showVideoCallEntry: showVideoCallEntry,
        videoButtonDisabledReason: videoButtonDisabledReason,
      ),
      body: AppBackground(
        child: Column(
          children: [
            if (keyInfo.state == PeerKeyTrustState.changed)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: Icon(
                    Icons.gpp_maybe,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  title: Text(
                    l10n.encryptionKeyChanged,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    l10n.sendingBlockedKeyChanged,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: _showKeyInfo,
                    child: Text(l10n.verify),
                  ),
                ),
              ),
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: _ChatEmptyState(
                        text: l10n.noMessagesYet,
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (_, index) {
                        final message = messages[index];
                        final isMe = message.fromUserId == currentUserId;
                        final attachmentProgress =
                            _chat.attachmentProgressFor(message.id);
                        final key = _messageKeys.putIfAbsent(
                          message.id,
                          () => GlobalKey(),
                        );
                        return KeyedSubtree(
                          key: key,
                          child: HestiaListEntrance(
                            key: ValueKey('motion_${message.id}'),
                            beginOffset:
                                isMe ? const Offset(18, 0) : const Offset(0, 8),
                            child: Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: isMe
                                  ? _MessageBubble(
                                      message: message,
                                      isMe: isMe,
                                      attachmentProgress: attachmentProgress,
                                      onLongPress: () =>
                                          _showMessageActions(message),
                                      onReplyTap: () => _scrollToMessage(
                                        message.replyToMessageId,
                                      ),
                                    )
                                  : HestiaFadeScale(
                                      child: _MessageBubble(
                                        message: message,
                                        isMe: isMe,
                                        attachmentProgress: attachmentProgress,
                                        onLongPress: () =>
                                            _showMessageActions(message),
                                        onReplyTap: () => _scrollToMessage(
                                          message.replyToMessageId,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_sendingFile) const LinearProgressIndicator(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyTo != null)
                      _ReplyComposerBar(
                        message: _replyTo!,
                        onCancel: _clearReply,
                      ),
                    Row(
                      children: [
                        if (AppConfig.enableFileAttachments)
                          _ChatIconButton(
                            onPressed: _sendingFile ? null : _sendFile,
                            icon: Icons.attach_file,
                            tooltip: l10n.sendFile,
                          ),
                        Expanded(
                          child: MicroHint(
                            hint: MicroOnboardingHint.messageInput,
                            icon: Icons.edit_outlined,
                            text: l10n.hintMessageInput,
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AnimatedContainer(
                              duration: HestiaMotion.normal,
                              curve: HestiaMotion.curve,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  if (_messageFocusNode.hasFocus)
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.12),
                                      blurRadius: 14,
                                    ),
                                ],
                              ),
                              child: TextField(
                                controller: _messageController,
                                focusNode: _messageFocusNode,
                                minLines: 1,
                                maxLines: 5,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _sendText(),
                                decoration: InputDecoration(
                                  hintText: _messageFocusNode.hasFocus
                                      ? null
                                      : l10n.message,
                                  border: const OutlineInputBorder(),
                                ),
                                onTap: () =>
                                    MicroOnboardingService.instance.markSeen(
                                  MicroOnboardingHint.messageInput,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedSwitcher(
                          duration: HestiaMotion.normal,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.96, end: 1)
                                    .animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _messageController.text.trim().isEmpty
                              ? const SizedBox(key: ValueKey('send-empty'))
                              : HestiaPressable(
                                  key: const ValueKey('send-ready'),
                                  onTap: _sendText,
                                  haptic: true,
                                  borderRadius: BorderRadius.circular(8),
                                  child: const _SendButton(),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildChatAppBar({
    required BuildContext context,
    required PeerKeyInfo keyInfo,
    required bool showVideoCallEntry,
    required String? videoButtonDisabledReason,
  }) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final l10n = context.l10n;
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final compactAndroid = !kIsWeb &&
              Platform.isAndroid &&
              (constraints.maxWidth < 390 || textScale > 1.15);
          final iconSize = compactAndroid ? 44.0 : 48.0;

          return AppBar(
            titleSpacing: compactAndroid ? 0 : null,
            title: Text(
              widget.peerNickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
            actions: [
              if (!compactAndroid)
                _ChatIconButton(
                  tooltip: _keyTooltip(context, keyInfo.state),
                  onPressed: _showKeyInfo,
                  icon: _keyIcon(keyInfo.state),
                  size: iconSize,
                ),
              PopupMenuButton<String>(
                tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                onSelected: (value) async {
                  if (value == 'key_info') {
                    _showKeyInfo();
                  } else if (value == 'block') {
                    await _chat.blockUser(widget.peerUserId);
                  } else if (value == 'unblock') {
                    await _chat.unblockUser(widget.peerUserId);
                  }
                },
                itemBuilder: (context) => [
                  if (compactAndroid)
                    PopupMenuItem(
                      value: 'key_info',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_keyIcon(keyInfo.state)),
                        title: Text(
                          _keyTooltip(context, keyInfo.state),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  PopupMenuItem(
                    value: _chat.isBlockedByMe(widget.peerUserId)
                        ? 'unblock'
                        : 'block',
                    child: Text(
                      _chat.isBlockedByMe(widget.peerUserId)
                          ? l10n.unblockUser
                          : l10n.blockUser,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (AppConfig.enableVoiceCalls)
                _ChatIconButton(
                  tooltip: l10n.audioCall,
                  onPressed: () => _startCall(video: false),
                  icon: Icons.call,
                  haptic: true,
                  size: iconSize,
                ),
              if (showVideoCallEntry)
                _ChatIconButton(
                  tooltip: videoButtonDisabledReason == null
                      ? l10n.videoCall
                      : '${l10n.videoCall}: $videoButtonDisabledReason',
                  onPressed: videoButtonDisabledReason == null
                      ? () => _startCall(video: true)
                      : null,
                  icon: Icons.videocam,
                  haptic: true,
                  size: iconSize,
                ),
            ],
          );
        },
      ),
    );
  }

  IconData _keyIcon(PeerKeyTrustState state) {
    switch (state) {
      case PeerKeyTrustState.verified:
        return Icons.verified_user;
      case PeerKeyTrustState.changed:
        return Icons.gpp_maybe;
      case PeerKeyTrustState.missing:
        return Icons.no_encryption_gmailerrorred;
      case PeerKeyTrustState.untrusted:
        return Icons.shield_outlined;
    }
  }

  String _keyTooltip(BuildContext context, PeerKeyTrustState state) {
    switch (state) {
      case PeerKeyTrustState.verified:
        return context.l10n.verifiedEncryptionKey;
      case PeerKeyTrustState.changed:
        return context.l10n.encryptionKeyChanged;
      case PeerKeyTrustState.missing:
        return context.l10n.noEncryptionKey;
      case PeerKeyTrustState.untrusted:
        return context.l10n.verifyEncryptionKey;
    }
  }

  String _avatarLetter(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed.substring(0, 1).toUpperCase();
  }

  bool _shouldShowVideoCallEntry() {
    final featureEnabled = AppConfig.enableVideoCalls;
    final voiceEnabled = AppConfig.enableVoiceCalls;
    final android = !kIsWeb && Platform.isAndroid;
    final desktop = !kIsWeb && defaultTargetPlatform == TargetPlatform.fuchsia;
    final webVideoStopFixDisabled = _webVideoTemporarilyDisabled();
    final webDesktop = kIsWeb &&
        !webVideoStopFixDisabled &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS;
    final activeContact = _chat.isActiveContact(widget.peerUserId);
    final androidPhaseFallback = android && voiceEnabled;
    final visible = activeContact &&
        ((android && (featureEnabled || androidPhaseFallback)) ||
            (desktop && featureEnabled) ||
            (webDesktop && featureEnabled));
    final disabledReason = _videoButtonDisabledReason(null);
    final platform = android
        ? 'android'
        : desktop
            ? 'desktop'
            : kIsWeb
                ? webDesktop
                    ? 'web_desktop'
                    : 'web_unsupported'
                : 'other';
    final logKey =
        'platform=$platform enableVideoCalls=$featureEnabled activeContact=$activeContact '
        'cameraAvailable=$_desktopCameraAvailable cameraCheckPending=$_desktopCameraCheckPending '
        'finalVisible=$visible finalDisabledReason=${disabledReason ?? 'none'} '
        'androidFallback=$androidPhaseFallback peer=${_shortId(widget.peerUserId)}';
    if (_lastVideoButtonVisibilityLog != logKey) {
      _lastVideoButtonVisibilityLog = logKey;
      DiagnosticService.instance.log('UI video call entry $logKey');
      if (kIsWeb && webVideoStopFixDisabled) {
        debugPrint(
          '[CallStopFix] start video call blocked reason=web_video_temporarily_disabled',
        );
      }
    }
    return visible;
  }

  String? _videoButtonDisabledReason(BuildContext? context) {
    if (kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        return context?.l10n.videoCallUnavailable ?? 'web_mobile_unsupported';
      }
      return null;
    }
    if (defaultTargetPlatform != TargetPlatform.fuchsia) {
      return null;
    }
    return context?.l10n.desktopVideoExperimental ?? 'desktop_experimental';
  }

  bool _webVideoTemporarilyDisabled() => false;

  String _shortId(String value) =>
      value.length <= 8 ? value : '${value.substring(0, 8)}...';
}

class _ForwardTarget {
  final String userId;
  final String nickname;

  const _ForwardTarget({
    required this.userId,
    required this.nickname,
  });
}

class _ChatEmptyState extends StatelessWidget {
  final String text;

  const _ChatEmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return HestiaFadeScale(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: scheme.primary.withValues(alpha: 0.72),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ChatIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool haptic;
  final double size;

  const _ChatIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.haptic = false,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: HestiaPressable(
        onTap: onPressed,
        haptic: haptic,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox.square(
        dimension: 48,
        child: Icon(Icons.send, color: scheme.onPrimary),
      ),
    );
  }
}

class _KeyFingerprintDialog extends StatefulWidget {
  final PeerKeyInfo initialInfo;
  final Future<void> Function() onTrust;
  final Future<void> Function() onRemoveTrust;

  const _KeyFingerprintDialog({
    required this.initialInfo,
    required this.onTrust,
    required this.onRemoveTrust,
  });

  @override
  State<_KeyFingerprintDialog> createState() => _KeyFingerprintDialogState();
}

class _KeyFingerprintDialogState extends State<_KeyFingerprintDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _trust() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.onTrust();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = context.localizedError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _removeTrust() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.onRemoveTrust();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = context.localizedError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.initialInfo;
    final canTrust = info.publicKey != null &&
        info.state != PeerKeyTrustState.verified &&
        !_busy;
    final canRemoveTrust = info.state == PeerKeyTrustState.verified && !_busy;
    final qrPayload = info.publicKey == null
        ? null
        : jsonEncode({
            'type': 'HESTIA_KEY_V1',
            'userId': info.userId,
            'nickname': info.nickname,
            'publicKey': info.publicKey,
            'fingerprint': info.fingerprint,
          });

    return AlertDialog(
      title: Text(context.l10n.encryptionKey),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.nickname),
            const SizedBox(height: 12),
            Text(_statusText(info.state)),
            const SizedBox(height: 16),
            SelectableText(
              info.fingerprint ?? context.l10n.noFingerprint,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (AppConfig.enableKeyQrVerification && qrPayload != null) ...[
              const SizedBox(height: 16),
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: QrImageView(
                      data: qrPayload,
                      version: QrVersions.auto,
                      size: 180,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.close),
        ),
        if (canRemoveTrust)
          TextButton.icon(
            onPressed: _removeTrust,
            icon: const Icon(Icons.remove_circle_outline),
            label: Text(context.l10n.removeTrust),
          ),
        FilledButton.icon(
          onPressed: canTrust ? _trust : null,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_user),
          label: Text(
            info.state == PeerKeyTrustState.changed
                ? context.l10n.trustNewKey
                : context.l10n.trustKey,
          ),
        ),
      ],
    );
  }

  String _statusText(PeerKeyTrustState state) {
    switch (state) {
      case PeerKeyTrustState.verified:
        return context.l10n.keyTrusted;
      case PeerKeyTrustState.changed:
        return context.l10n.keyChangedWarning;
      case PeerKeyTrustState.missing:
        return context.l10n.keyMissing;
      case PeerKeyTrustState.untrusted:
        return context.l10n.keyUntrusted;
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final AttachmentTransferProgress? attachmentProgress;
  final VoidCallback? onLongPress;
  final VoidCallback? onReplyTap;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.attachmentProgress,
    this.onLongPress,
    this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final attachment = message.attachment;
    final isLegacyMissedCall = message.id.startsWith('missed_call_');
    final isCallEvent =
        message.type == ChatMessageType.call || isLegacyMissedCall;
    final timestampLabel = DateFormat('dd.MM HH:mm').format(message.timestamp);

    if (isCallEvent) {
      final callTitle = _callEventTitle(context, message, isLegacyMissedCall);
      final durationLabel = !isLegacyMissedCall &&
              message.callStatus == CallStatus.completed &&
              message.callDurationSeconds != null
          ? _formatCallDuration(message.callDurationSeconds!)
          : null;
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _callEventIcon(message, isLegacyMissedCall),
                    size: 16,
                    color: scheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      durationLabel == null
                          ? callTitle
                          : '$callTitle \u00b7 $durationLabel',
                      style: TextStyle(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                timestampLabel,
                style: TextStyle(
                  color: scheme.onErrorContainer.withValues(alpha: 0.78),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedOpacity(
      opacity: message.status == MessageDeliveryStatus.sending ? 0.78 : 1,
      duration: HestiaMotion.normal,
      curve: HestiaMotion.curve,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color:
                isMe ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.fromNickname,
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (message.isForwarded)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.forward,
                        size: 14,
                        color: scheme.onSurface.withValues(alpha: 0.65),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        message.forwardedFromSenderName == null
                            ? context.l10n.forwarded
                            : context.l10n.forwardedFrom(
                                message.forwardedFromSenderName!,
                              ),
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.65),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              if (message.replyToMessageId != null)
                _ReplyPreviewBlock(
                  message: message,
                  onTap: onReplyTap,
                ),
              if (message.text.isNotEmpty) Text(message.text),
              if (AppConfig.enableFileAttachments && attachment != null) ...[
                if (message.text.isNotEmpty) const SizedBox(height: 10),
                _AttachmentCard(
                  attachment: attachment,
                  status: message.status,
                  isMe: isMe,
                  progress: attachmentProgress,
                ),
              ],
              const SizedBox(height: 6),
              AnimatedOpacity(
                opacity:
                    message.status == MessageDeliveryStatus.sending ? 0.72 : 1,
                duration: HestiaMotion.normal,
                curve: HestiaMotion.curve,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timestampLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      AnimatedSwitcher(
                        duration: HestiaMotion.normal,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.9, end: 1)
                                .animate(animation),
                            child: child,
                          ),
                        ),
                        child: Icon(
                          _statusIcon(message.status),
                          key: ValueKey(message.status),
                          size: 14,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _statusIcon(MessageDeliveryStatus status) {
    switch (status) {
      case MessageDeliveryStatus.sending:
        return Icons.schedule;
      case MessageDeliveryStatus.sent:
        return Icons.check;
      case MessageDeliveryStatus.delivered:
        return Icons.done_all;
      case MessageDeliveryStatus.failed:
        return Icons.error_outline;
    }
  }

  IconData _callEventIcon(ChatMessage message, bool isLegacyMissedCall) {
    if (isLegacyMissedCall) {
      return Icons.call_missed;
    }
    if (message.isVideoCall) {
      switch (message.callStatus) {
        case CallStatus.missed:
        case CallStatus.canceledByCaller:
        case CallStatus.failedTimeout:
        case CallStatus.failedNetwork:
          return Icons.videocam_off_outlined;
        default:
          return Icons.videocam;
      }
    }
    switch (message.callStatus) {
      case CallStatus.missed:
      case CallStatus.canceledByCaller:
      case CallStatus.failedTimeout:
      case CallStatus.failedNetwork:
        return Icons.call_missed;
      case CallStatus.rejectedByRecipient:
        return Icons.call_end;
      case CallStatus.completed:
        return Icons.phone;
      case CallStatus.connected:
      case CallStatus.incomingRinging:
      case CallStatus.outgoingRinging:
      case null:
        return message.callDirection == CallDirection.outgoing
            ? Icons.call_made
            : Icons.call_received;
    }
  }

  String _callEventTitle(
    BuildContext context,
    ChatMessage message,
    bool isLegacyMissedCall,
  ) {
    if (isLegacyMissedCall) {
      return context.l10n.callEventMissedVoice;
    }
    if (message.isVideoCall) {
      final videoCall = context.l10n.videoCall;
      switch (message.callStatus) {
        case CallStatus.missed:
          return context.l10n.callEventMissedVideo;
        case CallStatus.rejectedByRecipient:
          return context.l10n.callEventRejectedVideo;
        case CallStatus.canceledByCaller:
          return context.l10n.callEventCanceledVideo;
        case CallStatus.failedTimeout:
        case CallStatus.failedNetwork:
          return context.l10n.callEventFailed;
        case CallStatus.connected:
        case CallStatus.incomingRinging:
        case CallStatus.outgoingRinging:
        case CallStatus.completed:
        case null:
          return videoCall;
      }
    }
    switch (message.callStatus) {
      case CallStatus.missed:
        return context.l10n.callEventMissedVoice;
      case CallStatus.rejectedByRecipient:
        return context.l10n.callEventRejectedVoice;
      case CallStatus.canceledByCaller:
        return context.l10n.callEventCanceledVoice;
      case CallStatus.failedTimeout:
      case CallStatus.failedNetwork:
        return context.l10n.callEventFailed;
      case CallStatus.completed:
        return context.l10n.callEventVoice;
      case CallStatus.connected:
      case CallStatus.incomingRinging:
      case CallStatus.outgoingRinging:
      case null:
        return message.callDirection == CallDirection.outgoing
            ? context.l10n.callEventOutgoingVoice
            : context.l10n.callEventIncomingVoice;
    }
  }

  String _formatCallDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final remainingSeconds = safeSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${remainingSeconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class _ReplyComposerBar extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onCancel;

  const _ReplyComposerBar({
    required this.message,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: scheme.primary, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.fromNickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _previewForMessage(context, message),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.cancelReply,
            onPressed: onCancel,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _ReplyPreviewBlock extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onTap;

  const _ReplyPreviewBlock({
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: scheme.primary, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.replyToSenderName ?? context.l10n.originalMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message.replyPreviewText?.isNotEmpty == true
                    ? _localizedReplyPreview(context, message.replyPreviewText!)
                    : context.l10n.originalMessageUnavailable,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.75),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _previewForMessage(BuildContext context, ChatMessage message) {
  if (message.attachment != null) {
    return message.attachment!.name;
  }
  final text = message.text.trim();
  if (text.isEmpty) {
    return context.l10n.attachment;
  }
  return text.length > 120 ? '${text.substring(0, 120)}...' : text;
}

String _localizedReplyPreview(BuildContext context, String preview) {
  return preview == 'Attachment' ? context.l10n.attachment : preview;
}

class _AttachmentCard extends StatefulWidget {
  final ChatAttachment attachment;
  final MessageDeliveryStatus status;
  final bool isMe;
  final AttachmentTransferProgress? progress;

  const _AttachmentCard({
    required this.attachment,
    required this.status,
    required this.isMe,
    this.progress,
  });

  @override
  State<_AttachmentCard> createState() => _AttachmentCardState();
}

class _AttachmentCardState extends State<_AttachmentCard> {
  String? _objectUrl;
  String? _objectUrlKey;
  bool? _lastPreviewAvailable;
  String? _lastUnsupportedType;

  @override
  void initState() {
    super.initState();
    _refreshObjectUrl();
  }

  @override
  void didUpdateWidget(covariant _AttachmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshObjectUrl();
  }

  @override
  void dispose() {
    _revokeObjectUrl();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _refreshObjectUrl();
    final attachment = widget.attachment;
    final imageBytes = _webAttachmentBytes(attachment);
    final webAttachmentAvailable = kIsWeb && imageBytes != null;
    final webPreviewSupported = kIsWeb &&
        webAttachmentAvailable &&
        BrowserAttachmentPreview.canPreview(attachment.name, attachment.kind);
    final canOpenInBrowser = webPreviewSupported && _objectUrl != null;
    final canOpenInPlace = PlatformCapabilities.supportsPersistentAttachments &&
        attachment.localPath.isNotEmpty &&
        AttachmentPolicy.canOpenInPlace(attachment.name, attachment.kind);
    final progress = widget.progress;
    final showProgress = progress != null &&
        progress.stage != AttachmentTransferStage.sent &&
        progress.stage != AttachmentTransferStage.received &&
        progress.stage != AttachmentTransferStage.failed;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (attachment.isImage && imageBytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  imageBytes,
                  width: 220,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else if (!kIsWeb &&
              attachment.isImage &&
              File(attachment.localPath).existsSync())
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(attachment.localPath),
                  width: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Row(
            children: [
              Icon(_iconForAttachment(attachment)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_typeLabel(attachment)} \u00b7 ${_formatBytes(attachment.sizeBytes)} \u00b7 ${_statusLabel(context, progress)}',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress.fraction),
            const SizedBox(height: 6),
            Text(
              _progressDetails(context, progress),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.68),
                  ),
            ),
          ],
          if (progress?.stage == AttachmentTransferStage.failed &&
              (progress?.error?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Text(
              context.localizedError(progress!.error!),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: !showProgress && canOpenInBrowser
                    ? _openBrowserPreview
                    : !showProgress && canOpenInPlace
                        ? () => OpenFile.open(attachment.localPath)
                        : null,
                icon: const Icon(Icons.open_in_new),
                label: Text(context.l10n.open),
              ),
              OutlinedButton.icon(
                onPressed:
                    ((PlatformCapabilities.supportsPersistentAttachments &&
                                    attachment.localPath.isNotEmpty) ||
                                webAttachmentAvailable) &&
                            !showProgress
                        ? () => _saveCopy(context, attachment)
                        : null,
                icon: const Icon(Icons.download),
                label: Text(context.l10n.save),
              ),
            ],
          ),
          if (kIsWeb &&
              webAttachmentAvailable &&
              !webPreviewSupported &&
              !showProgress) ...[
            const SizedBox(height: 6),
            Text(
              context.l10n.previewUnavailable,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.68),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  void _refreshObjectUrl() {
    if (!kIsWeb) {
      return;
    }
    final attachment = widget.attachment;
    final bytes = _webAttachmentBytes(attachment);
    final previewAvailable = bytes != null &&
        BrowserAttachmentPreview.canPreview(attachment.name, attachment.kind);
    _logPreviewAvailability(attachment, previewAvailable);
    if (bytes == null || !previewAvailable) {
      if (bytes != null) {
        _logUnsupportedPreviewType(attachment);
      }
      _revokeObjectUrl();
      return;
    }

    final key =
        '${attachment.id}:${attachment.name}:${attachment.kind}:${bytes.length}';
    if (_objectUrl != null && _objectUrlKey == key) {
      return;
    }
    _revokeObjectUrl();
    _objectUrl = BrowserAttachmentPreview.createObjectUrl(
      fileName: attachment.name,
      kind: attachment.kind,
      bytes: bytes,
    );
    _objectUrlKey = _objectUrl == null ? null : key;
  }

  void _openBrowserPreview() {
    final objectUrl = _objectUrl;
    if (objectUrl == null) {
      return;
    }
    BrowserAttachmentPreview.openObjectUrl(objectUrl);
  }

  void _revokeObjectUrl() {
    final objectUrl = _objectUrl;
    if (objectUrl == null) {
      return;
    }
    BrowserAttachmentPreview.revokeObjectUrl(objectUrl);
    _objectUrl = null;
    _objectUrlKey = null;
  }

  void _logPreviewAvailability(
    ChatAttachment attachment,
    bool previewAvailable,
  ) {
    if (_lastPreviewAvailable == previewAvailable) {
      return;
    }
    _lastPreviewAvailable = previewAvailable;
    debugPrint('[WebFile] preview available=$previewAvailable');
  }

  void _logUnsupportedPreviewType(ChatAttachment attachment) {
    final type = AttachmentPolicy.extensionForName(attachment.name).isEmpty
        ? attachment.kind
        : AttachmentPolicy.extensionForName(attachment.name);
    if (_lastUnsupportedType == type) {
      return;
    }
    _lastUnsupportedType = type;
    debugPrint('[WebFile] unsupported preview type=$type');
  }

  Future<void> _saveCopy(
      BuildContext context, ChatAttachment attachment) async {
    try {
      final path = await ChatService.instance.exportAttachment(attachment);
      if (!context.mounted) {
        return;
      }
      showHestiaSnackBar(
        context,
        context.l10n.savedTo(context.localizedError(path)),
        tone: HestiaStatusTone.success,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      showHestiaSnackBar(
        context,
        context.l10n.saveFailed(context.localizedError(error)),
        tone: HestiaStatusTone.error,
      );
    }
  }

  IconData _iconForAttachment(ChatAttachment attachment) {
    if (attachment.isImage) {
      return Icons.image_outlined;
    }
    if (attachment.isVideo) {
      return Icons.videocam_outlined;
    }
    if (attachment.isAudio) {
      return Icons.audiotrack_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _statusLabel(
    BuildContext context,
    AttachmentTransferProgress? progress,
  ) {
    if (progress != null) {
      switch (progress.stage) {
        case AttachmentTransferStage.preparing:
          return context.l10n.attachmentPreparing;
        case AttachmentTransferStage.encrypting:
          return context.l10n.attachmentEncrypting;
        case AttachmentTransferStage.uploading:
          return context.l10n.attachmentUploading;
        case AttachmentTransferStage.downloading:
          return context.l10n.attachmentDownloading;
        case AttachmentTransferStage.decrypting:
          return context.l10n.attachmentDecrypting;
        case AttachmentTransferStage.saving:
          return context.l10n.attachmentSaving;
        case AttachmentTransferStage.sent:
          return context.l10n.attachmentSent;
        case AttachmentTransferStage.received:
          return context.l10n.attachmentReceived;
        case AttachmentTransferStage.failed:
          return context.l10n.attachmentFailed;
      }
    }
    switch (widget.status) {
      case MessageDeliveryStatus.sending:
        return context.l10n.attachmentUploading;
      case MessageDeliveryStatus.failed:
        return context.l10n.attachmentFailed;
      case MessageDeliveryStatus.sent:
      case MessageDeliveryStatus.delivered:
        return widget.isMe
            ? context.l10n.attachmentSent
            : context.l10n.attachmentReceived;
    }
  }

  String _progressDetails(
    BuildContext context,
    AttachmentTransferProgress progress,
  ) {
    final total = progress.totalBytes;
    final fraction = progress.fraction;
    final percent = fraction == null ? null : (fraction * 100).floor();
    if (total != null && total > 0) {
      final text =
          '${_formatBytes(progress.transferredBytes)} / ${_formatBytes(total)}';
      return percent == null ? text : '$percent% \u00b7 $text';
    }
    if (progress.transferredBytes > 0) {
      return _formatBytes(progress.transferredBytes);
    }
    return context.l10n.attachmentWorking;
  }

  String _typeLabel(ChatAttachment attachment) {
    final extension = AttachmentPolicy.extensionForName(attachment.name);
    return extension.isEmpty ? attachment.kind : extension.toUpperCase();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Uint8List? _webAttachmentBytes(ChatAttachment attachment) {
    if (!kIsWeb || !attachment.localPath.startsWith('web:')) {
      return null;
    }

    return LocalDataService.instance.webAttachmentBytes(attachment);
  }
}
