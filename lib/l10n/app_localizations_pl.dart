// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appName => 'Hestia';

  @override
  String get splashTagline => 'Prywatna przestrzeń dla swoich';

  @override
  String get systemDefault => 'Domyślny systemowy';

  @override
  String get language => 'Język';

  @override
  String get settings => 'Ustawienia';

  @override
  String get theme => 'Motyw';

  @override
  String get themeSystem => 'Systemowy';

  @override
  String get themeLight => 'Jasny';

  @override
  String get themeDark => 'Ciemny';

  @override
  String get appearance => 'Wygląd';

  @override
  String get background => 'Tło';

  @override
  String get backgroundDefault => 'Domyślne';

  @override
  String get backgroundChooseColor => 'Wybierz kolor';

  @override
  String get backgroundChooseImage => 'Wybierz obraz';

  @override
  String get reset => 'Resetuj';

  @override
  String get cancel => 'Anuluj';

  @override
  String get save => 'Zapisz';

  @override
  String get close => 'Zamknij';

  @override
  String get continueAction => 'Kontynuuj';

  @override
  String get search => 'Szukaj';

  @override
  String get refresh => 'Odśwież';

  @override
  String get accept => 'Akceptuj';

  @override
  String get decline => 'Odrzuć';

  @override
  String get request => 'Prośba';

  @override
  String get error => 'Błąd';

  @override
  String get server => 'Serwer';

  @override
  String get serverUrl => 'URL serwera';

  @override
  String serverConnected(String host) {
    return 'Połączono z $host';
  }

  @override
  String get serverDisconnected => 'Rozłączono';

  @override
  String get login => 'Logowanie';

  @override
  String get registration => 'Rejestracja';

  @override
  String get register => 'Zarejestruj';

  @override
  String get nicknameRequired => 'Nazwa jest wymagana';

  @override
  String get passwordRequired => 'Hasło jest wymagane';

  @override
  String get nicknameTooShort => 'Nazwa musi mieć co najmniej 2 znaki';

  @override
  String get passwordTooShort => 'Hasło musi mieć co najmniej 6 znaków';

  @override
  String get chooseNickname => 'Wybierz nową nazwę';

  @override
  String get yourNickname => 'Twoja nazwa';

  @override
  String get choosePassword => 'Wybierz hasło';

  @override
  String get password => 'Hasło';

  @override
  String get showPassword => 'Pokaż hasło';

  @override
  String get hidePassword => 'Ukryj hasło';

  @override
  String get chats => 'Czaty';

  @override
  String get contacts => 'Kontakty';

  @override
  String get requests => 'Prośby';

  @override
  String get addContact => 'Dodaj kontakt';

  @override
  String get privacy => 'Prywatność';

  @override
  String get backup => 'Kopia zapasowa';

  @override
  String get devices => 'Urządzenia';

  @override
  String get allowUsernameSearch => 'Zezwalaj na wyszukiwanie po nazwie';

  @override
  String get messagesFrom => 'Wiadomości od';

  @override
  String get callsFrom => 'Połączenia od';

  @override
  String get everyone => 'Wszyscy';

  @override
  String get noChatsYet => 'Nie ma jeszcze czatów.';

  @override
  String get noContactsYet => 'Dodaj kontakt, aby rozpocząć rozmowę';

  @override
  String get firstRunNoContactsTitle => 'Dodaj kontakt, aby rozpocząć rozmowę';

  @override
  String get firstRunNoContactsBody =>
      'Znajdź osobę po nazwie użytkownika i wyślij prośbę.';

  @override
  String get hintAddContact => 'Znajdź osobę po nazwie użytkownika';

  @override
  String get hintRequests => 'Tutaj pojawiają się prośby o dodanie';

  @override
  String get hintMessageInput => 'Napisz wiadomość';

  @override
  String get noPendingRequests => 'Brak oczekujących próśb.';

  @override
  String get findUsername => 'Znajdź nazwę użytkownika';

  @override
  String get username => 'Nazwa użytkownika';

  @override
  String get enterUsername => 'Wpisz nazwę użytkownika';

  @override
  String get userFound => 'Znaleziono użytkownika';

  @override
  String get userNotFound =>
      'Nie znaleziono użytkownika albo wyszukiwanie jest wyłączone.';

  @override
  String get sendContactRequest => 'Wyślij prośbę o kontakt';

  @override
  String requestSentTo(String name) {
    return 'Wysłano prośbę do $name';
  }

  @override
  String get retentionContactAdded => 'Kontakt dodany. Możesz rozpocząć czat.';

  @override
  String get retentionFirstMessageSent =>
      'Wiadomość wysłana. Hestia zadba o spokojną i prywatną rozmowę.';

  @override
  String get retentionStartChatHint =>
      'Otwórz czat i wyślij pierwszą wiadomość, gdy będziesz gotowy.';

  @override
  String get retentionDayReminder =>
      'Dawno nie rozmawialiście. Prywatne czaty są tutaj, gdy chcesz spokojnie odpisać.';

  @override
  String get retentionThreeDayReminder =>
      'Delikatne przypomnienie: rozmowy z zaufanymi osobami czekają tutaj.';

  @override
  String get retentionNewMessages => 'Masz nowe wiadomości.';

  @override
  String get contact => 'Kontakt';

  @override
  String get contactOnline => 'Teraz online';

  @override
  String get block => 'Zablokuj';

  @override
  String get unblockUser => 'Odblokuj użytkownika';

  @override
  String get blockUser => 'Zablokuj użytkownika';

  @override
  String get wantsToAddYou => 'Chce dodać Cię do kontaktów';

  @override
  String get attachment => 'Załącznik';

  @override
  String attachmentNamed(String name) {
    return 'Załącznik: $name';
  }

  @override
  String get mute => 'Wycisz';

  @override
  String get unmute => 'Wyłącz wyciszenie';

  @override
  String get pin => 'Przypnij';

  @override
  String get unpin => 'Odepnij';

  @override
  String get archive => 'Archiwizuj';

  @override
  String get deleteForMe => 'Usuń u mnie';

  @override
  String get backupWarning =>
      'Kopie zapasowe są szyfrowane lokalnie. Zachowaj hasło: bez niego nie da się przywrócić kopii.';

  @override
  String get backupPassword => 'Hasło kopii zapasowej';

  @override
  String get confirmBackupPassword => 'Potwierdź hasło eksportu';

  @override
  String get backupPasswordsDoNotMatch =>
      'Hasła kopii zapasowej nie są zgodne.';

  @override
  String get backupExportCancelled => 'Eksport kopii zapasowej anulowany.';

  @override
  String get backupSaved => 'Kopia zapasowa zapisana.';

  @override
  String get backupImported =>
      'Kopia zapasowa zaimportowana. Dane lokalne zostały przywrócone.';

  @override
  String get import => 'Importuj';

  @override
  String get export => 'Eksportuj';

  @override
  String get noSessionData => 'Brak danych sesji.';

  @override
  String get unknownActivity => 'Nieznana aktywność';

  @override
  String lastActive(String time) {
    return 'Ostatnia aktywność $time';
  }

  @override
  String currentDevice(String name) {
    return '$name (bieżące)';
  }

  @override
  String get revoke => 'Odwołaj';

  @override
  String get logoutCurrent => 'Wyloguj bieżące';

  @override
  String get message => 'Wiadomość';

  @override
  String get send => 'Wyślij';

  @override
  String get sendFile => 'Wyślij plik';

  @override
  String messageSendFailed(String error) {
    return 'Nie udało się wysłać wiadomości: $error';
  }

  @override
  String fileSendFailed(String error) {
    return 'Nie udało się wysłać pliku: $error';
  }

  @override
  String get noMessagesYet => 'Napisz pierwszą wiadomość';

  @override
  String get reply => 'Odpowiedz';

  @override
  String get forward => 'Przekaż';

  @override
  String get forwardTo => 'Przekaż do';

  @override
  String get forwarded => 'Przekazano';

  @override
  String forwardedFrom(String name) {
    return 'Przekazano od $name';
  }

  @override
  String forwardedTo(String name) {
    return 'Przekazano do $name';
  }

  @override
  String forwardFailed(String error) {
    return 'Nie udało się przekazać: $error';
  }

  @override
  String get noForwardTargets => 'Brak dostępnych kontaktów do przekazania';

  @override
  String get cancelReply => 'Anuluj odpowiedź';

  @override
  String get originalMessage => 'Oryginalna wiadomość';

  @override
  String get originalMessageUnavailable =>
      'Oryginalna wiadomość jest niedostępna';

  @override
  String savedTo(String path) {
    return 'Zapisano w $path';
  }

  @override
  String saveFailed(String error) {
    return 'Nie udało się zapisać: $error';
  }

  @override
  String get open => 'Otwórz';

  @override
  String get userUnavailable => 'Użytkownik jest niedostępny.';

  @override
  String get callRejected => 'Połączenie zostało odrzucone.';

  @override
  String get sessionRevoked => 'Ta sesja została odwołana.';

  @override
  String couldNotConnectTo(String host) {
    return 'Nie udało się połączyć z $host';
  }

  @override
  String get unknownServerError => 'Nieznany błąd serwera';

  @override
  String get authenticationRequired => 'Wymagane uwierzytelnienie.';

  @override
  String get localFileNotFound => 'Nie znaleziono lokalnego pliku.';

  @override
  String get webAttachmentAvailable =>
      'Plik jest dostępny w bieżącej sesji przeglądarki.';

  @override
  String get webAttachmentUnavailable =>
      'Plik jest niedostępny po ponownym uruchomieniu przeglądarki.';

  @override
  String get attachmentTypeNotAllowed =>
      'Ten typ załącznika jest niedozwolony.';

  @override
  String get attachmentValidationFailed =>
      'Nie udało się sprawdzić załącznika.';

  @override
  String get attachmentTooLarge => 'Załącznik jest za duży.';

  @override
  String get attachmentLimits =>
      'Dozwolone pliki: dokumenty, obrazy, audio i wideo. Limity: obrazy 25 MB, audio/dokumenty 50 MB, wideo 200 MB.';

  @override
  String get selectedFileReadFailed =>
      'Nie udało się odczytać wybranego pliku.';

  @override
  String get forwardLocalFileUnavailable =>
      'Nie udało się przekazać: lokalny plik jest niedostępny.';

  @override
  String get attachmentUploadFailed => 'Nie udało się przesłać załącznika.';

  @override
  String peerKeyChangedCall(String name) {
    return 'Klucz szyfrowania użytkownika $name zmienił się. Sprawdź odcisk przed połączeniem.';
  }

  @override
  String peerNoEncryptionKey(String name) {
    return '$name nie ma jeszcze klucza szyfrowania.';
  }

  @override
  String get encryptionKey => 'Klucz szyfrowania';

  @override
  String get verify => 'Zweryfikuj';

  @override
  String get trustKey => 'Zaufaj kluczowi';

  @override
  String get trustNewKey => 'Zaufaj nowemu kluczowi';

  @override
  String get removeTrust => 'Usuń zaufanie';

  @override
  String get verifiedEncryptionKey => 'Zweryfikowany klucz szyfrowania';

  @override
  String get encryptionKeyChanged => 'Klucz szyfrowania się zmienił';

  @override
  String get noEncryptionKey => 'Brak klucza szyfrowania';

  @override
  String get verifyEncryptionKey => 'Zweryfikuj klucz szyfrowania';

  @override
  String get sendingBlockedKeyChanged =>
      'Wysyłanie jest zablokowane, dopóki ponownie nie zweryfikujesz tego kontaktu.';

  @override
  String get keyTrusted => 'Ten klucz jest zaufany na tym urządzeniu.';

  @override
  String get keyChangedWarning =>
      'Uwaga: ten klucz się zmienił. Porównaj odcisk przed ponownym zaufaniem.';

  @override
  String get keyMissing =>
      'Ten użytkownik nie opublikował jeszcze klucza szyfrowania.';

  @override
  String get keyUntrusted =>
      'Porównaj ten odcisk z drugą osobą, a potem zaufaj kluczowi.';

  @override
  String get noFingerprint => 'Brak odcisku';

  @override
  String get audioCall => 'Połączenie audio';

  @override
  String get videoCall => 'Połączenie wideo';

  @override
  String callFailed(String error) {
    return 'Połączenie nie powiodło się: $error';
  }

  @override
  String get anotherCallActive => 'Inne połączenie jest już aktywne';

  @override
  String get calling => 'Dzwonienie...';

  @override
  String get connected => 'Połączono';

  @override
  String get muteCall => 'Mikrofon wyłączony';

  @override
  String get unmuteCall => 'Mikrofon włączony';

  @override
  String get endCall => 'Zakończ';

  @override
  String get incomingCall => 'Połączenie przychodzące';

  @override
  String get voiceCall => 'Połączenie głosowe';

  @override
  String get pushSyncChannelDescription =>
      'Powiadomienia synchronizacji wiadomości i próśb Hestia.';

  @override
  String get pushCallChannelDescription =>
      'Alerty połączeń przychodzących Hestia.';

  @override
  String get newContactRequestNotification => 'Nowa prośba o kontakt';

  @override
  String get newMessageNotification => 'Nowa wiadomość';

  @override
  String get incomingVideoCallNotification => 'Przychodzące połączenie wideo';

  @override
  String get incomingVoiceCallNotification => 'Przychodzące połączenie głosowe';

  @override
  String get unknownCaller => 'Nieznany';

  @override
  String get rejectCall => 'Odrzuć';

  @override
  String get updateAvailable => 'Dostępna aktualizacja';

  @override
  String versionAvailable(String version) {
    return 'Dostępna jest wersja $version.';
  }

  @override
  String get startingDownload => 'Rozpoczynanie pobierania...';

  @override
  String downloadingProgress(String percent) {
    return 'Pobieranie... $percent%';
  }

  @override
  String get downloadFailedRetry =>
      'Pobieranie nie powiodło się. Spróbuj ponownie.';

  @override
  String get later => 'Później';

  @override
  String get downloading => 'Pobieranie...';

  @override
  String get updateViaAppStore => 'Aktualizuj przez App Store';

  @override
  String get downloadAndInstall => 'Pobierz i zainstaluj';

  @override
  String get openDownloadPage => 'Otwórz stronę pobierania';

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
  String get onboardingSkip => 'Pomiń';

  @override
  String get onboardingNext => 'Dalej';

  @override
  String get onboardingGetStarted => 'Zacznij';

  @override
  String get onboardingWelcomeTitle => 'Witamy w Hestia';

  @override
  String get onboardingWelcomeBody =>
      'Spokojny komunikator do prywatnych czatów, połączeń i plików.';

  @override
  String get onboardingPrivacyTitle => 'Prywatność od początku';

  @override
  String get onboardingPrivacyBody =>
      'Wiadomości używają kluczy szyfrowania. Czaty i pliki zostają lokalnie.';

  @override
  String get onboardingHowItWorksTitle => 'Prosty przepływ';

  @override
  String get onboardingHowItWorksBody =>
      'Wybierz serwer, dodaj kontakty i akceptuj prośby przed rozmową.';

  @override
  String get onboardingCallsFilesTitle => 'Połączenia i pliki';

  @override
  String get onboardingCallsFilesBody =>
      'Rozmawiaj głosowo i udostępniaj pliki w tej samej chronionej przestrzeni.';

  @override
  String get onboardingServerTitle => 'Wybierz serwer';

  @override
  String get onboardingServerBody =>
      'Użyj domyślnego serwera albo połącz Hestię z własnym serwerem.';

  @override
  String get onboardingDefaultServer => 'Serwer domyślny';

  @override
  String get onboardingCustomServer => 'Własny serwer';

  @override
  String get onboardingCustomServerBody =>
      'Dla wdrożeń self-hosted lub prywatnych.';

  @override
  String get onboardingGetStartedTitle => 'Gotowe do startu';

  @override
  String get onboardingGetStartedBody =>
      'Utwórz nowe konto albo zaloguj się na istniejące.';

  @override
  String get diagnostics => 'Diagnostyka';

  @override
  String get diagnosticMode => 'Tryb diagnostyczny';

  @override
  String get diagnosticModeDescription =>
      'Domyślnie wyłączony. Bez haseł, tokenów ani jawnej treści wiadomości.';

  @override
  String get testMicrophone => 'Przetestuj mikrofon';

  @override
  String get copyDiagnostics => 'Kopiuj diagnostykę';

  @override
  String get videoPreview => 'Podgląd wideo';

  @override
  String get switchCamera => 'Przełącz kamerę';

  @override
  String get cameraMicPermissionsRequired =>
      'Wymagane są uprawnienia do kamery i mikrofonu.';

  @override
  String get cameraPreviewTimedOut =>
      'Przekroczono czas oczekiwania na podgląd kamery.';

  @override
  String get cameraUnavailableCheckPermissions =>
      'Kamera jest niedostępna. Sprawdź uprawnienia kamery i mikrofonu.';

  @override
  String get noCameraVideoTrack => 'Nie utworzono ścieżki wideo z kamery.';

  @override
  String get micPermissionRequiredForCalls =>
      'Do połączeń wymagane jest uprawnienie do mikrofonu.';

  @override
  String get cameraPermissionRequiredForVideoCalls =>
      'Do wideorozmów wymagane jest uprawnienie do kamery.';

  @override
  String get noCameraFound => 'Nie znaleziono kamery.';
}
