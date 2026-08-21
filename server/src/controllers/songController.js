const Song = require('../models/Song');
const Artist = require('../models/Artist');
const Album = require('../models/Album');
const LocalStore = require('../models/store');
const SyncService = require('../services/syncService');
const MetadataService = require('../services/metadataService');
const mongoose = require('mongoose');

class SongController {
  static formatSong(s) {
    if (!s) return null;
    let cleanArt = (s.artistName || s.artist || '').trim();
    if (cleanArt.toLowerCase() === 'unknown artist' || cleanArt.toLowerCase() === 'unknown') {
      cleanArt = s.movieName || s.albumName || '';
    }
    return {
      id: s._id ? s._id.toString() : (s.id || '').toString(),
      _id: s._id ? s._id.toString() : (s.id || '').toString(),
      title: s.title || 'Untitled Track',
      artist: cleanArt,
      artistName: cleanArt,
      album: s.albumName || s.movieName || s.album || 'Single',
      movieName: s.movieName || s.albumName || s.album || 'Single',
      albumName: s.albumName || s.movieName || s.album || 'Single',
      genre: s.genre || 'Tamil Soundtrack',
      language: s.language || 'Tamil',
      duration: s.duration || 0,
      artworkUrl: s.artworkUrl || '',
      audioUrl: s.storage?.directStreamUrl || s.audioUrl,
      playCount: s.playCount || 0,
      likesCount: s.likesCount || 0,
      createdAt: s.createdAt || new Date().toISOString(),
    };
  }

