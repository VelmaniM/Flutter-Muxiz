const express = require('express');
const router = express.Router();
const SyncController = require('../../../controllers/syncController');

router.get('/', SyncController.getSyncStatus);
router.post('/wipe', SyncController.wipeAllCache);
router.post('/wipe-catalog', SyncController.wipeCatalog);

module.exports = router;
