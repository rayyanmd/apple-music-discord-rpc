#!/bin/sh -xe
# cd to project root
cd "$(dirname "$0")"
cd ..

DENO_PATH="$(which deno)"
if [ -z "$DENO_PATH" ]; then
  echo --- Deno not found. Please install Deno first and add it to your PATH.
  exit 1
fi
DENO_PATH_DIR="$(dirname "$DENO_PATH")"

./scripts/uninstall.sh

# Prompt for API keys
read -p "Enter your LASTFM_API_KEY: " LASTFM_API_KEY
read -p "Enter your LASTFM_API_SECRET: " LASTFM_API_SECRET

# Get a request token
echo --- Getting Last.fm request token...
TOKEN_RESPONSE=$(curl -s "https://ws.audioscrobbler.com/2.0/?method=auth.getToken&api_key=$LASTFM_API_KEY&format=json")
TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$TOKEN" ]; then
  echo --- Failed to get Last.fm token. Check your API key.
  exit 1
fi

# Ask user to authorize in browser
echo --- Please authorize the app in your browser:
echo "https://www.last.fm/api/auth/?api_key=$LASTFM_API_KEY&token=$TOKEN"
open "https://www.last.fm/api/auth/?api_key=$LASTFM_API_KEY&token=$TOKEN"
read -p "Press Enter after you have authorized the app..."

# Sign the getSession request (requires md5 of "api_key{KEY}method{METHOD}token{TOKEN}{SECRET}")
API_SIG=$(printf "api_key%smethodauth.getSessiontoken%s%s" "$LASTFM_API_KEY" "$TOKEN" "$LASTFM_API_SECRET" | md5)

# Exchange token for session key
SESSION_RESPONSE=$(curl -s "https://ws.audioscrobbler.com/2.0/?method=auth.getSession&api_key=$LASTFM_API_KEY&token=$TOKEN&api_sig=$API_SIG&format=json")
LASTFM_SESSION_KEY=$(echo "$SESSION_RESPONSE" | grep -o '"key":"[^"]*"' | cut -d'"' -f4)

if [ -z "$LASTFM_SESSION_KEY" ]; then
  echo --- Failed to get Last.fm session key. Did you authorize the app?
  echo --- Response: "$SESSION_RESPONSE"
  exit 1
fi

echo --- Got Last.fm session key!

echo --- Copy launch agent plist
mkdir ~/Library/LaunchAgents/ || true
cp -f scripts/moe.yuru.music-rpc.plist ~/Library/LaunchAgents/
echo --- Edit launch agent plist
# /usr/bin is for osascript
plutil -replace EnvironmentVariables.PATH -string "$DENO_PATH_DIR:/usr/bin" ~/Library/LaunchAgents/moe.yuru.music-rpc.plist
plutil -replace WorkingDirectory -string "$(pwd)" ~/Library/LaunchAgents/moe.yuru.music-rpc.plist
plutil -replace EnvironmentVariables.LASTFM_API_KEY -string "$LASTFM_API_KEY" ~/Library/LaunchAgents/moe.yuru.music-rpc.plist
plutil -replace EnvironmentVariables.LASTFM_API_SECRET -string "$LASTFM_API_SECRET" ~/Library/LaunchAgents/moe.yuru.music-rpc.plist
plutil -replace EnvironmentVariables.LASTFM_SESSION_KEY -string "$LASTFM_SESSION_KEY" ~/Library/LaunchAgents/moe.yuru.music-rpc.plist
echo --- Load launch agent
launchctl load ~/Library/LaunchAgents/moe.yuru.music-rpc.plist
echo --- INSTALL SUCCESS
