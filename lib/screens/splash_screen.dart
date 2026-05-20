import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../widgets/motion.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: HestiaFadeScale(
          beginScale: 0.95,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                dark ? 'assets/logo/logo_dark.png' : 'assets/logo/logo.png',
                width: 96,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 18),
              Text(
                context.l10n.splashTagline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


