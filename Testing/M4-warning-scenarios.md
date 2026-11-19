# M4 walkthrough: the warning scenarios (PRD 14.3)

Use the files in `~/FallbackTest` and the offline test page `~/fallback/Testing/upload-test.html` (drag it onto Chrome or Safari). The links at the top of the page turn it into a pretend careers page for **Acme**, **Globex** or **Northwind**; Fallback names the destination after it. Nothing is uploaded anywhere.

Start Fallback with `cd ~/fallback && make run`.

## How a card behaves (FR-26)

- It slides in at the top right, under the menu bar, never in the middle of the screen.
- It never takes the keyboard: keep typing in the browser while it's up.
- It stays 10 seconds (the thin line along the bottom counts down). Hovering pauses it.
- While a card is up, the menu-bar icon has an orange dot.
- Buttons: the fix (filled), **Send anyway**, and a quiet **Don't warn for this document** link (FR-25).
- Every warning, card or not, is listed in the Ledger › **Warnings** (FR-27).

**Sensitivity (PRD 8.2).** Fallback starts on **Balanced**: W1, W4, W5 and the softer check show as cards; W2 and W3 go to the Ledger only. Change it in Settings › **Warnings**. Pick **Strict** if you want W2 and W3 as cards.

**Cool-down.** The same warning for the same document won't show as a card twice within 10 minutes. If a card doesn't appear on a repeat, that's why: Ledger › Warnings lists it as "Already warned about this N minutes ago".

## 1. W1 Older version

1. On the test page (any company, or Gmail with a new draft), pick `resume_v3.pdf`.
2. **Expect** the card **Older version**: "resume_v3.pdf is older than resume_v5.pdf, which you edited …". The strip shows each file's date: **5 Nov · picking now** → **{date} · edited {when}**.
3. Click **Show newer file**: Finder opens with `resume_v5.pdf` selected.

> Cards show dates, never version numbers. The Ledger and the document timeline still number the family (resume_v3.pdf is v1 there, as the oldest file).

## 2. W2 Already sent

1. Click **Northwind**. Pick `resume_v5.pdf`.
2. Pick `resume_v5.pdf` again on the same page.
3. **Expect** in Balanced: no card, and Ledger › Warnings shows **Already sent · W2 · Ledger only (Balanced)**. In Strict: the card **Already sent**, "You sent this exact file to Northwind on …".

## 3. W3 Changed since last send

1. Click **Globex**. Pick `resume_v3.pdf` (W1 shows; click **Send anyway**).
2. Pick `resume_v5.pdf` on the same page.
3. **Expect** in Balanced: Ledger › Warnings shows **Changed since last send · W3**. In Strict: the card **Heads up**, "Globex has an earlier version (resume_v3.pdf, …)".

## 4. W4 Check the recipient

1. Click **Acme**. Pick any file (so Fallback knows Acme).
2. Click **Globex**. Pick `Proposal_Acme.pdf`.
3. **Expect** the card **Check the recipient**: "This file mentions Acme, but you're sending it to Globex." The file name shows *Acme* in orange, and the card says **1 more check ›** (W5 also fired; W4 comes first).
4. **Show sends to Acme** opens the Ledger at Acme.

## 5. W5 Out-of-date export

1. Click **no company** (or use Gmail). Pick `Proposal_Acme.pdf`.
   On the test page, "no company" is still named after the page title, so W4 also fires (under "more", or as the card if W4 hasn't shown for this document in the last 10 minutes). Gmail doesn't do this.
2. **Expect** the card **Out-of-date export**: "Proposal_Acme.docx was edited after this PDF was made." The strip: PDF made 14 Nov → DOCX edited 18 Nov.
3. **Reveal source document** opens Finder at the DOCX.

## 6. Save (FR-27)

1. Pick `resume_v3.pdf` (W1 card).
2. Within 2 minutes, pick `resume_v5.pdf`.
3. **Expect** Ledger › Warnings: the W1 row's outcome turns **Saved** ("Picked resume_v5.pdf … s later"), and the summary counts **1 save**.

## Also: the softer check

Pick `Resume_Razorpay.pdf`. **Expect** **Another version exists**, never "Older version". Its buttons are **Show other version** and **It's the right one**.

## Muting

On any card, **Don't warn for this document** mutes that document for every rule; on W2, **Don't warn for this destination** mutes the place. Undo it in Settings › Warnings › **Muted**. Later warnings for it are listed in the Ledger as "Muted for this document" (or destination), never as cards.
