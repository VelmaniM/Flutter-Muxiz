const Artist = require('../models/Artist');
const Song = require('../models/Song');
const LocalStore = require('../models/store');
const SyncService = require('../services/syncService');
const mongoose = require('mongoose');

class ArtistController {
  /**
   * Helper to normalize and canonicalize artist names
   */
  static canonicalizeName(name) {
    if (!name) return '';
    return name
      .replace(/\s+/g, ' ')
      .trim();
  }

  /**
   * GET /api/v1/artists
   * Aggregates and deduplicates all artists across the published catalog
   */
  static async getAllArtists(req, res, next) {
    try {
      const { search } = req.query;
      let artists = [];

      // Fetch all published songs from MongoDB or LocalStore
      let publishedSongs = [];
      let dbArtistDocs = [];

      if (mongoose.connection.readyState === 1) {
        [publishedSongs, dbArtistDocs] = await Promise.all([
          Song.find({ status: 'PUBLISHED' }).lean(),
          Artist.find().lean(),
        ]);
      } else {
        publishedSongs = LocalStore.getLocalSongs().filter((s) => s.status !== 'DELETED');
      }

      // Map for deduplicated artists: key = normalized lower case name
      const artistMap = new Map();

      // 1. Seed with registered Artist docs
      dbArtistDocs.forEach((doc) => {
        const canonical = ArtistController.canonicalizeName(doc.name);
        const key = canonical.toLowerCase();
        if (canonical && !artistMap.has(key)) {
          artistMap.set(key, {
            id: doc._id.toString(),
            _id: doc._id.toString(),
            name: canonical,
            imageUrl: doc.imageUrl || '',
            bio: doc.bio || '',
            songsCount: 0,
            monthlyListeners: doc.monthlyListeners || 5000,
            createdAt: doc.createdAt,
          });
        }
      });

      // 2. Scan all published songs and aggregate tracks under single canonical artists
      publishedSongs.forEach((song) => {
        const rawArtist = song.artistName || song.artist || 'Unknown Artist';
        // Split compound artists by comma, ampersand, 'feat.', 'ft.'
        const individualArtists = rawArtist
          .split(/,|&|\bfeat\.?\b|\bft\.?\b|\band\b/i)
          .map((n) => ArtistController.canonicalizeName(n))
          .filter((n) => n.length > 0 && n.toLowerCase() !== 'unknown artist');

        // If no valid split, use the raw string
        const artistsToProcess = individualArtists.length > 0 ? individualArtists : [ArtistController.canonicalizeName(rawArtist)];

        artistsToProcess.forEach((artistName) => {
          const key = artistName.toLowerCase();
          if (!artistMap.has(key)) {
            artistMap.set(key, {
              id: Math.random().toString(36).substring(2, 9),
              _id: Math.random().toString(36).substring(2, 9),
              name: artistName,
              imageUrl: song.artworkUrl || '',
              bio: '',
              songsCount: 0,
              monthlyListeners: 2400,
            });
          }

          const existing = artistMap.get(key);
          existing.songsCount += 1;
          // If artist has no portrait yet, use the song's Apple Music cover art as profile photo
          if (!existing.imageUrl && song.artworkUrl) {
            existing.imageUrl = song.artworkUrl;
          }
        });
      });

      artists = Array.from(artistMap.values());

      // Filter by search query if present
      if (search) {
        const sLower = search.toLowerCase();
        artists = artists.filter((a) => a.name.toLowerCase().includes(sLower));
      }

      // Sort by songs count descending
      artists.sort((a, b) => b.songsCount - a.songsCount);

      res.json({
        success: true,
        count: artists.length,
        artists,
        data: artists,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/artists
   */
  static async createArtist(req, res, next) {
    try {
      const { name, imageUrl, bio } = req.body;
      if (!name) {
        return res.status(400).json({ success: false, message: 'Artist name is required.' });
      }

      const canonicalName = ArtistController.canonicalizeName(name);
      let artist;

      if (mongoose.connection.readyState === 1) {
        artist = await Artist.findOneAndUpdate(
          { name: canonicalName },
          { imageUrl: imageUrl || '', bio: bio || '' },
          { upsert: true, new: true }
        );
      } else {
        artist = {
          id: Math.random().toString(36).substring(2, 9),
          _id: Math.random().toString(36).substring(2, 9),
          name: canonicalName,
          imageUrl: imageUrl || '',
          bio: bio || '',
          songsCount: 0,
        };
      }

      await SyncService.bumpEpoch('SYNC', `Artist "${canonicalName}" profile saved`);

      res.status(201).json({
        success: true,
        message: `Artist "${canonicalName}" saved successfully.`,
        artist,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * PUT /api/v1/artists/:id
   * Works for both real MongoDB Artist docs AND song-derived virtual artists
   */
  static async updateArtist(req, res, next) {
    try {
      const { name, imageUrl, bio } = req.body;
      const idParam = req.params.id;
      let updated = null;

      if (mongoose.connection.readyState === 1) {
        // 1. Try by real MongoDB _id first
        const isValidObjectId = /^[a-f\d]{24}$/i.test(idParam);
        if (isValidObjectId) {
          updated = await Artist.findByIdAndUpdate(
            idParam,
            {
              ...(name && { name: ArtistController.canonicalizeName(name) }),
              ...(imageUrl !== undefined && { imageUrl }),
              ...(bio !== undefined && { bio }),
            },
            { new: true }
          );
        }

        // 2. If not found by ID, upsert by OLD artist name (sent in body as originalName or name)
        if (!updated) {
          const searchName = req.body.originalName || req.body.name || name;
          const canonicalNew = name ? ArtistController.canonicalizeName(name) : null;
          updated = await Artist.findOneAndUpdate(
            { name: { $regex: new RegExp(`^${searchName}$`, 'i') } },
            {
              ...(canonicalNew && { name: canonicalNew }),
              ...(imageUrl !== undefined && { imageUrl }),
              ...(bio !== undefined && { bio }),
            },
            { upsert: true, new: true, setDefaultsOnInsert: true }
          );
        }

        // 3. Also update all songs that reference the old artist name
        if (updated && req.body.originalName && req.body.originalName !== updated.name) {
          await Song.updateMany(
            { artistName: { $regex: new RegExp(`^${req.body.originalName}$`, 'i') } },
            { $set: { artistName: updated.name } }
          );
        }
      } else {
        // LocalStore mode: update songs with matching artist name
        const oldName = req.body.originalName || name;
        const newName = name ? ArtistController.canonicalizeName(name) : oldName;
        LocalStore.updateLocalSongs((songs) =>
          songs.map((s) => {
            if ((s.artistName || '').toLowerCase() === oldName.toLowerCase()) {
              return {
                ...s,
                artistName: newName,
                ...(imageUrl !== undefined && { artworkUrl: imageUrl || s.artworkUrl }),
              };
            }
            return s;
          })
        );
        updated = {
          _id: idParam,
          id: idParam,
          name: newName,
          imageUrl: imageUrl || '',
          bio: bio || '',
        };
      }

      await SyncService.bumpEpoch('SYNC', `Artist "${updated?.name || name}" profile updated`);

      res.json({
        success: true,
        message: 'Artist profile updated successfully.',
        artist: updated,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * DELETE /api/v1/artists/:id
   */
  static async deleteArtist(req, res, next) {
    try {
      let deleted;
      if (mongoose.connection.readyState === 1) {
        deleted = await Artist.findByIdAndDelete(req.params.id);
        if (deleted) {
          await Song.deleteMany({ artistName: deleted.name });
        }
      }

      await SyncService.bumpEpoch('SYNC', `Artist and catalog updated`);

      res.json({
        success: true,
        message: 'Artist profile deleted successfully.',
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = ArtistController;
