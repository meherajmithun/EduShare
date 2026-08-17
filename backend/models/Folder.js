const mongoose = require('mongoose');

const folderSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    departmentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Department',
      default: null,
    },
    color: {
      type: String,
      default: '#3B82F6',
    },
  },
  { timestamps: true }
);

folderSchema.index({ userId: 1, name: 1 }, { unique: true });
folderSchema.index({ userId: 1, createdAt: -1 });

module.exports = mongoose.model('Folder', folderSchema);
