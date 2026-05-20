import 'package:flutter/material.dart';
import 'package:hestia/config.dart';
import 'package:hestia/l10n/l10n.dart';

class LoginScreen extends StatefulWidget {
  final Future<void> Function(String nickname, String password) onLogin;
  final Future<void> Function(String nickname, String password) onRegister;
  final bool initialRegisterMode;

  const LoginScreen({
    super.key,
    required this.onLogin,
    required this.onRegister,
    this.initialRegisterMode = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nicknameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _serverCtrl = TextEditingController(text: AppConfig.serverInput);
  bool _busy = false;
  String? _error;
  late bool _registerMode;
  bool _obscurePassword = true;
  bool _showServer = false;

  @override
  void initState() {
    super.initState();
    _registerMode = widget.initialRegisterMode;
  }

  Future<void> _submit() async {
    final nick = _nicknameCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (nick.isEmpty) {
      setState(() {
        _error = context.l10n.nicknameRequired;
      });
      return;
    }
    if (password.isEmpty) {
      setState(() {
        _error = context.l10n.passwordRequired;
      });
      return;
    }
    if (_registerMode && nick.length < 2) {
      setState(() {
        _error = context.l10n.nicknameTooShort;
      });
      return;
    }
    if (_registerMode && password.length < 6) {
      setState(() {
        _error = context.l10n.passwordTooShort;
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppConfig.setServerInput(_serverCtrl.text);
      if (_registerMode) {
        await widget.onRegister(nick, password);
      } else {
        await widget.onLogin(nick, password);
      }
    } catch (e) {
      setState(() {
        _error = context.localizedError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _passwordCtrl.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 72,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.appName,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${l10n.server}: ${AppConfig.host}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () {
                                    setState(() {
                                      _showServer = !_showServer;
                                    });
                                  },
                            icon: const Icon(Icons.dns_outlined),
                            label: Text(l10n.server),
                          ),
                          if (_showServer) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: _serverCtrl,
                              decoration: InputDecoration(
                                labelText: l10n.serverUrl,
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                            ),
                          ],
                          const SizedBox(height: 36),
                          SegmentedButton<bool>(
                            segments: [
                              ButtonSegment(
                                value: false,
                                label: Text(l10n.login),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(l10n.registration),
                              ),
                            ],
                            selected: {_registerMode},
                            onSelectionChanged: _busy
                                ? null
                                : (values) {
                                    setState(() {
                                      _registerMode = values.first;
                                      _error = null;
                                    });
                                  },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nicknameCtrl,
                            decoration: InputDecoration(
                              labelText: _registerMode
                                  ? l10n.chooseNickname
                                  : l10n.yourNickname,
                              border: const OutlineInputBorder(),
                            ),
                            textInputAction: TextInputAction.next,
                            autofocus: true,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordCtrl,
                            decoration: InputDecoration(
                              labelText: _registerMode
                                  ? l10n.choosePassword
                                  : l10n.password,
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? l10n.showPassword
                                    : l10n.hidePassword,
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                              ),
                            ),
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _registerMode
                                          ? l10n.register
                                          : l10n.continueAction,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


