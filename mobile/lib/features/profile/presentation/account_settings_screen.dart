import 'package:flutter/material.dart';

import '../../../app/router.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../chat/data/chat_unread_controller.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            Row(
              children: [
                _CircleButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(
                    'Account Settings',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(width: 44),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsList(
              title: 'Account',
              rows: [
                SettingsRowData(
                  icon: Icons.mail_outline_rounded,
                  title: 'Email',
                  value: _valueOrFallback(appSession.email, 'Email not loaded'),
                ),
                const SettingsRowData(
                  icon: Icons.lock_outline_rounded,
                  title: 'Password',
                  value: 'Change your password',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const SettingsList(
              title: 'Preferences',
              rows: [
                SettingsRowData(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  value: 'Manage your notification preferences',
                ),
                SettingsRowData(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy',
                  value: 'Control who can see your content',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsList(
              rows: [
                SettingsRowData(
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  value: 'Sign out of your account',
                  iconColor: const Color(0xFFE15241),
                  iconBackground: const Color(0xFFFFEFED),
                  titleColor: const Color(0xFFE15241),
                  onTap: () {
                    appSession.clear();
                    chatUnreadController.clear();
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoute.welcome.path,
                      (_) => false,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _valueOrFallback(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }
}

class SettingsScreen extends AccountSettingsScreen {
  const SettingsScreen({super.key});
}

class SettingsRowData {
  const SettingsRowData({
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor = AppColors.primary,
    this.iconBackground = AppColors.primarySoft,
    this.titleColor = AppColors.textPrimary,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;
  final Color iconBackground;
  final Color titleColor;
  final VoidCallback? onTap;
}

class SettingsList extends StatelessWidget {
  const SettingsList({
    super.key,
    required this.rows,
    this.title,
  });

  final String? title;
  final List<SettingsRowData> rows;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Text(
            title!,
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                _SettingsRow(row: rows[index]),
                if (index != rows.length - 1)
                  const Divider(height: 1, color: AppColors.border),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.row});

  final SettingsRowData row;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: row.onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: row.iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(row.icon, color: row.iconColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    style: textTheme.titleMedium?.copyWith(
                      color: row.titleColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(row.value, style: textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
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
