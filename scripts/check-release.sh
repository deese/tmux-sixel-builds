#!/usr/bin/env bash
set -euo pipefail

TMUX_API="https://api.github.com/repos/tmux/tmux/releases/latest"
LOCAL_API="https://api.github.com/repos/deese/tmux-sixel-builds/releases"

LATEST_VERSION=$(curl -s "$TMUX_API" | jq -r '.tag_name' | sed 's/^v//')
echo "latest_version=$LATEST_VERSION" >> "$GITHUB_OUTPUT"

if curl -s "$LOCAL_API" | jq -e '.[] | select(.tag_name == "tmux-'$LATEST_VERSION'")' > /dev/null; then
    echo "should_build=false" >> "$GITHUB_OUTPUT"
    echo "Release tmux-$LATEST_VERSION already exists. Skipping build."
else
    echo "should_build=true" >> "$GITHUB_OUTPUT"
    echo "New release detected: tmux-$LATEST_VERSION. Proceeding with build."
fi
