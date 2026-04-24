import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';
import '../services/local_data_service.dart';
import '../services/micro_onboarding_service.dart';
import '../services/retention_service.dart';
import '../widgets/app_background.dart';
import '../widgets/micro_hint.dart';
import '../widgets/motion.dart';
import '../widgets/notifications.dart';
import '../widgets/ui_kit.dart';
import 'call_screen.dart';

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

    final firstCall =
        await RetentionService.instance.markSeen(RetentionMoment.firstCallStarted);
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
    final keyInfo = _chat.peerKeyInfo(widget.peerUserId, widget.peerNickname);
    final l10n = context.l10n;
    _chat.markConversationRead(_conversationId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(widget.peerNickname),
        actions: [
          _ChatIconButton(
            tooltip: _keyTooltip(context, keyInfo.state),
            onPressed: _showKeyInfo,
            icon: _keyIcon(keyInfo.state),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'block') {
                await _chat.blockUser(widget.peerUserId);
              } else if (value == 'unblock') {
                await _chat.unblockUser(widget.peerUserId);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _chat.isBlockedByMe(widget.peerUserId)
                    ? 'unblock'
                    : 'block',
                child: Text(
                  _chat.isBlockedByMe(widget.peerUserId)
                      ? l10n.unblockUser
                      : l10n.blockUser,
                ),
              ),
            ],
          ),
          _ChatIconButton(
            tooltip: l10n.audioCall,
            onPressed: () => _startCall(video: false),
            icon: Icons.call,
            haptic: true,
          ),
          _ChatIconButton(
            tooltip: l10n.videoCall,
            onPressed: () => _startCall(video: true),
            icon: Icons.videocam,
            haptic: true,
          ),
        ],
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (_, index) {
                        final message = messages[index];
                        final key = _messageKeys.putIfAbsent(
                          message.id,
                          () => GlobalKey(),
                        );
                        return KeyedSubtree(
                          key: key,
                          child: HestiaListEntrance(
                            key: ValueKey('motion_${message.id}'),
                            beginOffset: message.isMe
                                ? const Offset(18, 0)
                                : const Offset(0, 8),
                            child: message.isMe
                                ? _MessageBubble(
                                    message: message,
                                    onLongPress: () =>
                                        _showMessageActions(message),
                                    onReplyTap: () => _scrollToMessage(
                                      message.replyToMessageId,
                                    ),
                                  )
                                : HestiaFadeScale(
                                    child: _MessageBubble(
                                      message: message,
                                      onLongPress: () =>
                                          _showMessageActions(message),
                                      onReplyTap: () => _scrollToMessage(
                                        message.replyToMessageId,
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
                                onTap: () => MicroOnboardingService.instance
                                    .markSeen(
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

  const _ChatIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.haptic = false,
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
          dimension: 48,
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
            if (qrPayload != null) ...[
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
  final VoidCallback? onLongPress;
  final VoidCallback? onReplyTap;

  const _MessageBubble({
    required this.message,
    this.onLongPress,
    this.onReplyTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final attachment = message.attachment;

    return AnimatedOpacity(
      opacity: message.status == MessageDeliveryStatus.sending ? 0.78 : 1,
      duration: HestiaMotion.normal,
      curve: HestiaMotion.curve,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Align(
        alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: message.isMe
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!message.isMe)
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
              if (attachment != null) ...[
                if (message.text.isNotEmpty) const SizedBox(height: 10),
                _AttachmentCard(attachment: attachment),
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
                      DateFormat('dd.MM HH:mm').format(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (message.isMe) ...[
                      const SizedBox(width: 6),
                      AnimatedSwitcher(
                        duration: HestiaMotion.normal,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(
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

class _AttachmentCard extends StatelessWidget {
  final ChatAttachment attachment;

  const _AttachmentCard({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final imageBytes = _webAttachmentBytes(attachment);

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
                child: Text(
                  attachment.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed:
                    kIsWeb ? null : () => OpenFile.open(attachment.localPath),
                icon: const Icon(Icons.open_in_new),
                label: Text(context.l10n.open),
              ),
              OutlinedButton.icon(
                onPressed: () => _saveCopy(context, attachment),
                icon: const Icon(Icons.download),
                label: Text(context.l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
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

  Uint8List? _webAttachmentBytes(ChatAttachment attachment) {
    if (!kIsWeb || !attachment.localPath.startsWith('web:')) {
      return null;
    }

    return LocalDataService.instance.webAttachmentBytes(attachment);
  }
}
