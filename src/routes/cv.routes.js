const express = require('express');
const { authRequired } = require('../middleware/auth');
const cv = require('../controllers/cv.controller');

const router = express.Router();
router.use(authRequired);

router.get('/documents', cv.listDocuments);
router.post('/documents', cv.createDocument);
router.get('/documents/:id', cv.getDocument);
router.delete('/documents/:id', cv.deleteDocument);
router.post('/documents/:id/analyze', cv.analyzeDocument);

module.exports = router;
