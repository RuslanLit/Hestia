import 'package:flutter/material.dart';
import 'package:hestia/config.dart';
import 'package:hestia/l10n/l10n.dart';
import 'package:hestia/services/product_content_service.dart';
import 'package:hestia/theme/theme.dart';
import 'package:hestia/widgets/ui_kit.dart';

class OnboardingScreen extends StatefulWidget {
  final void Function({required bool registerMode}) onFinish;

  const OnboardingScreen({
    super.key,
    required this.onFinish,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  final _serverCtrl = TextEditingController(text: AppConfig.serverInput);
  int _index = 0;
  bool _customServer = AppConfig.host != AppConfig.defaultHost;
  bool _savingServer = false;
  String? _serverError;

  @override
  void dispose() {
    _controller.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index == 1) {
      final saved = await _saveServerChoice();
      if (!saved) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    if (_index == 2) {
      await _finish(registerMode: true);
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish({required bool registerMode}) async {
    final saved = await _saveServerChoice();
    if (!mounted) {
      return;
    }
    if (!saved) {
      await _controller.animateToPage(
        1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    widget.onFinish(registerMode: registerMode);
  }

  Future<bool> _saveServerChoice() async {
    setState(() {
      _savingServer = true;
      _serverError = null;
    });
    try {
      await AppConfig.setServerInput(
        _customServer ? _serverCtrl.text : AppConfig.defaultServerInput,
      );
      if (!_customServer) {
        _serverCtrl.text = AppConfig.serverInput;
      }
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _serverError = context.localizedError(error);
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _savingServer = false;
        });
      }
    }
  }

  void _skip() => widget.onFinish(registerMode: false);

  List<_OnboardingPageData> _pages(
    BuildContext context,
    ProductLocaleContent content,
  ) {
    return [
      _OnboardingPageData(
        icon: Icons.forum_outlined,
        title: content.hero.title,
        body: content.hero.body,
      ),
      _OnboardingPageData(
        icon: Icons.dns_outlined,
        title: content.serverChoice.title,
        body: content.serverChoice.body,
        content: _ServerChoice(
          customServer: _customServer,
          controller: _serverCtrl,
          saving: _savingServer,
          errorText: _serverError,
          defaultLabel: content.serverChoice.defaultLabel,
          customLabel: content.serverChoice.customLabel,
          customBody: content.serverChoice.customBody,
          onCustomChanged: (value) {
            setState(() {
              _customServer = value;
              _serverError = null;
            });
          },
        ),
      ),
      _OnboardingPageData(
        icon: Icons.arrow_forward,
        title: content.getStarted.title,
        body: content.getStarted.body,
        content: _GetStartedActions(
          onRegister: () => _finish(registerMode: true),
          onLogin: () => _finish(registerMode: false),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<ProductContent>(
          future: ProductContentService.instance.load(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final content = snapshot.data!.locale(
              Localizations.localeOf(context).languageCode,
            );
            final pages = _pages(context, content);
            final isLast = _index == pages.length - 1;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    HestiaSpacing.lg,
                    HestiaSpacing.sm,
                    HestiaSpacing.lg,
                    0,
                  ),
                  child: Row(
                    children: [
                      Text(
                        l10n.appName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _skip,
                        child: Text(l10n.onboardingSkip),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: pages.length,
                    onPageChanged: (value) {
                      setState(() {
                        _index = value;
                      });
                    },
                    itemBuilder: (context, index) {
                      return _OnboardingPage(data: pages[index]);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(HestiaSpacing.lg),
                  child: Row(
                    children: [
                      _Dots(count: pages.length, index: _index),
                      const Spacer(),
                      HestiaButton.primary(
                        onPressed: _savingServer ? null : _next,
                        label: Text(
                          isLast
                              ? content.getStarted.primary
                              : l10n.onboardingNext,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String body;
  final Widget? content;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.body,
    this.content,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData data;

  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(HestiaSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  data.icon,
                  size: 42,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: HestiaSpacing.xxl),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: HestiaSpacing.md),
              Text(
                data.body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              if (data.content != null) ...[
                const SizedBox(height: HestiaSpacing.xxl),
                data.content!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerChoice extends StatelessWidget {
  final bool customServer;
  final bool saving;
  final String? errorText;
  final String defaultLabel;
  final String customLabel;
  final String customBody;
  final TextEditingController controller;
  final ValueChanged<bool> onCustomChanged;

  const _ServerChoice({
    required this.customServer,
    required this.saving,
    required this.errorText,
    required this.defaultLabel,
    required this.customLabel,
    required this.customBody,
    required this.controller,
    required this.onCustomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return HestiaSurfaceCard(
      child: Column(
        children: [
          _ServerOption(
            selected: !customServer,
            enabled: !saving,
            title: Text(defaultLabel),
            subtitle: Text(AppConfig.defaultServerInput),
            onTap: () => onCustomChanged(false),
          ),
          _ServerOption(
            selected: customServer,
            enabled: !saving,
            title: Text(customLabel),
            subtitle: Text(customBody),
            onTap: () => onCustomChanged(true),
          ),
          if (customServer) ...[
            const SizedBox(height: HestiaSpacing.md),
            HestiaTextInput(
              controller: controller,
              label: context.l10n.serverUrl,
              hint: 'https://hestiachat.site',
              prefixIcon: Icons.link,
              textInputAction: TextInputAction.done,
            ),
            if (errorText != null) ...[
              const SizedBox(height: HestiaSpacing.sm),
              Text(
                errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ServerOption extends StatelessWidget {
  final bool selected;
  final bool enabled;
  final Widget title;
  final Widget subtitle;
  final VoidCallback onTap;

  const _ServerOption({
    required this.selected,
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: title,
      subtitle: subtitle,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _GetStartedActions extends StatelessWidget {
  final VoidCallback onRegister;
  final VoidCallback onLogin;

  const _GetStartedActions({
    required this.onRegister,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        HestiaButton.primary(
          expanded: true,
          onPressed: onRegister,
          label: Text(l10n.register),
        ),
        const SizedBox(height: HestiaSpacing.md),
        HestiaButton.outline(
          expanded: true,
          onPressed: onLogin,
          label: Text(l10n.login),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;

  const _Dots({
    required this.count,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(count, (item) {
        final selected = item == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: selected ? 22 : 8,
          height: 8,
          margin: const EdgeInsets.only(right: HestiaSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.outline,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
