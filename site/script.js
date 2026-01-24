/* Configuration */

// Set this to your MolnOS API root endpoint
const API_BASE_URL = 'http://localhost:3000';
const BUCKET_ID = 'inbox-bucket';

// TODO
const APP_ID = 'inboxapp';
const FUNCTION_IDS = {
  listMessages: 'getlstfn',
  getMessage: 'getmsgfn',
  sendMessage: 'pstmsgfn'
};

/* Demo Mode */

const DEMO_MODE = localStorage.getItem('DEMO_DATA') === 'true';

const DEMO_MESSAGES = [
  {
    id: 'demo-1',
    from: 'System',
    subject: 'Your inbox is private',
    body: 'This inbox runs locally on this machine.\n\nNo messages ever leave it.',
    date: '1984-01-24T09:00:00Z'
  },
  {
    id: 'demo-2',
    from: 'Alex',
    subject: 'Welcome',
    body: 'This is a personal inbox.\n\nIt belongs to you.',
    date: '1984-01-24T08:30:00Z'
  },
  {
    id: 'demo-3',
    from: 'Jamie',
    subject: 'Can you see this?',
    body: 'If you’re reading this, the system is working.',
    date: '1984-01-24T08:00:00Z'
  }
];

/* Views */

const signinView = document.getElementById('signinView');
const inboxView = document.getElementById('inboxView');
const messageView = document.getElementById('messageView');
const composeView = document.getElementById('composeView');
const signOutBtn = document.getElementById('signOutBtn');

function show(view) {
  [signinView, inboxView, messageView, composeView].forEach((v) => {
    v.classList.add('hidden');
  });
  view.classList.remove('hidden');

  // Show sign-out button only when not on signin view
  if (view === signinView) {
    signOutBtn.classList.add('hidden');
  } else {
    signOutBtn.classList.remove('hidden');
  }
}

/* Inbox */

const messageList = document.getElementById('messageList');

async function loadInbox() {
  let messages;

  if (DEMO_MODE) {
    messages = DEMO_MESSAGES;
  } else {
    try {
      const userEmail = api.userIdentity?.email;

      if (!userEmail) {
        console.error('User email not available');
        messages = [];
      } else {
        messages = await api.functions.run('listMessages', { userEmail });

        // Ensure messages is an array
        if (!Array.isArray(messages)) {
          console.error('Expected array of messages, got:', messages);
          messages = [];
        }
      }
    } catch (error) {
      console.error('Failed to load messages:', error);
      messages = [];
    }
  }

  messageList.innerHTML = '';

  if (messages.length === 0) {
    messageList.innerHTML = '<li class="empty-state">No messages yet</li>';
    return;
  }

  messages
    .sort((a, b) => new Date(b.date) - new Date(a.date))
    .forEach((msg) => {
      const li = document.createElement('li');
      li.innerHTML = `
        <div class="message-row">
          <div class="from">${msg.from || 'Unknown'}</div>
          <div class="subject">${msg.subject || '(No subject)'}</div>
          <div class="date">${new Date(msg.date).toLocaleDateString()}</div>
        </div>
      `;
      li.onclick = () => openMessage(msg.id);
      messageList.appendChild(li);
    });
}

/* Message view */

async function openMessage(id) {
  let msg;

  if (DEMO_MODE) {
    msg = DEMO_MESSAGES.find((m) => m.id === id);
  } else {
    try {
      const userEmail = api.userIdentity?.email;
      const response = await api.functions.run('getMessage', { id, userEmail });

      // Parse response if it's a JSON string
      if (typeof response === 'string') {
        try {
          msg = JSON.parse(response);
        } catch (parseError) {
          console.error('Failed to parse message response:', parseError);
          console.error('Response was:', response);
          return;
        }
      } else {
        msg = response;
      }
    } catch (error) {
      console.error('Failed to load message:', error);
      return;
    }
  }

  if (!msg) {
    console.error('Message not found:', id);
    return;
  }

  document.getElementById('msgFrom').textContent = msg.from || 'Unknown';
  document.getElementById('msgDate').textContent = new Date(
    msg.date
  ).toLocaleString();
  document.getElementById('msgSubject').textContent =
    msg.subject || '(No subject)';
  document.getElementById('msgBody').textContent = msg.body || '';

  // Display images if present
  const imagesContainer = document.getElementById('msgImages');
  imagesContainer.innerHTML = '';

  if (msg.images && msg.images.length > 0) {
    msg.images.forEach((imageKey) => {
      const img = document.createElement('img');
      img.src = api.storage.getImageUrl(BUCKET_ID, imageKey);
      img.alt = 'Message attachment';
      img.className = 'message-image';
      imagesContainer.appendChild(img);
    });
  }

  show(messageView);
}

