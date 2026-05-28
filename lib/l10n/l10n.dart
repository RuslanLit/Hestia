import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  String localizedError(Object error) => l10n.localizeError(error);
}

extension HestiaErrorLocalizations on AppLocalizations {
  String get alwaysReachableTitle => _extra(
        uk: 'Завжди на звʼязку',
        ru: 'Всегда на связи',
        pl: 'Zawsze dostępna',
        es: 'Siempre disponible',
        cs: 'Vždy dostupná',
        de: 'Immer erreichbar',
        en: 'Always reachable',
      );
  String get alwaysReachablePrompt => _extra(
        uk: 'Дозвольте Hestia працювати у фоні для дзвінків і повідомлень.',
        ru: 'Разрешите Hestia работать в фоне для звонков и сообщений.',
        pl: 'Pozwól Hestii działać w tle dla połączeń i wiadomości.',
        es: 'Permite que Hestia se ejecute en segundo plano para llamadas y mensajes.',
        cs: 'Povolte Hestii běžet na pozadí kvůli hovorům a zprávám.',
        de: 'Erlaube Hestia, für Anrufe und Nachrichten im Hintergrund zu laufen.',
        en: 'Allow Hestia to run in background for calls/messages.',
      );
  String get notNow => _extra(
        uk: 'Не зараз',
        ru: 'Не сейчас',
        pl: 'Nie teraz',
        es: 'Ahora no',
        cs: 'Teď ne',
        de: 'Nicht jetzt',
        en: 'Not now',
      );
  String get allow => _extra(
        uk: 'Дозволити',
        ru: 'Разрешить',
        pl: 'Zezwól',
        es: 'Permitir',
        cs: 'Povolit',
        de: 'Erlauben',
        en: 'Allow',
      );
  String get callExpired => _extra(
        uk: 'Дзвінок минув.',
        ru: 'Время звонка истекло.',
        pl: 'Połączenie wygasło.',
        es: 'La llamada expiró.',
        cs: 'Hovor vypršel.',
        de: 'Der Anruf ist abgelaufen.',
        en: 'Call expired',
      );
  String get videoCallsDisabled => _extra(
        uk: 'Відеодзвінки вимкнено.',
        ru: 'Видеозвонки отключены.',
        pl: 'Połączenia wideo są wyłączone.',
        es: 'Las videollamadas están desactivadas.',
        cs: 'Videohovory jsou vypnuté.',
        de: 'Videoanrufe sind deaktiviert.',
        en: 'Video calls are disabled.',
      );
  String get microphoneUnavailableListenOnly => _extra(
        uk: 'Мікрофон недоступний. Можна лише дивитися або слухати.',
        ru: 'Микрофон недоступен. Можно только смотреть или слушать.',
        pl: 'Mikrofon jest niedostępny. Możesz tylko oglądać lub słuchać.',
        es: 'El micrófono no está disponible. Solo puedes ver o escuchar.',
        cs: 'Mikrofon není dostupný. Můžete pouze sledovat nebo poslouchat.',
        de: 'Mikrofon nicht verfügbar. Du kannst nur zusehen oder zuhören.',
        en: 'Microphone unavailable. You can watch/listen only.',
      );
  String get desktopVoiceSetupFailed => _extra(
        uk: 'Не вдалося налаштувати голосовий дзвінок на компʼютері.',
        ru: 'Не удалось настроить голосовой звонок на компьютере.',
        pl: 'Nie udało się skonfigurować połączenia głosowego na komputerze.',
        es: 'No se pudo configurar la llamada de voz en el escritorio.',
        cs: 'Nepodařilo se nastavit hlasový hovor na počítači.',
        de: 'Desktop-Sprachanruf konnte nicht eingerichtet werden.',
        en: 'Desktop voice call setup failed.',
      );
  String get desktopMicrophonePermission => _extra(
        uk: 'Мікрофон недоступний. Перевірте дозволи мікрофона на компʼютері.',
        ru: 'Микрофон недоступен. Проверьте разрешения микрофона на компьютере.',
        pl: 'Mikrofon jest niedostępny. Sprawdź uprawnienia mikrofonu na komputerze.',
        es: 'El micrófono no está disponible. Revisa los permisos del micrófono en el escritorio.',
        cs: 'Mikrofon není dostupný. Zkontrolujte oprávnění mikrofonu na počítači.',
        de: 'Mikrofon nicht verfügbar. Prüfe die Mikrofonberechtigungen auf dem Desktop.',
        en: 'Microphone unavailable. Check Desktop microphone permissions.',
      );
  String get desktopCameraUnavailable => _extra(
        uk: 'Не вдалося запустити камеру на компʼютері. Вона може бути зайнята або заблокована налаштуваннями приватності.',
        ru: 'Не удалось запустить камеру на компьютере. Она может быть занята или заблокирована настройками приватности.',
        pl: 'Nie udało się uruchomić kamery na komputerze. Może być zajęta albo zablokowana w ustawieniach prywatności.',
        es: 'No se pudo iniciar la cámara de escritorio. Puede estar ocupada o bloqueada por la configuración de privacidad.',
        cs: 'Nepodařilo se spustit kameru na počítači. Může být obsazená nebo blokovaná nastavením soukromí.',
        de: 'Desktop-Kamera konnte nicht gestartet werden. Sie ist möglicherweise belegt oder durch Datenschutzeinstellungen blockiert.',
        en: 'Could not start Desktop camera. It may be busy or blocked by privacy settings.',
      );
  String get androidCameraMicPermission => _extra(
        uk: 'Не вдалося запустити камеру або мікрофон. Перевірте дозволи камери й мікрофона в Android.',
        ru: 'Не удалось запустить камеру или микрофон. Проверьте разрешения камеры и микрофона в Android.',
        pl: 'Nie udało się uruchomić kamery lub mikrofonu. Sprawdź uprawnienia kamery i mikrofonu w Androidzie.',
        es: 'No se pudo iniciar la cámara o el micrófono. Revisa los permisos de cámara y micrófono en Android.',
        cs: 'Nepodařilo se spustit kameru nebo mikrofon. Zkontrolujte oprávnění kamery a mikrofonu v Androidu.',
        de: 'Kamera oder Mikrofon konnte nicht gestartet werden. Prüfe die Android-Berechtigungen für Kamera und Mikrofon.',
        en: 'Could not start camera or microphone. Check Android camera and microphone permissions.',
      );
  String get androidMicrophonePermissionDisabled => _extra(
        uk: 'Дозвіл на мікрофон вимкнено. Увімкніть доступ до мікрофона в налаштуваннях Android.',
        ru: 'Разрешение на микрофон отключено. Включите доступ к микрофону в настройках Android.',
        pl: 'Uprawnienie mikrofonu jest wyłączone. Włącz dostęp do mikrofonu w ustawieniach Androida.',
        es: 'El permiso de micrófono está desactivado. Activa el acceso al micrófono en los ajustes de Android.',
        cs: 'Oprávnění mikrofonu je vypnuté. Povolte přístup k mikrofonu v nastavení Androidu.',
        de: 'Mikrofonberechtigung ist deaktiviert. Aktiviere den Mikrofonzugriff in den Android-Einstellungen.',
        en: 'Microphone permission is disabled. Enable microphone access in Android settings.',
      );
  String get androidCameraPermissionDisabled => _extra(
        uk: 'Дозвіл на камеру вимкнено. Увімкніть доступ до камери в налаштуваннях Android.',
        ru: 'Разрешение на камеру отключено. Включите доступ к камере в настройках Android.',
        pl: 'Uprawnienie kamery jest wyłączone. Włącz dostęp do kamery w ustawieniach Androida.',
        es: 'El permiso de cámara está desactivado. Activa el acceso a la cámara en los ajustes de Android.',
        cs: 'Oprávnění kamery je vypnuté. Povolte přístup ke kameře v nastavení Androidu.',
        de: 'Kameraberechtigung ist deaktiviert. Aktiviere den Kamerazugriff in den Android-Einstellungen.',
        en: 'Camera permission is disabled. Enable camera access in Android settings.',
      );
  String get fileAttachmentsDisabled => _extra(
        uk: 'Файлові вкладення вимкнено в цій версії.',
        ru: 'Файловые вложения отключены в этой версии.',
        pl: 'Załączniki plików są wyłączone w tej wersji.',
        es: 'Los archivos adjuntos están desactivados en esta versión.',
        cs: 'Přílohy souborů jsou v této verzi vypnuté.',
        de: 'Dateianhänge sind in dieser Version deaktiviert.',
        en: 'File attachments are disabled in this version.',
      );
  String get fileForwardingDisabled => _extra(
        uk: 'Пересилання файлових вкладень вимкнено в цій версії.',
        ru: 'Пересылка файловых вложений отключена в этой версии.',
        pl: 'Przekazywanie załączników plików jest wyłączone w tej wersji.',
        es: 'El reenvío de archivos adjuntos está desactivado en esta versión.',
        cs: 'Přeposílání souborových příloh je v této verzi vypnuté.',
        de: 'Weiterleiten von Dateianhängen ist in dieser Version deaktiviert.',
        en: 'Forwarding file attachments is disabled in this version.',
      );
  String get previewUnavailable => _extra(
        uk: 'Попередній перегляд недоступний.',
        ru: 'Предпросмотр недоступен.',
        pl: 'Podgląd jest niedostępny.',
        es: 'La vista previa no está disponible.',
        cs: 'Náhled není dostupný.',
        de: 'Vorschau nicht verfügbar.',
        en: 'Preview unavailable.',
      );
  String get cameraOn => _extra(
        uk: 'Камера увімкнена',
        ru: 'Камера включена',
        pl: 'Kamera włączona',
        es: 'Cámara activada',
        cs: 'Kamera zapnuta',
        de: 'Kamera an',
        en: 'Camera on',
      );
  String get cameraOff => _extra(
        uk: 'Камера вимкнена',
        ru: 'Камера выключена',
        pl: 'Kamera wyłączona',
        es: 'Cámara desactivada',
        cs: 'Kamera vypnuta',
        de: 'Kamera aus',
        en: 'Camera off',
      );
  String get cameraUnavailableAudioFallback => _extra(
        uk: 'Камера недоступна. Продовжуємо з аудіо.',
        ru: 'Камера недоступна. Продолжаем с аудио.',
        pl: 'Kamera jest niedostępna. Kontynuuję z audio.',
        es: 'La cámara no está disponible. Continuando con audio.',
        cs: 'Kamera není dostupná. Pokračuje se zvukem.',
        de: 'Kamera nicht verfügbar. Weiter mit Audio.',
        en: 'Camera unavailable. Continuing with audio.',
      );
  String cannotEncryptFor(String name) => _extra(
        uk: 'Не вдалося зашифрувати для $name: ключа шифрування ще немає.',
        ru: 'Не удалось зашифровать для $name: ключа шифрования пока нет.',
        pl: 'Nie można zaszyfrować dla $name: nie ma jeszcze klucza szyfrowania.',
        es: 'No se puede cifrar para $name: aún no hay clave de cifrado.',
        cs: 'Nelze šifrovat pro $name: zatím chybí šifrovací klíč.',
        de: 'Verschlüsselung für $name nicht möglich: Es gibt noch keinen Verschlüsselungsschlüssel.',
        en: 'Cannot encrypt for $name: no encryption key yet.',
      );
  String peerKeyChangedSending(String name) => _extra(
        uk: 'Ключ шифрування $name змінився. Перевірте відбиток перед надсиланням.',
        ru: 'Ключ шифрования $name изменился. Проверьте отпечаток перед отправкой.',
        pl: 'Klucz szyfrowania użytkownika $name zmienił się. Sprawdź odcisk przed wysłaniem.',
        es: 'La clave de cifrado de $name cambió. Verifica la huella antes de enviar.',
        cs: 'Šifrovací klíč uživatele $name se změnil. Před odesláním ověřte otisk.',
        de: 'Der Verschlüsselungsschlüssel von $name hat sich geändert. Prüfe den Fingerabdruck vor dem Senden.',
        en: '$name encryption key changed. Verify the fingerprint before sending.',
      );
  String get androidStoppedBackgroundService => _extra(
        uk: 'Android зупинив фонову службу. Дзвінки й повідомлення можуть не надходити, доки Hestia не буде відкрита знову.',
        ru: 'Android остановил фоновую службу. Звонки и сообщения могут не приходить, пока Hestia не будет открыта снова.',
        pl: 'Android zatrzymał usługę w tle. Połączenia i wiadomości mogą nie docierać, dopóki Hestia nie zostanie ponownie otwarta.',
        es: 'Android detuvo el servicio en segundo plano. Es posible que las llamadas y mensajes no lleguen hasta que vuelvas a abrir Hestia.',
        cs: 'Android zastavil službu na pozadí. Hovory a zprávy nemusí dorazit, dokud Hestii znovu neotevřete.',
        de: 'Android hat den Hintergrunddienst beendet. Anrufe und Nachrichten kommen möglicherweise erst wieder an, wenn Hestia geöffnet wird.',
        en: 'Android stopped background service. Calls/messages may not arrive until Hestia is opened again.',
      );
  String get userUnavailable => _extra(
        uk: 'Користувач недоступний.',
        ru: 'Пользователь недоступен.',
        pl: 'Użytkownik jest niedostępny.',
        es: 'El usuario no está disponible.',
        cs: 'Uživatel není dostupný.',
        de: 'Benutzer ist nicht verfügbar.',
        en: 'User is unavailable.',
      );
  String get callRejected => _extra(
        uk: 'Дзвінок відхилено.',
        ru: 'Звонок отклонён.',
        pl: 'Połączenie zostało odrzucone.',
        es: 'La llamada fue rechazada.',
        cs: 'Hovor byl odmítnut.',
        de: 'Anruf wurde abgelehnt.',
        en: 'Call was rejected.',
      );
  String get finishingPreviousCall => _extra(
        uk: 'Завершення попереднього дзвінка...',
        ru: 'Завершение предыдущего звонка...',
        pl: 'Kończenie poprzedniego połączenia...',
        es: 'Finalizando la llamada anterior...',
        cs: 'Ukončování předchozího hovoru...',
        de: 'Vorheriger Anruf wird beendet...',
        en: 'Finishing previous call...',
      );
  String get desktopVideoExperimental => _extra(
        uk: 'Надсилання відео на компʼютері є експериментальним',
        ru: 'Передача видео на компьютере является экспериментальной',
        pl: 'Wysyłanie wideo na komputerze jest eksperymentalne',
        es: 'El envío de vídeo en escritorio es experimental',
        cs: 'Odesílání videa na počítači je experimentální',
        de: 'Das Senden von Desktop-Video ist experimentell',
        en: 'Desktop video sending is experimental',
      );
  String get callEventOutgoingVoice => _extra(
        uk: 'Вихідний голосовий дзвінок',
        ru: 'Исходящий голосовой звонок',
        pl: 'Wychodzące połączenie głosowe',
        es: 'Llamada de voz saliente',
        cs: 'Odchozí hlasový hovor',
        de: 'Ausgehender Sprachanruf',
        en: 'Outgoing voice call',
      );
  String get callEventIncomingVoice => _extra(
        uk: 'Вхідний голосовий дзвінок',
        ru: 'Входящий голосовой звонок',
        pl: 'Przychodzące połączenie głosowe',
        es: 'Llamada de voz entrante',
        cs: 'Příchozí hlasový hovor',
        de: 'Eingehender Sprachanruf',
        en: 'Incoming voice call',
      );
  String get callEventMissedVoice => _extra(
        uk: 'Пропущений голосовий дзвінок',
        ru: 'Пропущенный голосовой звонок',
        pl: 'Nieodebrane połączenie głosowe',
        es: 'Llamada de voz perdida',
        cs: 'Zmeškaný hlasový hovor',
        de: 'Verpasster Sprachanruf',
        en: 'Missed voice call',
      );
  String get callEventRejectedVoice => _extra(
        uk: 'Відхилений голосовий дзвінок',
        ru: 'Отклонённый голосовой звонок',
        pl: 'Odrzucone połączenie głosowe',
        es: 'Llamada de voz rechazada',
        cs: 'Odmítnutý hlasový hovor',
        de: 'Abgelehnter Sprachanruf',
        en: 'Rejected voice call',
      );
  String get callEventCanceledVoice => _extra(
        uk: 'Скасований голосовий дзвінок',
        ru: 'Отменённый голосовой звонок',
        pl: 'Anulowane połączenie głosowe',
        es: 'Llamada de voz cancelada',
        cs: 'Zrušený hlasový hovor',
        de: 'Abgebrochener Sprachanruf',
        en: 'Canceled voice call',
      );
  String get callEventMissedVideo => _extra(
        uk: 'Пропущений відеодзвінок',
        ru: 'Пропущенный видеозвонок',
        pl: 'Nieodebrane połączenie wideo',
        es: 'Videollamada perdida',
        cs: 'Zmeškaný videohovor',
        de: 'Verpasster Videoanruf',
        en: 'Missed video call',
      );
  String get callEventRejectedVideo => _extra(
        uk: 'Відхилений відеодзвінок',
        ru: 'Отклонённый видеозвонок',
        pl: 'Odrzucone połączenie wideo',
        es: 'Videollamada rechazada',
        cs: 'Odmítnutý videohovor',
        de: 'Abgelehnter Videoanruf',
        en: 'Rejected video call',
      );
  String get callEventCanceledVideo => _extra(
        uk: 'Скасований відеодзвінок',
        ru: 'Отменённый видеозвонок',
        pl: 'Anulowane połączenie wideo',
        es: 'Videollamada cancelada',
        cs: 'Zrušený videohovor',
        de: 'Abgebrochener Videoanruf',
        en: 'Canceled video call',
      );
  String get callEventVoice => _extra(
        uk: 'Голосовий дзвінок',
        ru: 'Голосовой звонок',
        pl: 'Połączenie głosowe',
        es: 'Llamada de voz',
        cs: 'Hlasový hovor',
        de: 'Sprachanruf',
        en: 'Voice call',
      );
  String get callEventDuration => _extra(
        uk: 'Тривалість',
        ru: 'Длительность',
        pl: 'Czas trwania',
        es: 'Duración',
        cs: 'Délka',
        de: 'Dauer',
        en: 'Duration',
      );
  String get callEventFailed => _extra(
        uk: 'Дзвінок не вдався',
        ru: 'Звонок не удался',
        pl: 'Połączenie nie powiodło się',
        es: 'La llamada falló',
        cs: 'Hovor selhal',
        de: 'Anruf fehlgeschlagen',
        en: 'Call failed',
      );
  String get callProgressWaitingForAnswer => _extra(
        uk: 'Очікування відповіді',
        ru: 'Ожидание ответа',
        pl: 'Oczekiwanie na odpowiedź',
        es: 'Esperando respuesta',
        cs: 'Čekání na odpověď',
        de: 'Warten auf Antwort',
        en: 'Waiting for answer',
      );
  String get callProgressConnecting => _extra(
        uk: 'Підключення...',
        ru: 'Подключение...',
        pl: 'Łączenie...',
        es: 'Conectando...',
        cs: 'Připojování...',
        de: 'Verbindung wird hergestellt...',
        en: 'Connecting...',
      );
  String get callProgressInCall => _extra(
        uk: 'Розмова триває',
        ru: 'Звонок активен',
        pl: 'Rozmowa trwa',
        es: 'En llamada',
        cs: 'Probíhá hovor',
        de: 'Im Anruf',
        en: 'In call',
      );
  String get callProgressEnded => _extra(
        uk: 'Дзвінок завершено',
        ru: 'Звонок завершён',
        pl: 'Połączenie zakończone',
        es: 'Llamada finalizada',
        cs: 'Hovor skončil',
        de: 'Anruf beendet',
        en: 'Call ended',
      );
  String get callProgressNetworkFailed => _extra(
        uk: 'Дзвінок не вдався через мережу',
        ru: 'Звонок не удался из-за сети',
        pl: 'Połączenie nie powiodło się z powodu sieci',
        es: 'La llamada falló por la red',
        cs: 'Hovor selhal kvůli síti',
        de: 'Anruf wegen Netzwerk fehlgeschlagen',
        en: 'Call failed because of the network',
      );
  String get sessionRevoked => _extra(
        uk: 'Цю сесію відкликано.',
        ru: 'Эта сессия была отозвана.',
        pl: 'Ta sesja została odwołana.',
        es: 'Esta sesión fue revocada.',
        cs: 'Tato relace byla odvolána.',
        de: 'Diese Sitzung wurde widerrufen.',
        en: 'This session was revoked.',
      );
  String get logout => _extra(
        uk: 'Вийти',
        ru: 'Выйти',
        pl: 'Wyloguj',
        es: 'Cerrar sesión',
        cs: 'Odhlásit se',
        de: 'Abmelden',
        en: 'Log out',
      );
  String get logoutConfirmTitle => _extra(
        uk: 'Вийти з акаунта?',
        ru: 'Выйти из аккаунта?',
        pl: 'Wylogować z konta?',
        es: '¿Cerrar sesión de la cuenta?',
        cs: 'Odhlásit se z účtu?',
        de: 'Vom Konto abmelden?',
        en: 'Log out of account?',
      );
  String get logoutAccount => _extra(
        uk: 'Вийти з акаунта',
        ru: 'Выйти из аккаунта',
        pl: 'Wyloguj z konta',
        es: 'Cerrar sesión de la cuenta',
        cs: 'Odhlásit se z účtu',
        de: 'Vom Konto abmelden',
        en: 'Log out of account',
      );
  String get currentDeviceBadge => _extra(
        uk: 'Поточний пристрій',
        ru: 'Текущее устройство',
        pl: 'Bieżące urządzenie',
        es: 'Dispositivo actual',
        cs: 'Aktuální zařízení',
        de: 'Aktuelles Gerät',
        en: 'Current device',
      );
  String get deviceManagementLater => _extra(
        uk: 'Керування пристроями буде доступне пізніше.',
        ru: 'Управление устройствами будет доступно позже.',
        pl: 'Zarządzanie urządzeniami będzie dostępne później.',
        es: 'La gestión de dispositivos estará disponible más tarde.',
        cs: 'Správa zařízení bude dostupná později.',
        de: 'Geräteverwaltung wird später verfügbar sein.',
        en: 'Device management will be available later.',
      );
  String get serverConnecting => _extra(
        uk: 'Підключення...',
        ru: 'Подключение...',
        pl: 'Łączenie...',
        es: 'Conectando...',
        cs: 'Připojování...',
        de: 'Verbindung wird hergestellt...',
        en: 'Connecting...',
      );
  String get serverAuthorizationError => _extra(
        uk: 'Помилка авторизації',
        ru: 'Ошибка авторизации',
        pl: 'Błąd autoryzacji',
        es: 'Error de autorización',
        cs: 'Chyba autorizace',
        de: 'Autorisierungsfehler',
        en: 'Authorization error',
      );
  String get serverError => _extra(
        uk: 'Помилка сервера',
        ru: 'Ошибка сервера',
        pl: 'Błąd serwera',
        es: 'Error del servidor',
        cs: 'Chyba serveru',
        de: 'Serverfehler',
        en: 'Server error',
      );
  String couldNotConnectTo(String host) => _extra(
        uk: 'Не вдалося підключитися до $host',
        ru: 'Не удалось подключиться к $host',
        pl: 'Nie udało się połączyć z $host',
        es: 'No se pudo conectar con $host',
        cs: 'Nepodařilo se připojit k $host',
        de: 'Verbindung zu $host nicht möglich',
        en: 'Could not connect to $host',
      );
  String get unknownServerError => _extra(
        uk: 'Невідома помилка сервера',
        ru: 'Неизвестная ошибка сервера',
        pl: 'Nieznany błąd serwera',
        es: 'Error desconocido del servidor',
        cs: 'Neznámá chyba serveru',
        de: 'Unbekannter Serverfehler',
        en: 'Unknown server error',
      );
  String get authenticationRequired => _extra(
        uk: 'Потрібна автентифікація.',
        ru: 'Требуется аутентификация.',
        pl: 'Wymagane uwierzytelnienie.',
        es: 'Se requiere autenticación.',
        cs: 'Je vyžadováno ověření.',
        de: 'Authentifizierung erforderlich.',
        en: 'Authentication required.',
      );
  String get localFileNotFound => _extra(
        uk: 'Локальний файл не знайдено.',
        ru: 'Локальный файл не найден.',
        pl: 'Nie znaleziono lokalnego pliku.',
        es: 'No se encontró el archivo local.',
        cs: 'Místní soubor nebyl nalezen.',
        de: 'Lokale Datei nicht gefunden.',
        en: 'Local file not found.',
      );
  String get unsupportedImageFormat => _extra(
        uk: 'Непідтримуваний формат зображення.',
        ru: 'Неподдерживаемый формат изображения.',
        pl: 'Nieobsługiwany format obrazu.',
        es: 'Formato de imagen no compatible.',
        cs: 'Nepodporovaný formát obrázku.',
        de: 'Nicht unterstütztes Bildformat.',
        en: 'Unsupported image format.',
      );
  String get imageTooLarge => _extra(
        uk: 'Зображення завелике.',
        ru: 'Изображение слишком большое.',
        pl: 'Obraz jest za duży.',
        es: 'La imagen es demasiado grande.',
        cs: 'Obrázek je příliš velký.',
        de: 'Das Bild ist zu groß.',
        en: 'Image is too large.',
      );
  String get backupProfileUnavailable => _extra(
        uk: 'Немає профілю для експорту.',
        ru: 'Нет профиля для экспорта.',
        pl: 'Brak profilu do wyeksportowania.',
        es: 'No hay perfil disponible para exportar.',
        cs: 'Pro export není dostupný žádný profil.',
        de: 'Kein Profil zum Exportieren verfügbar.',
        en: 'No profile is available to export.',
      );
  String get backupFileNotSelected => _extra(
        uk: 'Файл резервної копії не вибрано.',
        ru: 'Файл резервной копии не выбран.',
        pl: 'Nie wybrano pliku kopii zapasowej.',
        es: 'No se seleccionó ningún archivo de copia de seguridad.',
        cs: 'Nebyl vybrán soubor zálohy.',
        de: 'Keine Sicherungsdatei ausgewählt.',
        en: 'No backup file selected.',
      );
  String get backupReadFailed => _extra(
        uk: 'Не вдалося прочитати файл резервної копії.',
        ru: 'Не удалось прочитать файл резервной копии.',
        pl: 'Nie udało się odczytać pliku kopii zapasowej.',
        es: 'No se pudo leer el archivo de copia de seguridad.',
        cs: 'Soubor zálohy se nepodařilo přečíst.',
        de: 'Sicherungsdatei konnte nicht gelesen werden.',
        en: 'Could not read backup file.',
      );
  String get backupFormatUnsupported => _extra(
        uk: 'Непідтримуваний формат резервної копії.',
        ru: 'Неподдерживаемый формат резервной копии.',
        pl: 'Nieobsługiwany format kopii zapasowej.',
        es: 'Formato de copia de seguridad no compatible.',
        cs: 'Nepodporovaný formát zálohy.',
        de: 'Nicht unterstütztes Sicherungsformat.',
        en: 'Unsupported backup format.',
      );
  String get backupPasswordWrongOrCorrupted => _extra(
        uk: 'Пароль резервної копії неправильний або файл пошкоджено.',
        ru: 'Пароль резервной копии неверен или файл повреждён.',
        pl: 'Hasło kopii zapasowej jest nieprawidłowe lub plik jest uszkodzony.',
        es: 'La contraseña es incorrecta o el archivo está dañado.',
        cs: 'Heslo zálohy je nesprávné nebo je soubor poškozen.',
        de: 'Das Sicherungspasswort ist falsch oder die Datei ist beschädigt.',
        en: 'Backup password is wrong or file is corrupted.',
      );
  String get backupPasswordMinimum => _extra(
        uk: 'Пароль резервної копії має містити щонайменше 8 символів.',
        ru: 'Пароль резервной копии должен содержать не менее 8 символов.',
        pl: 'Hasło kopii zapasowej musi mieć co najmniej 8 znaków.',
        es: 'La contraseña de copia de seguridad debe tener al menos 8 caracteres.',
        cs: 'Heslo zálohy musí mít alespoň 8 znaků.',
        de: 'Das Sicherungspasswort muss mindestens 8 Zeichen lang sein.',
        en: 'Backup password must be at least 8 characters.',
      );
  String get exportBackupDialogTitle => _extra(
        uk: 'Експорт резервної копії Hestia',
        ru: 'Экспорт резервной копии Hestia',
        pl: 'Eksport kopii zapasowej Hestia',
        es: 'Exportar copia de seguridad de Hestia',
        cs: 'Export zálohy Hestia',
        de: 'Hestia-Sicherung exportieren',
        en: 'Export Hestia backup',
      );
  String get encryptionIdentityUnavailable => _extra(
        uk: 'Ключі шифрування недоступні.',
        ru: 'Ключи шифрования недоступны.',
        pl: 'Klucze szyfrowania są niedostępne.',
        es: 'Las claves de cifrado no están disponibles.',
        cs: 'Šifrovací klíče nejsou dostupné.',
        de: 'Verschlüsselungsschlüssel sind nicht verfügbar.',
        en: 'Encryption identity is not available.',
      );
  String get invalidBackupEncryptionIdentity => _extra(
        uk: 'Резервна копія не містить коректних ключів шифрування.',
        ru: 'Резервная копия не содержит корректных ключей шифрования.',
        pl: 'Kopia zapasowa nie zawiera prawidłowych kluczy szyfrowania.',
        es: 'La copia de seguridad no contiene claves de cifrado válidas.',
        cs: 'Záloha neobsahuje platné šifrovací klíče.',
        de: 'Die Sicherung enthält keine gültigen Verschlüsselungsschlüssel.',
        en: 'Backup does not contain a valid encryption identity.',
      );
  String get invalidEncryptionKey => _extra(
        uk: 'Некоректний ключ шифрування.',
        ru: 'Некорректный ключ шифрования.',
        pl: 'Nieprawidłowy klucz szyfrowania.',
        es: 'Clave de cifrado no válida.',
        cs: 'Neplatný šifrovací klíč.',
        de: 'Ungültiger Verschlüsselungsschlüssel.',
        en: 'Invalid encryption key.',
      );
  String get encryptedPayloadVerificationFailed => _extra(
        uk: 'Не вдалося перевірити зашифровані дані.',
        ru: 'Не удалось проверить зашифрованные данные.',
        pl: 'Nie udało się zweryfikować zaszyfrowanych danych.',
        es: 'No se pudieron verificar los datos cifrados.',
        cs: 'Šifrovaná data se nepodařilo ověřit.',
        de: 'Verschlüsselte Daten konnten nicht geprüft werden.',
        en: 'Encrypted data verification failed.',
      );
  String get webAttachmentAvailable => _extra(
        uk: 'Файл доступний у поточній сесії браузера.',
        ru: 'Файл доступен в текущей сессии браузера.',
        pl: 'Plik jest dostępny w bieżącej sesji przeglądarki.',
        es: 'El archivo está disponible en esta sesión del navegador.',
        cs: 'Soubor je dostupný v aktuální relaci prohlížeče.',
        de: 'Die Datei ist in dieser Browser-Sitzung verfügbar.',
        en: 'The file is available in this browser session.',
      );
  String get webAttachmentUnavailable => _extra(
        uk: 'Файл недоступний після перезапуску браузера.',
        ru: 'Файл недоступен после перезапуска браузера.',
        pl: 'Plik jest niedostępny po ponownym uruchomieniu przeglądarki.',
        es: 'El archivo no está disponible después de reiniciar el navegador.',
        cs: 'Soubor po restartu prohlížeče není dostupný.',
        de: 'Die Datei ist nach einem Neustart des Browsers nicht verfügbar.',
        en: 'The file is unavailable after restarting the browser.',
      );
  String get attachmentTypeNotAllowed => _extra(
        uk: 'Цей тип вкладення не дозволено.',
        ru: 'Этот тип вложения не разрешён.',
        pl: 'Ten typ załącznika jest niedozwolony.',
        es: 'Este tipo de adjunto no está permitido.',
        cs: 'Tento typ přílohy není povolen.',
        de: 'Dieser Anhangstyp ist nicht erlaubt.',
        en: 'This attachment type is not allowed.',
      );
  String get attachmentTypeBlockedForSafety => _extra(
        uk: 'Цей тип файлу заблоковано з міркувань безпеки.',
        ru: 'Этот тип файла заблокирован из соображений безопасности.',
        pl: 'Ten typ pliku jest zablokowany ze względów bezpieczeństwa.',
        es: 'Este tipo de archivo está bloqueado por seguridad.',
        cs: 'Tento typ souboru je z bezpečnostních důvodů blokován.',
        de: 'Dieser Dateityp ist aus Sicherheitsgründen blockiert.',
        en: 'This file type is blocked for safety.',
      );
  String get attachmentValidationFailed => _extra(
        uk: 'Не вдалося перевірити вкладення.',
        ru: 'Не удалось проверить вложение.',
        pl: 'Nie udało się sprawdzić załącznika.',
        es: 'No se pudo validar el adjunto.',
        cs: 'Přílohu se nepodařilo ověřit.',
        de: 'Anhang konnte nicht geprüft werden.',
        en: 'Attachment validation failed.',
      );
  String get attachmentTooLarge => _extra(
        uk: 'Вкладення завелике.',
        ru: 'Вложение слишком большое.',
        pl: 'Załącznik jest za duży.',
        es: 'El adjunto es demasiado grande.',
        cs: 'Příloha je příliš velká.',
        de: 'Der Anhang ist zu groß.',
        en: 'Attachment is too large.',
      );
  String get attachmentLimits => _extra(
        uk: 'Дозволені документи, зображення, аудіо та відео. Ліміти: документи/зображення 50 МБ, аудіо 100 МБ, відео 250 МБ. Один файл на повідомлення.',
        ru: 'Разрешены документы, изображения, аудио и видео. Лимиты: документы/изображения 50 МБ, аудио 100 МБ, видео 250 МБ. Один файл на сообщение.',
        pl: 'Dozwolone pliki: dokumenty, obrazy, audio i wideo. Limity: obrazy 25 MB, audio/dokumenty 50 MB, wideo 200 MB.',
        es: 'Archivos permitidos: documentos, imágenes, audio y vídeo. Límites: imágenes 25 MB, audio/documentos 50 MB, vídeo 200 MB.',
        cs: 'Povolené soubory: dokumenty, obrázky, audio a video. Limity: obrázky 25 MB, audio/dokumenty 50 MB, video 200 MB.',
        de: 'Erlaubte Dateien: Dokumente, Bilder, Audio und Video. Limits: Bilder 25 MB, Audio/Dokumente 50 MB, Video 200 MB.',
        en: 'Documents, images, audio and video are allowed. Limits: documents/images 50 MB, audio 100 MB, video 250 MB. One file per message.',
      );
  String get blockedUsers => _extra(
        uk: 'Заблоковані користувачі',
        ru: 'Заблокированные пользователи',
        pl: 'Zablokowani użytkownicy',
        es: 'Usuarios bloqueados',
        cs: 'Blokovaní uživatelé',
        de: 'Blockierte Benutzer',
        en: 'Blocked users',
      );
  String get unblock => _extra(
        uk: 'Розблокувати',
        ru: 'Разблокировать',
        pl: 'Odblokuj',
        es: 'Desbloquear',
        cs: 'Odblokovat',
        de: 'Entsperren',
        en: 'Unblock',
      );
  String get noBlockedUsers => _extra(
        uk: 'Заблокованих користувачів немає',
        ru: 'Нет заблокированных пользователей',
        pl: 'Brak zablokowanych użytkowników',
        es: 'No hay usuarios bloqueados',
        cs: 'Žádní blokovaní uživatelé',
        de: 'Keine blockierten Benutzer',
        en: 'No blocked users',
      );
  String get attachmentUploading => _extra(
        uk: 'Завантажується',
        ru: 'Загружается',
        pl: 'Przesyłanie',
        es: 'Subiendo',
        cs: 'Nahrává se',
        de: 'Wird hochgeladen',
        en: 'Uploading',
      );
  String get attachmentPreparing => _extra(
        uk: 'Підготовка',
        ru: 'Подготовка',
        pl: 'Przygotowywanie',
        es: 'Preparando',
        cs: 'Příprava',
        de: 'Vorbereitung',
        en: 'Preparing',
      );
  String get attachmentEncrypting => _extra(
        uk: 'Шифрування',
        ru: 'Шифрование',
        pl: 'Szyfrowanie',
        es: 'Cifrando',
        cs: 'Šifrování',
        de: 'Verschlüsselung',
        en: 'Encrypting',
      );
  String get attachmentDownloading => _extra(
        uk: 'Завантаження',
        ru: 'Загрузка',
        pl: 'Pobieranie',
        es: 'Descargando',
        cs: 'Stahování',
        de: 'Download',
        en: 'Downloading',
      );
  String get attachmentDecrypting => _extra(
        uk: 'Розшифрування',
        ru: 'Расшифровка',
        pl: 'Odszyfrowywanie',
        es: 'Descifrando',
        cs: 'Dešifrování',
        de: 'Entschlüsselung',
        en: 'Decrypting',
      );
  String get attachmentSaving => _extra(
        uk: 'Збереження',
        ru: 'Сохранение',
        pl: 'Zapisywanie',
        es: 'Guardando',
        cs: 'Ukládání',
        de: 'Speichern',
        en: 'Saving',
      );
  String get attachmentWorking => _extra(
        uk: 'Обробка...',
        ru: 'Обработка...',
        pl: 'Przetwarzanie...',
        es: 'Procesando...',
        cs: 'Zpracování...',
        de: 'Verarbeitung...',
        en: 'Working...',
      );
  String get attachmentSent => _extra(
        uk: 'Надіслано',
        ru: 'Отправлено',
        pl: 'Wysłano',
        es: 'Enviado',
        cs: 'Odesláno',
        de: 'Gesendet',
        en: 'Sent',
      );
  String get attachmentReceived => _extra(
        uk: 'Отримано',
        ru: 'Получено',
        pl: 'Odebrano',
        es: 'Recibido',
        cs: 'Přijato',
        de: 'Empfangen',
        en: 'Received',
      );
  String get attachmentFailed => _extra(
        uk: 'Помилка',
        ru: 'Ошибка',
        pl: 'Błąd',
        es: 'Error',
        cs: 'Chyba',
        de: 'Fehler',
        en: 'Failed',
      );
  String get selectedFileReadFailed => _extra(
        uk: 'Не вдалося прочитати вибраний файл.',
        ru: 'Не удалось прочитать выбранный файл.',
        pl: 'Nie udało się odczytać wybranego pliku.',
        es: 'No se pudo leer el archivo seleccionado.',
        cs: 'Vybraný soubor se nepodařilo přečíst.',
        de: 'Die ausgewählte Datei konnte nicht gelesen werden.',
        en: 'Could not read the selected file.',
      );
  String get selectedFileNotFound => _extra(
        uk: 'Файл не знайдено на пристрої.',
        ru: 'Файл не найден на устройстве.',
        pl: 'Nie znaleziono pliku na urządzeniu.',
        es: 'No se encontró el archivo en el dispositivo.',
        cs: 'Soubor nebyl v zařízení nalezen.',
        de: 'Datei wurde auf dem Gerät nicht gefunden.',
        en: 'File was not found on device.',
      );
  String get selectedFileAccessDenied => _extra(
        uk: 'Немає доступу до вибраного файлу.',
        ru: 'Нет доступа к выбранному файлу.',
        pl: 'Brak dostępu do wybranego pliku.',
        es: 'No se pudo acceder al archivo seleccionado.',
        cs: 'K vybranému souboru není přístup.',
        de: 'Kein Zugriff auf die ausgewählte Datei.',
        en: 'Could not access the selected file.',
      );
  String get forwardLocalFileUnavailable => _extra(
        uk: 'Не вдалося переслати: локальний файл недоступний.',
        ru: 'Не удалось переслать: локальный файл недоступен.',
        pl: 'Nie udało się przekazać: lokalny plik jest niedostępny.',
        es: 'No se pudo reenviar: el archivo local no está disponible.',
        cs: 'Přeposlání selhalo: místní soubor není dostupný.',
        de: 'Weiterleiten fehlgeschlagen: Die lokale Datei ist nicht verfügbar.',
        en: 'Forward failed: the local file is unavailable.',
      );
  String get attachmentUploadFailed => _extra(
        uk: 'Не вдалося завантажити вкладення.',
        ru: 'Не удалось загрузить вложение.',
        pl: 'Nie udało się przesłać załącznika.',
        es: 'No se pudo subir el adjunto.',
        cs: 'Přílohu se nepodařilo nahrát.',
        de: 'Anhang konnte nicht hochgeladen werden.',
        en: 'Attachment upload failed.',
      );
  String get uploadEndpointUnavailable => _extra(
        uk: 'Серверний endpoint для файлів недоступний.',
        ru: 'Серверный endpoint для файлов недоступен.',
        pl: 'Endpoint przesyłania plików jest niedostępny.',
        es: 'El endpoint de subida de archivos no está disponible.',
        cs: 'Endpoint pro nahrávání souborů není dostupný.',
        de: 'Der Upload-Endpunkt ist nicht verfügbar.',
        en: 'Upload endpoint unavailable.',
      );
  String get invalidUploadResponse => _extra(
        uk: 'Сервер повернув некоректну відповідь на завантаження.',
        ru: 'Сервер вернул некорректный ответ на загрузку.',
        pl: 'Serwer zwrócił nieprawidłową odpowiedź przesyłania.',
        es: 'El servidor devolvió una respuesta de subida no válida.',
        cs: 'Server vrátil neplatnou odpověď na nahrávání.',
        de: 'Der Server hat eine ungültige Upload-Antwort gesendet.',
        en: 'Invalid upload response.',
      );
  String get noServerConnection => _extra(
        uk: 'Немає підключення до сервера.',
        ru: 'Нет подключения к серверу.',
        pl: 'Brak połączenia z serwerem.',
        es: 'No hay conexión con el servidor.',
        cs: 'Není připojení k serveru.',
        de: 'Keine Verbindung zum Server.',
        en: 'No server connection.',
      );
  String get serverFileUploadUnsupported => _extra(
        uk: 'Сервер не підтримує завантаження файлів.',
        ru: 'Сервер не поддерживает загрузку файлов.',
        pl: 'Serwer nie obsługuje przesyłania plików.',
        es: 'El servidor no admite subida de archivos.',
        cs: 'Server nepodporuje nahrávání souborů.',
        de: 'Der Server unterstützt keine Datei-Uploads.',
        en: 'Server does not support file uploads.',
      );
  String get attachmentNotFoundOnServer => _extra(
        uk: 'Файл не знайдено на сервері.',
        ru: 'Файл не найден на сервере.',
        pl: 'Załącznik jest niedostępny.',
        es: 'El adjunto no está disponible.',
        cs: 'Příloha není dostupná.',
        de: 'Der Anhang ist nicht verfügbar.',
        en: 'Attachment is unavailable.',
      );
  String peerKeyChangedCall(String name) => _extra(
        uk: 'Ключ шифрування $name змінився. Перевірте відбиток перед дзвінком.',
        ru: 'Ключ шифрования $name изменился. Проверьте отпечаток перед звонком.',
        pl: 'Klucz szyfrowania użytkownika $name zmienił się. Sprawdź odcisk przed połączeniem.',
        es: 'La clave de cifrado de $name cambió. Verifica la huella antes de llamar.',
        cs: 'Šifrovací klíč uživatele $name se změnil. Před hovorem ověřte otisk.',
        de: 'Der Verschlüsselungsschlüssel von $name hat sich geändert. Prüfe den Fingerabdruck vor dem Anruf.',
        en: '$name\'s encryption key changed. Verify the fingerprint before calling.',
      );
  String peerNoEncryptionKey(String name) => _extra(
        uk: 'У $name ще немає ключа шифрування.',
        ru: 'У $name пока нет ключа шифрования.',
        pl: '$name nie ma jeszcze klucza szyfrowania.',
        es: '$name aún no tiene clave de cifrado.',
        cs: '$name zatím nemá šifrovací klíč.',
        de: '$name hat noch keinen Verschlüsselungsschlüssel.',
        en: '$name has no encryption key yet.',
      );
  String get pushSyncChannelDescription => _extra(
        uk: 'Синхронізація сповіщень Hestia про повідомлення й запити.',
        ru: 'Синхронизация уведомлений Hestia о сообщениях и запросах.',
        pl: 'Powiadomienia synchronizacji wiadomości i próśb Hestia.',
        es: 'Notificaciones de sincronización de mensajes y solicitudes de Hestia.',
        cs: 'Synchronizační oznámení Hestia pro zprávy a žádosti.',
        de: 'Synchronisierungsbenachrichtigungen für Hestia-Nachrichten und -Anfragen.',
        en: 'Sync notifications for Hestia messages and requests.',
      );
  String get pushCallChannelDescription => _extra(
        uk: 'Сповіщення Hestia про вхідні дзвінки.',
        ru: 'Уведомления Hestia о входящих звонках.',
        pl: 'Alerty połączeń przychodzących Hestia.',
        es: 'Alertas de llamadas entrantes de Hestia.',
        cs: 'Upozornění Hestia na příchozí hovory.',
        de: 'Hinweise auf eingehende Hestia-Anrufe.',
        en: 'Incoming call alerts for Hestia.',
      );
  String get pushMessagesChannel => _extra(
        uk: 'Повідомлення',
        ru: 'Сообщения',
        pl: 'Wiadomości',
        es: 'Mensajes',
        cs: 'Zprávy',
        de: 'Nachrichten',
        en: 'Messages',
      );
  String get pushCallsChannel => _extra(
        uk: 'Дзвінки',
        ru: 'Звонки',
        pl: 'Połączenia',
        es: 'Llamadas',
        cs: 'Hovory',
        de: 'Anrufe',
        en: 'Calls',
      );
  String get pushBackgroundChannel => _extra(
        uk: 'Фонове підключення',
        ru: 'Фоновое соединение',
        pl: 'Połączenie w tle',
        es: 'Conexión en segundo plano',
        cs: 'Připojení na pozadí',
        de: 'Hintergrundverbindung',
        en: 'Background connection',
      );
  String get pushMessageChannelDescription => _extra(
        uk: 'Сповіщення про вхідні повідомлення.',
        ru: 'Уведомления о входящих сообщениях.',
        pl: 'Powiadomienia o przychodzących wiadomościach.',
        es: 'Notificaciones de mensajes entrantes.',
        cs: 'Oznámení o příchozích zprávách.',
        de: 'Benachrichtigungen über eingehende Nachrichten.',
        en: 'Incoming message notifications.',
      );
  String get pushBackgroundChannelDescription => _extra(
        uk: 'Підтримує підключення Hestia, коли Firebase push недоступний.',
        ru: 'Поддерживает подключение Hestia, когда Firebase push недоступен.',
        pl: 'Utrzymuje połączenie Hestia, gdy powiadomienia Firebase są niedostępne.',
        es: 'Mantiene Hestia conectada cuando las notificaciones Firebase no están disponibles.',
        cs: 'Udržuje připojení Hestia, když push Firebase není dostupný.',
        de: 'Hält Hestia verbunden, wenn Firebase Push nicht verfügbar ist.',
        en: 'Keeps Hestia connected when Firebase push is unavailable.',
      );
  String get newContactRequestNotification => _extra(
        uk: 'Новий запит у контакти',
        ru: 'Новый запрос в контакты',
        pl: 'Nowa prośba o kontakt',
        es: 'Nueva solicitud de contacto',
        cs: 'Nová žádost o kontakt',
        de: 'Neue Kontaktanfrage',
        en: 'New contact request',
      );
  String get newMessageNotification => _extra(
        uk: 'Нове повідомлення',
        ru: 'Новое сообщение',
        pl: 'Nowa wiadomość',
        es: 'Nuevo mensaje',
        cs: 'Nová zpráva',
        de: 'Neue Nachricht',
        en: 'New message',
      );
  String get incomingVideoCallNotification => _extra(
        uk: 'Вхідний відеодзвінок',
        ru: 'Входящий видеозвонок',
        pl: 'Przychodzące połączenie wideo',
        es: 'Videollamada entrante',
        cs: 'Příchozí videohovor',
        de: 'Eingehender Videoanruf',
        en: 'Incoming video call',
      );
  String get incomingVoiceCallNotification => _extra(
        uk: 'Вхідний голосовий дзвінок',
        ru: 'Входящий голосовой звонок',
        pl: 'Przychodzące połączenie głosowe',
        es: 'Llamada de voz entrante',
        cs: 'Příchozí hlasový hovor',
        de: 'Eingehender Sprachanruf',
        en: 'Incoming voice call',
      );
  String get unknownCaller => _extra(
        uk: 'Невідомо',
        ru: 'Неизвестно',
        pl: 'Nieznany',
        es: 'Desconocido',
        cs: 'Neznámý',
        de: 'Unbekannt',
        en: 'Unknown',
      );
  String get rejectCall => _extra(
        uk: 'Відхилити',
        ru: 'Отклонить',
        pl: 'Odrzuć',
        es: 'Rechazar',
        cs: 'Odmítnout',
        de: 'Ablehnen',
        en: 'Reject',
      );
  String get updateAvailable => _extra(
        uk: 'Доступне оновлення',
        ru: 'Доступно обновление',
        pl: 'Dostępna aktualizacja',
        es: 'Actualización disponible',
        cs: 'Dostupná aktualizace',
        de: 'Update verfügbar',
        en: 'Update available',
      );
  String versionAvailable(String version) => _extra(
        uk: 'Доступна версія $version.',
        ru: 'Доступна версия $version.',
        pl: 'Dostępna jest wersja $version.',
        es: 'La versión $version está disponible.',
        cs: 'Je dostupná verze $version.',
        de: 'Version $version ist verfügbar.',
        en: 'Version $version is available.',
      );
  String get startingDownload => _extra(
        uk: 'Починається завантаження...',
        ru: 'Начинается загрузка...',
        pl: 'Rozpoczynanie pobierania...',
        es: 'Iniciando descarga...',
        cs: 'Spouštění stahování...',
        de: 'Download wird gestartet...',
        en: 'Starting download...',
      );
  String downloadingProgress(String percent) => _extra(
        uk: 'Завантаження... $percent%',
        ru: 'Загрузка... $percent%',
        pl: 'Pobieranie... $percent%',
        es: 'Descargando... $percent%',
        cs: 'Stahování... $percent%',
        de: 'Download läuft... $percent%',
        en: 'Downloading... $percent%',
      );
  String get downloadFailedRetry => _extra(
        uk: 'Не вдалося завантажити. Спробуйте ще раз.',
        ru: 'Не удалось загрузить. Попробуйте ещё раз.',
        pl: 'Pobieranie nie powiodło się. Spróbuj ponownie.',
        es: 'La descarga falló. Inténtalo de nuevo.',
        cs: 'Stažení selhalo. Zkuste to znovu.',
        de: 'Download fehlgeschlagen. Bitte versuche es erneut.',
        en: 'Download failed. Please try again.',
      );
  String get later => _extra(
        uk: 'Пізніше',
        ru: 'Позже',
        pl: 'Później',
        es: 'Más tarde',
        cs: 'Později',
        de: 'Später',
        en: 'Later',
      );
  String get downloading => _extra(
        uk: 'Завантаження...',
        ru: 'Загрузка...',
        pl: 'Pobieranie...',
        es: 'Descargando...',
        cs: 'Stahování...',
        de: 'Download läuft...',
        en: 'Downloading...',
      );
  String get updateViaAppStore => _extra(
        uk: 'Оновити через App Store',
        ru: 'Обновить через App Store',
        pl: 'Aktualizuj przez App Store',
        es: 'Actualizar mediante App Store',
        cs: 'Aktualizovat přes App Store',
        de: 'Über App Store aktualisieren',
        en: 'Update via App Store',
      );
  String get downloadAndInstall => _extra(
        uk: 'Завантажити й установити',
        ru: 'Скачать и установить',
        pl: 'Pobierz i zainstaluj',
        es: 'Descargar e instalar',
        cs: 'Stáhnout a nainstalovat',
        de: 'Herunterladen und installieren',
        en: 'Download and install',
      );
  String get openDownloadPage => _extra(
        uk: 'Відкрити сторінку завантаження',
        ru: 'Открыть страницу загрузки',
        pl: 'Otwórz stronę pobierania',
        es: 'Abrir página de descarga',
        cs: 'Otevřít stránku stažení',
        de: 'Download-Seite öffnen',
        en: 'Open download page',
      );

