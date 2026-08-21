const mongoose = require('mongoose');

const AlbumSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    artistId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Artist',
      default: null,
    },
    artistName: {
      type: String,
      default: 'Unknown Artist',
      trim: true,
    },
    artworkUrl: {
      type: String,
      default: '',
    },
    year: {
      type: Number,
      default: new Date().getFullYear(),
    },
    songsCount: {
      type: Number,
      default: 1,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.models.Album || mongoose.model('Album', AlbumSchema);
