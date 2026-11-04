import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/storage_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/cosmic_button.dart';
import '../../widgets/cosmic_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserRepository _userRepository = UserRepository();
  final StorageRepository _storageRepository = StorageRepository();

  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;

  File? _newImageFile;
  Uint8List? _newImageBytes;
  String? _newImageExtension;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthRepository>(context, listen: false).currentUser!;
    _displayNameController = TextEditingController(text: user.displayName);
    _bioController = TextEditingController(text: user.bio);
    _phoneController = TextEditingController(text: user.phone);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
        setState(() {
          _newImageBytes = bytes;
          _newImageExtension = ext;
          if (!kIsWeb) {
            _newImageFile = File(picked.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error choosing photo: $e')),
        );
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primaryLight),
              title: const Text('Choose from Gallery', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.secondary),
              title: const Text('Take a Photo', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authRepo = Provider.of<AuthRepository>(context, listen: false);
    final user = authRepo.currentUser!;

    setState(() => _isSaving = true);
    try {
      String? photoUrl;
      if (_newImageBytes != null || _newImageFile != null) {
        photoUrl = await _storageRepository.uploadProfilePhoto(
          userId: user.uid,
          imageBytes: _newImageBytes,
          imageFile: _newImageFile,
          fileExtension: _newImageExtension,
        );
      }

      await _userRepository.updateUserProfile(
        uid: user.uid,
        name: _displayNameController.text,
        displayName: _displayNameController.text,
        bio: _bioController.text,
        phone: _phoneController.text,
        photoURL: photoUrl,
        profilePhoto: photoUrl,
      );

      await authRepo.fetchCurrentUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.callRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthRepository>(context).currentUser!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar Change
              Center(
                child: Stack(
                  children: [
                    _newImageBytes != null
                        ? ClipOval(
                            child: Image.memory(_newImageBytes!, width: 96, height: 96, fit: BoxFit.cover),
                          )
                        : (_newImageFile != null
                            ? ClipOval(
                                child: Image.file(_newImageFile!, width: 96, height: 96, fit: BoxFit.cover),
                              )
                            : AvatarWidget(
                                name: user.displayName,
                                photoUrl: user.profilePhoto,
                                radius: 48,
                              )),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showImagePickerSheet,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Change Profile Photo', style: TextStyle(color: AppColors.primaryLight, fontSize: 13)),
              ),
              const SizedBox(height: 28),

              // Username (Readonly)
              CosmicTextField(
                controller: TextEditingController(text: '@${user.username}'),
                labelText: 'Username',
                hintText: '',
                enabled: false,
                prefixIcon: Icons.alternate_email,
              ),
              const SizedBox(height: 16),

              // Display Name
              CosmicTextField(
                controller: _displayNameController,
                labelText: 'Display Name',
                hintText: 'Your name',
                prefixIcon: Icons.badge_outlined,
                validator: Validators.validateDisplayName,
              ),
              const SizedBox(height: 16),

              // Bio
              CosmicTextField(
                controller: _bioController,
                labelText: 'Bio',
                hintText: 'Tell the Cosmic universe about yourself',
                prefixIcon: Icons.info_outline,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Phone
              CosmicTextField(
                controller: _phoneController,
                labelText: 'Phone',
                hintText: '+91 98765 43210',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: Validators.validatePhone,
              ),
              const SizedBox(height: 32),

              // Save Button
              CosmicButton(
                text: 'Save Changes',
                isLoading: _isSaving,
                onPressed: _saveProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
