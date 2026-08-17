const Folder = require('../models/Folder');
const VideoBookmark = require('../models/VideoBookmark');
const Material = require('../models/Material');
const { success, error, createError } = require('../utils/apiResponse');

// ─── GET /api/folders ──────────────────────────────────────────────────
// Returns the logged-in student's folders with real item counts
const getFolders = async (req, res) => {
  const userId = req.user._id;

  const folders = await Folder.find({ userId }).sort({ createdAt: -1 }).lean();

  const foldersWithCounts = await Promise.all(
    folders.map(async (f) => {
      const count = await VideoBookmark.countDocuments({
        userId,
        folderId: f._id,
      });
      return {
        _id: f._id,
        id: f._id.toString(),
        name: f.name,
        color: f.color || '#3B82F6',
        departmentId: f.departmentId,
        count,
        createdAt: f.createdAt,
        updatedAt: f.updatedAt,
      };
    })
  );

  const totalSavedCount = await VideoBookmark.countDocuments({ userId });

  res.json(
    success(
      {
        folders: foldersWithCounts,
        totalSavedCount,
      },
      'Folders retrieved successfully'
    )
  );
};

// ─── POST /api/folders ─────────────────────────────────────────────────
// Creates a new folder for the authenticated student
const createFolder = async (req, res) => {
  const userId = req.user._id;
  const { name, color } = req.body;

  if (!name || !name.trim()) {
    throw createError('Folder name is required', 400);
  }

  const trimmedName = name.trim();

  // Check if folder with same name exists for this user
  const existing = await Folder.findOne({ userId, name: trimmedName });
  if (existing) {
    throw createError('A folder with this name already exists', 400);
  }

  const folder = await Folder.create({
    userId,
    name: trimmedName,
    departmentId: req.user.departmentId || null,
    color: color || '#3B82F6',
  });

  res.status(201).json(
    success(
      {
        _id: folder._id,
        id: folder._id.toString(),
        name: folder.name,
        color: folder.color,
        count: 0,
        createdAt: folder.createdAt,
        updatedAt: folder.updatedAt,
      },
      'Folder created successfully'
    )
  );
};

// ─── PUT /api/folders/:id ──────────────────────────────────────────────
// Renames a folder belonging to the authenticated student
const renameFolder = async (req, res) => {
  const userId = req.user._id;
  const { id } = req.params;
  const { name, color } = req.body;

  if (!name || !name.trim()) {
    throw createError('Folder name is required', 400);
  }

  const trimmedName = name.trim();

  const folder = await Folder.findOne({ _id: id, userId });
  if (!folder) {
    throw createError('Folder not found', 404);
  }

  // Check if another folder with this name already exists
  const duplicate = await Folder.findOne({
    userId,
    name: trimmedName,
    _id: { $ne: id },
  });
  if (duplicate) {
    throw createError('A folder with this name already exists', 400);
  }

  folder.name = trimmedName;
  if (color) folder.color = color;
  await folder.save();

  const count = await VideoBookmark.countDocuments({ userId, folderId: folder._id });

  res.json(
    success(
      {
        _id: folder._id,
        id: folder._id.toString(),
        name: folder.name,
        color: folder.color,
        count,
        createdAt: folder.createdAt,
        updatedAt: folder.updatedAt,
      },
      'Folder updated successfully'
    )
  );
};

// ─── DELETE /api/folders/:id ───────────────────────────────────────────
// Deletes a folder and all bookmark associations inside it
const deleteFolder = async (req, res) => {
  const userId = req.user._id;
  const { id } = req.params;

  const folder = await Folder.findOneAndDelete({ _id: id, userId });
  if (!folder) {
    throw createError('Folder not found', 404);
  }

  // Delete bookmarks associated with this folder
  await VideoBookmark.deleteMany({ userId, folderId: id });

  res.json(success(null, 'Folder and its saved items deleted successfully'));
};

// ─── GET /api/folders/:id/materials ────────────────────────────────────
// Returns materials saved inside a specific folder
const getFolderMaterials = async (req, res) => {
  const userId = req.user._id;
  const { id } = req.params;

  const folder = await Folder.findOne({ _id: id, userId });
  if (!folder) {
    throw createError('Folder not found', 404);
  }

  const bookmarks = await VideoBookmark.find({ userId, folderId: id })
    .sort({ createdAt: -1 })
    .populate('materialId')
    .populate('courseId', 'name code departmentId')
    .lean();

  const items = bookmarks
    .filter((b) => b.materialId)
    .map((b) => ({
      bookmarkId: b._id,
      folderId: id,
      material: b.materialId,
      course: b.courseId,
      createdAt: b.createdAt,
    }));

  res.json(
    success(
      {
        folder: {
          _id: folder._id,
          id: folder._id.toString(),
          name: folder.name,
          color: folder.color,
          count: items.length,
          createdAt: folder.createdAt,
          updatedAt: folder.updatedAt,
        },
        items,
      },
      'Folder materials retrieved successfully'
    )
  );
};

// ─── POST /api/folders/:id/materials/:materialId ───────────────────────
// Saves a real material into a specific folder (preventing duplicate saves)
const saveMaterialToFolder = async (req, res) => {
  const userId = req.user._id;
  const { id: folderId, materialId } = req.params;
  const { courseId } = req.body;

  const folder = await Folder.findOne({ _id: folderId, userId });
  if (!folder) {
    throw createError('Folder not found', 404);
  }

  const mat = await Material.findById(materialId);
  if (!mat) {
    throw createError('Material not found', 404);
  }

  // Prevent duplicate saves in the same folder
  const existing = await VideoBookmark.findOne({
    userId,
    materialId,
    folderId,
  });

  if (existing) {
    return res.status(400).json(
      error(`This material is already saved in "${folder.name}".`, 400)
    );
  }

  const bookmark = await VideoBookmark.create({
    userId,
    materialId,
    courseId: courseId || mat.courseId,
    folderId,
  });

  // Also ensure a general bookmark entry exists so it shows in "All"
  await VideoBookmark.findOneAndUpdate(
    { userId, materialId, folderId: null },
    {
      userId,
      materialId,
      courseId: courseId || mat.courseId,
      folderId: null,
    },
    { upsert: true, new: true }
  );

  const updatedCount = await VideoBookmark.countDocuments({
    userId,
    folderId,
  });

  res.status(201).json(
    success(
      {
        bookmarkId: bookmark._id,
        folderId,
        materialId,
        folderName: folder.name,
        updatedCount,
      },
      `Material saved to "${folder.name}" successfully`
    )
  );
};

// ─── DELETE /api/folders/:id/materials/:materialId ─────────────────────
// Removes a material from a specific folder
const removeMaterialFromFolder = async (req, res) => {
  const userId = req.user._id;
  const { id: folderId, materialId } = req.params;

  const result = await VideoBookmark.findOneAndDelete({
    userId,
    folderId,
    materialId,
  });

  if (!result) {
    throw createError('Material is not in this folder', 404);
  }

  res.json(success(null, 'Material removed from folder successfully'));
};

module.exports = {
  getFolders,
  createFolder,
  renameFolder,
  deleteFolder,
  getFolderMaterials,
  saveMaterialToFolder,
  removeMaterialFromFolder,
};
