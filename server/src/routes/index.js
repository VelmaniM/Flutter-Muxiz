const express = require('express');
const router = express.Router();

const songsRouter = require('./api/v1/songs');
const uploadsRouter = require('./api/v1/uploads');
const syncRouter = require('./api/v1/sync');
const systemRouter = require('./api/v1/system');
const artistsRouter = require('./api/v1/artists');
const usersRouter = require('./api/v1/users');

const SyncController = require('../controllers/syncController');

// API v1 Routing
router.use('/api/v1/songs', songsRouter);
router.use('/api/v1/uploads', uploadsRouter);
router.use('/api/v1/sync', syncRouter);
router.use('/api/v1/system', systemRouter);
router.use('/api/v1/artists', artistsRouter);
router.use('/api/v1/users', usersRouter);

// Flutter backward-compatibility aliases
router.use('/api/v1/songs/artists/all', artistsRouter);
router.use('/api/artists', artistsRouter);
router.use('/api/users', usersRouter);

// Aliases for root level Flutter compatibility
router.use('/api/songs', songsRouter);
router.use('/api/uploads', uploadsRouter);
router.use('/api/sync', syncRouter);
router.get(['/api/cache/epoch', '/cache/epoch', '/api/v1/cache/epoch'], SyncController.getSyncStatus);
router.use(['/api/server/status', '/api/v1/server/status', '/server/status'], (req, res) => res.json({ status: 'LIVE', isOnline: true, active: true }));
router.use(['/api/health', '/api/v1/health'], (req, res) => res.json({ status: 'UP' }));

// SSE Real-time Events Stream for Mobile Clients
router.get(['/api/server/events', '/api/v1/server/events', '/server/events'], (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  res.write('event: connected\ndata: {"status":"CONNECTED"}\n\n');

  // Register with SyncService for real-time instant broadcast
  const SyncService = require('../services/syncService');
  SyncService.addSSEClient(res);

  const keepAliveInterval = setInterval(() => {
    res.write('event: ping\ndata: {"time":"' + new Date().toISOString() + '"}\n\n');
  }, 25000);

  req.on('close', () => {
    clearInterval(keepAliveInterval);
  });
});

module.exports = router;
