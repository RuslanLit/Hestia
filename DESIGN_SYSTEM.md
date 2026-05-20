# Hestia Design System

Hestia uses a quiet privacy-first visual language: soft neutrals, restrained green brand color, 8px controls, readable type, and matching light/dark tokens for Flutter and the landing site.

## Illustration Direction

Hestia illustrations should feel warm, calm, and human. Prefer semi-flat scenes with rounded forms, minimal detail, and people communicating in relaxed home-like environments.

Primary reference:

- see `ILLUSTRATION_SYSTEM.md`

Recommended use:

- landing hero
- onboarding
- empty states

Avoid mixing multiple illustration families in one page or flow.

## Colors

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| Primary | `#246B4F` | `#75C69C` | Brand color, primary actions |
| Primary hover | `#1D5A42` | `#91D5AF` | Hover state |
| Primary active | `#174A38` | `#B9E4C9` | Pressed state, strong accent text |
| Primary soft | `#DCECE3` | `#203528` | Subtle accent backgrounds |
| Background | `#F7F8F5` | `#101410` | App/page background |
| Surface | `#FFFFFF` | `#151B16` | Cards, dialogs, inputs |
| Surface strong | `#EFF3EC` | `#1B221D` | Section bands, filled inputs |
| Border | `#DDE5DC` | `#2D382F` | Dividers and outlines |
| Text primary | `#121512` | `#F4F6F0` | Main text |
| Text secondary | `#5D675E` | `#AAB5AA` | Muted text |
| Success | `#2E7D57` | `#2E7D57` | Positive state |
| Warning | `#B7791F` | `#B7791F` | Caution state |
| Error | `#BA1A1A` | `#BA1A1A` | Error/destructive state |
| Info | `#3267A8` | `#3267A8` | Informational state |

## Typography

| Token | Web | Flutter | Line height | Weight |
| --- | --- | --- | --- | --- |
| Font family | `Inter`, system UI fallback | `Inter`, platform fallbacks | - | - |
| H1 | `clamp(4.25rem, 13vw, 9.75rem)` | `40` | `1.08` | `800` |
| H2 | `clamp(2.3rem, 6vw, 5rem)` | `32` | `1.12` | `800` |
| H3 | `1.2rem` | `22` | `1.2` | `700` |
| Body | `1rem` | `16` | `1.5` | `400` |
| Small | `0.9rem` | `14` | `1.45` | `400` |

## Spacing

| Token | Value |
| --- | --- |
| `space-1` / `xs` | `4` |
| `space-2` / `sm` | `8` |
| `space-3` / `md` | `12` |
| `space-4` / `lg` | `16` |
| `space-6` / `xl` | `24` |
| `space-8` / `xxl` | `32` |
| `space-12` / `xxxl` | `48` |
| `space-16` / `huge` | `64` |

## Token Files

| Platform | File |
| --- | --- |
| Flutter | `lib/theme/theme.dart` |
| Landing site | `Landing_Hestia/CSS/variables.css` |
