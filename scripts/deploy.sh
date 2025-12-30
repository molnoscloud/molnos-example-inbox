#!/bin/bash

set -e

# Configuration - no need to change
BUCKET_NAME="inbox-bucket"
TABLE_NAME="inbox-messages"

echo "Setting up MolnOS Inbox infrastructure..."
echo ""

# Create storage bucket
echo "Creating storage bucket: $BUCKET_NAME"
molnos storage bucket create "$BUCKET_NAME" || echo "Bucket may already exist"
molnos storage bucket update "$BUCKET_NAME" public
echo ""

# Create database table
echo "Creating database table: $TABLE_NAME"
molnos db table create "$TABLE_NAME" || echo "Table may already exist"
echo ""

# Build JavaScript functions
echo "Building JavaScript functions..."
node scripts/build.mjs
echo ""

# Deploy functions
echo "Deploying serverless functions..."
echo ""

echo "Deploying get-message-list..."
molnos functions deploy "get-message-list" "dist/get-message-list.js" \
  --bindings='[{"service":"databases","permissions":[{"resource":"table","actions":["read","write"],"targets":["'"$TABLE_NAME"'"]}]}]'
echo ""

echo "Deploying get-message..."
molnos functions deploy "get-message" "dist/get-message.js" \
  --bindings='[{"service":"databases","permissions":[{"resource":"table","actions":["read","write"],"targets":["'"$TABLE_NAME"'"]}]}]'
echo ""

echo "Deploying post-message..."
molnos functions deploy "post-message" "dist/post-message.js" \
  --bindings='[{"service":"databases","permissions":[{"resource":"table","actions":["read","write"],"targets":["'"$TABLE_NAME"'"]}]}]'
echo ""

echo "✓ Functions deployed successfully"
echo ""

# Deploy static site
echo "Deploying static site..."

# Create JSON payload for site deployment
SITE_JSON=$(node -e "
const fs = require('fs');

const files = [
  { path: 'index.html', content: fs.readFileSync('site/index.html', 'base64') },
  { path: 'styles.css', content: fs.readFileSync('site/styles.css', 'base64') },
  { path: 'script.js', content: fs.readFileSync('site/script.js', 'base64') }
];

console.log(JSON.stringify({ files }));
")

echo "$SITE_JSON" | molnos sites deploy - || echo "Site may already exist"

echo ""
echo "Setup complete!"
echo ""
echo "To view deployed functions and their IDs, see above, or run:"
echo "  molnos functions list"
echo ""
echo "To view deployed sites and their IDs, see above, or run:"
echo "  molnos sites list"
echo ""
echo "To update functions later, use the update.sh script with environment variables:"
echo "  export LIST_MESSAGES_ID='<id>'"
echo "  export GET_MESSAGE_ID='<id>'"
echo "  export SEND_MESSAGE_ID='<id>'"
echo "  ./update.sh"
