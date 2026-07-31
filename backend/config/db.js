/**
 * config/db.js — MongoDB Atlas connection via Mongoose
 *
 * Production-tuned timeouts for Render free tier:
 *  - serverSelectionTimeoutMS raised from 5 s → 15 s
 *    (Atlas free clusters can be slow to respond on cold Render starts)
 *  - socketTimeoutMS kept at 45 s
 */

const mongoose = require('mongoose');
const dns = require('dns');

const connectDB = async () => {
  try {
    // Set reliable public DNS servers to resolve MongoDB SRV records (fixes querySrv ECONNREFUSED on ISP DNS)
    try {
      dns.setServers(['8.8.8.8', '8.8.4.4']);
    } catch (_) {
      // Fall back silently if setServers fails
    }

    const conn = await mongoose.connect(process.env.MONGO_URI, {
      maxPoolSize: 10,
      serverSelectionTimeoutMS: 15000, // wait up to 15 s for Atlas on cold start
      socketTimeoutMS: 45000,
    });

    console.log(`✅  MongoDB connected: ${conn.connection.host}`);

    // Auto-seed Super Admin if one does not exist yet
    const User = require('../models/User');
    const existingSuperAdmin = await User.findOne({ role: 'super_admin' });
    if (!existingSuperAdmin) {
      const email = process.env.SUPER_ADMIN_EMAIL || 'superadmin@bubt.edu.bd';
      const password = process.env.SUPER_ADMIN_PASSWORD || 'SuperAdminPassword123';
      const name = process.env.SUPER_ADMIN_NAME || 'Super Admin';

      await User.create({
        name,
        email: email.toLowerCase().trim(),
        password,
        role: 'super_admin',
        status: 'active',
        department: 'All Departments',
        isActive: true,
      });
      console.log(`✅  Super Admin account auto-created: ${email}`);
    }
  } catch (error) {
    console.error(`❌  MongoDB connection failed: ${error.message}`);
    process.exit(1); // Kill the process — app cannot run without DB
  }
};

module.exports = connectDB;
