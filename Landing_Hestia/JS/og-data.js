(function (root) {
  const data = {
    languages: ["en", "uk", "ru", "pl", "es", "cs", "de"],
    pages: ["index", "downloads", "server-setup", "privacy", "faq", "comparison"],
    languageNames: {
      en: "English",
      uk: "Українська",
      ru: "Русский",
      pl: "Polski",
      es: "Español",
      cs: "Čeština",
      de: "Deutsch",
    },
    translations: {
      en: {
        index: {
          title: "Hestia Messenger",
          description: "Private messenger for people you trust: family, close friends, and small teams.",
        },
        downloads: {
          title: "Get Hestia",
          description: "Download Hestia for Android, macOS, Linux, or open the web version.",
        },
        "server-setup": {
          title: "Server setup guide",
          description: "Run a self-hosted Hestia server with HTTPS, WSS, environment variables, and TURN guidance.",
        },
        privacy: {
          title: "Privacy & Security",
          description: "Understand what Hestia protects, what metadata remains visible, and where the security model has limits.",
        },
        faq: {
          title: "FAQ / Common Questions",
          description: "Short answers about Hestia, privacy, calls, files, self-hosting, and technical choices.",
        },
        comparison: {
          title: "Why Hestia?",
          description: "How Hestia differs from Telegram, Signal, and Matrix without pretending they solve the same problem.",
        },
      },
      uk: {
        index: {
          title: "Hestia Messenger",
          description: "Приватний месенджер для родини, близьких друзів і невеликих команд.",
        },
        downloads: {
          title: "Завантажити Hestia",
          description: "Завантажте Hestia для Android, macOS, Linux або відкрийте web-версію.",
        },
        "server-setup": {
          title: "Інструкція з налаштування сервера",
          description: "Запустіть self-hosted сервер Hestia з HTTPS, WSS, environment variables і TURN-рекомендаціями.",
        },
        privacy: {
          title: "Приватність і безпека",
          description: "Що Hestia захищає, яка metadata лишається видимою та де є межі моделі безпеки.",
        },
        faq: {
          title: "FAQ / Поширені питання",
          description: "Короткі відповіді про Hestia, приватність, дзвінки, файли, self-hosting і технічні рішення.",
        },
        comparison: {
          title: "Чому Hestia?",
          description: "Чим Hestia відрізняється від Telegram, Signal і Matrix без змішування різних задач.",
        },
      },
      ru: {
        index: {
          title: "Hestia Messenger",
          description: "Приватный мессенджер для семьи, близких друзей и небольших команд.",
        },
        downloads: {
          title: "Скачать Hestia",
          description: "Скачайте Hestia для Android, macOS, Linux или откройте web-версию.",
        },
        "server-setup": {
          title: "Инструкция по настройке сервера",
          description: "Запустите self-hosted сервер Hestia с HTTPS, WSS, environment variables и TURN-рекомендациями.",
        },
        privacy: {
          title: "Приватность и безопасность",
          description: "Что защищает Hestia, какая metadata остается видимой и где есть ограничения модели безопасности.",
        },
        faq: {
          title: "FAQ / Частые вопросы",
          description: "Короткие ответы про Hestia, приватность, звонки, файлы, self-hosting и технические решения.",
        },
        comparison: {
          title: "Почему Hestia?",
          description: "Чем Hestia отличается от Telegram, Signal и Matrix без попытки смешать разные задачи.",
        },
      },
      pl: {
        index: {
          title: "Hestia Messenger",
          description: "Prywatny komunikator dla rodziny, bliskich znajomych i małych zespołów.",
        },
        downloads: {
          title: "Pobierz Hestia",
          description: "Pobierz Hestia dla Androida, macOS, Linux albo otwórz wersję web.",
        },
        "server-setup": {
          title: "Instrukcja konfiguracji serwera",
          description: "Uruchom self-hosted serwer Hestia z HTTPS, WSS, environment variables i wskazówkami TURN.",
        },
        privacy: {
          title: "Prywatność i bezpieczeństwo",
          description: "Co Hestia chroni, jaka metadata pozostaje widoczna i gdzie są ograniczenia modelu bezpieczeństwa.",
        },
        faq: {
          title: "FAQ / Częste pytania",
          description: "Krótkie odpowiedzi o Hestia, prywatności, rozmowach, plikach, self-hostingu i decyzjach technicznych.",
        },
        comparison: {
          title: "Dlaczego Hestia?",
          description: "Czym Hestia różni się od Telegram, Signal i Matrix bez udawania, że rozwiązują ten sam problem.",
        },
      },
      es: {
        index: {
          title: "Hestia Messenger",
          description: "Mensajero privado para familia, amistades cercanas y equipos pequeños.",
        },
        downloads: {
          title: "Obtener Hestia",
          description: "Descarga Hestia para Android, macOS, Linux o abre la versión web.",
        },
        "server-setup": {
          title: "Guía de configuración del servidor",
          description: "Ejecuta un servidor Hestia self-hosted con HTTPS, WSS, environment variables y guía TURN.",
        },
        privacy: {
          title: "Privacidad y seguridad",
          description: "Qué protege Hestia, qué metadata sigue visible y dónde están los límites del modelo de seguridad.",
        },
        faq: {
          title: "FAQ / Preguntas frecuentes",
          description: "Respuestas cortas sobre Hestia, privacidad, llamadas, archivos, self-hosting y decisiones técnicas.",
        },
        comparison: {
          title: "¿Por qué Hestia?",
          description: "Cómo Hestia se diferencia de Telegram, Signal y Matrix sin fingir que resuelven el mismo problema.",
        },
      },
      cs: {
        index: {
          title: "Hestia Messenger",
          description: "Soukromý messenger pro rodinu, blízké přátele a malé týmy.",
        },
        downloads: {
          title: "Získat Hestia",
          description: "Stáhněte Hestia pro Android, macOS, Linux nebo otevřete webovou verzi.",
        },
        "server-setup": {
          title: "Průvodce nastavením serveru",
          description: "Spusťte self-hosted server Hestia s HTTPS, WSS, environment variables a TURN doporučeními.",
        },
        privacy: {
          title: "Soukromí a bezpečnost",
          description: "Co Hestia chrání, jaká metadata zůstávají viditelná a kde jsou limity bezpečnostního modelu.",
        },
        faq: {
          title: "FAQ / Časté otázky",
          description: "Krátké odpovědi o Hestia, soukromí, hovorech, souborech, self-hostingu a technických volbách.",
        },
        comparison: {
          title: "Proč Hestia?",
          description: "Jak se Hestia liší od Telegram, Signal a Matrix bez předstírání, že řeší stejný problém.",
        },
      },
      de: {
        index: {
          title: "Hestia Messenger",
          description: "Privater Messenger für Familie, enge Freunde und kleine Teams.",
        },
        downloads: {
          title: "Hestia herunterladen",
          description: "Laden Sie Hestia für Android, macOS, Linux herunter oder öffnen Sie die Web-Version.",
        },
        "server-setup": {
          title: "Server-Einrichtungsanleitung",
          description: "Betreiben Sie einen self-hosted Hestia-Server mit HTTPS, WSS, environment variables und TURN-Hinweisen.",
        },
        privacy: {
          title: "Datenschutz & Sicherheit",
          description: "Was Hestia schützt, welche Metadata sichtbar bleibt und wo das Sicherheitsmodell Grenzen hat.",
        },
        faq: {
          title: "FAQ / Häufige Fragen",
          description: "Kurze Antworten zu Hestia, Datenschutz, Anrufen, Dateien, Self-hosting und technischen Entscheidungen.",
        },
        comparison: {
          title: "Warum Hestia?",
          description: "Wie sich Hestia von Telegram, Signal und Matrix unterscheidet, ohne dieselbe Aufgabe vorzutäuschen.",
        },
      },
    },
  };

  root.HestiaOgData = data;
  if (typeof module !== "undefined") {
    module.exports = data;
  }
})(typeof window !== "undefined" ? window : globalThis);



