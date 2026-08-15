const mongoose = require('mongoose');

const pdfProgressSchema = new mongoose.Schema(
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
    },
    currentPage: {
      type: Number,
      default: 1,
    },
    totalPages: {
      type: Number,
      default: 1,
    },
    progressPercentage: {
      type: Number,
      default: 0,
    },
    lastReadAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

pdfProgressSchema.index({ userId: 1, materialId: 1 }, { unique: true });
pdfProgressSchema.index({ userId: 1, lastReadAt: -1 });

module.exports = mongoose.model('PdfProgress', pdfProgressSchema);
