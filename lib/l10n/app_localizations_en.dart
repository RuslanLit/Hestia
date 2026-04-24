// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Hestia';

  @override
  String get splashTagline => 'Private space for people you trust';

  @override
  String get systemDefault => 'System default';

  @override
  String get language => 'Language';

  @override
  String get settings => 'Settings';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get appearance => 'Appearance';

  @override
  String get background => 'Background';

  @override
  String get backgroundDefault => 'Default';

  @override
  String get backgroundChooseColor => 'Choose color';

  @override
  String get backgroundChooseImage => 'Choose image';

  @override
  String get reset => 'Reset';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get close => 'Close';

  @override
  String get continueAction => 'Continue';

  @override
  String get search => 'Search';

  @override
  String get refresh => 'Refresh';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get request => 'Request';

  @override
  String get error => 'Error';

  @override
  String get server => 'Server';

  @override
  String get serverUrl => 'Server URL';

  @override
  String serverConnected(String host) {
    return 'Connected to $host';
  }

  @override
  String get serverDisconnected => 'Disconnected';

  @override
  String get login => 'Login';

  @override
  String get registration => 'Registration';

  @override
  String get register => 'Register';

  @override
  String get nicknameRequired => 'Nickname is required';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get nicknameTooShort => 'Nickname must be at least 2 characters';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get chooseNickname => 'Choose a new nickname';

  @override
  String get yourNickname => 'Your nickname';

  @override
  String get choosePassword => 'Choose a password';

  @override
  String get password => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get chats => 'Chats';

  @override
  String get contacts => 'Contacts';

  @override
  String get requests => 'Requests';

  @override
  String get addContact => 'Add contact';

  @override
  String get privacy => 'Privacy';

  @override
  String get backup => 'Backup';

  @override
  String get devices => 'Devices';

  @override
  String get allowUsernameSearch => 'Allow username search';

  @override
  String get messagesFrom => 'Messages from';

  @override
  String get callsFrom => 'Calls from';

  @override
  String get everyone => 'Everyone';

  @override
  String get noChatsYet => 'No chats yet.';

  @override
  String get noContactsYet => 'Add a contact to start a conversation';

  @override
  String get firstRunNoContactsTitle => 'Add a contact to start a conversation';

  @override
  String get firstRunNoContactsBody =>
      'Find someone by username and send a request.';

  @override
  String get hintAddContact => 'Find someone by username';

  @override
  String get hintRequests => 'Contact requests appear here';

  @override
  String get hintMessageInput => 'Write a message';

  @override
  String get noPendingRequests => 'No pending requests.';

  @override
  String get findUsername => 'Find username';

  @override
  String get username => 'Username';

  @override
  String get enterUsername => 'Enter username';

  @override
  String get userFound => 'User found';

  @override
  String get userNotFound => 'User not found or discovery is disabled.';

  @override
  String get sendContactRequest => 'Send contact request';

  @override
  String requestSentTo(String name) {
    return 'Request sent to $name';
  }

  @override
  String get retentionContactAdded => 'Contact added. You can start a chat.';

  @override
  String get retentionFirstMessageSent =>
      'Message sent. Hestia will keep the conversation quiet and private.';

  @override
  String get retentionStartChatHint =>
      'Open a chat and send your first message when you are ready.';

  @override
  String get retentionDayReminder =>
      'You have not talked for a while. Your private chats are here when you need them.';

  @override
  String get retentionThreeDayReminder =>
      'A quiet check-in: your trusted conversations are waiting here.';

  @override
  String get retentionNewMessages => 'You have new messages.';

  @override
  String get contact => 'Contact';

  @override
  String get contactOnline => 'Online now';

  @override
  String get block => 'Block';

  @override
  String get unblockUser => 'Unblock user';

  @override
  String get blockUser => 'Block user';

  @override
  String get wantsToAddYou => 'Wants to add you as a contact';

  @override
  String get attachment => 'Attachment';

  @override
  String attachmentNamed(String name) {
    return 'Attachment: $name';
  }

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get archive => 'Archive';

  @override
  String get deleteForMe => 'Delete for me';

  @override
  String get backupWarning =>
      'Backups are encrypted locally. Keep the password safe: without it the backup cannot be restored.';

  @override
  String get backupPassword => 'Backup password';

  @override
  String get confirmBackupPassword => 'Confirm password for export';

  @override
  String get backupPasswordsDoNotMatch => 'Backup passwords do not match.';

  @override
  String get backupExportCancelled => 'Backup export cancelled.';

  @override
  String get backupSaved => 'Backup saved.';

  @override
  String get backupImported => 'Backup imported. Local data was restored.';

  @override
  String get import => 'Import';

  @override
  String get export => 'Export';

  @override
  String get noSessionData => 'No session data yet.';

  @override
  String get unknownActivity => 'Unknown activity';

  @override
  String lastActive(String time) {
    return 'Last active $time';
  }

  @override
  String currentDevice(String name) {
    return '$name (current)';
  }

  @override
  String get revoke => 'Revoke';

  @override
  String get logoutCurrent => 'Logout current';

  @override
  String get message => 'Message';

  @override
  String get send => 'Send';

  @override
  String get sendFile => 'Send file';

  @override
  String messageSendFailed(String error) {
    return 'Message send failed: $error';
  }

  @override
  String fileSendFailed(String error) {
    return 'File send failed: $error';
  }

  @override
  String get noMessagesYet => 'Write the first message';

  @override
  String get reply => 'Reply';

  @override
  String get forward => 'Forward';

  @override
  String get forwardTo => 'Forward to';

  @override
  String get forwarded => 'Forwarded';

  @override
  String forwardedFrom(String name) {
    return 'Forwarded from $name';
  }

  @override
  String forwardedTo(String name) {
    return 'Forwarded to $name';
  }

  @override
  String forwardFailed(String error) {
    return 'Forward failed: $error';
  }

  @override
  String get noForwardTargets => 'No available contacts to forward to';

  @override
  String get cancelReply => 'Cancel reply';

  @override
  String get originalMessage => 'Original message';

  @override
  String get originalMessageUnavailable => 'Original message unavailable';

  @override
  String savedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String saveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get open => 'Open';

  @override
  String get userUnavailable => 'User is unavailable.';

  @override
  String get callRejected => 'Call was rejected.';

  @override
  String get sessionRevoked => 'This session was revoked.';

  @override
  String couldNotConnectTo(String host) {
    return 'Could not connect to $host';
  }

  @override
  String get unknownServerError => 'Unknown server error';

  @override
  String get authenticationRequired => 'Authentication required.';

  @override
  String get localFileNotFound => 'Local file not found.';

  @override
  String get webAttachmentAvailable =>
      'The file is available in this browser session.';

  @override
  String get webAttachmentUnavailable =>
      'The file is unavailable after restarting the browser.';

  @override
  String get attachmentTypeNotAllowed => 'This attachment type is not allowed.';

  @override
  String get attachmentValidationFailed => 'Attachment validation failed.';

  @override
  String get attachmentTooLarge => 'Attachment is too large.';

  @override
  String get attachmentLimits =>
      'Allowed files: documents, images, audio, and video. Limits: images 25 MB, audio/documents 50 MB, video 200 MB.';

  @override
  String get selectedFileReadFailed => 'Could not read the selected file.';

  @override
  String get forwardLocalFileUnavailable =>
      'Forward failed: the local file is unavailable.';

  @override
  String get attachmentUploadFailed => 'Attachment upload failed.';

  @override
  String peerKeyChangedCall(String name) {
    return '$name\'s encryption key changed. Verify the fingerprint before calling.';
  }

  @override
  String peerNoEncryptionKey(String name) {
    return '$name has no encryption key yet.';
  }

  @override
  String get encryptionKey => 'Encryption key';

  @override
  String get verify => 'Verify';

  @override
  String get trustKey => 'Trust key';

  @override
  String get trustNewKey => 'Trust new key';

  @override
  String get removeTrust => 'Remove trust';

  @override
  String get verifiedEncryptionKey => 'Verified encryption key';

  @override
  String get encryptionKeyChanged => 'Encryption key changed';

  @override
  String get noEncryptionKey => 'No encryption key';

  @override
  String get verifyEncryptionKey => 'Verify encryption key';

  @override
  String get sendingBlockedKeyChanged =>
      'Sending is blocked until you verify this contact again.';

  @override
  String get keyTrusted => 'This key is trusted on this device.';

  @override
  String get keyChangedWarning =>
      'Warning: this key changed. Compare the fingerprint before trusting it again.';

  @override
  String get keyMissing => 'This user has not published an encryption key yet.';

  @override
  String get keyUntrusted =>
      'Compare this fingerprint with the other user, then trust it.';

  @override
  String get noFingerprint => 'No fingerprint available';

  @override
  String get audioCall => 'Audio call';

  @override
  String get videoCall => 'Video call';

  @override
  String callFailed(String error) {
    return 'Call failed: $error';
  }

  @override
  String get anotherCallActive => 'Another call is already active';

  @override
  String get calling => 'Calling...';

  @override
  String get connected => 'Connected';

  @override
  String get muteCall => 'Mute';

  @override
  String get unmuteCall => 'Unmute';

  @override
  String get endCall => 'End';

  @override
  String get incomingCall => 'Incoming call';

  @override
  String get voiceCall => 'Voice call';

  @override
  String get pushSyncChannelDescription =>
      'Sync notifications for Hestia messages and requests.';

  @override
  String get pushCallChannelDescription => 'Incoming call alerts for Hestia.';

  @override
  String get newContactRequestNotification => 'New contact request';

  @override
  String get newMessageNotification => 'New message';

  @override
  String get incomingVideoCallNotification => 'Incoming video call';

  @override
  String get incomingVoiceCallNotification => 'Incoming voice call';

  @override
  String get unknownCaller => 'Unknown';

  @override
  String get rejectCall => 'Reject';

  @override
  String get updateAvailable => 'Update available';

  @override
  String versionAvailable(String version) {
    return 'Version $version is available.';
  }

  @override
  String get startingDownload => 'Starting download...';

  @override
  String downloadingProgress(String percent) {
    return 'Downloading... $percent%';
  }

  @override
  String get downloadFailedRetry => 'Download failed. Please try again.';

  @override
  String get later => 'Later';

  @override
  String get downloading => 'Downloading...';

  @override
  String get updateViaAppStore => 'Update via App Store';

  @override
  String get downloadAndInstall => 'Download and install';

  @override
  String get openDownloadPage => 'Open download page';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageUkrainian => 'Українська';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languagePolish => 'Polski';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageCzech => 'Čeština';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Hestia';

  @override
  String get onboardingWelcomeBody =>
      'A quiet messenger for private chats, calls, and files.';

  @override
  String get onboardingPrivacyTitle => 'Private by design';

  @override
  String get onboardingPrivacyBody =>
      'Messages use encryption keys. Your chats and files stay stored locally.';

  @override
  String get onboardingHowItWorksTitle => 'Simple flow';

  @override
  String get onboardingHowItWorksBody =>
      'Choose a server, add contacts, and approve requests before chatting.';

  @override
  String get onboardingCallsFilesTitle => 'Calls and files';

  @override
  String get onboardingCallsFilesBody =>
      'Start voice calls and share files from the same protected space.';

  @override
  String get onboardingServerTitle => 'Choose your server';

  @override
  String get onboardingServerBody =>
      'Use the default server or connect Hestia to your own server.';

  @override
  String get onboardingDefaultServer => 'Default server';

  @override
  String get onboardingCustomServer => 'Custom server';

  @override
  String get onboardingCustomServerBody =>
      'For self-hosted or private deployments.';

  @override
  String get onboardingGetStartedTitle => 'Ready when you are';

  @override
  String get onboardingGetStartedBody =>
      'Create a new account or login with an existing one.';
}
