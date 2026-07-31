/**
 * models/Rating.js — Mongoose schema for contributor ratings
 *
 * Business rules:
 *   - Only students can create / update / delete ratings.
 *   - One rating per student per contributor (compound unique index).
 *   - stars: 1–5 integer, required.
 *   - review: optional text (max 500 chars).
 *   - Whenever a rating changes, the controller calls recalcContributorRating()
 *     to update User.avgRating and User.totalRatings.
 */

const mongoose = require('mongoose');

const ratingSchema = new mongoose.Schema(
  {
    // The contributor being rated
    contributor: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Contributor reference is required'],
    },

    // The student who submitted the rating
    ratedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Rater reference is required'],
    },

    // Denormalised name of the student (avoids a join on every list query)
    ratedByName: {
      type: String,
      trim: true,
      default: '',
    },

    // 1–5 star integer rating
    stars: {
      type: Number,
      required: [true, 'Star rating is required'],
      min: [1, 'Rating must be at least 1 star'],
      max: [5, 'Rating cannot exceed 5 stars'],
      validate: {
        validator: Number.isInteger,
        message: 'Stars must be a whole number (1–5)',
      },
    },

    // Optional text review
    review: {
      type: String,
      trim: true,
      maxlength: [500, 'Review cannot exceed 500 characters'],
      default: '',
    },
  },
  {
    timestamps: true, // createdAt + updatedAt
    toJSON: {
      transform(doc, ret) {
        ret.id = ret._id.toString();
        ret.contributor = ret.contributor?.toString?.() ?? ret.contributor;
        ret.ratedBy = ret.ratedBy?.toString?.() ?? ret.ratedBy;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

// ─── Indexes ──────────────────────────────────────────────────────────

// One rating per student per contributor
ratingSchema.index({ contributor: 1, ratedBy: 1 }, { unique: true });

// Fast lookup of all ratings for a contributor (profile page)
ratingSchema.index({ contributor: 1, createdAt: -1 });

module.exports = mongoose.model('Rating', ratingSchema);
