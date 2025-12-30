#!/bin/bash

set -e

# This script updates the site/script.js file with actual credentials from .app-credentials
# Run this after deploying with deploy.sh

if [ ! -f ".app-credentials" ]; then
  echo "Error: .app-credentials file not found"
  echo "Please run ./scripts/deploy.sh first"
  exit 1
fi

source .app-credentials

if [ -z "$APP_ID" ]; then
  echo "Error: APP_ID not found in .app-credentials"
  exit 1
fi

echo "Updating site/script.js with credentials..."
echo "  APP_ID: $APP_ID"

# Update APP_ID in script.js
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  sed -i '' "s/const APP_ID = '.*';/const APP_ID = '$APP_ID';/" site/script.js
else
  # Linux
  sed -i "s/const APP_ID = '.*';/const APP_ID = '$APP_ID';/" site/script.js
fi

# Update FUNCTION_IDS if they exist
if [ -n "$LIST_MESSAGES_ID" ] && [ -n "$GET_MESSAGE_ID" ] && [ -n "$SEND_MESSAGE_ID" ]; then
  echo "  LIST_MESSAGES_ID: $LIST_MESSAGES_ID"
  echo "  GET_MESSAGE_ID: $GET_MESSAGE_ID"
  echo "  SEND_MESSAGE_ID: $SEND_MESSAGE_ID"

  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - need to handle multiline replacement differently
    sed -i '' "/const FUNCTION_IDS = {/,/};/c\\
const FUNCTION_IDS = {\\
  listMessages: '$LIST_MESSAGES_ID',\\
  getMessage: '$GET_MESSAGE_ID',\\
  sendMessage: '$SEND_MESSAGE_ID'\\
};
" site/script.js
  else
    # Linux
    sed -i "/const FUNCTION_IDS = {/,/};/c\\const FUNCTION_IDS = {\n  listMessages: '$LIST_MESSAGES_ID',\n  getMessage: '$GET_MESSAGE_ID',\n  sendMessage: '$SEND_MESSAGE_ID'\n};" site/script.js
  fi
fi

echo "✓ Configuration updated successfully"
echo ""
