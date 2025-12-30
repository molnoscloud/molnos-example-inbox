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

Run the setup script to create all required infrastructure:

```bash
./scripts/deploy.sh
```

This will:

- Create an **Application Registration** for OAuth authentication
- Create a storage bucket named `inbox-bucket`
- Create the `inbox-messages` database table
- Build and deploy all three serverless functions
- Deploy the static site with authentication callback page
- Save credentials to `.app-credentials` file

**Important:** The setup script will display your Application ID and save it to `.app-credentials`. Keep this file secure as it contains your authentication credentials.

### 3. Update Site Configuration

After deployment, update your site configuration with the Application ID:

```bash
./scripts/update-config.sh
```

This automatically updates [site/script.js](site/script.js) with your application credentials.

### 4. Update Function IDs and Redeploy

Update [site/script.js](site/script.js) with the function IDs from the setup output:

```javascript
const FUNCTION_IDS = {
  listMessages: 'your-list-function-id',
  getMessage: 'your-get-function-id',
  sendMessage: 'your-send-function-id'
};
```

Then redeploy the site with the updated configuration:

```bash
source .app-credentials
export LIST_MESSAGES_ID='<list-function-id>'
export GET_MESSAGE_ID='<get-function-id>'
export SEND_MESSAGE_ID='<send-function-id>'
./scripts/update.sh
```

### 5. Access the Application

The site is deployed and accessible via MolnOS:

```text
http://localhost:3000/sites/projects/abc12def/
```

## Authentication Flow

This application uses **MolnOS Application Registration** for secure authentication:

### How It Works

1. **Application Registration**: During deployment, the app registers with MolnOS Core with:
   - Application name: `inbox-app`
   - Redirect URI: Points to your deployed site's auth callback page
   - Application ID: Unique identifier for your application

2. **User Sign-In Flow**:
   - User enters email on the sign-in page
   - App calls `/auth/login` with email, redirect URL, and application ID
   - MolnOS sends a magic link to the user's email
   - User clicks the magic link
   - MolnOS verifies the token and redirects to your app's callback page with access tokens
   - Callback page stores tokens in localStorage and redirects to the main app

3. **Authenticated Requests**:
   - All API requests include the access token in the Authorization header
   - Tokens are automatically loaded from localStorage on page load

4. **Sign Out**:
   - User clicks "Sign out" button in the inbox header
   - App clears tokens from localStorage and redirects to sign-in page

### Security Features

- **No insecure CLI auth endpoint**: The old `/auth/login/cli` endpoint is removed
- **Application whitelisting**: Only registered applications can receive auth callbacks
- **Redirect URI validation**: MolnOS validates the redirect URL against registered URIs
- **Token-based sessions**: Access tokens expire and can be refreshed using refresh tokens
- **Secure storage**: Tokens are stored in browser localStorage (use HttpOnly cookies in production)

### Files

- [site/index.html](site/index.html) - Main app with sign-in form and sign-out button
- [site/auth-callback.html](site/auth-callback.html) - OAuth callback page that receives tokens
- [site/script.js](site/script.js) - Authentication logic and API client
- [scripts/deploy.sh](scripts/deploy.sh) - Creates Application Registration during deployment
- [scripts/teardown.sh](scripts/teardown.sh) - Deletes Application Registration during cleanup

## Management Scripts

This project includes management scripts in the `scripts/` directory:

### Setup Script ([scripts/deploy.sh](scripts/deploy.sh))

Creates all infrastructure from scratch:

```bash
./scripts/deploy.sh
```

### Config Update Script ([scripts/update-config.sh](scripts/update-config.sh))

Updates the site configuration with Application ID:

```bash
./scripts/update-config.sh
```

### Update Script ([scripts/update.sh](scripts/update.sh))

Updates functions and site after making code changes:

