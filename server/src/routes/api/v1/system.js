const express = require('express');
const router = express.Router();
const SystemController = require('../../../controllers/systemController');

router.get('/health', SystemController.getHealth);
router.get('/metrics', SystemController.getMetrics);

module.exports = router;
