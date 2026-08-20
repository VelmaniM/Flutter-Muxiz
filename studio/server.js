const express = require('express');
const cors = require('cors');
const multer = require('multer');
const { google } = require('googleapis');
const { PrismaClient } = require('@prisma/client');
const path = require('path');
const fs = require('fs');
const { Readable } = require('stream');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
require('dotenv').config();

const app = express();
const prisma = new PrismaClient();
const PORT = process.env.STUDIO_PORT || process.env.PORT || 5001;
const JWT_SECRET = process.env.JWT_SECRET || 'muxiz_secure_jwt_secret_token_2026_super_safe';

// --- Server Online / Offline State Management ---
let serverActive = true;
const STATUS_FILE = path.join(__dirname, '.server_status.json');

try {
  if (fs.existsSync(STATUS_FILE)) {
    const raw = fs.readFileSync(STATUS_FILE, 'utf8');
    const parsed = JSON.parse(raw);
    if (typeof parsed.active === 'boolean') {
      serverActive = parsed.active;
    }
  }
} catch (_) {}

function saveServerState(active) {
  serverActive = active;
  try {
    fs.writeFileSync(STATUS_FILE, JSON.stringify({ active: serverActive, updatedAt: new Date().toISOString() }));
  } catch (_) {}
  broadcastServerEvent('server_status', {
    active: serverActive,
    status: serverActive ? 'ONLINE' : 'OFFLINE',
    timestamp: Date.now(),
  });
}

// --- Server-Sent Events (SSE) Real-Time Push ---
const sseClients = new Set();

function broadcastServerEvent(event, data) {
  const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
  for (const res of sseClients) {
    try {
      res.write(payload);
    } catch (_) {
      sseClients.delete(res);
    }
  }
}

app.use(cors({ origin: true, credentials: true }));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(express.static(path.join(__dirname, 'public')));

// Configure Multer for in-memory audio/image uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 100 * 1024 * 1024 }, // 100MB limit
});

// Configure Google Drive OAuth2 Client
function getDriveClient() {
  const auth = new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
    process.env.GOOGLE_REDIRECT_URI
  );
  auth.setCredentials({
    refresh_token: process.env.GOOGLE_DRIVE_REFRESH_TOKEN,
  });
  return google.drive({ version: 'v3', auth });
}

// Convert Buffer to Readable Stream
function bufferToStream(buffer) {
  const stream = new Readable();
  stream.push(buffer);
  stream.push(null);
  return stream;
}

// Sanitize string helper
function sanitize(str) {
  if (!str) return '';
  return str
    .replace(/\.(mp3|m4a|wav|flac|aac|ogg|opus)$/i, '')
    .replace(/https?:\/\/[^\s]+/gi, '')
    .replace(/www\.[^\s]+/gi, '')
    .replace(/(masstamilan|isaimini|starmusiq|tamiltunes|sensongs|kuttyweb|tamilwire)(\.(com|org|in|net|co|fun|cc|xyz))?/gi, '')
    .replace(/\[\s*(320kbps|128kbps|192kbps|256kbps|64kbps|kbps|vbr|lossless|cd-rip|flac|hq|hd|original|audio)\s*\]/gi, '')
    .replace(/\(\s*(320kbps|128kbps|192kbps|256kbps|64kbps|kbps|vbr|lossless|cd-rip|flac|hq|hd|original|audio)\s*\)/gi, '')
    .replace(/\[\s*\]/g, '')
    .replace(/\(\s*\)/g, '')
    .replace(/_/g, ' ')
    .replace(/\s+/g, ' ')
    .replace(/^[\s\-–—:._,]+|[\s\-–—:._,]+$/g, '')
    .trim();
}

// --- Server Status & Real-Time SSE Routes ---

