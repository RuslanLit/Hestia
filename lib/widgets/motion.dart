import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HestiaMotion {
  const HestiaMotion._();

  static const fast = Duration(milliseconds: 120);
  static const normal = Duration(milliseconds: 180);
  static const slow = Duration(milliseconds: 240);
  static const curve = Curves.easeOutCubic;

  static void lightImpact() {
    HapticFeedback.lightImpact();
  }

  static Route<T> route<T>(WidgetBuilder builder) {
    return PageRouteBuilder<T>(
      transitionDuration: normal,
      reverseTransitionDuration: fast,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: curve);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.025, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class HestiaPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final bool haptic;
  final double pressedScale;

  const HestiaPressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.haptic = false,
    this.pressedScale = 0.97,
  });

  @override
  State<HestiaPressable> createState() => _HestiaPressableState();
}

class _HestiaPressableState extends State<HestiaPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() {
      _pressed = value;
    });
  }

  void _tap() {
    if (widget.haptic) {
      HestiaMotion.lightImpact();
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return AnimatedScale(
      scale: enabled && _pressed ? widget.pressedScale : 1,
      duration: HestiaMotion.fast,
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? _tap : null,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          borderRadius: widget.borderRadius,
          child: widget.child,
        ),
      ),
    );
  }
}

class HestiaListEntrance extends StatelessWidget {
  final Widget child;
  final int index;
  final Offset beginOffset;

  const HestiaListEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.beginOffset = const Offset(0, 12),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: HestiaMotion.normal,
      curve: HestiaMotion.curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              beginOffset.dx * (1 - value),
              beginOffset.dy * (1 - value),
            ),
            child: child,
          ),
        );
      },
      child: AnimatedSize(
        duration: HestiaMotion.normal,
        curve: HestiaMotion.curve,
        alignment: Alignment.topCenter,
        child: child,
      ),
    );
  }
}

class HestiaFadeScale extends StatelessWidget {
  final Widget child;
  final double beginScale;

  const HestiaFadeScale({
    super.key,
    required this.child,
    this.beginScale = 0.98,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: HestiaMotion.normal,
      curve: HestiaMotion.curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: beginScale + ((1 - beginScale) * value),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}


