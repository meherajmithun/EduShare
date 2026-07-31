import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:edushare/core/theme.dart';
import 'package:edushare/core/services/auth_service.dart';
import 'package:edushare/widgets/custom_button.dart';
import 'package:edushare/widgets/custom_textfield.dart';
import 'package:edushare/widgets/glass_card.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _designationController;

  Uint8List? _selectedPhotoBytes;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _designationController = TextEditingController(text: user?.designation ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _selectedPhotoBytes = file.bytes;
            _isUploadingPhoto = true;
          });

          final authService = Provider.of<AuthService>(context, listen: false);
          final error = await authService.updateProfilePhotoBytes(
            file.bytes!,
            file.name,
          );

          if (mounted) {
            setState(() => _isUploadingPhoto = false);
            if (error != null) {
              _showSnackBar(error, isError: true);
            } else {
              _showSnackBar('Profile picture updated!');
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        _showSnackBar('Failed to select image.', isError: true);
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final error = await authService.updateProfile(
      name: _nameController.text.trim(),
      bio: _bioController.text.trim(),
      designation: _designationController.text.trim(),
    );

    if (mounted) {
      if (error != null) {
        _showSnackBar(error, isError: true);
      } else {
        _showSnackBar('Profile updated successfully!');
        Navigator.of(context).pop();
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthService>().currentUser;
    final isLoading = context.watch<AuthService>().isLoading;

    if (user == null) return const SizedBox.shrink();

    final profilePhotoUrl = user.profilePhotoUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            // Avatar picker
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.accentColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _selectedPhotoBytes != null
                          ? Image.memory(
                              _selectedPhotoBytes!,
                              fit: BoxFit.cover,
                              width: 100,
                              height: 100,
                            )
                          : (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty)
                              ? Image.network(
                                  profilePhotoUrl,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                  errorBuilder: (_, __, ___) => _buildInitialsAvatar(user.name),
                                )
                              : _buildInitialsAvatar(user.name),
                    ),
                  ),

                  if (_isUploadingPhoto)
                    Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    ),

                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap camera icon to update picture',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: theme.disabledColor,
              ),
            ),
            const SizedBox(height: 28),

            // Form
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomTextField(
                      label: 'FULL NAME',
                      hint: 'Enter your full name',
                      controller: _nameController,
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    CustomTextField(
                      label: 'BIO / ABOUT ME',
                      hint: 'Tell us a bit about yourself...',
                      controller: _bioController,
                      prefixIcon: Icons.info_outline_rounded,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    CustomTextField(
                      label: 'DESIGNATION',
                      hint: 'e.g. Student / Assistant Professor',
                      controller: _designationController,
                      prefixIcon: Icons.work_outline_rounded,
                    ),
                    const SizedBox(height: 30),

                    CustomButton(
                      text: 'Save Changes',
                      isLoading: isLoading,
                      onPressed: _handleSave,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(String name) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 36,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
