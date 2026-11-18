# M2 hand checks

How to check each M2 requirement yourself. Start Fallback with `cd ~/fallback && make run`. Use the files in `~/FallbackTest` and the offline page `~/fallback/Testing/upload-test.html`. Never press Send.

## Where things are

- **Popover:** click the Fallback icon in the menu bar. The search box is ready to type in.
- **Ledger:** in the popover, click **Open Ledger** or press **⌘L**.
- **Quit:** press **⌘Q** while the popover or the Ledger is open.

## FR-9: every send is stored, and survives restarts

1. In Chrome, on the test page, pick `resume_v5.pdf`.
2. Open the popover. `resume_v5.pdf` is at the top of **Recent**.
3. Quit Fallback (⌘Q) and start it again with `make run`. Open the popover: the send is still there.
4. Restart your Mac, start Fallback, and check again.

Pass: the send is still there after each restart, with its file, destination, app and time. In the Ledger's detail panel you also see the **Fingerprint** and **Size**.

## FR-5: readable destination names

| Do this | Destination should read |
|---|---|
| Gmail in Chrome or Safari: attach a file to a new draft | Gmail |
| Any normal website upload, such as ilovepdf.com | the site's main domain, such as **ilovepdf.com** |
| Slack channel: + › Upload from your computer | **#channel-name** |
| Slack direct message | the person's name |
| Mail, new message | Mail |
| WhatsApp | WhatsApp |
| The offline test page | the browser's name (it's a file on your Mac, not a website) |

If you apply for jobs on Workday, Greenhouse, Lever, Ashby, LinkedIn or Naukri, the destination should be the **company name**. Every row of the PRD 9.5 table also has an automatic test (`make test`).

## FR-6: confidence dot

In the Ledger, the dot at the end of each row shows confidence:

- **Solid blue (High):** the file and the web address are both known. Any browser pick.
- **Solid grey (Medium):** the file is known, but there's only a window title. Mail, Slack, WhatsApp.
- **Grey ring (Low):** Fallback only knows the file's name. Rare.

Click a row: the detail panel shows the same as a label, such as "High confidence".

## FR-10: search

1. Open the popover and type part of a file name, such as `resume`. Results appear as you type.
2. Type a destination, such as `gmail`. The first row summarises Gmail ("n sends · last today"), then lists the files.
3. Type an app (`slack`) or words from a page title.
4. Type something that matches nothing, such as `zzzz`. You get "No sends match “zzzz”" and "Search runs on this Mac only. Nothing leaves it."
5. Type a near-miss of one of your destinations (such as `gmial`). It suggests "Did you mean Gmail?".
6. In the Ledger, the **Search sends** box filters the table the same way.

Speed (under 100 ms for 10,000 sends) is checked by an automatic test.

## FR-11: All sends and By destination, newest first

1. Open the Ledger. **All sends** groups sends under Today, Yesterday, This week and Earlier, newest first.
2. Click **Today**, **7 days** and **All** at the top. The list changes to match.
3. Click the **Sent** column heading. The order flips to oldest first; click again to flip it back.
4. Click **By destination** in the sidebar. Each place shows its number of sends. Click one to see its timeline, newest first.
5. Click a destination under **Destinations** in the sidebar. It opens straight to that place.

## FR-12: send detail and its four actions

Click a send in **All sends**. In the right-hand panel:

- **Quick Look:** previews the file.
- **Reveal in Finder:** opens Finder with the file selected.
- **Open page:** opens the web page you uploaded from (browser sends only).
- **Copy file:** then paste in Finder (⌘V) to get a copy.

Then move or delete one test file you sent, such as by dragging `final.pdf` to the Trash, and click its send again. **Location** says "Moved or deleted since it was sent", and the file buttons are greyed out. Put the file back afterwards.

(Finding a moved file by its fingerprint needs folder watching, which comes in M3.)

## FR-13: rename a destination, delete, "not a send"

1. Click a send, then the **pencil** at the top right. The "Edit destination label" box shows what Fallback saw.
2. Type a new name, such as `My test page`. Leave **Use for future sends to this address** ticked, and click **Save**. This send and the earlier sends to the same place are renamed. Pick another file on the same page: the new send uses the new name too.
3. Rename again with the box **unticked**. Only that one send changes.
4. In **By destination**, click **Rename** to rename a whole place.
5. Right-click a send and choose **Not a Send**. It disappears from every list and from search.
6. Right-click a send and choose **Delete…**, then confirm. It's gone for good.

## Also in M2

- **Pause:** click the pause icon in the popover and choose **For 1 Hour**. The menu-bar icon dims, and the popover says "Paused until …". Pick a file: nothing is recorded. Click **Resume**.
- **Permission problem:** turn Fallback off in System Settings › Privacy & Security › Accessibility. Within a second the menu-bar icon gets an orange dot, and the popover shows "Fallback can't see file pickers". Turn it back on, and both go away.
- **Empty state:** on a brand-new ledger, the popover shows "Nothing sent yet" and **Try it on a test page**, which opens the offline test page.
- **Light mode:** switch macOS to Light. The Ledger follows screen 24.
