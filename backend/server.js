/**
 * server.js — EduShare Express Entry Point
 *
 * Boots the Express application, connects to MongoDB Atlas,
 * registers all route groups, and starts listening on PORT.
 *
 * Production notes:
 *  - PORT comes from process.env.PORT (Render injects this automatically)
 *  - Morgan logs in 'combined' format in production for structured access logs
 *  - CORS is configured from ALLOWED_ORIGINS env var (comma-separated)
 *    Leave ALLOWED_ORIGINS empty to allow all origins (fine for a mobile API)
 */

require('dotenv').config();
require('express-async-errors'); // Patch async route handlers — no try/catch boilerplate needed

const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const connectDB = require('./config/db');

// ─── Route imports ────────────────────────────────────────────────────
const authRoutes = require('./routes/authRoutes');
const departmentRoutes = require('./routes/departmentRoutes');
const courseRoutes = require('./routes/courseRoutes');
const materialRoutes = require('./routes/materialRoutes');
const adminRoutes = require('./routes/adminRoutes');
const userRoutes = require('./routes/userRoutes');

// ─── Bootstrap ────────────────────────────────────────────────────────
const app = express();
const PORT = process.env.PORT || 5000;

// Connect to MongoDB
connectDB();

// ─── CORS ─────────────────────────────────────────────────────────────
// ALLOWED_ORIGINS: comma-separated list of allowed origins.
// Leave blank (or unset) to allow ALL origins — correct for a mobile API
// where the client has no fixed Origin header.
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim()).filter(Boolean)
  : [];

app.use(
  cors({
    origin: (origin, callback) => {
      // Allow requests with no origin (mobile apps, curl, Render health checks)
      if (!origin) return callback(null, true);
      // If no allow-list is configured, permit everything
      if (allowedOrigins.length === 0) return callback(null, true);
      if (allowedOrigins.includes(origin)) return callback(null, true);
      callback(new Error(`CORS: origin ${origin} not allowed`));
    },
    credentials: true,
  })
);

// ─── Middleware ───────────────────────────────────────────────────────
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Log every request — use 'combined' in production for structured logs
// Render captures stdout so all console output appears in the dashboard
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

// ─── Health check ─────────────────────────────────────────────────────
// Render uses this endpoint to determine if the service is healthy.
// It must respond with 2xx within the health check interval.
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'edushare-api',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString(),
  });
});

// ─── API Routes ───────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/departments', departmentRoutes);
app.use('/api/courses', courseRoutes);
app.use('/api/materials', materialRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/users', userRoutes);

// ─── 404 handler ─────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route ${req.originalUrl} not found` });
});

// ─── Global error handler ─────────────────────────────────────────────
// Catches anything thrown from route handlers (express-async-errors handles async)
app.use((err, req, res, next) => { // eslint-disable-line no-unused-vars
  // Always log the full error server-side
  console.error(`[ERROR] ${err.stack || err.message}`);

  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';

  res.status(statusCode).json({
    success: false,
    message,
    // Only include stack traces in development — never leak internals in production
    ...(process.env.NODE_ENV !== 'production' && { stack: err.stack }),
  });
});

// ─── Start server ─────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`✅  EduShare API running on port ${PORT} [${process.env.NODE_ENV || 'development'}]`);
});

module.exports = app;
