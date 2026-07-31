/**
 * services/notificationService.js — Notification creation helpers
 *
 * Called from materialController (on upload), adminController (on approve/reject),
 * authController (on Admin registration), and superAdminController (on Admin
 * approve/reject). Never throws — notification failures must never break the
 * primary operation.
 */

const Notification = require('../models/Notification');
const User = require('../models/User');

/**
 * Notify the assigned Admin that a new material was uploaded to their department.
 */
const notifyFacultyAdminOnUpload = async ({ material, uploader }) => {
  try {
    if (!material.assignedAdmin) return; // No Admin assigned — skip

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
    console.error('[NotificationService] Failed to notify Admin on upload:', err.message);
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

/**
 * Notify the Super Admin that a new Admin registration is pending their approval.
 * Finds the super_admin user automatically.
 */
const notifySuperAdminOnNewAdmin = async ({ newAdmin }) => {
  try {
    const superAdmin = await User.findOne({ role: 'super_admin', isActive: true });
    if (!superAdmin) return; // No Super Admin found — skip

    await Notification.create({
      recipient: superAdmin._id,
      sender: newAdmin._id,
      senderName: newAdmin.name,
      title: 'New Admin Registration',
      message: `${newAdmin.name} (${newAdmin.email}) has submitted an Admin registration request for the ${newAdmin.department || 'N/A'} department. Review and approve or reject.`,
      type: 'admin_registered',
    });
  } catch (err) {
    console.error('[NotificationService] Failed to notify Super Admin on new Admin registration:', err.message);
  }
};

const sendPushNotificationIfFcmExists = async (user, title, body) => {
  if (user && user.fcmToken && global.adminFcm) {
    try {
      await global.adminFcm.messaging().send({
        token: user.fcmToken,
        notification: { title, body },
      });
    } catch (err) {
      console.error('[NotificationService] Push notification error:', err.message);
    }
  }
};

/**
 * Notify the Admin that their account has been approved by the Super Admin.
 */
const notifyAdminOnApproval = async ({ admin, superAdmin }) => {
  try {
    const title = 'Account Approved ✓';
    const message = `Your Admin account has been approved by ${superAdmin.name}. You can now log in to EduShare.`;

    await Notification.create({
      recipient: admin._id,
      sender: superAdmin._id,
      senderName: superAdmin.name,
      title,
      message,
      type: 'admin_approved',
    });

    await sendPushNotificationIfFcmExists(admin, title, message);
  } catch (err) {
    console.error('[NotificationService] Failed to notify Admin on approval:', err.message);
  }
};

/**
 * Notify the Admin that their account has been rejected by the Super Admin.
 */
const notifyAdminOnRejection = async ({ admin, superAdmin, reason }) => {
  try {
    const reasonText = reason && reason.trim()
      ? reason.trim()
      : 'No reason provided.';
    const title = 'Account Registration Rejected';
    const message = `Your Admin registration was rejected by ${superAdmin.name}. Reason: ${reasonText}`;

    await Notification.create({
      recipient: admin._id,
      sender: superAdmin._id,
      senderName: superAdmin.name,
      title,
      message,
      type: 'admin_rejected',
    });

    await sendPushNotificationIfFcmExists(admin, title, message);
  } catch (err) {
    console.error('[NotificationService] Failed to notify Admin on rejection:', err.message);
  }
};

/**
 * Notify the Faculty Admin that a new contributor has registered for their department.
 * @param {Object} contributor — newly registered User document
 * @param {Object} facultyAdmin — the active Faculty Admin for the department
 */
const notifyFacultyAdminOnContributorRegistration = async ({ contributor, facultyAdmin }) => {
  try {
    if (!facultyAdmin) return; // No Faculty Admin assigned — skip (Super Admin will review)

    await Notification.create({
      recipient: facultyAdmin._id,
      sender: contributor._id,
      senderName: contributor.name,
      title: 'New Contributor Registration',
      message: `${contributor.name} (${contributor.email}) has registered as a Contributor in the ${contributor.department || 'your'} department and is awaiting your approval.`,
      type: 'contributor_registered',
    });
  } catch (err) {
    console.error('[NotificationService] Failed to notify Faculty Admin on contributor registration:', err.message);
  }
};

/**
 * Notify the contributor that their account has been approved by the Faculty Admin.
 */
const notifyContributorOnAccountApproval = async ({ contributor, admin }) => {
  try {
    await Notification.create({
      recipient: contributor._id,
      sender: admin._id,
      senderName: admin.name,
      title: 'Account Approved ✓',
      message: `Your contributor account has been approved by ${admin.name}. You can now log in to EduShare and upload materials.`,
      type: 'contributor_approved',
    });
  } catch (err) {
    console.error('[NotificationService] Failed to notify contributor on approval:', err.message);
  }
};

/**
 * Notify the contributor that their account has been rejected, with the reason.
 */
const notifyContributorOnAccountRejection = async ({ contributor, admin, reason }) => {
  try {
    const reasonText = reason && reason.trim() ? reason.trim() : 'No reason provided.';

    await Notification.create({
      recipient: contributor._id,
      sender: admin._id,
      senderName: admin.name,
      title: 'Contributor Registration Rejected',
      message: `Your contributor registration was rejected by ${admin.name}. Reason: ${reasonText}`,
      type: 'contributor_rejected',
    });
  } catch (err) {
    console.error('[NotificationService] Failed to notify contributor on rejection:', err.message);
  }
};

module.exports = {
  notifyFacultyAdminOnUpload,
  notifyContributorOnApproval,
  notifyContributorOnRejection,
  notifySuperAdminOnNewAdmin,
  notifyAdminOnApproval,
  notifyAdminOnRejection,
  notifyFacultyAdminOnContributorRegistration,
  notifyContributorOnAccountApproval,
  notifyContributorOnAccountRejection,
};
