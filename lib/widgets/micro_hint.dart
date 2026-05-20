import 'package:flutter/material.dart';

import '../services/micro_onboarding_service.dart';
import 'motion.dart';

class MicroHint extends StatefulWidget {
  final MicroOnboardingHint hint;
  final IconData icon;
  final String text;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const MicroHint({
    super.key,
    required this.hint,
    required this.icon,
    required this.text,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<MicroHint> createState() => _MicroHintState();
}

class _MicroHintState extends State<MicroHint> {
  final _service = MicroOnboardingService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final show = _service.shouldShow(widget.hint);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: HestiaMotion.normal,
          child: show
              ? Padding(
                  key: ValueKey(widget.hint),
                  padding: widget.padding,
                  child: _HintBubble(
                    icon: widget.icon,
                    text: widget.text,
                    onClose: () => _service.markSeen(widget.hint),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        AnimatedContainer(
          duration: HestiaMotion.normal,
          curve: HestiaMotion.curve,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: show
                ? Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.36),
                    width: 1.5,
                  )
                : null,
          ),
          padding: show ? const EdgeInsets.all(4) : EdgeInsets.zero,
          child: widget.child,
        ),
      ],
    );
  }
}

class _HintBubble extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onClose;

  const _HintBubble({
    required this.icon,
    required this.text,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return HestiaFadeScale(
      beginScale: 0.98,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: scheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


