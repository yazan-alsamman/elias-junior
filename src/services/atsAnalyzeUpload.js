/**
 * Upload ATS: try Uvicorn FastAPI first, fall back to local text extraction + heuristic.
 */

const { analyzeCvFileViaFastapi } = require('./atsFastapiClient');
const { analyzeExtractedText } = require('./atsHeuristic');
const { extractTextFromUpload } = require('./cvTextExtract');

/**
 * @returns {Promise<{ ats: object, extractedText: string, engine: string }>}
 */
async function analyzeUploadedCvFile({ fileBuffer, fileName }) {
  try {
    const ats = await analyzeCvFileViaFastapi({ fileBuffer, fileName });
    return {
      ats,
      extractedText: '',
      engine: ats.templateId || 'fastapi-ats-format-v1',
    };
  } catch (fastErr) {
    console.warn(
      `[ats] FastAPI unavailable (${process.env.ATS_FASTAPI_URL || 'no URL'}):`,
      fastErr.message,
    );

    let extractedText = '';
    try {
      extractedText = await extractTextFromUpload(fileBuffer, fileName);
    } catch (extractErr) {
      console.warn('[ats] Text extraction failed:', extractErr.message);
    }

    if (!extractedText || extractedText.length < 40) {
      extractedText = [
        `Uploaded CV: ${fileName}`,
        '',
        'ATS format engine was unreachable; only a basic keyword scan ran.',
        'Start Uvicorn (start-ats-uvicorn.cmd) and set ATS_FASTAPI_URL for full PDF/DOCX rules.',
      ].join('\n');
    }

    const ats = analyzeExtractedText(extractedText);
    ats.issuesSummary = `Heuristic fallback (Uvicorn ATS offline) — ${ats.issuesSummary}`;
    ats.recommendationBullets = [
      'Connect ATS_FASTAPI_URL to a running Uvicorn service for format rules (images, columns, tables).',
      ...ats.recommendationBullets,
    ].slice(0, 6);
    ats.templateId = 'heuristic-fallback-v1';

    return {
      ats,
      extractedText,
      engine: ats.templateId,
    };
  }
}

module.exports = { analyzeUploadedCvFile };
