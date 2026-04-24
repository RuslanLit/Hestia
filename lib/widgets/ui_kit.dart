import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import 'motion.dart';

enum HestiaButtonVariant { primary, secondary, outline }

enum HestiaStatusTone { neutral, success, warning, error, info }

class HestiaButton extends StatelessWidget {
  final Widget label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final HestiaButtonVariant variant;
  final bool expanded;

  const HestiaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = HestiaButtonVariant.primary,
    this.expanded = false,
  });

  const HestiaButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
  }) : variant = HestiaButtonVariant.primary;

  const HestiaButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
  }) : variant = HestiaButtonVariant.secondary;

  const HestiaButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
  }) : variant = HestiaButtonVariant.outline;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? label
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: HestiaSpacing.sm),
              label,
            ],
          );
    final button = switch (variant) {
      HestiaButtonVariant.primary => FilledButton(
          onPressed: onPressed,
          child: child,
        ),
      HestiaButtonVariant.secondary => FilledButton.tonal(
          onPressed: onPressed,
          child: child,
        ),
      HestiaButtonVariant.outline => OutlinedButton(
          onPressed: onPressed,
          child: child,
        ),
    };
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class HestiaTextInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  const HestiaTextInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
  });

  const HestiaTextInput.password({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.onSubmitted,
    this.onChanged,
  })  : prefixIcon = Icons.lock_outline,
        obscureText = true,
        textInputAction = TextInputAction.done;

  const HestiaTextInput.search({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.onSubmitted,
    this.onChanged,
  })  : prefixIcon = Icons.search,
        obscureText = false,
        textInputAction = TextInputAction.search;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
    );
  }
}

class HestiaSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const HestiaSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(HestiaSpacing.xl),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class HestiaMessagePreviewCard extends StatelessWidget {
  final String title;
  final String preview;
  final String? time;
  final int unreadCount;
  final bool muted;
  final bool pinned;
  final VoidCallback? onTap;

  const HestiaMessagePreviewCard({
    super.key,
    required this.title,
    required this.preview,
    this.time,
    this.unreadCount = 0,
    this.muted = false,
    this.pinned = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: HestiaSpacing.lg,
        vertical: HestiaSpacing.sm,
      ),
      leading: HestiaAvatar(label: title),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (time != null)
            Padding(
              padding: const EdgeInsets.only(right: HestiaSpacing.sm),
              child: Text(time!, style: Theme.of(context).textTheme.bodySmall),
            ),
          if (muted)
            const Padding(
              padding: EdgeInsets.only(right: HestiaSpacing.sm),
              child: Icon(Icons.notifications_off_outlined, size: 18),
            ),
          if (pinned)
            const Padding(
              padding: EdgeInsets.only(right: HestiaSpacing.sm),
              child: Icon(Icons.push_pin_outlined, size: 18),
            ),
          if (unreadCount > 0) HestiaUnreadBadge(count: unreadCount),
        ],
      ),
      onTap: onTap,
    );
  }
}

class HestiaFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const HestiaFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return HestiaSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HestiaIconTile(icon: icon),
          const SizedBox(height: HestiaSpacing.xl),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: HestiaSpacing.sm),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class HestiaDownloadCard extends StatelessWidget {
  final String title;
  final String description;
  final String actionLabel;
  final String recommendedLabel;
  final VoidCallback? onPressed;
  final bool recommended;

  const HestiaDownloadCard({
    super.key,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
    this.recommendedLabel = 'Recommended',
    this.recommended = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return HestiaSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recommended) ...[
            HestiaStatusBadge(
              label: recommendedLabel,
              tone: HestiaStatusTone.info,
            ),
            const SizedBox(height: HestiaSpacing.md),
          ],
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: HestiaSpacing.sm),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: HestiaSpacing.xl),
          HestiaButton.outline(
            expanded: true,
            onPressed: onPressed,
            icon: Icons.download,
            label: Text(actionLabel, style: TextStyle(color: scheme.onSurface)),
          ),
        ],
      ),
    );
  }
}

class HestiaHeader extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;

  const HestiaHeader({
    super.key,
    required this.title,
    this.actions = const [],
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(title: title, actions: actions, bottom: bottom);
  }
}

class HestiaTabs extends StatelessWidget implements PreferredSizeWidget {
  final List<Tab> tabs;
  final TabController? controller;
  final ValueChanged<int>? onTap;

  const HestiaTabs({
    super.key,
    required this.tabs,
    this.controller,
    this.onTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    return TabBar(controller: controller, tabs: tabs, onTap: onTap);
  }
}

class HestiaMenuDrawer extends StatelessWidget {
  final Widget? header;
  final List<Widget> children;

  const HestiaMenuDrawer({
    super.key,
    this.header,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (header != null) header!,
            ...children,
          ],
        ),
      ),
    );
  }
}

class HestiaUnreadBadge extends StatelessWidget {
  final int count;

  const HestiaUnreadBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Badge.count(
      count: count,
      backgroundColor: Theme.of(context).colorScheme.primary,
      textColor: Theme.of(context).colorScheme.onPrimary,
    );
  }
}

class HestiaStatusBadge extends StatelessWidget {
  final String label;
  final HestiaStatusTone tone;

