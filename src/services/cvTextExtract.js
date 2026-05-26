/**
 * Extract plain text from uploaded CV bytes (PDF / DOCX) for heuristic ATS fallback.
 */

async function extractTextFromUpload(fileBuffer, fileName) {
  const ext = String(fileName || '').toLowerCase().split('.').pop();
  if (!fileBuffer || !Buffer.isBuffer(fileBuffer)) {
    return '';
  }

  if (ext === 'pdf') {
    const { PDFParse } = require('pdf-parse');
    const parser = new PDFParse({ data: fileBuffer });
    const result = await parser.getText();
    return String(result.text || '').trim();
  }

  if (ext === 'docx') {
    const mammoth = require('mammoth');
    const result = await mammoth.extractRawText({ buffer: fileBuffer });
    return String(result.value || '').trim();
  }

  return '';
}

module.exports = { extractTextFromUpload };
