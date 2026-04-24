// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appName => 'Hestia';

  @override
  String get splashTagline => 'Приватний простір для своїх';

  @override
  String get systemDefault => 'Як у системі';

  @override
  String get language => 'Мова';

  @override
  String get settings => 'Налаштування';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Системна';

  @override
  String get themeLight => 'Світла';

  @override
  String get themeDark => 'Темна';

  @override
  String get appearance => 'Вигляд';

  @override
  String get background => 'Фон';

  @override
  String get backgroundDefault => 'За замовчуванням';

  @override
  String get backgroundChooseColor => 'Вибрати колір';

  @override
  String get backgroundChooseImage => 'Вибрати зображення';

  @override
  String get reset => 'Скинути';

  @override
  String get cancel => 'Скасувати';

  @override
  String get save => 'Зберегти';

  @override
  String get close => 'Закрити';

  @override
  String get continueAction => 'Продовжити';

  @override
  String get search => 'Пошук';

  @override
  String get refresh => 'Оновити';

  @override
  String get accept => 'Прийняти';

  @override
  String get decline => 'Відхилити';

  @override
  String get request => 'Запит';

  @override
  String get error => 'Помилка';

  @override
  String get server => 'Сервер';

  @override
  String get serverUrl => 'URL сервера';

  @override
  String serverConnected(String host) {
    return 'Підключено до $host';
  }

  @override
  String get serverDisconnected => 'Відключено';

  @override
  String get login => 'Вхід';

  @override
  String get registration => 'Реєстрація';

  @override
  String get register => 'Зареєструватися';

  @override
  String get nicknameRequired => 'Нік обов\'язковий';

  @override
  String get passwordRequired => 'Пароль обов\'язковий';

  @override
  String get nicknameTooShort => 'Нік має містити щонайменше 2 символи';

  @override
  String get passwordTooShort => 'Пароль має містити щонайменше 6 символів';

  @override
  String get chooseNickname => 'Оберіть новий нік';

  @override
  String get yourNickname => 'Ваш нік';

  @override
  String get choosePassword => 'Оберіть пароль';

  @override
  String get password => 'Пароль';

  @override
  String get showPassword => 'Показати пароль';

  @override
  String get hidePassword => 'Сховати пароль';

  @override
  String get chats => 'Чати';

  @override
  String get contacts => 'Контакти';

  @override
  String get requests => 'Запити';

  @override
  String get addContact => 'Додати контакт';

  @override
  String get privacy => 'Приватність';

  @override
  String get backup => 'Резервна копія';

  @override
  String get devices => 'Пристрої';

  @override
  String get allowUsernameSearch => 'Дозволити пошук за ніком';

  @override
  String get messagesFrom => 'Повідомлення від';

  @override
  String get callsFrom => 'Дзвінки від';

  @override
  String get everyone => 'Усі';

  @override
  String get noChatsYet => 'Чатів поки немає.';

  @override
  String get noContactsYet => 'Додайте контакт, щоб почати спілкування';

  @override
  String get firstRunNoContactsTitle =>
      'Додайте контакт, щоб почати спілкування';

  @override
  String get firstRunNoContactsBody =>
      'Знайдіть людину за іменем користувача й надішліть запит.';

  @override
  String get hintAddContact => 'Знайдіть людину за іменем користувача';

  @override
  String get hintRequests => 'Тут з’являються запити на додавання';

  @override
  String get hintMessageInput => 'Напишіть повідомлення';

  @override
  String get noPendingRequests => 'Очікуваних запитів немає.';

  @override
  String get findUsername => 'Знайти нік';

  @override
  String get username => 'Нік';

  @override
  String get enterUsername => 'Введіть нік';

  @override
  String get userFound => 'Користувача знайдено';

  @override
  String get userNotFound => 'Користувача не знайдено або пошук вимкнено.';

  @override
  String get sendContactRequest => 'Надіслати запит';

  @override
  String requestSentTo(String name) {
    return 'Запит надіслано $name';
  }

  @override
  String get retentionContactAdded => 'Контакт додано. Можна почати чат.';

  @override
  String get retentionFirstMessageSent =>
      'Повідомлення надіслано. Hestia збереже розмову спокійною і приватною.';

  @override
  String get retentionStartChatHint =>
      'Відкрийте чат і надішліть перше повідомлення, коли будете готові.';

  @override
  String get retentionDayReminder =>
      'Ви давно не спілкувалися. Приватні чати тут, коли захочете спокійно відповісти.';

  @override
  String get retentionThreeDayReminder =>
      'М\'яке нагадування: розмови зі своїми чекають тут.';

  @override
  String get retentionNewMessages => 'Є нові повідомлення.';

  @override
  String get contact => 'Контакт';

  @override
  String get contactOnline => 'Зараз онлайн';

  @override
  String get block => 'Заблокувати';

  @override
  String get unblockUser => 'Розблокувати користувача';

  @override
  String get blockUser => 'Заблокувати користувача';

  @override
  String get wantsToAddYou => 'Хоче додати вас у контакти';

  @override
  String get attachment => 'Вкладення';

  @override
  String attachmentNamed(String name) {
    return 'Вкладення: $name';
  }

  @override
  String get mute => 'Вимкнути звук';

  @override
  String get unmute => 'Увімкнути звук';

  @override
  String get pin => 'Закріпити';

  @override
  String get unpin => 'Відкріпити';

  @override
  String get archive => 'Архівувати';

  @override
  String get deleteForMe => 'Видалити у мене';

  @override
  String get backupWarning =>
      'Резервні копії шифруються локально. Збережіть пароль: без нього відновлення неможливе.';

  @override
  String get backupPassword => 'Пароль резервної копії';

  @override
  String get confirmBackupPassword => 'Підтвердіть пароль для експорту';

  @override
  String get backupPasswordsDoNotMatch =>
      'Паролі резервної копії не збігаються.';

  @override
  String get backupExportCancelled => 'Експорт резервної копії скасовано.';

  @override
  String get backupSaved => 'Резервну копію збережено.';

  @override
  String get backupImported =>
      'Резервну копію імпортовано. Локальні дані відновлено.';

  @override
  String get import => 'Імпорт';

  @override
  String get export => 'Експорт';

  @override
  String get noSessionData => 'Даних про сесії поки немає.';

  @override
  String get unknownActivity => 'Активність невідома';

  @override
  String lastActive(String time) {
    return 'Остання активність $time';
  }

  @override
  String currentDevice(String name) {
    return '$name (поточний)';
  }

  @override
  String get revoke => 'Відкликати';

  @override
  String get logoutCurrent => 'Вийти з поточної';

  @override
  String get message => 'Повідомлення';

  @override
  String get send => 'Надіслати';

  @override
  String get sendFile => 'Надіслати файл';

  @override
  String messageSendFailed(String error) {
    return 'Не вдалося надіслати повідомлення: $error';
  }

  @override
  String fileSendFailed(String error) {
    return 'Не вдалося надіслати файл: $error';
  }

  @override
  String get noMessagesYet => 'Напишіть перше повідомлення';

  @override
  String get reply => 'Відповісти';

  @override
  String get forward => 'Переслати';

  @override
  String get forwardTo => 'Переслати до';

  @override
  String get forwarded => 'Переслано';

  @override
  String forwardedFrom(String name) {
    return 'Переслано від $name';
  }

  @override
  String forwardedTo(String name) {
    return 'Переслано $name';
  }

  @override
  String forwardFailed(String error) {
    return 'Не вдалося переслати: $error';
  }

  @override
  String get noForwardTargets => 'Немає доступних контактів для пересилання';

  @override
  String get cancelReply => 'Скасувати відповідь';

  @override
  String get originalMessage => 'Початкове повідомлення';

  @override
  String get originalMessageUnavailable => 'Початкове повідомлення недоступне';

  @override
  String savedTo(String path) {
    return 'Збережено в $path';
  }

  @override
  String saveFailed(String error) {
    return 'Не вдалося зберегти: $error';
  }

  @override
  String get open => 'Відкрити';

  @override
  String get userUnavailable => 'Користувач недоступний.';

  @override
  String get callRejected => 'Дзвінок відхилено.';

  @override
  String get sessionRevoked => 'Цю сесію відкликано.';

  @override
  String couldNotConnectTo(String host) {
    return 'Не вдалося підключитися до $host';
  }

  @override
  String get unknownServerError => 'Невідома помилка сервера';

  @override
  String get authenticationRequired => 'Потрібна автентифікація.';

  @override
  String get localFileNotFound => 'Локальний файл не знайдено.';

  @override
  String get webAttachmentAvailable =>
      'Файл доступний у поточній сесії браузера.';

  @override
  String get webAttachmentUnavailable =>
      'Файл недоступний після перезапуску браузера.';

  @override
  String get attachmentTypeNotAllowed => 'Цей тип вкладення не дозволено.';

  @override
  String get attachmentValidationFailed => 'Не вдалося перевірити вкладення.';

  @override
  String get attachmentTooLarge => 'Вкладення завелике.';

  @override
  String get attachmentLimits =>
      'Дозволені файли: документи, зображення, аудіо та відео. Ліміти: зображення 25 МБ, аудіо/документи 50 МБ, відео 200 МБ.';

  @override
  String get selectedFileReadFailed => 'Не вдалося прочитати вибраний файл.';

  @override
  String get forwardLocalFileUnavailable =>
      'Не вдалося переслати: локальний файл недоступний.';

  @override
  String get attachmentUploadFailed => 'Не вдалося завантажити вкладення.';

  @override
  String peerKeyChangedCall(String name) {
    return 'Ключ шифрування $name змінився. Перевірте відбиток перед дзвінком.';
  }

  @override
  String peerNoEncryptionKey(String name) {
    return 'У $name ще немає ключа шифрування.';
  }

  @override
  String get encryptionKey => 'Ключ шифрування';

  @override
  String get verify => 'Перевірити';

  @override
  String get trustKey => 'Довіряти ключу';

  @override
  String get trustNewKey => 'Довіряти новому ключу';

  @override
  String get removeTrust => 'Прибрати довіру';

  @override
  String get verifiedEncryptionKey => 'Перевірений ключ шифрування';

  @override
  String get encryptionKeyChanged => 'Ключ шифрування змінився';

  @override
  String get noEncryptionKey => 'Немає ключа шифрування';

  @override
  String get verifyEncryptionKey => 'Перевірити ключ шифрування';

  @override
  String get sendingBlockedKeyChanged =>
      'Надсилання заблоковано, доки ви знову не перевірите цей контакт.';

  @override
  String get keyTrusted => 'Цей ключ довірений на цьому пристрої.';

  @override
  String get keyChangedWarning =>
      'Увага: цей ключ змінився. Порівняйте відбиток перед довірою.';

  @override
  String get keyMissing => 'Цей користувач ще не опублікував ключ шифрування.';

  @override
  String get keyUntrusted =>
      'Порівняйте відбиток зі співрозмовником, потім довіртеся ключу.';

  @override
  String get noFingerprint => 'Відбиток недоступний';

  @override
  String get audioCall => 'Аудіодзвінок';

  @override
  String get videoCall => 'Відеодзвінок';

  @override
  String callFailed(String error) {
    return 'Дзвінок не вдався: $error';
  }

  @override
  String get anotherCallActive => 'Інший дзвінок уже активний';

  @override
  String get calling => 'Виклик...';

  @override
  String get connected => 'З\'єднано';

  @override
  String get muteCall => 'Вимкнути мікрофон';

  @override
  String get unmuteCall => 'Увімкнути мікрофон';

  @override
  String get endCall => 'Завершити';

  @override
  String get incomingCall => 'Вхідний дзвінок';

  @override
  String get voiceCall => 'Голосовий дзвінок';

  @override
  String get pushSyncChannelDescription =>
      'Синхронізація сповіщень Hestia про повідомлення й запити.';

  @override
  String get pushCallChannelDescription =>
      'Сповіщення Hestia про вхідні дзвінки.';

  @override
  String get newContactRequestNotification => 'Новий запит у контакти';

  @override
  String get newMessageNotification => 'Нове повідомлення';

  @override
  String get incomingVideoCallNotification => 'Вхідний відеодзвінок';

  @override
  String get incomingVoiceCallNotification => 'Вхідний голосовий дзвінок';

  @override
  String get unknownCaller => 'Невідомо';

  @override
  String get rejectCall => 'Відхилити';

  @override
  String get updateAvailable => 'Доступне оновлення';

  @override
  String versionAvailable(String version) {
    return 'Доступна версія $version.';
  }

  @override
  String get startingDownload => 'Починається завантаження...';

  @override
  String downloadingProgress(String percent) {
    return 'Завантаження... $percent%';
  }

  @override
  String get downloadFailedRetry => 'Не вдалося завантажити. Спробуйте ще раз.';

  @override
  String get later => 'Пізніше';

  @override
  String get downloading => 'Завантаження...';

  @override
  String get updateViaAppStore => 'Оновити через App Store';

  @override
  String get downloadAndInstall => 'Завантажити й установити';

  @override
  String get openDownloadPage => 'Відкрити сторінку завантаження';

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
  String get onboardingSkip => 'Пропустити';

  @override
  String get onboardingNext => 'Далі';

  @override
  String get onboardingGetStarted => 'Почати';

  @override
  String get onboardingWelcomeTitle => 'Вітаємо в Hestia';

  @override
  String get onboardingWelcomeBody =>
      'Спокійний месенджер для приватних чатів, дзвінків і файлів.';

  @override
  String get onboardingPrivacyTitle => 'Приватність за задумом';

  @override
  String get onboardingPrivacyBody =>
      'Повідомлення використовують ключі шифрування. Чати й файли зберігаються локально.';

  @override
  String get onboardingHowItWorksTitle => 'Простий процес';

  @override
  String get onboardingHowItWorksBody =>
      'Оберіть сервер, додайте контакти й підтверджуйте запити перед спілкуванням.';

  @override
  String get onboardingCallsFilesTitle => 'Дзвінки та файли';

  @override
  String get onboardingCallsFilesBody =>
      'Запускайте голосові дзвінки й надсилайте файли в одному захищеному просторі.';

  @override
  String get onboardingServerTitle => 'Оберіть сервер';

  @override
  String get onboardingServerBody =>
      'Використовуйте стандартний сервер або підключіть власний сервер Hestia.';

  @override
  String get onboardingDefaultServer => 'Стандартний сервер';

  @override
  String get onboardingCustomServer => 'Власний сервер';

  @override
  String get onboardingCustomServerBody =>
      'Для self-hosted або приватних розгортань.';

  @override
  String get onboardingGetStartedTitle => 'Можна починати';

  @override
  String get onboardingGetStartedBody =>
      'Створіть новий акаунт або увійдіть в існуючий.';
}
