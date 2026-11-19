# Fallback PRD: macOS app v1

Nov 16, 2026 · @Anshu

## 1. Document info and summary

|  |  |
| --- | --- |
| Product | Fallback |
| Platform | macOS 14 (Sonoma) and later, Apple silicon and Intel |
| Version covered | v1.0 (first public release), plus the v1.1 items marked as such |
| Status | Draft for build |
| Owner | Anshu (product, design decisions, testing, launch) |
| Engineering | Claude Code, directed by the owner |
| Licence | MIT, public on GitHub from day one |

**Fallback in one paragraph.** Fallback is a free, open-source Mac app that remembers every file you send and where it went. It sits quietly in the menu bar. When you pick a file to attach or upload in any app (Chrome, Safari, WhatsApp, Slack, Mail), Fallback notices which file you chose and where you're sending it. If it's an older version, already sent there, or obviously meant for someone else, it warns you within a second. Later, you can ask "what exactly did I send to Razorpay?" and get the exact file back. Everything stays on your Mac. Nothing is uploaded, ever.

**The one-line pitch:** *Never send the wrong file again, and always know what you sent.*

**How to read this doc.** Sections 1-5 are the why and what. Sections 6-8 are the product behaviour. Sections 9-12 are how it's built and the quality bar. Section 13 is the step-by-step build plan with prompts to paste into Claude Code. Every requirement has an ID (like FR-12) so you can point Claude Code at it.

## 2. Problem, evidence and why now

### The problem

People send files all day: resumes to job portals, decks to investors, proposals to clients, invoices to customers, documents on WhatsApp. Each of those files has versions: resume\_v3, resume\_v5\_final, Proposal\_Acme\_revised. Three things keep going wrong.

1. **The wrong version goes out.** You attach resume\_v3 when v5 has the new numbers. You find out when the interviewer asks about a job you left off.
2. **The wrong file goes to the wrong person.** The proposal written for Acme lands in Globex's inbox, with Acme's pricing in it.
3. **Nobody can answer "what did I send?"** A recruiter calls three weeks later. Which resume did they get? Which deck did the investor see? Email search covers only email. Uploads to Workday, Naukri, LinkedIn, WhatsApp and Slack leave no trail you can search.

### Evidence

- One document-management vendor cites a study claiming 60% of professionals sent the wrong version of a document to a client or colleague in the past year. It's a vendor number, so treat it as directional, but almost everyone recognises the experience.
- Existing tools solve slices of this for companies: attachment tracking inside Salesforce (Cirrus Insight), document management for law firms, and a Zendesk add-on that makes support agents review attachments before sending. Nothing does it for an individual, across every app they use.
- **Validation still needed (owner task):** 15 short interviews before launch, covering job seekers, freelancers, founders and salespeople. One question: "Tell me about the last time you sent the wrong file, or couldn't remember what you'd sent." If fewer than half have a story, revisit the positioning.

### Why now

- People apply to more jobs and send more versions than ever. Tailoring a resume per application, often with AI, means many near-identical files.
- AI makes producing new versions nearly free, and keeping track of them harder.
- Macs now give apps clean, user-granted permissions to observe other apps (Accessibility). That makes a cross-app, local-only tool possible without a browser extension or any server.

## 3. Users, personas and jobs to be done

### Primary persona: the active job seeker ("Arjun")

- 26-35, working professional in Bengaluru, Mumbai or Delhi, on a Mac.
- Applying to 20-60 roles a quarter through Workday, Greenhouse, Lever, Naukri, LinkedIn and email.
- Keeps 5-15 resume versions plus cover letters, tailored per role.
- **Pain:** "I don't know which resume Razorpay has." "I sent the version with a typo."
- **Job to be done:** when a company replies, instantly see exactly what I sent them, and never send an outdated resume.

### Secondary persona: the founder or consultant ("Meera")

- Sends decks, proposals and invoices to investors and clients over email, WhatsApp and Slack.
- **Pain:** "Did that investor get the deck with the old traction numbers?" "I almost sent Client A's pricing to Client B."
- **Job to be done:** catch the wrong-recipient mistake before it happens, and keep a record of which version each person has.

### Tertiary persona: the salesperson or recruiter ("Rohit")

- Sends one-pagers, price lists and contracts to many contacts daily.
- **Job to be done:** know which price list each prospect has. This persona is the bridge to a future paid team version.

### Anti-persona (not for v1)

- Teams needing shared document control and approvals. They should use a document-management system.
- People who mostly send files from their phone. Fallback v1 is Mac-only.

### Jobs to be done, ranked

1. **Warn me** before the wrong version or wrong file goes out. *(the moment of value)*
2. **Tell me** what I sent to a company or person, and when. *(the habit)*
3. **Show me** the version history of a document and where each version went. *(the delight)*

## 4. Goals, non-goals and success metrics

### Goals for v1

1. Detect when a user picks a file to send in the most common Mac apps and websites, with high accuracy.
2. Keep a searchable, private, on-device ledger of every send.
3. Track versions of files in folders the user chooses, and group them into document "families".
4. Warn in under a second, in a way that feels helpful, never naggy.
5. Be trustworthy enough that a privacy-conscious person installs it: open-source, local-only, clear permissions.

### Non-goals for v1 (deliberately out)

- Windows, Linux, iPhone or Android.
- Blocking or cancelling an upload. Fallback warns. It doesn't interfere.
- Detecting files dragged straight from Finder into a browser (moved to v1.2, see roadmap).
- Reading the content of your emails or messages.
- Cloud sync, accounts, sign-in, or any server.
- AI or LLM features. Nothing in v1 needs them, and their absence is part of the privacy story.
- Files attached from Google Drive or Dropbox pickers inside websites, which aren't local files.
- Team or shared ledgers (future paid tier).

### Success metrics

**North-star metric:** *saves per active user per month.* A save is when a user sees a warning and then picks a different file within two minutes. That's the moment Fallback earned its place.

| Metric | Definition | 90-day target |
| --- | --- | --- |
| Downloads | DMG downloads from the site and GitHub releases | 3,000 |
| GitHub stars | Public repo | 1,000 |
| Activation | Granted Accessibility and recorded at least one send within 24 hours of install | 60% of installs |
| Detection accuracy | Picks correctly recorded, in owner's test matrix (section 14) | 95% or more in Chrome and Safari on the top 10 sites |
| Weekly active | Recorded at least one send in the week | 40% of activated users at day 30 |
| Saves | As defined above | 1 or more per active user per month |
| Warning annoyance | Share of warnings dismissed with "don't warn me about this again" | Under 15% |

**Measuring without telemetry.** v1 sends nothing home. So metrics come from download counts, GitHub, an optional in-app "Fallback saved me" button that opens a pre-filled GitHub discussion or tweet, and a local stats screen users can screenshot and share. An opt-in, anonymous weekly count can be considered for v1.1, never on by default.

## 5. Product principles

When a decision is unclear, these settle it, in this order.

1. **Private by architecture, not by promise.** No servers, no accounts, no network calls except an update check the user can switch off. File contents never leave the Mac. Fallback stores fingerprints and metadata, not copies of files.
2. **Silent until it matters.** No pop-ups for normal sends. A warning appears only when something is likely wrong. If users start ignoring warnings, Fallback has failed, so precision beats recall.
3. **Warn, never block.** The user is always in control. Every warning has "Send anyway" and "Don't warn me about this again".
4. **One glance, one action.** Each warning says what's wrong in one line and offers the fix in one click.
5. **Works with the apps people already use.** No new workflow, no "send through Fallback". It watches the moment people already go through.
6. **Honest about limits.** When Fallback isn't sure (couldn't read the site, for example), it records the send with a confidence level and says so, rather than guessing.
7. **Small and fast.** Under 1% CPU when idle. People uninstall menu-bar apps that make the fan spin.

