#!/bin/bash

set -e

# Function and Site IDs - SET THESE VIA ENVIRONMENT VARIABLES
LIST_MESSAGES_ID="${LIST_MESSAGES_ID:-}"
GET_MESSAGE_ID="${GET_MESSAGE_ID:-}"
SEND_MESSAGE_ID="${SEND_MESSAGE_ID:-}"
SITE_ID="${SITE_ID:-}"

if [ -z "$LIST_MESSAGES_ID" ] || [ -z "$GET_MESSAGE_ID" ] || [ -z "$SEND_MESSAGE_ID" ]; then
  echo "Error: Function IDs not set"
  echo ""
  echo "Please set the following environment variables:"
  echo "  export LIST_MESSAGES_ID='<id>'"
  echo "  export GET_MESSAGE_ID='<id>'"
  echo "  export SEND_MESSAGE_ID='<id>'"
  echo ""
  echo "You can find these IDs by running:"
  echo "  molnos functions list"
  echo ""
  exit 1
fi

if [ -z "$SITE_ID" ] ; then
  echo "Error: Site ID not set"
  echo ""
  echo "Please set the following environment variables:"
  echo "  export SITE_ID='<id>'"
  echo ""
  echo "You can find this ID by running:"
  echo "  molnos sites list"
  echo ""
  exit 1
fi

echo "Updating MolnOS Inbox application..."
echo ""

# Build JavaScript functions
echo "Building JavaScript functions..."
node scripts/build.mjs
echo ""

# Update functions
echo "Updating serverless functions..."

update_function() {
  local name=$1
  local function_id=$2
  local file=$3

  echo "Updating $name (ID: $function_id)..."

  if molnos functions update "$function_id" "$file"; then
    echo "✓ $name updated successfully"
  else
    echo "✗ Failed to update $name"
    return 1
  fi
}

update_function "get-message-list" "$LIST_MESSAGES_ID" "dist/get-message-list.js"
update_function "get-message" "$GET_MESSAGE_ID" "dist/get-message.js"
update_function "post-message" "$SEND_MESSAGE_ID" "dist/post-message.js"

echo ""

# Update static site
echo "Updating static site: $SITE_ID"

# Create JSON payload for site deployment
SITE_JSON=$(node -e "
const fs = require('fs');

const files = [
  { path: 'index.html', content: fs.readFileSync('site/index.html', 'base64') },
  { path: 'styles.css', content: fs.readFileSync('site/styles.css', 'base64') },
  { path: 'script.js', content: fs.readFileSync('site/script.js', 'base64') }
];

console.log(JSON.stringify({ projectId: '$SITE_ID', files }));
")

echo "$SITE_JSON" | molnos sites deploy "$SITE_ID" -

echo ""
echo "Update complete!"
echo ""
echo "All functions and site have been updated successfully."
