const express = require('express');
const multer = require('multer');
const { authRequired } = require('../middleware/auth');
const cv = require('../controllers/cv.controller');

const router = express.Router();
router.use(authRequired);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

router.get('/documents', cv.listDocuments);
router.post('/documents', cv.createDocument);
router.post('/documents/upload-analyze', upload.single('file'), cv.uploadAndAnalyzeFile);
router.get('/documents/:id', cv.getDocument);
router.delete('/documents/:id', cv.deleteDocument);
router.post('/documents/:id/analyze', cv.analyzeDocument);

module.exports = router;
