#!/bin/zsh
# Double-click to rebuild Fallback in Release and reinstall it to /Applications.
cd "$(dirname "$0")" && make install
echo
echo "Done. You can close this window."
