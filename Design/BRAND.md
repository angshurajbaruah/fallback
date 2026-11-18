# Fallback brand and UI rules

Confirmed 16 Nov 2026. This file and `tokens.json` are the source of truth for how Fallback looks. If a screen image in `screens/` disagrees with a number here, this file wins.

## The feel

Fallback should look like an Apple or Google first-party utility, not another SaaS app. In practice that means a deep black ground, one signal colour used sparingly, flat exact shapes and system-native controls. It feels calm, quiet, precise and trustworthy. It never looks like security software.

Mood words: Quiet · Precise · Watchful · Unhurried · Assured · Lucid

## Logo: 1D "Folio f"

A lowercase f built from three sheets of one document family. The stem sits in front. The arm and crossbar tuck behind it, cut apart by one even gap. It's a monogram and a version stack at once.

- 24-unit grid, three rounded sheets, 1.8-unit gap. No gradients, outlines, 3D or rotation.
- **On black:** arm Grey `#7C7C7C`, crossbar Lavender Blush `#EEE5E9`, stem Frosted Blue `#92DCE5`.
- **On Lavender Blush:** arm Frosted Blue, crossbar Grey, stem Black.
- **One colour:** Lavender Blush on black, Black on light.
- **Lockup:** mark to the left of the lowercase "fallback" wordmark in Sora Medium, tracked +14%. Mark height is about 1.2× the wordmark's cap height, with a gap of about half the mark's width.
- **Clear space:** at least the stem's width on every side.
- Never put Burnt Tangerine in the mark.

Files: `assets/logo/`.

## Menu-bar icon

- `assets/menu-bar/MenuBarIconTemplate.pdf` (or the @1x/@2x PNGs). It's a template image: black with transparency, and macOS tints it. Set `isTemplate = true`.
- 16 pt glyph in a 22 pt slot.
- **Paused:** the icon dims to 45% opacity.
- **Permission problem (FR-31):** a 7 pt Burnt Tangerine dot at the top right, with a 1.5 pt dark ring.

## App icon

- A black squircle (corner radius 22.4%) with one Frosted Blue bloom rising from the bottom. The full-colour mark is 54% of the tile.
- `assets/app-icon/AppIcon.appiconset` is ready to drop into the Xcode asset catalogue. It's drawn on Apple's macOS icon grid (824 px tile inside a 1024 px canvas).
- Full-bleed 1024 sources and a Lavender Blush light version are also in `assets/app-icon/`. Use the light one for print or light marketing only. The app ships the dark icon.

## Colour

| Token | Dark (default) | Light | Use |
|---|---|---|---|
| bg | #000000 | #EEE5E9 | Window and page background |
| surface | #0E0E10 | #FFFFFF | Cards, panels |
| surface-2 | #18181B | #F6F1F3 | Raised rows, notification cards |
| text | #EEE5E9 | #000000 | Primary text |
| text-muted | #7C7C7C | #565456 | Secondary text |
| primary | #92DCE5 | #000000 | Selection, links, the lit sheet, info |
| warning | #D64933 | #B83A26 | Warnings only |

The rules:

- Black first. Frosted Blue is the only colour that glows.
- Burnt Tangerine is for alert UI only: warning cards, the warning pip, the bad version chip and the permission dot.
- Severity colours: a **warning** uses the Tangerine icon tile (tint at 15%, text `#EF7A63`). **Info** uses the Frosted Blue tile (tint at 13%). **Neutral** uses Lavender Blush at 8%.
- Hairlines are Lavender Blush at 8% (`line`) or 13% (`line2`).

## Type

- **UI:** SF Pro, the system font. Never bundle another UI font.
- **Brand:** Sora Medium, used only for the wordmark, onboarding headlines and empty-state titles. Bundle Sora (SIL Open Font Licence) in the app.
- **Ledger details:** SF Mono 11.5–12 pt for timestamps, fingerprints and version chips.
- **App scale:** window titles 15 pt semibold. Body 13 pt. Row titles 12.5 pt medium. Captions 11–11.5 pt. Section labels 10.5 pt semibold, uppercase, tracked +12%.

## Components (dark values)

| Component | Spec |
|---|---|
| Menu-bar popover (S1) | 368 pt wide, radius 14. Background `rgba(30,30,34,.92)` with vibrancy and a 1 pt inner border at Lavender Blush 8.5%. Search field 32 pt tall, radius 9, focused on open, ⌥⌘F hint. Rows are 48 pt tall, radius 9. The footer has "Open Ledger ⌘L", Pause and Settings |
| Warning card (S4) | 372 pt wide, radius 18, padding 14/16/16, vibrancy. Header: mini mark, "Fallback · now" and a close button. Severity tile 30 pt, radius 9. Title 13 pt semibold, body 12 pt. Buttons are 26 pt tall: the primary action is filled Lavender Blush with black text, the secondary is grey. The mute action is a quiet 11 pt text link, not a button. A 2 pt countdown hairline runs along the bottom |
| Version strip (in cards) | Pills 30 pt tall, radius 8. The bad version gets a Tangerine 55% outline. The good one gets a Frosted Blue tint and outline |
| Buttons | 28 pt tall, radius 7 (app). Primary = Lavender Blush fill with black text. Frost = Frosted Blue fill with black text, used for Resume and toggles. Destructive = Tangerine fill with white text. Ghost = text only. Pills (radius 999) appear only in onboarding and on the website |
| Toggles | 38×22 pt. On = Frosted Blue |
| Selected row | Frosted Blue at 14% fill plus a 1 pt Frosted Blue 22% inner border |
| Version chip | 20 pt tall, radius 6. Frosted Blue 13% tint with Frosted Blue text |
| Confidence dot (FR-6) | 8 pt. High = solid Frosted Blue. Medium = solid Grey. Low = Grey 1.5 pt ring only |
| Focus ring | 3.5 pt Frosted Blue at 32%, plus a 1 pt inner border at 70% |
| Ledger window | Sidebar 236 pt. Toolbar 54 pt. Inspector 328 pt. Table rows 44 pt, radius 8 |
| Onboarding window | 920×680 pt, one step per screen, with a progress indicator |
| Settings window | 880 pt wide, six tabs |

## Behaviour rules from the designs

- The warning card slides in at the top right, under the menu bar, and never covers the centre of the screen. It never takes keyboard focus. It stays for 10 seconds, the hairline counts down, and hovering pauses it. It has at most three actions: the fix first, then Send anyway, then the mute link.
- The popover search is focused when the popover opens.
- Respect Reduce Motion: no slide, just a fade.
- **Light mode:** only the Ledger and a warning card are designed (`screens/24-Light-Ledger.png`). For other screens, swap the tokens using the Light column above and keep the same layout. Flag anything that looks wrong rather than inventing new styling.

## Don'ts

No padlocks, shields, clouds, paper planes, checkmarks as a brand device, parachutes, folders or dog-eared documents. No purple and no multi-colour gradients. One bloom per composition at most, always Frosted Blue.
