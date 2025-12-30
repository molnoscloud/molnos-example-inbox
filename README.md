# MolnOS Example: Inbox

This project demonstrates a simple messaging application: Inbox.

It is composed of a few common cloud primitives — adapted as needed — to work on [MolnOS](https://molnos.cloud).

The application allows you to privately read and write messages to other users on your MolnOS instance.

## Prerequisites

1. **MolnOS Core**: Install and start MolnOS Core ([documentation](https://molnos.cloud))
2. **MolnOS CLI**: The CLI should be available at `molnos` in this repository
3. **Authentication**: Set up authentication with `molnos auth configure`
4. **Node.js**: Required for building the functions (`npm install` to install dependencies)
5. **Services**: The following MolnOS services must be registered and running:
   - `databases` service (for PikoDB key-value storage)
   - `functions` service (for serverless functions)
   - `sites` service (for static site hosting)

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Set Up Infrastructure

Run the setup script to create all required infrastructure (database table, storage bucket, functions, and site):

```bash
./deploy.sh
```

This will:

- Create a storage bucket named `inbox-bucket`
- Create the `inbox-messages` database table
- Build and deploy all three serverless functions
- Deploy the static site

**Important:** Save the function IDs output by the setup script. You'll need them for updates.

### 3. Configure Environment Variables

After setup, export the function IDs for future updates:

```bash
export LIST_MESSAGES_ID='<id-from-setup>'
export GET_MESSAGE_ID='<id-from-setup>'
export SEND_MESSAGE_ID='<id-from-setup>'
```

### 4. Update Function IDs in Site

Update [site/script.js](site/script.js) with the function IDs from the setup output:

```javascript
const FUNCTION_IDS = {
  listMessages: 'your-list-function-id',
  getMessage: 'your-get-function-id',
  sendMessage: 'your-send-function-id'
};
```

### 5. Access the Application

The site is deployed and accessible via MolnOS:

```text
http://localhost:3000/sites/projects/abc12def/
```

## Management Scripts

This project includes three management scripts using the MolnOS CLI:

### Setup Script ([deploy.sh](deploy.sh))

Creates all infrastructure from scratch:

```bash
./deploy.sh
```

### Update Script ([update.sh](update.sh))

Updates functions and site after making code changes:

```bash
# Set function IDs first
export LIST_MESSAGES_ID='<id>'
export GET_MESSAGE_ID='<id>'
export SEND_MESSAGE_ID='<id>'

./update.sh
```

This will:

- Rebuild JavaScript functions
- Update all deployed functions
- Redeploy the static site

### Teardown Script ([teardown.sh](teardown.sh))

Removes all infrastructure:

```bash
# Optional: Set function IDs to delete functions
export LIST_MESSAGES_ID='<id>'
export GET_MESSAGE_ID='<id>'
export SEND_MESSAGE_ID='<id>'

./teardown.sh
```

## Project Structure

### Infrastructure Components

1. **Database Table**: `inbox-messages` - Stores all messages
2. **Storage Bucket**: `inbox-bucket` - For file storage
3. **Serverless Functions**: Three functions with database bindings
   - `get-message-list`: Lists all messages
   - `get-message`: Retrieves a specific message
   - `post-message`: Creates a new message
4. **Static Site**: `abc12def` - Frontend application

### File Structure

```text
.
├── functions/           # Source functions (ESM)
│   ├── get-message-list.mjs
│   ├── get-message.mjs
│   ├── post-message.mjs
│   └── config.mjs
├── dist/               # Built functions (created by build.mjs)
├── site/               # Static site files
│   ├── index.html
│   ├── script.js
│   └── styles.css
├── deploy.sh           # Infrastructure setup script
├── update.sh          # Update functions and site
├── teardown.sh        # Remove infrastructure
├── build.mjs          # Build script for functions
└── molnos-cli.sh      # MolnOS CLI tool
```

## Manual Operations (Advanced)

### Using MolnOS CLI Directly

All scripts use the MolnOS CLI. You can also use it directly:

```bash
# List functions
molnos functions list

# List database tables
molnos db tables

# List storage buckets
molnos storage buckets

# List deployed sites
molnos sites list
```

### Manual Function Deployment

If you prefer manual control:

```bash
# Build functions first
node build.mjs

# Deploy a function with bindings
molnos functions deploy "my-function" "dist/my-function.mjs" \
  --bindings='[{"service":"databases","permissions":[{"resource":"table","actions":["read","write"],"targets":["inbox-messages"]}]}]'

# Update a function
molnos functions update <function-id> "dist/my-function.mjs"
```

### Demo Mode

For testing without a backend, set demo mode in your browser console:

```javascript
localStorage.setItem('DEMO_DATA', 'true')
```

## Troubleshooting

### Function IDs Not Found

If you lose your function IDs:

```bash
molnos functions list
```

Then export them:

```bash
export LIST_MESSAGES_ID='<id>'
export GET_MESSAGE_ID='<id>'
export SEND_MESSAGE_ID='<id>'
```

### Authentication Issues

Make sure you're authenticated:

```bash
molnos auth status
molnos auth configure
```

### Site Not Loading

Check that the site is deployed:

```bash
molnos sites list
```

Verify function IDs in [site/script.js](site/script.js) match your deployed functions.
