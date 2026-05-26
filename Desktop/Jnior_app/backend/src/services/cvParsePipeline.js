/**
 * CV parse pipeline: Llama parser (optional) → text heuristic fallback.
 */

const { parseCvFileViaParser } = require('./cvParserClient');
const { parseCvFromFileHeuristic } = require('./cvHeuristicParse');

function heuristicEnabled() {
  const v = process.env.CV_TEXT_HEURISTIC;
  if (v === '0' || v === 'false') return false;
  return true;
}

/**
 * @param {{ fileBuffer: Buffer, fileName: string }} opts
 * @returns {Promise<{ parsedCv: object, engine: string } | null>}
 */
async function parseCvFileForPortfolio({ fileBuffer, fileName }) {
  try {
    const ml = await parseCvFileViaParser({ fileBuffer, fileName });
    if (ml?.parsedCv) {
      return ml;
    }
  } catch (err) {
    console.warn('[cv-parser] ML parse failed, trying text heuristic:', err.message);
  }

  if (!heuristicEnabled()) {
    return null;
  }

  try {
    return await parseCvFromFileHeuristic(fileBuffer, fileName);
  } catch (err) {
    console.warn('[cv-heuristic] parse failed:', err.message);
    return null;
  }
}

module.exports = {
  parseCvFileForPortfolio,
  heuristicEnabled,
};
