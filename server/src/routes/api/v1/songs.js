const express = require('express');
const router = express.Router();
const SongController = require('../../../controllers/songController');
const redisCache = require('../../../services/redisCacheService');

router.get('/', redisCache.middleware(120, 'songs'), SongController.getAllSongs);
router.get('/stream/:fileId', SongController.streamAudio);
router.get('/:id', SongController.getSongById);
router.put('/:id', SongController.updateSong);
router.delete('/album/:albumName', SongController.deleteAlbum);
router.delete('/artist/:artistName', SongController.deleteArtist);
router.delete('/:id', SongController.deleteSong);

module.exports = router;
