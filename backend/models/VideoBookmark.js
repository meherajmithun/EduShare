const mongoose = require('mongoose');

const videoBookmarkSchema = new mongoose.Schema(
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
  },
  { timestamps: true }
);

videoBookmarkSchema.index({ userId: 1, materialId: 1 }, { unique: true });
videoBookmarkSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('VideoBookmark', videoBookmarkSchema);
