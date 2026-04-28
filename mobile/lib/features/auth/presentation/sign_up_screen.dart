
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../../core/widgets/bottom_action_area.dart';
import '../../../core/widgets/onboarding_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../profile/data/profile_api.dart';
import '../data/auth_api.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const int _stepCount = 3;

  final AuthApi _authApi = AuthApi();
  final ProfileApi _profileApi = ProfileApi();
  final ImagePicker _imagePicker = ImagePicker();
  final PageController _pageController = PageController();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _cityController = TextEditingController();
  final _hobbiesController = TextEditingController();
  final _bioController = TextEditingController();

  int _currentStep = 0;
  bool _agreeToSafety = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isSubmitting = false;
  String _selectedGender = '';
  String? _errorMessage;
  XFile? _selectedAvatar;

  bool get _canContinueAccount {
    return _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _agreeToSafety;
  }

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_handleAccountFieldsChanged);
    _passwordController.addListener(_handleAccountFieldsChanged);
    _confirmPasswordController.addListener(_handleAccountFieldsChanged);
    _bioController.addListener(_limitBioLength);
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleAccountFieldsChanged);
    _passwordController.removeListener(_handleAccountFieldsChanged);
    _confirmPasswordController.removeListener(_handleAccountFieldsChanged);
    _bioController.removeListener(_limitBioLength);
    _pageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _cityController.dispose();
    _hobbiesController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _handleAccountFieldsChanged() {
    if (_currentStep != 0) return;

    if (_errorMessage == null) {
      setState(() {});
      return;
    }

    setState(() {
      _errorMessage = null;
    });
  }

  void _limitBioLength() {
    final text = _bioController.text;
    if (text.length <= 120) return;

    _bioController
      ..text = text.substring(0, 120)
      ..selection = const TextSelection.collapsed(offset: 120);
  }

  void _goBack() {
    if (_currentStep == 0) {
      Navigator.of(context).maybePop();
      return;
    }

    _animateToStep(_currentStep - 1);
  }

  Future<void> _animateToStep(int step) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _currentStep = step;
      _errorMessage = null;
    });
    await _pageController.animateToPage(
      step,
      duration: AppMotion.page,
      curve: Curves.easeOutCubic,
    );
  }

  void _continueFromAccount() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showValidationError('Enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      _showValidationError('Use at least 8 characters for your password.');
      return;
    }
    if (password != confirmPassword) {
      _showValidationError('Password and confirm password must match.');
      return;
    }
    if (!_agreeToSafety) {
      _showValidationError(
          'Agree to the guidelines and safe interactions policy to continue.');
      return;
    }

    _animateToStep(1);
  }

  void _continueFromProfile() {
    final displayName = _displayNameController.text.trim();
    final username = _usernameController.text.trim();

    if (displayName.isEmpty) {
      _showValidationError('Display name is required.');
      return;
    }
    if (username.isEmpty) {
      _showValidationError('Username is required.');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
      _showValidationError(
          'Use 3-20 lowercase letters, numbers, or underscores.');
      return;
    }

    _animateToStep(2);
  }

  void _showValidationError(String message) {
    setState(() {
      _errorMessage = message;
    });
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
    } catch (error) {
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
                      setState(() {
                        _selectedAvatar = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _chooseGender() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) {
        const options = <String>[
          '',
          'Woman',
          'Man',
          'Non-binary',
          'Prefer not to share',
        ];

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
              children: options.map((option) {
                final label = option.isEmpty ? 'Prefer not to share' : option;
                return ListTile(
                  title: Text(label),
                  trailing: _selectedGender == option
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(option),
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (value == null || !mounted) return;

    setState(() {
      _selectedGender = value;
    });
  }

  Future<void> _finishSetup({required bool skipOptional}) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await _authApi.signUp(
        SignUpRequest(
          email: _emailController.text.trim(),
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim(),
          city: _cityController.text.trim(),
          bio: skipOptional ? '' : _bioController.text.trim(),
          avatarPath: _selectedAvatar?.path ?? '',
        ),
      );

      appSession.setSession(
        token: result.token,
        userID: result.userID,
        username: result.username,
        email: result.email,
        profile: result.profile,
        profileComplete: result.profileComplete,
      );

      final updatedProfile = await _profileApi.updateMe(
        token: result.token,
        request: UpdateProfileRequest(
          displayName: _displayNameController.text.trim(),
          bio: skipOptional ? '' : _bioController.text.trim(),
          city: _cityController.text.trim(),
          country: result.profile.country,
          gender: skipOptional ? '' : _selectedGender,
          hobbiesText: skipOptional ? '' : _hobbiesController.text.trim(),
          visible: result.profile.visible,
          avatarPath: '',
        ),
      );

      appSession.updateProfile(updatedProfile, profileComplete: true);
      appSession.clear();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoute.login.path,
        (_) => false,
        arguments: LoginScreenArgs(
          identifier: _emailController.text.trim(),
          registrationSuccessMessage: 'Account created. Sign in to continue.',
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString().replaceFirst('HttpException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: OnboardingScaffold(
        errorMessage: _errorMessage,
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _CreateAccountStep(
              header: StepProgressHeader(
                currentStep: _currentStep,
                stepCount: _stepCount,
                onBack: _goBack,
              ),
              emailController: _emailController,
              passwordController: _passwordController,
              confirmPasswordController: _confirmPasswordController,
              agreeToSafety: _agreeToSafety,
              isPasswordVisible: _isPasswordVisible,
              isConfirmPasswordVisible: _isConfirmPasswordVisible,
              onAgreementChanged: (value) {
                setState(() {
                  _agreeToSafety = value;
                  _errorMessage = null;
                });
              },
              onPasswordVisibilityChanged: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
              onConfirmPasswordVisibilityChanged: () {
                setState(() {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                });
              },
            ),
            _ProfileStep(
              header: StepProgressHeader(
                currentStep: _currentStep,
                stepCount: _stepCount,
                onBack: _goBack,
              ),
              selectedAvatar: _selectedAvatar,
              displayNameController: _displayNameController,
              usernameController: _usernameController,
              cityController: _cityController,
              onPickAvatar: _showAvatarOptions,
            ),
            _PersonalizeStep(
              header: StepProgressHeader(
                currentStep: _currentStep,
                stepCount: _stepCount,
                onBack: _goBack,
              ),
              selectedGender: _selectedGender,
              hobbiesController: _hobbiesController,
              bioController: _bioController,
              onChooseGender: _chooseGender,
            ),
          ],
        ),
        bottom: _buildBottomActions(),
      ),
    );
  }

  Widget _buildBottomActions() {
    if (_currentStep == 0) {
      return BottomActionArea(
        primaryButton: PrimaryButton(
          label: 'Continue',
          onPressed: _canContinueAccount ? _continueFromAccount : null,
        ),
        footer: _SignInFooter(
          onPressed: () {
            Navigator.of(context).pushReplacementNamed(AppRoute.login.path);
          },
        ),
      );
    }

    if (_currentStep == 1) {
      return BottomActionArea(
        primaryButton: PrimaryButton(
          label: 'Continue',
          onPressed: _continueFromProfile,
        ),
      );
    }

    return BottomActionArea(
      primaryButton: PrimaryButton(
        label: _isSubmitting ? 'Creating account...' : 'Finish setup',
        onPressed:
            _isSubmitting ? null : () => _finishSetup(skipOptional: false),
      ),
      footer: SecondaryButton(
        label: 'Skip for now',
        onPressed:
            _isSubmitting ? null : () => _finishSetup(skipOptional: true),
      ),
    );
  }
}

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.body,
    required this.bottom,
    this.errorMessage,
  });

  final Widget body;
  final Widget bottom;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(child: body),
            AnimatedSwitcher(
              duration: AppMotion.quick,
              child: errorMessage == null
                  ? const SizedBox.shrink()
                  : Padding(
                      key: ValueKey(errorMessage),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        0,
                        AppSpacing.page,
                        AppSpacing.sm,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorMessage!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    ),
            ),
            bottom,
          ],
        ),
      ),
    );
  }
}

