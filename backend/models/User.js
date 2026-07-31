/**
 * models/User.js — Mongoose schema for registered users
 *
 * Roles:
 *   student       — default, read-only access
 *   contributor   — can upload materials
 *   admin         — legacy admin (kept for backward compatibility)
 *   faculty_admin — department-scoped Admin (shown as "Admin" in UI), requires Super Admin approval
 *   super_admin   — global admin, manages Admins and all departments (hidden from UI)
 *
 * Status (used for Admin approval workflow):
 *   active   — fully active account (default for student/contributor/admin/super_admin)
 *   pending  — Admin registration awaiting Super Admin approval
 *   rejected — Admin registration rejected by Super Admin
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

    // ─── Account status (Admin approval workflow) ──────────────────────────
    status: {
      type: String,
      enum: {
        values: ['active', 'pending', 'rejected', 'disabled'],
        message: 'Status must be active, pending, rejected, or disabled',
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
    bio: {
      type: String,
      trim: true,
      default: '',
    },
    profilePhotoUrl: {
      type: String,
      trim: true,
      default: '',
    },

    // ─── Admin approval tracking ───────────────────────────────────────────
    // Set when Super Admin approves or rejects a pending Admin
    verifiedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    verifiedAt: {
      type: Date,
      default: null,
    },
    rejectionReason: {
      type: String,
      trim: true,
      default: null,
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
