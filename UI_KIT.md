# Hestia UI Kit

UI Kit builds on the Hestia design tokens:

- Flutter tokens and widgets: `lib/theme/theme.dart`, `lib/widgets/ui_kit.dart`
- Web tokens and classes: `Landing_Hestia/CSS/variables.css`, `Landing_Hestia/CSS/ui-kit.css`

The kit stays intentionally small: it covers app/navigation primitives, cards, badges, and Hestia-specific chat/call/contact components.

## Component List

| Area | Flutter | Web CSS |
| --- | --- | --- |
| Primary button | `HestiaButton.primary` | `.ui-button .ui-button-primary` |
| Secondary button | `HestiaButton.secondary` | `.ui-button .ui-button-secondary` |
| Outline button | `HestiaButton.outline` | `.ui-button .ui-button-outline` |
| Text input | `HestiaTextInput` | `.ui-field`, `.ui-input` |
| Password input | `HestiaTextInput.password` | `.ui-input[type="password"]` |
| Search input | `HestiaTextInput.search` | `.ui-search` |
| Message preview card | `HestiaMessagePreviewCard` | `.ui-card .ui-message-preview` |
| Download card | `HestiaDownloadCard` | `.ui-card .ui-download-card` |
| Feature card | `HestiaFeatureCard` | `.ui-card .ui-feature-card` |
| Header | `HestiaHeader` | `.ui-header` |
| Tabs | `HestiaTabs` | `.ui-tabs`, `.ui-tab` |
| Drawer/menu | `HestiaMenuDrawer` | `.ui-menu`, `.ui-menu-item` |
| Unread badge | `HestiaUnreadBadge` | `.ui-badge` |
| Status badge | `HestiaStatusBadge` | `.ui-status` |
| Chat bubble | `HestiaChatBubble` | `.ui-chat-bubble` |
| Message reply block | `HestiaReplyBlock` | `.ui-reply-block` |
| File attachment preview | `HestiaAttachmentPreview` | `.ui-attachment-preview` |
| Incoming call UI | `HestiaIncomingCallCard` | `.ui-incoming-call` |
| Contact request card | `HestiaContactRequestCard` | `.ui-contact-request` |

## Flutter Examples

```dart
import 'package:hestia/widgets/ui_kit.dart';

HestiaButton.primary(
  icon: Icons.lock_outline,
  label: Text(context.l10n.login),
  onPressed: _submit,
);

HestiaTextInput.search(
  controller: searchCtrl,
  label: context.l10n.findUsername,
  onSubmitted: chat.searchUsername,
);
```

```dart
HestiaMessagePreviewCard(
  title: conversation.peerNickname,
  preview: subtitle,
  unreadCount: unreadCount,
  muted: settings.muted,
  pinned: settings.pinned,
  onTap: () => onOpenChat(conversation.peerUserId, conversation.peerNickname),
);
```

```dart
HestiaChatBubble(
  message: message,
  timestampLabel: DateFormat('dd.MM HH:mm').format(message.timestamp),
  replyBlock: message.replyToMessageId == null
      ? null
      : HestiaReplyBlock(
          sender: message.replyToSenderName ?? context.l10n.originalMessage,
          preview: message.replyPreviewText ?? context.l10n.originalMessageUnavailable,
          onTap: () => _scrollToMessage(message.replyToMessageId!),
        ),
  attachmentPreview: message.attachment == null
      ? null
      : HestiaAttachmentPreview(
          attachment: message.attachment!,
          openLabel: context.l10n.open,
          saveLabel: context.l10n.save,
          onSave: () => _saveAttachment(message.attachment!),
        ),
);
```

```dart
HestiaIncomingCallCard(
  callerName: info.fromNickname,
  callType: info.video ? context.l10n.videoCall : context.l10n.voiceCall,
  video: info.video,
  onAccept: _onAccept,
  onDecline: _onReject,
);
```

## Web Examples

```html
<a class="ui-button ui-button-primary" href="downloads.html">Download Hestia</a>
<a class="ui-button ui-button-outline" href="privacy.html">Privacy</a>
```

```html
<label class="ui-field">
  <span>Search</span>
  <input class="ui-search" type="search" placeholder="Find a username">
</label>
```

```html
<article class="ui-card ui-feature-card">
  <span class="ui-feature-icon">E2E</span>
  <h3 class="ui-card-title">Encrypted by default</h3>
  <p class="ui-card-text">Messages stay private between trusted devices.</p>
</article>
```

```html
<article class="ui-chat-bubble is-me">
  <div class="ui-reply-block">
    <p class="ui-reply-author">Alex</p>
    <p class="ui-reply-text">Original message preview</p>
  </div>
  <p class="ui-chat-text">Got it.</p>
  <p class="ui-chat-meta">12:40</p>
</article>
```

```html
<article class="ui-card ui-contact-request">
  <span class="ui-avatar">A</span>
  <div>
    <h3 class="ui-card-title">Alex</h3>
    <p class="ui-card-text">Wants to add you</p>
  </div>
  <div class="ui-contact-actions">
    <button class="ui-button ui-button-outline">Decline</button>
    <button class="ui-button ui-button-primary">Accept</button>
  </div>
</article>
```

## Usage Notes

- Prefer UI Kit components for new screens and landing sections.
- Keep screen-specific behavior in screens/services; keep reusable layout and visual rules in the kit.
- Use localized labels in Flutter. UI Kit widgets expose labels where text appears inside reusable actions.
