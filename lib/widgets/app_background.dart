import 'package:flutter/material.dart';

import '../models/background_settings.dart';
import '../services/background_service.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final background = BackgroundService.instance;
    final settings = background.settings;
    DecorationImage? image;
    Color color = Theme.of(context).scaffoldBackgroundColor;
    if (settings.type == BackgroundType.color && settings.colorValue != null) {
      color = Color(settings.colorValue!);
    } else if (settings.type == BackgroundType.image &&
        background.imageProvider != null) {
      image = DecorationImage(
        image: background.imageProvider!,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        image: image,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _overlayColor(context, settings.type),
        ),
        child: child,
      ),
    );
  }

  Color _overlayColor(BuildContext context, BackgroundType type) {
    if (type == BackgroundType.defaultTheme) {
      return Colors.transparent;
    }
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? scheme.surface.withValues(alpha: 0.48)
        : scheme.surface.withValues(alpha: 0.38);
  }
}
