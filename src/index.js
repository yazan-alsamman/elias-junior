const path = require('path');

// Load .env from backend/ folder even if node was started from another cwd
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const express = require('express');
const cors = require('cors');
const connectDB = require('./config/database');

const authRoutes = require('./routes/auth.routes');
const cvRoutes = require('./routes/cv.routes');
const githubRoutes = require('./routes/github.routes');
const portfolioRoutes = require('./routes/portfolio.routes');
const pipelineRoutes = require('./routes/pipeline.routes');
const { publicPortfolioPage } = require('./controllers/portfolio.public.controller');

const app = express();
app.use(cors());
app.use(express.json({ limit: '15mb' }));

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'careerpath-api' });
});

/** Public HTML portfolio (no auth). Link stored in MongoDB on portfolio create/update. */
app.get('/p/:slug', publicPortfolioPage);

app.use('/api/auth', authRoutes);
app.use('/api/cv', cvRoutes);
app.use('/api/github', githubRoutes);
app.use('/api/portfolio', portfolioRoutes);
app.use('/api/pipeline', pipelineRoutes);

app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

const PORT = Number(process.env.PORT) || 3001;

async function start() {
  console.log('Starting CareerPath API…');
  await connectDB();
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`API listening on http://localhost:${PORT}`);
  });
}

start().catch((err) => {
  console.error('Startup failed:', err);
  process.exit(1);
});
