/**
 * models/Material.js — Mongoose schema for academic materials
 *
 * Department-based approval workflow:
 *   1. Contributor uploads → backend finds active Faculty Admin for that dept
 *   2. assignedAdmin is set automatically
 *   3. Only that Faculty Admin sees the material in their pending queue
 *   4. On approve/reject, approvedBy/approvedAt/rejectionReason are stored
 *
 * approvalStatus mirrors status — kept separate so we can add
 * granular states in the future without breaking the `status` enum.
 */

const mongoose = require('mongoose');

const materialSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: [true, 'Title is required'],
      trim: true,
      minlength: [3, 'Title must be at least 3 characters'],
      maxlength: [200, 'Title cannot exceed 200 characters'],
    },
    description: {
      type: String,
      required: [true, 'Description is required'],
      trim: true,
      maxlength: [1000, 'Description cannot exceed 1000 characters'],
    },
    type: {
      type: String,
      enum: {
        values: ['notes', 'assignment', 'video'],
        message: 'Type must be notes, assignment, or video',
      },
      required: [true, 'Material type is required'],
    },
    // Cloudinary secure URL for PDF/doc files (null for video type)
    fileUrl: {
      type: String,
      default: null,
    },
    // Cloudinary public_id — needed to delete the file from Cloudinary
    filePublicId: {
      type: String,
      default: null,
    },
    // YouTube / Google Drive URL (null for file types)
    videoLink: {
      type: String,
      default: null,
    },
    courseId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Course',
      required: [true, 'Course reference is required'],
    },
    departmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Department',
      required: [true, 'Department reference is required'],
    },
    // Denormalised department name — used for fast filtering in admin views
    department: {
      type: String,
      trim: true,
      default: '',
    },
    // Reference to the contributing user
    uploadedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Uploader reference is required'],
    },
    // Denormalised contributor name — avoids a join on every list query
    contributorName: {
      type: String,
      required: [true, 'Contributor name is required'],
      trim: true,
    },

    // ─── Approval workflow fields ──────────────────────────────────────

    // approvalStatus is the canonical status for this workflow.
    // 'pending'  — awaiting review from the assigned Faculty Admin
    // 'approved' — approved by Faculty Admin or Super Admin
    // 'rejected' — rejected; rejectionReason is populated
    approvalStatus: {
      type: String,
      enum: {
        values: ['pending', 'approved', 'rejected'],
        message: 'approvalStatus must be pending, approved, or rejected',
      },
      default: 'pending',
    },

    // Legacy field kept for backward compatibility — always mirrors approvalStatus
    status: {
      type: String,
      enum: {
        values: ['pending', 'approved', 'rejected'],
        message: 'Status must be pending, approved, or rejected',
      },
      default: 'pending',
    },

    // The Faculty Admin assigned to review this material.
    // Set automatically on upload based on the material's department.
    // Null if no Faculty Admin is active for that department.
    assignedAdmin: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    // Denormalised name of the assigned admin for display purposes
    assignedAdminName: {
      type: String,
      default: null,
    },

    // Who ultimately approved or rejected (Faculty Admin or Super Admin)
    approvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    approvedByName: {
      type: String,
      default: null,
    },
    approvedAt: {
      type: Date,
      default: null,
    },

    // Populated when approvalStatus = 'rejected'
    rejectionReason: {
      type: String,
      trim: true,
      default: null,
    },

    // Admin review comment — visible to contributor after approve OR reject
    reviewComment: {
      type: String,
      trim: true,
      default: null,
    },

    // ─── Per-material rating stats (denormalised for fast reads) ──────────
    // Recalculated automatically when a MaterialRating is created/updated/deleted.
    avgRating: {
      type: Number,
      default: 0,
      min: 0,
      max: 5,
    },
    totalRatings: {
      type: Number,
      default: 0,
      min: 0,
    },
    // View counter for videos and materials
    views: {
      type: Number,
      default: 0,
      min: 0,
    },
  },
  {
    timestamps: true, // createdAt + updatedAt
    toJSON: {
      transform(doc, ret) {
        ret.id = ret._id.toString();
        ret.courseId = ret.courseId?.toString?.() ?? ret.courseId;
        ret.departmentId = ret.departmentId?.toString?.() ?? ret.departmentId;
        ret.uploadedBy = ret.uploadedBy?.toString?.() ?? ret.uploadedBy;
        ret.assignedAdmin = ret.assignedAdmin?.toString?.() ?? ret.assignedAdmin;
        ret.approvedBy = ret.approvedBy?.toString?.() ?? ret.approvedBy;
        delete ret._id;
        delete ret.__v;
        delete ret.filePublicId; // Internal field, never sent to clients
        return ret;
      },
    },
  }
);

// ─── Indexes ──────────────────────────────────────────────────────────
materialSchema.index({ courseId: 1, approvalStatus: 1 });
materialSchema.index({ uploadedBy: 1 });
materialSchema.index({ approvalStatus: 1 });
materialSchema.index({ assignedAdmin: 1, approvalStatus: 1 }); // Faculty Admin queue
materialSchema.index({ departmentId: 1, approvalStatus: 1 });

module.exports = mongoose.model('Material', materialSchema);
