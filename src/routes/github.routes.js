const express = require('express');
const { authRequired } = require('../middleware/auth');
const gh = require('../controllers/github.controller');

const router = express.Router();
router.use(authRequired);

router.get('/', gh.getGithub);
router.put('/', gh.linkGithub);

module.exports = router;
