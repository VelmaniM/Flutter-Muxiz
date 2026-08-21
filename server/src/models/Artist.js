const mongoose = require('mongoose');

const ArtistSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      index: true,
    },
    bio: {
      type: String,
      default: 'Celebrated Tamil Artist on Muxiz.',
    },
    imageUrl: {
      type: String,
      default: '',
    },
    popularTracksCount: {
      type: Number,
      default: 0,
    },
    monthlyListeners: {
      type: Number,
      default: 1000,
    },
    isVerified: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.models.Artist || mongoose.model('Artist', ArtistSchema);
