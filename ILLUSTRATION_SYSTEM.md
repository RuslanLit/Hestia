# Hestia Illustration System

Hestia illustrations should make the product feel like a private, warm place for close conversations. The goal is not to sell "security software". The goal is to show calm human connection.

## 1. Style Choice

Recommended style for Hestia:

- semi-flat illustration
- soft rounded geometry
- minimal detail
- human scenes with relaxed posture
- warm, quiet palette
- clean background with lots of breathing room

Why this fits Hestia:

- warmer than strict flat corporate graphics
- more human than icon-only layouts
- easier to keep consistent across landing, onboarding, and empty states
- works well in SVG and can be recolored for light/dark themes

Visual characteristics:

- rounded faces, hands, phones, furniture
- simple folds and shadows
- no aggressive contrast
- no glossy realism
- no cyber, matrix, neon, hacker motifs

## 2. Character Direction

Preferred subjects:

- two friends chatting
- siblings or family members sharing updates
- a parent and child checking messages
- a small trusted circle
- a person joining a call from home

Character rules:

- neutral clothing
- diverse but calm representation
- expressive enough to feel alive, not cartoonish
- no exaggerated comedy poses
- no business-team stock-photo energy

## 3. Recommended Sources

### Free Sources

1. unDraw
- Pros: large library, easy SVG workflow, simple customization.
- Cons: can feel generic and slightly startup-like if used raw.
- Fit for Hestia: good for secondary sections and empty states after recoloring.

2. Storyset by Freepik
- Pros: broad coverage, flexible themes, easy to find relationship and communication scenes.
- Cons: styles vary; easy to lose consistency if mixed carelessly.
- Fit for Hestia: good if one single style family is chosen and reused consistently.

3. Humaaans
- Pros: modular people system, friendly shapes, easy to build recurring Hestia-like scenes.
- Cons: requires assembly and art direction; can feel unfinished if composition is weak.
- Fit for Hestia: very strong option for a custom, reusable character system.

4. Open Doodles
- Pros: warm, playful, human, memorable.
- Cons: doodle line style is more casual and can feel too whimsical in product flows.
- Fit for Hestia: suitable for selected empty states, less suitable as the primary site style.

### Paid Sources

1. Blush
- Pros: strong quality, customizable characters, reliable family/friend scenes, easy consistency.
- Cons: paid workflow; can still feel template-driven if not art-directed.
- Fit for Hestia: best paid option for fast consistency with human warmth.

2. Icons8 Ouch!
- Pros: polished sets, good emotional tone, wide range of scenes.
- Cons: some sets feel product-marketing heavy; needs careful style selection.
- Fit for Hestia: good for landing hero and polished editorial sections if one set is picked and reused.

## 4. Source Recommendation for Hestia

Recommended default stack:

1. Primary source: Humaaans or Blush
2. Secondary support source: unDraw
3. Avoid mixing more than one major illustration family on the same page

Best practical approach:

- Use one main character style for hero, onboarding, and empty states.
- Use icons and simple graphic motifs for small feature blocks.
- Do not combine Humaaans characters with Open Doodles or a separate Freepik style in the same viewport.

## 5. AI Illustration Prompts

Use AI only if we need custom scenes that stock libraries cannot cover.

### Base Prompt

`semi-flat illustration of two close friends chatting on smartphones at home, warm cream and soft blue palette, rounded shapes, gentle shadows, minimal detail, calm friendly mood, clean background, modern product illustration, svg-friendly composition`

### Hero Prompt

`semi-flat illustration of a small trusted circle staying in touch through a private messenger, warm home atmosphere, soft cream background, muted blue and amber accents, rounded human shapes, minimal background clutter, calm emotional tone, editorial tech illustration, no realism, no cyber motifs`

### Empty State Prompt: No Contacts

`semi-flat illustration of one person inviting a friend to a private chat space, soft warm palette, rounded forms, minimal detail, friendly and calm mood, clean negative space, no background clutter, vector illustration style`

### Empty State Prompt: No Messages

`semi-flat illustration of a quiet chat moment before a conversation begins, one person holding a phone and smiling softly, warm cream background, gentle blue and amber accents, minimal vector style, rounded shapes, no realism`

### Onboarding Prompt: Calls