class StepProgressHeader extends StatelessWidget {
  const StepProgressHeader({
    super.key,
    required this.currentStep,
    required this.stepCount,
    required this.onBack,
  });

  final int currentStep;
  final int stepCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            AppBackButton(onPressed: onBack),
            const Spacer(),
            Container(
              height: AppSizes.stepPillHeight,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                'Step ${currentStep + 1} of $stepCount',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.caption,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.progressHorizontalInset,
          ),
          child: Row(
            children: List.generate(stepCount, (index) {
              final isActive = index <= currentStep;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == stepCount - 1 ? 0 : AppSpacing.sm,
                  ),
                  child: AnimatedContainer(
                    duration: AppMotion.medium,
                    height: AppSizes.progressBarHeight,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.buttonHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTypography.body,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class ProfilePhotoPicker extends StatelessWidget {
  const ProfilePhotoPicker({
    super.key,
    required this.selectedAvatar,
    required this.onTap,
  });

  final XFile? selectedAvatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: AppSizes.avatar,
            height: AppSizes.avatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: AppSizes.avatar,
                  height: AppSizes.avatar,
                  padding: const EdgeInsets.all(AppSizes.avatarInset),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryLight,
                      image: selectedAvatar == null
                          ? null
                          : DecorationImage(
                              image: FileImage(File(selectedAvatar!.path)),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: selectedAvatar == null
                        ? const Icon(
                            Icons.photo_camera_rounded,
                            color: AppColors.avatarIcon,
                            size: AppSizes.avatarIcon,
                          )
                        : null,
                  ),
                ),
                Positioned(
                  right: AppSizes.avatarActionRight,
                  bottom: AppSizes.avatarActionBottom,
                  child: Container(
                    width: AppSizes.avatarAction,
                    height: AppSizes.avatarAction,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      border: Border.all(
                        color: AppColors.surface,
                        width: AppSizes.avatarActionBorder,
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: AppSizes.avatarActionIcon,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          selectedAvatar == null ? 'Add profile photo' : 'Profile photo added',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTypography.body,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Optional, but helps friends\nrecognize you.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppTypography.caption,
            height: AppTypography.helperLineHeight,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({
    required this.header,
    required this.title,
    required this.subtitle,
    required this.children,
    this.compactTop = false,
  });

  final Widget header;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool compactTop;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          SizedBox(height: compactTop ? AppSpacing.lg : AppSpacing.xl),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppTypography.onboardingTitle,
              height: AppTypography.titleLineHeight,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppTypography.body,
              height: AppTypography.bodyLineHeight,
              fontWeight: FontWeight.w400,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _CreateAccountStep extends StatelessWidget {
  const _CreateAccountStep({
    required this.header,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.agreeToSafety,
    required this.isPasswordVisible,
    required this.isConfirmPasswordVisible,
    required this.onAgreementChanged,
    required this.onPasswordVisibilityChanged,
    required this.onConfirmPasswordVisibilityChanged,
  });

  final Widget header;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool agreeToSafety;
  final bool isPasswordVisible;
  final bool isConfirmPasswordVisible;
  final ValueChanged<bool> onAgreementChanged;
  final VoidCallback onPasswordVisibilityChanged;
  final VoidCallback onConfirmPasswordVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return _StepContent(
      header: header,
      title: 'Create your account',
      subtitle: 'Use your email to get started with FaceOff.',
      children: [
        const SizedBox(height: AppSpacing.xl),
        OnboardingTextField(
          controller: emailController,
          label: 'Email',
          hint: 'you@example.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        OnboardingTextField(
          controller: passwordController,
          label: 'Password',
          hint: 'Enter your password',
          icon: Icons.lock_outline_rounded,
          obscureText: !isPasswordVisible,
          textInputAction: TextInputAction.next,
          trailing: IconButton(
            onPressed: onPasswordVisibilityChanged,
            icon: Icon(
              isPasswordVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Padding(
          padding: EdgeInsets.only(
            left: AppSizes.inputTextOffset,
            right: AppSpacing.md,
          ),
          child: Text(
            'Use 8+ characters with a mix of letters, numbers\nand symbols.',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: AppTypography.helper,
              height: AppTypography.helperLineHeight,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OnboardingTextField(
          controller: confirmPasswordController,
          label: 'Confirm password',
          hint: 'Confirm your password',
          icon: Icons.lock_outline_rounded,
          obscureText: !isConfirmPasswordVisible,
          textInputAction: TextInputAction.done,
          trailing: IconButton(
            onPressed: onConfirmPasswordVisibilityChanged,
            icon: Icon(
              isConfirmPasswordVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.checkboxTop),
        _AgreementRow(
          isChecked: agreeToSafety,
          onChanged: onAgreementChanged,
        ),
      ],
    );
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.isChecked,
    required this.onChanged,
  });

  final bool isChecked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!isChecked),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: AppMotion.quick,
            width: AppSizes.checkbox,
            height: AppSizes.checkbox,
            margin: const EdgeInsets.only(top: AppSizes.checkboxInsetTop),
            decoration: BoxDecoration(
              color: isChecked ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSizes.checkboxRadius),
              border: Border.all(
                color: isChecked ? AppColors.primary : AppColors.borderStrong,
                width: AppSizes.checkboxBorder,
              ),
            ),
            child: isChecked
                ? const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: AppTypography.body,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTypography.caption,
                  height: AppTypography.paragraphLineHeight,
                  fontWeight: FontWeight.w400,
                ),
                children: [
                  TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Community Guidelines',
                    style: TextStyle(color: AppColors.primary),
                  ),
                  TextSpan(text: ' and '),
                  TextSpan(
                    text: 'safe interactions policy',
                    style: TextStyle(color: AppColors.primary),
                  ),
                  TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    required this.header,
    required this.selectedAvatar,
    required this.displayNameController,
    required this.usernameController,
    required this.cityController,
    required this.onPickAvatar,
  });

  final Widget header;
  final XFile? selectedAvatar;
  final TextEditingController displayNameController;
  final TextEditingController usernameController;
  final TextEditingController cityController;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    return _StepContent(
      header: header,
      title: 'Set up your profile',
      subtitle: 'Help friends find and recognize you.',
      compactTop: true,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: ProfilePhotoPicker(
            selectedAvatar: selectedAvatar,
            onTap: onPickAvatar,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        OnboardingTextField(
          controller: displayNameController,
          label: 'Display name',
          hint: 'Enter your display name',
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        OnboardingTextField(
          controller: usernameController,
          label: 'Username',
          hint: 'Choose a username',
          icon: Icons.alternate_email_rounded,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        OnboardingTextField(
          controller: cityController,
          label: 'Home city',
          hint: 'Enter your city',
          icon: Icons.location_on_outlined,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}

class _PersonalizeStep extends StatelessWidget {
  const _PersonalizeStep({
    required this.header,
    required this.selectedGender,
    required this.hobbiesController,
    required this.bioController,
    required this.onChooseGender,
  });

  final Widget header;
  final String selectedGender;
  final TextEditingController hobbiesController;
  final TextEditingController bioController;
  final VoidCallback onChooseGender;

  @override
  Widget build(BuildContext context) {
    final genderLabel =
        selectedGender.isEmpty ? 'Prefer not to share' : selectedGender;

    return _StepContent(
      header: header,
      title: 'Make it yours',
      subtitle:
          'Add a little context, or skip for now.\nYou can always update this later.',
      compactTop: false,
      children: [
        const SizedBox(height: AppSpacing.xl),
        _GenderField(
          value: genderLabel,
          onTap: onChooseGender,
        ),
        const SizedBox(height: AppSpacing.md),
        OnboardingTextField(
          controller: hobbiesController,
          label: 'Hobbies or interests (optional)',
          hint: 'E.g. Music, Photography, Gaming',
          icon: Icons.favorite_border_rounded,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: bioController,
          builder: (context, value, child) {
            return Stack(
              children: [
                OnboardingTextField(
                  controller: bioController,
                  label: 'Short bio (optional)',
                  hint: 'Tell others about yourself...',
                  icon: Icons.edit_outlined,
                  maxLines: 4,
                  minHeight: AppSizes.bioHeight,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(120),
                  ],
                ),
                Positioned(
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Text(
                    '${value.text.length}/120',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppTypography.helper,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GenderField extends StatelessWidget {
  const _GenderField({
    required this.value,
    required this.onTap,
  });

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        height: AppSpacing.inputHeight,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            const Icon(
              Icons.group_outlined,
              color: AppColors.textPrimary,
              size: AppSizes.icon,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: AppTypography.helper,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(text: 'Gender '),
                        TextSpan(
                          text: '(optional)',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppTypography.body,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textPrimary,
              size: AppSizes.icon,
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInFooter extends StatelessWidget {
  const _SignInFooter({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: RichText(
        text: const TextSpan(
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppTypography.caption,
            fontWeight: FontWeight.w400,
          ),
          children: [
            TextSpan(text: 'Already have an account? '),
            TextSpan(
              text: 'Sign in',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
