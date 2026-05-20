// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Hestia';

  @override
  String get splashTagline => 'Privater Raum für vertraute Menschen';

  @override
  String get systemDefault => 'Systemstandard';

  @override
  String get language => 'Sprache';

  @override
  String get settings => 'Einstellungen';

  @override
  String get theme => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get appearance => 'Darstellung';

  @override
  String get background => 'Hintergrund';

  @override
  String get backgroundDefault => 'Standard';

  @override
  String get backgroundChooseColor => 'Farbe wählen';

  @override
  String get backgroundChooseImage => 'Bild wählen';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get save => 'Speichern';

  @override
  String get close => 'Schließen';

  @override
  String get continueAction => 'Weiter';

  @override
  String get search => 'Suchen';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get accept => 'Annehmen';

  @override
  String get decline => 'Ablehnen';

  @override
  String get request => 'Anfrage';

  @override
  String get error => 'Fehler';

  @override
  String get server => 'Server';

  @override
  String get serverUrl => 'Server-URL';

  @override
  String serverConnected(String host) {
    return 'Verbunden mit $host';
  }

  @override
  String get serverDisconnected => 'Getrennt';

  @override
  String get login => 'Anmelden';

  @override
  String get registration => 'Registrierung';

  @override
  String get register => 'Registrieren';

  @override
  String get nicknameRequired => 'Benutzername ist erforderlich';

  @override
  String get passwordRequired => 'Passwort ist erforderlich';

  @override
  String get nicknameTooShort => 'Benutzername muss mindestens 2 Zeichen haben';

  @override
  String get passwordTooShort => 'Passwort muss mindestens 6 Zeichen haben';

  @override
  String get chooseNickname => 'Neuen Benutzernamen wählen';

  @override
  String get yourNickname => 'Dein Benutzername';

  @override
  String get choosePassword => 'Passwort wählen';

  @override
  String get password => 'Passwort';

  @override
  String get showPassword => 'Passwort anzeigen';

  @override
  String get hidePassword => 'Passwort ausblenden';

  @override
  String get chats => 'Chats';

  @override
  String get contacts => 'Kontakte';

  @override
  String get requests => 'Anfragen';

  @override
  String get addContact => 'Kontakt hinzufügen';

  @override
  String get privacy => 'Datenschutz';

  @override
  String get backup => 'Backup';

  @override
  String get devices => 'Geräte';

  @override
  String get allowUsernameSearch => 'Suche nach Benutzername erlauben';

  @override
  String get messagesFrom => 'Nachrichten von';

  @override
  String get callsFrom => 'Anrufe von';

  @override
  String get everyone => 'Alle';

  @override
  String get noChatsYet => 'Noch keine Chats.';

  @override
  String get noContactsYet =>
      'Füge einen Kontakt hinzu, um ein Gespräch zu beginnen';

  @override
  String get firstRunNoContactsTitle =>
      'Füge einen Kontakt hinzu, um ein Gespräch zu beginnen';

  @override
  String get firstRunNoContactsBody =>
      'Suche jemanden per Benutzername und sende eine Anfrage.';

  @override
  String get hintAddContact => 'Finde jemanden per Benutzername';

  @override
  String get hintRequests => 'Hier erscheinen Kontaktanfragen';

  @override
  String get hintMessageInput => 'Schreibe eine Nachricht';

  @override
  String get noPendingRequests => 'Keine ausstehenden Anfragen.';

  @override
  String get findUsername => 'Benutzernamen suchen';

  @override
  String get username => 'Benutzername';

  @override
  String get enterUsername => 'Benutzernamen eingeben';

  @override
  String get userFound => 'Benutzer gefunden';

  @override
  String get userNotFound =>
      'Benutzer nicht gefunden oder Suche ist deaktiviert.';

  @override
  String get sendContactRequest => 'Kontaktanfrage senden';

  @override
  String requestSentTo(String name) {
    return 'Anfrage an $name gesendet';
  }

  @override
  String get retentionContactAdded =>
      'Kontakt hinzugefügt. Du kannst einen Chat starten.';

  @override
  String get retentionFirstMessageSent =>
      'Nachricht gesendet. Hestia hält das Gespräch ruhig und privat.';

  @override
  String get retentionStartChatHint =>
      'Öffne einen Chat und sende deine erste Nachricht, wenn du bereit bist.';

  @override
  String get retentionDayReminder =>
      'Ihr habt länger nicht gesprochen. Deine privaten Chats sind hier, wenn du in Ruhe antworten möchtest.';

  @override
  String get retentionThreeDayReminder =>
      'Eine sanfte Erinnerung: deine vertrauten Gespräche warten hier.';

  @override
  String get retentionNewMessages => 'Du hast neue Nachrichten.';

  @override
  String get contact => 'Kontakt';

  @override
  String get contactOnline => 'Jetzt online';

  @override
  String get block => 'Blockieren';

  @override
  String get unblockUser => 'Benutzer entsperren';

  @override
  String get blockUser => 'Benutzer blockieren';

  @override
  String get wantsToAddYou => 'Möchte dich als Kontakt hinzufügen';

  @override
  String get attachment => 'Anhang';

  @override
  String attachmentNamed(String name) {
    return 'Anhang: $name';
  }

  @override
  String get mute => 'Stummschalten';

  @override
  String get unmute => 'Stummschaltung aufheben';

  @override
  String get pin => 'Anheften';

  @override
  String get unpin => 'Lösen';

  @override
  String get archive => 'Archivieren';

  @override
  String get deleteForMe => 'Für mich löschen';

  @override
  String get backupWarning =>
      'Backups werden lokal verschlüsselt. Bewahre das Passwort gut auf: Ohne es kann das Backup nicht wiederhergestellt werden.';

  @override
  String get backupPassword => 'Backup-Passwort';

  @override
  String get confirmBackupPassword => 'Passwort für Export bestätigen';

  @override
  String get backupPasswordsDoNotMatch =>
      'Backup-Passwörter stimmen nicht überein.';

  @override
  String get backupExportCancelled => 'Backup-Export abgebrochen.';

  @override
  String get backupSaved => 'Backup gespeichert.';

  @override
  String get backupImported =>
      'Backup importiert. Lokale Daten wurden wiederhergestellt.';

  @override
  String get import => 'Importieren';

  @override
  String get export => 'Exportieren';

  @override
  String get noSessionData => 'Noch keine Sitzungsdaten.';

  @override
  String get unknownActivity => 'Unbekannte Aktivität';

  @override
  String lastActive(String time) {
    return 'Zuletzt aktiv $time';
  }

  @override
  String currentDevice(String name) {
    return '$name (aktuell)';
  }

  @override
  String get revoke => 'Widerrufen';

  @override
  String get logoutCurrent => 'Aktuelle Sitzung abmelden';

  @override
  String get message => 'Nachricht';

  @override
  String get send => 'Senden';

  @override
  String get sendFile => 'Datei senden';

  @override
  String messageSendFailed(String error) {
    return 'Nachricht konnte nicht gesendet werden: $error';
  }

  @override
  String fileSendFailed(String error) {
    return 'Datei konnte nicht gesendet werden: $error';
  }

  @override
  String get noMessagesYet => 'Schreibe die erste Nachricht';

  @override
  String get reply => 'Antworten';

  @override
  String get forward => 'Weiterleiten';

  @override
  String get forwardTo => 'Weiterleiten an';

  @override
  String get forwarded => 'Weitergeleitet';

  @override
  String forwardedFrom(String name) {
    return 'Weitergeleitet von $name';
  }

  @override
  String forwardedTo(String name) {
    return 'Weitergeleitet an $name';
  }

  @override
  String forwardFailed(String error) {
    return 'Weiterleiten fehlgeschlagen: $error';
  }

  @override
  String get noForwardTargets => 'Keine verfügbaren Kontakte zum Weiterleiten';

  @override
  String get cancelReply => 'Antwort abbrechen';

  @override
  String get originalMessage => 'Ursprüngliche Nachricht';

  @override
  String get originalMessageUnavailable =>
      'Ursprüngliche Nachricht nicht verfügbar';

  @override
  String savedTo(String path) {
    return 'Gespeichert unter $path';
  }

  @override
  String saveFailed(String error) {
    return 'Speichern fehlgeschlagen: $error';
  }

  @override
  String get open => 'Öffnen';

  @override
  String get userUnavailable => 'Benutzer ist nicht verfügbar.';

  @override
  String get callRejected => 'Anruf wurde abgelehnt.';

  @override
  String get sessionRevoked => 'Diese Sitzung wurde widerrufen.';

  @override
  String couldNotConnectTo(String host) {
    return 'Verbindung zu $host nicht möglich';
  }

  @override
  String get unknownServerError => 'Unbekannter Serverfehler';

  @override
  String get authenticationRequired => 'Authentifizierung erforderlich.';

  @override
  String get localFileNotFound => 'Lokale Datei nicht gefunden.';

  @override
  String get webAttachmentAvailable =>
      'Die Datei ist in dieser Browser-Sitzung verfügbar.';

  @override
  String get webAttachmentUnavailable =>
      'Die Datei ist nach einem Neustart des Browsers nicht verfügbar.';

  @override
  String get attachmentTypeNotAllowed => 'Dieser Anhangstyp ist nicht erlaubt.';

  @override
  String get attachmentValidationFailed =>
      'Anhang konnte nicht geprüft werden.';

  @override
  String get attachmentTooLarge => 'Der Anhang ist zu groß.';

  @override
  String get attachmentLimits =>
      'Erlaubte Dateien: Dokumente, Bilder, Audio und Video. Limits: Bilder 25 MB, Audio/Dokumente 50 MB, Video 200 MB.';

  @override
  String get selectedFileReadFailed =>
      'Die ausgewählte Datei konnte nicht gelesen werden.';

  @override
  String get forwardLocalFileUnavailable =>
      'Weiterleiten fehlgeschlagen: Die lokale Datei ist nicht verfügbar.';

  @override
  String get attachmentUploadFailed =>
      'Anhang konnte nicht hochgeladen werden.';

  @override
  String peerKeyChangedCall(String name) {
    return 'Der Verschlüsselungsschlüssel von $name hat sich geändert. Prüfe den Fingerabdruck vor dem Anruf.';
  }

  @override
  String peerNoEncryptionKey(String name) {
    return '$name hat noch keinen Verschlüsselungsschlüssel.';
  }

  @override
  String get encryptionKey => 'Verschlüsselungsschlüssel';

  @override
  String get verify => 'Prüfen';

  @override
  String get trustKey => 'Schlüssel vertrauen';

  @override
  String get trustNewKey => 'Neuem Schlüssel vertrauen';

  @override
  String get removeTrust => 'Vertrauen entfernen';

  @override
  String get verifiedEncryptionKey => 'Verifizierter Verschlüsselungsschlüssel';

  @override
  String get encryptionKeyChanged => 'Verschlüsselungsschlüssel geändert';

  @override
  String get noEncryptionKey => 'Kein Verschlüsselungsschlüssel';

  @override
  String get verifyEncryptionKey => 'Verschlüsselungsschlüssel prüfen';

  @override
  String get sendingBlockedKeyChanged =>
      'Senden ist blockiert, bis du diesen Kontakt erneut verifizierst.';

  @override
  String get keyTrusted => 'Diesem Schlüssel wird auf diesem Gerät vertraut.';

  @override
  String get keyChangedWarning =>
      'Achtung: Dieser Schlüssel hat sich geändert. Vergleiche den Fingerabdruck, bevor du ihm erneut vertraust.';

  @override
  String get keyMissing =>
      'Dieser Benutzer hat noch keinen Verschlüsselungsschlüssel veröffentlicht.';

  @override
  String get keyUntrusted =>
      'Vergleiche diesen Fingerabdruck mit der anderen Person und vertraue dann dem Schlüssel.';

  @override
  String get noFingerprint => 'Kein Fingerabdruck verfügbar';

  @override
  String get audioCall => 'Audioanruf';

  @override
  String get videoCall => 'Videoanruf';

  @override
  String callFailed(String error) {
    return 'Anruf fehlgeschlagen: $error';
  }

  @override
  String get anotherCallActive => 'Ein anderer Anruf ist bereits aktiv';

  @override
  String get calling => 'Anrufen...';

  @override
  String get connected => 'Verbunden';

  @override
  String get muteCall => 'Mikrofon aus';

  @override
  String get unmuteCall => 'Mikrofon an';

  @override
  String get endCall => 'Beenden';

  @override
  String get incomingCall => 'Eingehender Anruf';

  @override
  String get voiceCall => 'Sprachanruf';

  @override
  String get pushSyncChannelDescription =>
      'Synchronisierungsbenachrichtigungen für Hestia-Nachrichten und -Anfragen.';

  @override
  String get pushCallChannelDescription =>
      'Hinweise auf eingehende Hestia-Anrufe.';

  @override
  String get newContactRequestNotification => 'Neue Kontaktanfrage';

  @override
  String get newMessageNotification => 'Neue Nachricht';

  @override
  String get incomingVideoCallNotification => 'Eingehender Videoanruf';

  @override
  String get incomingVoiceCallNotification => 'Eingehender Sprachanruf';

  @override
  String get unknownCaller => 'Unbekannt';

  @override
  String get rejectCall => 'Ablehnen';

  @override
  String get updateAvailable => 'Update verfügbar';

  @override
  String versionAvailable(String version) {
    return 'Version $version ist verfügbar.';
  }

  @override
  String get startingDownload => 'Download wird gestartet...';

  @override
  String downloadingProgress(String percent) {
    return 'Download läuft... $percent%';
  }

  @override
  String get downloadFailedRetry =>
      'Download fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get later => 'Später';

  @override
  String get downloading => 'Download läuft...';

  @override
  String get updateViaAppStore => 'Über App Store aktualisieren';

  @override
  String get downloadAndInstall => 'Herunterladen und installieren';

  @override
  String get openDownloadPage => 'Download-Seite öffnen';

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
  String get onboardingSkip => 'Überspringen';

  @override
  String get onboardingNext => 'Weiter';

  @override
  String get onboardingGetStarted => 'Loslegen';

  @override
  String get onboardingWelcomeTitle => 'Willkommen bei Hestia';

  @override
  String get onboardingWelcomeBody =>
      'Ein ruhiger Messenger für private Chats, Anrufe und Dateien.';

  @override
  String get onboardingPrivacyTitle => 'Privat von Anfang an';

  @override
  String get onboardingPrivacyBody =>
      'Nachrichten nutzen Verschlüsselungsschlüssel. Chats und Dateien bleiben lokal gespeichert.';

  @override
  String get onboardingHowItWorksTitle => 'Einfacher Ablauf';

  @override
  String get onboardingHowItWorksBody =>
      'Server wählen, Kontakte hinzufügen und Anfragen vor dem Chatten bestätigen.';

  @override
  String get onboardingCallsFilesTitle => 'Anrufe und Dateien';

  @override
  String get onboardingCallsFilesBody =>
      'Starte Sprachanrufe und teile Dateien im selben geschützten Bereich.';

  @override
  String get onboardingServerTitle => 'Server wählen';

  @override
  String get onboardingServerBody =>
      'Nutze den Standardserver oder verbinde Hestia mit deinem eigenen Server.';

  @override
  String get onboardingDefaultServer => 'Standardserver';

  @override
  String get onboardingCustomServer => 'Eigener Server';

  @override
  String get onboardingCustomServerBody =>
      'Für self-hosted oder private Installationen.';

  @override
  String get onboardingGetStartedTitle => 'Bereit zum Start';

  @override
  String get onboardingGetStartedBody =>
      'Erstelle ein neues Konto oder melde dich mit einem bestehenden an.';

  @override
  String get diagnostics => 'Diagnose';

  @override
  String get diagnosticMode => 'Diagnosemodus';

  @override
  String get diagnosticModeDescription =>
      'Standardmäßig deaktiviert. Keine Passwörter, Tokens oder Klartextnachrichten.';

  @override
  String get testMicrophone => 'Mikrofon testen';

  @override
  String get copyDiagnostics => 'Diagnose kopieren';

  @override
  String get videoPreview => 'Videovorschau';

  @override
  String get switchCamera => 'Kamera wechseln';

  @override
  String get cameraMicPermissionsRequired =>
      'Kamera- und Mikrofonberechtigungen sind erforderlich.';

  @override
  String get cameraPreviewTimedOut =>
      'Zeitüberschreitung bei der Kameravorschau.';

  @override
  String get cameraUnavailableCheckPermissions =>
      'Kamera nicht verfügbar. Prüfe die Kamera- und Mikrofonberechtigungen.';

  @override
  String get noCameraVideoTrack => 'Es wurde keine Kameravideospur erstellt.';

  @override
  String get micPermissionRequiredForCalls =>
      'Für Anrufe ist die Mikrofonberechtigung erforderlich.';

  @override
  String get cameraPermissionRequiredForVideoCalls =>
      'Für Videoanrufe ist die Kameraberechtigung erforderlich.';

  @override
  String get noCameraFound => 'Keine Kamera gefunden.';
}
