# M5: run onboarding again as if on a fresh Mac

Quit Fallback first (⌘Q in the popover). Then in Terminal:

```bash
tccutil reset Accessibility com.angshurajbaruah.fallback
tccutil reset AppleEvents com.angshurajbaruah.fallback
tccutil reset SystemPolicyDocumentsFolder com.angshurajbaruah.fallback
tccutil reset SystemPolicyDesktopFolder com.angshurajbaruah.fallback
tccutil reset SystemPolicyDownloadsFolder com.angshurajbaruah.fallback
```

These remove the permission (on this Mac: "Device Control and Data Access"), browser control, and folder access.

To make Fallback forget everything too, use Settings › Privacy › **Delete All…** (it reopens onboarding), or quit and run:

```bash
rm -rf ~/Library/Application\ Support/Fallback ~/Library/Logs/Fallback
```

Then `cd ~/fallback && make run`: onboarding opens at step 1.
