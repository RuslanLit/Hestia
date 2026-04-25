(function () {
  const supported = ["uk", "ru", "en", "pl", "es", "cs", "de"];
  const storageKey = "hestia.language";
  const release = window.HestiaReleaseConfig || {};
  const platforms = release.platforms || {};
  let sharedProductContent = null;

  const names = {
    uk: "Українська",
    ru: "Русский",
    en: "English",
    pl: "Polski",
    es: "Español",
    cs: "Čeština",
    de: "Deutsch",
  };

  const copy = {
    en: {
      nav: ["Features", "Privacy", "Server", "Downloads"],
      footer: ["Privacy", "Source code", "Documentation", "Server setup guide"],
      common: {
        version: "Version",
        copyright: "© 2026 Hestia Project.",
        recommended: "Recommended for {platform}. Download starts only after you click.",
        unknown: "We could not identify your platform, so no download will start automatically.",
        viewDownloads: "View all downloads",
        type: "Type",
        size: "Size",
      },
      platform: {
        android: ["Android", "Download for Android", "Download APK"],
        windows: ["Windows", "Download for Windows", "Download for Windows"],
        windowsPortable: ["Windows portable", "Download portable ZIP", "Download ZIP"],
        macos: ["macOS", "Download for macOS", "Download for macOS"],
        linux: ["Linux", "Download for Linux", "Download for Linux"],
        ios: ["iOS", "iOS build", "Not available"],
        web: ["Web", "Open Web Version", "Open Web Version"],
        server: ["Self-hosted server", "Self-host your server", "Server setup guide"],
        landing: ["Landing/site", "Download site package", "Download site ZIP"],
        checksums: ["Checksums", "Download checksums", "Download checksums"],
      },
      landing: {
        eyebrow: "Private messenger for people you trust",
        title: "Hestia",
        copy: "Your personal space for communication with family, close friends, and small teams: messages, files, and calls with local history and a server you can choose.",
        web: "Open Web Version",
        featuresEyebrow: "Made for your circle",
        featuresTitle: "A calm place to talk, share, and stay in control.",
        featuresCopy: "Hestia keeps the focus on the people you choose: family, close friends, and small teams that want privacy without complexity.",
        features: [
          ["M", "Chats for trusted people", "Keep everyday conversations in a private space built around explicit contacts and simple controls."],
          ["F", "Files for your group", "Share photos, documents, and notes without turning your server into a place for readable content."],
          ["C", "Calls when text is not enough", "Voice and video calls live next to your chats, so family, friends, or teammates can switch context naturally."],
          ["S", "A server you can choose", "Use the provided server or connect your own when your family, team, or community wants more ownership."],
          ["L", "History stays close", "Conversation history is kept on your device, helping reduce what needs to live on the server."],
          ["T", "Clear contact trust", "Verification is available for important contacts, but the app keeps the everyday experience simple."],
        ],
        howEyebrow: "How it works",
        howTitle: "Four steps from install to conversation.",
        steps: [
          ["Download the client", "Install Hestia on Android, desktop, or open the web version."],
          ["Connect to a server", "Use an existing Hestia server or prepare your own self-hosted backend."],
          ["Add contacts by request", "Start conversations through explicit contact requests instead of public discovery."],
          ["Talk in your own space", "Message, share files, and call with controls that stay understandable."],
        ],
        downloadsEyebrow: "Choose your client",
        downloadsTitle: "Downloads",
        downloadsCopy: "Hestia recommends the right client for your device, but download starts only after you choose it.",
        releaseDetails: "View release details",
        releaseNotes: "Release notes",
        privacyEyebrow: "Privacy model",
        privacyTitle: "Privacy you can understand.",
        privacy: [
          "Hestia is designed so the server does not keep readable messages or files. Your conversation history stays on your device.",
          "Privacy is still honest: the server may handle accounts, delivery state, connection timing, IP addresses, and other metadata needed to run the service.",
          "For families, friends, and small teams, self-hosting is an option when you want more control over where that server lives and who operates it.",
        ],
      },
      downloads: {
        eyebrow: "Release downloads",
        title: "Get Hestia",
        copy: "Download the right client for your platform. Links, version numbers, release notes, and checksum references are managed from one release config.",
        recommended: "Recommended download",
        notes: "Release notes",
        current: "Current release",
        version: "Version",
        sectionCopy: "Download files are hosted on GitHub Releases. Checksums are provided for verification before installing or running packages.",
        releasePage: "GitHub Release page",
        checksums: "Checksums",
        serverGuide: "Server setup guide",
        available: "Available downloads",
        unavailable: "Coming later",
        status: "Status",
        installTitle: "Install safely",
        installSteps: ["Download the file for your platform.", "Verify the SHA-256 checksum.", "Install or run the package."],
      },
      server: {
        eyebrow: "Self-hosting",
        title: "Server setup guide",
        intro: "Run a Hestia server for your own users on one domain. The same Node.js app can serve the landing at /, config at /api/config, and WebSocket traffic at /ws.",
        note: "Important: a self-hosted server still handles metadata such as accounts, connection timing, IP addresses, and delivery state. Treat logs and backups carefully.",
        toc: ["Requirements", "Before starting", "Get the code", "Environment", "Start server", "HTTPS / WSS", "TURN for calls", "Connect client", "Verify", "Security", "Troubleshooting"],
        sections: [
          ["Requirements", ["Minimum: 1 vCPU, 1 GB RAM, 10-20 GB SSD.", "Recommended: 2 vCPU, 2-4 GB RAM, 30-50 GB SSD.", "Linux, a domain name, HTTPS/WSS, and TURN for difficult call networks are recommended."]],
          ["What you need before starting", ["VPS or server with shell access.", "One domain name.", "Node.js and npm.", "Git.", "Firewall access.", "Optional Nginx or Caddy reverse proxy.", "Optional Firebase config for Android push.", "Optional TURN server for call relay fallback."]],
          ["Get the server code", ["Replace the repository placeholder with the real Hestia server repository URL when it is published."], "git clone https://github.com/RuslanLit/Hestia.git hestia-server\ncd hestia-server\nnpm install"],
          ["Configure environment", ["Create a .env file in the server directory. Keep tokens private and never publish service account files."], "PORT=3000\nSERVER_NAME=Hestia Self-Hosted\nOFFLINE_TTL_MS=604800000\nREGISTRATION_ENABLED=true\nINVITE_ONLY=false\nINVITE_CODES=\nADMIN_TOKEN=<GENERATE_A_LONG_RANDOM_TOKEN>\nTURN_SERVERS=[]\nFIREBASE_PROJECT_ID=\nFIREBASE_CLIENT_EMAIL=\nFIREBASE_PRIVATE_KEY="],
          ["Start the server", ["The server should expose the landing at /, backend config at /api/config, WebSocket at /ws, and writable persistence storage."], "npm start\ncurl http://127.0.0.1:3000/api/config"],
          ["Reverse proxy, HTTPS, and WSS", ["For production, put the single Hestia Node.js app behind a TLS reverse proxy. A separate api subdomain is not required."], "server {\n    listen 443 ssl http2;\n    server_name hestiachat.site;\n    ssl_certificate /path/to/fullchain.pem;\n    ssl_certificate_key /path/to/privkey.pem;\n    location / {\n        proxy_pass http://127.0.0.1:3000;\n        proxy_http_version 1.1;\n        proxy_set_header Host $host;\n        proxy_set_header Upgrade $http_upgrade;\n        proxy_set_header Connection \"upgrade\";\n    }\n}"],
          ["Optional TURN for calls", ["Direct WebRTC works best. Restrictive networks may require TURN relay fallback through TURN_SERVERS."], "TURN_SERVERS=[{\"urls\":\"turn:turn.your-domain.test:3478\",\"username\":\"<TURN_USERNAME>\",\"credential\":\"<TURN_PASSWORD>\"}]"],
          ["Connect the client", ["Open Hestia, enter the single-domain server URL if required, register or log in, then test messaging and calls."]],
          ["Verification checklist", ["/ serves the landing.", "/releases/latest.json is reachable.", "/api/config is reachable over HTTPS.", "WebSocket connects over /ws.", "Registration or login works.", "Two users can exchange messages.", "Offline delivery, file transfer, and call signaling work."]],
          ["Security basics", ["Use HTTPS/WSS.", "Choose a strong ADMIN_TOKEN.", "Restrict registration when needed.", "Keep server and OS updated.", "Avoid exposing debug logs.", "Back up data carefully.", "Remember that metadata may still be visible."]],
          ["Troubleshooting", ["If the app cannot connect, check URL, DNS, firewall, proxy, and TLS.", "If WebSocket fails, check upgrade headers.", "If push fails, check Firebase config.", "If calls fail behind NAT, configure TURN.", "If files are rejected, check limits and disk space."]],
        ],
      },
      privacyPage: {
        eyebrow: "Security model",
        title: "Privacy & Security",
        intro: "Hestia is designed as a privacy-first messenger focused on reducing server-side data exposure. In the current architecture, messages and files are intended to be encrypted on the client before they touch the server.",
        note: "This page describes intended security properties and known limitations. It is not a promise of anonymity or perfect protection.",
        toc: ["Protected data", "Server-visible data", "Trust model", "Not protected", "Local data", "Push notifications", "Server model", "Self-hosted", "Recommendations", "Limitations", "Future work"],
        sections: [
          ["What is protected", ["Text messages are encrypted on the client before sending; the server should not see plaintext.", "Files are encrypted before upload; the server should store encrypted blobs.", "Calls use WebRTC with DTLS-SRTP media encryption in transit.", "Message history is stored on the user's device rather than centrally as plaintext."]],
          ["What the server can see", ["Which accounts communicate.", "Connection times and activity patterns.", "Message frequency and delivery state.", "Encrypted file sizes.", "Call signaling events.", "IP addresses and connection metadata."]],
          ["Trust model and fingerprint verification", ["Each user is intended to have a public key.", "First contact uses trust on first use.", "Fingerprint or QR verification helps confirm a contact key.", "If a key changes, communication should be blocked until re-verification.", "Without verification, MITM risk remains possible."]],
          ["What is not protected by design", ["Compromised devices.", "Malware on a user device.", "Screen recording or local access.", "Weak device passwords.", "Social engineering.", "Users manually copying sensitive content."]],
          ["Local data", ["Messages and files are stored locally for usability. Decrypted data exists on the device while the user reads messages, opens files, or participates in calls."]],
          ["Push notifications", ["Push is intended as a wake-up mechanism. By default, push payloads should avoid plaintext message content and carry minimal metadata."]],
          ["Server model", ["The server relays encrypted traffic, coordinates delivery, and may temporarily store encrypted payloads for offline delivery.", "The server is controlled by its operator. In a self-hosted model, that operator may be you or your organization."]],
          ["Self-hosted implications", ["Running your own server increases infrastructure control but does not hide metadata from that server.", "You are responsible for TLS, logs, backups, updates, and operational security."]],
          ["Security recommendations", ["Verify fingerprints for important contacts.", "Use strong passwords.", "Keep devices locked and updated.", "Update Hestia regularly.", "Trust the server operator or consider self-hosting.", "Do not ignore unexpected key-change warnings."]],
          ["Limitations", ["No anonymous routing by default.", "Metadata is not fully hidden.", "The current trust model includes TOFU.", "No formal external security audit is claimed.", "Endpoint compromise can expose local plaintext."]],
          ["Future improvements", ["Stronger key verification UX, optional at-rest encryption controls, more metadata minimization, and additional transport privacy options."]],
        ],
      },
    },
  };

  const overlays = {
    ru: {
      nav: ["Возможности", "Приватность", "Сервер", "Загрузки"],
      footer: ["Приватность", "Исходный код", "Документация", "Настройка сервера"],
      common: { version: "Версия", recommended: "Рекомендуется для {platform}. Загрузка начнется только после клика.", unknown: "Платформа не распознана, автоматическая загрузка не запускается.", viewDownloads: "Все загрузки", type: "Тип", size: "Размер" },
      platform: { android: ["Android", "Скачать для Android", "Скачать APK"], windows: ["Windows", "Скачать для Windows", "Скачать для Windows"], windowsPortable: ["Windows portable", "Скачать portable ZIP", "Скачать ZIP"], macos: ["macOS", "Скачать для macOS", "Скачать для macOS"], linux: ["Linux", "Скачать для Linux", "Скачать для Linux"], ios: ["iOS", "Сборка iOS", "Недоступно"], web: ["Web", "Скачать Web-сборку", "Скачать Web ZIP"], server: ["Сервер", "Скачать backend", "Скачать backend"], landing: ["Лендинг/site", "Скачать site-пакет", "Скачать site ZIP"], checksums: ["Checksums", "Скачать checksums", "Скачать checksums"] },
      landing: { eyebrow: "Приватный мессенджер для людей, которым вы доверяете", copy: "Ваше личное пространство для общения с семьей, близкими друзьями и небольшими командами: сообщения, файлы и звонки с локальной историей и сервером на выбор.", web: "Открыть Web-версию", featuresEyebrow: "Сделано для своего круга", featuresTitle: "Спокойное место для разговоров, файлов и контроля.", featuresCopy: "Hestia фокусируется на людях, которых выбираете вы: семье, близких друзьях и небольших командах, которым нужна приватность без лишней сложности.", howEyebrow: "Как это работает", howTitle: "Четыре шага от установки до разговора.", downloadsEyebrow: "Выберите клиент", downloadsTitle: "Загрузки", downloadsCopy: "Hestia рекомендует клиент для устройства, но загрузка начинается только после вашего выбора.", releaseDetails: "Детали релиза", releaseNotes: "Заметки релиза", privacyEyebrow: "Модель приватности", privacyTitle: "Приватность, которую легко понять." },
      downloads: { eyebrow: "Релизные загрузки", title: "Скачать Hestia", copy: "Ссылки ведут на assets в GitHub Releases; latest.json используется для актуальной версии и проверки обновлений.", recommended: "Рекомендуемая загрузка", notes: "Заметки релиза", current: "Текущий релиз", version: "Версия", sectionCopy: "Файлы хранятся в GitHub Releases. Checksums доступны для проверки перед установкой.", releasePage: "Страница релиза GitHub", checksums: "Checksums", serverGuide: "Настройка сервера", available: "Доступные загрузки", unavailable: "Будет позже", status: "Статус", installTitle: "Безопасная установка", installSteps: ["Скачайте файл для своей платформы.", "Проверьте SHA-256 checksum.", "Установите или запустите пакет."] },
      server: { eyebrow: "Self-hosting", title: "Инструкция по настройке сервера", intro: "Запустите сервер Hestia для своих пользователей. Сервер ретранслирует зашифрованный трафик и signaling; plaintext сообщения и файлы не должны храниться на сервере.", note: "Важно: self-hosted сервер все равно обрабатывает metadata: аккаунты, время подключений, IP и состояние доставки.", toc: ["Требования", "Перед началом", "Код сервера", "Environment", "Запуск", "HTTPS / WSS", "TURN для звонков", "Клиент", "Проверка", "Безопасность", "Проблемы"] },
      privacyPage: { eyebrow: "Модель безопасности", title: "Приватность и безопасность", intro: "Hestia спроектирована как privacy-first мессенджер, который снижает раскрытие данных на стороне сервера. В текущей архитектуре сообщения и файлы шифруются на клиенте до отправки.", note: "Эта страница описывает свойства и ограничения. Это не обещание анонимности или идеальной защиты.", toc: ["Что защищено", "Что видит сервер", "Модель доверия", "Что не защищено", "Локальные данные", "Push", "Модель сервера", "Self-hosted", "Рекомендации", "Ограничения", "Будущее"] },
    },
    uk: {
      nav: ["Можливості", "Приватність", "Сервер", "Завантаження"],
      footer: ["Приватність", "Код", "Документація", "Налаштування сервера"],
      common: { version: "Версія", recommended: "Рекомендовано для {platform}. Завантаження почнеться лише після натискання.", unknown: "Платформу не розпізнано, автоматичне завантаження не запускається.", viewDownloads: "Усі завантаження", type: "Тип", size: "Розмір" },
      platform: { android: ["Android", "Завантажити для Android", "Завантажити APK"], windows: ["Windows", "Завантажити для Windows", "Завантажити для Windows"], windowsPortable: ["Windows portable", "Завантажити portable ZIP", "Завантажити ZIP"], macos: ["macOS", "Завантажити для macOS", "Завантажити для macOS"], linux: ["Linux", "Завантажити для Linux", "Завантажити для Linux"], ios: ["iOS", "Збірка iOS", "Недоступно"], web: ["Web", "Завантажити Web-збірку", "Завантажити Web ZIP"], server: ["Сервер", "Завантажити backend", "Завантажити backend"], landing: ["Лендинг/site", "Завантажити site-пакет", "Завантажити site ZIP"], checksums: ["Checksums", "Завантажити checksums", "Завантажити checksums"] },
      landing: { eyebrow: "Приватний месенджер для людей, яким ви довіряєте", copy: "Ваш особистий простір для спілкування з родиною, близькими друзями й невеликими командами: повідомлення, файли та дзвінки з локальною історією і сервером на вибір.", web: "Відкрити Web-версію", featuresEyebrow: "Створено для свого кола", featuresTitle: "Спокійне місце для розмов, файлів і контролю.", featuresCopy: "Hestia зосереджується на людях, яких ви обираєте: родині, близьких друзях і невеликих командах, яким потрібна приватність без складності.", howEyebrow: "Як це працює", howTitle: "Чотири кроки від встановлення до розмови.", downloadsEyebrow: "Оберіть клієнт", downloadsTitle: "Завантаження", downloadsCopy: "Hestia рекомендує клієнт для пристрою, але завантаження починається тільки після вибору.", releaseDetails: "Деталі релізу", releaseNotes: "Нотатки релізу", privacyEyebrow: "Модель приватності", privacyTitle: "Приватність, яку легко зрозуміти." },
      downloads: { eyebrow: "Релізні завантаження", title: "Завантажити Hestia", copy: "Посилання ведуть на assets у GitHub Releases; latest.json використовується для актуальної версії та перевірки оновлень.", recommended: "Рекомендоване завантаження", notes: "Нотатки релізу", current: "Поточний реліз", version: "Версія", sectionCopy: "Файли зберігаються в GitHub Releases. Checksums доступні для перевірки перед встановленням.", releasePage: "Сторінка релізу GitHub", checksums: "Checksums", serverGuide: "Налаштування сервера", available: "Доступні завантаження", unavailable: "Буде пізніше", status: "Статус", installTitle: "Безпечне встановлення", installSteps: ["Завантажте файл для своєї платформи.", "Перевірте SHA-256 checksum.", "Встановіть або запустіть пакет."] },
      server: { eyebrow: "Self-hosting", title: "Інструкція з налаштування сервера", intro: "Запустіть сервер Hestia для своїх користувачів. Сервер ретранслює зашифрований трафік і signaling; plaintext повідомлення та файли не повинні зберігатися на сервері.", note: "Важливо: self-hosted сервер усе одно обробляє metadata: акаунти, час підключень, IP та стан доставки.", toc: ["Вимоги", "Перед початком", "Код сервера", "Environment", "Запуск", "HTTPS / WSS", "TURN для дзвінків", "Клієнт", "Перевірка", "Безпека", "Проблеми"] },
      privacyPage: { eyebrow: "Модель безпеки", title: "Приватність і безпека", intro: "Hestia спроєктована як privacy-first месенджер, що зменшує розкриття даних на сервері. У поточній архітектурі повідомлення та файли шифруються на клієнті до надсилання.", note: "Ця сторінка описує властивості й обмеження. Це не обіцянка анонімності або ідеального захисту.", toc: ["Що захищено", "Що бачить сервер", "Модель довіри", "Що не захищено", "Локальні дані", "Push", "Модель сервера", "Self-hosted", "Поради", "Обмеження", "Майбутнє"] },
    },
    pl: {
      nav: ["Funkcje", "Prywatność", "Serwer", "Pobieranie"],
      footer: ["Prywatność", "Kod źródłowy", "Dokumentacja", "Konfiguracja serwera"],
      common: { version: "Wersja", recommended: "Zalecane dla {platform}. Pobieranie zacznie się dopiero po kliknięciu.", unknown: "Nie rozpoznano platformy; pobieranie nie rozpocznie się automatycznie.", viewDownloads: "Wszystkie pliki", type: "Typ", size: "Rozmiar" },
      platform: { android: ["Android", "Pobierz dla Androida", "Pobierz APK"], windows: ["Windows", "Pobierz dla Windows", "Pobierz dla Windows"], windowsPortable: ["Windows portable", "Pobierz portable ZIP", "Pobierz ZIP"], macos: ["macOS", "Pobierz dla macOS", "Pobierz dla macOS"], linux: ["Linux", "Pobierz dla Linux", "Pobierz dla Linux"], ios: ["iOS", "Build iOS", "Niedostępne"], web: ["Web", "Pobierz build web", "Pobierz Web ZIP"], server: ["Serwer", "Pobierz backend", "Pobierz backend"], landing: ["Landing/site", "Pobierz pakiet site", "Pobierz site ZIP"], checksums: ["Checksums", "Pobierz checksums", "Pobierz checksums"] },
      landing: { eyebrow: "Prywatny komunikator dla ludzi, którym ufasz", copy: "Twoja osobista przestrzeń do rozmów z rodziną, bliskimi znajomymi i małymi zespołami: wiadomości, pliki i połączenia z lokalną historią oraz wyborem serwera.", web: "Otwórz wersję web", featuresEyebrow: "Dla Twojego kręgu", featuresTitle: "Spokojne miejsce do rozmów, dzielenia się i kontroli.", featuresCopy: "Hestia skupia się na osobach, które wybierasz: rodzinie, bliskich znajomych i małych zespołach, które chcą prywatności bez złożoności.", howEyebrow: "Jak to działa", howTitle: "Cztery kroki od instalacji do rozmowy.", downloadsEyebrow: "Wybierz klienta", downloadsTitle: "Pobieranie", downloadsCopy: "Hestia zaleca klienta dla urządzenia, ale pobieranie startuje tylko po wyborze.", releaseDetails: "Szczegóły wydania", releaseNotes: "Notatki wydania", privacyEyebrow: "Model prywatności", privacyTitle: "Prywatność, którą łatwo zrozumieć." },
      downloads: { eyebrow: "Pliki wydania", title: "Pobierz Hestia", copy: "Linki prowadzą do assets w GitHub Releases; latest.json obsługuje aktualną wersję i sprawdzanie aktualizacji.", recommended: "Zalecane pobranie", notes: "Notatki wydania", current: "Bieżące wydanie", version: "Wersja", sectionCopy: "Pliki są hostowane w GitHub Releases. Checksums służą do weryfikacji przed instalacją.", releasePage: "Strona wydania GitHub", checksums: "Checksums", serverGuide: "Konfiguracja serwera", available: "Dostępne pliki", unavailable: "Później", status: "Status", installTitle: "Bezpieczna instalacja", installSteps: ["Pobierz plik dla swojej platformy.", "Zweryfikuj checksum SHA-256.", "Zainstaluj lub uruchom pakiet."] },
      server: { eyebrow: "Self-hosting", title: "Instrukcja konfiguracji serwera", intro: "Uruchom serwer Hestia dla swoich użytkowników. Serwer przekazuje szyfrowany ruch i signaling; wiadomości i pliki plaintext nie powinny być na nim przechowywane.", note: "Ważne: self-hosted serwer nadal obsługuje metadata, takie jak konta, czas połączeń, IP i stan dostarczenia.", toc: ["Wymagania", "Przed startem", "Kod serwera", "Environment", "Uruchomienie", "HTTPS / WSS", "TURN dla rozmów", "Klient", "Weryfikacja", "Bezpieczeństwo", "Problemy"] },
      privacyPage: { eyebrow: "Model bezpieczeństwa", title: "Prywatność i bezpieczeństwo", intro: "Hestia jest projektowana jako privacy-first komunikator ograniczający ekspozycję danych po stronie serwera. W obecnej architekturze wiadomości i pliki są szyfrowane po stronie klienta przed wysłaniem.", note: "Ta strona opisuje zamierzone właściwości i ograniczenia. Nie jest obietnicą anonimowości ani idealnej ochrony.", toc: ["Chronione dane", "Widoczne dla serwera", "Model zaufania", "Niechronione", "Dane lokalne", "Push", "Model serwera", "Self-hosted", "Zalecenia", "Ograniczenia", "Przyszłość"] },
    },
    es: {
      nav: ["Funciones", "Privacidad", "Servidor", "Descargas"],
      footer: ["Privacidad", "Código fuente", "Documentación", "Guía del servidor"],
      common: { version: "Versión", recommended: "Recomendado para {platform}. La descarga empieza solo después de hacer clic.", unknown: "No se pudo identificar la plataforma; no se inicia ninguna descarga automática.", viewDownloads: "Ver todas las descargas", type: "Tipo", size: "Tamaño" },
      platform: { android: ["Android", "Descargar para Android", "Descargar APK"], windows: ["Windows", "Descargar para Windows", "Descargar para Windows"], windowsPortable: ["Windows portable", "Descargar portable ZIP", "Descargar ZIP"], macos: ["macOS", "Descargar para macOS", "Descargar para macOS"], linux: ["Linux", "Descargar para Linux", "Descargar para Linux"], ios: ["iOS", "Build iOS", "No disponible"], web: ["Web", "Descargar build web", "Descargar Web ZIP"], server: ["Servidor", "Descargar backend", "Descargar backend"], landing: ["Landing/site", "Descargar paquete site", "Descargar site ZIP"], checksums: ["Checksums", "Descargar checksums", "Descargar checksums"] },
      landing: { eyebrow: "Mensajero privado para personas en las que confías", copy: "Tu espacio personal para comunicarte con familia, amistades cercanas y equipos pequeños: mensajes, archivos y llamadas con historial local y un servidor que puedes elegir.", web: "Abrir versión web", featuresEyebrow: "Hecho para tu círculo", featuresTitle: "Un lugar tranquilo para hablar, compartir y mantener el control.", featuresCopy: "Hestia se centra en las personas que eliges: familia, amistades cercanas y equipos pequeños que quieren privacidad sin complejidad.", howEyebrow: "Cómo funciona", howTitle: "Cuatro pasos desde instalar hasta conversar.", downloadsEyebrow: "Elige tu cliente", downloadsTitle: "Descargas", downloadsCopy: "Hestia recomienda el cliente correcto, pero la descarga solo empieza cuando lo eliges.", releaseDetails: "Detalles de la versión", releaseNotes: "Notas de la versión", privacyEyebrow: "Modelo de privacidad", privacyTitle: "Privacidad fácil de entender." },
      downloads: { eyebrow: "Descargas de versión", title: "Obtener Hestia", copy: "Los enlaces apuntan a assets de GitHub Releases; latest.json mantiene la versión actual y el update checker.", recommended: "Descarga recomendada", notes: "Notas de la versión", current: "Versión actual", version: "Versión", sectionCopy: "Los archivos están alojados en GitHub Releases. Usa checksums para verificar antes de instalar.", releasePage: "Página del release en GitHub", checksums: "Checksums", serverGuide: "Guía del servidor", available: "Descargas disponibles", unavailable: "Más adelante", status: "Estado", installTitle: "Instalación segura", installSteps: ["Descarga el archivo para tu plataforma.", "Verifica el checksum SHA-256.", "Instala o ejecuta el paquete."] },
      server: { eyebrow: "Self-hosting", title: "Guía de configuración del servidor", intro: "Ejecuta un servidor Hestia para tus usuarios. El servidor retransmite tráfico cifrado y signaling; mensajes y archivos plaintext no deberían guardarse en el servidor.", note: "Importante: un servidor self-hosted aún maneja metadata como cuentas, tiempos de conexión, IP y estado de entrega.", toc: ["Requisitos", "Antes de empezar", "Código", "Environment", "Iniciar", "HTTPS / WSS", "TURN para llamadas", "Cliente", "Verificar", "Seguridad", "Problemas"] },
      privacyPage: { eyebrow: "Modelo de seguridad", title: "Privacidad y seguridad", intro: "Hestia está diseñada como mensajero privacy-first para reducir la exposición de datos en el servidor. En la arquitectura actual, mensajes y archivos se cifran en el cliente antes de enviarse.", note: "Esta página describe propiedades previstas y limitaciones conocidas. No promete anonimato ni protección perfecta.", toc: ["Datos protegidos", "Visible al servidor", "Modelo de confianza", "No protegido", "Datos locales", "Push", "Modelo servidor", "Self-hosted", "Recomendaciones", "Limitaciones", "Futuro"] },
    },
    cs: {
      nav: ["Funkce", "Soukromí", "Server", "Stahování"],
      footer: ["Soukromí", "Zdrojový kód", "Dokumentace", "Nastavení serveru"],
      common: { version: "Verze", recommended: "Doporučeno pro {platform}. Stahování začne až po kliknutí.", unknown: "Platformu se nepodařilo rozpoznat; nic se nestáhne automaticky.", viewDownloads: "Všechna stahování", type: "Typ", size: "Velikost" },
      platform: { android: ["Android", "Stáhnout pro Android", "Stáhnout APK"], windows: ["Windows", "Stáhnout pro Windows", "Stáhnout pro Windows"], windowsPortable: ["Windows portable", "Stáhnout portable ZIP", "Stáhnout ZIP"], macos: ["macOS", "Stáhnout pro macOS", "Stáhnout pro macOS"], linux: ["Linux", "Stáhnout pro Linux", "Stáhnout pro Linux"], ios: ["iOS", "Build iOS", "Nedostupné"], web: ["Web", "Stáhnout web build", "Stáhnout Web ZIP"], server: ["Server", "Stáhnout backend", "Stáhnout backend"], landing: ["Landing/site", "Stáhnout site balíček", "Stáhnout site ZIP"], checksums: ["Checksums", "Stáhnout checksums", "Stáhnout checksums"] },
      landing: { eyebrow: "Soukromý messenger pro lidi, kterým věříte", copy: "Váš osobní prostor pro komunikaci s rodinou, blízkými přáteli a malými týmy: zprávy, soubory a hovory s lokální historií a serverem, který si můžete vybrat.", web: "Otevřít webovou verzi", featuresEyebrow: "Pro váš okruh lidí", featuresTitle: "Klidné místo pro rozhovor, sdílení a kontrolu.", featuresCopy: "Hestia se soustředí na lidi, které si vyberete: rodinu, blízké přátele a malé týmy, které chtějí soukromí bez složitosti.", howEyebrow: "Jak to funguje", howTitle: "Čtyři kroky od instalace ke konverzaci.", downloadsEyebrow: "Vyberte klienta", downloadsTitle: "Stahování", downloadsCopy: "Hestia doporučí klienta pro zařízení, ale stahování začne jen po výběru.", releaseDetails: "Detaily vydání", releaseNotes: "Poznámky k vydání", privacyEyebrow: "Model soukromí", privacyTitle: "Soukromí, kterému lze rozumět." },
      downloads: { eyebrow: "Stažení vydání", title: "Získat Hestia", copy: "Odkazy vedou na assets v GitHub Releases; latest.json drží aktuální verzi a update checker.", recommended: "Doporučené stažení", notes: "Poznámky k vydání", current: "Aktuální vydání", version: "Verze", sectionCopy: "Soubory jsou hostované v GitHub Releases. Checksums slouží k ověření před instalací.", releasePage: "Stránka vydání GitHub", checksums: "Checksums", serverGuide: "Nastavení serveru", available: "Dostupná stažení", unavailable: "Později", status: "Stav", installTitle: "Bezpečná instalace", installSteps: ["Stáhněte soubor pro svou platformu.", "Ověřte SHA-256 checksum.", "Nainstalujte nebo spusťte balíček."] },
      server: { eyebrow: "Self-hosting", title: "Průvodce nastavením serveru", intro: "Spusťte server Hestia pro své uživatele. Server přenáší šifrovaný provoz a signaling; plaintext zprávy a soubory by na něm neměly být uloženy.", note: "Důležité: self-hosted server stále zpracovává metadata jako účty, časy připojení, IP a stav doručení.", toc: ["Požadavky", "Před začátkem", "Kód serveru", "Environment", "Spuštění", "HTTPS / WSS", "TURN pro hovory", "Klient", "Ověření", "Bezpečnost", "Problémy"] },
      privacyPage: { eyebrow: "Model bezpečnosti", title: "Soukromí a bezpečnost", intro: "Hestia je navržena jako privacy-first messenger omezující vystavení dat na serveru. V aktuální architektuře se zprávy a soubory šifrují v klientu před odesláním.", note: "Tato stránka popisuje zamýšlené vlastnosti a omezení. Neslibuje anonymitu ani dokonalou ochranu.", toc: ["Chráněná data", "Viditelné serveru", "Model důvěry", "Nechráněné", "Lokální data", "Push", "Model serveru", "Self-hosted", "Doporučení", "Omezení", "Budoucnost"] },
    },
    de: {
      nav: ["Funktionen", "Datenschutz", "Server", "Downloads"],
      footer: ["Datenschutz", "Quellcode", "Dokumentation", "Server-Anleitung"],
      common: { version: "Version", recommended: "Empfohlen für {platform}. Der Download startet erst nach einem Klick.", unknown: "Die Plattform wurde nicht erkannt; es startet kein automatischer Download.", viewDownloads: "Alle Downloads", type: "Typ", size: "Größe" },
      platform: { android: ["Android", "Für Android herunterladen", "APK herunterladen"], windows: ["Windows", "Für Windows herunterladen", "Für Windows herunterladen"], windowsPortable: ["Windows portable", "Portable ZIP herunterladen", "ZIP herunterladen"], macos: ["macOS", "Für macOS herunterladen", "Für macOS herunterladen"], linux: ["Linux", "Für Linux herunterladen", "Für Linux herunterladen"], ios: ["iOS", "iOS-Build", "Nicht verfügbar"], web: ["Web", "Web-Build herunterladen", "Web ZIP herunterladen"], server: ["Server", "Backend herunterladen", "Backend herunterladen"], landing: ["Landing/site", "Site-Paket herunterladen", "Site ZIP herunterladen"], checksums: ["Checksums", "Checksums herunterladen", "Checksums herunterladen"] },
      landing: { eyebrow: "Privater Messenger für Menschen, denen du vertraust", copy: "Dein persönlicher Raum für Kommunikation mit Familie, engen Freunden und kleinen Teams: Nachrichten, Dateien und Anrufe mit lokaler Historie und einem Server, den du wählen kannst.", web: "Web-Version öffnen", featuresEyebrow: "Gemacht für deinen Kreis", featuresTitle: "Ein ruhiger Ort zum Reden, Teilen und Kontrollieren.", featuresCopy: "Hestia konzentriert sich auf die Menschen, die du auswählst: Familie, enge Freunde und kleine Teams, die Privatsphäre ohne Komplexität wollen.", howEyebrow: "So funktioniert es", howTitle: "Vier Schritte von der Installation zum Gespräch.", downloadsEyebrow: "Client wählen", downloadsTitle: "Downloads", downloadsCopy: "Hestia empfiehlt den passenden Client, aber der Download startet erst nach Ihrer Auswahl.", releaseDetails: "Release-Details", releaseNotes: "Release Notes", privacyEyebrow: "Datenschutzmodell", privacyTitle: "Datenschutz, den man verstehen kann." },
      downloads: { eyebrow: "Release-Downloads", title: "Hestia herunterladen", copy: "Links zeigen auf GitHub Release assets; latest.json liefert aktuelle Version und Update-Prüfung.", recommended: "Empfohlener Download", notes: "Release Notes", current: "Aktuelles Release", version: "Version", sectionCopy: "Dateien liegen in GitHub Releases. Checksums helfen bei der Prüfung vor Installation.", releasePage: "GitHub Release-Seite", checksums: "Checksums", serverGuide: "Server-Anleitung", available: "Verfügbare Downloads", unavailable: "Kommt später", status: "Status", installTitle: "Sicher installieren", installSteps: ["Datei für deine Plattform herunterladen.", "SHA-256 Checksum prüfen.", "Paket installieren oder starten."] },
      server: { eyebrow: "Self-hosting", title: "Server-Einrichtungsanleitung", intro: "Betreiben Sie einen Hestia-Server für Ihre Nutzer. Der Server leitet verschlüsselten Traffic und Signaling weiter; Plaintext-Nachrichten und Dateien sollten nicht auf dem Server gespeichert werden.", note: "Wichtig: Ein self-hosted Server verarbeitet weiterhin Metadata wie Konten, Verbindungszeiten, IPs und Zustellstatus.", toc: ["Anforderungen", "Vorbereitung", "Server-Code", "Environment", "Start", "HTTPS / WSS", "TURN für Anrufe", "Client", "Prüfen", "Sicherheit", "Probleme"] },
      privacyPage: { eyebrow: "Sicherheitsmodell", title: "Datenschutz & Sicherheit", intro: "Hestia ist als privacy-first Messenger konzipiert, der serverseitige Datenexposition reduziert. In der aktuellen Architektur werden Nachrichten und Dateien vor dem Senden im Client verschlüsselt.", note: "Diese Seite beschreibt beabsichtigte Eigenschaften und bekannte Grenzen. Sie verspricht keine Anonymität und keinen perfekten Schutz.", toc: ["Geschützte Daten", "Für Server sichtbar", "Vertrauensmodell", "Nicht geschützt", "Lokale Daten", "Push", "Servermodell", "Self-hosted", "Empfehlungen", "Grenzen", "Zukunft"] },
    },
  };

  Object.keys(overlays).forEach((lang) => {
    copy[lang] = merge(copy.en, overlays[lang]);
  });

  const serverCodes = copy.en.server.sections.map((section) => section[2]);
  const privacySections = {
    ru: [
      ["Что нужно для запуска", ["Минимум: 1 vCPU, 1 GB RAM, 10-20 GB SSD.", "Рекомендуется: 2 vCPU, 2-4 GB RAM, 30-50 GB SSD.", "Рекомендуются Linux, домен, HTTPS/WSS и TURN для сложных сетей звонков."]],
      ["Что подготовить заранее", ["VPS или сервер с shell-доступом.", "Домен или поддомен.", "Node.js и npm.", "Git.", "Доступ к firewall.", "Опционально Nginx или Caddy.", "Опционально Firebase для Android push.", "Опционально TURN для relay fallback."]],
      ["Получить код сервера", ["Замените placeholder репозитория на реальный URL Hestia server, когда он будет опубликован."], serverCodes[2]],
      ["Настроить environment", ["Создайте .env в директории сервера. Храните токены приватно и не публикуйте service account файлы."], serverCodes[3]],
      ["Запустить сервер", ["Сервер должен отдавать лендинг на /, config на /api/config, WebSocket на /ws и иметь доступ на запись к persistence storage."], serverCodes[4]],
      ["Reverse proxy, HTTPS и WSS", ["Для production разместите один Node.js app Hestia за TLS reverse proxy. Отдельный api subdomain не требуется."], serverCodes[5]],
      ["Опционально TURN для звонков", ["Прямой WebRTC работает лучше всего. Ограниченные сети могут требовать TURN relay fallback через TURN_SERVERS."], serverCodes[6]],
      ["Подключить клиент", ["Откройте Hestia, введите URL одного домена при необходимости, зарегистрируйтесь или войдите, затем проверьте сообщения и звонки."]],
      ["Проверочный список", ["/ отдает лендинг.", "/releases/latest.json доступен.", "/api/config доступен по HTTPS.", "WebSocket подключается по /ws.", "Регистрация или вход работают.", "Два пользователя обмениваются сообщениями.", "Offline delivery, передача файлов и call signaling работают."]],
      ["Основы безопасности", ["Используйте HTTPS/WSS.", "Выберите сильный ADMIN_TOKEN.", "Ограничьте регистрацию при необходимости.", "Обновляйте сервер и ОС.", "Не раскрывайте debug logs.", "Делайте резервные копии аккуратно.", "Помните, что metadata может быть видима."]],
      ["Типовые проблемы", ["Если приложение не подключается, проверьте URL, DNS, firewall, proxy и TLS.", "Если WebSocket падает, проверьте upgrade headers.", "Если push не работает, проверьте Firebase config.", "Если звонки не проходят за NAT, настройте TURN.", "Если файлы отклоняются, проверьте лимиты и диск."]],
    ],
    uk: [
      ["Що потрібно для запуску", ["Мінімум: 1 vCPU, 1 GB RAM, 10-20 GB SSD.", "Рекомендовано: 2 vCPU, 2-4 GB RAM, 30-50 GB SSD.", "Рекомендовані Linux, домен, HTTPS/WSS і TURN для складних мереж дзвінків."]],
      ["Що підготувати заздалегідь", ["VPS або сервер із shell-доступом.", "Домен або піддомен.", "Node.js і npm.", "Git.", "Доступ до firewall.", "Опційно Nginx або Caddy.", "Опційно Firebase для Android push.", "Опційно TURN для relay fallback."]],
      ["Отримати код сервера", ["Замініть placeholder репозиторію на реальний URL Hestia server, коли він буде опублікований."], serverCodes[2]],
      ["Налаштувати environment", ["Створіть .env у директорії сервера. Тримайте токени приватними й не публікуйте service account файли."], serverCodes[3]],
      ["Запустити сервер", ["Сервер має віддавати лендинг на /, config на /api/config, WebSocket на /ws і мати запис у persistence storage."], serverCodes[4]],
      ["Reverse proxy, HTTPS і WSS", ["Для production розмістіть один Node.js app Hestia за TLS reverse proxy. Окремий api subdomain не потрібен."], serverCodes[5]],
      ["Опційно TURN для дзвінків", ["Прямий WebRTC працює найкраще. Обмежені мережі можуть потребувати TURN relay fallback через TURN_SERVERS."], serverCodes[6]],
      ["Підключити клієнт", ["Відкрийте Hestia, введіть URL одного домену за потреби, зареєструйтеся або увійдіть, потім перевірте повідомлення й дзвінки."]],
      ["Список перевірки", ["/ віддає лендинг.", "/releases/latest.json доступний.", "/api/config доступний через HTTPS.", "WebSocket підключається через /ws.", "Реєстрація або вхід працюють.", "Два користувачі обмінюються повідомленнями.", "Offline delivery, файли та call signaling працюють."]],
      ["Основи безпеки", ["Використовуйте HTTPS/WSS.", "Оберіть сильний ADMIN_TOKEN.", "Обмежте реєстрацію за потреби.", "Оновлюйте сервер і ОС.", "Не відкривайте debug logs.", "Робіть резервні копії обережно.", "Пам'ятайте, що metadata може бути видимою."]],
      ["Типові проблеми", ["Якщо застосунок не підключається, перевірте URL, DNS, firewall, proxy і TLS.", "Якщо WebSocket не працює, перевірте upgrade headers.", "Якщо push не працює, перевірте Firebase config.", "Якщо дзвінки не проходять за NAT, налаштуйте TURN.", "Якщо файли відхиляються, перевірте ліміти й диск."]],
    ],
    pl: [
      ["Wymagania", ["Minimum: 1 vCPU, 1 GB RAM, 10-20 GB SSD.", "Zalecane: 2 vCPU, 2-4 GB RAM, 30-50 GB SSD.", "Zalecane są Linux, domena, HTTPS/WSS i TURN dla trudnych sieci rozmów."]],
      ["Co przygotować", ["VPS lub serwer z dostępem shell.", "Domena lub subdomena.", "Node.js i npm.", "Git.", "Dostęp do firewalla.", "Opcjonalnie Nginx lub Caddy.", "Opcjonalnie Firebase dla Android push.", "Opcjonalnie TURN dla relay fallback."]],
      ["Pobierz kod serwera", ["Zastąp placeholder repozytorium prawdziwym URL Hestia server, gdy zostanie opublikowany."], serverCodes[2]],
      ["Skonfiguruj environment", ["Utwórz .env w katalogu serwera. Trzymaj tokeny prywatnie i nie publikuj plików service account."], serverCodes[3]],
      ["Uruchom serwer", ["Serwer powinien udostępniać landing na /, config na /api/config, WebSocket na /ws i mieć zapis do persistence storage."], serverCodes[4]],
      ["Reverse proxy, HTTPS i WSS", ["W produkcji umieść jedną aplikację Node.js Hestia za TLS reverse proxy. Osobna subdomena api nie jest wymagana."], serverCodes[5]],
      ["Opcjonalnie TURN dla rozmów", ["Bezpośredni WebRTC działa najlepiej. Ograniczone sieci mogą wymagać TURN relay fallback przez TURN_SERVERS."], serverCodes[6]],
      ["Połącz klienta", ["Otwórz Hestia, wpisz URL jednej domeny, jeśli trzeba, zarejestruj się lub zaloguj, potem przetestuj wiadomości i rozmowy."]],
      ["Lista weryfikacji", ["/ serwuje landing.", "/releases/latest.json jest dostępny.", "/api/config jest dostępny przez HTTPS.", "WebSocket łączy się przez /ws.", "Rejestracja lub logowanie działa.", "Dwóch użytkowników wymienia wiadomości.", "Offline delivery, pliki i call signaling działają."]],
      ["Podstawy bezpieczeństwa", ["Używaj HTTPS/WSS.", "Wybierz silny ADMIN_TOKEN.", "Ogranicz rejestrację, gdy trzeba.", "Aktualizuj serwer i OS.", "Nie ujawniaj debug logs.", "Ostrożnie twórz backupy.", "Pamiętaj, że metadata może być widoczna."]],
      ["Rozwiązywanie problemów", ["Jeśli aplikacja nie łączy się, sprawdź URL, DNS, firewall, proxy i TLS.", "Jeśli WebSocket pada, sprawdź upgrade headers.", "Jeśli push nie działa, sprawdź Firebase config.", "Jeśli rozmowy zawodzą za NAT, skonfiguruj TURN.", "Jeśli pliki są odrzucane, sprawdź limity i dysk."]],
    ],
    es: [
      ["Requisitos", ["Mínimo: 1 vCPU, 1 GB RAM, 10-20 GB SSD.", "Recomendado: 2 vCPU, 2-4 GB RAM, 30-50 GB SSD.", "Se recomiendan Linux, dominio, HTTPS/WSS y TURN para redes de llamadas difíciles."]],
      ["Antes de empezar", ["VPS o servidor con acceso shell.", "Dominio o subdominio.", "Node.js y npm.", "Git.", "Acceso al firewall.", "Opcional Nginx o Caddy.", "Opcional Firebase para Android push.", "Opcional TURN para relay fallback."]],
      ["Obtener el código", ["Sustituye el placeholder del repositorio por el URL real del servidor Hestia cuando se publique."], serverCodes[2]],
      ["Configurar environment", ["Crea un .env en el directorio del servidor. Mantén tokens privados y no publiques archivos service account."], serverCodes[3]],
      ["Iniciar el servidor", ["El servidor debe exponer landing en /, config en /api/config, WebSocket en /ws y poder escribir en persistence storage."], serverCodes[4]],
      ["Reverse proxy, HTTPS y WSS", ["En producción, coloca una sola app Node.js de Hestia detrás de un TLS reverse proxy. No se requiere subdominio api separado."], serverCodes[5]],
      ["TURN opcional para llamadas", ["WebRTC directo funciona mejor. Redes restrictivas pueden necesitar TURN relay fallback mediante TURN_SERVERS."], serverCodes[6]],
      ["Conectar el cliente", ["Abre Hestia, introduce el URL de un solo dominio si hace falta, regístrate o inicia sesión, y prueba mensajes y llamadas."]],
      ["Lista de verificación", ["/ sirve el landing.", "/releases/latest.json es accesible.", "/api/config es accesible por HTTPS.", "WebSocket conecta por /ws.", "Registro o login funciona.", "Dos usuarios intercambian mensajes.", "Offline delivery, archivos y call signaling funcionan."]],
      ["Seguridad básica", ["Usa HTTPS/WSS.", "Elige un ADMIN_TOKEN fuerte.", "Restringe registro si hace falta.", "Actualiza servidor y SO.", "No expongas debug logs.", "Haz backups con cuidado.", "Recuerda que metadata puede ser visible."]],
      ["Problemas comunes", ["Si la app no conecta, revisa URL, DNS, firewall, proxy y TLS.", "Si WebSocket falla, revisa upgrade headers.", "Si push falla, revisa Firebase config.", "Si llamadas fallan detrás de NAT, configura TURN.", "Si archivos son rechazados, revisa límites y disco."]],
    ],
    cs: [
      ["Požadavky", ["Minimum: 1 vCPU, 1 GB RAM, 10-20 GB SSD.", "Doporučeno: 2 vCPU, 2-4 GB RAM, 30-50 GB SSD.", "Doporučuje se Linux, doména, HTTPS/WSS a TURN pro složité sítě hovorů."]],
      ["Před začátkem", ["VPS nebo server se shell přístupem.", "Doména nebo subdoména.", "Node.js a npm.", "Git.", "Přístup k firewallu.", "Volitelně Nginx nebo Caddy.", "Volitelně Firebase pro Android push.", "Volitelně TURN pro relay fallback."]],
      ["Získat kód serveru", ["Nahraďte placeholder repozitáře skutečným URL Hestia serveru, až bude publikován."], serverCodes[2]],
      ["Nastavit environment", ["Vytvořte .env v adresáři serveru. Tokeny držte soukromé a nepublikujte service account soubory."], serverCodes[3]],
      ["Spustit server", ["Server má poskytovat landing na /, config na /api/config, WebSocket na /ws a mít zápis do persistence storage."], serverCodes[4]],
      ["Reverse proxy, HTTPS a WSS", ["V produkci dejte jednu Node.js aplikaci Hestia za TLS reverse proxy. Samostatná api subdoména není nutná."], serverCodes[5]],
      ["Volitelně TURN pro hovory", ["Přímý WebRTC funguje nejlépe. Omezené sítě mohou vyžadovat TURN relay fallback přes TURN_SERVERS."], serverCodes[6]],
      ["Připojit klienta", ["Otevřete Hestia, zadejte URL jedné domény, pokud je potřeba, registrujte se nebo přihlaste a otestujte zprávy a hovory."]],
      ["Kontrolní seznam", ["/ obsluhuje landing.", "/releases/latest.json je dostupný.", "/api/config je dostupný přes HTTPS.", "WebSocket se připojí přes /ws.", "Registrace nebo přihlášení funguje.", "Dva uživatelé si vymění zprávy.", "Offline delivery, soubory a call signaling fungují."]],
      ["Základy bezpečnosti", ["Používejte HTTPS/WSS.", "Zvolte silný ADMIN_TOKEN.", "Omezte registraci, když je potřeba.", "Aktualizujte server a OS.", "Nevystavujte debug logs.", "Zálohujte opatrně.", "Pamatujte, že metadata mohou být viditelná."]],
      ["Řešení problémů", ["Pokud se aplikace nepřipojí, zkontrolujte URL, DNS, firewall, proxy a TLS.", "Pokud WebSocket selže, zkontrolujte upgrade headers.", "Pokud push nefunguje, zkontrolujte Firebase config.", "Pokud hovory selžou za NAT, nastavte TURN.", "Pokud jsou soubory odmítnuty, zkontrolujte limity a disk."]],
    ],
    de: [
      ["Anforderungen", ["Minimum: 1 vCPU, 1 GB RAM, 10-20 GB SSD.", "Empfohlen: 2 vCPU, 2-4 GB RAM, 30-50 GB SSD.", "Linux, Domain, HTTPS/WSS und TURN für schwierige Anrufnetzwerke werden empfohlen."]],
      ["Vor dem Start", ["VPS oder Server mit Shell-Zugriff.", "Domain oder Subdomain.", "Node.js und npm.", "Git.", "Firewall-Zugriff.", "Optional Nginx oder Caddy.", "Optional Firebase für Android Push.", "Optional TURN für relay fallback."]],
      ["Server-Code holen", ["Ersetzen Sie den Repository-Platzhalter durch die echte Hestia-Server-URL, sobald sie veröffentlicht ist."], serverCodes[2]],
      ["Environment konfigurieren", ["Erstellen Sie eine .env im Serververzeichnis. Tokens privat halten und keine service account Dateien veröffentlichen."], serverCodes[3]],
      ["Server starten", ["Der Server sollte Landing auf /, Config auf /api/config, WebSocket auf /ws und Schreibzugriff auf persistence storage bereitstellen."], serverCodes[4]],
      ["Reverse Proxy, HTTPS und WSS", ["In Produktion eine einzelne Hestia Node.js App hinter einen TLS reverse proxy stellen. Eine separate api-Subdomain ist nicht nötig."], serverCodes[5]],
      ["Optional TURN für Anrufe", ["Direktes WebRTC funktioniert am besten. Restriktive Netzwerke können TURN relay fallback über TURN_SERVERS erfordern."], serverCodes[6]],
      ["Client verbinden", ["Hestia öffnen, bei Bedarf die Ein-Domain-URL eingeben, registrieren oder anmelden, dann Nachrichten und Anrufe testen."]],
      ["Prüfliste", ["/ liefert das Landing.", "/releases/latest.json ist erreichbar.", "/api/config ist über HTTPS erreichbar.", "WebSocket verbindet über /ws.", "Registrierung oder Login funktioniert.", "Zwei Nutzer können Nachrichten austauschen.", "Offline delivery, Dateiübertragung und call signaling funktionieren."]],
      ["Sicherheitsgrundlagen", ["HTTPS/WSS verwenden.", "Starken ADMIN_TOKEN wählen.", "Registrierung bei Bedarf einschränken.", "Server und OS aktuell halten.", "Debug logs nicht offenlegen.", "Backups sorgfältig schützen.", "Metadata kann weiterhin sichtbar sein."]],
      ["Fehlerbehebung", ["Wenn die App nicht verbindet, URL, DNS, Firewall, Proxy und TLS prüfen.", "Wenn WebSocket fehlschlägt, upgrade headers prüfen.", "Wenn Push nicht funktioniert, Firebase config prüfen.", "Wenn Anrufe hinter NAT scheitern, TURN konfigurieren.", "Wenn Dateien abgelehnt werden, Limits und Speicherplatz prüfen."]],
    ],
  };

  Object.keys(privacySections).forEach((lang) => {
    copy[lang].server.sections = privacySections[lang];
  });

  const privacyLocalized = {
    ru: [
      ["Что защищено", ["Текстовые сообщения шифруются на клиенте до отправки; сервер не должен видеть plaintext.", "Файлы шифруются до загрузки; сервер должен хранить encrypted blobs.", "Звонки используют WebRTC с DTLS-SRTP для шифрования media in transit.", "История сообщений хранится на устройстве пользователя, а не централизованно как plaintext."]],
      ["Что может видеть сервер", ["Какие аккаунты общаются.", "Время подключений и паттерны активности.", "Частоту сообщений и состояние доставки.", "Размеры зашифрованных файлов.", "Call signaling events.", "IP-адреса и connection metadata."]],
      ["Модель доверия и fingerprint", ["У каждого пользователя должен быть public key.", "Первый контакт использует trust on first use.", "Fingerprint или QR verification помогает подтвердить ключ.", "Если ключ меняется, общение должно блокироваться до повторной проверки.", "Без проверки остается риск MITM."]],
      ["Что не защищено по design", ["Скомпрометированные устройства.", "Malware на устройстве.", "Запись экрана или локальный доступ.", "Слабые пароли устройства.", "Социальная инженерия.", "Ручное копирование чувствительного контента."]],
      ["Локальные данные", ["Сообщения и файлы хранятся локально для удобства. Расшифрованные данные существуют на устройстве во время чтения, открытия файлов или звонков."]],
      ["Push-уведомления", ["Push используется как wake-up mechanism. По умолчанию payload не должен содержать plaintext сообщений и должен нести минимальную metadata."]],
      ["Модель сервера", ["Сервер ретранслирует encrypted traffic, координирует доставку и может временно хранить encrypted payloads для offline delivery.", "Сервер контролируется оператором; в self-hosted модели это можете быть вы или ваша организация."]],
      ["Self-hosted последствия", ["Свой сервер повышает контроль над инфраструктурой, но не скрывает metadata от этого сервера.", "Вы отвечаете за TLS, logs, backups, updates и operational security."]],
      ["Рекомендации", ["Проверяйте fingerprints важных контактов.", "Используйте сильные пароли.", "Держите устройства заблокированными и обновленными.", "Регулярно обновляйте Hestia.", "Доверяйте оператору сервера или рассмотрите self-hosting.", "Не игнорируйте неожиданные key-change warnings."]],
      ["Ограничения", ["Нет anonymous routing по умолчанию.", "Metadata не скрыта полностью.", "Текущая модель доверия включает TOFU.", "На этой странице не заявляется внешний security audit.", "Компрометация endpoint может раскрыть локальный plaintext."]],
      ["Будущие улучшения", ["Более сильный UX проверки ключей, опциональное at-rest encryption, больше metadata minimization и дополнительные transport privacy options."]],
    ],
    uk: [
      ["Що захищено", ["Текстові повідомлення шифруються на клієнті до надсилання; сервер не має бачити plaintext.", "Файли шифруються до завантаження; сервер має зберігати encrypted blobs.", "Дзвінки використовують WebRTC з DTLS-SRTP для шифрування media in transit.", "Історія повідомлень зберігається на пристрої користувача, а не централізовано як plaintext."]],
      ["Що може бачити сервер", ["Які акаунти спілкуються.", "Час підключень і патерни активності.", "Частоту повідомлень і стан доставки.", "Розміри зашифрованих файлів.", "Call signaling events.", "IP-адреси та connection metadata."]],
      ["Модель довіри та fingerprint", ["Кожен користувач має мати public key.", "Перший контакт використовує trust on first use.", "Fingerprint або QR verification допомагає підтвердити ключ.", "Якщо ключ змінюється, спілкування має блокуватися до повторної перевірки.", "Без перевірки залишається ризик MITM."]],
      ["Що не захищено за design", ["Скомпрометовані пристрої.", "Malware на пристрої.", "Запис екрана або локальний доступ.", "Слабкі паролі пристрою.", "Соціальна інженерія.", "Ручне копіювання чутливого контенту."]],
      ["Локальні дані", ["Повідомлення й файли зберігаються локально для зручності. Розшифровані дані існують на пристрої під час читання, відкриття файлів або дзвінків."]],
      ["Push-сповіщення", ["Push використовується як wake-up mechanism. За замовчуванням payload не має містити plaintext повідомлень і має нести мінімальну metadata."]],
      ["Модель сервера", ["Сервер ретранслює encrypted traffic, координує доставку й може тимчасово зберігати encrypted payloads для offline delivery.", "Сервер контролюється оператором; у self-hosted моделі це можете бути ви або ваша організація."]],
      ["Self-hosted наслідки", ["Власний сервер підвищує контроль над інфраструктурою, але не приховує metadata від цього сервера.", "Ви відповідаєте за TLS, logs, backups, updates і operational security."]],
      ["Рекомендації", ["Перевіряйте fingerprints важливих контактів.", "Використовуйте сильні паролі.", "Тримайте пристрої заблокованими й оновленими.", "Регулярно оновлюйте Hestia.", "Довіряйте оператору сервера або розгляньте self-hosting.", "Не ігноруйте несподівані key-change warnings."]],
      ["Обмеження", ["Немає anonymous routing за замовчуванням.", "Metadata не прихована повністю.", "Поточна модель довіри включає TOFU.", "На цій сторінці не заявлено зовнішній security audit.", "Компрометація endpoint може розкрити локальний plaintext."]],
      ["Майбутні покращення", ["Сильніший UX перевірки ключів, опційне at-rest encryption, більше metadata minimization і додаткові transport privacy options."]],
    ],
  };

  privacyLocalized.pl = [
    ["Co jest chronione", ["Wiadomości tekstowe są szyfrowane w kliencie przed wysłaniem; serwer nie powinien widzieć plaintext.", "Pliki są szyfrowane przed wysłaniem; serwer powinien przechowywać encrypted blobs.", "Rozmowy używają WebRTC z DTLS-SRTP do szyfrowania mediów w tranzycie.", "Historia wiadomości jest przechowywana na urządzeniu użytkownika, nie centralnie jako plaintext."]],
    ["Co widzi serwer", ["Które konta komunikują się.", "Czasy połączeń i wzorce aktywności.", "Częstotliwość wiadomości i stan dostarczenia.", "Rozmiary zaszyfrowanych plików.", "Zdarzenia call signaling.", "Adresy IP i connection metadata."]],
    ["Model zaufania i fingerprint", ["Każdy użytkownik powinien mieć public key.", "Pierwszy kontakt używa trust on first use.", "Fingerprint lub QR verification pomaga potwierdzić klucz.", "Po zmianie klucza komunikacja powinna być zablokowana do ponownej weryfikacji.", "Bez weryfikacji pozostaje ryzyko MITM."]],
    ["Czego nie chroni projekt", ["Skompromitowanych urządzeń.", "Malware na urządzeniu.", "Nagrywania ekranu lub lokalnego dostępu.", "Słabych haseł urządzenia.", "Socjotechniki.", "Ręcznego kopiowania wrażliwych treści."]],
    ["Dane lokalne", ["Wiadomości i pliki są przechowywane lokalnie dla wygody. Odszyfrowane dane istnieją na urządzeniu podczas czytania, otwierania plików lub rozmów."]],
    ["Powiadomienia push", ["Push ma działać jako mechanizm wybudzania. Domyślnie payload nie powinien zawierać plaintext wiadomości i powinien mieć minimalną metadata."]],
    ["Model serwera", ["Serwer przekazuje encrypted traffic, koordynuje dostarczanie i może tymczasowo przechowywać encrypted payloads dla offline delivery.", "Serwer kontroluje operator; w modelu self-hosted możesz to być Ty lub Twoja organizacja."]],
    ["Konsekwencje self-hosted", ["Własny serwer zwiększa kontrolę nad infrastrukturą, ale nie ukrywa metadata przed tym serwerem.", "Odpowiadasz za TLS, logs, backups, updates i operational security."]],
    ["Zalecenia", ["Weryfikuj fingerprints ważnych kontaktów.", "Używaj silnych haseł.", "Blokuj i aktualizuj urządzenia.", "Regularnie aktualizuj Hestia.", "Ufaj operatorowi serwera albo rozważ self-hosting.", "Nie ignoruj niespodziewanych key-change warnings."]],
    ["Ograniczenia", ["Brak anonymous routing domyślnie.", "Metadata nie jest całkowicie ukryta.", "Obecny model zaufania zawiera TOFU.", "Ta strona nie deklaruje zewnętrznego security audit.", "Kompromitacja endpointu może ujawnić lokalny plaintext."]],
    ["Przyszłość", ["Silniejszy UX weryfikacji kluczy, opcjonalne at-rest encryption, większe metadata minimization i dodatkowe transport privacy options."]],
  ];

  privacyLocalized.es = [
    ["Qué está protegido", ["Los mensajes se cifran en el cliente antes de enviarse; el servidor no debería ver plaintext.", "Los archivos se cifran antes de subir; el servidor debería guardar encrypted blobs.", "Las llamadas usan WebRTC con DTLS-SRTP para cifrar medios en tránsito.", "El historial se guarda en el dispositivo del usuario, no centralmente como plaintext."]],
    ["Qué puede ver el servidor", ["Qué cuentas se comunican.", "Tiempos de conexión y patrones de actividad.", "Frecuencia de mensajes y estado de entrega.", "Tamaños de archivos cifrados.", "Eventos de call signaling.", "Direcciones IP y connection metadata."]],
    ["Modelo de confianza y fingerprint", ["Cada usuario debería tener una public key.", "El primer contacto usa trust on first use.", "Fingerprint o QR verification ayuda a confirmar la clave.", "Si una clave cambia, la comunicación debería bloquearse hasta re-verificar.", "Sin verificación, sigue existiendo riesgo MITM."]],
    ["Qué no protege el diseño", ["Dispositivos comprometidos.", "Malware en el dispositivo.", "Grabación de pantalla o acceso local.", "Contraseñas débiles del dispositivo.", "Ingeniería social.", "Copiar manualmente contenido sensible."]],
    ["Datos locales", ["Mensajes y archivos se guardan localmente por usabilidad. Los datos descifrados existen en el dispositivo al leer, abrir archivos o participar en llamadas."]],
    ["Notificaciones push", ["Push se usa como mecanismo de activación. Por defecto, el payload no debería incluir plaintext de mensajes y debería llevar metadata mínima."]],
    ["Modelo del servidor", ["El servidor retransmite encrypted traffic, coordina entrega y puede guardar temporalmente encrypted payloads para offline delivery.", "El servidor lo controla su operador; en self-hosted puedes ser tú o tu organización."]],
    ["Implicaciones self-hosted", ["Tu propio servidor aumenta el control de infraestructura, pero no oculta metadata de ese servidor.", "Eres responsable de TLS, logs, backups, updates y operational security."]],
    ["Recomendaciones", ["Verifica fingerprints de contactos importantes.", "Usa contraseñas fuertes.", "Mantén dispositivos bloqueados y actualizados.", "Actualiza Hestia con regularidad.", "Confía en el operador del servidor o considera self-hosting.", "No ignores key-change warnings inesperados."]],
    ["Limitaciones", ["No hay anonymous routing por defecto.", "La metadata no se oculta por completo.", "El modelo actual incluye TOFU.", "Esta página no afirma un security audit externo.", "Un endpoint comprometido puede exponer plaintext local."]],
    ["Mejoras futuras", ["Mejor UX de verificación de claves, at-rest encryption opcional, más metadata minimization y opciones extra de transport privacy."]],
  ];

  privacyLocalized.cs = [
    ["Co je chráněno", ["Textové zprávy se šifrují v klientu před odesláním; server by neměl vidět plaintext.", "Soubory se šifrují před nahráním; server by měl ukládat encrypted blobs.", "Hovory používají WebRTC s DTLS-SRTP pro šifrování médií během přenosu.", "Historie zpráv je uložena na zařízení uživatele, ne centrálně jako plaintext."]],
    ["Co server vidí", ["Které účty komunikují.", "Časy připojení a vzorce aktivity.", "Frekvenci zpráv a stav doručení.", "Velikosti šifrovaných souborů.", "Události call signaling.", "IP adresy a connection metadata."]],
    ["Model důvěry a fingerprint", ["Každý uživatel by měl mít public key.", "První kontakt používá trust on first use.", "Fingerprint nebo QR verification pomáhá potvrdit klíč.", "Při změně klíče by komunikace měla být blokována do nového ověření.", "Bez ověření zůstává riziko MITM."]],
    ["Co návrh nechrání", ["Kompromitovaná zařízení.", "Malware na zařízení.", "Nahrávání obrazovky nebo lokální přístup.", "Slabá hesla zařízení.", "Sociální inženýrství.", "Ruční kopírování citlivého obsahu."]],
    ["Lokální data", ["Zprávy a soubory jsou kvůli použitelnosti uloženy lokálně. Dešifrovaná data existují na zařízení při čtení, otevírání souborů nebo hovorech."]],
    ["Push oznámení", ["Push má sloužit jako wake-up mechanismus. Ve výchozím stavu by payload neměl obsahovat plaintext zpráv a měl by nést minimum metadata."]],
    ["Model serveru", ["Server přenáší encrypted traffic, koordinuje doručení a může dočasně ukládat encrypted payloads pro offline delivery.", "Server ovládá operátor; v self-hosted modelu to můžete být vy nebo vaše organizace."]],
    ["Důsledky self-hosted", ["Vlastní server zvyšuje kontrolu nad infrastrukturou, ale neskrývá metadata před tímto serverem.", "Odpovídáte za TLS, logs, backups, updates a operational security."]],
    ["Doporučení", ["Ověřujte fingerprints důležitých kontaktů.", "Používejte silná hesla.", "Udržujte zařízení zamčená a aktualizovaná.", "Pravidelně aktualizujte Hestia.", "Důvěřujte operátorovi serveru nebo zvažte self-hosting.", "Neignorujte nečekaná key-change warnings."]],
    ["Omezení", ["Žádný anonymous routing ve výchozím stavu.", "Metadata nejsou zcela skrytá.", "Aktuální model zahrnuje TOFU.", "Tato stránka netvrdí externí security audit.", "Kompromitovaný endpoint může odhalit lokální plaintext."]],
    ["Budoucnost", ["Silnější UX ověření klíčů, volitelné at-rest encryption, více metadata minimization a další transport privacy options."]],
  ];

  privacyLocalized.de = [
    ["Was geschützt ist", ["Textnachrichten werden im Client vor dem Senden verschlüsselt; der Server sollte keinen Plaintext sehen.", "Dateien werden vor dem Upload verschlüsselt; der Server sollte encrypted blobs speichern.", "Anrufe verwenden WebRTC mit DTLS-SRTP für Medienverschlüsselung während der Übertragung.", "Nachrichtenverlauf liegt auf dem Gerät des Nutzers, nicht zentral als Plaintext."]],
    ["Was der Server sehen kann", ["Welche Konten kommunizieren.", "Verbindungszeiten und Aktivitätsmuster.", "Nachrichtenfrequenz und Zustellstatus.", "Größen verschlüsselter Dateien.", "Call signaling events.", "IP-Adressen und connection metadata."]],
    ["Vertrauensmodell und Fingerprint", ["Jeder Nutzer sollte einen public key haben.", "Der erste Kontakt nutzt trust on first use.", "Fingerprint oder QR verification hilft, den Schlüssel zu bestätigen.", "Bei Schlüsseländerung sollte Kommunikation bis zur erneuten Prüfung blockiert werden.", "Ohne Prüfung bleibt MITM-Risiko möglich."]],
    ["Was nicht geschützt ist", ["Kompromittierte Geräte.", "Malware auf dem Gerät.", "Bildschirmaufnahme oder lokaler Zugriff.", "Schwache Gerätepasswörter.", "Social Engineering.", "Manuelles Kopieren sensibler Inhalte."]],
    ["Lokale Daten", ["Nachrichten und Dateien werden aus Nutzbarkeitsgründen lokal gespeichert. Entschlüsselte Daten existieren auf dem Gerät beim Lesen, Öffnen von Dateien oder Telefonieren."]],
    ["Push-Benachrichtigungen", ["Push dient als wake-up mechanism. Standardmäßig sollte der Payload keinen Nachrichten-Plaintext enthalten und nur minimale metadata tragen."]],
    ["Servermodell", ["Der Server leitet encrypted traffic weiter, koordiniert Zustellung und kann encrypted payloads für offline delivery temporär speichern.", "Der Server wird vom Betreiber kontrolliert; im self-hosted Modell können das Sie oder Ihre Organisation sein."]],
    ["Self-hosted Auswirkungen", ["Ein eigener Server erhöht Infrastrukturkontrolle, versteckt aber metadata nicht vor diesem Server.", "Sie sind verantwortlich für TLS, logs, backups, updates und operational security."]],
    ["Empfehlungen", ["Fingerprints wichtiger Kontakte prüfen.", "Starke Passwörter verwenden.", "Geräte gesperrt und aktuell halten.", "Hestia regelmäßig aktualisieren.", "Dem Serverbetreiber vertrauen oder self-hosting erwägen.", "Unerwartete key-change warnings nicht ignorieren."]],
    ["Grenzen", ["Kein anonymous routing standardmäßig.", "Metadata wird nicht vollständig verborgen.", "Das aktuelle Modell enthält TOFU.", "Diese Seite behauptet keinen externen security audit.", "Ein kompromittierter Endpoint kann lokalen Plaintext offenlegen."]],
    ["Zukunft", ["Stärkere UX für Schlüsselprüfung, optionales at-rest encryption, mehr metadata minimization und zusätzliche transport privacy options."]],
  ];

  Object.keys(privacyLocalized).forEach((lang) => {
    copy[lang].privacyPage.sections = privacyLocalized[lang];
  });

  const landingLocalized = {
    ru: {
      features: [
        ["M", "Приватные сообщения", "Диалоги построены вокруг зашифрованного транспорта и понятного доверия к контактам."],
        ["F", "Зашифрованная передача файлов", "Передавайте файлы через клиент без хранения plaintext на сервере."],
        ["C", "Голосовые и видеозвонки", "Общайтесь в реальном времени в той же модели контактов."],
        ["S", "Self-hosted опция", "Запускайте свой backend, когда нужен контроль инфраструктуры."],
        ["L", "Локальное хранение", "История хранится на устройстве, ограничивая server-side retention."],
        ["T", "Проверка fingerprint", "Проверяйте контакты по fingerprint, чтобы доверие было явным."],
      ],
      steps: [["Скачайте клиент", "Установите Hestia на Android, desktop или откройте web."], ["Подключитесь к серверу", "Используйте существующий сервер или подготовьте self-hosted backend."], ["Добавьте контакты запросом", "Начинайте общение через явные contact requests."], ["Общайтесь безопаснее", "Пишите, отправляйте файлы и звоните с доступными проверками доверия."]],
      privacy: ["Hestia спроектирована так, чтобы сервер не хранил plaintext сообщений или файлов.", "Fingerprint verification помогает подтвердить собеседника, а privacy controls включают блокировку.", "Self-hosted модель дает командам и сообществам путь к контролю backend."],
    },
    uk: {
      features: [
        ["M", "Приватні повідомлення", "Діалоги побудовані навколо зашифрованого транспорту й зрозумілої довіри до контактів."],
        ["F", "Зашифроване передавання файлів", "Передавайте файли через клієнт без зберігання plaintext на сервері."],
        ["C", "Голосові та відеодзвінки", "Спілкуйтеся в реальному часі в тій самій моделі контактів."],
        ["S", "Self-hosted опція", "Запускайте власний backend, коли потрібен контроль інфраструктури."],
        ["L", "Локальне зберігання", "Історія зберігається на пристрої, обмежуючи server-side retention."],
        ["T", "Перевірка fingerprint", "Перевіряйте контакти за fingerprint, щоб довіра була явною."],
      ],
      steps: [["Завантажте клієнт", "Встановіть Hestia на Android, desktop або відкрийте web."], ["Підключіться до сервера", "Використайте наявний сервер або підготуйте self-hosted backend."], ["Додайте контакти запитом", "Починайте спілкування через явні contact requests."], ["Спілкуйтеся безпечніше", "Пишіть, надсилайте файли й дзвоніть із доступними перевірками довіри."]],
      privacy: ["Hestia спроєктована так, щоб сервер не зберігав plaintext повідомлень або файлів.", "Fingerprint verification допомагає підтвердити співрозмовника, а privacy controls включають блокування.", "Self-hosted модель дає командам і спільнотам шлях до контролю backend."],
    },
    pl: {
      features: [
        ["M", "Prywatne wiadomości", "Rozmowy opierają się na szyfrowanym transporcie i jasnym zaufaniu do kontaktów."],
        ["F", "Szyfrowany transfer plików", "Udostępniaj pliki przez klienta bez przechowywania plaintext na serwerze."],
        ["C", "Rozmowy głosowe i wideo", "Rozmawiaj w czasie rzeczywistym w tym samym modelu kontaktów."],
        ["S", "Opcja self-hosted", "Uruchom własny backend, gdy potrzebujesz kontroli infrastruktury."],
        ["L", "Lokalne przechowywanie", "Historia zostaje na urządzeniu, ograniczając server-side retention."],
        ["T", "Weryfikacja fingerprint", "Sprawdzaj kontakty po fingerprint, aby zaufanie było świadome."],
      ],
      steps: [["Pobierz klienta", "Zainstaluj Hestia na Androidzie, desktopie albo otwórz web."], ["Połącz z serwerem", "Użyj istniejącego serwera albo przygotuj self-hosted backend."], ["Dodaj kontakty prośbą", "Rozpoczynaj rozmowy przez jawne contact requests."], ["Komunikuj się bezpieczniej", "Pisz, wysyłaj pliki i dzwoń z dostępną weryfikacją zaufania."]],
      privacy: ["Hestia jest projektowana tak, aby serwer nie przechowywał plaintext wiadomości ani plików.", "Fingerprint verification pomaga potwierdzić rozmówcę, a privacy controls obejmują blokowanie.", "Model self-hosted daje zespołom i społecznościom kontrolę nad backendem."],
    },
    es: {
      features: [
        ["M", "Mensajería privada", "Las conversaciones se diseñan alrededor de transporte cifrado y confianza clara en contactos."],
        ["F", "Transferencia cifrada de archivos", "Comparte archivos desde el cliente sin pedir al servidor que guarde plaintext."],
        ["C", "Llamadas de voz y video", "Habla en tiempo real con el mismo modelo de contactos."],
        ["S", "Opción self-hosted", "Ejecuta tu backend cuando necesitas control de infraestructura."],
        ["L", "Almacenamiento local", "El historial permanece en tu dispositivo y limita server-side retention."],
        ["T", "Verificación fingerprint", "Verifica contactos con fingerprint para que la confianza sea explícita."],
      ],
      steps: [["Descarga el cliente", "Instala Hestia en Android, desktop o abre web."], ["Conecta al servidor", "Usa un servidor existente o prepara un backend self-hosted."], ["Añade contactos por solicitud", "Inicia conversaciones con contact requests explícitos."], ["Comunícate con más seguridad", "Envía mensajes, archivos y llamadas con verificaciones de confianza disponibles."]],
      privacy: ["Hestia está diseñada para que el servidor no almacene plaintext de mensajes o archivos.", "Fingerprint verification ayuda a confirmar al contacto, y privacy controls incluyen bloqueo.", "El modelo self-hosted da a equipos y comunidades una ruta para controlar su backend."],
    },
    cs: {
      features: [
        ["M", "Soukromé zprávy", "Konverzace jsou postaveny na šifrovaném transportu a jasné důvěře kontaktů."],
        ["F", "Šifrovaný přenos souborů", "Sdílejte soubory přes klienta bez ukládání plaintext na serveru."],
        ["C", "Hlasové a video hovory", "Mluvte v reálném čase ve stejném modelu kontaktů."],
        ["S", "Možnost self-hosted", "Spusťte vlastní backend, když potřebujete kontrolu infrastruktury."],
        ["L", "Lokální úložiště", "Historie zůstává na zařízení a omezuje server-side retention."],
        ["T", "Ověření fingerprint", "Ověřujte kontakty pomocí fingerprint, aby důvěra byla záměrná."],
      ],
      steps: [["Stáhněte klienta", "Nainstalujte Hestia na Android, desktop nebo otevřete web."], ["Připojte server", "Použijte existující server nebo připravte self-hosted backend."], ["Přidejte kontakty žádostí", "Začínejte konverzace přes explicitní contact requests."], ["Komunikujte bezpečněji", "Posílejte zprávy, soubory a volejte s dostupným ověřením důvěry."]],
      privacy: ["Hestia je navržena tak, aby server neukládal plaintext zpráv nebo souborů.", "Fingerprint verification pomáhá potvrdit kontakt a privacy controls zahrnují blokování.", "Model self-hosted dává týmům a komunitám cestu ke kontrole backendu."],
    },
    de: {
      features: [
        ["M", "Private Nachrichten", "Konversationen basieren auf verschlüsseltem Transport und klarer Kontaktvertrauensprüfung."],
        ["F", "Verschlüsselte Dateiübertragung", "Teilen Sie Dateien über den Client, ohne Plaintext auf dem Server zu speichern."],
        ["C", "Sprach- und Videoanrufe", "Sprechen Sie in Echtzeit im gleichen Kontaktmodell."],
        ["S", "Self-hosted Option", "Betreiben Sie Ihr eigenes Backend, wenn Infrastrukturkontrolle wichtig ist."],
        ["L", "Lokale Speicherung", "Der Verlauf bleibt auf dem Gerät und begrenzt server-side retention."],
        ["T", "Fingerprint-Prüfung", "Prüfen Sie Kontakte per Fingerprint, damit Vertrauen explizit ist."],
      ],
      steps: [["Client herunterladen", "Installieren Sie Hestia auf Android, Desktop oder öffnen Sie Web."], ["Mit Server verbinden", "Nutzen Sie einen bestehenden Server oder bereiten Sie ein self-hosted Backend vor."], ["Kontakte per Anfrage hinzufügen", "Starten Sie Gespräche über explizite contact requests."], ["Sicherer kommunizieren", "Nachrichten, Dateien und Anrufe mit verfügbaren Vertrauensprüfungen."]],
      privacy: ["Hestia ist so gestaltet, dass der Server keinen Plaintext von Nachrichten oder Dateien speichert.", "Fingerprint verification hilft, Kontakte zu bestätigen; privacy controls enthalten Blockieren.", "Das self-hosted Modell gibt Teams und Communities Kontrolle über ihr Backend."],
    },
  };

  Object.keys(landingLocalized).forEach((lang) => {
    copy[lang].landing.features = landingLocalized[lang].features;
    copy[lang].landing.steps = landingLocalized[lang].steps;
    copy[lang].landing.privacy = landingLocalized[lang].privacy;
  });

  const faqLabels = {
    en: "FAQ",
    uk: "FAQ",
    ru: "FAQ",
    pl: "FAQ",
    es: "FAQ",
    cs: "FAQ",
    de: "FAQ",
  };

  const comparisonLabels = {
    en: "Compare",
    uk: "Порівняння",
    ru: "Сравнение",
    pl: "Porównanie",
    es: "Comparar",
    cs: "Srovnání",
    de: "Vergleich",
  };

  const faqData = {
    en: {
      eyebrow: "Common questions",
      title: "FAQ / Common Questions",
      intro: "Short answers about Hestia, privacy, calls, files, and self-hosting.",
      sections: [
        ["General", [["What is Hestia?", "Hestia is a privacy-first messenger with clients for mobile, desktop, and web, plus an optional self-hosted server."], ["Is Hestia free?", "The public site is built around direct downloads and self-hosting. Exact licensing and service terms should be checked in the project repository when published."], ["Who is it for?", "It is for users, teams, and communities that want encrypted communication, explicit contact trust, and more control over server infrastructure."]]],
        ["Privacy & Security", [["Are messages encrypted?", "Messages are intended to be encrypted on the client before they are sent to the server."], ["Can the server read my messages?", "The server should not see plaintext messages or files, but it can still see operational metadata."], ["What data does the server see?", "It may see accounts, connection times, message frequency, file sizes, call events, IP addresses, and delivery state."], ["Is Hestia anonymous?", "No. Hestia is privacy-first, but it does not provide anonymous routing like Tor or I2P by default."]]],
        ["Usage", [["How do I add contacts?", "Contacts are added through explicit requests. This keeps communication intentional and reduces unwanted discovery."], ["Why can't I message someone without request?", "Hestia avoids a global open inbox model. A contact request gives the other person a chance to accept or ignore you."], ["What happens if a user blocks me?", "Blocked users should not be able to continue normal contact with the blocker. Exact client behavior can depend on the app version."]]],
        ["Calls", [["How do calls work?", "Calls use WebRTC signaling through the server and encrypted media transport between participants where possible."], ["Why do calls sometimes fail?", "Strict NAT, firewalls, or missing TURN relay can prevent peers from connecting reliably."], ["Do calls use my server?", "The server helps with signaling. Media may be peer-to-peer or use relay infrastructure depending on network conditions and TURN setup."]]],
        ["Files", [["Are files encrypted?", "Files are intended to be encrypted before upload, so the server stores encrypted blobs instead of plaintext files."], ["What file types are allowed?", "Allowed types depend on the client and server policy. The server may reject risky or unsupported uploads."], ["Why can't I send very large files?", "Large files can create storage, bandwidth, and delivery problems. Servers may enforce size limits."]]],
        ["Self-hosting", [["Do I need my own server?", "No. You can use a server provided by someone you trust, if one is available."], ["Can I use someone else's server?", "Yes, but remember that the server operator may still see metadata even if plaintext is protected."], ["How hard is it to run a server?", "A basic server should be manageable for someone comfortable with Linux, domains, TLS, and reverse proxies."]]],
        ["Technical", [["Does Hestia work without internet?", "Local history remains on the device, but sending messages, syncing, calls, and delivery need network access."], ["Why does it use push notifications?", "Push can wake the client for new activity without sending plaintext message content by default."], ["Why is there no global user list?", "A global list would expose users and encourage unwanted discovery. Hestia favors explicit contact requests."]]],
      ],
    },
    ru: {
      eyebrow: "Частые вопросы",
      title: "FAQ / Частые вопросы",
      intro: "Короткие ответы про Hestia, приватность, звонки, файлы и self-hosting.",
      sections: [
        ["Общее", [["Что такое Hestia?", "Hestia — privacy-first мессенджер с клиентами для mobile, desktop и web, а также опциональным self-hosted сервером."], ["Hestia бесплатная?", "Сайт сейчас ориентирован на прямые загрузки и self-hosting. Точные лицензии и условия нужно проверить в репозитории проекта после публикации."], ["Для кого Hestia?", "Для пользователей, команд и сообществ, которым нужны encrypted communication, явное доверие к контактам и больше контроля над сервером."]]],
        ["Приватность и безопасность", [["Сообщения шифруются?", "Сообщения должны шифроваться на клиенте до отправки на сервер."], ["Может ли сервер читать сообщения?", "Сервер не должен видеть plaintext сообщений или файлов, но metadata все равно может быть видима."], ["Какие данные видит сервер?", "Аккаунты, время подключений, частоту сообщений, размеры файлов, события звонков, IP и состояние доставки."], ["Hestia анонимна?", "Нет. Hestia privacy-first, но не дает anonymous routing как Tor или I2P по умолчанию."]]],
        ["Использование", [["Как добавить контакты?", "Контакты добавляются через явные запросы. Это снижает нежелательное обнаружение и случайные сообщения."], ["Почему нельзя написать без запроса?", "Hestia избегает модели глобального открытого inbox. Запрос дает человеку возможность принять или проигнорировать контакт."], ["Что если пользователь меня заблокировал?", "Заблокированный пользователь не должен продолжать обычный контакт с тем, кто его заблокировал. Детали зависят от версии клиента."]]],
        ["Звонки", [["Как работают звонки?", "Звонки используют WebRTC signaling через сервер и encrypted media transport между участниками, где это возможно."], ["Почему звонки иногда не работают?", "Строгий NAT, firewall или отсутствие TURN relay могут мешать стабильному соединению."], ["Звонки используют мой сервер?", "Сервер помогает с signaling. Media может идти peer-to-peer или через relay в зависимости от сети и TURN."]]],
        ["Файлы", [["Файлы шифруются?", "Файлы должны шифроваться до загрузки, чтобы сервер хранил encrypted blobs, а не plaintext."], ["Какие типы файлов разрешены?", "Это зависит от политики клиента и сервера. Сервер может отклонять рискованные или неподдерживаемые uploads."], ["Почему нельзя отправлять очень большие файлы?", "Большие файлы создают нагрузку на storage, bandwidth и delivery. Серверы могут задавать лимиты."]]],
        ["Self-hosting", [["Нужен ли свой сервер?", "Нет. Можно использовать сервер оператора, которому вы доверяете, если он доступен."], ["Можно использовать чужой сервер?", "Да, но оператор сервера может видеть metadata, даже если plaintext защищен."], ["Сложно ли запустить сервер?", "Базовый сервер реалистичен для человека, знакомого с Linux, доменами, TLS и reverse proxy."]]],
        ["Техническое", [["Работает ли Hestia без интернета?", "Локальная история остается на устройстве, но отправка, sync, звонки и доставка требуют сеть."], ["Зачем push-уведомления?", "Push может разбудить клиент для новой активности без plaintext сообщения в payload по умолчанию."], ["Почему нет глобального списка пользователей?", "Глобальный список раскрывал бы пользователей и поощрял нежелательный поиск. Hestia выбирает явные contact requests."]]],
      ],
    },
    uk: {
      eyebrow: "Поширені питання",
      title: "FAQ / Поширені питання",
      intro: "Короткі відповіді про Hestia, приватність, дзвінки, файли та self-hosting.",
      sections: [
        ["Загальне", [["Що таке Hestia?", "Hestia — privacy-first месенджер із клієнтами для mobile, desktop і web та опційним self-hosted сервером."], ["Hestia безкоштовна?", "Сайт зараз орієнтований на прямі завантаження й self-hosting. Точні ліцензії та умови варто перевірити в репозиторії після публікації."], ["Для кого Hestia?", "Для користувачів, команд і спільнот, яким потрібні encrypted communication, явна довіра до контактів і більше контролю над сервером."]]],
        ["Приватність і безпека", [["Повідомлення шифруються?", "Повідомлення мають шифруватися на клієнті до надсилання на сервер."], ["Чи може сервер читати повідомлення?", "Сервер не має бачити plaintext повідомлень або файлів, але metadata може бути видимою."], ["Які дані бачить сервер?", "Акаунти, час підключень, частоту повідомлень, розміри файлів, події дзвінків, IP і стан доставки."], ["Hestia анонімна?", "Ні. Hestia privacy-first, але не надає anonymous routing як Tor або I2P за замовчуванням."]]],
        ["Використання", [["Як додати контакти?", "Контакти додаються через явні запити. Це зменшує небажане виявлення та випадкові повідомлення."], ["Чому не можна писати без запиту?", "Hestia уникає моделі глобального відкритого inbox. Запит дає людині можливість прийняти або проігнорувати контакт."], ["Що якщо користувач мене заблокував?", "Заблокований користувач не має продовжувати звичайний контакт із тим, хто його заблокував. Деталі залежать від версії клієнта."]]],
        ["Дзвінки", [["Як працюють дзвінки?", "Дзвінки використовують WebRTC signaling через сервер і encrypted media transport між учасниками, де це можливо."], ["Чому дзвінки іноді не працюють?", "Суворий NAT, firewall або відсутність TURN relay можуть заважати стабільному з'єднанню."], ["Дзвінки використовують мій сервер?", "Сервер допомагає з signaling. Media може йти peer-to-peer або через relay залежно від мережі й TURN."]]],
        ["Файли", [["Файли шифруються?", "Файли мають шифруватися до завантаження, щоб сервер зберігав encrypted blobs, а не plaintext."], ["Які типи файлів дозволені?", "Це залежить від політики клієнта й сервера. Сервер може відхиляти ризикові або непідтримувані uploads."], ["Чому не можна надсилати дуже великі файли?", "Великі файли створюють навантаження на storage, bandwidth і delivery. Сервери можуть задавати ліміти."]]],
        ["Self-hosting", [["Чи потрібен власний сервер?", "Ні. Можна використовувати сервер оператора, якому ви довіряєте, якщо він доступний."], ["Можна використовувати чужий сервер?", "Так, але оператор сервера може бачити metadata, навіть якщо plaintext захищений."], ["Чи складно запустити сервер?", "Базовий сервер реалістичний для людини, знайомої з Linux, доменами, TLS і reverse proxy."]]],
        ["Технічне", [["Чи працює Hestia без інтернету?", "Локальна історія лишається на пристрої, але надсилання, sync, дзвінки й доставка потребують мережі."], ["Навіщо push-сповіщення?", "Push може розбудити клієнт для нової активності без plaintext повідомлення в payload за замовчуванням."], ["Чому немає глобального списку користувачів?", "Глобальний список розкривав би користувачів і заохочував небажаний пошук. Hestia обирає явні contact requests."]]],
      ],
    },
    pl: {
      eyebrow: "Częste pytania",
      title: "FAQ / Częste pytania",
      intro: "Krótkie odpowiedzi o Hestia, prywatności, rozmowach, plikach i self-hostingu.",
      sections: [
        ["Ogólne", [["Czym jest Hestia?", "Hestia to privacy-first komunikator z klientami mobile, desktop i web oraz opcjonalnym serwerem self-hosted."], ["Czy Hestia jest darmowa?", "Strona skupia się na bezpośrednich pobraniach i self-hostingu. Licencję i warunki sprawdź w repozytorium projektu po publikacji."], ["Dla kogo jest Hestia?", "Dla osób, zespołów i społeczności, które chcą szyfrowanej komunikacji, jawnego zaufania do kontaktów i kontroli nad serwerem."]]],
        ["Prywatność i bezpieczeństwo", [["Czy wiadomości są szyfrowane?", "Wiadomości powinny być szyfrowane w kliencie przed wysłaniem na serwer."], ["Czy serwer może czytać wiadomości?", "Serwer nie powinien widzieć plaintext wiadomości ani plików, ale metadata może być widoczna."], ["Co widzi serwer?", "Konta, czasy połączeń, częstotliwość wiadomości, rozmiary plików, zdarzenia rozmów, IP i stan dostarczenia."], ["Czy Hestia jest anonimowa?", "Nie. Hestia jest privacy-first, ale domyślnie nie daje anonymous routing jak Tor lub I2P."]]],
        ["Użycie", [["Jak dodać kontakty?", "Kontakty dodaje się przez jawne prośby, co ogranicza niechciane odkrywanie."], ["Dlaczego nie mogę pisać bez prośby?", "Hestia unika globalnej otwartej skrzynki. Prośba daje drugiej osobie wybór."], ["Co jeśli ktoś mnie zablokuje?", "Zablokowany użytkownik nie powinien kontynuować normalnego kontaktu z blokującym. Szczegóły zależą od wersji klienta."]]],
        ["Rozmowy", [["Jak działają rozmowy?", "Rozmowy używają WebRTC signaling przez serwer i szyfrowanego transportu mediów, gdy to możliwe."], ["Dlaczego rozmowy czasem zawodzą?", "Ścisły NAT, firewall albo brak TURN relay może utrudnić połączenie."], ["Czy rozmowy używają mojego serwera?", "Serwer pomaga w signaling. Media może iść peer-to-peer albo przez relay zależnie od sieci i TURN."]]],
        ["Pliki", [["Czy pliki są szyfrowane?", "Pliki powinny być szyfrowane przed wysłaniem, aby serwer przechowywał encrypted blobs."], ["Jakie typy plików są dozwolone?", "Zależy to od polityki klienta i serwera; serwer może odrzucać ryzykowne lub nieobsługiwane uploady."], ["Dlaczego nie mogę wysłać bardzo dużych plików?", "Duże pliki obciążają storage, bandwidth i delivery, więc serwery mogą mieć limity."]]],
        ["Self-hosting", [["Czy potrzebuję własnego serwera?", "Nie. Możesz użyć serwera operatora, któremu ufasz."], ["Czy mogę używać cudzego serwera?", "Tak, ale operator może widzieć metadata nawet wtedy, gdy plaintext jest chroniony."], ["Jak trudno uruchomić serwer?", "Podstawowy serwer jest realny dla osoby znającej Linux, domeny, TLS i reverse proxy."]]],
        ["Techniczne", [["Czy Hestia działa bez internetu?", "Lokalna historia zostaje na urządzeniu, ale wysyłanie, sync, rozmowy i dostarczanie wymagają sieci."], ["Po co push notifications?", "Push może obudzić klienta bez plaintext wiadomości w payloadzie domyślnie."], ["Dlaczego nie ma globalnej listy użytkowników?", "Globalna lista ujawniałaby użytkowników. Hestia wybiera jawne contact requests."]]],
      ],
    },
    es: {
      eyebrow: "Preguntas frecuentes",
      title: "FAQ / Preguntas frecuentes",
      intro: "Respuestas cortas sobre Hestia, privacidad, llamadas, archivos y self-hosting.",
      sections: [
        ["General", [["¿Qué es Hestia?", "Hestia es un mensajero privacy-first con clientes mobile, desktop y web, y servidor self-hosted opcional."], ["¿Hestia es gratis?", "El sitio se centra en descargas directas y self-hosting. La licencia y términos deben revisarse en el repositorio cuando se publique."], ["¿Para quién es?", "Para usuarios, equipos y comunidades que quieren comunicación cifrada, confianza explícita en contactos y control del servidor."]]],
        ["Privacidad y seguridad", [["¿Los mensajes están cifrados?", "Los mensajes deberían cifrarse en el cliente antes de enviarse al servidor."], ["¿Puede el servidor leer mis mensajes?", "El servidor no debería ver plaintext de mensajes o archivos, pero metadata puede seguir visible."], ["¿Qué datos ve el servidor?", "Cuentas, tiempos de conexión, frecuencia de mensajes, tamaños de archivos, eventos de llamadas, IP y estado de entrega."], ["¿Hestia es anónima?", "No. Hestia es privacy-first, pero no ofrece anonymous routing como Tor o I2P por defecto."]]],
        ["Uso", [["¿Cómo añado contactos?", "Los contactos se añaden mediante solicitudes explícitas para reducir descubrimiento no deseado."], ["¿Por qué no puedo escribir sin solicitud?", "Hestia evita una bandeja global abierta. La solicitud permite aceptar o ignorar el contacto."], ["¿Qué pasa si me bloquean?", "Un usuario bloqueado no debería seguir el contacto normal con quien lo bloqueó. Depende de la versión del cliente."]]],
        ["Llamadas", [["¿Cómo funcionan las llamadas?", "Usan WebRTC signaling a través del servidor y transporte cifrado de medios cuando es posible."], ["¿Por qué fallan a veces?", "NAT estricto, firewalls o falta de TURN relay pueden impedir conexiones estables."], ["¿Usan mi servidor?", "El servidor ayuda con signaling. Los medios pueden ser peer-to-peer o relay según red y TURN."]]],
        ["Archivos", [["¿Los archivos están cifrados?", "Los archivos deberían cifrarse antes de subirlos para que el servidor guarde encrypted blobs."], ["¿Qué tipos se permiten?", "Depende de la política del cliente y servidor; se pueden rechazar uploads riesgosos o no soportados."], ["¿Por qué no puedo enviar archivos muy grandes?", "Archivos grandes consumen storage, bandwidth y delivery; los servidores pueden imponer límites."]]],
        ["Self-hosting", [["¿Necesito mi propio servidor?", "No. Puedes usar un servidor de un operador en quien confíes."], ["¿Puedo usar un servidor ajeno?", "Sí, pero el operador puede ver metadata aunque el plaintext esté protegido."], ["¿Qué tan difícil es ejecutar uno?", "Un servidor básico es manejable para alguien cómodo con Linux, dominios, TLS y reverse proxy."]]],
        ["Técnico", [["¿Hestia funciona sin internet?", "El historial local queda en el dispositivo, pero enviar, sincronizar, llamar y entregar requiere red."], ["¿Por qué usa push?", "Push puede despertar el cliente sin enviar plaintext del mensaje en el payload por defecto."], ["¿Por qué no hay lista global?", "Una lista global expondría usuarios. Hestia prefiere contact requests explícitos."]]],
      ],
    },
    cs: {
      eyebrow: "Časté otázky",
      title: "FAQ / Časté otázky",
      intro: "Krátké odpovědi o Hestia, soukromí, hovorech, souborech a self-hostingu.",
      sections: [
        ["Obecné", [["Co je Hestia?", "Hestia je privacy-first messenger s klienty pro mobile, desktop a web a volitelným self-hosted serverem."], ["Je Hestia zdarma?", "Web se zaměřuje na přímá stažení a self-hosting. Licenci a podmínky zkontrolujte v repozitáři po publikaci."], ["Pro koho je?", "Pro uživatele, týmy a komunity, které chtějí šifrovanou komunikaci, explicitní důvěru kontaktů a kontrolu serveru."]]],
        ["Soukromí a bezpečnost", [["Jsou zprávy šifrované?", "Zprávy by se měly šifrovat v klientu před odesláním na server."], ["Může server číst zprávy?", "Server by neměl vidět plaintext zpráv nebo souborů, ale metadata mohou být viditelná."], ["Co server vidí?", "Účty, časy připojení, frekvenci zpráv, velikosti souborů, události hovorů, IP a stav doručení."], ["Je Hestia anonymní?", "Ne. Hestia je privacy-first, ale neposkytuje anonymous routing jako Tor nebo I2P ve výchozím stavu."]]],
        ["Používání", [["Jak přidám kontakty?", "Kontakty se přidávají přes explicitní žádosti, což omezuje nechtěné vyhledávání."], ["Proč nemohu psát bez žádosti?", "Hestia se vyhýbá globální otevřené schránce. Žádost dává druhé osobě volbu."], ["Co když mě někdo zablokuje?", "Blokovaný uživatel by neměl pokračovat v běžném kontaktu. Detaily závisí na verzi klienta."]]],
        ["Hovory", [["Jak fungují hovory?", "Používají WebRTC signaling přes server a šifrovaný transport médií, kde je to možné."], ["Proč někdy selžou?", "Přísný NAT, firewall nebo chybějící TURN relay mohou bránit stabilnímu spojení."], ["Používají můj server?", "Server pomáhá se signaling. Média mohou jít peer-to-peer nebo přes relay podle sítě a TURN."]]],
        ["Soubory", [["Jsou soubory šifrované?", "Soubory by se měly šifrovat před uploadem, aby server ukládal encrypted blobs."], ["Jaké typy jsou povolené?", "Záleží na politice klienta a serveru; rizikové nebo nepodporované uploady mohou být odmítnuty."], ["Proč nejdou velmi velké soubory?", "Velké soubory zatěžují storage, bandwidth a delivery, proto mohou mít servery limity."]]],
        ["Self-hosting", [["Potřebuji vlastní server?", "Ne. Můžete použít server operátora, kterému důvěřujete."], ["Mohu použít cizí server?", "Ano, ale operátor může vidět metadata, i když je plaintext chráněn."], ["Jak těžké je server spustit?", "Základní server zvládne člověk obeznámený s Linuxem, doménami, TLS a reverse proxy."]]],
        ["Technické", [["Funguje Hestia bez internetu?", "Lokální historie zůstává v zařízení, ale odesílání, sync, hovory a doručení potřebují síť."], ["Proč používá push?", "Push může probudit klienta bez plaintext zprávy v payloadu ve výchozím nastavení."], ["Proč není globální seznam?", "Globální seznam by odhaloval uživatele. Hestia preferuje explicitní contact requests."]]],
      ],
    },
    de: {
      eyebrow: "Häufige Fragen",
      title: "FAQ / Häufige Fragen",
      intro: "Kurze Antworten zu Hestia, Datenschutz, Anrufen, Dateien und Self-hosting.",
      sections: [
        ["Allgemein", [["Was ist Hestia?", "Hestia ist ein privacy-first Messenger mit Clients für Mobile, Desktop und Web sowie optionalem self-hosted Server."], ["Ist Hestia kostenlos?", "Die Seite konzentriert sich auf direkte Downloads und Self-hosting. Lizenz und Bedingungen sollten im Projekt-Repository geprüft werden."], ["Für wen ist es?", "Für Nutzer, Teams und Communities, die verschlüsselte Kommunikation, explizites Kontaktvertrauen und Serverkontrolle wollen."]]],
        ["Datenschutz & Sicherheit", [["Sind Nachrichten verschlüsselt?", "Nachrichten sollen im Client verschlüsselt werden, bevor sie an den Server gehen."], ["Kann der Server mitlesen?", "Der Server sollte keinen Plaintext von Nachrichten oder Dateien sehen, aber metadata kann sichtbar bleiben."], ["Welche Daten sieht der Server?", "Konten, Verbindungszeiten, Nachrichtenfrequenz, Dateigrößen, Anrufereignisse, IPs und Zustellstatus."], ["Ist Hestia anonym?", "Nein. Hestia ist privacy-first, bietet aber standardmäßig kein anonymous routing wie Tor oder I2P."]]],
        ["Nutzung", [["Wie füge ich Kontakte hinzu?", "Kontakte werden über explizite Anfragen hinzugefügt. Das reduziert unerwünschte Entdeckung."], ["Warum kann ich nicht ohne Anfrage schreiben?", "Hestia vermeidet ein global offenes Postfach. Die Anfrage gibt der anderen Person eine Wahl."], ["Was passiert bei Blockierung?", "Blockierte Nutzer sollten keinen normalen Kontakt fortsetzen können. Details hängen von der Client-Version ab."]]],
        ["Anrufe", [["Wie funktionieren Anrufe?", "Anrufe nutzen WebRTC signaling über den Server und verschlüsselten Medientransport, wo möglich."], ["Warum scheitern Anrufe manchmal?", "Striktes NAT, Firewalls oder fehlender TURN relay können stabile Verbindungen verhindern."], ["Nutzen Anrufe meinen Server?", "Der Server hilft beim signaling. Medien laufen je nach Netzwerk und TURN peer-to-peer oder über relay."]]],
        ["Dateien", [["Sind Dateien verschlüsselt?", "Dateien sollen vor dem Upload verschlüsselt werden, damit der Server encrypted blobs speichert."], ["Welche Dateitypen sind erlaubt?", "Das hängt von Client- und Serverrichtlinien ab; riskante oder nicht unterstützte Uploads können abgelehnt werden."], ["Warum keine sehr großen Dateien?", "Große Dateien belasten storage, bandwidth und delivery. Server können Limits setzen."]]],
        ["Self-hosting", [["Brauche ich einen eigenen Server?", "Nein. Sie können einen Server eines vertrauenswürdigen Betreibers nutzen."], ["Kann ich fremde Server nutzen?", "Ja, aber der Betreiber kann metadata sehen, auch wenn Plaintext geschützt ist."], ["Wie schwer ist der Betrieb?", "Ein Basisserver ist für Personen mit Linux, Domains, TLS und reverse proxy gut machbar."]]],
        ["Technisch", [["Funktioniert Hestia ohne Internet?", "Lokaler Verlauf bleibt auf dem Gerät, aber Senden, Sync, Anrufe und Zustellung brauchen Netzwerk."], ["Warum Push-Benachrichtigungen?", "Push kann den Client wecken, ohne standardmäßig Nachrichten-Plaintext im Payload zu senden."], ["Warum keine globale Nutzerliste?", "Eine globale Liste würde Nutzer offenlegen. Hestia setzt auf explizite contact requests."]]],
      ],
    },
  };

  Object.keys(faqData).forEach((lang) => {
    copy[lang].faq = faqData[lang];
    copy[lang].nav = [copy[lang].nav[0], copy[lang].nav[1], copy[lang].nav[2], faqLabels[lang], copy[lang].nav[3]];
    copy[lang].footer = [copy[lang].footer[0], faqLabels[lang], copy[lang].footer[1], copy[lang].footer[2], copy[lang].footer[3]];
  });

  const tableRows = {
    en: [
      ["Self-hosted", "Yes", "No", "No", "Yes, federated"],
      ["End-to-end encryption", "Designed for messages/files", "Secret Chats; cloud chats differ", "Default for messages/calls", "Available, room/client dependent"],
      ["Server sees plaintext", "Should not for messages/files", "Cloud chats are server-side", "No message/call plaintext", "Homeserver should not read encrypted rooms"],
      ["Local-first history", "Yes", "No, cloud sync focus", "Yes", "Mixed, client/server model"],
      ["Global user directory", "No", "Large public discovery", "Phone/contact based", "Room/user discovery exists"],
      ["Calls", "WebRTC", "Built-in", "Encrypted calls", "VoIP/WebRTC support"],
      ["Offline delivery", "Temporary encrypted payloads", "Cloud storage/delivery", "Queued encrypted delivery", "Server event history"],
      ["Ease of setup", "Small server target", "No self-hosting", "No self-hosting", "More complex"],
      ["Scalability", "Small groups first", "Very large public scale", "Large consumer scale", "Large federated network"],
      ["Metadata exposure", "Server metadata remains", "Service metadata remains", "Minimized, centralized service", "Federated metadata remains"],
    ],
    ru: [
      ["Self-hosted", "Да", "Нет", "Нет", "Да, федерация"],
      ["E2E encryption", "Для сообщений/файлов по design", "Secret Chats; cloud chats иначе", "По умолчанию для сообщений/звонков", "Доступно, зависит от комнаты/клиента"],
      ["Сервер видит plaintext", "Не должен для сообщений/файлов", "Cloud chats серверные", "Нет plaintext сообщений/звонков", "Homeserver не должен читать encrypted rooms"],
      ["Local-first history", "Да", "Нет, фокус на cloud sync", "Да", "Смешанная client/server модель"],
      ["Глобальный каталог", "Нет", "Большое публичное discovery", "Phone/contact based", "Есть room/user discovery"],
      ["Звонки", "WebRTC", "Встроены", "Зашифрованные звонки", "VoIP/WebRTC support"],
      ["Offline delivery", "Временные encrypted payloads", "Cloud storage/delivery", "Queued encrypted delivery", "Server event history"],
      ["Простота setup", "Цель — небольшой сервер", "Self-hosting нет", "Self-hosting нет", "Сложнее"],
      ["Масштаб", "Сначала малые группы", "Очень большой public scale", "Большой consumer scale", "Большая федеративная сеть"],
      ["Metadata", "Metadata сервера остается", "Metadata сервиса остается", "Минимизируется, но centralized", "Federated metadata остается"],
    ],
    uk: [
      ["Self-hosted", "Так", "Ні", "Ні", "Так, федерація"],
      ["E2E encryption", "Для повідомлень/файлів за design", "Secret Chats; cloud chats інакше", "За замовчуванням для повідомлень/дзвінків", "Доступно, залежить від кімнати/клієнта"],
      ["Сервер бачить plaintext", "Не має для повідомлень/файлів", "Cloud chats серверні", "Ні plaintext повідомлень/дзвінків", "Homeserver не має читати encrypted rooms"],
      ["Local-first history", "Так", "Ні, фокус на cloud sync", "Так", "Змішана client/server модель"],
      ["Глобальний каталог", "Ні", "Велике публічне discovery", "Phone/contact based", "Є room/user discovery"],
      ["Дзвінки", "WebRTC", "Вбудовані", "Зашифровані дзвінки", "VoIP/WebRTC support"],
      ["Offline delivery", "Тимчасові encrypted payloads", "Cloud storage/delivery", "Queued encrypted delivery", "Server event history"],
      ["Простота setup", "Ціль — малий сервер", "Self-hosting немає", "Self-hosting немає", "Складніше"],
      ["Масштаб", "Спершу малі групи", "Дуже великий public scale", "Великий consumer scale", "Велика федеративна мережа"],
      ["Metadata", "Metadata сервера лишається", "Metadata сервісу лишається", "Мінімізується, але centralized", "Federated metadata лишається"],
    ],
  };

  tableRows.pl = [
    ["Self-hosted", "Tak", "Nie", "Nie", "Tak, federacja"],
    ["E2E encryption", "Dla wiadomości/plików w projekcie", "Secret Chats; cloud chats inaczej", "Domyślnie dla wiadomości/rozmów", "Dostępne, zależne od pokoju/klienta"],
    ["Serwer widzi plaintext", "Nie powinien dla wiadomości/plików", "Cloud chats są serwerowe", "Brak plaintext wiadomości/rozmów", "Homeserver nie powinien czytać encrypted rooms"],
    ["Local-first history", "Tak", "Nie, nacisk na cloud sync", "Tak", "Mieszany model client/server"],
    ["Globalny katalog", "Nie", "Duże public discovery", "Phone/contact based", "Istnieje room/user discovery"],
    ["Rozmowy", "WebRTC", "Wbudowane", "Szyfrowane rozmowy", "VoIP/WebRTC support"],
    ["Offline delivery", "Tymczasowe encrypted payloads", "Cloud storage/delivery", "Queued encrypted delivery", "Server event history"],
    ["Łatwość setup", "Cel: mały serwer", "Brak self-hosting", "Brak self-hosting", "Bardziej złożone"],
    ["Skalowanie", "Najpierw małe grupy", "Bardzo duża skala publiczna", "Duża skala konsumencka", "Duża sieć federacyjna"],
    ["Metadata", "Metadata serwera zostaje", "Metadata usługi zostaje", "Minimalizowana, ale centralna", "Federated metadata zostaje"],
  ];

  tableRows.es = [
    ["Self-hosted", "Sí", "No", "No", "Sí, federado"],
    ["E2E encryption", "Diseñado para mensajes/archivos", "Secret Chats; cloud chats difieren", "Por defecto para mensajes/llamadas", "Disponible, depende de sala/cliente"],
    ["Servidor ve plaintext", "No debería para mensajes/archivos", "Cloud chats son de servidor", "Sin plaintext de mensajes/llamadas", "Homeserver no debería leer encrypted rooms"],
    ["Local-first history", "Sí", "No, foco en cloud sync", "Sí", "Modelo client/server mixto"],
    ["Directorio global", "No", "Gran public discovery", "Phone/contact based", "Existe room/user discovery"],
    ["Llamadas", "WebRTC", "Integradas", "Llamadas cifradas", "VoIP/WebRTC support"],
    ["Offline delivery", "Encrypted payloads temporales", "Cloud storage/delivery", "Queued encrypted delivery", "Server event history"],
    ["Facilidad setup", "Objetivo: servidor pequeño", "Sin self-hosting", "Sin self-hosting", "Más complejo"],
    ["Escalabilidad", "Primero grupos pequeños", "Escala pública muy grande", "Gran escala consumer", "Gran red federada"],
    ["Metadata", "Metadata del servidor permanece", "Metadata del servicio permanece", "Minimizada, centralizada", "Federated metadata permanece"],
  ];

  tableRows.cs = [
    ["Self-hosted", "Ano", "Ne", "Ne", "Ano, federace"],
    ["E2E encryption", "Navrženo pro zprávy/soubory", "Secret Chats; cloud chats se liší", "Výchozí pro zprávy/hovory", "Dostupné, záleží na místnosti/klientu"],
    ["Server vidí plaintext", "Neměl by pro zprávy/soubory", "Cloud chats jsou serverové", "Žádný plaintext zpráv/hovorů", "Homeserver by neměl číst encrypted rooms"],
    ["Local-first history", "Ano", "Ne, důraz na cloud sync", "Ano", "Smíšený client/server model"],
    ["Globální katalog", "Ne", "Velké public discovery", "Phone/contact based", "Existuje room/user discovery"],
    ["Hovory", "WebRTC", "Vestavěné", "Šifrované hovory", "VoIP/WebRTC support"],
    ["Offline delivery", "Dočasné encrypted payloads", "Cloud storage/delivery", "Queued encrypted delivery", "Server event history"],
    ["Snadnost setup", "Cíl: malý server", "Bez self-hosting", "Bez self-hosting", "Složitější"],
    ["Škálování", "Nejprve malé skupiny", "Velká veřejná škála", "Velká consumer škála", "Velká federovaná síť"],
    ["Metadata", "Metadata serveru zůstávají", "Metadata služby zůstávají", "Minimalizována, centralizovaná", "Federated metadata zůstávají"],
  ];

  tableRows.de = [
    ["Self-hosted", "Ja", "Nein", "Nein", "Ja, föderiert"],
    ["E2E encryption", "Für Nachrichten/Dateien vorgesehen", "Secret Chats; cloud chats anders", "Standard für Nachrichten/Anrufe", "Verfügbar, raum/client-abhängig"],
    ["Server sieht Plaintext", "Sollte nicht für Nachrichten/Dateien", "Cloud chats serverseitig", "Kein Nachrichten/Anruf-Plaintext", "Homeserver sollte encrypted rooms nicht lesen"],
    ["Local-first history", "Ja", "Nein, Fokus cloud sync", "Ja", "Gemischtes client/server Modell"],
    ["Globales Verzeichnis", "Nein", "Großes public discovery", "Phone/contact based", "Room/user discovery vorhanden"],
    ["Anrufe", "WebRTC", "Eingebaut", "Verschlüsselte Anrufe", "VoIP/WebRTC support"],
    ["Offline delivery", "Temporäre encrypted payloads", "Cloud storage/delivery", "Queued encrypted delivery", "Server event history"],
    ["Setup-Aufwand", "Ziel: kleiner Server", "Kein self-hosting", "Kein self-hosting", "Komplexer"],
    ["Skalierung", "Kleine Gruppen zuerst", "Sehr große public scale", "Große consumer scale", "Großes föderiertes Netz"],
    ["Metadata", "Server-metadata bleibt", "Service-metadata bleibt", "Minimiert, zentralisiert", "Federated metadata bleibt"],
  ];

  const comparisonData = {
    en: {
      eyebrow: "Messenger choice",
      title: "Why Hestia?",
      intro: "How Hestia differs from Telegram, Signal, and Matrix without pretending they solve the same problem.",
      position: "Hestia is a self-hosted privacy-first messenger designed for small groups, private communities, and environments where infrastructure control matters.",
      headers: ["Feature", "Hestia", "Telegram", "Signal", "Matrix"],
      rows: tableRows.en,
      sections: [
        ["Hestia vs Telegram", ["Telegram is convenient and large-scale, but regular cloud chats are built around Telegram's cloud model. Hestia is aimed at self-hosting, encrypted payloads before send, and no global user directory.", "Choose Hestia when infrastructure ownership and smaller trusted groups matter more than public discovery and massive channels."]],
        ["Hestia vs Signal", ["Signal has a strong privacy model and default end-to-end encryption, but it is not a self-hosted product for small private servers.", "Hestia gives the server operator more control and uses a different trust model, including TOFU and fingerprint verification."]],
        ["Hestia vs Matrix", ["Matrix is an open, federated communication protocol with a broad ecosystem. That flexibility can also make deployment and moderation more complex.", "Hestia is intentionally narrower: simpler server, smaller groups, and less protocol surface to operate."]],
        ["When to choose Hestia", ["Small teams", "Private groups", "Self-hosted setups", "Controlled environments", "Communities that prefer explicit contact requests"]],
        ["When not to choose Hestia", ["Mass public messaging", "Anonymous networks", "Very large public infrastructure", "Federated discovery across many independent servers", "A drop-in replacement for every Telegram, Signal, or Matrix workflow"]],
      ],
      cta: ["Download Hestia", "Try Web Version", "Set up your own server"],
    },
    ru: {
      eyebrow: "Выбор мессенджера",
      title: "Почему Hestia?",
      intro: "Чем Hestia отличается от Telegram, Signal и Matrix без попытки выдать разные задачи за одну.",
      position: "Hestia — self-hosted privacy-first мессенджер для малых групп, частных сообществ и сред, где важен контроль инфраструктуры.",
      headers: ["Возможность", "Hestia", "Telegram", "Signal", "Matrix"],
      rows: tableRows.ru,
      sections: [
        ["Hestia vs Telegram", ["Telegram удобен и масштабен, но обычные cloud chats построены вокруг облачной модели Telegram. Hestia ориентирована на self-hosting, encrypted payloads before send и отсутствие глобального каталога.", "Выбирайте Hestia, когда владение инфраструктурой и небольшие доверенные группы важнее публичного discovery и больших каналов."]],
        ["Hestia vs Signal", ["Signal имеет сильную privacy-модель и E2E по умолчанию, но это не self-hosted продукт для малых частных серверов.", "Hestia дает оператору сервера больше контроля и использует другую модель доверия: TOFU и fingerprint verification."]],
        ["Hestia vs Matrix", ["Matrix — открытый federated protocol с большой экосистемой. Гибкость часто означает более сложные deployment и moderation.", "Hestia намеренно уже: проще сервер, меньше группы, меньше protocol surface для эксплуатации."]],
        ["Когда выбирать Hestia", ["Небольшие команды", "Частные группы", "Self-hosted setup", "Контролируемые среды", "Сообщества с явными contact requests"]],
        ["Когда Hestia не подходит", ["Массовые публичные рассылки", "Анонимные сети", "Очень большая публичная инфраструктура", "Federated discovery между множеством серверов", "Полная замена всех сценариев Telegram, Signal или Matrix"]],
      ],
      cta: ["Скачать Hestia", "Открыть Web-версию", "Настроить свой сервер"],
    },
    uk: {
      eyebrow: "Вибір месенджера",
      title: "Чому Hestia?",
      intro: "Чим Hestia відрізняється від Telegram, Signal і Matrix без спроби змішати різні задачі.",
      position: "Hestia — self-hosted privacy-first месенджер для малих груп, приватних спільнот і середовищ, де важливий контроль інфраструктури.",
      headers: ["Можливість", "Hestia", "Telegram", "Signal", "Matrix"],
      rows: tableRows.uk,
      sections: [
        ["Hestia vs Telegram", ["Telegram зручний і масштабний, але звичайні cloud chats побудовані навколо хмарної моделі Telegram. Hestia орієнтована на self-hosting, encrypted payloads before send і відсутність глобального каталогу.", "Обирайте Hestia, коли контроль інфраструктури й малі довірені групи важливіші за public discovery та великі канали."]],
        ["Hestia vs Signal", ["Signal має сильну privacy-модель і E2E за замовчуванням, але це не self-hosted продукт для малих приватних серверів.", "Hestia дає оператору сервера більше контролю й використовує іншу модель довіри: TOFU та fingerprint verification."]],
        ["Hestia vs Matrix", ["Matrix — відкритий federated protocol із великою екосистемою. Гнучкість часто означає складніші deployment і moderation.", "Hestia навмисно вужча: простіший сервер, менші групи, менше protocol surface для експлуатації."]],
        ["Коли обирати Hestia", ["Невеликі команди", "Приватні групи", "Self-hosted setup", "Контрольовані середовища", "Спільноти з явними contact requests"]],
        ["Коли Hestia не підходить", ["Масові публічні розсилки", "Анонімні мережі", "Дуже велика публічна інфраструктура", "Federated discovery між багатьма серверами", "Повна заміна всіх сценаріїв Telegram, Signal або Matrix"]],
      ],
      cta: ["Завантажити Hestia", "Відкрити Web-версію", "Налаштувати свій сервер"],
    },
    pl: {
      eyebrow: "Wybór komunikatora",
      title: "Dlaczego Hestia?",
      intro: "Czym Hestia różni się od Telegram, Signal i Matrix bez udawania, że rozwiązują ten sam problem.",
      position: "Hestia to self-hosted privacy-first komunikator dla małych grup, prywatnych społeczności i środowisk, gdzie ważna jest kontrola infrastruktury.",
      headers: ["Funkcja", "Hestia", "Telegram", "Signal", "Matrix"],
      rows: tableRows.pl,
      sections: [
        ["Hestia vs Telegram", ["Telegram jest wygodny i bardzo skalowalny, ale zwykłe cloud chats opierają się na modelu chmury Telegram.", "Hestia stawia na self-hosting, szyfrowanie przed wysłaniem i brak globalnego katalogu użytkowników."]],
        ["Hestia vs Signal", ["Signal ma silny model prywatności i domyślne E2E, ale nie jest produktem self-hosted dla małych prywatnych serwerów.", "Hestia daje operatorowi serwera więcej kontroli i używa innego modelu zaufania: TOFU oraz fingerprint verification."]],
        ["Hestia vs Matrix", ["Matrix to otwarty federated protocol z szerokim ekosystemem. Ta elastyczność może oznaczać trudniejsze wdrożenie i moderację.", "Hestia jest węższa: prostszy serwer, mniejsze grupy i mniej powierzchni protokołu do utrzymania."]],
        ["Kiedy wybrać Hestia", ["Małe zespoły", "Prywatne grupy", "Self-hosted setup", "Kontrolowane środowiska", "Społeczności z jawnymi contact requests"]],
        ["Kiedy nie wybierać Hestia", ["Masowa komunikacja publiczna", "Sieci anonimowe", "Bardzo duża publiczna infrastruktura", "Federated discovery między wieloma serwerami", "Pełny zamiennik każdego workflow Telegram, Signal lub Matrix"]],
      ],
      cta: ["Pobierz Hestia", "Otwórz wersję web", "Skonfiguruj własny serwer"],
    },
    es: {
      eyebrow: "Elegir mensajero",
      title: "¿Por qué Hestia?",
      intro: "Cómo Hestia se diferencia de Telegram, Signal y Matrix sin fingir que resuelven el mismo problema.",
      position: "Hestia es un mensajero self-hosted privacy-first para grupos pequeños, comunidades privadas y entornos donde importa controlar la infraestructura.",
      headers: ["Función", "Hestia", "Telegram", "Signal", "Matrix"],
      rows: tableRows.es,
      sections: [
        ["Hestia vs Telegram", ["Telegram es cómodo y masivo, pero los cloud chats normales se basan en el modelo cloud de Telegram.", "Hestia prioriza self-hosting, cifrado antes de enviar y ausencia de directorio global."]],
        ["Hestia vs Signal", ["Signal tiene un modelo fuerte de privacidad y E2E por defecto, pero no es un producto self-hosted para pequeños servidores privados.", "Hestia da más control al operador del servidor y usa otro modelo de confianza: TOFU y fingerprint verification."]],
        ["Hestia vs Matrix", ["Matrix es un federated protocol abierto con gran ecosistema. Esa flexibilidad puede hacer más complejo desplegar y moderar.", "Hestia es más estrecha: servidor simple, grupos pequeños y menos superficie de protocolo."]],
        ["Cuándo elegir Hestia", ["Equipos pequeños", "Grupos privados", "Self-hosted setup", "Entornos controlados", "Comunidades con contact requests explícitos"]],
        ["Cuándo no elegir Hestia", ["Mensajería pública masiva", "Redes anónimas", "Infraestructura pública enorme", "Federated discovery entre muchos servidores", "Sustituto total de todos los workflows de Telegram, Signal o Matrix"]],
      ],
      cta: ["Descargar Hestia", "Abrir versión web", "Configurar tu servidor"],
    },
    cs: {
      eyebrow: "Volba messengeru",
      title: "Proč Hestia?",
      intro: "Jak se Hestia liší od Telegram, Signal a Matrix bez předstírání, že řeší stejný problém.",
      position: "Hestia je self-hosted privacy-first messenger pro malé skupiny, soukromé komunity a prostředí, kde záleží na kontrole infrastruktury.",
      headers: ["Funkce", "Hestia", "Telegram", "Signal", "Matrix"],
      rows: tableRows.cs,
      sections: [
        ["Hestia vs Telegram", ["Telegram je pohodlný a velký, ale běžné cloud chats stojí na cloudovém modelu Telegram.", "Hestia míří na self-hosting, šifrování před odesláním a žádný globální adresář."]],
        ["Hestia vs Signal", ["Signal má silný model soukromí a výchozí E2E, ale není self-hosted produkt pro malé soukromé servery.", "Hestia dává operátorovi serveru více kontroly a používá jiný model důvěry: TOFU a fingerprint verification."]],
        ["Hestia vs Matrix", ["Matrix je otevřený federated protocol s širokým ekosystémem. Flexibilita může znamenat složitější nasazení a moderaci.", "Hestia je užší: jednodušší server, menší skupiny a menší plocha protokolu k provozu."]],
        ["Kdy zvolit Hestia", ["Malé týmy", "Soukromé skupiny", "Self-hosted setup", "Kontrolovaná prostředí", "Komunity s explicitními contact requests"]],
        ["Kdy Hestia nevolit", ["Masová veřejná komunikace", "Anonymní sítě", "Velmi velká veřejná infrastruktura", "Federated discovery mezi mnoha servery", "Úplná náhrada všech workflow Telegram, Signal nebo Matrix"]],
      ],
      cta: ["Stáhnout Hestia", "Otevřít webovou verzi", "Nastavit vlastní server"],
    },
    de: {
      eyebrow: "Messenger-Wahl",
      title: "Warum Hestia?",
      intro: "Wie sich Hestia von Telegram, Signal und Matrix unterscheidet, ohne so zu tun, als lösten sie dasselbe Problem.",
      position: "Hestia ist ein self-hosted privacy-first Messenger für kleine Gruppen, private Communities und Umgebungen, in denen Infrastrukturkontrolle wichtig ist.",
      headers: ["Merkmal", "Hestia", "Telegram", "Signal", "Matrix"],
      rows: tableRows.de,
      sections: [
        ["Hestia vs Telegram", ["Telegram ist bequem und skaliert groß, aber normale cloud chats basieren auf Telegrams Cloud-Modell.", "Hestia setzt auf self-hosting, Verschlüsselung vor dem Senden und kein globales Nutzerverzeichnis."]],
        ["Hestia vs Signal", ["Signal hat ein starkes Datenschutzmodell und standardmäßiges E2E, ist aber kein self-hosted Produkt für kleine private Server.", "Hestia gibt dem Serverbetreiber mehr Kontrolle und nutzt ein anderes Vertrauensmodell: TOFU und fingerprint verification."]],
        ["Hestia vs Matrix", ["Matrix ist ein offenes federated protocol mit großem Ökosystem. Diese Flexibilität kann Deployment und Moderation komplexer machen.", "Hestia ist bewusst enger: einfacherer Server, kleinere Gruppen und weniger Protokolloberfläche im Betrieb."]],
        ["Wann Hestia passt", ["Kleine Teams", "Private Gruppen", "Self-hosted setup", "Kontrollierte Umgebungen", "Communities mit expliziten contact requests"]],
        ["Wann Hestia nicht passt", ["Massenhafte öffentliche Kommunikation", "Anonyme Netzwerke", "Sehr große öffentliche Infrastruktur", "Federated discovery über viele Server", "Vollständiger Ersatz jedes Telegram-, Signal- oder Matrix-Workflows"]],
      ],
      cta: ["Hestia herunterladen", "Web-Version öffnen", "Eigenen Server einrichten"],
    },
  };

  Object.keys(comparisonData).forEach((lang) => {
    copy[lang].comparison = comparisonData[lang];
    copy[lang].nav = [copy[lang].nav[0], copy[lang].nav[1], copy[lang].nav[2], comparisonLabels[lang], copy[lang].nav[3], copy[lang].nav[4]];
    copy[lang].footer = [copy[lang].footer[0], comparisonLabels[lang], copy[lang].footer[1], copy[lang].footer[2], copy[lang].footer[3], copy[lang].footer[4]];
  });

  function merge(base, patch) {
    if (Array.isArray(base)) return Array.isArray(patch) ? patch : base.slice();
    if (typeof base !== "object" || base === null) return patch ?? base;
    const out = { ...base };
    Object.keys(patch || {}).forEach((key) => {
      out[key] = merge(base[key], patch[key]);
    });
    return out;
  }

  function escapeHtml(value) {
    return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function browserLanguage() {
    const urlLang = new URLSearchParams(window.location.search).get("lang");
    if (supported.includes(urlLang)) return urlLang;
    const saved = localStorage.getItem(storageKey);
    if (supported.includes(saved)) return saved;
    const languages = navigator.languages || [navigator.language || "en"];
    const match = languages
      .map((lang) => lang.toLowerCase().split("-")[0])
      .find((lang) => supported.includes(lang));
    return match || "en";
  }

  function pageKey() {
    const path = window.location.pathname.toLowerCase();
    if (path.includes("downloads")) return "downloads";
    if (path.includes("server-setup")) return "server";
    if (path.includes("privacy")) return "privacy";
    if (path.includes("faq")) return "faq";
    if (path.includes("comparison") || path.includes("why-hestia")) return "comparison";
    return "landing";
  }

  function langData() {
    const lang = window.HestiaLang || browserLanguage();
    const base = copy[lang] || copy.en;
    const shared =
      sharedProductContent?.locales?.[lang] ||
      sharedProductContent?.locales?.en;
    return shared ? mergeSharedProductContent(base, shared) : base;
  }

  function mergeSharedProductContent(base, shared) {
    const data = {
      ...base,
      common: { ...base.common },
      landing: { ...base.landing },
    };
    data.common.viewDownloads =
      shared.downloads?.viewDownloads || data.common.viewDownloads;
    data.landing.eyebrow = shared.hero?.eyebrow || data.landing.eyebrow;
    data.landing.title = shared.hero?.title || data.landing.title;
    data.landing.copy = shared.hero?.body || data.landing.copy;
    data.landing.web = shared.downloads?.openWeb || data.landing.web;
    data.landing.featuresEyebrow =
      shared.featuresIntro?.eyebrow || data.landing.featuresEyebrow;
    data.landing.featuresTitle =
      shared.featuresIntro?.title || data.landing.featuresTitle;
    data.landing.featuresCopy =
      shared.featuresIntro?.body || data.landing.featuresCopy;
    if (Array.isArray(shared.features)) {
      data.landing.features = shared.features.map((item) => [
        item.icon || "",
        item.title || "",
        item.body || "",
      ]);
    }
    data.landing.howEyebrow =
      shared.howItWorks?.eyebrow || data.landing.howEyebrow;
    data.landing.howTitle =
      shared.howItWorks?.title || data.landing.howTitle;
    if (Array.isArray(shared.howItWorks?.steps)) {
      data.landing.steps = shared.howItWorks.steps.map((item) => [
        item.title || "",
        item.body || "",
      ]);
    }
    data.landing.downloadsEyebrow =
      shared.downloads?.eyebrow || data.landing.downloadsEyebrow;
    data.landing.downloadsTitle =
      shared.downloads?.title || data.landing.downloadsTitle;
    data.landing.downloadsCopy =
      shared.downloads?.body || data.landing.downloadsCopy;
    data.landing.releaseDetails =
      shared.downloads?.releaseDetails || data.landing.releaseDetails;
    data.landing.releaseNotes =
      shared.downloads?.releaseNotes || data.landing.releaseNotes;
    data.landing.privacyEyebrow =
      shared.privacy?.eyebrow || data.landing.privacyEyebrow;
    data.landing.privacyTitle =
      shared.privacy?.title || data.landing.privacyTitle;
    if (Array.isArray(shared.privacy?.body)) {
      data.landing.privacy = shared.privacy.body;
    }
    return data;
  }

  async function loadSharedProductContent() {
    try {
      const response = await fetch("content/product_content.json", {
        cache: "no-cache",
      });
      if (response.ok) {
        sharedProductContent = await response.json();
      }
    } catch (_) {
      sharedProductContent = null;
    }
  }

  function linkFor(key) {
    return release.links?.[key] || "#";
  }

  function baseUrl() {
    const configured = release.siteUrl;
    if (configured && !configured.includes("example")) return configured.replace(/\/$/, "");
    return window.location.origin;
  }

  function pagePath(page = pageKey()) {
    return {
      landing: "index.html",
      downloads: "downloads.html",
      server: "server-setup.html",
      privacy: "privacy.html",
      faq: "faq.html",
      comparison: "comparison.html",
    }[page] || "index.html";
  }

  function ogPageKey(page = pageKey()) {
    return pagePath(page).replace(/\.html$/, "");
  }

  function localizedUrl(lang, page = pageKey()) {
    return `${baseUrl()}/${pagePath(page)}?lang=${lang}`;
  }

  function currentCanonical() {
    return localizedUrl(window.HestiaLang);
  }

  function pageSeo() {
    const d = langData();
    const page = pageKey();
    const ogPage = ogPageKey(page);
    const ogData = window.HestiaOgData;
    const ogCopy =
      ogData?.translations?.[window.HestiaLang]?.[ogPage] ||
      ogData?.translations?.en?.[ogPage];
    const map = {
      landing: {
        title: ogCopy?.title || `Hestia Messenger | ${d.landing.eyebrow}`,
        description: ogCopy?.description || d.landing.copy,
        keywords: "Hestia, messenger, privacy-first, encrypted messaging, self-hosted",
      },
      downloads: {
        title: ogCopy?.title || `${d.downloads.title} | Hestia Messenger`,
        description: ogCopy?.description || d.downloads.copy,
        keywords: "Hestia downloads, Android APK, Windows messenger, Linux messenger, macOS messenger",
      },
      server: {
        title: ogCopy?.title || `${d.server.title} | Hestia Messenger`,
        description: ogCopy?.description || d.server.intro,
        keywords: "Hestia server, self-hosted messenger, WSS, HTTPS, TURN",
      },
      privacy: {
        title: ogCopy?.title || `${d.privacyPage.title} | Hestia Messenger`,
        description: ogCopy?.description || d.privacyPage.intro,
        keywords: "Hestia privacy, messenger security, encrypted messages, metadata",
      },
      faq: {
        title: ogCopy?.title || `${d.faq.title} | Hestia Messenger`,
        description: ogCopy?.description || d.faq.intro,
        keywords: "Hestia FAQ, messenger questions, self-hosted messenger",
      },
      comparison: {
        title: ogCopy?.title || `${d.comparison.title} | Hestia Messenger`,
        description: ogCopy?.description || d.comparison.intro,
        keywords: "Hestia vs Telegram, Hestia vs Signal, Hestia vs Matrix, messenger comparison",
      },
    };
    return map[page] || map.landing;
  }

  function upsertMeta(selector, createTag, attrs) {
    let element = document.head.querySelector(selector);
    if (!element) {
      element = document.createElement(createTag);
      document.head.append(element);
    }
    Object.entries(attrs).forEach(([key, value]) => {
      if (key === "textContent") element.textContent = value;
      else element.setAttribute(key, value);
    });
    return element;
  }

  function updateSeo() {
    const seo = pageSeo();
    const url = currentCanonical();
    const imageLang = supported.includes(window.HestiaLang) ? window.HestiaLang : "en";
    const image = `${baseUrl()}/og/${imageLang}/${ogPageKey()}.png`;
    document.title = seo.title;
    upsertMeta('meta[name="description"]', "meta", { name: "description", content: seo.description });
    upsertMeta('meta[name="keywords"]', "meta", { name: "keywords", content: seo.keywords });
    upsertMeta('link[rel="canonical"]', "link", { rel: "canonical", href: url });

    document.head.querySelectorAll('link[rel="alternate"][data-i18n-alt]').forEach((el) => el.remove());
    supported.forEach((lang) => {
      upsertMeta(`link[rel="alternate"][hreflang="${lang}"]`, "link", {
        rel: "alternate",
        hreflang: lang,
        href: localizedUrl(lang),
        "data-i18n-alt": "true",
      });
    });
    upsertMeta('link[rel="alternate"][hreflang="x-default"]', "link", {
      rel: "alternate",
      hreflang: "x-default",
      href: localizedUrl("en"),
      "data-i18n-alt": "true",
    });

    upsertMeta('meta[property="og:title"]', "meta", { property: "og:title", content: seo.title });
    upsertMeta('meta[property="og:description"]', "meta", { property: "og:description", content: seo.description });
    upsertMeta('meta[property="og:type"]', "meta", { property: "og:type", content: "website" });
    upsertMeta('meta[property="og:url"]', "meta", { property: "og:url", content: url });
    upsertMeta('meta[property="og:image"]', "meta", { property: "og:image", content: image });
    upsertMeta('meta[property="og:image:width"]', "meta", { property: "og:image:width", content: "1200" });
    upsertMeta('meta[property="og:image:height"]', "meta", { property: "og:image:height", content: "630" });
    upsertMeta('meta[property="og:site_name"]', "meta", { property: "og:site_name", content: "Hestia" });
    upsertMeta('meta[property="og:locale"]', "meta", { property: "og:locale", content: window.HestiaLang });

    upsertMeta('meta[name="twitter:card"]', "meta", { name: "twitter:card", content: "summary_large_image" });
    upsertMeta('meta[name="twitter:title"]', "meta", { name: "twitter:title", content: seo.title });
    upsertMeta('meta[name="twitter:description"]', "meta", { name: "twitter:description", content: seo.description });
    upsertMeta('meta[name="twitter:image"]', "meta", { name: "twitter:image", content: image });

    upsertMeta('script[type="application/ld+json"][data-schema="software"]', "script", {
      type: "application/ld+json",
      "data-schema": "software",
      textContent: JSON.stringify({
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        name: "Hestia",
        description: seo.description,
        operatingSystem: "Android, Windows, macOS, Linux, Web",
        applicationCategory: "CommunicationApplication",
        offers: {
          "@type": "Offer",
          price: "0",
          priceCurrency: "USD",
        },
        url,
      }),
    });
  }

  function platformLabel(key, index) {
    return langData().platform[key]?.[index] || copy.en.platform[key]?.[index] || key;
  }

  function platformDescription(key) {
    const descriptions = {
      android: {
        en: "Install the Android APK directly.",
        ru: "Установите Android APK напрямую.",
        uk: "Встановіть Android APK напряму.",
        pl: "Zainstaluj Android APK bezpośrednio.",
        es: "Instala el APK de Android directamente.",
        cs: "Nainstalujte Android APK přímo.",
        de: "Installieren Sie die Android-APK direkt.",
      },
      windows: {
        en: "Desktop installer for Windows PCs.",
        ru: "Установщик для Windows ПК.",
        uk: "Інсталятор для Windows ПК.",
        pl: "Instalator dla komputerów Windows.",
        es: "Instalador de escritorio para Windows.",
        cs: "Instalátor pro počítače Windows.",
        de: "Desktop-Installer für Windows-PCs.",
      },
      windowsPortable: {
        en: "Portable Windows package without an installer.",
        ru: "Портативный Windows-пакет без установщика.",
        uk: "Портативний Windows-пакет без інсталятора.",
        pl: "Przenośny pakiet Windows bez instalatora.",
        es: "Paquete portátil de Windows sin instalador.",
        cs: "Přenosný balíček Windows bez instalátoru.",
        de: "Portables Windows-Paket ohne Installer.",
      },
      macos: {
        en: "Desktop package for Mac devices.",
        ru: "Пакет для устройств Mac.",
        uk: "Пакет для пристроїв Mac.",
        pl: "Pakiet dla urządzeń Mac.",
        es: "Paquete para dispositivos Mac.",
        cs: "Balíček pro zařízení Mac.",
        de: "Desktop-Paket für Mac-Geräte.",
      },
      linux: {
        en: "Portable desktop build for Linux systems.",
        ru: "Портативная сборка для Linux.",
        uk: "Портативна збірка для Linux.",
        pl: "Przenośna wersja dla Linux.",
        es: "Build portátil para Linux.",
        cs: "Přenosná verze pro Linux.",
        de: "Portable Desktop-Version für Linux.",
      },
      web: {
        en: "Static web client bundle for hosting.",
        ru: "Статическая Web-сборка для хостинга.",
        uk: "Статична Web-збірка для хостингу.",
        pl: "Statyczny pakiet web do hostingu.",
        es: "Bundle web estático para hosting.",
        cs: "Statický webový balíček pro hosting.",
        de: "Statisches Web-Bundle für Hosting.",
      },
      server: {
        en: "Backend server package for self-hosting.",
        ru: "Пакет backend-сервера для self-hosting.",
        uk: "Пакет backend-сервера для self-hosting.",
        pl: "Pakiet backend serwera do self-hostingu.",
        es: "Paquete backend del servidor para self-hosting.",
        cs: "Backend balíček serveru pro self-hosting.",
        de: "Backend-Serverpaket für Self-Hosting.",
      },
      landing: {
        en: "Static landing/site package for deployment.",
        ru: "Статический пакет лендинга/site для deployment.",
        uk: "Статичний пакет лендингу/site для deployment.",
        pl: "Statyczny pakiet landing/site do wdrożenia.",
        es: "Paquete estático landing/site para despliegue.",
        cs: "Statický balíček landing/site pro nasazení.",
        de: "Statisches Landing/site-Paket für Deployment.",
      },
      ios: {
        en: "Not available without Apple Developer Program signing and distribution.",
        ru: "Недоступно без Apple Developer Program, подписи и distribution.",
        uk: "Недоступно без Apple Developer Program, підпису й distribution.",
        pl: "Niedostępne bez Apple Developer Program, podpisu i dystrybucji.",
        es: "No disponible sin Apple Developer Program, firma y distribución.",
        cs: "Nedostupné bez Apple Developer Program, podpisu a distribuce.",
        de: "Nicht verfügbar ohne Apple Developer Program, Signierung und Distribution.",
      },
      checksums: {
        en: "SHA-256 hashes for verifying release files.",
        ru: "SHA-256 хэши для проверки релизных файлов.",
        uk: "SHA-256 хеші для перевірки релізних файлів.",
        pl: "Hashe SHA-256 do weryfikacji plików wydania.",
        es: "Hashes SHA-256 para verificar archivos del release.",
        cs: "SHA-256 hashe pro ověření souborů vydání.",
        de: "SHA-256 Hashes zur Prüfung der Release-Dateien.",
      },
    };
    return descriptions[key]?.[window.HestiaLang] || descriptions[key]?.en || "";
  }

  function renderHeader() {
    const nav = document.querySelector(".site-nav");
    if (!nav) return;
    const d = langData();
    const links = [
      ["index.html#features", d.nav[0]],
      [linkFor("privacy"), d.nav[1]],
      [linkFor("serverGuide"), d.nav[2]],
      [linkFor("comparison"), d.nav[3]],
      [linkFor("faq"), d.nav[4]],
      ["downloads.html", d.nav[5]],
    ];
    nav.innerHTML = links
      .map(([href, text]) => `<a class="nav-link" href="${href}">${escapeHtml(text)}</a>`)
      .join("");
    nav.appendChild(languageSwitcher());
  }

  function languageSwitcher() {
    const wrap = document.createElement("label");
    wrap.className = "language-switcher";
    wrap.setAttribute("aria-label", "Language");
    const select = document.createElement("select");
    supported.forEach((lang) => {
      const option = document.createElement("option");
      option.value = lang;
      option.textContent = names[lang];
      option.selected = lang === window.HestiaLang;
      select.append(option);
    });
    select.addEventListener("change", () => {
      localStorage.setItem(storageKey, select.value);
      window.HestiaLang = select.value;
      const nextUrl = new URL(window.location.href);
      nextUrl.searchParams.set("lang", select.value);
      window.history.replaceState({}, "", nextUrl);
      document.dispatchEvent(
        new CustomEvent("hestia:language-change", {
          detail: { language: select.value },
        }),
      );
      renderAll();
    });
    wrap.append(select);
    return wrap;
  }

  function renderFooter() {
    const d = langData();
    document.querySelectorAll("[data-site-version]").forEach((el) => {
      el.textContent = release.currentVersion || "preview";
    });
    document.querySelectorAll(".site-footer").forEach((footer) => {
      const paragraphs = footer.querySelectorAll("p:not([data-analytics-notice])");
      if (paragraphs[0]) {
        paragraphs[0].innerHTML = `${escapeHtml(d.common.version)} <span data-site-version>${escapeHtml(release.currentVersion || "preview")}</span>`;
      }
      if (paragraphs[1]) {
        paragraphs[1].textContent = d.common.copyright || copy.en.common.copyright;
      }
    });
    document.querySelectorAll(".footer-links").forEach((footer) => {
      footer.innerHTML = [
        [linkFor("privacy"), d.footer[0]],
        [linkFor("comparison"), d.footer[1]],
        [linkFor("faq"), d.footer[2]],
        [linkFor("source"), d.footer[3]],
        [linkFor("docs"), d.footer[4]],
        [linkFor("serverGuide"), d.footer[5]],
      ]
        .map(([href, text]) => `<a href="${href}">${escapeHtml(text)}</a>`)
        .join("");
    });
  }

  function renderLanding() {
    const d = langData().landing;
    document.querySelector("main").innerHTML = `
      <section class="hero" aria-labelledby="hero-title">
        <div class="hero-shell">
          <div class="hero-content">
            <picture class="hero-logo" aria-hidden="true"><source srcset="logo/logo_dark.png" media="(prefers-color-scheme: dark)"><img src="logo/logo.png" alt=""></picture>
            <p class="eyebrow">${escapeHtml(d.eyebrow)}</p>
            <h1 id="hero-title">Hestia</h1>
            <p class="hero-copy">${escapeHtml(d.copy)}</p>
            <div class="cta-row" aria-label="Recommended download">
              <a class="button button-primary" id="primary-download" href="#downloads">${escapeHtml(langData().common.viewDownloads)}</a>
              <a class="button button-secondary" href="${platforms.web?.url || "#"}">${escapeHtml(d.web)}</a>
            </div>
            <p class="platform-note" id="platform-note" aria-live="polite"></p>
          </div>
          <div class="hero-art" aria-hidden="true">
            <div class="hero-illustration">
              <img src="assets/illustrations/hero/hestia-hero-connection.svg" alt="" loading="eager">
            </div>
          </div>
        </div>
      </section>
      <section class="section features" id="features" aria-labelledby="features-title">
        <div class="section-heading"><div><p class="eyebrow">${escapeHtml(d.featuresEyebrow)}</p><h2 id="features-title">${escapeHtml(d.featuresTitle)}</h2></div><p class="section-copy">${escapeHtml(d.featuresCopy)}</p></div>
        <div class="feature-grid">${d.features.map((f, i) => `<article class="feature-card"><span class="feature-icon" aria-hidden="true">${featureIcon(i)}</span><h3>${escapeHtml(f[1])}</h3><p>${escapeHtml(f[2])}</p></article>`).join("")}</div>
      </section>
      <section class="section how-it-works" id="how-it-works" aria-labelledby="how-title">
        <div class="section-heading"><div><p class="eyebrow">${escapeHtml(d.howEyebrow)}</p><h2 id="how-title">${escapeHtml(d.howTitle)}</h2></div></div>
        <ol class="steps-list">${d.steps.map((s, i) => `<li><span class="step-number">${String(i + 1).padStart(2, "0")}</span><div><h3>${escapeHtml(s[0])}</h3><p>${escapeHtml(s[1])}</p></div></li>`).join("")}</ol>
      </section>
      <section class="downloads" id="downloads" aria-labelledby="downloads-title">
        <div class="section-heading"><div><p class="eyebrow">${escapeHtml(d.downloadsEyebrow)}</p><h2 id="downloads-title">${escapeHtml(d.downloadsTitle)}</h2></div><p class="section-copy">${escapeHtml(d.downloadsCopy)}</p></div>
        <div class="section-actions"><a class="button button-secondary" href="downloads.html">${escapeHtml(d.releaseDetails)}</a><a class="release-link" href="${release.releaseNotesUrl || "#"}">${escapeHtml(d.releaseNotes)}</a></div>
        <div class="download-grid">${["android", "windows", "macos", "linux", "web", "server"].map(downloadCard).join("")}</div>
      </section>
      <section class="section privacy" id="privacy" aria-labelledby="privacy-title">
        <div class="privacy-panel"><div><p class="eyebrow">${escapeHtml(d.privacyEyebrow)}</p><h2 id="privacy-title">${escapeHtml(d.privacyTitle)}</h2></div><div class="privacy-points">${d.privacy.map((p) => `<p>${escapeHtml(p)}</p>`).join("")}</div></div>
      </section>`;
  }

  function featureIcon(index) {
    const icons = [
      `<svg viewBox="0 0 24 24" focusable="false"><path d="M5 7.5A3.5 3.5 0 0 1 8.5 4h7A3.5 3.5 0 0 1 19 7.5v4A3.5 3.5 0 0 1 15.5 15H11l-3.8 3.2c-.6.5-1.5.1-1.5-.7V15.7A3.5 3.5 0 0 1 5 12.5v-5Z"/></svg>`,
      `<svg viewBox="0 0 24 24" focusable="false"><path d="M5 6.5A2.5 2.5 0 0 1 7.5 4H11l2 2h3.5A2.5 2.5 0 0 1 19 8.5v9A2.5 2.5 0 0 1 16.5 20h-9A2.5 2.5 0 0 1 5 17.5v-11Z"/><path d="m9 14 2-2 2.5 2.5L15 13l3 3"/></svg>`,
      `<svg viewBox="0 0 24 24" focusable="false"><path d="M5 8.5A2.5 2.5 0 0 1 7.5 6h6A2.5 2.5 0 0 1 16 8.5v7a2.5 2.5 0 0 1-2.5 2.5h-6A2.5 2.5 0 0 1 5 15.5v-7Z"/><path d="m16 10.2 2.8-2c.8-.6 1.9 0 1.9 1v5.6c0 1-.9 1.6-1.7 1l-3-2.1"/></svg>`,
      `<svg viewBox="0 0 24 24" focusable="false"><path d="M4.5 10.2 12 4l7.5 6.2v7.3A2.5 2.5 0 0 1 17 20H7a2.5 2.5 0 0 1-2.5-2.5v-7.3Z"/><path d="M9.2 20v-5.5A1.7 1.7 0 0 1 10.9 13h2.2a1.7 1.7 0 0 1 1.7 1.5V20"/></svg>`,
      `<svg viewBox="0 0 24 24" focusable="false"><path d="M12 5.2a6.8 6.8 0 1 0 6.8 6.8"/><path d="M12 8.3v4.1l2.9 1.8"/><path d="M12 3.6V6"/><path d="M20.4 12h-2.4"/></svg>`,
      `<svg viewBox="0 0 24 24" focusable="false"><path d="M12 4.2 18.6 7v5.4c0 3.6-2.4 6.8-6.6 7.8-4.2-1-6.6-4.2-6.6-7.8V7L12 4.2Z"/><path d="m9.3 12.2 1.9 1.9 3.7-4"/></svg>`,
    ];
    return icons[index] || icons[0];
  }

  function downloadCard(key) {
    const platform = platforms[key] || {};
    const wide = key === "server" ? " download-card-wide" : "";
    const available = platform.available !== false && !!platform.url;
    const action = available
      ? `<a class="button button-download" href="${platform.url}" rel="noopener">${escapeHtml(platformLabel(key, 2))}</a>`
      : `<span class="button button-disabled" aria-disabled="true">${escapeHtml(langData().downloads.unavailable || "Coming later")}</span>`;
    return `<article class="download-card${wide}${available ? "" : " is-disabled"}" data-platform-card="${key}"><div><h3>${escapeHtml(platformLabel(key, 0))}</h3><p>${escapeHtml(platformDescription(key))}</p></div>${action}</article>`;
  }

  function renderDownloads() {
    const d = langData().downloads;
    const availableKeys = ["android", "windows", "windowsPortable", "web", "server", "landing", "checksums"];
    const unavailableKeys = ["linux", "macos", "ios"];
    document.querySelector("main").innerHTML = `
      <section class="download-page-hero" aria-labelledby="download-page-title">
        <div class="download-page-heading">
          <p class="eyebrow">${escapeHtml(d.eyebrow)}</p><h1 id="download-page-title">${escapeHtml(d.title)}</h1><p class="hero-copy">${escapeHtml(d.copy)}</p>
          <div class="cta-row"><a class="button button-primary" id="primary-download" href="#release-list">${escapeHtml(d.recommended)}</a><a class="button button-secondary" href="${release.releasePageUrl || release.releaseNotesUrl || "#"}">${escapeHtml(d.releasePage || "GitHub Release page")}</a></div>
          <p class="platform-note" id="platform-note" aria-live="polite"></p>
        </div>
      </section>
      <section class="section release-section" aria-labelledby="release-title">
        <div class="section-heading"><div><p class="eyebrow">${escapeHtml(d.current)}</p><h2 id="release-title">Hestia <span>${escapeHtml(release.currentVersion || "preview")}</span></h2></div><p class="section-copy">${escapeHtml(d.sectionCopy)}</p></div>
        <div class="release-toolbar"><a class="release-link" href="${release.releasePageUrl || release.releaseNotesUrl || "#"}">${escapeHtml(d.releasePage || "GitHub Release page")}</a><a class="release-link" href="${release.checksumUrl || "#"}">${escapeHtml(d.checksums)}</a><a class="release-link" href="${release.updateManifestUrl || "#"}">latest.json</a><a class="release-link" href="${linkFor("serverGuide")}">${escapeHtml(d.serverGuide)}</a></div>
        <div class="release-install"><h3>${escapeHtml(d.installTitle || "Install safely")}</h3><ol>${(d.installSteps || copy.en.downloads.installSteps).map((step) => `<li>${escapeHtml(step)}</li>`).join("")}</ol></div>
        <h3 class="release-subtitle">${escapeHtml(d.available || "Available downloads")}</h3>
        <div class="release-list" id="release-list">${availableKeys.map(releaseRow).join("")}</div>
        <h3 class="release-subtitle">${escapeHtml(d.unavailable || "Coming later")}</h3>
        <div class="release-list release-list-status">${unavailableKeys.map(releaseRow).join("")}</div>
      </section>`;
  }

  function releaseRow(key) {
    const p = platforms[key] || {};
    const d = langData();
    const available = p.available !== false && !!p.url;
    const action = available
      ? `<a class="button button-download" href="${p.url}" rel="noopener">${escapeHtml(platformLabel(key, 2))}</a>`
      : `<span class="button button-disabled" aria-disabled="true">${escapeHtml(d.downloads.unavailable || "Coming later")}</span>`;
    const checksum = available
      ? `<code class="checksum">${escapeHtml(p.checksum || "")}</code>`
      : `<p class="release-status">${escapeHtml(platformDescription(key))}</p>`;
    return `<article class="release-row${available ? "" : " is-disabled"}" data-platform-card="${key}"><div><h3>${escapeHtml(platformLabel(key, 0))}</h3><p>${escapeHtml(available ? platformDescription(key) : d.downloads.status || "Status")}</p><div class="release-meta"><span class="release-meta-item">${escapeHtml(d.common.type)}: ${escapeHtml(p.fileType || "")}</span><span class="release-meta-item">${escapeHtml(d.downloads.version)}: ${escapeHtml(release.currentVersion || "")}</span><span class="release-meta-item">${escapeHtml(d.common.size)}: ${escapeHtml(p.fileSize || "")}</span></div>${checksum}</div><div class="release-actions"><span class="release-file">${escapeHtml(p.fileName || "")}</span>${action}</div></article>`;
  }

  function renderGuide(kind) {
    const data = langData()[kind === "server" ? "server" : "privacyPage"];
    const ids = kind === "server"
      ? ["requirements", "before-starting", "server-code", "environment", "start-server", "reverse-proxy", "turn", "connect-client", "verify", "security", "troubleshooting"]
      : ["protected", "server-visible", "trust-model", "not-protected", "local-data", "push", "server-model", "self-hosted", "recommendations", "limitations", "future"];
    document.querySelector("main").innerHTML = `
      <section class="guide-hero" aria-labelledby="guide-title"><div class="guide-hero-content"><p class="eyebrow">${escapeHtml(data.eyebrow)}</p><h1 id="guide-title">${escapeHtml(data.title)}</h1><p class="hero-copy">${escapeHtml(data.intro)}</p><div class="note-block">${escapeHtml(data.note)}</div></div></section>
      <section class="guide-layout" aria-label="${escapeHtml(data.title)}"><aside class="guide-toc" aria-label="${escapeHtml(data.title)}">${data.toc.map((item, i) => `<a href="#${ids[i]}">${escapeHtml(item)}</a>`).join("")}</aside><div class="guide-content">${data.sections.map((section, i) => guideSection(section, ids[i])).join("")}</div></section>`;
  }

  function renderFaq() {
    const data = langData().faq;
    document.querySelector("main").innerHTML = `
      <section class="guide-hero" aria-labelledby="faq-title">
        <div class="guide-hero-content">
          <p class="eyebrow">${escapeHtml(data.eyebrow)}</p>
          <h1 id="faq-title">${escapeHtml(data.title)}</h1>
          <p class="hero-copy">${escapeHtml(data.intro)}</p>
        </div>
      </section>
      <section class="faq-layout" aria-label="${escapeHtml(data.title)}">
        ${data.sections.map((section, index) => faqSection(section, index)).join("")}
      </section>`;
  }

  function faqSection(section, index) {
    const [title, items] = section;
    const id = `faq-${index + 1}`;
    return `<section class="faq-section" id="${id}">
      <h2>${escapeHtml(title)}</h2>
      <div class="faq-items">
        ${items.map((item, itemIndex) => faqItem(item, itemIndex === 0 && index === 0)).join("")}
      </div>
    </section>`;
  }

  function faqItem(item, open) {
    return `<details class="faq-item"${open ? " open" : ""}>
      <summary>${escapeHtml(item[0])}</summary>
      <p>${escapeHtml(item[1])}</p>
    </details>`;
  }

  function renderComparison() {
    const data = langData().comparison;
    document.querySelector("main").innerHTML = `
      <section class="guide-hero" aria-labelledby="comparison-title">
        <div class="guide-hero-content">
          <p class="eyebrow">${escapeHtml(data.eyebrow)}</p>
          <h1 id="comparison-title">${escapeHtml(data.title)}</h1>
          <p class="hero-copy">${escapeHtml(data.intro)}</p>
          <div class="note-block">${escapeHtml(data.position)}</div>
        </div>
      </section>
      <section class="comparison-layout" aria-label="${escapeHtml(data.title)}">
        <div class="comparison-table-wrap">${comparisonTable(data)}</div>
        <div class="comparison-sections">${data.sections.map(comparisonSection).join("")}</div>
        <div class="comparison-cta">
          <a class="button button-primary" href="downloads.html">${escapeHtml(data.cta[0])}</a>
          <a class="button button-secondary" href="${platforms.web?.url || "#"}">${escapeHtml(data.cta[1])}</a>
          <a class="button button-secondary" href="${linkFor("serverGuide")}">${escapeHtml(data.cta[2])}</a>
        </div>
      </section>`;
  }

  function comparisonTable(data) {
    return `<table class="comparison-table">
      <thead><tr>${data.headers.map((header) => `<th>${escapeHtml(header)}</th>`).join("")}</tr></thead>
      <tbody>${data.rows.map((row) => `<tr>${row.map((cell) => `<td>${escapeHtml(cell)}</td>`).join("")}</tr>`).join("")}</tbody>
    </table>`;
  }

  function comparisonSection(section) {
    const [title, items] = section;
    return `<article class="comparison-card">
      <h2>${escapeHtml(title)}</h2>
      ${items.length > 2 ? `<ul class="check-list">${items.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul>` : items.map((item) => `<p>${escapeHtml(item)}</p>`).join("")}
    </article>`;
  }

  function guideSection(section, id) {
    const [title, items, code] = section;
    const list = items.length > 1
      ? `<ul class="check-list ${items.length > 4 ? "two-column-list" : ""}">${items.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul>`
      : `<p>${escapeHtml(items[0] || "")}</p>`;
    return `<section class="guide-section" id="${id}"><p class="eyebrow">${escapeHtml(id.split("-")[0])}</p><h2>${escapeHtml(title)}</h2>${list}${code ? `<pre><code>${escapeHtml(code)}</code></pre>` : ""}</section>`;
  }

  function setRecommended() {
    const detected = typeof window.detectPlatform === "function" ? window.detectPlatform() : null;
    const primary = document.querySelector("#primary-download");
    const note = document.querySelector("#platform-note");
    document.querySelectorAll("[data-platform-card]").forEach((card) => {
      card.classList.toggle("is-recommended", card.dataset.platformCard === detected);
    });
    if (!primary || !note) return;
    if (!detected || !platforms[detected] || platforms[detected].available === false) {
      primary.textContent = langData().common.viewDownloads;
      primary.href = pageKey() === "downloads" ? "#release-list" : "#downloads";
      note.textContent = platforms[detected]?.available === false
        ? platformDescription(detected)
        : langData().common.unknown;
      return;
    }
    primary.textContent = platformLabel(detected, 1);
    primary.href = platforms[detected].url || "#";
    note.textContent = langData().common.recommended.replace("{platform}", platformLabel(detected, 0));
  }

  function renderCurrentPage() {
    const page = pageKey();
    if (page === "landing") renderLanding();
    if (page === "downloads") renderDownloads();
    if (page === "server") renderGuide("server");
    if (page === "privacy") renderGuide("privacy");
    if (page === "faq") renderFaq();
    if (page === "comparison") renderComparison();
  }

  function renderAll() {
    document.documentElement.lang = window.HestiaLang;
    updateSeo();
    renderHeader();
    renderCurrentPage();
    renderFooter();
    setRecommended();
    document.dispatchEvent(new CustomEvent("hestia:render"));
  }

  window.HestiaLang = browserLanguage();
  window.HestiaI18n = { renderAll, supported, names };
  document.addEventListener("DOMContentLoaded", () => {
    loadSharedProductContent().finally(renderAll);
  });
})();
