/**
 * services/notificationService.js — Notification creation helpers
 *
 * Called from materialController (on upload) and adminController
 * (on approve/reject). Never throws — notification failures must
 * never break the primary operation.
 */

const Notification = require('../models/Notification');

/**
 * Notify the assigned Faculty Admin that a new material was uploaded to their department.
 */
const notifyFacultyAdminOnUpload = async ({ material, uploader }) => {
  try {
    if (!material.assignedAdmin) return; // No Faculty Admin assigned — skip

    await Notification.create({
      recipient: material.assignedAdmin,
      sender: uploader._id,
      senderName: uploader.name,
      title: 'New Material for Review',
      message: `${uploader.name} uploaded "${material.title}" in ${material.department || 'your department'} and it needs your approval.`,
      type: 'upload_assigned',
      materialId: material._id,
      materialTitle: material.title,
    });
  } catch (err) {
    console.error('[NotificationService] Failed to notify Faculty Admin on upload:', err.message);
  }
};

/**
 * Notify the contributor that their material was approved.
 */
const notifyContributorOnApproval = async ({ material, admin }) => {
  try {
    await Notification.create({
      recipient: material.uploadedBy,
      sender: admin._id,
      senderName: admin.name,
      title: 'Material Approved ✓',
      message: `Great news! Your material "${material.title}" has been approved by ${admin.name} and is now live.`,
      type: 'material_approved',
      materialId: material._id,
      materialTitle: material.title,
    });
  } catch (err) {
    console.error('[NotificationService] Failed to notify contributor on approval:', err.message);
  }
};

/**
 * Notify the contributor that their material was rejected, with the reason.
 */
const notifyContributorOnRejection = async ({ material, admin, reason }) => {
  try {
    const reasonText = reason && reason.trim()
      ? reason.trim()
      : 'No reason provided.';

    await Notification.create({
      recipient: material.uploadedBy,
      sender: admin._id,
      senderName: admin.name,
      title: 'Material Rejected',
      message: `Your material "${material.title}" was rejected by ${admin.name}. Reason: ${reasonText}`,
      type: 'material_rejected',
      materialId: material._id,
      materialTitle: material.title,
    });
  } catch (err) {
    console.error('[NotificationService] Failed to notify contributor on rejection:', err.message);
  }
};

module.exports = {
  notifyFacultyAdminOnUpload,
  notifyContributorOnApproval,
  notifyContributorOnRejection,
};
