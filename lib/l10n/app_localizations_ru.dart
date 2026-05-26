// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Hestia';

  @override
  String get splashTagline => 'Приватное пространство для своих';

  @override
  String get systemDefault => 'Как в системе';

  @override
  String get language => 'Язык';

  @override
  String get settings => 'Настройки';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get appearance => 'Внешний вид';

  @override
  String get background => 'Фон';

  @override
  String get backgroundDefault => 'По умолчанию';

  @override
  String get backgroundChooseColor => 'Выбрать цвет';

  @override
  String get backgroundChooseImage => 'Выбрать изображение';

  @override
  String get reset => 'Сбросить';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get close => 'Закрыть';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get search => 'Поиск';

  @override
  String get refresh => 'Обновить';

  @override
  String get accept => 'Принять';

  @override
  String get decline => 'Отклонить';

  @override
  String get request => 'Запрос';

  @override
  String get error => 'Ошибка';

  @override
  String get server => 'Сервер';

  @override
  String get serverUrl => 'URL сервера';

  @override
  String serverConnected(String host) {
    return 'Подключено к $host';
  }

  @override
  String get serverDisconnected => 'Отключено';

  @override
  String get login => 'Вход';

  @override
  String get registration => 'Регистрация';

  @override
  String get register => 'Зарегистрироваться';

  @override
  String get nicknameRequired => 'Ник обязателен';

  @override
  String get passwordRequired => 'Пароль обязателен';

  @override
  String get nicknameTooShort => 'Ник должен быть не короче 2 символов';

  @override
  String get passwordTooShort => 'Пароль должен быть не короче 6 символов';

  @override
  String get chooseNickname => 'Выберите новый ник';

  @override
  String get yourNickname => 'Ваш ник';

  @override
  String get choosePassword => 'Выберите пароль';

  @override
  String get password => 'Пароль';

  @override
  String get showPassword => 'Показать пароль';

  @override
  String get hidePassword => 'Скрыть пароль';

  @override
  String get chats => 'Чаты';

  @override
  String get contacts => 'Контакты';

  @override
  String get requests => 'Запросы';

  @override
  String get addContact => 'Добавить контакт';

  @override
  String get privacy => 'Приватность';

  @override
  String get backup => 'Резервная копия';

  @override
  String get devices => 'Устройства';

  @override
  String get allowUsernameSearch => 'Разрешить поиск по нику';

  @override
  String get messagesFrom => 'Сообщения от';

  @override
  String get callsFrom => 'Звонки от';

  @override
  String get everyone => 'Все';

  @override
  String get noChatsYet => 'Чатов пока нет.';

  @override
  String get noContactsYet => 'Добавьте контакт, чтобы начать общение';

  @override
  String get firstRunNoContactsTitle =>
      'Добавьте контакт, чтобы начать общение';

  @override
  String get firstRunNoContactsBody =>
      'Найдите человека по имени пользователя и отправьте запрос.';

  @override
  String get hintAddContact => 'Найдите человека по имени пользователя';

  @override
  String get hintRequests => 'Здесь появляются запросы на добавление';

  @override
  String get hintMessageInput => 'Напишите сообщение';

  @override
  String get noPendingRequests => 'Ожидающих запросов нет.';

  @override
  String get findUsername => 'Найти ник';

  @override
  String get username => 'Ник';

  @override
  String get enterUsername => 'Введите ник';

  @override
  String get userFound => 'Пользователь найден';

  @override
  String get userNotFound => 'Пользователь не найден или поиск отключен.';

  @override
  String get sendContactRequest => 'Отправить запрос';

  @override
  String requestSentTo(String name) {
    return 'Запрос отправлен $name';
  }

  @override
  String get retentionContactAdded => 'Контакт добавлен. Можно начать чат.';

  @override
  String get retentionFirstMessageSent =>
      'Сообщение отправлено. Hestia сохранит разговор спокойным и приватным.';

  @override
  String get retentionStartChatHint =>
      'Откройте чат и отправьте первое сообщение, когда будете готовы.';

  @override
  String get retentionDayReminder =>
      'Вы давно не общались. Приватные чаты здесь, когда захотите спокойно ответить.';

  @override
  String get retentionThreeDayReminder =>
      'Мягкое напоминание: разговоры со своими ждут вас здесь.';

  @override
  String get retentionNewMessages => 'Есть новые сообщения.';

  @override
  String get contact => 'Контакт';

  @override
  String get contactOnline => 'Сейчас онлайн';

  @override
  String get block => 'Заблокировать';

  @override
  String get unblockUser => 'Разблокировать пользователя';

  @override
  String get blockUser => 'Заблокировать пользователя';

  @override
  String get wantsToAddYou => 'Хочет добавить вас в контакты';

  @override
  String get attachment => 'Вложение';

  @override
  String attachmentNamed(String name) {
    return 'Вложение: $name';
  }

  @override
  String get mute => 'Выключить звук';

  @override
  String get unmute => 'Включить звук';

  @override
  String get pin => 'Закрепить';

  @override
  String get unpin => 'Открепить';

  @override
  String get archive => 'Архивировать';

  @override
  String get deleteForMe => 'Удалить у меня';

  @override
  String get backupWarning =>
      'Резервные копии шифруются локально. Сохраните пароль: без него восстановление невозможно.';

  @override
  String get backupPassword => 'Пароль резервной копии';

  @override
  String get confirmBackupPassword => 'Подтвердите пароль для экспорта';

  @override
  String get backupPasswordsDoNotMatch =>
      'Пароли резервной копии не совпадают.';

  @override
  String get backupExportCancelled => 'Экспорт резервной копии отменен.';

  @override
  String get backupSaved => 'Резервная копия сохранена.';

  @override
  String get backupImported =>
      'Резервная копия импортирована. Локальные данные восстановлены.';

  @override
  String get import => 'Импорт';

  @override
  String get export => 'Экспорт';

  @override
  String get noSessionData => 'Активных устройств не найдено';

  @override
  String get unknownActivity => 'Активность неизвестна';

  @override
  String lastActive(String time) {
    return 'Последняя активность $time';
  }

  @override
  String currentDevice(String name) {
    return '$name (текущее)';
  }

  @override
  String get revoke => 'Отозвать';

  @override
  String get logoutCurrent => 'Выйти из этого устройства';

  @override
  String get message => 'Сообщение';

  @override
  String get send => 'Отправить';

  @override
  String get sendFile => 'Отправить файл';

  @override
  String messageSendFailed(String error) {
    return 'Не удалось отправить сообщение: $error';
  }

  @override
  String fileSendFailed(String error) {
    return 'Не удалось отправить файл: $error';
  }

  @override
  String get noMessagesYet => 'Напишите первое сообщение';

  @override
  String get reply => 'Ответить';

  @override
  String get forward => 'Переслать';

  @override
  String get forwardTo => 'Переслать в';

  @override
  String get forwarded => 'Переслано';

  @override
  String forwardedFrom(String name) {
    return 'Переслано от $name';
  }

  @override
  String forwardedTo(String name) {
    return 'Переслано $name';
  }

  @override
  String forwardFailed(String error) {
    return 'Не удалось переслать: $error';
  }

  @override
  String get noForwardTargets => 'Нет доступных контактов для пересылки';

  @override
  String get cancelReply => 'Отменить ответ';

  @override
  String get originalMessage => 'Исходное сообщение';

  @override
  String get originalMessageUnavailable => 'Исходное сообщение недоступно';

  @override
  String savedTo(String path) {
    return 'Сохранено в $path';
  }

  @override
  String saveFailed(String error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get open => 'Открыть';

  @override
  String get userUnavailable => 'Пользователь недоступен.';

  @override
  String get callRejected => 'Звонок отклонён.';

  @override
  String get sessionRevoked => 'Эта сессия была отозвана.';

  @override
  String couldNotConnectTo(String host) {
    return 'Не удалось подключиться к $host';
  }

  @override
  String get unknownServerError => 'Неизвестная ошибка сервера';

  @override
  String get authenticationRequired => 'Требуется аутентификация.';

  @override
  String get localFileNotFound => 'Локальный файл не найден.';

  @override
  String get webAttachmentAvailable =>
      'Файл доступен в текущей сессии браузера.';

  @override
  String get webAttachmentUnavailable =>
      'Файл недоступен после перезапуска браузера.';

  @override
  String get attachmentTypeNotAllowed => 'Этот тип вложения не разрешён.';

  @override
  String get attachmentValidationFailed => 'Не удалось проверить вложение.';

  @override
  String get attachmentTooLarge => 'Вложение слишком большое.';

  @override
  String get attachmentLimits =>
      'Разрешены документы, изображения, аудио и видео. Лимиты: документы/изображения 50 МБ, аудио 100 МБ, видео 250 МБ. Один файл на сообщение.';

  @override
  String get selectedFileReadFailed => 'Не удалось прочитать выбранный файл.';

  @override
  String get forwardLocalFileUnavailable =>
      'Не удалось переслать: локальный файл недоступен.';

  @override
  String get attachmentUploadFailed => 'Не удалось загрузить вложение.';

  @override
  String peerKeyChangedCall(String name) {
    return 'Ключ шифрования $name изменился. Проверьте отпечаток перед звонком.';
  }

  @override
  String peerNoEncryptionKey(String name) {
    return 'У $name пока нет ключа шифрования.';
  }

  @override
  String get encryptionKey => 'Ключ шифрования';

  @override
  String get verify => 'Проверить';

  @override
  String get trustKey => 'Доверять ключу';

  @override
  String get trustNewKey => 'Доверять новому ключу';

  @override
  String get removeTrust => 'Убрать доверие';

  @override
  String get verifiedEncryptionKey => 'Проверенный ключ шифрования';

  @override
  String get encryptionKeyChanged => 'Ключ шифрования изменился';

  @override
  String get noEncryptionKey => 'Нет ключа шифрования';

  @override
  String get verifyEncryptionKey => 'Проверить ключ шифрования';

  @override
  String get sendingBlockedKeyChanged =>
      'Отправка заблокирована, пока вы заново не проверите этот контакт.';

  @override
  String get keyTrusted => 'Этот ключ доверенный на этом устройстве.';

  @override
  String get keyChangedWarning =>
      'Внимание: этот ключ изменился. Сравните отпечаток перед доверием.';

  @override
  String get keyMissing =>
      'Этот пользователь еще не опубликовал ключ шифрования.';

  @override
  String get keyUntrusted =>
      'Сравните отпечаток с собеседником, затем доверьтесь ключу.';

  @override
  String get noFingerprint => 'Отпечаток недоступен';

  @override
  String get audioCall => 'Аудиозвонок';

  @override
  String get videoCall => 'Видеозвонок';

  @override
  String callFailed(String error) {
    return 'Звонок не удался: $error';
  }

  @override
  String get anotherCallActive => 'Другой звонок уже активен';

  @override
  String get calling => 'Вызов...';

  @override
  String get connected => 'Соединено';

  @override
  String get muteCall => 'Микрофон выключен';

  @override
  String get unmuteCall => 'Микрофон включен';

  @override
  String get endCall => 'Завершить';

  @override
  String get incomingCall => 'Входящий звонок';

  @override
  String get voiceCall => 'Голосовой звонок';

  @override
  String get pushSyncChannelDescription =>
      'Синхронизация уведомлений Hestia о сообщениях и запросах.';

  @override
  String get pushCallChannelDescription =>
      'Уведомления Hestia о входящих звонках.';

  @override
  String get newContactRequestNotification => 'Новый запрос в контакты';

  @override
  String get newMessageNotification => 'Новое сообщение';

  @override
  String get incomingVideoCallNotification => 'Входящий видеозвонок';

  @override
  String get incomingVoiceCallNotification => 'Входящий голосовой звонок';

  @override
  String get unknownCaller => 'Неизвестно';

  @override
  String get rejectCall => 'Отклонить';

  @override
  String get updateAvailable => 'Доступно обновление';

  @override
  String versionAvailable(String version) {
    return 'Доступна версия $version.';
  }

  @override
  String get startingDownload => 'Начинается загрузка...';

  @override
  String downloadingProgress(String percent) {
    return 'Загрузка... $percent%';
  }

  @override
  String get downloadFailedRetry => 'Не удалось загрузить. Попробуйте ещё раз.';

  @override
  String get later => 'Позже';

  @override
  String get downloading => 'Загрузка...';

  @override
  String get updateViaAppStore => 'Обновить через App Store';

  @override
  String get downloadAndInstall => 'Скачать и установить';

  @override
  String get openDownloadPage => 'Открыть страницу загрузки';

  @override
  String get checkForUpdates => 'Проверить обновления';

  @override
  String get latestVersionInstalled =>
      'У вас уже установлена последняя версия.';

  @override
  String get updatesAndroidOnly => 'Обновления доступны только на Android.';

  @override
  String get updateCheckFailed =>
      'Не удалось проверить обновления. Попробуйте ещё раз.';

  @override
  String currentVersionLabel(String version) {
    return 'Текущая версия: $version';
  }

  @override
  String latestVersionLabel(String version) {
    return 'Последняя версия: $version';
  }

  @override
  String get releaseNotes => 'Примечания к выпуску';

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
  String get onboardingSkip => 'Пропустить';

  @override
  String get onboardingNext => 'Далее';

  @override
  String get onboardingGetStarted => 'Начать';

  @override
  String get onboardingWelcomeTitle => 'Добро пожаловать в Hestia';

  @override
  String get onboardingWelcomeBody =>
      'Спокойный мессенджер для приватных чатов, звонков и файлов.';

  @override
  String get onboardingPrivacyTitle => 'Приватность по умолчанию';

  @override
  String get onboardingPrivacyBody =>
      'Сообщения используют ключи шифрования. Чаты и файлы хранятся локально.';

  @override
  String get onboardingHowItWorksTitle => 'Простая схема';

  @override
  String get onboardingHowItWorksBody =>
      'Выберите сервер, добавьте контакты и подтверждайте запросы перед общением.';

  @override
  String get onboardingCallsFilesTitle => 'Звонки и файлы';

  @override
  String get onboardingCallsFilesBody =>
      'Запускайте голосовые звонки и делитесь файлами в защищённом пространстве.';

  @override
  String get onboardingServerTitle => 'Выберите сервер';

  @override
  String get onboardingServerBody =>
      'Используйте сервер по умолчанию или подключите свой сервер Hestia.';

  @override
  String get onboardingDefaultServer => 'Сервер по умолчанию';

  @override
  String get onboardingCustomServer => 'Свой сервер';

  @override
  String get onboardingCustomServerBody =>
      'Для self-hosted или приватных установок.';

  @override
  String get onboardingGetStartedTitle => 'Можно начинать';

  @override
  String get onboardingGetStartedBody =>
      'Создайте новый аккаунт или войдите в существующий.';

  @override
  String get diagnostics => 'Диагностика';

  @override
  String get diagnosticMode => 'Режим диагностики';

  @override
  String get diagnosticModeDescription =>
      'По умолчанию выключен. Без паролей, токенов и открытого текста сообщений.';

  @override
  String get testMicrophone => 'Проверить микрофон';

  @override
  String get copyDiagnostics => 'Скопировать диагностику';

  @override
  String get videoPreview => 'Предпросмотр видео';

  @override
  String get switchCamera => 'Переключить камеру';

  @override
  String get cameraMicPermissionsRequired =>
      'Требуются разрешения на камеру и микрофон.';

  @override
  String get cameraPreviewTimedOut =>
      'Время ожидания предпросмотра камеры истекло.';

  @override
  String get cameraUnavailableCheckPermissions =>
      'Камера недоступна. Проверьте разрешения камеры и микрофона.';

  @override
  String get noCameraVideoTrack => 'Видеодорожка камеры не создана.';

  @override
  String get micPermissionRequiredForCalls =>
      'Для звонков требуется разрешение на микрофон.';

  @override
  String get cameraPermissionRequiredForVideoCalls =>
      'Для видеозвонков требуется разрешение на камеру.';

  @override
  String get noCameraFound => 'Камера не найдена.';
}
