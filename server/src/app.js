const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const path = require('path');

const routes = require('./routes');
const logger = require('./middlewares/logger');
const errorHandler = require('./middlewares/errorHandler');

const app = express();

// Security and Performance Middlewares
app.use(
  helmet({
    contentSecurityPolicy: false, // Allows direct media and cdn streams in Studio UI
    crossOriginEmbedderPolicy: false,
  })
);
app.use(cors({ origin: '*', methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'] }));
app.use(compression());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(logger);

// API Router with Strict No-Cache Headers for Studio & Dynamic Data
app.use((req, res, next) => {
  if (req.originalUrl.startsWith('/api') || req.originalUrl.startsWith('/studio')) {
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    res.setHeader('Surrogate-Control', 'no-store');
  }
  next();
});

app.use(routes);

// Serve Built React Studio Console Static Files
const publicPath = path.join(__dirname, '../public');
app.use(express.static(publicPath));

// Serve Studio on /studio and SPA fallback on non-API routes
app.get(['/studio', '/studio/*', '*'], (req, res, next) => {
  if (req.originalUrl.startsWith('/api')) {
    return next();
  }
  res.sendFile(path.join(publicPath, 'index.html'));
});

// Error Handling Middleware
app.use(errorHandler);

module.exports = app;
