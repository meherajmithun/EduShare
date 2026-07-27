/**
 * models/Notification.js — In-app notification schema
 *
 * Notification types:
 *   upload_assigned   — Faculty Admin receives this when a contributor uploads
 *                       to their department
 *   material_approved — Contributor receives this when their material is approved
 *   material_rejected — Contributor receives this when their material is rejected
 *                       (includes rejectionReason in the message)
 */

const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    // Who the notification is FOR
    recipient: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Recipient is required'],
      index: true,
    },

    // Who triggered the notification (uploader or approving admin)
    sender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Sender is required'],
    },
    senderName: {
      type: String,
      required: true,
      trim: true,
    },

    // Short notification heading
    title: {
      type: String,
      required: [true, 'Title is required'],
      trim: true,
      maxlength: 200,
    },

    // Full notification body
    message: {
      type: String,
      required: [true, 'Message is required'],
      trim: true,
      maxlength: 1000,
    },

    // Notification category
    type: {
      type: String,
      enum: {
        values: ['upload_assigned', 'material_approved', 'material_rejected'],
        message: 'Invalid notification type',
      },
      required: true,
    },

    // Optional reference to the related material
    materialId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Material',
      default: null,
    },
    materialTitle: {
      type: String,
      default: null,
      trim: true,
    },

    isRead: {
      type: Boolean,
      default: false,
      index: true,
    },
  },
  {
    timestamps: true,
    toJSON: {
      transform(doc, ret) {
        ret.id = ret._id.toString();
        ret.recipient = ret.recipient?.toString?.() ?? ret.recipient;
        ret.sender = ret.sender?.toString?.() ?? ret.sender;
        ret.materialId = ret.materialId?.toString?.() ?? ret.materialId;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

// Compound index: fetch all notifications for a user sorted by newest first
notificationSchema.index({ recipient: 1, createdAt: -1 });
// Count unread quickly
notificationSchema.index({ recipient: 1, isRead: 1 });

module.exports = mongoose.model('Notification', notificationSchema);
