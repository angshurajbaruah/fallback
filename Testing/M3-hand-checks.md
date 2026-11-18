# M3 hand checks

How to check each M3 requirement yourself. Start Fallback with `cd ~/fallback && make run`. In M3 it watches `~/FallbackTest` only. Open the Ledger from the popover (**Open Ledger**, or ⌘L).

## What Fallback found in ~/FallbackTest (19 Nov 2026)

| Document | Files | How they're related |
|---|---|---|
| **Resume** | resume_v3.pdf, resume_v5.pdf, final.pdf, 2.0.pdf, Document (3).pdf | Versions. v5 is newer than v3 (the dates tie, so the version numbers decide). final, 2.0 and Document (3) are 100% the same text but carry no order, so they're "unclear" |
| | Resume_Razorpay.pdf, Resume_Emergent.pdf | Sibling variants: tailored per company, never called "older" |
| **Proposal Acme** | Proposal_Acme.docx, Proposal_Acme.pdf | Export pair (for W5 in M4) |
| **Proposal Globex** | Proposal_Globex.docx | Its own document, not grouped with Acme |
| *(none)* | the two screenshots | Not grouped: generic names, different images |
| *(skipped)* | README.md | Under 1 KB (FR-21) |

## FR-15: changes show up within 5 seconds

1. Open the Ledger › **By document** › **Resume**.
2. In Finder, duplicate `resume_v5.pdf` (⌘D) and rename the copy `resume_v6.pdf`.
3. Within about 5 seconds, Resume shows a new version. Delete the copy, and it disappears from the timeline within 5 seconds too.

## FR-16: fingerprints

In the Resume timeline, each version shows its size and a short fingerprint ("4f2a…9c1e"). Two different files never share a fingerprint. Files over 500 MB use a quicker sampled fingerprint (checked by an automatic test).

## FR-17: renames and moves keep history

1. Send `Proposal_Acme.pdf` from the test page (so it has a send).
2. In Finder, rename it to `Proposal_Acme_old.pdf`.
3. In the Ledger, open the send: it now shows the new location, and the file is still the same document, with its send history.
4. Rename it back.

## FR-18: document families

Open **By document**. You should see the families in the table above. Click **Resume** to see the timeline (screen 08): versions on the left, with where each went; sibling variants and "Where versions went" on the right.

## FR-19: files from outside watched folders

1. Copy `resume_v5.pdf` to your Desktop (Desktop isn't watched in M3).
2. Pick that copy on the test page.
3. The send is recorded and fingerprinted, and it joins the Resume family by name and content. Delete the Desktop copy afterwards.

## FR-20: merge and split

- **Split:** in Resume, click **Split off…** and choose `Resume_Emergent.pdf` › **Split off**. It becomes its own document straight away.
- **Merge:** open that new document, click **Merge…** and choose **Resume**. The "Group into one document" dialog lists every file; click **Group**. Everything is back together, under the name in the dialog.
- **Suggestions:** when files look alike but not certainly (for example, the same document title only), By document shows "These files look like the same document" with **Not now**, **Review** and **Group**.

## FR-21: noise is skipped

Create a folder called `node_modules` inside `~/FallbackTest` and put a PDF in it. It never shows up. The same goes for hidden files, `.git`, `Library`, caches, app bundles and anything under 1 KB.

## FR-22: file types

PDF, Word, Pages, PowerPoint, Keynote, Excel, Numbers, CSV, TXT, Markdown, RTF, PNG, JPG, HEIC and ZIP are indexed. An `.mp3` in the folder is ignored. (Adding your own types and exclusions is stored now; the Settings screen for it comes in M5.)

## Also in M3

- **Version chips:** the popover, All sends (Ver. column) and the send detail show v1, v5 and so on. The detail panel shows "v5 · newest" and the family's versions as dots.
- **By destination:** shows "Latest resume they have" and "Also has" when a place received more than one version.
- **Popover search:** "Also matching" lists files on your Mac that match but were never sent.
- **Warnings:** the view is in place with "No warnings yet." Warnings arrive in M4.
- **Empty Ledger:** with no sends, All sends shows "Your trail starts with the next file you send", **Try it on a test page** and **Choose folders**, which adds a folder to watch.
