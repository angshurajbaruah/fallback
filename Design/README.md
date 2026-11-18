# Design/

Everything Claude Code needs to build Fallback's UI as approved on 16 Nov 2026. Put this folder in the repo root, next to PRD.md and CLAUDE.md.

| Path | What it is |
|---|---|
| `BRAND.md` | Rules: logo, colour, type, component specs, behaviour. Read this first |
| `tokens.json` | Exact colour (dark and light), type, spacing and radius tokens |
| `COPY.md` | Final UI wording for warning cards and the popover |
| `screens/` | One PNG per artboard. The README there maps each file to its PRD screen |
| `assets/logo/` | The Folio f mark as SVG and 1024 px PNG: colour on dark, colour on light, one-colour lavender, one-colour black |
| `assets/menu-bar/` | Menu-bar template icon (PDF, SVG, @1x and @2x PNG) |
| `assets/app-icon/` | `AppIcon.appiconset` for Xcode, plus 1024 px sources (dark and light, full-bleed and on Apple's grid) |

Order of authority: PRD.md decides behaviour, BRAND.md and tokens.json decide styling, COPY.md and the screen images decide wording.

Still to design (owner): light mode for the screens other than the Ledger, the DMG background, the one-page website and the GitHub social preview. Don't invent these. Ask.
