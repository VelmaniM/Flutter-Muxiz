const express = require('express');
const router = express.Router();
const UploadController = require('../../../controllers/uploadController');

router.post('/session', UploadController.createSession);
router.put('/direct', UploadController.directUpload);
router.post('/direct', UploadController.directUpload);
router.post('/complete', UploadController.completeUpload);
router.post('/extract-tags', UploadController.extractTags);
router.post('/avatar', UploadController.uploadAvatar);
router.delete('/avatar', UploadController.removeAvatar);
router.get(['/search-meta', '/apple-metadata', '/metadata'], UploadController.searchMetadata);

module.exports = router;

