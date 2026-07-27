/**
 * scripts/seedSuperAdmin.js — One-time Super Admin seeder
 *
 * Usage:
 *   node backend/scripts/seedSuperAdmin.js
 *
 * Reads credentials from environment variables:
 *   SUPER_ADMIN_EMAIL    — e.g. superadmin@bubt.edu.bd
 *   SUPER_ADMIN_PASSWORD — min 6 characters
 *   SUPER_ADMIN_NAME     — display name
 *
 * Set these in your .env file before running.
 * This script is safe to run multiple times — it checks for an existing
 * super_admin account and does nothing if one already exists.
 */

require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');

const run = async () => {
  const email = process.env.SUPER_ADMIN_EMAIL;
  const password = process.env.SUPER_ADMIN_PASSWORD;
  const name = process.env.SUPER_ADMIN_NAME || 'Super Admin';

  if (!email || !password) {
    console.error('❌  Missing SUPER_ADMIN_EMAIL or SUPER_ADMIN_PASSWORD in .env');
    process.exit(1);
  }

  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅  Connected to MongoDB');

    // Check if a super_admin already exists
    const existing = await User.findOne({ role: 'super_admin' });
    if (existing) {
      console.log(`ℹ️   Super Admin already exists: ${existing.email}`);
      await mongoose.disconnect();
      return;
    }

    // Also check if the email is already taken by another role
    const emailTaken = await User.findOne({ email: email.toLowerCase().trim() });
    if (emailTaken) {
      console.error(`❌  Email "${email}" is already registered as role: ${emailTaken.role}`);
      await mongoose.disconnect();
      process.exit(1);
    }

    // Create the Super Admin
    const superAdmin = await User.create({
      name,
      email: email.toLowerCase().trim(),
      password, // hashed by pre-save hook
      role: 'super_admin',
      status: 'active',
      department: 'All Departments',
      isActive: true,
    });

    console.log(`✅  Super Admin created successfully!`);
    console.log(`    Name:  ${superAdmin.name}`);
    console.log(`    Email: ${superAdmin.email}`);
    console.log(`    Role:  ${superAdmin.role}`);
    console.log(`    ID:    ${superAdmin._id}`);

    await mongoose.disconnect();
  } catch (err) {
    console.error('❌  Error:', err.message);
    process.exit(1);
  }
};

run();
