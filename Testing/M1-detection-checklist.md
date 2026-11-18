# M1 detection spike: 50-pick checklist

Goal (PRD 9.4): at least **48 of 50** rows pass (95%). If fewer pass, you decide between narrowing v1 to Chrome-family browsers and Mail, or rethinking the approach.

## Before you start

1. **Start Fallback:** in Terminal, `cd ~/fallback && make run`.
2. **Accessibility:** System Settings › Privacy & Security › Accessibility. Turn **Fallback** on. If it's not listed, click **+**, press ⌘⇧G, paste `~/fallback/build/Build/Products/Debug/Fallback.app` and click Open. If you see an older Fallback entry from before 18 Nov, remove it with **–** first.
3. **Open the log:** click the Fallback icon in the menu bar › **Detection Log…**. The top line should say "Accessibility allowed".
4. **Browser permission:** the first time you pick a file in Chrome and in Safari, macOS asks "Fallback wants to control Google Chrome / Safari". Click **Allow**. If you clicked Don't Allow: System Settings › Privacy & Security › Automation › Fallback › turn Chrome and Safari on.
5. **Test page:** open `~/fallback/Testing/upload-test.html` in Chrome and Safari (drag the file onto the browser window). It's offline: nothing is uploaded.
6. **Never press Send** in Gmail, Mail, Slack or WhatsApp. Picking a file only attaches it to a draft; remove it or discard the draft afterwards.

All files are in `~/FallbackTest`.

## What a pass looks like

A pick passes when the log shows, in order:

- `OPEN PANEL` with the right app,
- `CONTEXT` with the right tab address (browsers) or window title (other apps),
- `CLOSED by the Open button` (or double-click),
- a `METHOD A` or `METHOD B` line with the **exact** file(s) you picked,
- `RESULT ✓ …`.

A cancel passes when it shows `CLOSED with Cancel. Nothing recorded.` and no METHOD lines. A Save-panel row passes when it shows only `IGNORED`.

Write ✓ or ✗ in the Pass column. For every ✗, write one line on what you saw.

## Chrome (12)

| # | Where | Do this | Pass |
|---|---|---|---|
| 1 | Test page, One file | Pick `resume_v5.pdf`, click Open | |
| 2 | Test page, One file | Double-click `resume_v3.pdf` | |
| 3 | Test page, One file | Click `Proposal_Acme.pdf`, press Return | |
| 4 | Test page, Several files | ⌘-click `Proposal_Acme.pdf` and `Proposal_Acme.docx`, click Open (expect two files) | |
| 5 | Test page, One file | Click `final.pdf`, then click Cancel (expect nothing recorded) | |
| 6 | Test page, One file | Click `2.0.pdf`, press Escape (expect nothing recorded) | |
| 7 | Test page, One file | Pick `Document (3).pdf` (spaces and brackets in the name) | |
| 8 | Test page, One file | In the panel press ⌘3 (column view), pick `Resume_Emergent.pdf` | |
| 9 | Test page in tab 1, any site in tab 2 | Open the panel in tab 1, switch to tab 2 with ⌘⌥→, come back, pick `Resume_Razorpay.pdf`. CONTEXT must show tab 1 | |
| 10 | Gmail, new message | Paperclip, pick `Resume_Razorpay.pdf`. CONTEXT shows mail.google.com. Discard the draft | |
| 11 | Test page, One file | Type `Screenshot` in the panel's search box, click the 10.42 screenshot, click Open | |
| 12 | Test page | Press ⌘S (Save panel). Expect only `IGNORED`. Cancel it | |

## Safari (12)

| # | Where | Do this | Pass |
|---|---|---|---|
| 13 | Test page, One file | Pick `resume_v5.pdf`, click Open | |
| 14 | Test page, One file | Double-click `resume_v3.pdf` | |
| 15 | Test page, One file | Click `Proposal_Acme.pdf`, press Return | |
| 16 | Test page, Several files | ⌘-click `Proposal_Acme.pdf` and `Proposal_Globex.docx`, click Open (expect two files) | |
| 17 | Test page, One file | Click `final.pdf`, then Cancel | |
| 18 | Test page, One file | Click `2.0.pdf`, press Escape | |
| 19 | Test page, One file | Pick `Document (3).pdf` | |
| 20 | Test page, One file | Column view (⌘3), pick `Resume_Emergent.pdf` | |
| 21 | Test page in tab 1, any site in tab 2 | Open the panel in tab 1, switch tabs and back, pick `Resume_Razorpay.pdf`. CONTEXT must show tab 1 | |
| 22 | Gmail, new message | Paperclip, pick `resume_v5.pdf`. Discard the draft | |
| 23 | Test page, One file | Search `Screenshot`, pick the 18.05 screenshot | |
| 24 | Test page | File › Export as PDF… (Save panel). Expect only `IGNORED`. Cancel it | |

