# Fallback UI copy (from the approved designs)

This file replaces the placeholder copy that was in PRD section 6.4. `{braces}` are filled in at runtime. Bold in the designs is shown as **bold** here, and file and destination names are always bold in cards.

## Warning cards (S4)

Every card has the header "Fallback · now" plus a close button. The mute line is a quiet text link under the buttons.

| Rule | Severity | Title | Body | Primary | Secondary | Mute link |
|---|---|---|---|---|---|---|
| W1 Older version | Warning | Older version | **{file}** is older than **{newer}**, which you edited {when}. | Show newer file | Send anyway | Don't warn for this document |
| W2 Already sent | Info | Already sent | You sent this exact file to **{destination}** on {date}. | Show previous send | Send anyway | Don't warn for this destination |
| W3 Changed since last send | Info | Heads up | **{destination}** has an earlier version ({oldfile}, {date}). | Show what they have | Send anyway | Don't warn for this document |
| W4 Name mismatch | Warning | Check the recipient | This file mentions **{token}**, but you're sending it to **{destination}**. | Show sends to {token} | Send anyway | Don't warn for this document |
| W5 Stale export | Warning | Out-of-date export | **{source}** was edited after this PDF was made. | Reveal source document | Send anyway | Don't warn for this document |
| Softer check | Info | Another version exists | There's another version of this document (**{other}**, edited {when}). Check you've picked the right one. | Show other version | It's the right one | Don't warn for this document |
| First detection | Info (check icon) | Got it | Fallback saw you pick **{file}** on {site}. That's all it takes. | Open Ledger | (none) | (none) |
| Destination unknown | Neutral | Recorded, destination unknown | Recorded **{file}**. Couldn't tell where it was going, so add a label. | Add a label | Not a send | (none) |

The destination-unknown card has a focused text field labelled "Label this send" with the placeholder "e.g. Acme finance".

W4 for a company Fallback hasn't seen yet (PRD 16.4 P-2) uses the same title and body, with the primary **Show in Finder** (reveals the picked file) and the mute link **Not a company name**.

When more than one rule fires (FR-24), the mute row shows "{n} more check(s) ›" on the right.

Version strip labels: W1 shows "{date} · picking now" → "{date} · edited {when}". W3 shows "{date} · {destination} has" → "{date} · sending now". Each {date} is that file's own last-edited date ("today", "yesterday", "5 Nov"). In the W1 body, {newer} is the newer file's name (e.g. resume_v5.pdf). Cards never show family version numbers (v1, v2…), since they can contradict the number in a file name; the Ledger and the document timeline keep them, where the whole family is on screen. W5 shows "PDF · made {date}" → "{TYPE} · edited {when}".

## Menu-bar popover (S1)

- Search placeholder: "Search what you sent" (hint ⌥⌘F)
- Status line: "Watching {n} folders · {count} sends", with "{n} caught" on the right
- Section label: "Recent"
- Row subtitle: "{destination} · {app} · {time}"
- Footer: "Open Ledger" ⌘L, plus Pause and Settings icon buttons
- **Empty (first run):** title "Nothing sent yet" (Sora). Body: "Attach a file anywhere, in Chrome, Mail, Slack or WhatsApp, and it shows up here." Button: "Try it on a test page"
- **Search results:** a destination summary row first, "{n} sends · last {when} · has {versions}", then files. Then a section "Also matching" for files that were downloaded but not sent ("Downloaded · not sent")
- **No results:** "No sends match “{query}”". Suggestion: "Did you mean {match}? {n} sends." Footnote: "Search runs on this Mac only. Nothing leaves it."
- **Paused:** "Paused until {time}" / "Sends made now won't be recorded." Button: "Resume"
- **Permission problem:** "Fallback can't see file pickers" / "Accessibility was turned off. Turn it back on to keep your trail complete." Buttons: "Open System Settings", "Why?". The list below is labelled "Last recorded"

## Everything else

For the Ledger, document detail, onboarding, settings, stats and dialogs, take the copy from the screen images in `screens/`. Where an image and the PRD disagree on wording, the image wins. Where they disagree on behaviour, the PRD wins.
