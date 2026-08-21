const CacheEpoch = require('../models/CacheEpoch');
const Song = require('../models/Song');
const LocalStore = require('../models/store');
const mongoose = require('mongoose');

const sseClients = new Set();

class SyncService {
  /**
   * Register connected mobile SSE client
   */
  static addSSEClient(res) {
    sseClients.add(res);
    res.on('close', () => {
      sseClients.delete(res);
    });
  }

  /**
   * Broadcast real-time SSE event to all connected Flutter mobile apps
   */
  static broadcastSSE(event, data) {
    const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
    for (const client of sseClients) {
      try {
        client.write(payload);
      } catch (_) {
        sseClients.delete(client);
      }
    }
  }

  /**
   * Get current active epoch
   */
  static async getCurrentEpoch() {
    try {
      if (mongoose.connection.readyState === 1) {
        let record = await CacheEpoch.findOne({ key: 'GLOBAL_CACHE_EPOCH' });
        if (!record) {
          record = await CacheEpoch.create({
            key: 'GLOBAL_CACHE_EPOCH',
            epoch: Date.now(),
            action: 'SYNC',
            reason: 'Initial setup',
          });
        }
        const count = await Song.countDocuments({ status: 'PUBLISHED' });
        return {
          success: true,
          epoch: record.epoch,
          action: record.action,
          updatedAt: record.updatedAt,
          activeSongsCount: count,
        };
      } else {
        const local = LocalStore.getLocalEpoch();
        const songs = LocalStore.getLocalSongs();
        const activeSongs = songs.filter((s) => s.status !== 'DELETED');
        return {
          success: true,
          epoch: local.epoch || Date.now(),
          action: local.action || 'SYNC',
          updatedAt: new Date().toISOString(),
          activeSongsCount: activeSongs.length,
        };
      }
    } catch (err) {
      console.error('[SyncService getCurrentEpoch Error]', err.message);
      const local = LocalStore.getLocalEpoch();
      return {
        success: true,
        epoch: local.epoch || Date.now(),
        action: 'SYNC',
        activeSongsCount: 0,
      };
    }
  }

  /**
   * Bump epoch & broadcast instant event to mobile apps
   */
  static async bumpEpoch(action = 'SYNC', reason = 'Catalog Updated') {
    const newEpoch = Date.now();
    try {
      if (mongoose.connection.readyState === 1) {
        await CacheEpoch.findOneAndUpdate(
          { key: 'GLOBAL_CACHE_EPOCH' },
          { epoch: newEpoch, action, reason },
          { upsert: true, new: true }
        );
      } else {
        LocalStore.saveLocalEpoch({ epoch: newEpoch, action, reason });
      }

      console.log(`⚡ [SyncService] Global Cache Epoch bumped to: ${newEpoch} (${reason})`);

      // Invalidate Redis/In-Memory Cache
      try {
        const redisCache = require('./redisCacheService');
        await redisCache.flushAll();
      } catch (_) {}

      // Broadcast instant push event to all connected Flutter mobile devices
      const eventName = action === 'WIPE' ? 'app_cache_wipe' : 'catalog_update';
      this.broadcastSSE(eventName, {
        epoch: newEpoch,
        action,
        reason,
        timestamp: new Date().toISOString(),
      });

      return { success: true, epoch: newEpoch, action, reason };
    } catch (err) {
      console.error('[SyncService bumpEpoch Error]', err.message);
      LocalStore.saveLocalEpoch({ epoch: newEpoch, action, reason });
      return { success: true, epoch: newEpoch, action, reason };
    }
  }
}

module.exports = SyncService;
