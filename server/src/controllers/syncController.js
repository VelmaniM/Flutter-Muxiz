const SyncService = require('../services/syncService');
const Song = require('../models/Song');

class SyncController {
  /**
   * GET /api/v1/sync
   * Heartbeat & Cache Epoch status endpoint for Flutter Mobile App & Studio
   */
  static async getSyncStatus(req, res, next) {
    try {
      const syncInfo = await SyncService.getCurrentEpoch();
      res.json(syncInfo);
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/sync/wipe
   * Force Purge All Mobile App Caches & Bump Epoch
   */
  static async wipeAllCache(req, res, next) {
    try {
      const { reason } = req.body;
      const result = await SyncService.bumpEpoch(
        'PURGE_ALL',
        reason || 'Admin Remote Full Cache Invalidation'
      );
      res.json({
        success: true,
        message: 'Global Mobile Cache Purge triggered successfully!',
        epoch: result.epoch,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/sync/wipe-catalog
   * Wipes all songs, artists, albums and vaults from database and storage
   */
  static async wipeCatalog(req, res, next) {
    try {
      const Artist = require('../models/Artist');
      const Album = require('../models/Album');
      const LocalStore = require('../models/store');
      const fs = require('fs');
      const path = require('path');

      // 1. Wipe DB docs if connected
      try {
        await Promise.all([
          Song.deleteMany({}),
          Artist.deleteMany({}),
          Album.deleteMany({}),
        ]);
      } catch (_) {}

      // 2. Wipe local store files
      LocalStore.saveLocalSongs([]);
      LocalStore.saveLocalUsers([]);

      // 3. Clear vault directory
      const vaultDir = path.join(__dirname, '../../data/vault');
      if (fs.existsSync(vaultDir)) {
        const files = fs.readdirSync(vaultDir);
        for (const file of files) {
          try {
            fs.unlinkSync(path.join(vaultDir, file));
          } catch (_) {}
        }
      }

      const result = await SyncService.bumpEpoch('PURGE_ALL', 'Admin Catalog Full Clean Wipe');
      res.json({
        success: true,
        message: 'All song records, artists, albums, and storage vaults wiped clean.',
        epoch: result.epoch,
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = SyncController;
