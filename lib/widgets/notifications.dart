import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'ui_kit.dart';

const _desktopBreakpoint = 700.0;
const _desktopNotificationMaxWidth = 460.0;

void showHestiaSnackBar(
  BuildContext context,
  String message, {
  HestiaStatusTone tone = HestiaStatusTone.info,
}) {
  final media = MediaQuery.sizeOf(context);
  final isWide = media.width >= _desktopBreakpoint;
  final colors = _notificationColors(context, tone);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      width: isWide
          ? media.width.clamp(0, _desktopNotificationMaxWidth).toDouble()
          : null,
      margin: isWide
          ? null
          : EdgeInsets.fromLTRB(
              HestiaSpacing.lg,
              HestiaSpacing.lg,
              HestiaSpacing.lg,
              HestiaSpacing.lg + MediaQuery.viewPaddingOf(context).bottom,
            ),
      elevation: 10,
      backgroundColor: colors.background,
      padding: const EdgeInsets.symmetric(
        horizontal: HestiaSpacing.lg,
        vertical: HestiaSpacing.md,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border),
      ),
      content: _HestiaNotificationContent(
        message: message,
        tone: tone,
        colors: colors,
      ),
    ),
  );
}

class HestiaNotificationBanner extends StatelessWidget {
  final String message;
  final HestiaStatusTone tone;

  const HestiaNotificationBanner({
    super.key,
    required this.message,
    this.tone = HestiaStatusTone.info,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _notificationColors(context, tone);

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        minimum: const EdgeInsets.all(HestiaSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: _desktopNotificationMaxWidth,
          ),
          child: Material(
            color: colors.background,
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HestiaSpacing.lg,
                vertical: HestiaSpacing.md,
              ),
              child: _HestiaNotificationContent(
                message: message,
                tone: tone,
                colors: colors,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HestiaNotificationContent extends StatelessWidget {
  final String message;
  final HestiaStatusTone tone;
  final _NotificationColors colors;

  const _HestiaNotificationContent({
    required this.message,
    required this.tone,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_iconForTone(tone), color: colors.accent, size: 20),
        const SizedBox(width: HestiaSpacing.md),
        Expanded(
          child: Text(
            message,
            softWrap: true,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.foreground,
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}

IconData _iconForTone(HestiaStatusTone tone) {
  return switch (tone) {
    HestiaStatusTone.success => Icons.check_circle_outline,
    HestiaStatusTone.warning => Icons.warning_amber_rounded,
    HestiaStatusTone.error => Icons.error_outline,
    HestiaStatusTone.info => Icons.info_outline,
    HestiaStatusTone.neutral => Icons.notifications_none,
  };
}

_NotificationColors _notificationColors(
  BuildContext context,
  HestiaStatusTone tone,
) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final states = theme.extension<HestiaStateColors>()!;
  final accent = switch (tone) {
    HestiaStatusTone.success => states.success,
    HestiaStatusTone.warning => states.warning,
    HestiaStatusTone.error => states.error,
    HestiaStatusTone.info => states.info,
    HestiaStatusTone.neutral => scheme.primary,
  };
  final tintAlpha = theme.brightness == Brightness.dark ? 0.24 : 0.12;
  final background = Color.alphaBlend(
    accent.withValues(alpha: tintAlpha),
    scheme.surface,
  );

  return _NotificationColors(
    accent: accent,
    background: background,
    border: accent.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.36 : 0.24,
    ),
    foreground: scheme.onSurface,
  );
}

class _NotificationColors {
  final Color accent;
  final Color background;
  final Color border;
  final Color foreground;

  const _NotificationColors({
    required this.accent,
    required this.background,
    required this.border,
    required this.foreground,
  });
}