  /**
   * GET /api/v1/songs
   * List all published songs with search, genre, pagination, and sorting
   */
  static async getAllSongs(req, res, next) {
    try {
      const { search, genre, language, page = 1, limit = 50 } = req.query;
      let songs = [];
      let total = 0;

      if (mongoose.connection.readyState === 1) {
        const query = { status: 'PUBLISHED' };
        if (search) {
          query.$or = [
            { title: { $regex: search, $options: 'i' } },
            { artistName: { $regex: search, $options: 'i' } },
            { albumName: { $regex: search, $options: 'i' } },
            { movieName: { $regex: search, $options: 'i' } },
          ];
        }
        if (genre) query.genre = genre;
        if (language) query.language = language;

        total = await Song.countDocuments(query);
        songs = await Song.find(query)
          .sort({ createdAt: -1 })
          .skip((Number(page) - 1) * Number(limit))
          .limit(Number(limit))
          .lean();
      } else {
        const localSongs = LocalStore.getLocalSongs();
        let filtered = localSongs.filter((s) => s.status === 'PUBLISHED' || !s.status);
        if (search) {
          const sLower = search.toLowerCase();
          filtered = filtered.filter(
            (s) =>
              (s.title && s.title.toLowerCase().includes(sLower)) ||
              (s.artistName && s.artistName.toLowerCase().includes(sLower)) ||
              (s.movieName && s.movieName.toLowerCase().includes(sLower)) ||
              (s.albumName && s.albumName.toLowerCase().includes(sLower))
          );
        }
        if (genre) filtered = filtered.filter((s) => s.genre === genre);
        if (language) filtered = filtered.filter((s) => s.language === language);

        total = filtered.length;
        songs = filtered.slice((Number(page) - 1) * Number(limit), Number(page) * Number(limit));
      }

      const formatted = songs.map((s) => {
        let cleanArt = (s.artistName || s.artist || '').trim();
        if (cleanArt.toLowerCase() === 'unknown artist' || cleanArt.toLowerCase() === 'unknown') {
          cleanArt = s.movieName || s.albumName || '';
        }
        return {
          id: s._id ? s._id.toString() : s.id,
          _id: s._id ? s._id.toString() : s.id,
          title: s.title,
          artist: cleanArt,
          artistName: cleanArt,
          album: s.albumName || s.movieName || s.album || 'Single',
          movieName: s.movieName || s.albumName || s.album || 'Single',
          albumName: s.albumName || s.movieName || s.album || 'Single',
          genre: s.genre || 'Tamil Soundtrack',
          language: s.language || 'Tamil',
          duration: s.duration || 0,
          artworkUrl: s.artworkUrl || '',
          audioUrl: s.storage?.directStreamUrl || s.audioUrl,
          playCount: s.playCount || 0,
          likesCount: s.likesCount || 0,
          createdAt: s.createdAt || new Date().toISOString(),
        };
      });

      res.json({
        success: true,
        count: formatted.length,
        total,
        page: Number(page),
        totalPages: Math.ceil(total / Number(limit)),
        songs: formatted,
        data: formatted,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/v1/songs/stream/:fileId
   * Stream audio with range support for instant playback
   */
  static async streamAudio(req, res, next) {
    try {
      const { fileId } = req.params;
      const StorageService = require('../services/storageService');
      await StorageService.streamAudioFile(fileId, req, res);
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/v1/songs/:id
   */
  static async getSongById(req, res, next) {
    try {
      const song = await Song.findById(req.params.id);
      if (!song) {
        return res.status(404).json({ success: false, message: 'Song not found.' });
      }
      res.json({ success: true, song, data: song });
    } catch (error) {
      next(error);
    }
  }

  /**
   * PUT /api/v1/songs/:id
   * Update song metadata
   */
  static async updateSong(req, res, next) {
    try {
      const { title, artistName, movieName, albumName, genre, language, artworkUrl } = req.body;
      let updated = null;

        if (mongoose.connection.readyState === 1) {
        const doc = await Song.findByIdAndUpdate(
          req.params.id,
          {
            ...(title && { title: MetadataService.cleanTrackTitle(title) }),
            ...(artistName && { artistName: MetadataService.cleanString(artistName) }),
            ...(movieName && { movieName: MetadataService.cleanMovieOrAlbum(movieName) }),
            ...(albumName && { albumName: MetadataService.cleanMovieOrAlbum(albumName) }),
            ...(genre && { genre }),
            ...(language && { language }),
            ...(artworkUrl && { artworkUrl }),
          },
          { new: true }
        );
        if (doc) updated = SongController.formatSong(doc);
      } else {
        const songs = LocalStore.getLocalSongs();
        const targetId = (req.params.id || '').toString();
        const idx = songs.findIndex((s) => (s._id && s._id.toString() === targetId) || (s.id && s.id.toString() === targetId));
        if (idx !== -1) {
          const cleanTitle = title ? MetadataService.cleanTrackTitle(title) : songs[idx].title;
          const cleanMovie = (movieName || albumName) ? MetadataService.cleanMovieOrAlbum(movieName || albumName) : (songs[idx].movieName || songs[idx].albumName || 'Single');
          const cleanArtist = artistName ? MetadataService.cleanString(artistName) : (songs[idx].artistName || songs[idx].artist || 'Unknown Artist');

          songs[idx] = {
            ...songs[idx],
            status: 'PUBLISHED',
            title: cleanTitle,
            artist: cleanArtist,
            artistName: cleanArtist,
            movieName: cleanMovie,
            albumName: cleanMovie,
            album: cleanMovie,
            ...(genre && { genre }),
            ...(language && { language }),
            ...(artworkUrl && { artworkUrl }),
          };
          LocalStore.saveLocalSongs(songs);
          updated = SongController.formatSong(songs[idx]);
        }
      }

      if (!updated) {
        return res.status(404).json({ success: false, message: 'Song not found.' });
      }

      // Bump Cache Epoch
      await SyncService.bumpEpoch('SYNC', `Song "${updated.title}" updated`);

      res.json({ success: true, message: 'Song updated successfully.', song: updated });
    } catch (error) {
      next(error);
    }
  }

  /**
   * DELETE /api/v1/songs/:id
   * Soft Delete or Hard Delete
   */
  static async deleteSong(req, res, next) {
    try {
      const { hard } = req.query;
      let deletedSong = null;

      if (mongoose.connection.readyState === 1) {
        if (hard === 'true') {
          deletedSong = await Song.findByIdAndDelete(req.params.id);
        } else {
          deletedSong = await Song.findByIdAndUpdate(
            req.params.id,
            { status: 'DELETED' },
            { new: true }
          );
        }
      } else {
        const songs = LocalStore.getLocalSongs();
        const idx = songs.findIndex((s) => (s._id || s.id) === req.params.id);
        if (idx !== -1) {
          if (hard === 'true') {
            deletedSong = songs.splice(idx, 1)[0];
          } else {
            songs[idx].status = 'DELETED';
            deletedSong = songs[idx];
          }
          LocalStore.saveLocalSongs(songs);
        }
      }

      // --- Cascading Orphan Cleanup (Artist & Album) ---
      if (deletedSong) {
        const songArtist = deletedSong.artistName || deletedSong.artist;
        const songMovie = deletedSong.movieName || deletedSong.albumName || deletedSong.album;

        if (mongoose.connection.readyState === 1) {
          // 1. Check if artist has any remaining PUBLISHED songs
          if (songArtist && songArtist !== 'Unknown Artist') {
            const remainingArtistSongs = await Song.countDocuments({
              artistName: songArtist,
              status: 'PUBLISHED',
            });
            if (remainingArtistSongs === 0) {
              await Artist.deleteMany({ name: songArtist });
              console.log(`🧹 [Cascading Cleanup] Removed orphaned artist record: "${songArtist}"`);
            }
          }

          // 2. Check if album/movie has any remaining PUBLISHED songs
          if (songMovie && songMovie !== 'Single') {
            const remainingAlbumSongs = await Song.countDocuments({
              $or: [{ movieName: songMovie }, { albumName: songMovie }],
              status: 'PUBLISHED',
            });
            if (remainingAlbumSongs === 0) {
              await Album.deleteMany({ title: songMovie });
              console.log(`🧹 [Cascading Cleanup] Removed orphaned album record: "${songMovie}"`);
            }
          }
        }
      }

      await SyncService.bumpEpoch('SYNC', `Song deletion and clean-up synchronized`);

      res.json({
        success: true,
        message: 'Song removed from catalog successfully.',
        songId: deletedSong._id || deletedSong.id,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * DELETE /api/v1/songs/album/:albumName
   * Delete an entire Album and all its songs + associated orphaned artists
   */
  static async deleteAlbum(req, res, next) {
    try {
      const albumName = decodeURIComponent(req.params.albumName);
      if (mongoose.connection.readyState === 1) {
        await Song.deleteMany({
          $or: [{ movieName: albumName }, { albumName }],
        });
        await Album.deleteMany({ title: albumName });
      } else {
        const songs = LocalStore.getLocalSongs();
        const filtered = songs.filter(
          (s) => (s.movieName || s.albumName || s.album) !== albumName
        );
        LocalStore.saveLocalSongs(filtered);
      }

      await SyncService.bumpEpoch('SYNC', `Entire album "${albumName}" and its tracks deleted`);

      res.json({
        success: true,
        message: `Album "${albumName}" and all associated songs removed successfully.`,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * DELETE /api/v1/songs/artist/:artistName
   * Delete an entire Artist and all their songs + associated orphaned albums
   */
  static async deleteArtist(req, res, next) {
    try {
      const artistName = decodeURIComponent(req.params.artistName);
      if (mongoose.connection.readyState === 1) {
        await Song.deleteMany({ artistName });
        await Artist.deleteMany({ name: artistName });
      } else {
        const songs = LocalStore.getLocalSongs();
        const filtered = songs.filter(
          (s) => (s.artistName || s.artist) !== artistName
        );
        LocalStore.saveLocalSongs(filtered);
      }

      await SyncService.bumpEpoch('SYNC', `Entire artist "${artistName}" and their tracks deleted`);

      res.json({
        success: true,
        message: `Artist "${artistName}" and all their songs removed successfully.`,
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = SongController;
