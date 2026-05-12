const express = require('express');
const { authRequired } = require('../middleware/auth');
const pl = require('../controllers/pipeline.controller');

const router = express.Router();
router.use(authRequired);

router.get('/summary', pl.summary);

module.exports = router;
