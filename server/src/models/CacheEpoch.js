const mongoose = require('mongoose');

const CacheEpochSchema = new mongoose.Schema(
  {
    key: {
      type: String,
      default: 'GLOBAL_CACHE_EPOCH',
      unique: true,
    },
    epoch: {
      type: Number,
      required: true,
      default: () => Date.now(),
    },
    action: {
      type: String,
      enum: ['SYNC', 'PURGE_ALL', 'RELOAD_CATALOG'],
      default: 'SYNC',
    },
    reason: {
      type: String,
      default: 'Initial Server Boot',
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.models.CacheEpoch || mongoose.model('CacheEpoch', CacheEpochSchema);
