/**
 * models/Follow.js — Follow relationship between a student and a contributor.
 *
 * A student can follow a contributor to receive updates about new materials.
 * Compound unique index prevents duplicate follows.
 */

const mongoose = require('mongoose');

const followSchema = new mongoose.Schema(
  {
    // The user who is following (typically a student)
    follower: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Follower is required'],
      index: true,
    },

    // The contributor being followed
    following: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Following target is required'],
      index: true,
    },
  },
  {
    timestamps: true,
    toJSON: {
      transform(doc, ret) {
        ret.id = ret._id.toString();
        ret.follower = ret.follower?.toString?.() ?? ret.follower;
        ret.following = ret.following?.toString?.() ?? ret.following;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

// Prevent duplicate follows
followSchema.index({ follower: 1, following: 1 }, { unique: true });

module.exports = mongoose.model('Follow', followSchema);