// 1. Get Server Power & Health Status
app.get('/api/v1/server/status', async (req, res) => {
  try {
    const songCount = await prisma.song.count().catch(() => 0);
    res.json({
      success: true,
      active: serverActive,
      status: serverActive ? 'ONLINE' : 'OFFLINE',
      totalSongs: songCount,
      service: 'Muxiz Studio Engine',
      database: 'Connected (PostgreSQL)',
      storage: 'Google Drive Active',
      uptimeSeconds: Math.floor(process.uptime()),
      timestamp: Date.now(),
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// 2. Toggle or Set Server Power State
app.post('/api/v1/server/status', (req, res) => {
  const { active } = req.body;
  if (typeof active === 'boolean') {
    saveServerState(active);
  } else {
    saveServerState(!serverActive);
  }
  console.log(`📡 [Studio Server] Power state changed: ${serverActive ? '🟢 ONLINE (LIVE)' : '🔴 OFFLINE (STOPPED)'}`);
  res.json({
    success: true,
    active: serverActive,
    status: serverActive ? 'ONLINE' : 'OFFLINE',
    message: `Studio server is now ${serverActive ? 'ONLINE (Live)' : 'OFFLINE (Stopped)'}`,
    timestamp: Date.now(),
  });
});

app.post('/api/v1/server/toggle', (req, res) => {
  saveServerState(!serverActive);
  console.log(`📡 [Studio Server] Toggle state: ${serverActive ? '🟢 ONLINE (LIVE)' : '🔴 OFFLINE (STOPPED)'}`);
  res.json({
    success: true,
    active: serverActive,
    status: serverActive ? 'ONLINE' : 'OFFLINE',
    message: `Studio server toggled to ${serverActive ? 'ONLINE' : 'OFFLINE'}`,
    timestamp: Date.now(),
  });
});

// 3. Real-Time Server-Sent Events (SSE) Stream
app.get('/api/v1/server/events', async (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();

  sseClients.add(res);

  // Send immediate initial handshake
  const count = await prisma.song.count().catch(() => 0);
  res.write(`event: handshake\ndata: ${JSON.stringify({
    active: serverActive,
    status: serverActive ? 'ONLINE' : 'OFFLINE',
    totalSongs: count,
    timestamp: Date.now(),
  })}\n\n`);

  // Periodic heartbeat ping to keep connection alive
  const pingTimer = setInterval(() => {
    try {
      res.write(`event: ping\ndata: ${JSON.stringify({ timestamp: Date.now() })}\n\n`);
    } catch (_) {
      clearInterval(pingTimer);
      sseClients.delete(res);
    }
  }, 15000);

  req.on('close', () => {
    clearInterval(pingTimer);
    sseClients.delete(res);
  });
});

// --- Server Offline Guard Middleware ---
app.use((req, res, next) => {
  // Allow health, static dashboard, root, and server management routes even when stopped
  if (
    req.path === '/' ||
    req.path === '/studio' ||
    req.path === '/api/health' ||
    req.path.startsWith('/api/v1/server') ||
    req.path.endsWith('.html') ||
    req.path.endsWith('.css') ||
    req.path.endsWith('.js') ||
    req.path.endsWith('.png') ||
    req.path.endsWith('.ico') ||
    req.path.endsWith('.svg') ||
    req.path.endsWith('.jpg') ||
    req.path.endsWith('.webp')
  ) {
    return next();
  }

  // If server is toggled OFFLINE, block all song catalog and ingestion APIs with 503
  if (!serverActive) {
    return res.status(503).json({
      success: false,
      active: false,
      status: 'OFFLINE',
      message: 'Muxiz Studio Server is currently stopped/offline.',
      timestamp: new Date().toISOString(),
    });
  }

  next();
});

// --- Core API Routes ---

// Health & System Info
app.get('/api/health', async (req, res) => {
  try {
    const songCount = await prisma.song.count();
    res.json({
      status: 'ok',
      service: 'Muxiz Studio Server',
      database: 'Connected (PostgreSQL)',
      serverActive,
      totalSongs: songCount,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    res.status(500).json({ status: 'error', error: err.message });
  }
});

// Serve Studio Dashboard
app.get(['/', '/studio'], (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Songs Catalog API
app.get('/api/v1/songs', async (req, res) => {
  try {
    const { query, genre, artist, limit = 500, page = 1 } = req.query;
    const where = { status: 'active' };

    if (query) {
      where.OR = [
        { title: { contains: String(query), mode: 'insensitive' } },
        { artistName: { contains: String(query), mode: 'insensitive' } },
        { movieName: { contains: String(query), mode: 'insensitive' } },
        { albumName: { contains: String(query), mode: 'insensitive' } },
      ];
    }
    if (genre && genre !== 'All') {
      where.genre = { contains: String(genre), mode: 'insensitive' };
    }
    if (artist) {
      where.artistName = { contains: String(artist), mode: 'insensitive' };
    }

    let take = parseInt(limit, 10);
    if (!take || isNaN(take) || take <= 0) {
      take = 100000;
    }
    const skip = (Math.max(1, parseInt(page, 10)) - 1) * take;

    const [songs, total] = await Promise.all([
      prisma.song.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take,
        skip,
      }),
      prisma.song.count({ where }),
    ]);

    res.json({
      success: true,
      total,
      count: songs.length,
      data: songs,
      songs,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Direct Add Song (JSON)
app.post('/api/v1/songs', async (req, res) => {
  try {
    const { title, artistName, movieName, albumName, genre, language, artworkUrl, audioUrl, duration } = req.body;
    if (!title || !audioUrl) {
      return res.status(400).json({ success: false, message: 'Title and audioUrl are required.' });
    }

    const cleanTitle = sanitize(title);
    const cleanArtist = sanitize(artistName) || 'Unknown Artist';
    const cleanMovie = sanitize(movieName || albumName) || 'Single';

    let artistRecord = await prisma.artist.findFirst({
      where: { name: { equals: cleanArtist, mode: 'insensitive' } },
    });
    if (!artistRecord && cleanArtist !== 'Unknown Artist') {
      artistRecord = await prisma.artist.create({
        data: {
          name: cleanArtist,
          image: artworkUrl || null,
          bio: `Popular Tamil artist in Muxiz.`,
        },
      });
    }

    let albumRecord = null;
    if (cleanMovie && cleanMovie !== 'Single') {
      albumRecord = await prisma.album.findFirst({
        where: { title: { equals: cleanMovie, mode: 'insensitive' } },
      });
      if (!albumRecord) {
        albumRecord = await prisma.album.create({
          data: {
            title: cleanMovie,
            artistId: artistRecord?.id || null,
            artwork: artworkUrl || null,
          },
        });
      }
    }

    const savedSong = await prisma.song.create({
      data: {
        title: cleanTitle,
        artistName: cleanArtist,
        albumName: cleanMovie,
        movieName: cleanMovie,
        artistId: artistRecord?.id || null,
        albumId: albumRecord?.id || null,
        genre: genre || 'Tamil · Melody / Romantic',
        language: language || 'Tamil',
        audioUrl,
        artworkUrl: artworkUrl || null,
        duration: duration ? parseInt(duration, 10) : 180,
      },
    });

    const totalCount = await prisma.song.count();
    broadcastServerEvent('catalog_update', { action: 'add', song: savedSong, totalSongs: totalCount });

    res.status(201).json({
      success: true,
      message: `Song "${cleanTitle}" created successfully!`,
      song: savedSong,
      data: savedSong,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Upload Single Song with File to Google Drive & Save in DB
app.post(['/api/v1/uploads/song', '/api/uploads/song'], upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'Audio file is required.' });
    }

    const { title, artistName, movieName, albumName, genre, language, artworkUrl } = req.body;
    const cleanTitle = sanitize(title || req.file.originalname) || 'Untitled Track';
    const cleanArtist = sanitize(artistName) || 'Unknown Artist';
    const cleanMovie = sanitize(movieName || albumName) || 'Single';
    const cleanGenre = genre || 'Tamil · Melody / Romantic';
    const cleanLang = language || 'Tamil';

    // Upload to Google Drive
    const drive = getDriveClient();
    const folderId = process.env.GOOGLE_DRIVE_FOLDER_ID;

    const driveRes = await drive.files.create({
      requestBody: {
        name: `${cleanTitle}.mp3`,
        parents: folderId ? [folderId] : [],
        mimeType: req.file.mimetype || 'audio/mpeg',
      },
      media: {
        mimeType: req.file.mimetype || 'audio/mpeg',
        body: bufferToStream(req.file.buffer),
      },
      fields: 'id, name, webViewLink, webContentLink',
    });

    const fileId = driveRes.data.id;
    await drive.permissions.create({
      fileId,
      requestBody: { role: 'reader', type: 'anyone' },
    });

    const audioUrl = `https://drive.google.com/uc?export=download&id=${fileId}`;

    // Auto-create / Connect Artist Record in DB
    let artistRecord = await prisma.artist.findFirst({
      where: { name: { equals: cleanArtist, mode: 'insensitive' } },
    });
    if (!artistRecord && cleanArtist !== 'Unknown Artist') {
      artistRecord = await prisma.artist.create({
        data: {
          name: cleanArtist,
          image: artworkUrl || null,
          bio: `Popular Tamil artist with tracks in Muxiz.`,
        },
      });
    }

    // Auto-create / Connect Album Record in DB
    let albumRecord = null;
    if (cleanMovie && cleanMovie !== 'Single') {
      albumRecord = await prisma.album.findFirst({
        where: { title: { equals: cleanMovie, mode: 'insensitive' } },
      });
      if (!albumRecord) {
        albumRecord = await prisma.album.create({
          data: {
            title: cleanMovie,
            artistId: artistRecord?.id || null,
            artwork: artworkUrl || null,
          },
        });
      }
    }

    // Save Song in PostgreSQL Database
    const savedSong = await prisma.song.create({
      data: {
        title: cleanTitle,
        artistName: cleanArtist,
        albumName: cleanMovie,
        movieName: cleanMovie,
        artistId: artistRecord?.id || null,
        albumId: albumRecord?.id || null,
        genre: cleanGenre,
        language: cleanLang,
        audioUrl,
        artworkUrl: artworkUrl || null,
        driveFileId: fileId,
      },
    });

    const totalCount = await prisma.song.count();
    broadcastServerEvent('catalog_update', { action: 'upload', song: savedSong, totalSongs: totalCount });

    res.status(201).json({
      success: true,
      message: `Song "${cleanTitle}" uploaded successfully!`,
      song: savedSong,
      data: savedSong,
    });
  } catch (err) {
    console.error('Upload error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
});

// Upload Custom Artwork to Google Drive
app.post(['/api/v1/uploads/artwork', '/api/uploads/artwork'], upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'Image file required.' });
    }

    const drive = getDriveClient();
    const folderId = process.env.GOOGLE_DRIVE_FOLDER_ID;

    const driveRes = await drive.files.create({
      requestBody: {
        name: `cover_${Date.now()}.png`,
        parents: folderId ? [folderId] : [],
        mimeType: req.file.mimetype || 'image/png',
      },
      media: {
        mimeType: req.file.mimetype || 'image/png',
        body: bufferToStream(req.file.buffer),
      },
      fields: 'id',
    });

    const fileId = driveRes.data.id;
    await drive.permissions.create({
      fileId,
      requestBody: { role: 'reader', type: 'anyone' },
    });

    const artworkUrl = `https://lh3.googleusercontent.com/u/0/d/${fileId}=w600-h600`;
    res.json({ success: true, artworkUrl, fileId });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Upload Custom Artist Portrait
app.post(['/api/v1/uploads/artist-photo', '/api/uploads/artist-photo'], upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'Image file required.' });
    }

    const drive = getDriveClient();
    const folderId = process.env.GOOGLE_DRIVE_FOLDER_ID;

    const driveRes = await drive.files.create({
      requestBody: {
        name: `artist_${Date.now()}.png`,
        parents: folderId ? [folderId] : [],
        mimeType: req.file.mimetype || 'image/png',
      },
      media: {
        mimeType: req.file.mimetype || 'image/png',
        body: bufferToStream(req.file.buffer),
      },
      fields: 'id',
    });

    const fileId = driveRes.data.id;
    await drive.permissions.create({
      fileId,
      requestBody: { role: 'reader', type: 'anyone' },
    });

    const imageUrl = `https://lh3.googleusercontent.com/u/0/d/${fileId}=w600-h600`;
    res.json({ success: true, imageUrl, fileId });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Update Song in Database
app.put('/api/v1/songs/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { title, artistName, movieName, albumName, genre, language, artworkUrl } = req.body;

    const updated = await prisma.song.update({
      where: { id },
      data: {
        title: sanitize(title),
        artistName: sanitize(artistName),
        movieName: sanitize(movieName || albumName),
        albumName: sanitize(albumName || movieName),
        genre,
        language,
        artworkUrl,
      },
    });

    broadcastServerEvent('catalog_update', { action: 'update', song: updated });

    res.json({ success: true, message: 'Song updated successfully!', song: updated });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Delete Song from Database & Google Drive
app.delete('/api/v1/songs/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const song = await prisma.song.findUnique({ where: { id } });
    if (song && song.driveFileId) {
      try {
        const drive = getDriveClient();
        await drive.files.delete({ fileId: song.driveFileId });
      } catch (_) {}
    }

    await prisma.song.delete({ where: { id } });
    const totalCount = await prisma.song.count();
    broadcastServerEvent('catalog_update', { action: 'delete', songId: id, totalSongs: totalCount });

    res.json({ success: true, message: 'Song deleted successfully!' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// All Artists Discography API (Single Individual Artists, Normalized & Strictly Deduplicated)
app.get('/api/v1/songs/artists/all', async (req, res) => {
  try {
    const allSongs = await prisma.song.findMany({
      select: {
        id: true,
        title: true,
        artistName: true,
        albumName: true,
        movieName: true,
        artworkUrl: true,
        audioUrl: true,
        genre: true,
        duration: true,
      },
    });

    const artistMap = new Map();

    const normalizeArtist = (raw) => {
      if (!raw) return '';
      let clean = raw
        .replace(/(masstamilan|isaimini|starmusiq|tamiltunes|sensongs|kuttyweb|tamilwire)(\.(com|org|in|net|co|fun|cc|xyz))?/gi, '')
        .replace(/\b(masstamilan|isaimini|starmusiq|tamiltunes|sensongs|kuttyweb|tamilwire)\b/gi, '')
        .replace(/^[\s\-–—:._,]+|[\s\-–—:._,]+$/g, '')
        .trim();
      return clean;
    };

    const extractArtists = (raw) => {
      if (!raw) return [];
      const parts = raw
        .replace(/\s+(feat\.|ft\.|featuring|with|x|\/)\s+/gi, ', ')
        .replace(/\s+&\s+/g, ', ')
        .split(/[,;]/);

      const list = [];
      const seen = new Set();
      for (const p of parts) {
        const norm = normalizeArtist(p);
        if (norm && norm.length >= 2) {
          const lower = norm.toLowerCase();
          if (!['unknown artist', 'various artists', 'masstamilan', 'unknown'].includes(lower) && !seen.has(lower)) {
            seen.add(lower);
            list.push(norm);
          }
        }
      }
      return list.length > 0 ? list : [normalizeArtist(raw) || 'Unknown Artist'];
    };

    allSongs.forEach((song) => {
      const individualArtists = extractArtists(song.artistName);
      individualArtists.forEach((name) => {
        const key = name.toLowerCase().replace(/[^a-z0-9]/g, '');
        if (!key || key === 'unknownartist' || key === 'variousartists') return;

        if (!artistMap.has(key)) {
          artistMap.set(key, {
            id: name.toLowerCase().replace(/[^a-z0-9]/g, '_'),
            name: name,
            image: song.artworkUrl || '',
            artwork: song.artworkUrl || '',
            songCount: 1,
            songs: [song],
          });
        } else {
          const existing = artistMap.get(key);
          if (!existing.songs.some((s) => s.id === song.id)) {
            existing.songs.push(song);
            existing.songCount = existing.songs.length;
          }
          if ((!existing.image || existing.image.includes('fallback')) && song.artworkUrl) {
            existing.image = song.artworkUrl;
            existing.artwork = song.artworkUrl;
          }
        }
      });
    });

    const uniqueArtists = Array.from(artistMap.values()).sort((a, b) => b.songCount - a.songCount);

    res.json(uniqueArtists);
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// --- Remote App Cache & LocalStorage Purge Signal ---
let globalAppCacheEpoch = Date.now();

app.post(['/api/v1/cache/wipe-app-storage', '/api/v1/cache/flush', '/api/v1/songs/cache/clear'], (req, res) => {
  const target = req.body?.target || 'all';
  globalAppCacheEpoch = Date.now();

  // Broadcast immediate real-time SSE signal to all connected mobile & desktop apps
  broadcastServerEvent('app_cache_wipe', {
    action: 'WIPE_ALL',
    target,
    epoch: globalAppCacheEpoch,
    timestamp: Date.now(),
  });

  // Also broadcast fresh catalog update signal
  broadcastServerEvent('catalog_update', {
    timestamp: Date.now(),
  });

  return res.json({
    success: true,
    message: 'Instant Remote App Cache & Local Storage Wipe broadcasted to all connected apps!',
    target,
    epoch: globalAppCacheEpoch,
    connectedApps: sseClients.size,
    timestamp: new Date().toISOString(),
  });
});

app.get(['/api/v1/cache/epoch', '/api/v1/cache/status'], (req, res) => {
  return res.json({
    success: true,
    epoch: globalAppCacheEpoch,
    connectedApps: sseClients.size,
    serverActive,
    timestamp: Date.now(),
  });
});

// --- SQL User Authentication Engine (JWT + PostgreSQL + Google OAuth) ---
function generateJwtToken(user) {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      authProvider: user.authProvider,
    },
    JWT_SECRET,
    { expiresIn: '30d' }
  );
}

async function hashPassword(password) {
  return await bcrypt.hash(password, 10);
}

async function verifyPassword(password, storedHash) {
  if (!storedHash) return false;
  try {
    if (storedHash.startsWith('$2a$') || storedHash.startsWith('$2b$') || storedHash.startsWith('$2y$')) {
      return await bcrypt.compare(password, storedHash);
    }
  } catch (_) {}
  // Backward compatibility with legacy sha256 hashes
  const sha = crypto.createHash('sha256').update(password).digest('hex');
  return sha === storedHash;
}

// 1. Google Authentication & PostgreSQL Sync
app.post(['/api/v1/auth/google', '/api/auth/google'], async (req, res) => {
  try {
    const { email, displayName, avatar } = req.body;
    if (!email) {
      return res.status(400).json({ success: false, error: 'Valid Gmail address is required for Google Sign-In' });
    }

    const cleanEmail = email.trim().toLowerCase();
    let user = await prisma.user.findUnique({
      where: { email: cleanEmail },
    });

    let isNewUser = false;
    let finalAvatar = avatar;
    if (!finalAvatar || finalAvatar === 'emoji:🎧') {
      const nameForAvatar = (displayName && displayName.trim()) ? displayName.trim() : cleanEmail.split('@')[0];
      finalAvatar = `https://ui-avatars.com/api/?name=${encodeURIComponent(nameForAvatar)}&background=1DB954&color=ffffff&bold=true&size=256`;
    }

    if (!user) {
      // Register new Google user in PostgreSQL Database
      isNewUser = true;
      user = await prisma.user.create({
        data: {
          email: cleanEmail,
          displayName: (displayName && displayName.trim()) ? displayName.trim() : cleanEmail.split('@')[0],
          avatar: finalAvatar,
          authProvider: 'google',
        },
      });
      console.log(`[SQL Auth] Registered new Google User in PostgreSQL: ${cleanEmail} (ID: ${user.id})`);
    } else {
      // Existing user in PostgreSQL DB - update profile
      const updateData = {};
      if (finalAvatar && finalAvatar !== user.avatar) {
        updateData.avatar = finalAvatar;
      }
      if (displayName && displayName.trim() && displayName.trim() !== user.displayName) {
        updateData.displayName = displayName.trim();
      }
      if (Object.keys(updateData).length > 0) {
        user = await prisma.user.update({
          where: { email: cleanEmail },
          data: updateData,
        });
      }
      console.log(`[SQL Auth] Existing Google User validated from PostgreSQL: ${cleanEmail} (ID: ${user.id})`);
    }

    const token = generateJwtToken(user);
    return res.json({
      success: true,
      message: isNewUser ? 'New user registered and connected with Gmail!' : 'User validated successfully from SQL database!',
      isNewUser,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        avatar: user.avatar,
        authProvider: user.authProvider,
      },
      token,
    });
  } catch (err) {
    console.error('[SQL Auth] Google Error:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// 2. Email & Password Registration
app.post(['/api/v1/auth/register', '/api/auth/register'], async (req, res) => {
  try {
    const { email, password, displayName, avatar } = req.body;
    if (!email || !password) {
      return res.status(400).json({ success: false, error: 'Email and password are required' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const existing = await prisma.user.findUnique({
      where: { email: cleanEmail },
    });

    if (existing) {
      return res.status(409).json({
        success: false,
        error: 'An account with this email already exists in SQL database. Please log in.',
        userExists: true,
      });
    }

    const passwordHash = await hashPassword(password);
    let finalAvatar = avatar;
    if (!finalAvatar || finalAvatar === 'emoji:🎧') {
      const nameForAvatar = (displayName && displayName.trim()) ? displayName.trim() : cleanEmail.split('@')[0];
      finalAvatar = `https://ui-avatars.com/api/?name=${encodeURIComponent(nameForAvatar)}&background=1DB954&color=ffffff&bold=true&size=256`;
    }

    const user = await prisma.user.create({
      data: {
        email: cleanEmail,
        displayName: (displayName && displayName.trim()) ? displayName.trim() : cleanEmail.split('@')[0],
        avatar: finalAvatar,
        authProvider: 'local',
        passwordHash,
      },
    });

    console.log(`[SQL Auth] Created new local user in PostgreSQL: ${cleanEmail} (ID: ${user.id})`);
    const token = generateJwtToken(user);
    return res.json({
      success: true,
      message: 'Account created successfully in database!',
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        avatar: user.avatar,
        authProvider: user.authProvider,
      },
      token,
    });
  } catch (err) {
    console.error('[SQL Auth] Register Error:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// 3. Email & Password Login
app.post(['/api/v1/auth/login', '/api/auth/login'], async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ success: false, error: 'Email and password are required' });
    }

    const cleanEmail = email.trim().toLowerCase();
    const user = await prisma.user.findUnique({
      where: { email: cleanEmail },
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'No account found with this email in database. Please sign up.',
        notFound: true,
      });
    }

    const isMatch = await verifyPassword(password, user.passwordHash);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        error: 'Incorrect password. Please verify and try again.',
      });
    }

    console.log(`[SQL Auth] Logged in user from PostgreSQL: ${cleanEmail} (ID: ${user.id})`);
    const token = generateJwtToken(user);
    return res.json({
      success: true,
      message: 'Logged in successfully!',
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        avatar: user.avatar,
        authProvider: user.authProvider,
      },
      token,
    });
  } catch (err) {
    console.error('[SQL Auth] Login Error:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
});

// 4. Session & Token Validation (/me and /validate)
app.get(['/api/v1/auth/me', '/api/auth/me'], async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ success: false, error: 'Authorization token required' });
    }

    const token = authHeader.split(' ')[1];
    let decoded;
    try {
      decoded = jwt.verify(token, JWT_SECRET);
    } catch (_) {
      return res.status(401).json({ success: false, error: 'Invalid or expired token' });
    }

    const user = await prisma.user.findUnique({
      where: { id: decoded.id },
    });

    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found in database' });
    }

    return res.json({
      success: true,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        avatar: user.avatar,
        authProvider: user.authProvider,
      },
    });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

app.post(['/api/v1/auth/validate', '/api/auth/validate'], async (req, res) => {
  try {
    const { email, id, token } = req.body;

    if (token) {
      try {
        const decoded = jwt.verify(token, JWT_SECRET);
        const user = await prisma.user.findUnique({ where: { id: decoded.id } });
        if (user) {
          return res.json({
            success: true,
            valid: true,
            user: {
              id: user.id,
              email: user.email,
              displayName: user.displayName,
              avatar: user.avatar,
              authProvider: user.authProvider,
            },
          });
        }
      } catch (_) {}
    }

    if (!email && !id) {
      return res.status(400).json({ success: false, error: 'Email, ID or Token required' });
    }

    const user = await prisma.user.findFirst({
      where: {
        OR: [
          email ? { email: email.trim().toLowerCase() } : undefined,
          id ? { id } : undefined,
        ].filter(Boolean),
      },
    });

    if (!user) {
      return res.status(404).json({ success: false, valid: false, error: 'User does not exist in SQL database' });
    }

    return res.json({
      success: true,
      valid: true,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        avatar: user.avatar,
        authProvider: user.authProvider,
      },
    });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

// 5. Logout
app.post(['/api/v1/auth/logout', '/api/auth/logout'], (req, res) => {
  return res.json({ success: true, message: 'Session logged out successfully' });
});

// 6. User Accounts Management for Studio Dashboard
app.get(['/api/v1/users', '/api/users'], async (req, res) => {
  try {
    const users = await prisma.user.findMany({
      select: {
        id: true,
        email: true,
        displayName: true,
        avatar: true,
        authProvider: true,
        isPremium: true,
        createdAt: true,
        updatedAt: true,
        _count: {
          select: {
            playlists: true,
            favorites: true,
            listeningHistory: true,
          },
        },
      },
      orderBy: { updatedAt: 'desc' },
    });
    return res.json({ success: true, count: users.length, users });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

app.get(['/api/v1/users/:id', '/api/users/:id'], async (req, res) => {
  try {
    const { id } = req.params;
    const user = await prisma.user.findUnique({
      where: { id },
      include: {
        playlists: {
          select: {
            id: true,
            title: true,
            cover: true,
            createdAt: true,
            _count: { select: { songs: true } },
          },
          orderBy: { createdAt: 'desc' },
        },
        favorites: {
          include: {
            song: {
              select: {
                id: true,
                title: true,
                artistName: true,
                movieName: true,
                artworkUrl: true,
                duration: true,
              },
            },
          },
          orderBy: { createdAt: 'desc' },
          take: 20,
        },
        recentlyPlayed: {
          include: {
            song: {
              select: {
                id: true,
                title: true,
                artistName: true,
                movieName: true,
                artworkUrl: true,
              },
            },
          },
          orderBy: { playedAt: 'desc' },
          take: 10,
        },
      },
    });

    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found in database' });
    }

    return res.json({
      success: true,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        avatar: user.avatar,
        authProvider: user.authProvider,
        isPremium: user.isPremium,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
        playlists: user.playlists,
        favorites: user.favorites.map(f => f.song).filter(Boolean),
        recentlyPlayed: user.recentlyPlayed.map(r => r.song).filter(Boolean),
      },
    });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

app.delete(['/api/v1/users/:id', '/api/users/:id'], async (req, res) => {
  try {
    const { id } = req.params;
    await prisma.user.delete({ where: { id } });
    return res.json({ success: true, message: 'User deleted from PostgreSQL database' });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});

// Start Studio Server
app.listen(PORT, () => {
  console.log(`\n🎧 MUXIZ STUDIO ENGINE ACTIVE`);
  console.log(`📡 Local URL: http://localhost:${PORT}/studio`);
  console.log(`🌐 Network URL: http://192.168.1.94:${PORT}/studio`);
  console.log(`🎛️  Server Power State: ${serverActive ? '🟢 ONLINE (LIVE)' : '🔴 OFFLINE (STOPPED)'}`);
  console.log(`🗄️  Database: Connected to PostgreSQL`);
  console.log(`☁️  Storage: Connected to Google Drive\n`);
});
