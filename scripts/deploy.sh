#!/bin/bash

set -e

rm -f .app-credentials

# Configuration - no need to change
BUCKET_NAME="inbox-bucket"
TABLE_NAME="inbox-messages"
APP_NAME="inbox-app"

# Set this to the value of your domain
SITE_BASE_URL="http://localhost:3000"

echo "Setting up MolnOS Inbox infrastructure..."
echo ""

echo "Creating Application Registration..."

# Check if app already exists
APPS_LIST=$(molnos apps list 2>&1 | grep -o '{.*}')
EXISTING_APP_ID=$(echo "$APPS_LIST" | node -e "
const data = JSON.parse(require('fs').readFileSync(0, 'utf-8'));
const app = data.applications?.find(a => a.name === '$APP_NAME');
console.log(app?.id || '');
")

if [ -n "$EXISTING_APP_ID" ]; then
  echo "Application '$APP_NAME' already exists with ID: $EXISTING_APP_ID"
  APP_ID="$EXISTING_APP_ID"
else
  APP_RESPONSE=$(molnos apps create "$APP_NAME" \
    "MolnOS Inbox Application" \
    "$SITE_BASE_URL/sites/projects/abcd1234/auth-callback.html")

  # Extract application ID from response
  APP_ID=$(echo "$APP_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)

  if [ -z "$APP_ID" ]; then
    echo "Warning: Could not extract application ID from application creation response"
    echo "You may need to manually retrieve it using: molnos apps list"
  else
    echo "Application registered with application ID: $APP_ID"
  fi
fi

# Save to environment file
if [ -n "$APP_ID" ]; then
  echo "export APP_ID='$APP_ID'" > .app-credentials
  chmod 600 .app-credentials
fi
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

# Extract function IDs
echo "Extracting function IDs..."
FUNCTIONS_RESPONSE=$(molnos functions list 2>&1 | grep -o '{.*}')

# Use node to parse JSON properly
FUNCTION_IDS=$(echo "$FUNCTIONS_RESPONSE" | node -e "
const response = JSON.parse(require('fs').readFileSync(0, 'utf-8'));
const funcs = response.functions || [];
const list = funcs.find(f => f.name === 'get-message-list');
const get = funcs.find(f => f.name === 'get-message');
const post = funcs.find(f => f.name === 'post-message');
console.log(JSON.stringify({
  LIST_MESSAGES_ID: list?.id || '',
  GET_MESSAGE_ID: get?.id || '',
  SEND_MESSAGE_ID: post?.id || ''
}));
")

LIST_MESSAGES_ID=$(echo "$FUNCTION_IDS" | node -e "const data = JSON.parse(require('fs').readFileSync(0, 'utf-8')); console.log(data.LIST_MESSAGES_ID);")
GET_MESSAGE_ID=$(echo "$FUNCTION_IDS" | node -e "const data = JSON.parse(require('fs').readFileSync(0, 'utf-8')); console.log(data.GET_MESSAGE_ID);")
SEND_MESSAGE_ID=$(echo "$FUNCTION_IDS" | node -e "const data = JSON.parse(require('fs').readFileSync(0, 'utf-8')); console.log(data.SEND_MESSAGE_ID);")

if [ -n "$LIST_MESSAGES_ID" ]; then
  echo "get-message-list function ID: $LIST_MESSAGES_ID"
  echo "export LIST_MESSAGES_ID='$LIST_MESSAGES_ID'" >> .app-credentials
fi

if [ -n "$GET_MESSAGE_ID" ]; then
  echo "get-message function ID: $GET_MESSAGE_ID"
  echo "export GET_MESSAGE_ID='$GET_MESSAGE_ID'" >> .app-credentials
fi

if [ -n "$SEND_MESSAGE_ID" ]; then
  echo "post-message function ID: $SEND_MESSAGE_ID"
  echo "export SEND_MESSAGE_ID='$SEND_MESSAGE_ID'" >> .app-credentials
fi
echo ""

# Deploy static site
echo "Deploying static site..."

# Create JSON payload for site deployment
SITE_JSON=$(node -e "
const fs = require('fs');

const files = [
  { path: 'index.html', content: fs.readFileSync('site/index.html', 'base64') },
  { path: 'styles.css', content: fs.readFileSync('site/styles.css', 'base64') },
  { path: 'script.js', content: fs.readFileSync('site/script.js', 'base64') },
  { path: 'auth-callback.html', content: fs.readFileSync('site/auth-callback.html', 'base64') }
];

console.log(JSON.stringify({ files }));
")

SITE_RESPONSE=$(echo "$SITE_JSON" | molnos sites deploy - )

# Extract site/project ID
SITE_ID=$(echo "$SITE_RESPONSE" | grep -o '"projectId":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$SITE_ID" ]; then
  echo "Warning: Could not extract site ID from deployment response"
  echo "You may need to manually retrieve it using: molnos sites list"
else
  echo "Site deployed with ID: $SITE_ID"
  # Save to environment file
  echo "export SITE_ID='$SITE_ID'" >> .app-credentials

  # Update Application Registration with actual site ID in redirect URI
  if [ -n "$APP_ID" ]; then
    echo ""
    echo "Updating Application Registration redirect URI with actual site ID..."
    ACTUAL_REDIRECT_URI="$SITE_BASE_URL/sites/projects/$SITE_ID/auth-callback.html"
    molnos apps update "$APP_ID" \
      "{\"redirectUris\":[\"$ACTUAL_REDIRECT_URI\"]}" || echo "Warning: Failed to update redirect URI"
    echo "Redirect URI updated to: $ACTUAL_REDIRECT_URI"
  fi
fi

echo ""
echo "Updating site configuration with credentials..."
source .app-credentials
bash ./scripts/update-config.sh

echo ""
echo "Redeploying site with updated configuration..."
bash ./scripts/update.sh

echo ""
echo "=========================================="
echo "✓ Deployment complete!"
echo "=========================================="
echo ""
echo "All credentials saved to .app-credentials"
echo "  - APP_ID: $APP_ID"
echo "  - SITE_ID: $SITE_ID"
echo "  - LIST_MESSAGES_ID: $LIST_MESSAGES_ID"
echo "  - GET_MESSAGE_ID: $GET_MESSAGE_ID"
echo "  - SEND_MESSAGE_ID: $SEND_MESSAGE_ID"
echo ""
echo "Your inbox app is now live!"
echo ""
echo "Useful commands:"
echo "  molnos functions list  # View deployed functions"
echo "  molnos sites list      # View deployed sites"
echo "  molnos apps list       # View app registration"
echo ""
echo "To update your deployment later:"
echo "  source .app-credentials && ./scripts/update.sh"
echo ""
echo "To tear down all resources:"
echo "  source .app-credentials && ./scripts/teardown.sh"
echo ""