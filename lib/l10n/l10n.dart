import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  String localizedError(Object error) => l10n.localizeError(error);
}

extension HestiaErrorLocalizations on AppLocalizations {
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
  String get sessionRevoked => _extra(
        uk: 'Цю сесію відкликано.',
        ru: 'Эта сессия была отозвана.',
        pl: 'Ta sesja została odwołana.',
        es: 'Esta sesión fue revocada.',
        cs: 'Tato relace byla odvolána.',
        de: 'Diese Sitzung wurde widerrufen.',
        en: 'This session was revoked.',
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
        uk: 'Дозволені файли: документи, зображення, аудіо та відео. Ліміти: зображення 25 МБ, аудіо/документи 50 МБ, відео 200 МБ.',
        ru: 'Разрешены документы, изображения, аудио и видео. Лимиты: изображения 25 МБ, аудио/документы 50 МБ, видео 200 МБ.',
        pl: 'Dozwolone pliki: dokumenty, obrazy, audio i wideo. Limity: obrazy 25 MB, audio/dokumenty 50 MB, wideo 200 MB.',
        es: 'Archivos permitidos: documentos, imágenes, audio y vídeo. Límites: imágenes 25 MB, audio/documentos 50 MB, vídeo 200 MB.',
        cs: 'Povolené soubory: dokumenty, obrázky, audio a video. Limity: obrázky 25 MB, audio/dokumenty 50 MB, video 200 MB.',
        de: 'Erlaubte Dateien: Dokumente, Bilder, Audio und Video. Limits: Bilder 25 MB, Audio/Dokumente 50 MB, Video 200 MB.',
        en: 'Allowed files: documents, images, audio, and video. Limits: images 25 MB, audio/documents 50 MB, video 200 MB.',
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
        es: 'El servidor no admite la carga de archivos.',
        cs: 'Server nepodporuje nahrávání souborů.',
        de: 'Der Server unterstützt keine Datei-Uploads.',
        en: 'Server does not support file uploads.',
      );
  String get attachmentNotFoundOnServer => _extra(
        uk: 'Файл не знайдено на сервері.',
        ru: 'Файл не найден на сервере.',
        pl: 'Nie znaleziono pliku na serwerze.',
        es: 'No se encontró el archivo en el servidor.',
        cs: 'Soubor nebyl na serveru nalezen.',
        de: 'Datei wurde auf dem Server nicht gefunden.',
        en: 'File was not found on the server.',
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
    if (message == 'This session was revoked.') return sessionRevoked;
    if (message == 'Unknown server error') return unknownServerError;
    if (message == 'Authentication required.') return authenticationRequired;
    if (message.startsWith('Could not connect to ')) {
      return couldNotConnectTo(
          message.substring('Could not connect to '.length));
    }
    if (message.startsWith('Local file not found:')) {
      return localFileNotFound;
    }
    if (message == 'Файл доступен в текущей сессии браузера.') {
      return webAttachmentAvailable;
    }
    if (message == 'Файл недоступен после перезапуска браузера.') {
      return webAttachmentUnavailable;
    }
    if (message == 'Attachment type is not allowed.') {
      return attachmentTypeNotAllowed;
    }
    if (message.startsWith('Attachment type is not allowed. Allowed files:')) {
      return '$attachmentTypeNotAllowed $attachmentLimits';
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
    if (message == 'Forward failed: local file is unavailable.') {
      return forwardLocalFileUnavailable;
    }
    if (message == 'No server connection.') return noServerConnection;
    if (message == 'Server does not support file uploads.') {
      return serverFileUploadUnsupported;
    }
    if (message == 'Not found' || message == 'Attachment is unavailable.') {
      return attachmentNotFoundOnServer;
    }
    if (message == 'Attachment upload failed.' ||
        message.startsWith('Attachment upload failed (')) {
      return attachmentUploadFailed;
    }
    if (message.startsWith('Allowed files: documents, images, audio')) {
      return attachmentLimits;
    }
    if (message.contains(' ${_englishKeyChangedSuffix()}')) {
      final name = message.replaceFirst(' ${_englishKeyChangedSuffix()}', '');
      return peerKeyChangedCall(name);
    }
    if (message.endsWith(' has no encryption key yet.')) {
      final name = message.substring(
        0,
        message.length - ' has no encryption key yet.'.length,
      );
      return peerNoEncryptionKey(name);
    }

    return message;
  }

  String _englishKeyChangedSuffix() =>
      'encryption key changed. Verify the fingerprint before calling.';

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
