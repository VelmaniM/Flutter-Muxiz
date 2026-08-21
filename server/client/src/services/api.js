const BASE_URL = '';

export const api = {
  // Songs
  async getSongs(params = {}) {
    const query = new URLSearchParams(params).toString();
    const res = await fetch(`/api/v1/songs?${query}`);
    return res.json();
  },

  async updateSong(id, data) {
    const res = await fetch(`/api/v1/songs/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    return res.json();
  },

  async deleteSong(id, hard = false) {
    const res = await fetch(`/api/v1/songs/${id}?hard=${hard}`, {
      method: 'DELETE',
    });
    return res.json();
  },

  async deleteAlbum(albumName) {
    const res = await fetch(`/api/v1/songs/album/${encodeURIComponent(albumName)}`, {
      method: 'DELETE',
    });
    return res.json();
  },

  async deleteArtist(artistName) {
    const res = await fetch(`/api/v1/songs/artist/${encodeURIComponent(artistName)}`, {
      method: 'DELETE',
    });
    return res.json();
  },

  // Artists
  async getArtists(params = {}) {
    const query = new URLSearchParams(params).toString();
    const res = await fetch(`/api/v1/artists?${query}`);
    return res.json();
  },

  async createArtist(data) {
    const res = await fetch('/api/v1/artists', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    return res.json();
  },

  async updateArtist(id, data) {
    const res = await fetch(`/api/v1/artists/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    return res.json();
  },

  // Users
  async getUsers(params = {}) {
    const query = new URLSearchParams(params).toString();
    const res = await fetch(`/api/v1/users?${query}`);
    return res.json();
  },

  async createUser(data) {
    const res = await fetch('/api/v1/users', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    return res.json();
  },

  async updateUser(id, data) {
    const res = await fetch(`/api/v1/users/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    return res.json();
  },

  async deleteUser(id) {
    const res = await fetch(`/api/v1/users/${id}`, {
      method: 'DELETE',
    });
    return res.json();
  },

  // Uploads
  async createUploadSession(fileName, mimeType) {
    const res = await fetch('/api/v1/uploads/session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fileName, mimeType }),
    });
    return res.json();
  },

  async completeUpload(payload) {
    const res = await fetch('/api/v1/uploads/complete', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    return res.json();
  },

  async searchAppleMetadata(params) {
    if (typeof params === 'string') {
      const res = await fetch(`/api/v1/uploads/search-meta?query=${encodeURIComponent(params)}`);
      return res.json();
    }
    const queryParams = new URLSearchParams({
      query: params.query || params.rawFilename || '',
      title: params.title || '',
      artist: params.artist || params.artistName || '',
      album: params.album || params.movieName || params.albumName || '',
      duration: params.duration || '',
    }).toString();
    const res = await fetch(`/api/v1/uploads/search-meta?${queryParams}`);
    return res.json();
  },

  // Sync & Epoch
  async getSyncStatus() {
    const res = await fetch('/api/v1/sync');
    return res.json();
  },

  async wipeAppCache(reason) {
    const res = await fetch('/api/v1/sync/wipe', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ reason }),
    });
    return res.json();
  },

  async wipeCatalog() {
    const res = await fetch('/api/v1/sync/wipe-catalog', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    });
    return res.json();
  },

  // System
  async getMetrics() {
    const res = await fetch('/api/v1/system/metrics');
    return res.json();
  },
};
