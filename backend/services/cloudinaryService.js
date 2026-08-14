/**
 * services/cloudinaryService.js — Cloudinary upload helpers
 *
 * Uses multer memoryStorage + streamifier to stream uploads directly
 * to Cloudinary v2 — avoids the multer-storage-cloudinary peer-dep conflict.
 *
 * Provides:
 *  - uploadDoc      — multer middleware for documents/PDFs/images (20 MB)
 *  - uploadVideo    — multer middleware for video files (200 MB)
 *  - upload         — alias for uploadDoc (backward compat)
 *  - uploadBuffer() — upload a raw Buffer as a document/raw resource
 *  - uploadVideoBuffer() — upload a raw Buffer as a video resource
 *  - deleteFile()   — remove a file from Cloudinary by public_id
 */

const path = require('path');
const cloudinary = require('cloudinary').v2;
const multer = require('multer');
const streamifier = require('streamifier');

// Configure Cloudinary credentials from environment
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// ─── Allowed mime types & extensions ──────────────────────────────────────

const ALLOWED_DOC_MIMES = [
  'application/pdf',
  'application/x-pdf',
  'application/acrobat',
  'applications/vnd.pdf',
  'text/pdf',
  'text/x-pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'text/plain',
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'image/gif',
  'application/octet-stream',
];

const ALLOWED_DOC_EXTENSIONS = ['.pdf', '.doc', '.docx', '.ppt', '.pptx', '.txt', '.jpg', '.jpeg', '.png', '.webp', '.gif'];

const ALLOWED_VIDEO_MIMES = [
  'video/mp4',
  'video/x-matroska',
  'video/quicktime',
  'video/x-msvideo',
  'video/webm',
  'video/mpeg',
  'video/ogg',
  'video/3gpp',
  'video/x-flv',
  'application/octet-stream', // some devices send this for videos
];

const ALLOWED_VIDEO_EXTENSIONS = ['.mp4', '.mkv', '.mov', '.avi', '.webm', '.mpeg', '.ogv', '.3gp', '.flv'];

const ALL_ALLOWED_EXTENSIONS = [...ALLOWED_DOC_EXTENSIONS, ...ALLOWED_VIDEO_EXTENSIONS];
const ALL_ALLOWED_MIMES = [...ALLOWED_DOC_MIMES, ...ALLOWED_VIDEO_MIMES];

// ─── Multer — Universal Material Upload (200 MB) ─────────────────────────
// Accepts documents, PDFs, images, and videos for academic materials.
const uploadMaterialFile = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 200 * 1024 * 1024 }, // 200 MB
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const isAllowedExt = ALL_ALLOWED_EXTENSIONS.includes(ext);
    const isAllowedMime = ALL_ALLOWED_MIMES.includes(file.mimetype) ||
        file.mimetype.startsWith('image/') ||
        file.mimetype.startsWith('video/') ||
        file.mimetype === 'application/octet-stream';

    if (isAllowedExt || isAllowedMime) {
      cb(null, true);
    } else {
      cb(new Error(`File type not supported. Allowed: PDF, DOC, DOCX, JPG, PNG, WEBP, MP4, MOV, MKV. (Received: ${ext || file.mimetype})`), false);
    }
  },
});

// ─── Multer — Document/PDF/Image (50 MB) ─────────────────────────────────
const uploadDoc = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 50 * 1024 * 1024 }, // 50 MB
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const isAllowedExt = ALLOWED_DOC_EXTENSIONS.includes(ext);
    const isAllowedMime = ALLOWED_DOC_MIMES.includes(file.mimetype) ||
        file.mimetype.startsWith('image/') ||
        file.mimetype === 'application/octet-stream';

    if (isAllowedExt || isAllowedMime) {
      cb(null, true);
    } else {
      cb(new Error('File type not supported. Allowed: PDF, DOC, DOCX, JPG, PNG, WEBP.'), false);
    }
  },
});

// ─── Multer — Video (200 MB) ────────────────────────────────────────────
const uploadVideo = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 200 * 1024 * 1024 }, // 200 MB
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const isAllowedExt = ALLOWED_VIDEO_EXTENSIONS.includes(ext);
    const isAllowedMime = ALLOWED_VIDEO_MIMES.includes(file.mimetype) ||
        file.mimetype.startsWith('video/') ||
        file.mimetype === 'application/octet-stream';

    if (isAllowedExt || isAllowedMime) {
      cb(null, true);
    } else {
      cb(new Error('Video format not supported. Allowed: MP4, MKV, MOV, AVI, WebM.'), false);
    }
  },
});

// Backward-compatible alias
const upload = uploadMaterialFile;
const smartUpload = uploadMaterialFile;

/**
 * Stream a Buffer to Cloudinary as an auto resource (PDFs, docs, images).
 * @param {Buffer} buffer
 * @param {string} [folder]
 * @param {string} [publicId]  Optional custom public_id
 * @returns {Promise<{url: string, publicId: string}>}
 */
const uploadBuffer = (buffer, folder = 'edushare/materials', publicId) => {
  return new Promise((resolve, reject) => {
    const opts = { folder, resource_type: 'auto' };
    if (publicId) opts.public_id = publicId;

    const uploadStream = cloudinary.uploader.upload_stream(opts, (error, result) => {
      if (error) return reject(error);
      resolve({ url: result.secure_url, publicId: result.public_id });
    });

    streamifier.createReadStream(buffer).pipe(uploadStream);
  });
};

/**
 * Stream a Buffer to Cloudinary as a video resource.
 * @param {Buffer} buffer
 * @param {string} [folder]
 * @param {string} [publicId]  Optional custom public_id
 * @returns {Promise<{url: string, publicId: string}>}
 */
const uploadVideoBuffer = (buffer, folder = 'edushare/videos', publicId) => {
  return new Promise((resolve, reject) => {
    const opts = { folder, resource_type: 'video' };
    if (publicId) opts.public_id = publicId;

    const uploadStream = cloudinary.uploader.upload_stream(opts, (error, result) => {
      if (error) return reject(error);
      resolve({ url: result.secure_url, publicId: result.public_id });
    });

    streamifier.createReadStream(buffer).pipe(uploadStream);
  });
};

/**
 * Delete a file from Cloudinary by its public_id.
 * @param {string} publicId
 * @param {string} [resourceType='raw']
 */
const deleteFile = async (publicId, resourceType = 'raw') => {
  try {
    await cloudinary.uploader.destroy(publicId, { resource_type: resourceType });
  } catch (err) {
    console.error(`[Cloudinary] Failed to delete ${publicId}:`, err.message);
  }
};

module.exports = { upload, uploadDoc, uploadVideo, smartUpload, uploadMaterialFile, uploadBuffer, uploadVideoBuffer, deleteFile };