## 6. User experience: core flows and screens

### 6.1 Core flows

**Flow A: first run (target: under 2 minutes)**

1. **Welcome.** One sentence about what Fallback does, plus the privacy promise: "Everything stays on this Mac. Fallback never uploads anything."
2. **Accessibility permission.** Explains in plain words why it's needed ("so Fallback can see which file you pick when you attach something"). The button opens System Settings at the right pane. Fallback checks every second and moves on as soon as access is granted, with no restart.
3. **Browser permission.** Explains that macOS will ask "Fallback wants to control Google Chrome". This lets Fallback read the address of the page you're uploading to, nothing else. A "Test now" button triggers the prompt for each installed browser.
4. **Folders to track.** Pre-ticked suggestions: Documents, Desktop, Downloads. You can add any other folder, such as Resumes or Decks.
5. **Indexing.** A progress bar while Fallback fingerprints existing files in the background. You can close the window and it carries on.
6. **Try it.** "Open any website with an upload button and pick a file." When it detects the pick, a one-time toast confirms: "Got it. Fallback saw you pick resume\_v5.pdf on careers.razorpay.com." This is the aha moment, so it must work first time.

**Flow B: a normal send (90%+ of the time)**

You click Attach, pick a file, click Open. Fallback records the send silently. The menu-bar icon gives a subtle tick animation (can be switched off). Nothing else happens.

**Flow C: a warning**

Same as Flow B, but a rule fires (section 8). Within a second, a small card slides in at the top-right of the screen. It doesn't steal focus, so typing isn't interrupted.

