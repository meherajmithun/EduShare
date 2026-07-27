/**
 * models/Material.js — Mongoose schema for academic materials
 *
 * A material is either a file (notes/assignment — stored on Cloudinary)
 * or a video link (YouTube / Google Drive URL).
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
    status: {
      type: String,
      enum: {
        values: ['pending', 'approved', 'rejected'],
        message: 'Status must be pending, approved, or rejected',
      },
      default: 'pending',
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
        delete ret._id;
        delete ret.__v;
        delete ret.filePublicId; // Internal field, never sent to clients
        return ret;
      },
    },
  }
);

// ─── Indexes ──────────────────────────────────────────────────────────
// Speed up the most common query patterns
materialSchema.index({ courseId: 1, status: 1 });
materialSchema.index({ uploadedBy: 1 });
materialSchema.index({ status: 1 });

module.exports = mongoose.model('Material', materialSchema);