`semi-flat illustration of two people joining a private video call from cozy home spaces, warm colors, friendly faces, minimal detail, clean composition, soft rounded forms, modern vector product illustration`

### Prompt Constraints

Always include:

- semi-flat or flat illustration
- rounded shapes
- warm palette
- clean background
- minimal detail
- no realism
- no neon
- no cyber security visuals
- no office boardroom scenes

## 6. Styling Rules

After sourcing or generating illustrations, normalize them before use.

### Palette Rules

Map illustration colors to Hestia tokens as closely as possible:

- cream / page background -> `#FAF7F2`
- warm surface -> `#F4ECE3`
- primary blue -> `#3B82C4`
- soft blue -> `#D8ECFF`
- amber accent -> `#E2A146`
- green support -> `#4CA97A`
- dark text/outline -> `#1F2933`

Dark theme adaptation:

- keep illustration background transparent where possible
- reduce bright white fills
- shift shadows toward `#222832` / `#2B3340`
- keep skin/clothing colors slightly muted, not glowing

### Line and Shape Rules

- rounded corners only
- stroke width should be consistent per family
- avoid ultra-thin strokes
- avoid highly textured brushes
- prefer large readable silhouettes over tiny internal detail

### Composition Rules

- one main emotional idea per illustration
- no crowded scenes
- leave empty area for copy and buttons
- keep focal point centered or offset cleanly for responsive crops

## 7. Usage Rules

### Landing

Hero:

- use one main human communication illustration
- scene should show closeness, not productivity
- place beside or behind hero copy only if the composition stays readable

Feature sections:

- use small supporting illustrations only for major features
- for simple feature grids, icons are enough

Privacy / comparison / FAQ / server setup:

- do not add a new illustration style to every page
- use either one recurring hero illustration family or small repeated section artworks

Downloads:

- keep it practical
- one lightweight illustration near page intro is enough

### App

Empty states:

- no contacts
- no chats yet
- no requests
- no search results

Onboarding:

- first contact
- first message
- private calls

Do not add large decorative illustrations inside dense chat workflows unless they support an empty state or onboarding step.

## 8. Placement Recommendations

Recommended first batch:

1. Landing hero: trusted circle / family-and-friends communication
2. Landing privacy section: calm home/private-space illustration
3. App empty state: no contacts
4. App empty state: no chats
5. App onboarding: private calls

## 9. File Format and Optimization

Preferred format:

- SVG for hero, empty states, onboarding
- PNG/WebP only if raster detail is necessary

Rules:

- optimize SVG output
- strip unnecessary metadata
- keep transparent background where possible
- export dark-safe versions only when recoloring via CSS/theme is not enough

Web performance:

- lazy load non-critical illustrations
- do not block hero text rendering on oversized assets

## 10. Project Structure

Flutter app:

`assets/illustrations/`

Suggested structure:

- `assets/illustrations/hero/`
- `assets/illustrations/empty_states/`
- `assets/illustrations/onboarding/`
- `assets/illustrations/shared/`

Landing site:

`Landing_Hestia/assets/illustrations/`

Suggested structure:

- `Landing_Hestia/assets/illustrations/hero/`
- `Landing_Hestia/assets/illustrations/sections/`
- `Landing_Hestia/assets/illustrations/empty_states/`
- `Landing_Hestia/assets/illustrations/shared/`

Naming:

- `hero-private-circle-light.svg`
- `hero-private-circle-dark.svg`
- `empty-no-contacts.svg`
- `empty-no-messages.svg`
- `onboarding-private-calls.svg`

## 11. Do / Don't

Do:

- keep the emotional tone quiet and warm
- show people, not abstractions only
- reuse one style family
- let illustrations support copy, not fight it

Don't:

- mix doodle, realism, 3D, and flat on the same page
- use hacker, shield, lock-wallpaper, terminal, or military motifs as primary artwork
- overload every section with a separate scene
- use loud saturated gradients

## 12. Short Recommendation

If Hestia wants the fastest strong result:

1. pick Humaaans or Blush as the main style
2. build 4-5 recurring scenes
3. recolor them to Hestia tokens
4. use them in landing hero, onboarding, and empty states

That will make Hestia feel noticeably warmer, more human, and more memorable without redesigning the product.
