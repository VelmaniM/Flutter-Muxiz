const mongoose = require('mongoose');

const SongSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    artistName: {
      type: String,
      required: true,
      trim: true,
      index: true,
      default: 'Unknown Artist',
    },
    movieName: {
      type: String,
      trim: true,
      index: true,
      default: 'Single',
    },
    albumName: {
      type: String,
      trim: true,
      index: true,
      default: 'Single',
    },
    genre: {
      type: String,
      default: 'Tamil · Melody',
      trim: true,
    },
    language: {
      type: String,
      default: 'Tamil',
      trim: true,
      index: true,
    },
    duration: {
      type: Number,
      default: 240, // duration in seconds
    },
    artworkUrl: {
      type: String,
      default: '',
    },
    storage: {
      provider: {
        type: String,
        enum: ['GOOGLE_DRIVE', 'LOCAL_VAULT', 'DIRECT_URL'],
        default: 'GOOGLE_DRIVE',
      },
      fileId: {
        type: String,
        trim: true,
      },
      directStreamUrl: {
        type: String,
        required: true,
      },
      fileSize: {
        type: Number,
        default: 0,
      },
      mimeType: {
        type: String,
        default: 'audio/mpeg',
      },
    },
    status: {
      type: String,
      enum: ['DRAFT', 'PUBLISHED', 'UNPUBLISHED', 'DELETED'],
      default: 'PUBLISHED',
      index: true,
    },
    playCount: {
      type: Number,
      default: 0,
    },
    likesCount: {
      type: Number,
      default: 0,
    },
    artistId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Artist',
      default: null,
    },
    albumId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Album',
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

// High-speed Compound Text Index for Instant Search across 5M Songs
SongSchema.index({
  title: 'text',
  artistName: 'text',
  movieName: 'text',
  albumName: 'text',
  genre: 'text',
});

module.exports = mongoose.models.Song || mongoose.model('Song', SongSchema);