  String localizeError(Object error) {
    final raw = error.toString().trim();
    final message = raw.startsWith('Exception: ')
        ? raw.substring('Exception: '.length).trim()
        : raw;

    if (message == 'Nickname is required') return nicknameRequired;
    if (message == 'Password is required') return passwordRequired;
    if (message == 'Nickname must be at least 2 characters') {
      return nicknameTooShort;
    }
    if (message == 'Password must be at least 6 characters') {
      return passwordTooShort;
    }
    if (message == 'User is unavailable' || message == 'User is unavailable.') {
      return userUnavailable;
    }
    if (message == 'Call was rejected') return callRejected;
    if (message == 'Call expired') return callExpired;
    if (message == 'Video calls are disabled.') return videoCallsDisabled;
    if (message == 'Microphone unavailable. You can watch/listen only.') {
      return microphoneUnavailableListenOnly;
    }
    if (message == 'Desktop voice call setup failed.') {
      return desktopVoiceSetupFailed;
    }
    if (message ==
        'Microphone unavailable. Check Desktop microphone permissions.') {
      return desktopMicrophonePermission;
    }
    if (message ==
        'Could not start Desktop camera. It may be busy or blocked by privacy settings.') {
      return desktopCameraUnavailable;
    }
    if (message ==
        'Could not start camera or microphone. Check Android camera and microphone permissions.') {
      return androidCameraMicPermission;
    }
    if (message ==
        'Microphone permission is disabled. Enable microphone access in Android settings.') {
      return androidMicrophonePermissionDisabled;
    }
    if (message ==
        'Camera permission is disabled. Enable camera access in Android settings.') {
      return androidCameraPermissionDisabled;
    }
    if (message == 'File attachments are disabled in v0.1.0.') {
      return fileAttachmentsDisabled;
    }
    if (message == 'Forwarding file attachments is disabled in v0.1.0.') {
      return fileForwardingDisabled;
    }
    if (message.startsWith('Cannot encrypt for ') &&
        message.endsWith(': no encryption key yet.')) {
      final name = message
          .substring('Cannot encrypt for '.length)
          .replaceFirst(': no encryption key yet.', '');
      return cannotEncryptFor(name);
    }
    if (message.contains(' ${_englishSendingKeyChangedSuffix()}')) {
      final name = message.replaceFirst(
        ' ${_englishSendingKeyChangedSuffix()}',
        '',
      );
      return peerKeyChangedSending(name);
    }
    if (message ==
        'Android stopped background service. Calls/messages may not arrive until Hestia is opened again.') {
      return androidStoppedBackgroundService;
    }
    if (message == 'This session was revoked.') return sessionRevoked;
    if (message == 'Unknown server error') return unknownServerError;
    if (message == 'Authentication required.') return authenticationRequired;
    const invalidServerUrlPrefix = 'Invalid server URL: ';
    if (message.startsWith(invalidServerUrlPrefix)) {
      return invalidServerUrl(message.substring(invalidServerUrlPrefix.length));
    }
    const unsupportedServerUrlSchemePrefix = 'Unsupported server URL scheme: ';
    if (message.startsWith(unsupportedServerUrlSchemePrefix)) {
      return unsupportedServerUrlScheme(
        message.substring(unsupportedServerUrlSchemePrefix.length),
      );
    }
    if (message == 'No profile is available to export.') {
      return backupProfileUnavailable;
    }
    if (message == 'No backup file selected.') return backupFileNotSelected;
    if (message == 'Could not read backup file.') return backupReadFailed;
    if (message == 'Unsupported backup format.') return backupFormatUnsupported;
    if (message == 'Backup password is wrong or file is corrupted.') {
      return backupPasswordWrongOrCorrupted;
    }
    if (message == 'Backup password must be at least 8 characters.') {
      return backupPasswordMinimum;
    }
    if (message == 'Unsupported image format.') return unsupportedImageFormat;
    if (message == 'Image is too large.') return imageTooLarge;
    if (message == 'Encryption identity is not available.') {
      return encryptionIdentityUnavailable;
    }
    if (message == 'Backup does not contain a valid encryption identity.') {
      return invalidBackupEncryptionIdentity;
    }
    if (message == 'Invalid public key') return invalidEncryptionKey;
    if (message == 'Encrypted payload verification failed') {
      return encryptedPayloadVerificationFailed;
    }
    if (message == 'WebSocket is not connected.' ||
        message == 'Reconnect did not establish a websocket session.') {
      return noServerConnection;
    }
    if (message == 'camera_microphone_permissions_required') {
      return cameraMicPermissionsRequired;
    }
    if (message == 'camera_preview_timed_out') {
      return cameraPreviewTimedOut;
    }
    if (message == 'no_camera_video_track') {
      return noCameraVideoTrack;
    }
    if (message == 'microphone_permission_required_for_calls') {
      return micPermissionRequiredForCalls;
    }
    if (message == 'camera_permission_required_for_video_calls') {
      return cameraPermissionRequiredForVideoCalls;
    }
    if (message == 'no_camera_found') {
      return noCameraFound;
    }
    if (message == 'Camera unavailable. Continuing with audio.') {
      return cameraUnavailableAudioFallback;
    }
    if (message.startsWith('Could not connect to ')) {
      return couldNotConnectTo(
          message.substring('Could not connect to '.length));
    }
    if (message.startsWith('Local file not found:')) return localFileNotFound;
    if (message == 'Attachment type is blocked for safety.') {
      return attachmentTypeBlockedForSafety;
    }
    if (message == 'Attachment validation failed.') {
      return attachmentValidationFailed;
    }
    if (message.startsWith('Attachment validation failed. Allowed files:')) {
      return '$attachmentValidationFailed $attachmentLimits';
    }
    if (message == 'Attachment is too large.') return attachmentTooLarge;
    if (message.startsWith('Attachment is too large. Allowed files:')) {
      return '$attachmentTooLarge $attachmentLimits';
    }
    if (message == 'Could not read the selected file') {
      return selectedFileReadFailed;
    }
    if (message == 'File was not found on device.') return selectedFileNotFound;
    if (message == 'Could not access the selected file.') {
      return selectedFileAccessDenied;
    }
    if (message == 'Forward failed: local file is unavailable.') {
      return forwardLocalFileUnavailable;
    }
    if (message == 'No server connection.') return noServerConnection;
    if (message == 'Upload endpoint unavailable.') {
      return uploadEndpointUnavailable;
    }
    if (message == 'Invalid upload response.') return invalidUploadResponse;
    if (message == 'Server does not support file uploads.') {
      return serverFileUploadUnsupported;
    }
    if (message.startsWith('download failed:')) {
      return attachmentDownloadFailed;
    }
    if (message.startsWith('decrypt exception:') ||
        message.startsWith('decrypt failed:') ||
        message.startsWith('decode failed:')) {
      return attachmentDecryptFailed;
    }
    if (message.startsWith('file write failed:')) {
      return attachmentSaveFailed;
    }
    if (message == 'Not found' || message == 'Attachment is unavailable.') {
      return attachmentNotFoundOnServer;
    }
    if (message == 'Attachment upload failed.' ||
        message.startsWith('Attachment upload failed (')) {
      return attachmentUploadFailed;
    }
    if (message.startsWith('Allowed files:') ||
        message.startsWith('Documents, images, audio')) {
      return attachmentLimits;
    }
    if (message.contains(' ${_englishKeyChangedSuffix()}')) {
      final name = message.replaceFirst(' ${_englishKeyChangedSuffix()}', '');
      return peerKeyChangedCall(name);
    }
    if (message.endsWith(' has no encryption key yet.')) {
      final name = message.substring(
          0, message.length - ' has no encryption key yet.'.length);
      return peerNoEncryptionKey(name);
    }

    return message;
  }

  String _englishKeyChangedSuffix() =>
      'encryption key changed. Verify the fingerprint before calling.';

  String _englishSendingKeyChangedSuffix() =>
      'encryption key changed. Verify the fingerprint before sending.';

  String _extra({
    required String uk,
    required String ru,
    required String en,
    required String pl,
    required String es,
    required String cs,
    required String de,
  }) {
    return switch (localeName) {
      'uk' => uk,
      'ru' => ru,
      'pl' => pl,
      'es' => es,
      'cs' => cs,
      'de' => de,
      _ => en,
    };
  }
}
