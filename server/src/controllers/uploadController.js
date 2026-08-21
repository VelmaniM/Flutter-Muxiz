const StorageService = require('../services/storageService');
const MetadataService = require('../services/metadataService');
const SyncService = require('../services/syncService');
const Song = require('../models/Song');
const Artist = require('../models/Artist');
const Album = require('../models/Album');
const LocalStore = require('../models/store');
const mongoose = require('mongoose');

class UploadController {
  /**
   * POST /api/v1/uploads/session
   * Generate Direct Resumable Upload Session URL for 5TB Google Drive or Local Media Vault
   */
  static async createSession(req, res, next) {
    try {
      const { fileName, mimeType } = req.body;
      const cleanFileName = MetadataService.cleanTrackTitle(fileName || 'untitled') + '.mp3';

      const session = await StorageService.createResumableSession(
        cleanFileName,
        mimeType || 'audio/mpeg'
      );

      res.json(session);
    } catch (error) {
      next(error);
    }
  }

  /**
   * PUT /api/v1/uploads/direct
   * Handles binary stream upload directly to Media Vault + Direct Embedded Tag Extraction
   */
  static async directUpload(req, res, next) {
    try {
      const fileName = req.query.fileName || req.headers['x-file-name'] || 'track.mp3';
      const fileId = req.query.fileId || ('vlt_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7));
      const result = await StorageService.saveDirectUploadStream(fileId, req);

      // Direct Backend Embedded ID3 Metadata & Artwork Extraction
      let embeddedMetadata = null;
      try {
        const mm = require('music-metadata');
        const diskMeta = await mm.parseFile(result.filePath, { duration: true });
        const common = diskMeta?.common || {};
        const format = diskMeta?.format || {};

        let embeddedArtwork = '';
        if (common.picture && common.picture.length > 0) {
          const pic = common.picture[0];
          embeddedArtwork = `data:${pic.format};base64,${pic.data.toString('base64')}`;
        }

        embeddedMetadata = {
          title: common.title ? MetadataService.cleanTrackTitle(common.title) : null,
          artist: common.artist ? MetadataService.cleanString(common.artist) : null,
          album: common.album ? MetadataService.cleanMovieOrAlbum(common.album) : null,
          year: common.year || null,
          genre: 'Tamil Soundtrack',
          duration: Math.round(format.duration || 0),
          artworkUrl: embeddedArtwork,
        };
      } catch (e) {
        console.warn('[DirectUpload Embedded Tag Extraction Notice]', e.message);
      }

      // Asynchronously upload to Google Drive if configured
      StorageService.uploadToGoogleDriveBackground(fileId, result.filePath, fileName).catch(() => {});

      res.status(200).json({
        success: true,
        id: fileId,
        fileId: fileId,
        directStreamUrl: result.directStreamUrl,
        embeddedMetadata,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/uploads/complete
   * Finalize upload metadata with Direct Embedded ID3 Extraction & STRICT 0% Duplicate Detection
   */
  static async completeUpload(req, res, next) {
    try {
      const {
        fileId,
        audioUrl,
        title,
        artistName,
        movieName,
        albumName,
        genre,
        language,
        artworkUrl,
        duration,
        fileSize,
      } = req.body;

      let directStreamUrl = audioUrl;
      if (fileId) {
        directStreamUrl = await StorageService.makePublicStreamable(fileId);
      }

      if (!directStreamUrl) {
        return res.status(400).json({
          success: false,
          message: 'Either Google Drive fileId or audioUrl is required.',
        });
      }

      // 1. Direct Backend Embedded ID3 Tags & Picture Extraction
      let embeddedDiskMeta = null;
      if (fileId) {
        try {
          const path = require('path');
          const fs = require('fs');
          const mm = require('music-metadata');
          const vaultDir = path.join(__dirname, '../../../data/vault');
          const filePath = path.join(vaultDir, `${fileId}.mp3`);
          if (fs.existsSync(filePath)) {
            const diskMeta = await mm.parseFile(filePath, { duration: true });
            const common = diskMeta?.common || {};
            const format = diskMeta?.format || {};

            let diskArtwork = '';
            if (common.picture && common.picture.length > 0) {
              const pic = common.picture[0];
              diskArtwork = `data:${pic.format};base64,${pic.data.toString('base64')}`;
            }

            embeddedDiskMeta = {
              title: common.title ? MetadataService.cleanTrackTitle(common.title) : null,
              artist: common.artist ? MetadataService.cleanString(common.artist) : null,
              album: common.album ? MetadataService.cleanMovieOrAlbum(common.album) : null,
              duration: format.duration ? Math.round(format.duration) : null,
              artworkUrl: diskArtwork,
            };
          }
        } catch (_) {}
      }

      let cleanDuration = parseInt(duration, 10) || embeddedDiskMeta?.duration || 0;

      const rawTitle = MetadataService.cleanTrackTitle(title) || embeddedDiskMeta?.title || '';
      const cleanTitle = rawTitle || MetadataService.cleanTrackTitle(title) || 'Untitled Track';

      let cleanArtist = MetadataService.cleanString(artistName) || embeddedDiskMeta?.artist || '';
      // Strip known bad defaults — do NOT inject 'Soundtrack' as a fallback
      if (!cleanArtist ||
          cleanArtist.toLowerCase() === 'unknown artist' ||
          cleanArtist.toLowerCase() === 'unknown' ||
          cleanArtist.toLowerCase() === 'soundtrack' ||
          cleanArtist.toLowerCase() === 'various artists') {
        cleanArtist = embeddedDiskMeta?.artist || ''; // Empty is better than wrong
      }

      const rawMovie = MetadataService.cleanMovieOrAlbum(movieName || albumName) || embeddedDiskMeta?.album || '';
      const cleanMovie = (rawMovie && rawMovie !== 'Single') ? rawMovie : '';
      const cleanGenre = genre && genre !== 'Tamil Soundtrack' ? genre : (embeddedDiskMeta?.genre || '');
      const cleanLang = language || 'Tamil';

      let finalArtwork = artworkUrl && !artworkUrl.startsWith('blob:') ? artworkUrl : (embeddedDiskMeta?.artworkUrl || '');

      // --- AUTOMATIC MOVIE-LEVEL ARTWORK INHERITANCE ---
      // If songs belong to the SAME movie/album, artwork must automatically be the SAME!
      if (cleanMovie && cleanMovie !== 'Single') {
        if (!finalArtwork) {
          // Look up if any track from the same movie already has HD artwork
          if (mongoose.connection.readyState === 1) {
            const movieSister = await Song.findOne({
              status: 'PUBLISHED',
              $or: [
                { movieName: { $regex: new RegExp(`^${cleanMovie}$`, 'i') } },
                { albumName: { $regex: new RegExp(`^${cleanMovie}$`, 'i') } },
              ],
              artworkUrl: { $exists: true, $ne: '' },
            });
            if (movieSister?.artworkUrl) finalArtwork = movieSister.artworkUrl;
          } else {
            const localSongs = LocalStore.getLocalSongs();
            const movieSister = localSongs.find(
              (s) =>
                s.status !== 'DELETED' &&
                (s.movieName?.toLowerCase().trim() === cleanMovie.toLowerCase().trim() ||
                  s.albumName?.toLowerCase().trim() === cleanMovie.toLowerCase().trim()) &&
                s.artworkUrl &&
                !s.artworkUrl.startsWith('blob:')
            );
            if (movieSister?.artworkUrl) finalArtwork = movieSister.artworkUrl;
          }
        }
      }

      let artistDoc = null;
      let albumDoc = null;
      let targetSong = null;
      let isDuplicateAvoided = false;

      const normTitle = cleanTitle.toLowerCase().trim();
      const normMovie = cleanMovie.toLowerCase().trim();

      if (mongoose.connection.readyState === 1) {
        // --- 1. Deduplicate Artists ---
        artistDoc = await Artist.findOne({ name: { $regex: new RegExp(`^${cleanArtist}$`, 'i') } });
        if (!artistDoc && cleanArtist !== 'Unknown Artist') {
          artistDoc = await Artist.create({
            name: cleanArtist,
            imageUrl: finalArtwork || '',
          });
        }

        // --- 2. Deduplicate Albums & Unify Artwork ---
        if (cleanMovie && cleanMovie !== 'Single') {
          albumDoc = await Album.findOne({ title: { $regex: new RegExp(`^${cleanMovie}$`, 'i') } });
          if (!albumDoc) {
            albumDoc = await Album.create({
              title: cleanMovie,
              artistId: artistDoc?._id || null,
              artistName: cleanArtist,
              artworkUrl: finalArtwork || '',
            });
          } else if (finalArtwork && !albumDoc.artworkUrl) {
            albumDoc.artworkUrl = finalArtwork;
            await albumDoc.save();
          } else if (!finalArtwork && albumDoc.artworkUrl) {
            finalArtwork = albumDoc.artworkUrl;
          }

          // Unify artwork for all sister songs in this movie
          if (finalArtwork) {
            await Song.updateMany(
              {
                status: 'PUBLISHED',
                $or: [
                  { movieName: { $regex: new RegExp(`^${cleanMovie}$`, 'i') } },
                  { albumName: { $regex: new RegExp(`^${cleanMovie}$`, 'i') } },
                ],
                $or: [{ artworkUrl: { $exists: false } }, { artworkUrl: '' }, { artworkUrl: { $regex: '^blob:' } }],
              },
              { $set: { artworkUrl: finalArtwork } }
            );
          }
        }

        // --- 3. STRICT ZERO DUPLICATE SONG DETECTION ---
        // Search for an existing song with same title and movie/album, or same fileId
        const existingSong = await Song.findOne({
          status: 'PUBLISHED',
          $or: [
            {
              title: { $regex: new RegExp(`^${cleanTitle}$`, 'i') },
              $or: [
                { movieName: { $regex: new RegExp(`^${cleanMovie}$`, 'i') } },
                { albumName: { $regex: new RegExp(`^${cleanMovie}$`, 'i') } },
              ],
            },
            ...(fileId ? [{ 'storage.fileId': fileId }] : []),
          ],
        });

        if (existingSong) {
          // Avoid duplicate by updating existing track in place
          existingSong.title = cleanTitle;
          existingSong.artistName = cleanArtist;
          existingSong.movieName = cleanMovie;
          existingSong.albumName = cleanMovie;
          existingSong.genre = cleanGenre;
          existingSong.language = cleanLang;
          existingSong.duration = cleanDuration;
          if (finalArtwork) existingSong.artworkUrl = finalArtwork;
          if (fileId) {
            existingSong.storage = {
              provider: fileId.startsWith('vlt_') ? 'LOCAL_VAULT' : 'GOOGLE_DRIVE',
              fileId,
              directStreamUrl,
              fileSize: fileSize || 0,
              mimeType: 'audio/mpeg',
            };
          }
          await existingSong.save();
          targetSong = existingSong;
          isDuplicateAvoided = true;
          console.log(`🛡️ [Duplicate Prevention] Re-linked and updated existing track: "${cleanTitle}" (${cleanMovie})`);
        } else {
          targetSong = await Song.create({
            title: cleanTitle,
            artistName: cleanArtist,
            movieName: cleanMovie,
            albumName: cleanMovie,
            genre: cleanGenre,
            language: cleanLang,
            duration: cleanDuration,
            artworkUrl: finalArtwork || '',
            storage: {
              provider: fileId ? (fileId.startsWith('vlt_') ? 'LOCAL_VAULT' : 'GOOGLE_DRIVE') : 'DIRECT_URL',
              fileId: fileId || '',
              directStreamUrl,
              fileSize: fileSize || 0,
              mimeType: 'audio/mpeg',
            },
            status: 'PUBLISHED',
            artistId: artistDoc?._id || null,
            albumId: albumDoc?._id || null,
          });
        }
      } else {
        // --- Local File Store Fallback with Strict Duplicate Avoidance ---
        const songs = LocalStore.getLocalSongs();
        const existingIdx = songs.findIndex((s) => {
          if (s.status === 'DELETED') return false;
          const sTitle = (s.title || '').toLowerCase().trim();
          const sMovie = (s.movieName || s.albumName || '').toLowerCase().trim();
          const sFileId = s.storage?.fileId || s.fileId;
          return (sTitle === normTitle && sMovie === normMovie) || (fileId && sFileId === fileId);
        });

        if (existingIdx !== -1) {
          // Avoid duplicate by updating existing track in place
          songs[existingIdx] = {
            ...songs[existingIdx],
            title: cleanTitle,
            artistName: cleanArtist,
            movieName: cleanMovie,
            albumName: cleanMovie,
            genre: cleanGenre,
            language: cleanLang,
            duration: cleanDuration,
            artworkUrl: finalArtwork || songs[existingIdx].artworkUrl,
            storage: {
              provider: fileId ? (fileId.startsWith('vlt_') ? 'LOCAL_VAULT' : 'GOOGLE_DRIVE') : 'DIRECT_URL',
              fileId: fileId || songs[existingIdx].storage?.fileId || '',
              directStreamUrl,
              fileSize: fileSize || songs[existingIdx].storage?.fileSize || 0,
              mimeType: 'audio/mpeg',
            },
            status: 'PUBLISHED',
            updatedAt: new Date().toISOString(),
          };
          targetSong = songs[existingIdx];
          isDuplicateAvoided = true;
          console.log(`🛡️ [Duplicate Prevention Local] Re-linked and updated existing track: "${cleanTitle}" (${cleanMovie})`);
        } else {
          targetSong = {
            id: Math.random().toString(36).substring(2, 9),
            _id: Math.random().toString(36).substring(2, 9),
            title: cleanTitle,
            artistName: cleanArtist,
            movieName: cleanMovie,
            albumName: cleanMovie,
            genre: cleanGenre,
            language: cleanLang,
            duration: cleanDuration,
            artworkUrl: finalArtwork || '',
            storage: {
              provider: fileId ? (fileId.startsWith('vlt_') ? 'LOCAL_VAULT' : 'GOOGLE_DRIVE') : 'DIRECT_URL',
              fileId: fileId || '',
              directStreamUrl,
              fileSize: fileSize || 0,
              mimeType: 'audio/mpeg',
            },
            status: 'PUBLISHED',
            createdAt: new Date().toISOString(),
          };
          songs.unshift(targetSong);
        }

        // Unify artwork for all sister songs of this movie in LocalStore
        if (finalArtwork && cleanMovie && cleanMovie !== 'Single') {
          songs.forEach((s) => {
            if (
              s.status !== 'DELETED' &&
              (s.movieName?.toLowerCase().trim() === cleanMovie.toLowerCase().trim() ||
                s.albumName?.toLowerCase().trim() === cleanMovie.toLowerCase().trim()) &&
              (!s.artworkUrl || s.artworkUrl.startsWith('blob:'))
            ) {
              s.artworkUrl = finalArtwork;
            }
          });
        }

        LocalStore.saveLocalSongs(songs);
      }

      await SyncService.bumpEpoch(
        'SYNC',
        isDuplicateAvoided
          ? `Song "${cleanTitle}" updated without duplicate`
          : `New Song "${cleanTitle}" ingested`
      );

      res.status(isDuplicateAvoided ? 200 : 201).json({
        success: true,
        message: isDuplicateAvoided
          ? `Song "${cleanTitle}" was updated in catalog (0% Duplicate avoided).`
          : `Song ingested and saved to Media Vault & Database successfully!`,
        isDuplicateAvoided,
        song: targetSong,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET/POST /api/v1/uploads/search-meta
   * Deep Analysis & Double-Verification Engine for 100% Apple Music Metadata & 1400x1400 Artwork
   */
  static async searchMetadata(req, res, next) {
    try {
      const query = req.query.query || req.body?.query || '';
      const title = req.query.title || req.body?.title || '';
      const artist = req.query.artist || req.body?.artist || '';
      const album = req.query.album || req.query.movie || req.body?.album || req.body?.movie || '';
      const duration = parseInt(req.query.duration || req.body?.duration, 10) || null;

      const meta = await MetadataService.deepAnalyzeTrack({
        rawFilename: query,
        embeddedTitle: title || query,
        embeddedArtist: artist,
        embeddedAlbum: album,
        duration,
      });

      if (!meta) {
        return res.json({
          success: false,
          message: 'No exact Apple Music match found for query.',
        });
      }

      res.json({
        success: true,
        metadata: meta,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/uploads/extract-tags
   * Extract embedded ID3 / Vorbis tags directly from binary audio buffer
   */
  static async extractTags(req, res, next) {
    try {
      const chunks = [];
      req.on('data', (chunk) => chunks.push(chunk));
      req.on('end', async () => {
        try {
          const buffer = Buffer.concat(chunks);
          const tags = await MetadataService.parseBufferTags(buffer);
          res.json({
            success: true,
            tags: tags || {},
          });
        } catch (err) {
          res.json({ success: false, message: err.message });
        }
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = UploadController;