  const HestiaStatusBadge({
    super.key,
    required this.label,
    this.tone = HestiaStatusTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final states = Theme.of(context).extension<HestiaStateColors>()!;
    final color = switch (tone) {
      HestiaStatusTone.success => states.success,
      HestiaStatusTone.warning => states.warning,
      HestiaStatusTone.error => states.error,
      HestiaStatusTone.info => states.info,
      HestiaStatusTone.neutral => scheme.primary,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: HestiaSpacing.md,
          vertical: HestiaSpacing.xs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
      ),
    );
  }
}

class HestiaChatBubble extends StatelessWidget {
  final ChatMessage message;
  final Widget? replyBlock;
  final Widget? attachmentPreview;
  final VoidCallback? onLongPress;
  final String? timestampLabel;

  const HestiaChatBubble({
    super.key,
    required this.message,
    this.replyBlock,
    this.attachmentPreview,
    this.onLongPress,
    this.timestampLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: HestiaSpacing.xs),
          padding: const EdgeInsets.all(HestiaSpacing.md),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!message.isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: HestiaSpacing.xs),
                  child: Text(
                    message.fromNickname,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontSize: 12,
                        ),
                  ),
                ),
              if (replyBlock != null) replyBlock!,
              if (message.text.isNotEmpty) Text(message.text),
              if (attachmentPreview != null) ...[
                if (message.text.isNotEmpty)
                  const SizedBox(height: HestiaSpacing.md),
                attachmentPreview!,
              ],
              if (timestampLabel != null) ...[
                const SizedBox(height: HestiaSpacing.sm),
                Text(
                  timestampLabel!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class HestiaReplyBlock extends StatelessWidget {
  final String sender;
  final String preview;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;

  const HestiaReplyBlock({
    super.key,
    required this.sender,
    required this.preview,
    this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: HestiaSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(HestiaSpacing.sm),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: scheme.primary, width: 3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontSize: 12,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (onCancel != null)
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class HestiaAttachmentPreview extends StatelessWidget {
  final ChatAttachment attachment;
  final Uint8List? imageBytes;
  final String? openLabel;
  final String? saveLabel;
  final VoidCallback? onOpen;
  final VoidCallback? onSave;

  const HestiaAttachmentPreview({
    super.key,
    required this.attachment,
    this.imageBytes,
    this.openLabel,
    this.saveLabel,
    this.onOpen,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(HestiaSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachment.isImage && imageBytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: HestiaSpacing.md),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(imageBytes!, width: 220, fit: BoxFit.cover),
              ),
            ),
          Row(
            children: [
              Icon(_iconForAttachment(attachment)),
              const SizedBox(width: HestiaSpacing.sm),
              Expanded(
                child: Text(attachment.name, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (onOpen != null || onSave != null) ...[
            const SizedBox(height: HestiaSpacing.sm),
            Wrap(
              spacing: HestiaSpacing.sm,
              runSpacing: HestiaSpacing.sm,
              children: [
                if (onOpen != null)
                  OutlinedButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(openLabel ?? context.l10n.open),
                  ),
                if (onSave != null)
                  OutlinedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.download),
                    label: Text(saveLabel ?? context.l10n.save),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForAttachment(ChatAttachment attachment) {
    if (attachment.isImage) return Icons.image_outlined;
    if (attachment.isVideo) return Icons.videocam_outlined;
    if (attachment.isAudio) return Icons.audiotrack_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

class HestiaIncomingCallCard extends StatelessWidget {
  final String callerName;
  final String callType;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool video;
  final bool framed;

  const HestiaIncomingCallCard({
    super.key,
    required this.callerName,
    required this.callType,
    required this.onAccept,
    required this.onDecline,
    this.video = false,
    this.framed = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HestiaAvatar(label: callerName, radius: 36),
        const SizedBox(height: HestiaSpacing.md),
        Text(callerName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: HestiaSpacing.xs),
        Text(callType, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: HestiaSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HestiaCircleAction(
              icon: Icons.call_end,
              color: scheme.error,
              onTap: onDecline,
            ),
            const SizedBox(width: HestiaSpacing.xl),
            HestiaCircleAction(
              icon: video ? Icons.videocam : Icons.call,
              color: scheme.primary,
              onTap: onAccept,
            ),
          ],
        ),
      ],
    );
    return framed ? HestiaSurfaceCard(child: content) : content;
  }
}

class HestiaContactRequestCard extends StatelessWidget {
  final String username;
  final String subtitle;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const HestiaContactRequestCard({
    super.key,
    required this.username,
    required this.subtitle,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return HestiaSurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: HestiaSpacing.lg,
        vertical: HestiaSpacing.md,
      ),
      child: Row(
        children: [
          HestiaAvatar(label: username),
          const SizedBox(width: HestiaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(username, style: Theme.of(context).textTheme.titleLarge),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(onPressed: onDecline, icon: const Icon(Icons.close)),
          IconButton.filled(onPressed: onAccept, icon: const Icon(Icons.check)),
        ],
      ),
    );
  }
}

class HestiaAvatar extends StatelessWidget {
  final String label;
  final double radius;

  const HestiaAvatar({
    super.key,
    required this.label,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.72,
        ),
      ),
    );
  }
}

class HestiaIconTile extends StatelessWidget {
  final IconData icon;

  const HestiaIconTile({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
    );
  }
}

class HestiaCircleAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const HestiaCircleAction({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HestiaPressable(
      onTap: onTap,
      haptic: true,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
