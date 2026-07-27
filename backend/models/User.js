/**
 * models/User.js — Mongoose schema for registered users
 *
 * Roles:
 *   student       — default, read-only access
 *   contributor   — can upload materials
 *   admin         — legacy admin (kept for backward compatibility)
 *   faculty_admin — department-scoped admin, requires Super Admin approval
 *   super_admin   — global admin, manages Faculty Admins and all departments
 *
 * Status (used for Faculty Admin approval workflow):
 *   active  — fully active account (default for student/contributor/admin/super_admin)
 *   pending — Faculty Admin registration awaiting Super Admin approval
 *   disabled — account suspended by Super Admin
 */

const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
      minlength: [2, 'Name must be at least 2 characters'],
      maxlength: [100, 'Name cannot exceed 100 characters'],
    },
    email: {
      type: String,
      required: [true, 'Email is required'],
      unique: true,
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, 'Please enter a valid email address'],
    },
    password: {
      type: String,
      required: [true, 'Password is required'],
      minlength: [6, 'Password must be at least 6 characters'],
      select: false, // Never returned in queries by default
    },
    role: {
      type: String,
      enum: {
        values: ['student', 'contributor', 'admin', 'faculty_admin', 'super_admin'],
        message: 'Role must be student, contributor, admin, faculty_admin, or super_admin',
      },
      default: 'student',
    },

    // ─── Account status (Faculty Admin approval workflow) ──────────────────
    status: {
      type: String,
      enum: {
        values: ['active', 'pending', 'disabled'],
        message: 'Status must be active, pending, or disabled',
      },
      default: 'active',
    },

    // ─── Department ────────────────────────────────────────────────────────
    // Plain string kept for all roles (legacy + readability).
    department: {
      type: String,
      trim: true,
      default: '',
    },
    // ObjectId reference to Department document (used for Faculty Admin scoping).
    departmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Department',
      default: null,
    },

    // ─── Faculty Admin extra fields ────────────────────────────────────────
    facultyId: {
      type: String,
      trim: true,
      default: '',
    },
    designation: {
      type: String,
      trim: true,
      default: '',
    },
    profilePhotoUrl: {
      type: String,
      trim: true,
      default: '',
    },

    // ─── Soft-delete flag ──────────────────────────────────────────────────
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true, // Adds createdAt and updatedAt automatically
    toJSON: {
      // Remove __v and password when converting to JSON
      transform(doc, ret) {
        ret.id = ret._id.toString();
        delete ret._id;
        delete ret.__v;
        delete ret.password;
        return ret;
      },
    },
  }
);

// ─── Pre-save hook: hash password before storing ───────────────────────
userSchema.pre('save', async function (next) {
  // Only re-hash if the password field was actually modified
  if (!this.isModified('password')) return next();

  const saltRounds = 12;
  this.password = await bcrypt.hash(this.password, saltRounds);
  next();
});

// ─── Instance method: compare plain password vs stored hash ───────────
userSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

module.exports = mongoose.model('User', userSchema);
