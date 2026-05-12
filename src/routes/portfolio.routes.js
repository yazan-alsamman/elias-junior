const express = require('express');
const { authRequired } = require('../middleware/auth');
const p = require('../controllers/portfolio.controller');

const router = express.Router();
router.use(authRequired);

router.get('/', p.listPortfolios);
router.post('/', p.upsertPortfolio);

module.exports = router;
