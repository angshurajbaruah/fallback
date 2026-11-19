# Security and privacy

Fallback watches which files you send, so it should be clear exactly what it can see, what it keeps and where. This page is the plain-English version of [PRD.md](PRD.md) section 11.

## What Fallback reads

| Permission | What it reads | When |
| --- | --- | --- |
| **Accessibility** (called **Device Control and Data Access** on newer macOS) | The path of the file you pick in a "choose a file" window, and the title of that app's window | Only while a file-choosing window is open in a watched app: Safari, Chrome, Arc, Brave, Edge, Vivaldi, Firefox, Mail, Outlook, Slack, WhatsApp, Telegram, Teams, Discord and Zoom. Any of them can be switched off in Settings › Apps |
| **Automation**, one prompt per browser (optional) | The address and title of the browser's current tab | Once, at the moment you upload a file |
| **Files and folders** you choose (optional) | Each file's name, size and dates. To tell versions apart, it also briefly reads the file to make fingerprints (below) | When it first indexes a folder, then when files change |

It never reads what you type, what's on your screen, your emails, messages or contacts, or any window other than the file-choosing one. It never asks for Full Disk Access, Screen Recording, the camera or the microphone.

## What it stores

Everything is in one database on your Mac:

```
~/Library/Application Support/Fallback/fallback.sqlite
```

(In Finder: choose **Go › Go to Folder…**, paste `~/Library/Application Support/Fallback` and press Return.)

It holds:

- **Sends:** the file's name and path, which app it went through, the page address and title (for browsers) or window title, the destination's name, and the time.
- **Files in your chosen folders:** name, path, size, dates, and the title, author and creation date stored inside a PDF or document.
- **Fingerprints:**
  - **Exact copies:** a SHA-256 checksum.
  - **Similar documents:** a compact "word pattern" fingerprint made of 64 numbers. Your text can't be rebuilt from it.
  - **Similar images:** a 64-bit image hash.
- **Warnings** Fallback showed or recorded, and what you did next.
- **Your settings**, such as watched folders, labels you gave destinations, and muted documents.

**Never stored:** the contents of any file, emails, messages, screenshots, keystrokes, or pages you visited without uploading anything.

Settings › Privacy › **Delete All…** removes the database completely. You can also quit Fallback and delete the folder above.

## What never leaves your Mac

Everything. Fallback has no account and no server. It makes no network connections, and has no analytics, telemetry or crash reporting. A future update checker will be the only network request: it will fetch a small public file from GitHub, send nothing about you, and can be switched off in Settings › Privacy.

Logs go to macOS's own logging system with file names and addresses marked private, so they don't appear in shared diagnostic reports.

## Something to be aware of

Page addresses and titles can be revealing, for example a job application to a competitor. Anyone who can log in to your Mac user account could open Fallback's Ledger. Fallback relies on your Mac's own protection: your login password and FileVault. Turn on FileVault in System Settings › Privacy & Security if you haven't already.

## How it's built

- **Signing:** each copy is built on your own Mac and signed with your own free Apple ID, with Hardened Runtime on.
- **Sandbox:** Fallback isn't sandboxed, because sandboxed apps can't watch other apps' file windows. Its only extra permission is to send Apple Events (to read a browser's address).
- **No outside code:** no plugins, and no code is downloaded at runtime.
- **Dependencies:** just one, [GRDB](https://github.com/groue/GRDB.swift) for the database, pinned to an exact version.

## Reporting a problem

If you find a security or privacy problem, please report it privately first:

1. On the repository page, open the **Security** tab and click **Report a vulnerability**.
2. If that button isn't there, open an issue titled "Security report" **without any details**, and the maintainer will arrange a private way to talk.

Please include the macOS version, the Fallback version (Settings › About), and the steps to see the problem. Fixes for privacy problems come before anything else.
