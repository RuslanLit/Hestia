// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appName => 'Hestia';

  @override
  String get splashTagline => 'Soukromý prostor pro vaše blízké';

  @override
  String get systemDefault => 'Podle systému';

  @override
  String get language => 'Jazyk';

  @override
  String get settings => 'Nastavení';

  @override
  String get theme => 'Motiv';

  @override
  String get themeSystem => 'Systémový';

  @override
  String get themeLight => 'Světlý';

  @override
  String get themeDark => 'Tmavý';

  @override
  String get appearance => 'Vzhled';

  @override
  String get background => 'Pozadí';

  @override
  String get backgroundDefault => 'Výchozí';

  @override
  String get backgroundChooseColor => 'Vybrat barvu';

  @override
  String get backgroundChooseImage => 'Vybrat obrázek';

  @override
  String get reset => 'Resetovat';

  @override
  String get cancel => 'Zrušit';

  @override
  String get save => 'Uložit';

  @override
  String get close => 'Zavřít';

  @override
  String get continueAction => 'Pokračovat';

  @override
  String get search => 'Hledat';

  @override
  String get refresh => 'Obnovit';

  @override
  String get accept => 'Přijmout';

  @override
  String get decline => 'Odmítnout';

  @override
  String get request => 'Žádost';

  @override
  String get error => 'Chyba';

  @override
  String get server => 'Server';

  @override
  String get serverUrl => 'URL serveru';

  @override
  String serverConnected(String host) {
    return 'Připojeno k $host';
  }

  @override
  String get serverDisconnected => 'Odpojeno';

  @override
  String get login => 'Přihlášení';

  @override
  String get registration => 'Registrace';

  @override
  String get register => 'Registrovat';

  @override
  String get nicknameRequired => 'Uživatelské jméno je povinné';

  @override
  String get passwordRequired => 'Heslo je povinné';

  @override
  String get nicknameTooShort => 'Uživatelské jméno musí mít alespoň 2 znaky';

  @override
  String get passwordTooShort => 'Heslo musí mít alespoň 6 znaků';

  @override
  String get chooseNickname => 'Zvolte nové uživatelské jméno';

  @override
  String get yourNickname => 'Vaše uživatelské jméno';

  @override
  String get choosePassword => 'Zvolte heslo';

  @override
  String get password => 'Heslo';

  @override
  String get showPassword => 'Zobrazit heslo';

  @override
  String get hidePassword => 'Skrýt heslo';

  @override
  String get chats => 'Chaty';

  @override
  String get contacts => 'Kontakty';

  @override
  String get requests => 'Žádosti';

  @override
  String get addContact => 'Přidat kontakt';

  @override
  String get privacy => 'Soukromí';

  @override
  String get backup => 'Záloha';

  @override
  String get devices => 'Zařízení';

  @override
  String get allowUsernameSearch => 'Povolit vyhledávání podle jména';

  @override
  String get messagesFrom => 'Zprávy od';

  @override
  String get callsFrom => 'Hovory od';

  @override
  String get everyone => 'Všichni';

  @override
  String get noChatsYet => 'Zatím žádné chaty.';

  @override
  String get noContactsYet => 'Přidejte kontakt a začněte konverzaci';

  @override
  String get firstRunNoContactsTitle => 'Přidejte kontakt a začněte konverzaci';

  @override
  String get firstRunNoContactsBody =>
      'Najděte člověka podle uživatelského jména a pošlete žádost.';

  @override
  String get hintAddContact => 'Najděte člověka podle uživatelského jména';

  @override
  String get hintRequests => 'Tady se zobrazují žádosti o přidání';

  @override
  String get hintMessageInput => 'Napište zprávu';

  @override
  String get noPendingRequests => 'Žádné čekající žádosti.';

  @override
  String get findUsername => 'Najít uživatelské jméno';

  @override
  String get username => 'Uživatelské jméno';

  @override
  String get enterUsername => 'Zadejte uživatelské jméno';

  @override
  String get userFound => 'Uživatel nalezen';

  @override
  String get userNotFound =>
      'Uživatel nebyl nalezen nebo je vyhledávání vypnuté.';

  @override
  String get sendContactRequest => 'Poslat žádost o kontakt';

  @override
  String requestSentTo(String name) {
    return 'Žádost odeslána uživateli $name';
  }

  @override
  String get retentionContactAdded => 'Kontakt přidán. Můžete začít chat.';

  @override
  String get retentionFirstMessageSent =>
      'Zpráva odeslána. Hestia udrží konverzaci klidnou a soukromou.';

  @override
  String get retentionStartChatHint =>
      'Otevřete chat a pošlete první zprávu, až budete připraveni.';

  @override
  String get retentionDayReminder =>
      'Už jste si chvíli nepsali. Soukromé chaty jsou tady, až budete chtít odpovědět.';

  @override
  String get retentionThreeDayReminder =>
      'Jemné připomenutí: důvěryhodné konverzace tu na vás čekají.';

  @override
  String get retentionNewMessages => 'Máte nové zprávy.';

  @override
  String get contact => 'Kontakt';

  @override
  String get contactOnline => 'Právě online';

  @override
  String get block => 'Blokovat';

  @override
  String get unblockUser => 'Odblokovat uživatele';

  @override
  String get blockUser => 'Blokovat uživatele';

  @override
  String get wantsToAddYou => 'Chce si vás přidat do kontaktů';

  @override
  String get attachment => 'Příloha';

  @override
  String attachmentNamed(String name) {
    return 'Příloha: $name';
  }

  @override
  String get mute => 'Ztlumit';

  @override
  String get unmute => 'Zrušit ztlumení';

  @override
  String get pin => 'Připnout';

  @override
  String get unpin => 'Odepnout';

  @override
  String get archive => 'Archivovat';

  @override
  String get deleteForMe => 'Smazat u mě';

  @override
  String get backupWarning =>
      'Zálohy jsou šifrované lokálně. Heslo si bezpečně uložte: bez něj zálohu nelze obnovit.';

  @override
  String get backupPassword => 'Heslo zálohy';

  @override
  String get confirmBackupPassword => 'Potvrďte heslo pro export';

  @override
  String get backupPasswordsDoNotMatch => 'Hesla zálohy se neshodují.';

  @override
  String get backupExportCancelled => 'Export zálohy byl zrušen.';

  @override
  String get backupSaved => 'Záloha uložena.';

  @override
  String get backupImported => 'Záloha importována. Místní data byla obnovena.';

  @override
  String get import => 'Importovat';

  @override
  String get export => 'Exportovat';

  @override
  String get noSessionData => 'Zatím žádná data o relacích.';

  @override
  String get unknownActivity => 'Neznámá aktivita';

  @override
  String lastActive(String time) {
    return 'Poslední aktivita $time';
  }

  @override
  String currentDevice(String name) {
    return '$name (aktuální)';
  }

  @override
  String get revoke => 'Odvolat';

  @override
  String get logoutCurrent => 'Odhlásit aktuální';

  @override
  String get message => 'Zpráva';

  @override
  String get send => 'Odeslat';

  @override
  String get sendFile => 'Odeslat soubor';

  @override
  String messageSendFailed(String error) {
    return 'Zprávu se nepodařilo odeslat: $error';
  }

  @override
  String fileSendFailed(String error) {
    return 'Soubor se nepodařilo odeslat: $error';
  }

  @override
  String get noMessagesYet => 'Napište první zprávu';

  @override
  String get reply => 'Odpovědět';

  @override
  String get forward => 'Přeposlat';

  @override
  String get forwardTo => 'Přeposlat komu';

  @override
  String get forwarded => 'Přeposláno';

  @override
  String forwardedFrom(String name) {
    return 'Přeposláno od $name';
  }

  @override
  String forwardedTo(String name) {
    return 'Přeposláno uživateli $name';
  }

  @override
  String forwardFailed(String error) {
    return 'Přeposlání selhalo: $error';
  }

  @override
  String get noForwardTargets => 'Nejsou dostupné kontakty pro přeposlání';

  @override
  String get cancelReply => 'Zrušit odpověď';

  @override
  String get originalMessage => 'Původní zpráva';

  @override
  String get originalMessageUnavailable => 'Původní zpráva není dostupná';

  @override
  String savedTo(String path) {
    return 'Uloženo do $path';
  }

  @override
  String saveFailed(String error) {
    return 'Uložení selhalo: $error';
  }

  @override
  String get open => 'Otevřít';

  @override
  String get userUnavailable => 'Uživatel není dostupný.';

  @override
  String get callRejected => 'Hovor byl odmítnut.';

  @override
  String get sessionRevoked => 'Tato relace byla odvolána.';

  @override
  String couldNotConnectTo(String host) {
    return 'Nepodařilo se připojit k $host';
  }

  @override
  String get unknownServerError => 'Neznámá chyba serveru';

  @override
  String get authenticationRequired => 'Je vyžadováno ověření.';

  @override
  String get localFileNotFound => 'Místní soubor nebyl nalezen.';

  @override
  String get webAttachmentAvailable =>
      'Soubor je dostupný v aktuální relaci prohlížeče.';

  @override
  String get webAttachmentUnavailable =>
      'Soubor po restartu prohlížeče není dostupný.';

  @override
  String get attachmentTypeNotAllowed => 'Tento typ přílohy není povolen.';

  @override
  String get attachmentValidationFailed => 'Přílohu se nepodařilo ověřit.';

  @override
  String get attachmentTooLarge => 'Příloha je příliš velká.';

  @override
  String get attachmentLimits =>
      'Povolené soubory: dokumenty, obrázky, audio a video. Limity: obrázky 25 MB, audio/dokumenty 50 MB, video 200 MB.';

  @override
  String get selectedFileReadFailed => 'Vybraný soubor se nepodařilo přečíst.';

  @override
  String get forwardLocalFileUnavailable =>
      'Přeposlání selhalo: místní soubor není dostupný.';

  @override
  String get attachmentUploadFailed => 'Přílohu se nepodařilo nahrát.';

  @override
  String peerKeyChangedCall(String name) {
    return 'Šifrovací klíč uživatele $name se změnil. Před hovorem ověřte otisk.';
  }

  @override
  String peerNoEncryptionKey(String name) {
    return '$name zatím nemá šifrovací klíč.';
  }

  @override
  String get encryptionKey => 'Šifrovací klíč';

  @override
  String get verify => 'Ověřit';

  @override
  String get trustKey => 'Důvěřovat klíči';

  @override
  String get trustNewKey => 'Důvěřovat novému klíči';

  @override
  String get removeTrust => 'Odebrat důvěru';

  @override
  String get verifiedEncryptionKey => 'Ověřený šifrovací klíč';

  @override
  String get encryptionKeyChanged => 'Šifrovací klíč se změnil';

  @override
  String get noEncryptionKey => 'Žádný šifrovací klíč';

  @override
  String get verifyEncryptionKey => 'Ověřit šifrovací klíč';

  @override
  String get sendingBlockedKeyChanged =>
      'Odesílání je zablokováno, dokud tento kontakt znovu neověříte.';

  @override
  String get keyTrusted => 'Tento klíč je na tomto zařízení důvěryhodný.';

  @override
  String get keyChangedWarning =>
      'Upozornění: tento klíč se změnil. Před opětovnou důvěrou porovnejte otisk.';

  @override
  String get keyMissing => 'Tento uživatel zatím nezveřejnil šifrovací klíč.';

  @override
  String get keyUntrusted =>
      'Porovnejte tento otisk s druhým uživatelem a potom klíči důvěřujte.';

  @override
  String get noFingerprint => 'Otisk není dostupný';

  @override
  String get audioCall => 'Audio hovor';

  @override
  String get videoCall => 'Video hovor';

  @override
  String callFailed(String error) {
    return 'Hovor selhal: $error';
  }

  @override
  String get anotherCallActive => 'Jiný hovor je už aktivní';

  @override
  String get calling => 'Volání...';

  @override
  String get connected => 'Připojeno';

  @override
  String get muteCall => 'Mikrofon vypnutý';

  @override
  String get unmuteCall => 'Mikrofon zapnutý';

  @override
  String get endCall => 'Ukončit';

  @override
  String get incomingCall => 'Příchozí hovor';

  @override
  String get voiceCall => 'Hlasový hovor';

  @override
  String get pushSyncChannelDescription =>
      'Synchronizační oznámení Hestia pro zprávy a žádosti.';

  @override
  String get pushCallChannelDescription =>
      'Upozornění Hestia na příchozí hovory.';

  @override
  String get newContactRequestNotification => 'Nová žádost o kontakt';

  @override
  String get newMessageNotification => 'Nová zpráva';

  @override
  String get incomingVideoCallNotification => 'Příchozí videohovor';

  @override
  String get incomingVoiceCallNotification => 'Příchozí hlasový hovor';

  @override
  String get unknownCaller => 'Neznámý';

  @override
  String get rejectCall => 'Odmítnout';

  @override
  String get updateAvailable => 'Dostupná aktualizace';

  @override
  String versionAvailable(String version) {
    return 'Je dostupná verze $version.';
  }

  @override
  String get startingDownload => 'Spouštění stahování...';

  @override
  String downloadingProgress(String percent) {
    return 'Stahování... $percent%';
  }

  @override
  String get downloadFailedRetry => 'Stažení selhalo. Zkuste to znovu.';

  @override
  String get later => 'Později';

  @override
  String get downloading => 'Stahování...';

  @override
  String get updateViaAppStore => 'Aktualizovat přes App Store';

  @override
  String get downloadAndInstall => 'Stáhnout a nainstalovat';

  @override
  String get openDownloadPage => 'Otevřít stránku stažení';

  @override
  String get checkForUpdates => 'Zkontrolovat aktualizace';

  @override
  String get latestVersionInstalled => 'Již máte nejnovější verzi.';

  @override
  String get updatesAndroidOnly =>
      'Aktualizace jsou dostupné pouze pro Android.';

  @override
  String get updateCheckFailed =>
      'Aktualizace se nepodařilo zkontrolovat. Zkuste to znovu.';

  @override
  String currentVersionLabel(String version) {
    return 'Aktuální verze: $version';
  }

  @override
  String latestVersionLabel(String version) {
    return 'Nejnovější verze: $version';
  }

  @override
  String get releaseNotes => 'Poznámky k vydání';

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
  String get onboardingSkip => 'Přeskočit';

  @override
  String get onboardingNext => 'Další';

  @override
  String get onboardingGetStarted => 'Začít';

  @override
  String get onboardingWelcomeTitle => 'Vítejte v Hestia';

  @override
  String get onboardingWelcomeBody =>
      'Klidný messenger pro soukromé chaty, hovory a soubory.';

  @override
  String get onboardingPrivacyTitle => 'Soukromí od návrhu';

  @override
  String get onboardingPrivacyBody =>
      'Zprávy používají šifrovací klíče. Chaty a soubory zůstávají lokálně.';

  @override
  String get onboardingHowItWorksTitle => 'Jednoduchý postup';

  @override
  String get onboardingHowItWorksBody =>
      'Vyberte server, přidejte kontakty a schvalujte žádosti před chatem.';

  @override
  String get onboardingCallsFilesTitle => 'Hovory a soubory';

  @override
  String get onboardingCallsFilesBody =>
      'Spouštějte hlasové hovory a sdílejte soubory ve stejném chráněném prostoru.';

  @override
  String get onboardingServerTitle => 'Vyberte server';

  @override
  String get onboardingServerBody =>
      'Použijte výchozí server nebo připojte Hestia k vlastnímu serveru.';

  @override
  String get onboardingDefaultServer => 'Výchozí server';

  @override
  String get onboardingCustomServer => 'Vlastní server';

  @override
  String get onboardingCustomServerBody =>
      'Pro self-hosted nebo soukromé nasazení.';

  @override
  String get onboardingGetStartedTitle => 'Můžete začít';

  @override
  String get onboardingGetStartedBody =>
      'Vytvořte nový účet nebo se přihlaste ke stávajícímu.';

  @override
  String get diagnostics => 'Diagnostika';

  @override
  String get diagnosticMode => 'Diagnostický režim';

  @override
  String get diagnosticModeDescription =>
      'Ve výchozím nastavení vypnuto. Bez hesel, tokenů nebo prostého textu zpráv.';

  @override
  String get testMicrophone => 'Otestovat mikrofon';

  @override
  String get copyDiagnostics => 'Kopírovat diagnostiku';

  @override
  String get videoPreview => 'Náhled videa';

  @override
  String get switchCamera => 'Přepnout kameru';

  @override
  String get cameraMicPermissionsRequired =>
      'Jsou vyžadována oprávnění ke kameře a mikrofonu.';

  @override
  String get cameraPreviewTimedOut => 'Vypršel časový limit náhledu kamery.';

  @override
  String get cameraUnavailableCheckPermissions =>
      'Kamera není dostupná. Zkontrolujte oprávnění ke kameře a mikrofonu.';

  @override
  String get noCameraVideoTrack => 'Nebyla vytvořena video stopa kamery.';

  @override
  String get micPermissionRequiredForCalls =>
      'Pro hovory je vyžadováno oprávnění k mikrofonu.';

  @override
  String get cameraPermissionRequiredForVideoCalls =>
      'Pro videohovory je vyžadováno oprávnění ke kameře.';

  @override
  String get noCameraFound => 'Nebyla nalezena žádná kamera.';
}
