/**
 * services/cloudinaryService.js — Cloudinary upload helpers
 *
 * Uses multer memoryStorage + streamifier to stream uploads directly
 * to Cloudinary v2 — avoids the multer-storage-cloudinary peer-dep conflict.
 *
 * Provides:
 *  - upload        — multer middleware (stores file in memory, then streams to Cloudinary)
 *  - uploadBuffer() — upload a raw Buffer directly
 *  - deleteFile()  — remove a file from Cloudinary by public_id
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

// ─── Allowed mime types and extensions ────────────────────────────────
const ALLOWED_MIMES = [
  'application/pdf',
  'application/x-pdf',
  'application/acrobat',
  'applications/vnd.pdf',
  'text/pdf',
  'text/x-pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'image/jpeg',
  'image/jpg',
  'image/png',
  'image/webp',
  'application/octet-stream',
];

const ALLOWED_EXTENSIONS = ['.pdf', '.doc', '.docx', '.jpg', '.jpeg', '.png', '.webp'];

// ─── Multer (memory storage) ───────────────────────────────────────────
// Files land in req.file.buffer — we stream them to Cloudinary manually
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 }, // 20 MB
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname || '').toLowerCase();
    const isAllowedExt = ALLOWED_EXTENSIONS.includes(ext);
    const isAllowedMime = ALLOWED_MIMES.includes(file.mimetype);

    if (isAllowedExt || isAllowedMime) {
      cb(null, true);
    } else {
      cb(new Error('File type not supported. Allowed: PDF, DOC, DOCX, JPG, PNG.'), false);
    }
  },
});

/**
 * Stream a Buffer to Cloudinary.
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

module.exports = { upload, uploadBuffer, deleteFile };
