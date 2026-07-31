/**
 * models/Course.js — Mongoose schema for courses within a department
 *
 * Fields:
 *  - name         Course full name
 *  - code         Course code (e.g. CSE101)
 *  - departmentId Reference to Department document
 *  - semester     e.g. "Spring 2025" or "1st Semester"
 *  - credit       Credit hours (number)
 *  - status       active | inactive (default: active)
 */

const mongoose = require('mongoose');

const courseSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Course name is required'],
      trim: true,
    },
    code: {
      type: String,
      required: [true, 'Course code is required'],
      trim: true,
      uppercase: true,
    },
    departmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Department',
      required: [true, 'Department reference is required'],
    },
    semester: {
      type: String,
      trim: true,
      default: '',
    },
    credit: {
      type: Number,
      min: [0, 'Credit cannot be negative'],
      default: 3,
    },
    status: {
      type: String,
      enum: {
        values: ['active', 'inactive'],
        message: 'Status must be active or inactive',
      },
      default: 'active',
    },
  },
  {
    timestamps: true,
    toJSON: {
      transform(doc, ret) {
        ret.id = ret._id.toString();
        ret.departmentId = ret.departmentId?.toString?.() ?? ret.departmentId;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

module.exports = mongoose.model('Course', courseSchema);
