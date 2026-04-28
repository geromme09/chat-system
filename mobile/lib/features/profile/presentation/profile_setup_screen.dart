
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../data/profile_api.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const _genderOptions = <String>[
    '',
    'Woman',
    'Man',
    'Non-binary',
    'Prefer not to say',
  ];

  final ProfileApi _profileApi = ProfileApi();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _interestsController = TextEditingController();

  String _selectedGender = '';
  XFile? _selectedAvatar;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final profile = appSession.profile;
    _displayNameController.text = profile?.displayName ?? '';
    _usernameController.text = appSession.username ?? '';
    _bioController.text = profile?.bio ?? '';
    _locationController.text = _locationLabel(profile);
    _interestsController.text = profile?.hobbiesText ?? '';
    _selectedGender = profile?.gender ?? '';
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final token = appSession.token;
    final current = appSession.profile;
    if (token == null || current == null) {
      setState(
          () => _errorMessage = 'Your session expired. Please sign in again.');
      return;
    }

    final locationParts = _parseLocation(_locationController.text);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final updated = await _profileApi.updateMe(
        token: token,
        request: UpdateProfileRequest(
          displayName: _displayNameController.text.trim(),
          bio: _bioController.text.trim(),
          city: locationParts.$1,
          country: locationParts.$2,
          gender: _selectedGender,
          hobbiesText: _interestsController.text.trim(),
          visible: current.visible,
          avatarPath: _selectedAvatar?.path ?? '',
        ),
      );
      appSession.updateProfile(updated, profileComplete: true);
      if (!mounted) return;

      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        navigator.pushNamedAndRemoveUntil(AppRoute.appHome.path, (_) => false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (pickedImage == null || !mounted) return;

      setState(() {
        _selectedAvatar = pickedImage;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Unable to open ${source == ImageSource.camera ? 'camera' : 'gallery'} right now.';
      });
    }
  }

  Future<void> _showAvatarOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAvatar(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAvatar(ImageSource.gallery);
                  },
                ),
                if (_selectedAvatar != null)
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Remove photo'),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() => _selectedAvatar = null);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _displayNameController.text.trim().isEmpty
        ? 'Player'
        : _displayNameController.text.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            104,
          ),
          children: [
            _EditTopBar(onSave: _isSubmitting ? null : _saveProfile),
            const SizedBox(height: AppSpacing.lg),
            _EditAvatar(
              displayName: displayName,
              selectedAvatar: _selectedAvatar,
              onChangePhoto: _showAvatarOptions,
            ),
            const SizedBox(height: AppSpacing.lg),
            EditProfileForm(
              displayNameController: _displayNameController,
              usernameController: _usernameController,
              bioController: _bioController,
              locationController: _locationController,
              interestsController: _interestsController,
              selectedGender: _selectedGender,
              genderOptions: _genderOptions,
              onGenderChanged: (value) {
                setState(() => _selectedGender = value ?? '');
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.error,
                    ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _saveProfile,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: Text(_isSubmitting ? 'Saving...' : 'Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _locationLabel(SessionProfile? profile) {
    final parts = <String>[
      if ((profile?.city.trim() ?? '').isNotEmpty) profile!.city.trim(),
      if ((profile?.country.trim() ?? '').isNotEmpty) profile!.country.trim(),
    ];
    return parts.join(', ');
  }

  static (String, String) _parseLocation(String value) {
    final parts = value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return ('', '');
    if (parts.length == 1) return (parts.first, '');
    return (parts.first, parts.sublist(1).join(', '));
  }
}

class _EditTopBar extends StatelessWidget {
  const _EditTopBar({required this.onSave});

  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Text(
            'Edit Profile',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        TextButton(
          onPressed: onSave,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EditAvatar extends StatelessWidget {
  const _EditAvatar({
    required this.displayName,
    required this.selectedAvatar,
    required this.onChangePhoto,
  });

  final String displayName;
  final XFile? selectedAvatar;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 116,
              height: 116,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: selectedAvatar == null
                  ? Center(
                      child: Text(
                        _initialsFor(displayName),
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    )
                  : Image.file(
                      File(selectedAvatar!.path),
                      fit: BoxFit.cover,
                    ),
            ),
            Positioned(
              right: 0,
              bottom: 4,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: onChangePhoto,
          child: const Text('Change photo'),
        ),
      ],
    );
  }
}

class EditProfileForm extends StatelessWidget {
  const EditProfileForm({
    super.key,
    required this.displayNameController,
    required this.usernameController,
    required this.bioController,
    required this.locationController,
    required this.interestsController,
    required this.selectedGender,
    required this.genderOptions,
    required this.onGenderChanged,
  });

  final TextEditingController displayNameController;
  final TextEditingController usernameController;
  final TextEditingController bioController;
  final TextEditingController locationController;
  final TextEditingController interestsController;
  final String selectedGender;
  final List<String> genderOptions;
  final ValueChanged<String?> onGenderChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InputGroup(
          children: [
            _ProfileTextField(
              controller: displayNameController,
              label: 'Display name',
              hint: 'Your name',
            ),
            _ProfileTextField(
              controller: usernameController,
              label: 'Username',
              hint: '@username',
              enabled: false,
            ),
            _ProfileTextField(
              controller: bioController,
              label: 'Bio',
              hint: 'Tell friends a little about yourself',
              maxLines: 3,
              maxLength: 120,
            ),
            _ProfileTextField(
              controller: locationController,
              label: 'Location',
              hint: 'City, Country',
              prefixIcon: Icons.location_on_outlined,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _InputGroup(
          children: [
            DropdownButtonFormField<String>(
              initialValue: selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
              ),
              items: genderOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(
                        option.isEmpty ? 'Prefer not to say' : option,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onGenderChanged,
            ),
            _ProfileTextField(
              controller: interestsController,
              label: 'Interests',
              hint: 'Add your hobbies or interests',
              prefixIcon: Icons.chevron_right_rounded,
            ),
          ],
        ),
      ],
    );
  }
}

class _InputGroup extends StatelessWidget {
  const _InputGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;
  final int maxLines;
  final int? maxLength;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        filled: true,
        fillColor: AppColors.surface,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}

String _initialsFor(String value) {
  final parts =
      value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final initials = parts.take(2).map((part) => part.characters.first).join();
  return initials.isEmpty ? 'P' : initials.toUpperCase();
}
