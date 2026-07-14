import 'package:flutter/material.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../shared/koom_ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final phone = (user.mobile ?? '').trim();
    final roleText = _roleLabel(user.role, text);
    final displayName = user.displayName.trim().isEmpty
        ? (text.isKy ? 'Аты жок' : 'Без имени')
        : user.displayName.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(text.profile),
        actions: const [LanguageMenuButton(), SizedBox(width: 8)],
      ),
      body: KoomPageBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            KoomCard(
              gradient: MobileChatTheme.brandGradient,
              borderColor: Colors.white.withValues(alpha: 0.14),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                    child: KoomAvatar(
                      label: displayName,
                      radius: 38,
                      background: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (phone.isNotEmpty)
                    Text(
                      phone,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 13),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          roleText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            KoomSectionTitle(
              title: text.isKy ? 'Аккаунт' : 'Аккаунт',
              subtitle: text.isKy
                  ? 'Негизги профиль маалыматы'
                  : 'Основная информация профиля',
            ),
            const SizedBox(height: 12),
            KoomCard(
              showShadow: false,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _ProfileInfoRow(
                    icon: Icons.person_outline_rounded,
                    title: text.isKy ? 'Аты' : 'Имя',
                    value: displayName,
                  ),
                  Divider(color: colors.border, indent: 62),
                  _ProfileInfoRow(
                    icon: Icons.phone_android_rounded,
                    title: text.isKy ? 'Телефон номери' : 'Номер телефона',
                    value: phone.isEmpty ? '—' : phone,
                  ),
                  Divider(color: colors.border, indent: 62),
                  _ProfileInfoRow(
                    icon: Icons.verified_user_outlined,
                    title: text.isKy ? 'Ролу' : 'Роль',
                    value: roleText,
                  ),
                  Divider(color: colors.border, indent: 62),
                  _ProfileInfoRow(
                    icon: Icons.badge_outlined,
                    title: 'User ID',
                    value: user.id,
                    monospace: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            KoomCard(
              showShadow: false,
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text.isKy ? 'Коопсуздук' : 'Безопасность',
                          style: TextStyle(
                            color: colors.textStrong,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          text.isKy
                              ? 'Телефон номери кирүү жана маанилүү билдирүүлөр үчүн колдонулат.'
                              : 'Номер телефона используется для входа и важных уведомлений.',
                          style: TextStyle(
                            color: colors.textMuted,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role, AppText text) {
    switch (role) {
      case 'super_admin':
        return text.isKy ? 'Супер админ' : 'Супер админ';
      case 'platform_admin':
        return text.isKy ? 'Платформа админу' : 'Администратор платформы';
      default:
        return text.isKy ? 'Колдонуучу' : 'Пользователь';
    }
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.monospace = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: monospace ? 13 : 15,
                    fontWeight: FontWeight.w800,
                    fontFamily: monospace ? 'monospace' : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
