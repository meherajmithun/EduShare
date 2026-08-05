const mongoose = require('mongoose');

const videoProgressSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    materialId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Material',
      required: true,
    },
    courseId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Course',
      required: true,
    },
    lastPosition: {
      type: Number,
      default: 0, // seconds
    },
    duration: {
      type: Number,
      default: 0, // seconds
    },
    completed: {
      type: Boolean,
      default: false,
    },
    lastWatchedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

videoProgressSchema.index({ userId: 1, materialId: 1 }, { unique: true });
videoProgressSchema.index({ userId: 1, courseId: 1 });
videoProgressSchema.index({ userId: 1, lastWatchedAt: -1 });

module.exports = mongoose.model('VideoProgress', videoProgressSchema);
