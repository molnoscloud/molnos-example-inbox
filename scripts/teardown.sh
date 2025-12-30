#!/bin/bash

set -e

# Configuration - no need to change
BUCKET_NAME="inbox-bucket"
TABLE_NAME="inbox-messages"

# Function and Site IDs - SET THESE VIA ENVIRONMENT VARIABLES
LIST_MESSAGES_ID="${LIST_MESSAGES_ID:-}"
GET_MESSAGE_ID="${GET_MESSAGE_ID:-}"
SEND_MESSAGE_ID="${SEND_MESSAGE_ID:-}"
SITE_ID="${SITE_ID:-}"

echo "Tearing down MolnOS Inbox infrastructure..."
echo ""

# Delete site
echo "Deleting static site: $SITE_ID"
molnos sites delete "$SITE_ID" || echo "Site may not exist"
echo ""

# Delete functions (if IDs are provided via environment variables)
if [ -n "$LIST_MESSAGES_ID" ]; then
  echo "Deleting function: get-message-list ($LIST_MESSAGES_ID)"
  molnos functions delete "$LIST_MESSAGES_ID" || echo "Function may not exist"
fi

if [ -n "$GET_MESSAGE_ID" ]; then
  echo "Deleting function: get-message ($GET_MESSAGE_ID)"
  molnos functions delete "$GET_MESSAGE_ID" || echo "Function may not exist"
fi

if [ -n "$SEND_MESSAGE_ID" ]; then
  echo "Deleting function: post-message ($SEND_MESSAGE_ID)"
  molnos functions delete "$SEND_MESSAGE_ID" || echo "Function may not exist"
fi

# If no function IDs were provided, list functions and prompt user
if [ -z "$LIST_MESSAGES_ID" ] && [ -z "$GET_MESSAGE_ID" ] && [ -z "$SEND_MESSAGE_ID" ]; then
  echo ""
  echo "No function IDs provided via environment variables."
  echo "To delete functions, first list them:"
  echo "  molnos functions list"
  echo ""
  echo "Then delete manually:"
  echo "  molnos functions delete <function-id>"
  echo ""
fi

echo ""

# Delete database table
echo "Deleting database table: $TABLE_NAME"
molnos db table delete "$TABLE_NAME" || echo "Table may not exist"
echo ""

# Delete storage bucket
echo "Deleting storage bucket: $BUCKET_NAME"
molnos storage bucket delete "$BUCKET_NAME" || echo "Bucket may not exist"
echo ""

echo "Teardown complete!"
