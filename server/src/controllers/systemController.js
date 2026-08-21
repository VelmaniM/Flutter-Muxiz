const mongoose = require('mongoose');
const Song = require('../models/Song');
const Artist = require('../models/Artist');
const Album = require('../models/Album');
const User = require('../models/User');
const LocalStore = require('../models/store');
const SyncService = require('../services/syncService');
const { FOLDER_ID } = require('../config/googleDrive');

class SystemController {
  /**
   * GET /api/v1/system/health
   */
  static async getHealth(req, res) {
    const isDbConnected = mongoose.connection.readyState === 1;
    res.json({
      status: 'UP',
      timestamp: new Date().toISOString(),
      database: isDbConnected ? 'CONNECTED' : 'DISCONNECTED',
      vault: 'GOOGLE_DRIVE_5TB',
      uptime: process.uptime(),
    });
  }

  /**
   * GET /api/v1/system/metrics
   * Comprehensive telemetry for React Minimalist Studio Console
   */
  static async getMetrics(req, res, next) {
    try {
      const isDbConnected = mongoose.connection.readyState === 1;
      let songCount = 0;
      let artistCount = 0;
      let albumCount = 0;
      let userCount = 0;

      if (isDbConnected) {
        [songCount, artistCount, albumCount, userCount] = await Promise.all([
          Song.countDocuments({ status: 'PUBLISHED' }),
          Artist.countDocuments(),
          Album.countDocuments(),
          User.countDocuments(),
        ]);
      } else {
        const localSongs = LocalStore.getLocalSongs();
        const activeSongs = localSongs.filter((s) => s.status !== 'DELETED');
        songCount = activeSongs.length;
        artistCount = new Set(activeSongs.map((s) => s.artistName || s.artist)).size;
        albumCount = new Set(activeSongs.map((s) => s.movieName || s.albumName)).size;
        userCount = LocalStore.getLocalUsers().length;
      }

      const syncData = await SyncService.getCurrentEpoch();

      res.json({
        success: true,
        metrics: {
          songs: songCount,
          artists: artistCount,
          albums: albumCount,
          users: userCount,
          cacheEpoch: syncData.epoch,
          lastSync: syncData.updatedAt,
          dbStatus: isDbConnected ? 'ONLINE' : 'LOCAL VAULT READY',
          vaultStatus: '5TB VAULT ACTIVE',
          folderId: FOLDER_ID,
          serverUptime: Math.round(process.uptime()),
          nodeVersion: process.version,
          memoryUsageMB: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
        },
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = SystemController;
