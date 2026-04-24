# Hestia Content Sync

Hestia now has one product-content source for the landing page and in-app onboarding:

- Shared source: `Landing_Hestia/content/product_content.json`
- Flutter loader: `lib/services/product_content_service.dart`
- App usage: `lib/screens/onboarding_screen.dart`
- Web usage: `Landing_Hestia/JS/i18n.js`

## Audit Result

Before sync:

- Landing used product language such as "Encrypted messaging, file transfer, and calls..." and "Private communication without the theater."
- Onboarding used separate wording such as "A quiet messenger..." and "Private by design."
- Feature names differed between app and site.

After sync:

- Onboarding pulls hero, privacy, how-it-works, calls/files, server selection, and get-started copy from the same JSON as the landing page.
- Landing still keeps its broader page-specific i18n data, but its core product sections are overridden from shared content before render.
- Flutter keeps app-control labels such as Skip, Next, Register, and Login in ARB/localizations.

## Shared Structure

```json
{
  "version": 1,
  "locales": {
    "en": {
      "hero": {},
      "featuresIntro": {},
      "features": [],
      "howItWorks": {},
      "privacy": {},
      "downloads": {},
      "serverChoice": {},
      "getStarted": {}
    }
  }
}
```

## Canonical Feature Names

- Private messaging
- Encrypted file transfer
- Voice and video calls
- Self-hosted option
- Local storage
- Fingerprint verification