```bash
# Load credentials and set function IDs
source .app-credentials
export LIST_MESSAGES_ID='<id>'
export GET_MESSAGE_ID='<id>'
export SEND_MESSAGE_ID='<id>'

./scripts/update.sh
```

This will:

- Rebuild JavaScript functions
- Update all deployed functions
- Redeploy the static site

### Teardown Script ([scripts/teardown.sh](scripts/teardown.sh))

Removes all infrastructure:

```bash
# Load credentials and optionally set function IDs
source .app-credentials
export LIST_MESSAGES_ID='<id>'
export GET_MESSAGE_ID='<id>'
export SEND_MESSAGE_ID='<id>'

./scripts/teardown.sh
```

This will delete:

- Application Registration
- All deployed functions
- Static site
- Database table
- Storage bucket
- `.app-credentials` file

## Project Structure

### Infrastructure Components

1. **Application Registration**: `inbox-app` - OAuth application credentials
2. **Database Table**: `inbox-messages` - Stores all messages
3. **Storage Bucket**: `inbox-bucket` - For file storage
4. **Serverless Functions**: Three functions with database bindings
   - `get-message-list`: Lists all messages
   - `get-message`: Retrieves a specific message
   - `post-message`: Creates a new message
5. **Static Site**: Frontend application with auth callback

### File Structure

```text
.
├── functions/              # Source functions (ESM)
│   ├── get-message-list.mjs
│   ├── get-message.mjs
│   ├── post-message.mjs
│   └── config.mjs
├── dist/                  # Built functions (created by build.mjs)
├── site/                  # Static site files
│   ├── index.html         # Main app with sign-in/sign-out
│   ├── auth-callback.html # OAuth callback page
│   ├── script.js          # Application logic and auth
│   └── styles.css
├── scripts/               # Management scripts
│   ├── deploy.sh          # Infrastructure setup
│   ├── update.sh          # Update functions and site
│   ├── update-config.sh   # Update site config with credentials
│   ├── teardown.sh        # Remove infrastructure
│   └── build.mjs          # Build script for functions
├── .app-credentials       # Generated credentials (gitignored)
└── molnos-cli.sh         # MolnOS CLI tool
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

### Credentials Lost

If you lose your `.app-credentials` file:

```bash
# Get Application ID
molnos apps list

# Get Site ID
molnos sites list

# Get Function IDs
molnos functions list

# Recreate .app-credentials manually
cat > .app-credentials << EOF
export APP_ID='<your-client-id>'
export SITE_ID='<your-site-id>'
EOF
chmod 600 .app-credentials
```

### Authentication Flow Not Working

1. **Check Application Registration:**

   ```bash
   molnos apps list
   ```

   Verify your application is registered and has the correct redirect URI.

2. **Check Application ID in site:**

   Open [site/script.js](site/script.js) and verify `APP_ID` is set correctly.
   If not, run `./scripts/update-config.sh` to fix it.

3. **Verify Redirect URI:**
   The redirect URI must match exactly. Format: `http://localhost:3000/sites/projects/<SITE_ID>/auth-callback.html`

4. **Check Browser Console:**
   Open browser DevTools (F12) and check for JavaScript errors during sign-in or callback.

5. **Check Email:**
   Magic link should arrive within seconds. Check spam folder if needed.

### Site Not Loading

Check that the site is deployed:

```bash
molnos sites list
```

Verify function IDs in [site/script.js](site/script.js) match your deployed functions:

```bash
molnos functions list
```

### "Invalid or missing authentication" Errors

1. Clear browser localStorage and try signing in again:

   ```javascript
   // In browser console
   localStorage.clear()
   ```

2. Check if your access token expired. Sign out and sign in again.

3. Verify you're using the MolnOS API URL in [site/script.js](site/script.js):

   ```javascript
   const API_BASE_URL = 'http://localhost:3000';
   ```

### CLI Authentication Issues

For CLI operations (deploy, update, teardown):

```bash
molnos auth status
molnos auth configure
```