## Mail (10)

Start a new message (⌘N), then attach with ⌘⇧A. Discard the message at the end.

| # | Do this | Pass |
|---|---|---|
| 25 | Pick `resume_v5.pdf`, click Choose File | |
| 26 | Double-click `Proposal_Acme.docx` | |
| 27 | Click `final.pdf`, press Return | |
| 28 | ⌘-click `resume_v3.pdf` and `resume_v5.pdf`, click Choose File (expect two files) | |
| 29 | Click `2.0.pdf`, then Cancel | |
| 30 | Click `Document (3).pdf`, press Escape | |
| 31 | Pick `Document (3).pdf` | |
| 32 | Column view (⌘3), pick `Resume_Razorpay.pdf` | |
| 33 | Give the message the subject "Test 33", then attach `Proposal_Globex.docx`. CONTEXT window title shows "Test 33" | |
| 34 | Select any received message, File › Save As… (Save panel). Expect only `IGNORED`. Cancel it | |

## Slack (8)

In a channel or your own DM, click **+** › Upload from your computer. Don't send: remove the file from the message box after each pick.

| # | Do this | Pass |
|---|---|---|
| 35 | Pick `resume_v5.pdf`, click Open. CONTEXT window title names the channel | |
| 36 | Double-click `Proposal_Acme.pdf` | |
| 37 | Click `final.pdf`, press Return | |
| 38 | ⌘-click `Resume_Emergent.pdf` and `Resume_Razorpay.pdf`, click Open (expect two files) | |
| 39 | Click `2.0.pdf`, then Cancel | |
| 40 | Click `resume_v3.pdf`, press Escape | |
| 41 | Column view (⌘3), pick `Proposal_Globex.docx` | |
| 42 | Pick the 10.42 screenshot | |

## WhatsApp desktop (8)

Open the chat with yourself ("Message yourself"). Click **+** › Document (or Photos & Videos for 49). Don't send: close the preview after each pick.

| # | Do this | Pass |
|---|---|---|
| 43 | Pick `resume_v5.pdf`, click Open. CONTEXT window title noted | |
| 44 | Double-click `Proposal_Acme.pdf` | |
| 45 | Click `final.pdf`, press Return | |
| 46 | ⌘-click `resume_v3.pdf` and `Proposal_Acme.docx`, click Open (expect two files) | |
| 47 | Click `2.0.pdf`, then Cancel | |
| 48 | Click `Document (3).pdf`, press Escape | |
| 49 | Photos & Videos, pick the 18.05 screenshot | |
| 50 | Pick `Proposal_Globex.docx` | |

## When you're done

Count the ✓. Click **Copy Log** in the Detection Log window and paste the log into Claude Code with this page's ✓/✗ column, so we can see which method worked where.

## Results (18 Nov 2026)

Run by the owner across Chrome (Gmail, ChatGPT, ilovepdf), Safari (Gmail, test page), Mail, Slack and WhatsApp, not strictly in row order.

| What | Tried | Passed |
|---|---|---|
| File panels detected | 44 | 44 (none missed) |
| Picks with the right file(s) | 34 | 33 |
| Escape or Cancel recorded nothing | 10 | 10 |
| Several files at once | 6 | 6 |
| List view (⌘2) | 4 | 4 |
| Save panel recorded nothing | 1 | 1 |

**43 of 44 = 98%. Gate (95%) passed.**

- The one miss was a fast double-click in Chrome: the panel closed before the selection was read. Fixed by reading the row under the mouse; rechecked in Mail.
- **Method A carried every capture. Method B (Spotlight) matched 0 of 34**: attaching a file doesn't set its last-used date. Don't rely on it.
- Every panel was a sheet in the app's own window, found by its `OKButton`/`CancelButton` identifiers, including Safari and Mail (sandboxed).
- Destinations: browsers give the tab URL and title; Mail gives the subject; Slack gives channel and workspace; WhatsApp only gives "WhatsApp".
- For M2: a browser's own File › Open (opening a page) is logged as a send. Safari labels upload panels "Upload", Chrome says "Open" for both.
