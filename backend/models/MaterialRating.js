/**
 * models/MaterialRating.js — Per-material student rating schema
 *
 * Each student can rate each approved material once (1–5 stars + optional review).
 * When a rating is created/updated/deleted, the material's avgRating/totalRatings
 * are recalculated. The contributor's overall avgRating is then recalculated
 * from all their material ratings.
 */

const mongoose = require('mongoose');

const materialRatingSchema = new mongoose.Schema(
  {
    materialId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Material',
      required: [true, 'Material reference is required'],
      index: true,
    },
    // The contributor who owns the material (denormalised for fast recalc)
    contributorId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Contributor reference is required'],
      index: true,
    },
    ratedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Rater reference is required'],
    },
    ratedByName: {
      type: String,
      trim: true,
      default: '',
    },
    stars: {
      type: Number,
      required: [true, 'Star rating is required'],
      min: [1, 'Minimum rating is 1 star'],
      max: [5, 'Maximum rating is 5 stars'],
    },
    review: {
      type: String,
      trim: true,
      maxlength: [500, 'Review cannot exceed 500 characters'],
      default: '',
    },
  },
  {
    timestamps: true,
    toJSON: {
      transform(doc, ret) {
        ret.id = ret._id.toString();
        ret.materialId = ret.materialId?.toString?.() ?? ret.materialId;
        ret.contributorId = ret.contributorId?.toString?.() ?? ret.contributorId;
        ret.ratedBy = ret.ratedBy?.toString?.() ?? ret.ratedBy;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

// One rating per student per material
materialRatingSchema.index({ materialId: 1, ratedBy: 1 }, { unique: true });

module.exports = mongoose.model('MaterialRating', materialRatingSchema);