/* Compose view */

let attachedImages = [];

document.getElementById('composeBtn').onclick = () => {
  show(composeView);
};

document.getElementById('cancelCompose').onclick = () => {
  attachedImages = [];
  document.getElementById('imagePreviews').innerHTML = '';
  show(inboxView);
};

signOutBtn.onclick = () => {
  if (confirm('Are you sure you want to sign out?')) {
    api.auth.logout();
  }
};

// Handle image selection
document.getElementById('imageInput').onchange = (e) => {
  const files = Array.from(e.target.files);

  files.forEach((file) => {
    if (!file.type.startsWith('image/')) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      const imageData = {
        file,
        dataUrl: event.target.result,
        name: file.name
      };

      attachedImages.push(imageData);
      renderImagePreviews();
    };
    reader.readAsDataURL(file);
  });

  e.target.value = '';
};

function renderImagePreviews() {
  const container = document.getElementById('imagePreviews');
  container.innerHTML = '';

  attachedImages.forEach((img, index) => {
    const preview = document.createElement('div');
    preview.className = 'image-preview';

    const imgEl = document.createElement('img');
    imgEl.src = img.dataUrl;
    imgEl.alt = img.name;

    const removeBtn = document.createElement('button');
    removeBtn.type = 'button';
    removeBtn.className = 'remove-image';
    removeBtn.innerHTML = '×';
    removeBtn.onclick = () => {
      attachedImages.splice(index, 1);
      renderImagePreviews();
    };

    preview.appendChild(imgEl);
    preview.appendChild(removeBtn);
    container.appendChild(preview);
  });
}

document.getElementById('composeForm').onsubmit = async (e) => {
  e.preventDefault();

  if (DEMO_MODE) {
    alert('Demo mode: messages are read-only.');
    return;
  }

  const uploadedImages = [];

  // Upload images to storage bucket
  if (attachedImages.length > 0) {
    for (const img of attachedImages) {
      const timestamp = Date.now();
      const randomId = Math.random().toString(36).substring(2, 9);
      const key = `messages/${timestamp}-${randomId}-${img.name}`;

      try {
        await api.storage.uploadImage(BUCKET_ID, key, img.file);
        uploadedImages.push(key);
      } catch (error) {
        console.error('Failed to upload image:', error);
      }
    }
  }

  const payload = {
    from: api.userIdentity?.email || 'Anonymous',
    to: document.getElementById('to').value,
    subject: document.getElementById('subject').value,
    body: document.getElementById('body').value,
    images: uploadedImages
  };

  await api.functions.run('sendMessage', payload);

  e.target.reset();
  attachedImages = [];
  document.getElementById('imagePreviews').innerHTML = '';
  show(inboxView);
  loadInbox();
};

/* Navigation */

document.getElementById('backToInbox').onclick = () => {
  show(inboxView);
};

/* Signin */

document.getElementById('signinForm').onsubmit = async (e) => {
  e.preventDefault();

  const email = document.getElementById('signinEmail').value;
  const errorEl = document.getElementById('signinError');
  const submitBtn = e.target.querySelector('button[type="submit"]');

  errorEl.classList.add('hidden');
  errorEl.textContent = '';
  errorEl.style.color = '';

  // Disable submit button
  submitBtn.disabled = true;
  submitBtn.textContent = 'Sending...';

  try {
    const result = await api.auth.signin(email);

    // Show success message
    errorEl.textContent =
      result.message || 'Check your email for a magic link to sign in!';
    errorEl.style.color = 'green';
    errorEl.classList.remove('hidden');

    // Reset form
    e.target.reset();
  } catch (error) {
    console.error('Signin failed:', error);
    errorEl.textContent = error.message || 'Sign in failed. Please try again.';
    errorEl.style.color = 'red';
    errorEl.classList.remove('hidden');
  } finally {
    // Re-enable submit button
    submitBtn.disabled = false;
    submitBtn.textContent = 'Sign In';
  }
};

/* API */

class API {
  constructor() {
    this.baseUrl = API_BASE_URL;
    this.token = null;
    this.refreshToken = null;
    this.userIdentity = null;
    this.auth.loadTokens();
  }

