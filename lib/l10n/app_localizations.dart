import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('cs'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('pl'),
    Locale('ru'),
    Locale('uk')
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Hestia'**
  String get appName;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Private space for people you trust'**
  String get splashTagline;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get background;

  /// No description provided for @backgroundDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get backgroundDefault;

  /// No description provided for @backgroundChooseColor.
  ///
  /// In en, this message translates to:
  /// **'Choose color'**
  String get backgroundChooseColor;

  /// No description provided for @backgroundChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get backgroundChooseImage;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @request.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get request;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @serverConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to {host}'**
  String serverConnected(String host);

  /// No description provided for @serverDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get serverDisconnected;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @registration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get registration;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @nicknameRequired.
  ///
  /// In en, this message translates to:
  /// **'Nickname is required'**
  String get nicknameRequired;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @nicknameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Nickname must be at least 2 characters'**
  String get nicknameTooShort;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @chooseNickname.
  ///
  /// In en, this message translates to:
  /// **'Choose a new nickname'**
  String get chooseNickname;

  /// No description provided for @yourNickname.
  ///
  /// In en, this message translates to:
  /// **'Your nickname'**
  String get yourNickname;

  /// No description provided for @choosePassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a password'**
  String get choosePassword;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @contacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get contacts;

  /// No description provided for @requests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requests;

  /// No description provided for @addContact.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get addContact;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @backup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @devices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get devices;

  /// No description provided for @allowUsernameSearch.
  ///
  /// In en, this message translates to:
  /// **'Allow username search'**
  String get allowUsernameSearch;

  /// No description provided for @messagesFrom.
  ///
  /// In en, this message translates to:
  /// **'Messages from'**
  String get messagesFrom;

  /// No description provided for @callsFrom.
  ///
  /// In en, this message translates to:
  /// **'Calls from'**
  String get callsFrom;

  /// No description provided for @everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everyone;

  /// No description provided for @noChatsYet.
  ///
  /// In en, this message translates to:
  /// **'No chats yet.'**
  String get noChatsYet;

  /// No description provided for @noContactsYet.
  ///
  /// In en, this message translates to:
  /// **'Add a contact to start a conversation'**
  String get noContactsYet;

  /// No description provided for @firstRunNoContactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a contact to start a conversation'**
  String get firstRunNoContactsTitle;

  /// No description provided for @firstRunNoContactsBody.
  ///
  /// In en, this message translates to:
  /// **'Find someone by username and send a request.'**
  String get firstRunNoContactsBody;

  /// No description provided for @hintAddContact.
  ///
  /// In en, this message translates to:
  /// **'Find someone by username'**
  String get hintAddContact;

  /// No description provided for @hintRequests.
  ///
  /// In en, this message translates to:
  /// **'Contact requests appear here'**
  String get hintRequests;

  /// No description provided for @hintMessageInput.
  ///
  /// In en, this message translates to:
  /// **'Write a message'**
  String get hintMessageInput;

  /// No description provided for @noPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending requests.'**
  String get noPendingRequests;

  /// No description provided for @findUsername.
  ///
  /// In en, this message translates to:
  /// **'Find username'**
  String get findUsername;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @enterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter username'**
  String get enterUsername;

  /// No description provided for @userFound.
  ///
  /// In en, this message translates to:
  /// **'User found'**
  String get userFound;

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found or discovery is disabled.'**
  String get userNotFound;

  /// No description provided for @sendContactRequest.
  ///
  /// In en, this message translates to:
  /// **'Send contact request'**
  String get sendContactRequest;

  /// No description provided for @requestSentTo.
  ///
  /// In en, this message translates to:
  /// **'Request sent to {name}'**
  String requestSentTo(String name);

  /// No description provided for @retentionContactAdded.
  ///
  /// In en, this message translates to:
  /// **'Contact added. You can start a chat.'**
  String get retentionContactAdded;

  /// No description provided for @retentionFirstMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent. Hestia will keep the conversation quiet and private.'**
  String get retentionFirstMessageSent;

  /// No description provided for @retentionStartChatHint.
  ///
  /// In en, this message translates to:
  /// **'Open a chat and send your first message when you are ready.'**
  String get retentionStartChatHint;

  /// No description provided for @retentionDayReminder.
  ///
  /// In en, this message translates to:
  /// **'You have not talked for a while. Your private chats are here when you need them.'**
  String get retentionDayReminder;

  /// No description provided for @retentionThreeDayReminder.
  ///
  /// In en, this message translates to:
  /// **'A quiet check-in: your trusted conversations are waiting here.'**
  String get retentionThreeDayReminder;

  /// No description provided for @retentionNewMessages.
  ///
  /// In en, this message translates to:
  /// **'You have new messages.'**
  String get retentionNewMessages;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @contactOnline.
  ///
  /// In en, this message translates to:
  /// **'Online now'**
  String get contactOnline;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @unblockUser.
  ///
  /// In en, this message translates to:
  /// **'Unblock user'**
  String get unblockUser;

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get blockUser;

  /// No description provided for @wantsToAddYou.
  ///
  /// In en, this message translates to:
  /// **'Wants to add you as a contact'**
  String get wantsToAddYou;

  /// No description provided for @attachment.
  ///
  /// In en, this message translates to:
  /// **'Attachment'**
  String get attachment;

  /// No description provided for @attachmentNamed.
  ///
  /// In en, this message translates to:
  /// **'Attachment: {name}'**
  String attachmentNamed(String name);

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @deleteForMe.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get deleteForMe;

  /// No description provided for @backupWarning.
  ///
  /// In en, this message translates to:
  /// **'Backups are encrypted locally. Keep the password safe: without it the backup cannot be restored.'**
  String get backupWarning;

  /// No description provided for @backupPassword.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get backupPassword;

  /// No description provided for @confirmBackupPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password for export'**
  String get confirmBackupPassword;

  /// No description provided for @backupPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Backup passwords do not match.'**
  String get backupPasswordsDoNotMatch;

  /// No description provided for @backupExportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Backup export cancelled.'**
  String get backupExportCancelled;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved.'**
  String get backupSaved;

  /// No description provided for @backupImported.
  ///
  /// In en, this message translates to:
  /// **'Backup imported. Local data was restored.'**
  String get backupImported;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @noSessionData.
  ///
  /// In en, this message translates to:
  /// **'No active devices found'**
  String get noSessionData;

  /// No description provided for @unknownActivity.
  ///
  /// In en, this message translates to:
  /// **'Unknown activity'**
  String get unknownActivity;

  /// No description provided for @lastActive.
  ///
  /// In en, this message translates to:
  /// **'Last active {time}'**
  String lastActive(String time);

  /// No description provided for @currentDevice.
  ///
  /// In en, this message translates to:
  /// **'{name} (current)'**
  String currentDevice(String name);

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @logoutCurrent.
  ///
  /// In en, this message translates to:
  /// **'Log out from this device'**
  String get logoutCurrent;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @sendFile.
  ///
  /// In en, this message translates to:
  /// **'Send file'**
  String get sendFile;

  /// No description provided for @messageSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Message send failed: {error}'**
  String messageSendFailed(String error);

  /// No description provided for @fileSendFailed.
  ///
  /// In en, this message translates to:
  /// **'File send failed: {error}'**
  String fileSendFailed(String error);

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'Write the first message'**
  String get noMessagesYet;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// No description provided for @forwardTo.
  ///
  /// In en, this message translates to:
  /// **'Forward to'**
  String get forwardTo;

  /// No description provided for @forwarded.
  ///
  /// In en, this message translates to:
  /// **'Forwarded'**
  String get forwarded;

  /// No description provided for @forwardedFrom.
  ///
  /// In en, this message translates to:
  /// **'Forwarded from {name}'**
  String forwardedFrom(String name);

  /// No description provided for @forwardedTo.
  ///
  /// In en, this message translates to:
  /// **'Forwarded to {name}'**
  String forwardedTo(String name);

  /// No description provided for @forwardFailed.
  ///
  /// In en, this message translates to:
  /// **'Forward failed: {error}'**
  String forwardFailed(String error);

  /// No description provided for @noForwardTargets.
  ///
  /// In en, this message translates to:
  /// **'No available contacts to forward to'**
  String get noForwardTargets;

  /// No description provided for @cancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get cancelReply;

  /// No description provided for @originalMessage.
  ///
  /// In en, this message translates to:
  /// **'Original message'**
  String get originalMessage;

  /// No description provided for @originalMessageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Original message unavailable'**
  String get originalMessageUnavailable;

  /// No description provided for @savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String savedTo(String path);

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailed(String error);

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @userUnavailable.
  ///
  /// In en, this message translates to:
  /// **'User is unavailable.'**
  String get userUnavailable;

  /// No description provided for @callRejected.
  ///
  /// In en, this message translates to:
  /// **'Call was rejected.'**
  String get callRejected;

  /// No description provided for @sessionRevoked.
  ///
  /// In en, this message translates to:
  /// **'This session was revoked.'**
  String get sessionRevoked;

  /// No description provided for @couldNotConnectTo.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to {host}'**
  String couldNotConnectTo(String host);

  /// No description provided for @unknownServerError.
  ///
  /// In en, this message translates to:
  /// **'Unknown server error'**
  String get unknownServerError;

  /// No description provided for @authenticationRequired.
  ///
  /// In en, this message translates to:
  /// **'Authentication required.'**
  String get authenticationRequired;

  /// No description provided for @localFileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Local file not found.'**
  String get localFileNotFound;

  /// No description provided for @webAttachmentAvailable.
  ///
  /// In en, this message translates to:
  /// **'The file is available in this browser session.'**
  String get webAttachmentAvailable;

  /// No description provided for @webAttachmentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The file is unavailable after restarting the browser.'**
  String get webAttachmentUnavailable;

  /// No description provided for @attachmentTypeNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This attachment type is not allowed.'**
  String get attachmentTypeNotAllowed;

  /// No description provided for @attachmentValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Attachment validation failed.'**
  String get attachmentValidationFailed;

  /// No description provided for @attachmentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Attachment is too large.'**
  String get attachmentTooLarge;

  /// No description provided for @attachmentLimits.
  ///
  /// In en, this message translates to:
  /// **'Documents, images, audio and video are allowed. Limits: documents/images 50 MB, audio 100 MB, video 250 MB. One file per message.'**
  String get attachmentLimits;

  /// No description provided for @selectedFileReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the selected file.'**
  String get selectedFileReadFailed;

  /// No description provided for @forwardLocalFileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Forward failed: the local file is unavailable.'**
  String get forwardLocalFileUnavailable;

  /// No description provided for @attachmentUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Attachment upload failed.'**
  String get attachmentUploadFailed;

  /// No description provided for @peerKeyChangedCall.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s encryption key changed. Verify the fingerprint before calling.'**
  String peerKeyChangedCall(String name);

  /// No description provided for @peerNoEncryptionKey.
  ///
  /// In en, this message translates to:
  /// **'{name} has no encryption key yet.'**
  String peerNoEncryptionKey(String name);

  /// No description provided for @encryptionKey.
  ///
  /// In en, this message translates to:
  /// **'Encryption key'**
  String get encryptionKey;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @trustKey.
  ///
  /// In en, this message translates to:
  /// **'Trust key'**
  String get trustKey;

  /// No description provided for @trustNewKey.
  ///
  /// In en, this message translates to:
  /// **'Trust new key'**
  String get trustNewKey;

  /// No description provided for @removeTrust.
  ///
  /// In en, this message translates to:
  /// **'Remove trust'**
  String get removeTrust;

  /// No description provided for @verifiedEncryptionKey.
  ///
  /// In en, this message translates to:
  /// **'Verified encryption key'**
  String get verifiedEncryptionKey;

  /// No description provided for @encryptionKeyChanged.
  ///
  /// In en, this message translates to:
  /// **'Encryption key changed'**
  String get encryptionKeyChanged;

  /// No description provided for @noEncryptionKey.
  ///
  /// In en, this message translates to:
  /// **'No encryption key'**
  String get noEncryptionKey;

  /// No description provided for @verifyEncryptionKey.
  ///
  /// In en, this message translates to:
  /// **'Verify encryption key'**
  String get verifyEncryptionKey;

  /// No description provided for @sendingBlockedKeyChanged.
  ///
  /// In en, this message translates to:
  /// **'Sending is blocked until you verify this contact again.'**
  String get sendingBlockedKeyChanged;

  /// No description provided for @keyTrusted.
  ///
  /// In en, this message translates to:
  /// **'This key is trusted on this device.'**
  String get keyTrusted;

  /// No description provided for @keyChangedWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: this key changed. Compare the fingerprint before trusting it again.'**
  String get keyChangedWarning;

  /// No description provided for @keyMissing.
  ///
  /// In en, this message translates to:
  /// **'This user has not published an encryption key yet.'**
  String get keyMissing;

  /// No description provided for @keyUntrusted.
  ///
  /// In en, this message translates to:
  /// **'Compare this fingerprint with the other user, then trust it.'**
  String get keyUntrusted;

  /// No description provided for @noFingerprint.
  ///
  /// In en, this message translates to:
  /// **'No fingerprint available'**
  String get noFingerprint;

  /// No description provided for @audioCall.
  ///
  /// In en, this message translates to:
  /// **'Audio call'**
  String get audioCall;

  /// No description provided for @videoCall.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get videoCall;

  /// No description provided for @callFailed.
  ///
  /// In en, this message translates to:
  /// **'Call failed: {error}'**
  String callFailed(String error);

  /// No description provided for @anotherCallActive.
  ///
  /// In en, this message translates to:
  /// **'Another call is already active'**
  String get anotherCallActive;

  /// No description provided for @calling.
  ///
  /// In en, this message translates to:
  /// **'Calling...'**
  String get calling;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @muteCall.
  ///
  /// In en, this message translates to:
  /// **'Microphone off'**
  String get muteCall;

  /// No description provided for @unmuteCall.
  ///
  /// In en, this message translates to:
  /// **'Microphone on'**
  String get unmuteCall;

  /// No description provided for @endCall.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get endCall;

  /// No description provided for @incomingCall.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get incomingCall;

  /// No description provided for @voiceCall.
  ///
  /// In en, this message translates to:
  /// **'Voice call'**
  String get voiceCall;

  /// No description provided for @pushSyncChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Sync notifications for Hestia messages and requests.'**
  String get pushSyncChannelDescription;

  /// No description provided for @pushCallChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Incoming call alerts for Hestia.'**
  String get pushCallChannelDescription;

  /// No description provided for @newContactRequestNotification.
  ///
  /// In en, this message translates to:
  /// **'New contact request'**
  String get newContactRequestNotification;

  /// No description provided for @newMessageNotification.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get newMessageNotification;

  /// No description provided for @incomingVideoCallNotification.
  ///
  /// In en, this message translates to:
  /// **'Incoming video call'**
  String get incomingVideoCallNotification;

  /// No description provided for @incomingVoiceCallNotification.
  ///
  /// In en, this message translates to:
  /// **'Incoming voice call'**
  String get incomingVoiceCallNotification;

  /// No description provided for @unknownCaller.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownCaller;

  /// No description provided for @rejectCall.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectCall;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailable;

  /// No description provided for @versionAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available.'**
  String versionAvailable(String version);

  /// No description provided for @startingDownload.
  ///
  /// In en, this message translates to:
  /// **'Starting download...'**
  String get startingDownload;

  /// No description provided for @downloadingProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloading... {percent}%'**
  String downloadingProgress(String percent);

  /// No description provided for @downloadFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Please try again.'**
  String get downloadFailedRetry;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get downloading;

  /// No description provided for @updateViaAppStore.
  ///
  /// In en, this message translates to:
  /// **'Update via App Store'**
  String get updateViaAppStore;

  /// No description provided for @downloadAndInstall.
  ///
  /// In en, this message translates to:
  /// **'Download and install'**
  String get downloadAndInstall;

  /// No description provided for @openDownloadPage.
  ///
  /// In en, this message translates to:
  /// **'Open download page'**
  String get openDownloadPage;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @latestVersionInstalled.
  ///
  /// In en, this message translates to:
  /// **'You already have the latest version.'**
  String get latestVersionInstalled;

  /// No description provided for @updatesAndroidOnly.
  ///
  /// In en, this message translates to:
  /// **'Updates are available on Android only.'**
  String get updatesAndroidOnly;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates. Please try again.'**
  String get updateCheckFailed;

  /// No description provided for @currentVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Current version: {version}'**
  String currentVersionLabel(String version);

  /// No description provided for @latestVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Latest version: {version}'**
  String latestVersionLabel(String version);

  /// No description provided for @releaseNotes.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get releaseNotes;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageUkrainian.
  ///
  /// In en, this message translates to:
  /// **'Українська'**
  String get languageUkrainian;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @languagePolish.
  ///
  /// In en, this message translates to:
  /// **'Polski'**
  String get languagePolish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageCzech.
  ///
  /// In en, this message translates to:
  /// **'Čeština'**
  String get languageCzech;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Hestia'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'A quiet messenger for private chats, calls, and files.'**
  String get onboardingWelcomeBody;

  /// No description provided for @onboardingPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Private by design'**
  String get onboardingPrivacyTitle;

  /// No description provided for @onboardingPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Messages use encryption keys. Your chats and files stay stored locally.'**
  String get onboardingPrivacyBody;

  /// No description provided for @onboardingHowItWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'Simple flow'**
  String get onboardingHowItWorksTitle;

  /// No description provided for @onboardingHowItWorksBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a server, add contacts, and approve requests before chatting.'**
  String get onboardingHowItWorksBody;

  /// No description provided for @onboardingCallsFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Calls and files'**
  String get onboardingCallsFilesTitle;

  /// No description provided for @onboardingCallsFilesBody.
  ///
  /// In en, this message translates to:
  /// **'Start voice calls and share files from the same protected space.'**
  String get onboardingCallsFilesBody;

  /// No description provided for @onboardingServerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your server'**
  String get onboardingServerTitle;

  /// No description provided for @onboardingServerBody.
  ///
  /// In en, this message translates to:
  /// **'Use the default server or connect Hestia to your own server.'**
  String get onboardingServerBody;

  /// No description provided for @onboardingDefaultServer.
  ///
  /// In en, this message translates to:
  /// **'Default server'**
  String get onboardingDefaultServer;

  /// No description provided for @onboardingCustomServer.
  ///
  /// In en, this message translates to:
  /// **'Custom server'**
  String get onboardingCustomServer;

  /// No description provided for @onboardingCustomServerBody.
  ///
  /// In en, this message translates to:
  /// **'For self-hosted or private deployments.'**
  String get onboardingCustomServerBody;

  /// No description provided for @onboardingGetStartedTitle.
  ///
  /// In en, this message translates to:
  /// **'Ready when you are'**
  String get onboardingGetStartedTitle;

  /// No description provided for @onboardingGetStartedBody.
  ///
  /// In en, this message translates to:
  /// **'Create a new account or login with an existing one.'**
  String get onboardingGetStartedBody;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @diagnosticMode.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic mode'**
  String get diagnosticMode;

  /// No description provided for @diagnosticModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Off by default. No passwords, tokens, or message plaintext.'**
  String get diagnosticModeDescription;

  /// No description provided for @testMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Test microphone'**
  String get testMicrophone;

  /// No description provided for @copyDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Copy diagnostics'**
  String get copyDiagnostics;

  /// No description provided for @videoPreview.
  ///
  /// In en, this message translates to:
  /// **'Video preview'**
  String get videoPreview;

  /// No description provided for @switchCamera.
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get switchCamera;

  /// No description provided for @cameraMicPermissionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera and microphone permissions are required.'**
  String get cameraMicPermissionsRequired;

  /// No description provided for @cameraPreviewTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Camera preview timed out.'**
  String get cameraPreviewTimedOut;

  /// No description provided for @cameraUnavailableCheckPermissions.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable. Check camera and microphone permissions.'**
  String get cameraUnavailableCheckPermissions;

  /// No description provided for @noCameraVideoTrack.
  ///
  /// In en, this message translates to:
  /// **'No camera video track was created.'**
  String get noCameraVideoTrack;

  /// No description provided for @micPermissionRequiredForCalls.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required for calls.'**
  String get micPermissionRequiredForCalls;

  /// No description provided for @cameraPermissionRequiredForVideoCalls.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required for video calls.'**
  String get cameraPermissionRequiredForVideoCalls;

  /// No description provided for @noCameraFound.
  ///
  /// In en, this message translates to:
  /// **'No camera was found.'**
  String get noCameraFound;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'cs',
        'de',
        'en',
        'es',
        'pl',
        'ru',
        'uk'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pl':
      return AppLocalizationsPl();
    case 'ru':
      return AppLocalizationsRu();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
