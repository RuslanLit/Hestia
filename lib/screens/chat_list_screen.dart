import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../services/call_service.dart';
import '../services/chat_service.dart';
import '../services/diagnostic_service.dart';
import '../services/locale_service.dart';
import '../services/micro_onboarding_service.dart';
import '../services/retention_service.dart';
import '../services/storage_service.dart';
import '../services/theme_service.dart';
import '../services/background_service.dart';
import '../models/background_settings.dart';
import '../widgets/app_background.dart';
import '../widgets/micro_hint.dart';
import '../widgets/motion.dart';
import '../widgets/notifications.dart';
import '../widgets/ui_kit.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final int initialTabIndex;

  const ChatListScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  final _chat = ChatService.instance;
  final _retention = RetentionService.instance;
  final _searchCtrl = TextEditingController();
  final _listSearchCtrl = TextEditingController();
  late final TabController _tabController;
  String? _selectedPeerUserId;
  String? _selectedPeerNickname;
  bool _showDevicesPane = false;
  bool _retentionBannerDismissed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    )..addListener(_handleTabChanged);
    if (_tabController.index == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _chat.markContactRequestsSeen();
      });
    }
    _chat.addListener(_refresh);
    _retention.addListener(_refresh);
    _chat.requestUsers();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _chat.removeListener(_refresh);
    _retention.removeListener(_refresh);
    _searchCtrl.dispose();
    _listSearchCtrl.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!_tabController.indexIsChanging && _tabController.index == 2) {
      _chat.markContactRequestsSeen();
    }
    if (_usesDesktopLayout(context) && _showDevicesPane) {
      setState(() => _showDevicesPane = false);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _reload() => _chat.requestUsers();

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.logoutConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.logout),
            label: Text(context.l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _chat.logoutCurrentSession();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _editServer() async {
    final controller = TextEditingController(text: AppConfig.serverInput);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.server),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: context.l10n.serverUrl,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (next == null) return;

    await AppConfig.setServerInput(next);
    await _chat.reconnect();
    if (mounted) setState(() {});
  }

  Future<void> _editPrivacy() async {
    var settings = _chat.privacySettings;
    final next = await showDialog<PrivacySettings>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.privacy),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                value: settings.allowUserDiscovery,
                onChanged: (value) {
                  setDialogState(() {
                    settings = PrivacySettings(
                      allowUserDiscovery: value,
                      allowMessagesFrom: settings.allowMessagesFrom,
                      allowCallsFrom: settings.allowCallsFrom,
                    );
                  });
                },
                title: Text(context.l10n.allowUsernameSearch),
              ),
              DropdownButtonFormField<PrivacyAllowFrom>(
                initialValue: settings.allowMessagesFrom,
                decoration:
                    InputDecoration(labelText: context.l10n.messagesFrom),
                items: [
                  DropdownMenuItem(
                    value: PrivacyAllowFrom.contacts,
                    child: Text(context.l10n.contacts),
                  ),
                  DropdownMenuItem(
                    value: PrivacyAllowFrom.everyone,
                    child: Text(context.l10n.everyone),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    settings = PrivacySettings(
                      allowUserDiscovery: settings.allowUserDiscovery,
                      allowMessagesFrom: value,
                      allowCallsFrom: settings.allowCallsFrom,
                    );
                  });
                },
              ),
              DropdownButtonFormField<PrivacyAllowFrom>(
                initialValue: settings.allowCallsFrom,
                decoration: InputDecoration(labelText: context.l10n.callsFrom),
                items: [
                  DropdownMenuItem(
                    value: PrivacyAllowFrom.contacts,
                    child: Text(context.l10n.contacts),
                  ),
                  DropdownMenuItem(
                    value: PrivacyAllowFrom.everyone,
                    child: Text(context.l10n.everyone),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    settings = PrivacySettings(
                      allowUserDiscovery: settings.allowUserDiscovery,
                      allowMessagesFrom: settings.allowMessagesFrom,
                      allowCallsFrom: value,
                    );
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(settings),
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
    if (next != null) await _chat.updatePrivacySettings(next);
  }

  Future<void> _showBlockedUsers() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const _BlockedUsersDialog(),
    );
  }

  Future<void> _showFindUser() async {
    unawaited(
      MicroOnboardingService.instance.markSeen(MicroOnboardingHint.addContact),
    );
    await showDialog<void>(
      context: context,
      builder: (_) => const _FindUserDialog(),
    );
  }

  Future<void> _showBackup() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _BackupDialog(),
    );
  }

  Future<void> _showDevices() async {
    if (_usesDesktopLayout(context)) {
      setState(() {
        _showDevicesPane = true;
        _selectedPeerUserId = null;
        _selectedPeerNickname = null;
      });
      await _chat.requestSessions();
      return;
    }
    await _chat.requestSessions();
    if (!mounted) return;
    await Navigator.of(context).push(
      HestiaMotion.route((_) => const _MobileDevicesScreen()),
    );
  }

  Future<void> _showDiagnostics() async {
    var enabled = DiagnosticService.instance.enabled;
    var report = await _chat.diagnosticReport();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.diagnostics),
          content: SizedBox(
            width: 720,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  value: enabled,
                  onChanged: (value) async {
                    await DiagnosticService.instance.setEnabled(value);
                    report = await _chat.diagnosticReport();
                    setDialogState(() => enabled = value);
                  },
                  title: Text(context.l10n.diagnosticMode),
                  subtitle: Text(context.l10n.diagnosticModeDescription),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        report,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                report = await _chat.diagnosticReport();
                setDialogState(() {});
              },
              child: Text(context.l10n.refresh),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                if (!DiagnosticService.instance.enabled) {
                  await DiagnosticService.instance.setEnabled(true);
                  enabled = true;
                }
                await CallService.instance
                    .runDesktopAudioEnumerationDiagnostic();
                report = await _chat.diagnosticReport();
                setDialogState(() {});
              },
              icon: const Icon(Icons.mic),
              label: Text(context.l10n.testMicrophone),
            ),
            FilledButton.icon(
              onPressed: () async {
                final latest = await _chat.diagnosticReport();
                await Clipboard.setData(ClipboardData(text: latest));
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.copy),
              label: Text(context.l10n.copyDiagnostics),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editLanguage() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _LanguageDialog(),
    );
  }

  Future<void> _editTheme() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _ThemeDialog(),
    );
  }

  void _openChat(String peerUserId, String username) {
    if (_usesDesktopLayout(context)) {
      setState(() {
        _showDevicesPane = false;
        _selectedPeerUserId = peerUserId;
        _selectedPeerNickname = username;
      });
      _chat.markConversationRead(makeConversationId(
        _chat.profile?.userId ?? '',
        peerUserId,
      ));
      return;
    }

    Navigator.of(context).push(
      HestiaMotion.route(
        (_) => ChatScreen(
          peerUserId: peerUserId,
          peerNickname: username,
        ),
      ),
    );
  }

  bool _usesDesktopLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  String? _retentionHintText(BuildContext context) {
    if (_retentionBannerDismissed) {
      return null;
    }
    final l10n = context.l10n;
    if (_chat.unreadChatCount > 0) {
      return l10n.retentionNewMessages;
    }
    if (!_retention.hasContacts) {
      return null;
    }
    if (!_retention.hasSentMessage) {
      return l10n.retentionStartChatHint;
    }
    return switch (_retention.startupReminder) {
      RetentionReminder.threeDays => l10n.retentionThreeDayReminder,
      RetentionReminder.day => l10n.retentionDayReminder,
      RetentionReminder.none => null,
    };
  }

  String _connectionSubtitle(BuildContext context) {
    final l10n = context.l10n;
    return switch (_chat.connectionStatus) {
      ServerConnectionStatus.connecting => _localizedConnectionText(
          context,
          ru: 'Подключение...',
          en: 'Connecting...',
        ),
      ServerConnectionStatus.connected => l10n.serverConnected(AppConfig.host),
      ServerConnectionStatus.authError => _localizedConnectionText(
          context,
          ru: 'Ошибка авторизации',
          en: 'Authorization error',
        ),
      ServerConnectionStatus.serverError => _localizedConnectionText(
          context,
          ru: 'Ошибка сервера',
          en: 'Server error',
        ),
      ServerConnectionStatus.disconnected => l10n.serverDisconnected,
    };
  }

  String _localizedConnectionText(
    BuildContext context, {
    required String ru,
    required String en,
  }) {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'ru' || code == 'uk' ? ru : en;
  }

  @override
  Widget build(BuildContext context) {
    if (_usesDesktopLayout(context)) {
      return _buildDesktop(context);
    }
    return _buildMobile(context);
  }

  Widget _buildMobile(BuildContext context) {
    final profile = _chat.profile;
    final unreadChats = _chat.unreadChatCount;
    final newRequests = _chat.newContactRequestCount;
    final l10n = context.l10n;
    final useCompactAndroidToolbar =
        Theme.of(context).platform == TargetPlatform.android;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        titleSpacing: useCompactAndroidToolbar ? 0 : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _connectionSubtitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: useCompactAndroidToolbar
            ? _compactAndroidToolbarActions(context)
            : _fullMobileToolbarActions(context),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: _TabIconWithBadge(
                icon: Icons.chat_bubble_outline,
                count: unreadChats,
              ),
              text: l10n.chats,
            ),
            Tab(icon: const Icon(Icons.people_outline), text: l10n.contacts),
            Tab(
              icon: _TabIconWithBadge(
                icon: Icons.inbox_outlined,
                count: newRequests,
              ),
              text: l10n.requests,
            ),
          ],
        ),
      ),
      body: AppBackground(
        child: Column(
          children: [
            _AccountSummary(profile: profile),
            _RetentionBanner(
              text: _retentionHintText(context),
              onDismiss: () => setState(() {
                _retentionBannerDismissed = true;
              }),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ChatsTab(onOpenChat: _openChat),
                  _ContactsTab(
                    searchCtrl: _searchCtrl,
                    onAddContact: _showFindUser,
                    onOpenChat: _openChat,
                  ),
                  const _RequestsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: MicroHint(
        hint: MicroOnboardingHint.addContact,
        icon: Icons.person_search,
        text: l10n.hintAddContact,
        padding: const EdgeInsets.only(bottom: 10),
        child: _MotionExtendedFab(
          onPressed: _showFindUser,
          icon: Icons.person_add_alt_1,
          label: Text(l10n.addContact),
        ),
      ),
    );
  }

  List<Widget> _fullMobileToolbarActions(BuildContext context) {
    final l10n = context.l10n;
    return [
      _MotionIconButton(
        onPressed: _reload,
        tooltip: l10n.refresh,
        icon: Icons.refresh,
      ),
      _MotionIconButton(
        onPressed: _editPrivacy,
        tooltip: l10n.privacy,
        icon: Icons.privacy_tip_outlined,
      ),
      _MotionIconButton(
        onPressed: _showBlockedUsers,
        tooltip: l10n.blockedUsers,
        icon: Icons.block,
      ),
      if (AppConfig.enableBackupUi)
        _MotionIconButton(
          onPressed: _showBackup,
          tooltip: l10n.backup,
          icon: Icons.backup_outlined,
        ),
      _MotionIconButton(
        onPressed: _showDevices,
        tooltip: l10n.devices,
        icon: Icons.devices_other,
      ),
      _MotionIconButton(
        onPressed: _showDiagnostics,
        tooltip: l10n.diagnostics,
        icon: Icons.bug_report_outlined,
      ),
      _MotionIconButton(
        onPressed: _editLanguage,
        tooltip: l10n.language,
        icon: Icons.language,
      ),
      _MotionIconButton(
        onPressed: _editTheme,
        tooltip: l10n.theme,
        icon: Icons.brightness_6_outlined,
      ),
      _MotionIconButton(
        onPressed: _editServer,
        tooltip: l10n.server,
        icon: Icons.dns_outlined,
      ),
      _MotionIconButton(
        onPressed: _confirmLogout,
        tooltip: l10n.logout,
        icon: Icons.logout,
      ),
    ];
  }

  List<Widget> _compactAndroidToolbarActions(BuildContext context) {
    final l10n = context.l10n;
    return [
      _MotionIconButton(
        onPressed: _reload,
        tooltip: l10n.refresh,
        icon: Icons.refresh,
        size: 44,
      ),
      _MotionIconButton(
        onPressed: _editPrivacy,
        tooltip: l10n.privacy,
        icon: Icons.privacy_tip_outlined,
        size: 44,
      ),
      PopupMenuButton<String>(
        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case 'blocked':
              _showBlockedUsers();
            case 'backup':
              _showBackup();
            case 'devices':
              _showDevices();
            case 'diagnostics':
              _showDiagnostics();
            case 'language':
              _editLanguage();
            case 'theme':
              _editTheme();
            case 'server':
              _editServer();
            case 'logout':
              _confirmLogout();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'blocked',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.block),
              title: Text(l10n.blockedUsers),
            ),
          ),
          if (AppConfig.enableBackupUi)
            PopupMenuItem(
              value: 'backup',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.backup_outlined),
                title: Text(l10n.backup),
              ),
            ),
          PopupMenuItem(
            value: 'devices',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.devices_other),
              title: Text(l10n.devices),
            ),
          ),
          PopupMenuItem(
            value: 'diagnostics',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bug_report_outlined),
              title: Text(l10n.diagnostics),
            ),
          ),
          PopupMenuItem(
            value: 'language',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language),
              title: Text(l10n.language),
            ),
          ),
          PopupMenuItem(
            value: 'theme',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.brightness_6_outlined),
              title: Text(l10n.theme),
            ),
          ),
          PopupMenuItem(
            value: 'server',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dns_outlined),
              title: Text(l10n.server),
            ),
          ),
          PopupMenuItem(
            value: 'logout',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout),
              title: Text(l10n.logout),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildDesktop(BuildContext context) {
    final profile = _chat.profile;
    final unreadChats = _chat.unreadChatCount;
    final newRequests = _chat.newContactRequestCount;
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final selectedPeerUserId = _selectedPeerUserId;
    final selectedPeerNickname = _selectedPeerNickname;
    final listQuery = _listSearchCtrl.text;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerHighest,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1360),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.symmetric(
                  vertical: BorderSide(color: scheme.outline),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 348,
                    child: Material(
                      color: scheme.surface,
                      child: Column(
                        children: [
                          _DesktopLeftHeader(
                            title: l10n.appName,
                            subtitle: _connectionSubtitle(context),
                            onAddContact: _showFindUser,
                            onReload: _reload,
                            onPrivacy: _editPrivacy,
                            onBlockedUsers: _showBlockedUsers,
                            onBackup: _showBackup,
                            onDevices: _showDevices,
                            onDiagnostics: _showDiagnostics,
                            onLanguage: _editLanguage,
                            onTheme: _editTheme,
                            onServer: _editServer,
                            onLogout: _confirmLogout,
                          ),
                          _AccountSummary(profile: profile, compact: true),
                          _DesktopListSearch(
                            controller: _listSearchCtrl,
                            onChanged: (_) => setState(() {}),
                          ),
                          _RetentionBanner(
                            text: _retentionHintText(context),
                            compact: true,
                            onDismiss: () => setState(() {
                              _retentionBannerDismissed = true;
                            }),
                          ),
                          TabBar(
                            controller: _tabController,
                            tabs: [
                              Tab(
                                icon: _TabIconWithBadge(
                                  icon: Icons.chat_bubble_outline,
                                  count: unreadChats,
                                ),
                                text: l10n.chats,
                              ),
                              Tab(
                                icon: const Icon(Icons.people_outline),
                                text: l10n.contacts,
                              ),
                              Tab(
                                icon: _TabIconWithBadge(
                                  icon: Icons.inbox_outlined,
                                  count: newRequests,
                                ),
                                text: l10n.requests,
                              ),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _ChatsTab(
                                  searchQuery: listQuery,
                                  selectedPeerUserId: selectedPeerUserId,
                                  onAddContact: _showFindUser,
                                  onOpenChat: _openChat,
                                ),
                                _ContactsTab(
                                  searchCtrl: _searchCtrl,
                                  searchQuery: listQuery,
                                  selectedPeerUserId: selectedPeerUserId,
                                  onAddContact: _showFindUser,
                                  onOpenChat: _openChat,
                                ),
                                _RequestsTab(searchQuery: listQuery),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  VerticalDivider(width: 1, color: scheme.outline),
                  Expanded(
                    child: _showDevicesPane
                        ? const _DesktopDevicesPane()
                        : selectedPeerUserId == null ||
                                selectedPeerNickname == null
                            ? const _DesktopEmptyChatPane()
                            : ChatScreen(
                                key: ValueKey(
                                  'desktop_chat_$selectedPeerUserId',
                                ),
                                peerUserId: selectedPeerUserId,
                                peerNickname: selectedPeerNickname,
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountSummary extends StatelessWidget {
  final UserProfile? profile;
  final bool compact;

  const _AccountSummary({
    required this.profile,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final current = profile;
    if (current == null) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 16,
        compact ? 8 : 12,
        compact ? 12 : 16,
        compact ? 6 : 8,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 10,
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_circle_outlined,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${context.l10n.yourNickname}: ${current.nickname}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (compact ? textTheme.bodyMedium : textTheme.titleSmall)
                      ?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabIconWithBadge extends StatelessWidget {
  final IconData icon;
  final int count;

  const _TabIconWithBadge({
    required this.icon,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return Icon(icon);
    return Badge.count(
      count: count,
      child: Icon(icon),
    );
  }
}

class _MotionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool haptic;
  final double size;

  const _MotionIconButton({
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

class _MotionExtendedFab extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final Widget label;

  const _MotionExtendedFab({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return HestiaPressable(
      onTap: onPressed,
      haptic: true,
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.14),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: scheme.onPrimary, size: 20),
              const SizedBox(width: 10),
              DefaultTextStyle.merge(
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
                child: label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopLeftHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onAddContact;
  final VoidCallback onReload;
  final VoidCallback onPrivacy;
  final VoidCallback onBlockedUsers;
  final VoidCallback onBackup;
  final VoidCallback onDevices;
  final VoidCallback onDiagnostics;
  final VoidCallback onLanguage;
  final VoidCallback onTheme;
  final VoidCallback onServer;
  final VoidCallback onLogout;

  const _DesktopLeftHeader({
    required this.title,
    required this.subtitle,
    required this.onAddContact,
    required this.onReload,
    required this.onPrivacy,
    required this.onBlockedUsers,
    required this.onBackup,
    required this.onDevices,
    required this.onDiagnostics,
    required this.onLanguage,
    required this.onTheme,
    required this.onServer,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _MotionIconButton(
                  onPressed: onAddContact,
                  tooltip: context.l10n.addContact,
                  icon: Icons.person_add_alt_1,
                  haptic: true,
                ),
                _MotionIconButton(
                  onPressed: onReload,
                  tooltip: context.l10n.refresh,
                  icon: Icons.refresh,
                ),
                PopupMenuButton<String>(
                  tooltip: context.l10n.settings,
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'privacy':
                        onPrivacy();
                      case 'blocked':
                        onBlockedUsers();
                      case 'backup':
                        onBackup();
                      case 'devices':
                        onDevices();
                      case 'diagnostics':
                        onDiagnostics();
                      case 'language':
                        onLanguage();
                      case 'theme':
                        onTheme();
                      case 'server':
                        onServer();
                      case 'logout':
                        onLogout();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'privacy',
                      child: Text(context.l10n.privacy),
                    ),
                    PopupMenuItem(
                      value: 'blocked',
                      child: Text(context.l10n.blockedUsers),
                    ),
                    if (AppConfig.enableBackupUi)
                      PopupMenuItem(
                        value: 'backup',
                        child: Text(context.l10n.backup),
                      ),
                    PopupMenuItem(
                      value: 'devices',
                      child: Text(context.l10n.devices),
                    ),
                    PopupMenuItem(
                      value: 'diagnostics',
                      child: Text(context.l10n.diagnostics),
                    ),
                    PopupMenuItem(
                      value: 'language',
                      child: Text(context.l10n.language),
                    ),
                    PopupMenuItem(
                      value: 'theme',
                      child: Text(context.l10n.theme),
                    ),
                    PopupMenuItem(
                      value: 'server',
                      child: Text(context.l10n.server),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: Text(context.l10n.logout),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopListSearch extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _DesktopListSearch({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: context.l10n.search,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: context.l10n.close,
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: const Icon(Icons.close),
                  ),
            isDense: true,
          ),
        ),
      ),
    );
  }
}

class _DesktopEmptyChatPane extends StatelessWidget {
  const _DesktopEmptyChatPane();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Center(
        child: Text(
          context.l10n.chats,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _ThemeDialog extends StatefulWidget {
  const _ThemeDialog();

  @override
  State<_ThemeDialog> createState() => _ThemeDialogState();
}

class _ThemeDialogState extends State<_ThemeDialog> {
  bool _busy = false;
  String? _error;

  static const _backgroundColors = [
    Color(0xFFFAF7F2),
    Color(0xFFF4ECE3),
    Color(0xFFFFF1E2),
    Color(0xFFF6EAE8),
    Color(0xFF171A1F),
    Color(0xFF222832),
    Color(0xFF2B3340),
    Color(0xFF332D38),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = ThemeService.instance.themeMode;
    final background = BackgroundService.instance.settings;
    final modes = <ThemeMode, String>{
      ThemeMode.system: l10n.themeSystem,
      ThemeMode.light: l10n.themeLight,
      ThemeMode.dark: l10n.themeDark,
    };

    return AlertDialog(
      title: Text(l10n.appearance),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.theme,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final entry in modes.entries)
                ListTile(
                  title: Text(entry.value),
                  leading: Icon(_themeIcon(entry.key)),
                  trailing: entry.key == current
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () async {
                    await ThemeService.instance.setThemeMode(entry.key);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              const Divider(height: 28),
              Text(
                l10n.background,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: Text(l10n.backgroundDefault),
                trailing: background.type == BackgroundType.defaultTheme
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: _busy ? null : _resetBackground,
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(l10n.backgroundChooseImage),
                trailing: background.type == BackgroundType.image
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: _busy ? null : _chooseImage,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(l10n.backgroundChooseColor),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final color in _backgroundColors)
                      _ColorSwatchButton(
                        color: color,
                        selected: background.type == BackgroundType.color &&
                            background.colorValue == color.toARGB32(),
                        onTap: _busy ? null : () => _setColor(color),
                      ),
                  ],
                ),
              ),
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
      ),
      actions: [
        TextButton.icon(
          onPressed: _busy ? null : _resetBackground,
          icon: const Icon(Icons.restart_alt),
          label: Text(l10n.reset),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  IconData _themeIcon(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => Icons.brightness_auto_outlined,
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.dark => Icons.dark_mode_outlined,
    };
  }

  Future<void> _setColor(Color color) async {
    await _run(() => BackgroundService.instance.setColor(color));
  }

  Future<void> _chooseImage() async {
    await _run(() => BackgroundService.instance.chooseImage());
  }

  Future<void> _resetBackground() async {
    await _run(BackgroundService.instance.reset);
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) {
        setState(() {});
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
}

class _ColorSwatchButton extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const _ColorSwatchButton({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.backgroundChooseColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 32,
                child: selected
                    ? Icon(
                        Icons.check,
                        color: ThemeData.estimateBrightnessForColor(color) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageDialog extends StatelessWidget {
  const _LanguageDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = LocaleService.instance.languageCode;
    final languages = <String?, String>{
      null: l10n.systemDefault,
      'uk': l10n.languageUkrainian,
      'ru': l10n.languageRussian,
      'en': l10n.languageEnglish,
      'pl': l10n.languagePolish,
      'es': l10n.languageSpanish,
      'cs': l10n.languageCzech,
      'de': l10n.languageGerman,
    };

    return AlertDialog(
      title: Text(l10n.language),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in languages.entries)
              ListTile(
                title: Text(entry.value),
                trailing: entry.key == current
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () async {
                  await LocaleService.instance.setLanguageCode(entry.key);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

class _BackupDialog extends StatefulWidget {
  const _BackupDialog();

  @override
  State<_BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<_BackupDialog> {
  final _passphraseCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _passphraseCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final passwordsDoNotMatch = context.l10n.backupPasswordsDoNotMatch;
    final exportCancelled = context.l10n.backupExportCancelled;
    final backupSaved = context.l10n.backupSaved;
    if (_passphraseCtrl.text != _confirmCtrl.text) {
      setState(() {
        _error = passwordsDoNotMatch;
        _message = null;
      });
      return;
    }
    await _run(() async {
      final path = await ChatService.instance
          .exportEncryptedBackup(_passphraseCtrl.text);
      return path == null ? exportCancelled : backupSaved;
    });
  }

  Future<void> _import() async {
    final backupImported = context.l10n.backupImported;
    await _run(() async {
      await ChatService.instance.importEncryptedBackup(_passphraseCtrl.text);
      return backupImported;
    });
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final message = await action();
      if (mounted) {
        setState(() {
          _message = message;
        });
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
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.backup),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.backupWarning),
              const SizedBox(height: 16),
              TextField(
                controller: _passphraseCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.backupPassword,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.confirmBackupPassword,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _import,
          icon: const Icon(Icons.upload_file),
          label: Text(l10n.import),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : _export,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: Text(l10n.export),
        ),
      ],
    );
  }
}

class _BlockedUsersDialog extends StatefulWidget {
  const _BlockedUsersDialog();

  @override
  State<_BlockedUsersDialog> createState() => _BlockedUsersDialogState();
}

class _BlockedUsersDialogState extends State<_BlockedUsersDialog> {
  final _chat = ChatService.instance;

  @override
  void initState() {
    super.initState();
    _chat.addListener(_refresh);
  }

  @override
  void dispose() {
    _chat.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _unblock(Contact contact) async {
    await _chat.unblockUser(contact.peerUserId);
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _chat.blockedContacts;
    return AlertDialog(
      title: Text(context.l10n.blockedUsers),
      content: SizedBox(
        width: 460,
        child: blocked.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(context.l10n.noBlockedUsers),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: blocked.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final contact = blocked[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        contact.username.isEmpty
                            ? '?'
                            : contact.username[0].toUpperCase(),
                      ),
                    ),
                    title: Text(contact.username),
                    subtitle: Text(context.l10n.contact),
                    trailing: OutlinedButton.icon(
                      onPressed: () => _unblock(contact),
                      icon: const Icon(Icons.lock_open),
                      label: Text(context.l10n.unblock),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.close),
        ),
      ],
    );
  }
}

class _MobileDevicesScreen extends StatefulWidget {
  const _MobileDevicesScreen();

  @override
  State<_MobileDevicesScreen> createState() => _MobileDevicesScreenState();
}

class _DesktopDevicesPane extends StatefulWidget {
  const _DesktopDevicesPane();

  @override
  State<_DesktopDevicesPane> createState() => _DesktopDevicesPaneState();
}

class _DesktopDevicesPaneState extends State<_DesktopDevicesPane> {
  final _chat = ChatService.instance;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _chat.addListener(_refresh);
  }

  @override
  void dispose() {
    _chat.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _requestSessions() async {
    setState(() => _refreshing = true);
    await _chat.requestSessions();
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.logoutConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.logout),
            label: Text(context.l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _chat.logoutCurrentSession();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final sessions = _chat.sessions;
    final hasCurrentSession = sessions.any((session) => session.current);
    final visibleSessions = hasCurrentSession
        ? sessions
        : [
            SessionInfo(
              id: '__current_device__',
              deviceId: '',
              deviceName: StorageService.instance.deviceName,
              platform: StorageService.instance.platformName,
              current: true,
              lastActiveAt: DateTime.now(),
            ),
            ...sessions,
          ];
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(locale).add_Hm();

    return Material(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.devices,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _refreshing ? null : _requestSessions,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(l10n.refresh),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.logoutAccount),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: visibleSessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final session = visibleSessions[index];
                final lastActive = session.lastActiveAt == null
                    ? l10n.unknownActivity
                    : l10n.lastActive(
                        dateFormat.format(session.lastActiveAt!.toLocal()),
                      );
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(
                      session.current
                          ? Icons.phone_android
                          : Icons.devices_other,
                    ),
                    title: Text(
                      session.current
                          ? l10n.currentDeviceBadge
                          : session.deviceName,
                    ),
                    subtitle: Text('${session.platform}\n$lastActive'),
                    isThreeLine: true,
                    trailing: session.current
                        ? Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(session.deviceName),
                          )
                        : IconButton(
                            tooltip: l10n.revoke,
                            onPressed: () => _chat.revokeSession(session.id),
                            icon: const Icon(Icons.logout),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileDevicesScreenState extends State<_MobileDevicesScreen> {
  final _chat = ChatService.instance;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _chat.addListener(_refresh);
  }

  @override
  void dispose() {
    _chat.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _revoke(SessionInfo session) async {
    await _chat.revokeSession(session.id);
  }

  Future<void> _requestSessions() async {
    setState(() => _refreshing = true);
    await _chat.requestSessions();
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.logoutConfirmTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.logout),
            label: Text(context.l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _chat.logoutCurrentSession();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _chat.sessions;
    final hasCurrentSession = sessions.any((session) => session.current);
    final visibleSessions = hasCurrentSession
        ? sessions
        : [
            SessionInfo(
              id: '__current_device__',
              deviceId: '',
              deviceName: StorageService.instance.deviceName,
              platform: StorageService.instance.platformName,
              current: true,
              lastActiveAt: DateTime.now(),
            ),
            ...sessions,
          ];
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(locale).add_Hm();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devices)),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: visibleSessions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            l10n.noSessionData,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: visibleSessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final session = visibleSessions[index];
                          final lastActive = session.lastActiveAt == null
                              ? l10n.unknownActivity
                              : l10n.lastActive(
                                  dateFormat
                                      .format(session.lastActiveAt!.toLocal()),
                                );
                          return Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: Icon(
                                session.current
                                    ? Icons.phone_android
                                    : Icons.devices_other,
                              ),
                              title: Text(
                                session.current
                                    ? l10n.currentDeviceBadge
                                    : session.deviceName,
                              ),
                              subtitle:
                                  Text('${session.platform}\n$lastActive'),
                              isThreeLine: true,
                              trailing: session.current
                                  ? Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(session.deviceName),
                                    )
                                  : IconButton(
                                      tooltip: l10n.revoke,
                                      onPressed: () => _revoke(session),
                                      icon: const Icon(Icons.logout),
                                    ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _refreshing ? null : _requestSessions,
                      icon: _refreshing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(l10n.refresh),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: Text(l10n.logoutAccount),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FindUserDialog extends StatefulWidget {
  const _FindUserDialog();

  @override
  State<_FindUserDialog> createState() => _FindUserDialogState();
}

class _FindUserDialogState extends State<_FindUserDialog> {
  final _ctrl = TextEditingController();
  final _chat = ChatService.instance;
  bool _searched = false;
  bool _requesting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _chat.addListener(_refresh);
  }

  @override
  void dispose() {
    _chat.removeListener(_refresh);
    _ctrl.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _search() async {
    final username = _ctrl.text.trim();
    if (username.isEmpty) {
      setState(() {
        _error = context.l10n.enterUsername;
      });
      return;
    }
    setState(() {
      _searched = true;
      _error = null;
    });
    try {
      await _chat.searchUsername(username);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _searchErrorText(context, error);
      });
    }
  }

  String _searchErrorText(BuildContext context, Object error) {
    final text = error.toString();
    if (text.contains('No server connection')) {
      final code = Localizations.localeOf(context).languageCode;
      return code == 'ru' || code == 'uk'
          ? 'Нет подключения к серверу'
          : 'No server connection';
    }
    return context.localizedError(error);
  }

  Future<void> _request(UserContact user) async {
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      await _chat.sendContactRequest(user.userId);
      if (mounted) {
        Navigator.of(context).pop();
        showHestiaSnackBar(
          context,
          context.l10n.requestSentTo(user.nickname),
          tone: HestiaStatusTone.success,
        );
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
          _requesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _chat.lastSearchResult;
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.addContact),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.username,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_searched && result == null && _error == null) ...[
              const SizedBox(height: 12),
              Text(
                _chat.isConnected
                    ? l10n.userNotFound
                    : _searchErrorText(
                        context,
                        Exception('No server connection.'),
                      ),
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(result.nickname.isEmpty
                      ? '?'
                      : result.nickname[0].toUpperCase()),
                ),
                title: Text(result.nickname),
                subtitle: Text(l10n.sendContactRequest),
                trailing: FilledButton(
                  onPressed: _requesting ? null : () => _request(result),
                  child: _requesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.request),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _requesting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
        FilledButton.icon(
          onPressed: _requesting ? null : _search,
          icon: const Icon(Icons.search),
          label: Text(l10n.search),
        ),
      ],
    );
  }
}

class _ChatsTab extends StatelessWidget {
  final void Function(String peerUserId, String username) onOpenChat;
  final VoidCallback? onAddContact;
  final String searchQuery;
  final String? selectedPeerUserId;

  const _ChatsTab({
    required this.onOpenChat,
    this.onAddContact,
    this.searchQuery = '',
    this.selectedPeerUserId,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final conversations = ChatService.instance.conversations.where((item) {
      if (normalizedQuery.isEmpty) {
        return true;
      }
      final last = item.lastMessage;
      return item.peerNickname.toLowerCase().contains(normalizedQuery) ||
          (last?.text.toLowerCase().contains(normalizedQuery) ?? false);
    }).toList();
    if (conversations.isEmpty) {
      if (ChatService.instance.contacts.isEmpty && onAddContact != null) {
        return _FirstActionEmptyState(onAddContact: onAddContact!);
      }
      return _EmptyState(
        icon: Icons.chat_bubble_outline,
        text: context.l10n.noChatsYet,
      );
    }
    return ListView.separated(
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final conversation = conversations[index];
        final last = conversation.lastMessage;
        final unreadCount =
            ChatService.instance.unreadCountForConversation(conversation.id);
        final settings = ChatService.instance.chatSettingsFor(conversation.id);
        final subtitle = _conversationPreview(context, last);
        return HestiaListEntrance(
          index: index,
          child: ListTile(
            selected: conversation.peerUserId == selectedPeerUserId,
            selectedTileColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
            leading: _AvatarWithStatus(
              label: conversation.peerNickname,
              online:
                  ChatService.instance.isPeerOnline(conversation.peerUserId),
            ),
            title: _ContactTitle(conversation.peerNickname),
            subtitle: Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (settings.muted)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.notifications_off_outlined, size: 18),
                  ),
                if (settings.pinned)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.push_pin_outlined, size: 18),
                  ),
                AnimatedSwitcher(
                  duration: HestiaMotion.normal,
                  child: unreadCount > 0
                      ? Padding(
                          key: ValueKey(unreadCount),
                          padding: const EdgeInsets.only(right: 8),
                          child: Badge.count(
                            count: unreadCount,
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'mute') {
                      await ChatService.instance
                          .toggleChatMute(conversation.id);
                    } else if (value == 'pin') {
                      await ChatService.instance.toggleChatPin(conversation.id);
                    } else if (value == 'archive') {
                      await ChatService.instance
                          .toggleChatArchive(conversation.id);
                    } else if (value == 'delete') {
                      await ChatService.instance
                          .deleteConversationForMe(conversation.id);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'mute',
                      child: Text(
                        settings.muted
                            ? context.l10n.unmute
                            : context.l10n.mute,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pin',
                      child: Text(
                        settings.pinned ? context.l10n.unpin : context.l10n.pin,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(context.l10n.archive),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.l10n.deleteForMe),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () {
              ChatService.instance.markConversationRead(conversation.id);
              onOpenChat(conversation.peerUserId, conversation.peerNickname);
            },
          ),
        );
      },
    );
  }

  String _conversationPreview(BuildContext context, ChatMessage? last) {
    if (last == null) {
      return '';
    }
    if (last.id.startsWith('missed_call_')) {
      return context.l10n.callEventMissedVoice;
    }
    if (last.type == ChatMessageType.call || last.callId != null) {
      switch (last.callStatus) {
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
          return last.callDirection == CallDirection.outgoing
              ? context.l10n.callEventOutgoingVoice
              : context.l10n.callEventIncomingVoice;
      }
    }
    if (last.attachment != null) {
      return context.l10n.attachmentNamed(last.attachment!.name);
    }
    return last.text;
  }
}

class _ContactsTab extends StatelessWidget {
  final TextEditingController searchCtrl;
  final void Function(String peerUserId, String username) onOpenChat;
  final VoidCallback? onAddContact;
  final String searchQuery;
  final String? selectedPeerUserId;

  const _ContactsTab({
    required this.searchCtrl,
    required this.onOpenChat,
    this.onAddContact,
    this.searchQuery = '',
    this.selectedPeerUserId,
  });

  @override
  Widget build(BuildContext context) {
    final chat = ChatService.instance;
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final contacts = chat.contacts.where((item) {
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return item.username.toLowerCase().contains(normalizedQuery);
    }).toList();
    final searchResult = chat.lastSearchResult;
    final visibleSearchResult =
        searchResult != null && chat.shouldShowSearchResult(searchResult)
            ? searchResult
            : null;
    Future<void> runSearch(String value) async {
      try {
        await chat.searchUsername(value);
      } catch (error) {
        if (!context.mounted) return;
        final code = Localizations.localeOf(context).languageCode;
        showHestiaSnackBar(
          context,
          error.toString().contains('No server connection')
              ? (code == 'ru' || code == 'uk'
                  ? 'Нет подключения к серверу'
                  : 'No server connection')
              : context.localizedError(error),
          tone: HestiaStatusTone.error,
        );
      }
    }

    return RefreshIndicator(
      onRefresh: chat.requestUsers,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.findUsername,
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: runSearch,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => runSearch(searchCtrl.text),
                tooltip: context.l10n.search,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          if (visibleSearchResult != null) ...[
            const SizedBox(height: 12),
            ListTile(
              leading: _AvatarWithStatus(
                label: visibleSearchResult.nickname,
                online: visibleSearchResult.online,
              ),
              title: _ContactTitle(visibleSearchResult.nickname),
              subtitle: Text(context.l10n.userFound),
              trailing: FilledButton(
                onPressed: () =>
                    chat.sendContactRequest(visibleSearchResult.userId),
                child: Text(context.l10n.request),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (contacts.isEmpty)
            onAddContact == null
                ? _EmptyState(
                    icon: Icons.people_outline,
                    text: context.l10n.noContactsYet,
                  )
                : _FirstActionEmptyState(onAddContact: onAddContact!)
          else
            for (final (index, contact) in contacts.indexed)
              HestiaListEntrance(
                index: index,
                child: ListTile(
                  selected: contact.peerUserId == selectedPeerUserId,
                  selectedTileColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.10),
                  leading: _AvatarWithStatus(
                    label: contact.username,
                    online: chat.isPeerOnline(contact.peerUserId),
                  ),
                  title: _ContactTitle(contact.username),
                  subtitle: Text(
                    chat.isPeerOnline(contact.peerUserId)
                        ? context.l10n.contactOnline
                        : context.l10n.contact,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'block') chat.blockUser(contact.peerUserId);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'block',
                        child: Text(context.l10n.block),
                      ),
                    ],
                  ),
                  onTap: () => onOpenChat(contact.peerUserId, contact.username),
                ),
              ),
        ],
      ),
    );
  }
}

class _AvatarWithStatus extends StatelessWidget {
  final String label;
  final bool online;

  const _AvatarWithStatus({
    required this.label,
    required this.online,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          child: Text(label.isEmpty ? '?' : label[0].toUpperCase()),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: AnimatedScale(
            scale: online ? 1 : 0,
            duration: HestiaMotion.normal,
            curve: HestiaMotion.curve,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surface,
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.tertiary,
                  ),
                  child: const SizedBox(width: 10, height: 10),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactTitle extends StatelessWidget {
  final String text;

  const _ContactTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style?.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  final String searchQuery;

  const _RequestsTab({this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    final chat = ChatService.instance;
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final requests = chat.pendingRequests.where((item) {
      if (normalizedQuery.isEmpty) {
        return true;
      }
      return item.fromUsername.toLowerCase().contains(normalizedQuery);
    }).toList();
    if (requests.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: MicroHint(
              hint: MicroOnboardingHint.requests,
              icon: Icons.inbox_outlined,
              text: context.l10n.hintRequests,
              child: const SizedBox.shrink(),
            ),
          ),
          _EmptyState(
            icon: Icons.inbox_outlined,
            text: context.l10n.noPendingRequests,
          ),
        ],
      );
    }
    return ListView.separated(
      itemCount: requests.length + 1,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: MicroHint(
              hint: MicroOnboardingHint.requests,
              icon: Icons.inbox_outlined,
              text: context.l10n.hintRequests,
              child: const SizedBox.shrink(),
            ),
          );
        }
        final request = requests[index - 1];
        return HestiaListEntrance(
          index: index,
          child: ListTile(
            leading: CircleAvatar(
              child: Text(request.fromUsername.isEmpty
                  ? '?'
                  : request.fromUsername[0].toUpperCase()),
            ),
            title: _ContactTitle(request.fromUsername),
            subtitle: Text(context.l10n.wantsToAddYou),
            trailing: Wrap(
              spacing: 8,
              children: [
                _MotionIconButton(
                  tooltip: context.l10n.decline,
                  onPressed: () => chat.declineContactRequest(request.id),
                  icon: Icons.close,
                ),
                _MotionIconButton(
                  tooltip: context.l10n.accept,
                  onPressed: () async {
                    HestiaMotion.lightImpact();
                    await chat.acceptContactRequest(request.id);
                    final firstContact = await RetentionService.instance
                        .markSeen(RetentionMoment.firstContactAdded);
                    chat.sendRetentionEvent(RetentionMoment.firstContactAdded);
                    if (!context.mounted || !firstContact) {
                      return;
                    }
                    showHestiaSnackBar(
                      context,
                      context.l10n.retentionContactAdded,
                      tone: HestiaStatusTone.info,
                    );
                  },
                  icon: Icons.check,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          const SizedBox(height: 160),
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
}

class _RetentionBanner extends StatelessWidget {
  final String? text;
  final bool compact;
  final VoidCallback onDismiss;

  const _RetentionBanner({
    required this.text,
    required this.onDismiss,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final message = text;
    final scheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: HestiaMotion.normal,
      switchInCurve: HestiaMotion.curve,
      switchOutCurve: Curves.easeIn,
      child: message == null
          ? const SizedBox.shrink()
          : Padding(
              key: ValueKey(message),
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 16,
                compact ? 8 : 12,
                compact ? 12 : 16,
                compact ? 4 : 8,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite_border,
                        size: 18,
                        color: scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSecondaryContainer),
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.close,
                        onPressed: onDismiss,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _FirstActionEmptyState extends StatelessWidget {
  final VoidCallback onAddContact;

  const _FirstActionEmptyState({required this.onAddContact});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 88),
        Icon(
          Icons.people_outline,
          size: 64,
          color: scheme.primary,
        ),
        const SizedBox(height: 18),
        Text(
          context.l10n.firstRunNoContactsTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.firstRunNoContactsBody,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 24),
        Center(
          child: MicroHint(
            hint: MicroOnboardingHint.addContact,
            icon: Icons.person_search,
            text: context.l10n.hintAddContact,
            padding: const EdgeInsets.only(bottom: 10),
            child: _MotionExtendedFab(
              onPressed: onAddContact,
              icon: Icons.person_add_alt_1,
              label: Text(context.l10n.addContact),
            ),
          ),
        ),
      ],
    );
  }
}
