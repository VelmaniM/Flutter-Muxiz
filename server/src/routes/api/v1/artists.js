const express = require('express');
const router = express.Router();
const ArtistController = require('../../../controllers/artistController');

router.get('/', ArtistController.getAllArtists);
router.post('/', ArtistController.createArtist);
router.put('/:id', ArtistController.updateArtist);
router.delete('/:id', ArtistController.deleteArtist);

module.exports = router;