> **Older version** resume\_v3.pdf is older than resume\_v5.pdf (edited yesterday). \[Show newer file\] \[Send anyway\] \[Don't warn for this document\]

The card stays 10 seconds, with a hairline counting down, and pauses while hovered. "Show newer file" reveals it in Finder, already selected, so you can drag it in or re-attach it.

**Flow D: "what did I send them?"**

Click the menu-bar icon, type "razorpay", and see every send to Razorpay: file, version, date, app, page. Click one for details, then Quick Look, Reveal in Finder, or open the page it was sent on.

**Flow E: a document's history**

Open the Ledger window, then Documents, then "Resume". A timeline shows each version (v3, v4, v5) with when it was saved and every place it was sent.

**Flow F: fixing Fallback's mistakes**

For any send, you can: rename the destination ("wd3.myworkdayjobs.com" becomes "Razorpay"), delete it, or mark it "not a send". For documents, you can merge two families or split one off.

### 6.2 Screens

| ID | Screen | What's on it |
| --- | --- | --- |
| S1 | Menu-bar popover | Search box (focused on open), last 10 sends, status line ("Watching" or "Paused until 6 pm"), buttons for Ledger and Settings |
| S2 | Ledger window | Sidebar: All sends, By destination, By document, Warnings. Main area: sortable table (file, version, destination, app, date). Right panel: details of the selected send |
| S3 | Document detail | Version timeline. Each version shows file name, saved date, size, fingerprint (short), and a list of where it was sent |
| S4 | Warning card | Title, one line, two buttons plus a quiet mute link. Severity colour: Burnt Tangerine for warnings, Frosted Blue for information |
| S5 | Onboarding | Six steps from Flow A, with a progress indicator |
| S6 | Settings | Tabs: General, Folders, Apps, Warnings, Privacy, About (detail in FR-28 to FR-35) |
| S7 | Your stats | "Fallback has recorded 214 sends and caught 9 mistakes", with a Share button that makes an image |

### 6.3 Design deliverables (owner-led)

The owner designs the brand and every screen. Designs get added to this section only after the owner approves them, and **no UI gets built until then.** This list says what needs designing.

**Screens and states: 7 screens, about 40 states**

| Screen | States and variants to design |
| --- | --- |
| S1 Menu-bar popover | Normal list, empty (first run), search results, no results, paused, permission problem |
| S2 Ledger window | All sends, By destination, By document, Warnings, send detail panel, empty state |
| S3 Document detail | Version timeline, "Group these files?" suggestion, merge or split dialog |
| S4 Warning cards | W1 to W5, "Another version exists", first-detection "Got it", "Couldn't tell where this went" |
| S5 Onboarding | Welcome, Accessibility, browser permission, folders, indexing, try it |
| S6 Settings | General, Folders, Apps, Warnings, Privacy, About |
| S7 Stats | Stats screen, shareable image |
| Small dialogs | Edit destination label, delete-all confirmation, update available |

**Brand and assets**

- Logo and wordmark
- App icon (1024 px source, macOS icon style)
- Menu-bar icon (monochrome template, so macOS can tint it for light and dark menu bars)
- Colour palette for light and dark mode, and type choices
- DMG installer background
- Website (one page, section 15.2)
- GitHub social preview image (1280 x 640) and README demo GIF

**Constraints the designs must respect** (from the requirements, not style choices)

- Works in light and dark mode, and with Reduce Motion on.
- Warning cards never take keyboard focus, never cover the centre of the screen, and have at most three buttons.
- Every control has a text label VoiceOver can read.

**Approved designs (16 Nov 2026).** The owner approved the brand and the screen designs; build UI from these two sources.

- **Brand identity:** [Fallback design system](https://claude.ai/artifact/UVknwwLTzPoCJgQnWFF53r). Logo 1D "Folio f" with the lowercase Sora wordmark; palette Black #000000, Lavender Blush #EEE5E9, Frosted Blue #92DCE5, Grey #7C7C7C, Burnt Tangerine #D64933 (warnings only, replaces the amber in S4 and 6.4); SF Pro for UI.
- **Screens:** [Fallback · macOS app UI](https://claude.ai/artifact/5pmE9iiRgHesi6FgwMsh7E), 25 artboards covering S1–S7 and their states, the small dialogs and a light-mode Ledger.
- **Still to design:** light mode for the remaining screens, the DMG background, the one-page website and the GitHub social preview.

**In the repo (what Claude Code reads).** The two links above are private to the owner, so Claude Code can't open them. Everything it needs is copied into a `Design/` folder in the repo root:

| Path | Contents |
| --- | --- |
| Design/BRAND.md | Logo, colour, type and component specs, behaviour rules. Read first |
| Design/tokens.json | Exact colour (dark and light), type, spacing and radius tokens |
| Design/COPY.md | Final wording for warning cards and the popover (replaces the old draft copy) |
| Design/screens/ | One 2x PNG per artboard, numbered 00 to 24, mapped to S1 to S7 in its README |
| Design/assets/ | Folio f mark (SVG, PNG), menu-bar template icon (PDF, PNG), AppIcon.appiconset for Xcode |

Order of authority: this PRD decides behaviour, BRAND.md and tokens.json decide styling, COPY.md and the screen images decide wording. If the designs change, re-export them into `Design/` before the next milestone.

### 6.4 UI copy (final, from the approved designs; full deck in Design/COPY.md)

| Moment | Title | Body | Actions |
| --- | --- | --- | --- |
| Older version (W1) | Older version | {file} is older than {newer}, which you edited {when}. | Show newer file · Send anyway · mute: Don't warn for this document |
| Already sent (W2) | Already sent | You sent this exact file to {destination} on {date}. | Show previous send · Send anyway · mute: Don't warn for this destination |
| Changed since last send (W3) | Heads up | {destination} has an earlier version ({oldfile}, {date}). | Show what they have · Send anyway · mute: Don't warn for this document |
| Name mismatch (W4) | Check the recipient | This file mentions {token}, but you're sending it to {destination}. | Show sends to {token} · Send anyway · mute: Don't warn for this document |
| Stale export (W5) | Out-of-date export | {source} was edited after this PDF was made. | Reveal source document · Send anyway · mute: Don't warn for this document |
| Order unclear (softer check) | Another version exists | There's another version of this document ({other}, edited {when}). Check you've picked the right one. | Show other version · It's the right one · mute: Don't warn for this document |
| First detection | Got it | Fallback saw you pick {file} on {site}. That's all it takes. | Open Ledger |
| Couldn't read the site | Recorded, destination unknown | Recorded {file}. Couldn't tell where it was going, so add a label. | Add a label · Not a send |
| Accessibility revoked (popover) | Fallback can't see file pickers | Accessibility was turned off. Turn it back on to keep your trail complete. | Open System Settings · Why? |
| Paused (popover) | Paused until {time} | Sends made now won't be recorded. | Resume |
| Nothing sent yet (popover) | Nothing sent yet | Attach a file anywhere, in Chrome, Mail, Slack or WhatsApp, and it shows up here. | Try it on a test page |

## 7. Functional requirements

Priority: **P0** = must ship in v1.0. **P1** = should ship in v1.0, can slip to v1.1. **P2** = v1.1 or later.

### 7.1 Detection

| ID | Requirement | Pri | Acceptance criteria |
| --- | --- | --- | --- |
| FR-1 | Detect when a file-open panel appears in a watched app | P0 | Detected in Chrome, Safari, Arc, Brave, Edge, Mail, Slack, WhatsApp desktop. No detection for Save panels |
| FR-2 | Capture the file or files the user selected when the panel closes with Open/Choose/Upload | P0 | Full path recorded for each file. Multiple selection gives one event per file. Cancel records nothing |
| FR-3 | Only watch "sending apps" from an editable list | P0 | Default list: browsers, Mail, Outlook, Slack, WhatsApp, Telegram, Teams, Discord, Zoom. Picking a file in Preview or Word is ignored |
| FR-4 | Capture context at the moment the panel opens: app name and bundle ID, window title, and for browsers the active tab's URL and title | P0 | Context belongs to the tab that opened the panel, even if the user switches tabs afterwards |
| FR-5 | Turn context into a readable destination label (rules in 9.5) | P0 | Workday, Greenhouse, Lever, LinkedIn, Naukri, Gmail resolve to a company or service name. Others fall back to the website's main domain |
| FR-6 | Mark each send with a confidence: High (file and URL known), Medium (file known, only window title), Low (file guessed) | P0 | Visible as a small dot in the Ledger |
| FR-7 | Firefox and other browsers without scripting support | P1 | Recorded with window title only, Medium confidence |
| FR-8 | Recipient name for Gmail, Mail and Outlook compose windows | P2 | Reads the To field. Moves to v1.1 |

### 7.2 Ledger

| ID | Requirement | Pri | Acceptance criteria |
| --- | --- | --- | --- |
| FR-9 | Store every send with file, fingerprint, destination, app, URL, title, time, confidence | P0 | Survives app restart and Mac restart. No data loss on crash |
| FR-10 | Search across file names, destinations, page titles and apps | P0 | Results as you type, under 100 ms for 10,000 sends |
| FR-11 | Views: All sends, By destination, By document, Warnings | P0 | Each sortable by date, newest first by default |
| FR-12 | Send detail with Quick Look, Reveal in Finder, Open page, Copy file | P0 | If the file has since moved, Fallback finds it by fingerprint in watched folders. If it's gone, it says so |
| FR-13 | Edit destination label (applies to future sends to the same place too, if the user chooses), delete a send, mark "not a send" | P0 | Label rules saved and reused |
| FR-14 | Export the ledger as CSV | P1 | All columns, UTF-8, opens cleanly in Excel and Numbers |

### 7.3 Files, versions and documents

| ID | Requirement | Pri | Acceptance criteria |
| --- | --- | --- | --- |
| FR-15 | Watch user-chosen folders for new, changed, renamed and deleted files | P0 | Changes reflected within 5 seconds |
| FR-16 | Fingerprint files (SHA-256 of contents) plus size and modified date | P0 | Files up to 500 MB. Larger files use size + date + first and last 1 MB |
| FR-17 | Follow a file across renames and moves inside watched folders | P0 | Renaming resume.pdf to resume\_old.pdf keeps its history |
| FR-18 | Group files into document families (algorithm in 8.3) | P0 | resume\_v3.pdf, Resume v5 FINAL.pdf and resume (1).pdf form one family |
| FR-19 | Files picked from outside watched folders are still recorded | P0 | Fingerprinted at the moment of sending and grouped by name |
| FR-20 | Manually merge families or move a file into another family | P1 | Takes effect immediately in warnings |
| FR-21 | Skip noise: hidden files, app bundles, node\_modules, .git, Library, caches, files under 1 KB | P0 | Configurable exclude list |
| FR-22 | File types indexed by default: pdf, doc, docx, pages, ppt, pptx, key, xls, xlsx, numbers, csv, txt, md, rtf, png, jpg, jpeg, heic, zip | P0 | User can add types |

### 7.4 Warnings

| ID | Requirement | Pri | Acceptance criteria |
| --- | --- | --- | --- |
| FR-23 | Evaluate warning rules (section 8) every time a send is recorded | P0 | Card shown within 1 second of the panel closing in 95% of cases |
| FR-24 | At most one card per pick. If several rules fire, show the most severe and list the rest under "More" | P0 |  |
| FR-25 | Card actions: primary fix, Send anyway, Don't warn for this document or destination | P0 | Choices remembered |
| FR-26 | Card never takes keyboard focus and never covers the centre of the screen | P0 | Typing in the browser isn't interrupted |
| FR-27 | Record what happened after each warning and detect a "save" (a different file from the same family picked within 2 minutes) | P0 | Saves counted in Stats |
| FR-37 | "Recorded, destination unknown": when the destination genuinely couldn't be resolved at all (a browser gave no page address, so only a window title is known; not merely Medium confidence), ask the user to label it. Neutral card, not a warning: no Tangerine. Shown in Strict and Balanced, Ledger-only in Quiet. Never takes precedence over a warning: if any warning fires for the same pick, the warning gets the card and this stays in the Ledger. Actions: Add a label (saved as a label rule, FR-13), Not a send | P1 | Asked at most once per unknown destination, ever (see 8.2). The label field takes typing only after the user clicks it (FR-26) |

### 7.5 App shell and settings

| ID | Requirement | Pri | Acceptance criteria |
| --- | --- | --- | --- |
| FR-28 | Menu-bar app with no Dock icon | P0 |  |
| FR-29 | Launch at login, on by default after onboarding | P0 | Uses Apple's login item service |
| FR-30 | Pause watching for 1 hour, until tomorrow, or until resumed | P0 | Status visible in the popover |
| FR-31 | Permission health check: if Accessibility or browser access is revoked, the icon shows a warning dot and the popover explains how to fix it | P0 |  |
| FR-32 | Settings tabs: General, Folders, Apps, Warnings (toggle each rule, sensitivity Strict/Balanced/Quiet), Privacy, About | P0 |  |
| FR-33 | Privacy tab: export data, delete all data (with confirmation), turn update checks off | P0 | Delete removes the database and caches completely |
| FR-34 | Automatic updates through Sparkle, with the user's consent | P1 | Signed updates only |
| FR-35 | Global shortcut to open search (default Option+Command+F, changeable) | P1 |  |
| FR-36 | Stats screen with a shareable image | P1 | Image contains counts only, no file names |

## 8. Warning engine

### 8.1 Rules

| Rule | Fires when | Severity | Default | Primary action |
| --- | --- | --- | --- | --- |
| **W1 Older version** | The picked file belongs to a family, and another file in that family with the **same extension** is a High-confidence newer version of it (8.3), with a clear order. If the order is unclear, the softer "Another version exists" check shows instead | Warning | On | Show newer file |
| **W2 Already sent** | The exact same fingerprint was sent to the same destination within the last 90 days | Info | On | Show previous send |
| **W3 Changed since last send** | A different version from the same family was sent to the same destination before | Info | On | Show what they have |
| **W4 Name mismatch** | The file name contains an organisation name that differs from the current destination (8.4) | Warning | On | Show sends to {token} |
| **W5 Stale export** | The picked file is a PDF, and a .docx, .pages, .key or .pptx with the same family stem was modified after the PDF | Warning | On | Reveal source document |

### 8.2 Rules about rules

- **Precedence:** W4, then W1, then W5, then W3, then W2. Only the top one shows as a card; the others appear under "More".
- **Sensitivity:**
  - *Strict* shows all rules.
  - *Balanced* (default) shows W1, W4 and W5 as cards, and W2 and W3 only in the Ledger.
  - *Quiet* shows only W4 and W1.
- **Muting:** "Don't warn for this document" mutes that family for every rule. "Don't warn for this destination" mutes that destination. Both can be undone in Settings.
- **Cool-down:** the same rule for the same family won't show twice within 10 minutes.
- **Label requests (FR-37):** Fallback asks for a destination label at most once per unknown destination, ever. Once a label rule is saved (FR-13), it never asks about that place again; if the user dismisses the card without labelling, it doesn't ask again either.
- **Precision target:** in the owner's own two-week trial, under 1 false-alarm card per day. If a rule misses that, it gets tightened before launch.

### 8.3 Grouping files into document families

A family is **the same document across its versions, whatever the files are called**. "final.pdf", "2.0.pdf" and "Document (3).pdf" can all be one family. Fallback combines four kinds of evidence, strongest first, and gives every link between two files a confidence.

| Layer | Signal | Example | Confidence |
| --- | --- | --- | --- |
| 1. Lineage | Same file identity after a rename or move. A duplicate or "Save As" (a new file appears with exactly the same fingerprint as an existing one). Downloads that macOS stamped with the same source (the "where from" address: the same email thread, Drive link or web page) | Three downloads of a deck from one Gmail thread | High |
| 2. Document metadata | Read on-device from inside the file: PDF title, author, creation date and internal document ID. Word, PowerPoint and Excel core properties (title, author, created) | final.pdf and 2.0.pdf both titled "Anshu Resume" and created on the same date | Medium. High when internal IDs match |
| 3. Content similarity | Text extracted on-device and turned into a compact similarity fingerprint (MinHash over word groups). Images get a perceptual fingerprint that survives resizing and re-saving | Untitled.pdf shares 88% of its text with resume\_v5.pdf | High at 75% or more of the same text. Medium at 50-75% |
| 4. Name stem | The name rules below. A supporting signal only | resume\_v3 and Resume v5 FINAL | Medium on its own. High with any other signal |
| 5. You | Manual merge or split |  | Always wins |

**What each confidence does**

- **High:** grouped automatically.
- **Medium:** a suggestion in the Ledger ("These 3 files look like the same document. Group them?"). Never grouped automatically, never used for warnings until confirmed.
- **Low:** nothing.

**Version or sibling variant?** Inside a family, every pair of files is labelled:

| Relationship | When | What it means for warnings |
| --- | --- | --- |
| **Newer version** | B was changed after A, A hasn't been changed since B appeared, and the link is High confidence | W1 can say A is older |
| **Sibling variant** | Both files keep getting edited, or they went to different destinations within 30 days, or their names carry different organisation names (Resume\_Razorpay vs Resume\_Emergent) | Never called older. Only W4 (wrong recipient) applies |
| **Export** | A PDF and the .docx, .pages, .key or .pptx it came from | Used by W5 only |
| **Unclear** | None of the above fit | Softer check (below) instead of W1 |

**Which is newer:** the document's internal modified date when it has one, otherwise the file's modified date. For downloads, the download order from the same source.

**The softer check ("Another version exists").** When the picked file has a sibling or an unclear relative that was changed more recently, Fallback doesn't say "older". It says: "There's another version of this document ({other}, edited {when}). Check you've picked the right one." It shows as a card only if that other file changed in the last 7 days. Otherwise it appears in the Ledger only.

**Privacy and limits.**

- Extracted text is used once to make the fingerprint, then thrown away. Only the fingerprint is stored.
- Text extraction stops at 200 pages or 5 MB of text.
- Scanned PDFs with no text layer rely on layers 1, 2 and 4 (no text recognition in v1).

**Speed.** Similar-file lookups use a bucketing index, so a new file is compared only with likely matches. Target: under 200 ms per new file.

**Examples the tests must cover**

| Files | Grouped by | Relationship |
| --- | --- | --- |
| resume\_v3.pdf, resume\_v5.pdf | Name + content | v5 is the newer version |
| final.pdf, 2.0.pdf, Document (3).pdf, downloaded from one email thread | Lineage + content | Versions, ordered by download and internal date |
| Resume\_Razorpay.pdf, Resume\_Emergent.pdf | Content | Sibling variants |
| Proposal.docx, Proposal.pdf | Name + content | Export pair (W5) |
| Two different screenshots | Not grouped | Generic names; images not near-identical |

**Name-stem rules (layer 4)**

1. Lowercase the name without its extension.
2. Remove version markers: v3, v 3, ver3, version 3, final, final final, draft, revised, updated, new, latest, copy, "(1)", trailing "-2" or "\_2", and dates in common formats.
3. Turn underscores, dashes and dots into spaces, collapse repeated spaces, and trim.
4. Stems under 4 characters, or generic ones (document, untitled, scan, image, img, file, screenshot, photo, export), never group by name. Lineage or content can still group them.

| File name | Stem |
| --- | --- |
| Resume\_v3.pdf | resume |
| Anshu Resume FINAL (1).pdf | anshu resume |
| resume-v5-final-final.pdf | resume |
| Pitch Deck 2026-11-16.key | pitch deck |
| Proposal\_Acme\_revised.docx | proposal acme |
| Screenshot 2026-11-16 at 10.42.png | (too generic for name grouping) |

### 8.4 Name-mismatch rule (W4) in detail

1. **Known organisations** = every destination label in the ledger (Razorpay, Acme), plus any names the user adds in Settings.
2. Split the file name into words (also splitting CamelCase like AcmeProposal). Ignore words under 3 letters and common words (resume, cv, final, draft, proposal, invoice, deck, the, for).
3. If a word matches a known organisation, and that organisation is **not** part of the current destination (its label, domain or page title), W4 fires.
4. If the destination couldn't be identified (Low confidence), W4 doesn't fire. It never guesses.

## 9. How it works on macOS: architecture and detection

### 9.1 Technology choices (and why)

| Choice | Decision | Why |
| --- | --- | --- |
| Language and UI | Swift 6, SwiftUI, with AppKit where SwiftUI can't do it (the warning card, the menu-bar popover details) | The Accessibility and file-system APIs this app depends on are native Mac APIs. Swift reaches them directly. Cross-platform frameworks (Tauri, Electron) would add a translation layer exactly where the hard part is |
| Minimum macOS | 14 Sonoma | Modern SwiftUI menu-bar support and login-item APIs. Covers the large majority of active Macs |
| Project setup | XcodeGen (project.yml) + a Swift package for the core logic | Xcode project files are hard for Claude Code to edit safely. A small YAML file generates them. Core logic in a package can be tested with `swift test` without opening Xcode |
| Database | SQLite through GRDB, with full-text search (FTS5) | Fast, reliable, one file, battle-tested. Search across 10,000+ sends instantly |
| Fingerprints | SHA-256 via Apple's CryptoKit, streamed in chunks | Built in, fast, no dependency |
| Updates | Sparkle 2 | The open-source standard for apps distributed outside the App Store |
| Distribution | Signed with a Developer ID and notarised by Apple, shipped as a DMG from the website and GitHub Releases. Not on the Mac App Store | App Store apps are sandboxed and can't observe other apps' windows, which is the core of Fallback |

### 9.2 Components

| Component | Job |
| --- | --- |
| **AppShell** | Menu-bar item, windows, lifecycle, launch at login |
| **PermissionsManager** | Checks and requests Accessibility and Apple Events permission, and watches for revocation |
| **PanelWatcher** | Watches the sending apps for file-open panels and reports the files chosen |
| **ContextResolver** | At the moment a panel opens: which app, which window, and for browsers which URL and tab title |
| **DestinationResolver** | Turns a URL or window title into a readable label like "Razorpay" (9.5) |
| **FileIndexer** | Watches chosen folders, fingerprints files, follows renames |
| **FamilyEngine** | Builds stems and families (8.3) |
| **WarningEngine** | Runs the rules (8.1) on each new send and decides what to show |
| **Store** | The database: sends, files, families, warnings, settings |
| **UI** | Popover, Ledger window, warning card, onboarding, settings, stats |
| **Updater** | Sparkle integration |

The engines (Destination, Family, Warning) contain no Mac-specific code. They live in the `FallbackCore` package with full unit tests. Everything that touches macOS APIs lives in the app target.

### 9.3 The send pipeline, step by step

1. A watched app becomes active. PanelWatcher attaches an Accessibility observer to that app's process.
2. A new window or sheet appears. PanelWatcher checks whether it's a file-open panel: the dialog role, a file browser inside, and a default button such as Open, Choose or Upload.
3. **At that moment** ContextResolver captures the app, window title, and for browsers the active tab's URL and title. Capturing now, not later, means the context belongs to the tab that asked for the file.
4. The user picks a file. When the panel closes through its default button, PanelWatcher reads the selected file path or paths.
5. The file is fingerprinted (or looked up, if already indexed) and matched to its family.
6. A send record is written to the database.
7. WarningEngine evaluates the rules. If one fires, the warning card appears.
8. Total target: under 1 second from the panel closing to the card appearing.

### 9.4 Reading the selected file: the riskiest part, decided by a spike

This is the one place where the plan must be proven on a real Mac before building everything else (milestone M1). Methods, in order of preference:

- **Method A, read the panel through Accessibility.** Mac file dialogs expose their contents to Accessibility, which is how VoiceOver reads them aloud. The selected items, the file-name field and the current folder can be read just before the panel closes.
- **Method B, ask Spotlight what was just used.** When a file is chosen in a dialog, macOS updates its "last opened" date. Right after the panel closes, a Spotlight query for files used in the last few seconds can confirm or recover the selection. This acts as a cross-check, or as a backup when Method A fails.
- **Not used:** Apple's Endpoint Security framework, which needs a special entitlement from Apple, and kernel extensions. Both break the "no permissions from anyone" rule.

**Known complication to test early:** in sandboxed apps, the open panel is drawn by a separate system service (the Open and Save Panel Service), not by the app itself. Safari, Mail and many App Store apps work this way. PanelWatcher may need to observe that service's process as well. Chrome and other non-sandboxed apps draw the panel themselves.

**Go/no-go gate:** the spike must reach 95% correct captures across Chrome, Safari, Mail, Slack and WhatsApp in 50 test picks. If it doesn't, the owner decides between narrowing v1 to Chrome-family browsers and Mail, or rethinking the approach.

### 9.5 Working out the destination

**For browsers**, Fallback asks the browser for the active tab's address and title using Apple Events:

- Chrome, Arc, Brave, Edge and other Chrome-based browsers: the active tab of the front window.
- Safari: the current tab of the front window.
- Firefox doesn't support this, so Fallback uses the window title through Accessibility (Medium confidence).

**Built-in destination rules** (shipped as a JSON file, easy to extend by pull request):

| Pattern | Label |
| --- | --- |
| `{tenant}.wd*.myworkdayjobs.com/...` | Tenant name, title-cased (razorpay becomes Razorpay) |
| `boards.greenhouse.io/{company}` or `job-boards.greenhouse.io/{company}` | Company from the path |
| `jobs.lever.co/{company}` | Company from the path |
| `jobs.ashbyhq.com/{company}` | Company from the path |
| `linkedin.com/jobs/...` | Company parsed from the tab title ("Role \| Company \| LinkedIn") |
| `naukri.com/...` | Company parsed from the tab title, else "Naukri" |
| `mail.google.com` | "Gmail" (recipient in v1.1) |
| `outlook.live.com`, `outlook.office.com` | "Outlook" (recipient in v1.1) |
| `web.whatsapp.com` | "WhatsApp Web" |
| Anything else | Main domain via the public suffix list (careers.acme.co.in becomes acme.co.in) |

**For native apps**, the window title is the best signal: Slack's is "#channel - Workspace - Slack", Mail's compose window shows the subject, WhatsApp desktop's shows the chat in some versions. Each app gets a small parser.

**User labels win.** Once a user renames a destination, that label applies to all future sends with the same pattern.

### 9.6 File indexing

- Uses FSEvents (the Mac's file-change notifications) on the chosen folders, with per-file events.
- Changes are debounced by 2 seconds so a file being saved isn't fingerprinted mid-write.
- Each file's identity comes from its volume and file ID, so renames and moves are followed.
- The initial index runs at low priority in the background. Target: 10,000 files in under 5 minutes on an M1 Mac without making the fan spin.

### 9.7 The warning card

A floating, non-activating panel at the top-right of the screen, below the menu bar. It sits above normal windows but never takes keyboard focus, so the user can keep typing in the browser.

### 9.8 Repository layout

```
fallback/
  project.yml              # XcodeGen definition
  CLAUDE.md                # rules for Claude Code
  PRD.md                   # export of this document
  App/                     # macOS app target (SwiftUI + AppKit)
    AppShell/ Permissions/ Panel/ Context/ Indexer/ UI/ Updater/
  Packages/FallbackCore/   # pure Swift, unit-tested
    Sources/FallbackCore/ Destination/ Family/ Warning/ Models/
    Tests/FallbackCoreTests/
  Resources/destinations.json
  Scripts/                 # build, sign, notarise, make-dmg
  docs/                    # website (GitHub Pages)
```

## 10. Data model

One SQLite file at `~/Library/Application Support/Fallback/fallback.sqlite`, in WAL mode for crash safety. Times are stored in UTC and shown in local time.

### files

| Column | Type | Notes |
| --- | --- | --- |
| id | integer, primary key |  |
| file\_identity | text | Volume ID + file ID, used to follow renames. Unique when present |
| path | text | Current path. Null if the file is gone |
| name | text | Current file name |
| ext | text | Lowercase extension |
| stem | text | From the family algorithm |
| family\_id | integer, foreign key | Null for too-generic names |
| sha256 | text | Hex fingerprint |
| size\_bytes | integer |  |
| modified\_at | datetime | File's modified date |
| first\_seen\_at | datetime |  |
| last\_seen\_at | datetime |  |
| in\_watched\_folder | boolean |  |

### families

| Column | Type | Notes |
| --- | --- | --- |
| id | integer, primary key |  |
| stem | text |  |
| display\_name | text | Editable, defaults to the stem title-cased |
| muted | boolean | "Don't warn for this document" |
| merged\_into\_id | integer | Set when the user merges families |

**Extra columns on files** for the grouping layers in 8.3: where\_from (download source), doc\_title, doc\_author, doc\_created\_at, doc\_internal\_id, text\_signature (MinHash, binary), image\_signature (perceptual hash).

### family\_links

| Column | Type | Notes |
| --- | --- | --- |
| id | integer, primary key |  |
| file\_a\_id, file\_b\_id | integer, foreign keys |  |
| signal | text | lineage, metadata, content, name or user |
| confidence | text | high, medium or low |
| similarity | real | 0 to 1, for content links |
| relation | text | version, variant, export or unclear |
| decided\_by | text | auto or user |

### destinations

| Column | Type | Notes |
| --- | --- | --- |
| id | integer, primary key |  |
| key | text, unique | Normalised identity, such as `workday:razorpay` or `domain:acme.co.in` |
| label | text | What the user sees |
| label\_source | text | rule, user or fallback |
| muted | boolean |  |

### sends

| Column | Type | Notes |
| --- | --- | --- |
| id | integer, primary key |  |
| file\_id | integer, foreign key |  |
| sha256 | text | Copied at send time, so history stays true even if the file later changes |
| file\_name\_at\_send | text | Copied at send time |
| destination\_id | integer, foreign key |  |
| app\_bundle\_id | text |  |
| app\_name | text |  |
| url | text | Null for native apps |
| page\_title | text | Window or tab title |
| confidence | text | high, medium or low |
| detection\_method | text | ax\_panel, spotlight or manual |
| sent\_at | datetime |  |
| is\_hidden | boolean | "Not a send" |

### warnings

| Column | Type | Notes |
| --- | --- | --- |
| id | integer, primary key |  |
| send\_id | integer, foreign key |  |
| rule | text | W1 to W5 |
| shown\_as\_card | boolean |  |
| outcome | text | fixed, sent\_anyway, muted, ignored, saved |
| created\_at | datetime |  |

### label\_rules, watched\_folders, watched\_apps, settings

Small tables for user-defined destination labels, folder and app lists, and key-value settings.

### Search index

An FTS5 virtual table over file\_name\_at\_send, destination label, page\_title and app\_name, kept in sync with triggers.

### Migrations

Every schema change is a numbered GRDB migration. Never edit an old migration. That rule goes in CLAUDE.md.

## 11. Privacy, security and permissions

### 11.1 Permissions Fallback asks for

| Permission | Why | Required? | If refused |
| --- | --- | --- | --- |
| Accessibility | To see file-open panels in other apps and read the chosen file | Yes | Fallback can't record sends. Onboarding explains this and offers to retry |
| Automation (one prompt per browser) | To read the address and title of the active tab | Strongly recommended | Sends are recorded with the window title only (Medium confidence) |
| Files and folders (Desktop, Documents, Downloads) | macOS asks the first time Fallback indexes these folders | For those folders | Those folders aren't indexed. Files picked from them are still fingerprinted at send time |

Fallback never asks for Full Disk Access, Screen Recording, Contacts, Mail data, the camera or the microphone.

### 11.2 What is stored, and what never is

- **Stored, locally:** file paths and names, fingerprints, sizes, dates, destination labels, URLs and page titles of upload pages, the app used, and warning outcomes.
- **Never stored:** the contents of any file, emails, messages, screenshots, keystrokes, or pages you visit without uploading.
- **Never sent anywhere:** anything. The only network request is Sparkle's update check (a static file on GitHub), which can be switched off. No analytics, no crash reporting in v1.

### 11.3 Honest note on sensitivity

URLs and page titles can be revealing (for example, a job application to a competitor). Anyone who can log in to the Mac as this user can open the ledger. v1 relies on the Mac's own protection (FileVault, user account). Settings offer "Delete all data" and "Forget sends older than N days". An optional app lock with Touch ID goes on the v1.1 list.

### 11.4 Security practices

- Hardened Runtime on. Signed with Developer ID, notarised by Apple.
- No loading of plugins or code at runtime.
- Logs use Apple's unified logging with file names marked private, so they don't appear in shared diagnostics.
- Dependencies kept minimal (GRDB, Sparkle) and pinned to exact versions.
- The whole codebase is public, so anyone can check these claims. Say so on the website.

## 12. Non-functional requirements

| ID | Area | Requirement |
| --- | --- | --- |
| NFR-1 | Speed | Warning card visible within 1 second of the panel closing (95th percentile) |
| NFR-2 | Idle cost | Under 1% CPU and under 80 MB memory when idle. No polling loops except the permission check during onboarding |
| NFR-3 | Indexing | 10,000 files in under 5 minutes on an M1, at background priority |
| NFR-4 | Search | Results under 100 ms with 10,000 sends |
| NFR-5 | Reliability | No data loss on crash or force-quit (WAL mode, transactions). A crash in PanelWatcher never takes the app down: the watcher restarts itself |
| NFR-6 | Compatibility | macOS 14 and 15 and the current release. Universal build (Apple silicon and Intel). Chrome, Safari, Arc, Brave, Edge, Firefox (Medium confidence) |
| NFR-7 | App size | DMG under 15 MB |
| NFR-8 | Accessibility | Every control labelled for VoiceOver. Full keyboard navigation in the Ledger. Respects Reduce Motion |
| NFR-9 | Localisation | English in v1. All strings in an Xcode String Catalog so translation is easy later |
| NFR-10 | Battery | No measurable battery impact in Activity Monitor's Energy tab over a normal day |

## 13. Build plan with Claude Code

About 5-6 weeks part-time. Each milestone ends with something you can run and check yourself. Don't start the next one until the current one passes its checks.

### 13.1 One-time setup on your Mac (day 1)

1. **Install Xcode** from the Mac App Store (it's large, around 15 GB). Open it once, accept the licence and let it install its components.
2. **Install Homebrew** (the Mac package manager) from brew.sh, then in Terminal run `brew install xcodegen git gh`.
3. **Install Claude Code** using the official instructions in Anthropic's Claude Code docs, and sign in.
4. **GitHub:** run `gh auth login`, then create a public repository called `fallback`.
5. **Apple Developer Program:** enrol as an individual (about $99 a year). Do this on day 1, because approval can take a few days and you'll need it by milestone M6.
6. **Test folder:** create `~/FallbackTest` with sample files: resume\_v3.pdf, resume\_v5.pdf, Proposal\_Acme.docx, Proposal\_Acme.pdf and so on. You'll use it in every milestone.
7. **Save this PRD** into the repo as `PRD.md` (export this doc to Markdown), and copy the Design/ folder (Fallback-Design.zip, with the screen PNGs exported into Design/screens/) into the repo root.

### 13.2 CLAUDE.md (put this in the repo root)

```
# Fallback
Mac menu-bar app that records every file the user sends and warns
before the wrong one goes out. Full spec: PRD.md. Requirement IDs
(FR-x, NFR-x, W1-W5) come from it.

## Stack
Swift 6 (strict concurrency), SwiftUI + AppKit, macOS 14+.
XcodeGen (project.yml): never edit .xcodeproj by hand, run `make gen`.
Core logic in Packages/FallbackCore (no AppKit imports there).
GRDB for SQLite. Sparkle for updates. No other dependencies
without asking.

## Design
UI follows Design/ in the repo root: BRAND.md and tokens.json
for styling, COPY.md and screens/*.png for wording and layout.
The PRD wins on behaviour. Every colour, font size and radius
lives in one Theme.swift built from tokens.json: no hex values
in views. Burnt Tangerine is for warnings only. Dark first;
light mode swaps tokens, same layout. Never invent a screen,
state or look that isn't designed: ask first.

## Commands
make gen | make build | make test | make run

## Rules
- Privacy is the product: no network calls except Sparkle.
  No analytics, no telemetry, no crash reporters.
- Never store file contents. Fingerprints and metadata only.
- Every engine change (Destination, Family, Warning) needs unit tests.
- DB changes = new numbered GRDB migration. Never edit old ones.
- Log with os.Logger; mark file names and URLs as private.
- The owner is not a developer: explain what you changed in plain
  English, and give exact steps when Xcode or macOS needs a click.
- Before deleting or moving files outside this repo, stop and ask.
- Reference PRD IDs in commit messages, e.g. "FR-12: reveal in Finder".
```

### 13.3 Milestones

**Before M0: D0, design (owner).** The owner designs the brand and all screens (section 6.3), with Claude's help where asked. Building starts only after the owner approves the designs and they're added to 6.3. D0 is done: approved 16 Nov 2026 and synced into the repo's Design/ folder (6.3). Milestones that build screens (M2 to M5) follow those designs. M3 grows to about 1.5 weeks because of content-similarity grouping (8.3).

| # | Milestone | Covers | Time | Done when |
| --- | --- | --- | --- | --- |
| M0 | Skeleton | 9.1, 9.8 | 1 day | A menu-bar icon appears with a Quit item. `make test` passes |
| M1 | **Detection spike (go/no-go)** | FR-1 to FR-4, 9.3, 9.4 | 3-5 days | 95% of 50 test picks captured correctly with file and context |
| M2 | Ledger | FR-5, FR-6, FR-9 to FR-13, section 10 | 1 week | Every pick appears in the popover with a sensible destination. Search works |
| M3 | Files and families | FR-15 to FR-22, 8.3 | 1 week | Test folder indexed, families correct, renames followed |
| M4 | Warnings | FR-23 to FR-27, section 8 | 1 week | Each scenario in 14.3 shows the right card, once, without stealing focus |
| M5 | Onboarding and settings | Flow A, FR-28 to FR-36 | 4-5 days | A fresh Mac user can install and reach "Got it" in under 2 minutes |
| M6 | Ship-ready | Section 12, 15.2 | 4-5 days | Signed, notarised DMG installs on a second Mac without warnings. Updates work |
| M7 | Launch | Section 15 | 1 week | Public release |

### 13.4 Prompts to paste into Claude Code

Start each milestone in a fresh Claude Code session from the repo folder. Ask it to plan first, read the plan, then say "go".

**M0, skeleton**

> Read CLAUDE.md and PRD.md. Set up the project as described in PRD section 9.8. Create a project.yml for a macOS 14 menu-bar app called Fallback: no Dock icon, Hardened Runtime on, not sandboxed, with the Apple Events entitlement and a clear NSAppleEventsUsageDescription. Create the FallbackCore Swift package with one passing test. Add a Makefile with gen, build, test and run. The app should only show a menu-bar icon with Quit. First give me a plan, then build it, then tell me exactly how to run it.

**M1, detection spike**

> We're doing milestone M1, the detection spike from PRD sections 9.3 and 9.4. Build a debug window that logs, live: (1) every file-open panel that appears in a watched app (app name, bundle ID, time), (2) the context captured when it opens (Chrome and Safari tab URL and title via Apple Events, otherwise window title via Accessibility), and (3) the selected file paths when it closes through its default button. Implement Method A (read the panel via Accessibility) and Method B (Spotlight recently-used query) and log which one succeeded. Handle sandboxed apps whose panel is drawn by the Open and Save Panel Service. Ignore Save panels. Add a Copy Log button. When done, write me a 50-pick test checklist across Chrome, Safari, Mail, Slack and WhatsApp desktop.

**M2, ledger**

> Milestone M2. Implement the database from PRD section 10 with GRDB, including FTS5 search and migrations. Promote the M1 detection into PanelWatcher and ContextResolver. Build DestinationResolver in FallbackCore using Resources/destinations.json, with a unit test for every row of the table in 9.5. Read Design/README.md and Design/BRAND.md first. Create Theme.swift from Design/tokens.json, add AppIcon.appiconset and the menu-bar template icon from Design/assets, and bundle Sora for the wordmark. Build the menu-bar popover (S1) to match Design/screens/01, with every state on it, and a first Ledger window (S2) with All sends and By destination to match screens 04 and 05. Use the wording in Design/COPY.md. Implement FR-5, FR-6 and FR-9 to FR-13. Show me how to check each requirement by hand.

**M3, files and families**

> Milestone M3. Build FileIndexer (PRD 9.6) with FSEvents on user-chosen folders, 2-second debounce, streamed SHA-256, and file identity so renames are followed. Build FamilyEngine in FallbackCore exactly as PRD 8.3, with unit tests for every example in the table plus at least 20 more edge cases you think of. Add the By document view and the document timeline (S3), matching Design/screens/08 and 09, plus the Ledger Warnings view and empty state (screens 06 and 07). Implement FR-15 to FR-22. Index \~/FallbackTest and show me the families it found.

**M4, warnings**

> Milestone M4. Build WarningEngine in FallbackCore for rules W1 to W5, with the precedence, sensitivity levels, muting and cool-down in PRD 8.2 and the W4 logic in 8.4, all unit-tested. Build the warning card (PRD 9.7, S4) as a non-activating floating panel, matching Design/screens/02 and 03 and using the wording in Design/COPY.md. Implement FR-23 to FR-27, including detecting saves. Then walk me through the five scenarios in PRD 14.3.

**M5, onboarding and settings**

> Milestone M5. Build onboarding (PRD Flow A, S5) including the live Accessibility check and the "Try it" step. Build Settings (S6) and Stats (S7). Match Design/screens/10 to 15 for onboarding, 16 to 21 for Settings, 22 for Stats and 23 for the small dialogs. Implement FR-28 to FR-36. Test onboarding as if on a fresh Mac: tell me how to reset permissions with tccutil so I can run it again from scratch.

**M6, ship-ready**

> Milestone M6. Check NFR-1 to NFR-10 and report numbers. Make a universal release build. Write Scripts/release.sh to sign with my Developer ID, notarise with notarytool, staple, and build a DMG. Integrate Sparkle 2 with an appcast hosted on GitHub Releases. Write the README (what it does, privacy promise, permissions, install, build from source). Tell me step by step what I need to do in my Apple Developer account.

### 13.5 Working well with Claude Code (for a non-developer)

- **One milestone per session.** Start fresh each time, so the context stays focused.
- **Plan first, then build.** Read the plan. If something in it surprises you, ask why before saying go.
- **Commit after every working step.** Ask: "commit this with a message that names the PRD IDs." If something breaks later, you can go back.
- **When something doesn't work, describe what you saw**, not what you think is wrong: "I picked resume\_v5.pdf in Chrome on Gmail and nothing appeared in the log."
- **Ask for logs.** "Add logging so we can see why this failed" fixes most mysteries.
- **Keep the PRD as the source of truth.** If you change your mind about behaviour, update this doc first, then tell Claude Code to re-read it.
- **Protect your real files.** Test on \~/FallbackTest, not on your actual resumes, until M4 passes.

## 14. Test plan

### 14.1 Automated tests (run with `make test`)

- **FamilyEngine:** every example in 8.3, plus edge cases: unicode names, emoji, very long names, names that are only a version ("v2.pdf"), Hindi file names.
- **DestinationResolver:** every row in 9.5, plus messy real URLs with query strings and tracking parameters.
- **WarningEngine:** each rule firing and not firing, precedence, sensitivity levels, muting, cool-down, and the "save" detection.
- **Store:** migrations run cleanly on an empty database and on one from the previous version.

### 14.2 Manual detection matrix (run before every release)

| App | Where | Action | Expected destination | Expected confidence |
| --- | --- | --- | --- | --- |
| Chrome | Gmail compose | Attach file | Gmail | High |
| Chrome | Workday application | Upload resume | Company name | High |
| Chrome | Greenhouse application | Attach resume | Company name | High |
| Chrome | LinkedIn Easy Apply | Upload resume | Company name | High |
| Chrome | Naukri profile | Update resume | Naukri | High |
| Chrome | WhatsApp Web | Attach document | WhatsApp Web | High |
| Safari | Gmail compose | Attach file | Gmail | High |
| Safari | Lever application | Attach resume | Company name | High |
| Arc or Brave | Any upload form | Upload | Main domain | High |
| Firefox | Any upload form | Upload | Window title | Medium |
| Mail | New message | Attach | Subject from window title | Medium |
| Slack desktop | A DM | Upload file | Channel or person from window title | Medium |
| WhatsApp desktop | A chat | Attach document | WhatsApp (chat if available) | Medium |
| Preview | Open a file | Open | Not recorded (not a sending app) | n/a |
| Chrome | Any page | Save As | Not recorded (Save panel) | n/a |
| Chrome | Upload form | Pick 3 files | 3 separate sends | High |
| Chrome | Upload form | Cancel | Nothing recorded | n/a |

### 14.3 Warning scenarios

1. **W1:** create resume\_v3.pdf, then later resume\_v5.pdf. Upload v3 in Gmail. Expect "Older version".
2. **W2:** upload resume\_v5.pdf to the same Greenhouse company twice. Expect "Already sent" the second time.
3. **W3:** send v3 to a company, then v5 to the same company. Expect "Heads up" naming v3.
4. **W4:** send anything to Acme (so Acme is known). Then upload Proposal\_Acme.pdf on a different company's page. Expect "Check the recipient".
5. **W5:** export Proposal.pdf, then edit Proposal.docx. Upload the PDF. Expect "Out-of-date export".
6. **Save:** after the W1 card, pick resume\_v5.pdf within 2 minutes. Stats should count one save.

### 14.4 Dogfooding and beta

- **Owner dogfood, 14 days:** use Fallback for real. Keep a one-line daily note: false alarms, missed sends, anything annoying. The precision target in 8.2 must hold.
- **Private beta, 10-15 people:** the interviewees from section 2. Send them the DMG directly. Ask for three things after a week: did onboarding make sense, did any warning feel wrong, and did it catch anything real.

### 14.5 Release checklist

All automated tests pass. Manual matrix done on the latest macOS and the one before it. Fresh-install onboarding tested after resetting permissions. DMG opens on a second Mac with no security warnings. Update from the previous version keeps all data. README and website match what the app actually does.

## 15. Launch and distribution

### 15.1 Before anything public

- **Name check for "Fallback".** It's a common word, so check that the domain you want is available (for example getfallback.app or fallback.so), that the GitHub name is free, and do a quick search of the trademark registers in India and the US for software products called Fallback. This is a check, not a filing. If there's a clash in software, pick a variant now rather than after launch.
- **Positioning line:** *Fallback remembers every file you send, and stops you sending the wrong one.* Sub-line: *Free, open-source, and nothing ever leaves your Mac.*

### 15.2 Website (one page, on GitHub Pages)

1. Headline and sub-line, plus a big Download for Mac button.
2. A 20-second looping demo: attach resume\_v3 in Gmail, the card appears, click "Show newer file", attach v5.
3. Three benefits: warns before the wrong file goes out, answers "what did I send them?", private by design.
4. Privacy section in plain words: what's stored, what isn't, and a link to the code.
5. Permissions explained before people install, so the Accessibility prompt isn't a surprise.
6. FAQ: why Accessibility, does it read my email (no), Windows (not yet), cost (free).

### 15.3 Channels and the angle for each

| Channel | Angle |
| --- | --- |
| Show HN | Technical honesty: how a Mac app can see which file you picked in any app, privately. Link the code |
| r/macapps | A small native utility, free and open-source |
| LinkedIn | Your personal story: the job-search moment that started it. This is your strongest channel, so write it yourself (humanised, no AI tone) |
| r/developersIndia, r/india, job-seeker communities | "Never send the wrong resume again" |
| Product Hunt | Launch about a week after HN, with the demo GIF and early "saved me" quotes |
| Homebrew | Submit a cask after the first stable release, so developers can `brew install` it |

### 15.4 Launch-day checklist

DMG and website live. GitHub README polished, with the demo GIF at the top. Issues and Discussions turned on, with issue templates (bug, wrong destination, false alarm). A "Fallback saved me" discussion pinned. You're free for the day to answer every comment within an hour.

### 15.5 After launch

- Ship a small update every week for the first month. Fast fixes build trust in open-source projects.
- Collect "saved me" stories. They're your best marketing and your evidence for any future paid tier.
- Accept pull requests to destinations.json. It's the easiest way for the community to contribute.

## 16. Risks, open questions and roadmap

### 16.1 Risks

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Reading the selected file is unreliable in some apps | Medium | High | M1 spike with a go/no-go gate before anything else is built. Two methods (Accessibility plus Spotlight). Confidence labels instead of silent guesses |
| A macOS update changes how open panels behave | Medium | High | Test on each macOS beta from June. Watcher self-heals and reports through the permission-health indicator |
| People are scared by the Accessibility prompt | High | Medium | Explain before asking. Open-source code. A privacy page in plain words. Compare to familiar apps that need the same permission |
| False alarms make people ignore or uninstall | Medium | High | Precision over recall. Generic names never grouped. Two-week dogfood with a hard false-alarm limit |
| Drag-and-drop uploads are missed | High | Medium | Stated openly in v1. Planned for v1.2 |
| Name clash with an existing "Fallback" software product | Low-Medium | Medium | Check in 15.1 before going public |
| Ledger reveals sensitive history on a shared Mac | Low | Medium | Delete-all, auto-forget, and Touch ID lock on the v1.1 list |
| Scope creep delays launch | High | Medium | Non-goals in section 4 are a contract. New ideas go to the roadmap, not into v1 |

### 16.2 Open questions

1. Should W2 ("Already sent") show as a card in Balanced mode? Decide after dogfooding.
2. Should a PDF and the DOCX it came from count as one document family, or stay two families linked only by W5?
3. Is 90 days the right window for W2?
4. Does the menu-bar tick animation feel reassuring or distracting?
5. Is opt-in, anonymous counting worth adding in v1.1, given the privacy story?

### 16.3 Roadmap

**v1.1 (about 4-6 weeks after launch)**

- Recipient names from Gmail, Outlook and Mail compose windows (FR-8).
- Import your Sent email history from Gmail on the Mac, with a Google app password, so your trail starts complete on day one.
- Touch ID lock for the Ledger.
- Quick Look preview inside the warning card.

**v1.2**

- Detect files dragged into browser windows and chat apps.
- Smarter families: suggest merges when two families look like the same document.

**v2 and the business**

- **Fallback for teams (paid):** a shared, end-to-end-encrypted ledger, so a sales team, agency or CA firm knows what any member sent to each client. This is the first thing worth charging for.
- **Windows version,** once the Mac app proves the demand.
- **The bigger platform:** the same engine (watching files, fingerprints, versions) is the base for the agent-safety idea from the research doc. Fallback can grow from "undo the wrong send" into "undo anything that went wrong on your computer".
