import 'package:flutter/material.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/firestore_service.dart';

/// Bottom sheet allowing a student to save any real resource (PDF, Image, Video)
/// into an existing folder or create a new folder on the fly with duplicate protection.
class SaveToFolderSheet extends StatefulWidget {
  final String materialId;
  final String? courseId;
  final String? materialTitle;
  final VoidCallback? onSaved;

  const SaveToFolderSheet({
    super.key,
    required this.materialId,
    this.courseId,
    this.materialTitle,
    this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required String materialId,
    String? courseId,
    String? materialTitle,
    VoidCallback? onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SaveToFolderSheet(
        materialId: materialId,
        courseId: courseId,
        materialTitle: materialTitle,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<SaveToFolderSheet> createState() => _SaveToFolderSheetState();
}

class _SaveToFolderSheetState extends State<SaveToFolderSheet> {
  final FirestoreService _firestoreService = FirestoreService();

  List<Map<String, dynamic>> _folders = [];
  bool _isLoading = true;
  String? _savingFolderId;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() => _isLoading = true);
    try {
      final res = await _firestoreService.getFolders();
      final list = (res['folders'] as List<dynamic>?) ?? [];
      if (mounted) {
        setState(() {
          _folders = list.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToFolder(Map<String, dynamic> folder) async {
    final folderId = (folder['_id'] ?? folder['id'] ?? '').toString();
    final folderName = folder['name'] ?? 'Folder';
    if (folderId.isEmpty) return;

    setState(() => _savingFolderId = folderId);

    try {
      await _firestoreService.saveMaterialToFolder(
        folderId,
        widget.materialId,
        courseId: widget.courseId,
      );

      if (mounted) {
        setState(() => _savingFolderId = null);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Saved to "$folderName"')),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        widget.onSaved?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _savingFolderId = null);
        final rawMsg = e.toString();
        final cleanMsg = rawMsg
            .replaceAll('Exception: ', '')
            .replaceAll('ValidationException: ', '')
            .replaceAll('ConflictException: ', '');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cleanMsg.isNotEmpty ? cleanMsg : 'Already saved in this folder'),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.create_new_folder_rounded, color: AppTheme.primaryColor, size: 22),
            SizedBox(width: 8),
            Text('New Folder', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. Algorithms For Mid',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF334155)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);

              try {
                final newFolder = await _firestoreService.createFolder(name);
                await _loadFolders();
                // Automatically save the material into this newly created folder
                await _saveToFolder(newFolder);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not create folder: ${e.toString()}'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Create & Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Save to Folder',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  if (widget.materialTitle != null && widget.materialTitle!.isNotEmpty)
                    Text(
                      widget.materialTitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Create New Folder Button ────────────────────────
          InkWell(
            onTap: _showCreateFolderDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryColor, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Create New Folder',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Folders List ────────────────────────────────────
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
            )
          else if (_folders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.folder_open_rounded, size: 40, color: theme.disabledColor),
                    const SizedBox(height: 8),
                    Text(
                      'No folders yet',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create your first folder above to organize your resources.',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11, color: theme.disabledColor),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.35,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _folders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final folder = _folders[index];
                  final folderId = (folder['_id'] ?? folder['id'] ?? '').toString();
                  final folderName = folder['name'] ?? 'Folder';
                  final count = (folder['count'] as num?)?.toInt() ?? 0;
                  final isSaving = _savingFolderId == folderId;

                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.folder_rounded, color: AppTheme.primaryColor, size: 20),
                      ),
                      title: Text(
                        folderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        '$count saved items',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      trailing: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _saveToFolder(folder),
                              child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