  /* Publicly exposed methods to call MolnOS endpoints */

  auth = {
    loadTokens: () => {
      this.token = localStorage.getItem('MolnOSToken');
      this.refreshToken = localStorage.getItem('MolnOSRefreshToken');
    },

    signin: async (email) => {
      // Construct redirect URL to our auth callback page
      const currentOrigin = window.location.origin;
      const currentPath = window.location.pathname;
      // Extract site path (everything up to and including the project ID)
      const sitePath = currentPath.substring(
        0,
        currentPath.lastIndexOf('/') + 1
      );
      const redirectUrl = `${currentOrigin}${sitePath}auth-callback.html`;

      const response = await fetch(`${this.baseUrl}/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          email,
          redirectUrl,
          applicationId: APP_ID
        })
      });

      if (!response.ok) {
        const error = await response.text();
        throw new Error(error || response.statusText);
      }

      const data = await response.json();

      // Show success message - user needs to check their email
      return data;
    },

    logout: () => {
      this.auth.clearTokens();
      // Redirect to signin
      window.location.href = 'index.html';
    },

    clearTokens: () => {
      this.token = null;
      this.refreshToken = null;
      localStorage.removeItem('MolnOSToken');
      localStorage.removeItem('MolnOSRefreshToken');
    }
  };

  identity = {
    /**
     * @description Get caller identity.
     */
    whoami: async () => {
      const identity = await this.request('/identity/whoami');
      // Extract email from metadata for easier access
      this.userIdentity = {
        ...identity,
        email: identity?.metadata?.email
      };
      return this.userIdentity;
    }
  };

  functions = {
    /**
     * @description Run a MolnOS serverless function.
     */
    run: async (functionName, payload = null) => {
      const functionId = FUNCTION_IDS[functionName];
      if (!functionId) throw new Error('Missing function ID to call!');

      const options = payload
        ? { method: 'POST', body: payload }
        : { method: 'GET' };

      return this.request(`/functions/run/${functionId}`, options);
    }
  };

  storage = {
    /**
     * @description Upload an image to storage bucket using multipart/form-data.
     */
    uploadImage: async (bucketName, key, file) => {
      const formData = new FormData();
      formData.append('key', key);
      formData.append('file', file);

      const headers = {
        Authorization: `Bearer ${this.token}`
      };
      // Don't set Content-Type - browser will set it with boundary for multipart/form-data

      const response = await fetch(
        `${this.baseUrl}/storage/buckets/${bucketName}/objects`,
        {
          method: 'PUT',
          headers,
          body: formData
        }
      );

      if (!response.ok) {
        const error = await response.text();
        throw new Error(error || response.statusText);
      }

      const contentType = response.headers.get('content-type');
      if (contentType?.includes('application/json')) {
        return await response.json();
      }

      return await response.text();
    },

    /**
     * @description Get image URL from bucket.
     */
    getImageUrl: (bucketName, key) => {
      return `${this.baseUrl}/storage/buckets/${bucketName}/objects/${encodeURIComponent(key)}`;
    }
  };

  /**
   * @description Sugared fetch/request handler.
   */
  async request(endpoint, options = {}, _isRetry = false) {
    const headers = {
      'Content-Type': 'application/json'
    };

    if (options.headers) {
      for (const [key, value] of Object.entries(options.headers)) {
        if (key.toLowerCase() !== 'authorization') {
          headers[key] = value;
        }
      }
    }

    headers.Authorization = `Bearer ${this.token}`;

    const config = {
      ...options,
      headers
    };

    if (config.body && typeof config.body === 'object') {
      config.body = JSON.stringify(config.body);
    }

    const response = await fetch(`${this.baseUrl}${endpoint}`, config);

    if (!response.ok) {
      const error = await response.text();
      throw new Error(error || response.statusText);
    }

    const contentType = response.headers.get('content-type');
    if (contentType?.includes('application/json')) {
      return await response.json();
    }

    return await response.text();
  }
}

/* Init */

const api = new API();

async function init() {
  if (!DEMO_MODE) {
    // Check if user has valid token
    if (!api.token) {
      show(signinView);
      return;
    }

    try {
      await api.identity.whoami();
      console.log('User identity loaded:', api.userIdentity);
    } catch (error) {
      console.error('Failed to fetch user identity:', error);
      // Clear invalid tokens and show signin
      api.auth.clearTokens();
      show(signinView);
      return;
    }
  }

  show(inboxView);
  await loadInbox();
}

init();
