/**
 * config/db.js — MongoDB Atlas connection via Mongoose
 *
 * Production-tuned timeouts for Render free tier:
 *  - serverSelectionTimeoutMS raised from 5 s → 15 s
 *    (Atlas free clusters can be slow to respond on cold Render starts)
 *  - socketTimeoutMS kept at 45 s
 */

const mongoose = require('mongoose');

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGO_URI, {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 15000, // wait up to 15 s for Atlas on cold start
      socketTimeoutMS: 45000,
    });

    console.log(`✅  MongoDB connected: ${conn.connection.host}`);
  } catch (error) {
    console.error(`❌  MongoDB connection failed: ${error.message}`);
    process.exit(1); // Kill the process — app cannot run without DB
  }
};

module.exports = connectDB;
