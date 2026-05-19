import 'package:flutter/material.dart';

import '../../app/appearance.dart';
import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../shared/ui_helpers.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final phone = (user.mobile ?? '').trim();
    final roleText = _roleLabel(user.role, text);

    return Scaffold(
      appBar: AppBar(title: Text(text.isKy ? 'Профиль' : 'Профиль')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.border),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 10))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: MobileChatTheme.primary,
                child: Text(avatarText(user.displayName), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 14),
              Text(
                user.displayName.trim().isEmpty ? (text.isKy ? 'Аты жок' : 'Без имени') : user.displayName.trim(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: colors.textStrong, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: colors.surfaceSoft, borderRadius: BorderRadius.circular(999), border: Border.all(color: colors.border)),
                child: Text(roleText, style: const TextStyle(color: MobileChatTheme.primaryDark, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          _ProfileInfoCard(children: [
            _ProfileInfoRow(icon: Icons.person_outline_rounded, title: text.isKy ? 'Аты' : 'Имя', value: user.displayName.trim().isEmpty ? '—' : user.displayName.trim()),
            _ProfileInfoRow(icon: Icons.phone_android_rounded, title: text.isKy ? 'Телефон номери' : 'Номер телефона', value: phone.isEmpty ? '—' : phone),
            _ProfileInfoRow(icon: Icons.verified_user_outlined, title: text.isKy ? 'Ролу' : 'Роль', value: roleText),
            _ProfileInfoRow(icon: Icons.badge_outlined, title: 'User ID', value: user.id),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: colors.surfaceSoft, borderRadius: BorderRadius.circular(22), border: Border.all(color: colors.border)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, color: MobileChatTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text.isKy
                      ? 'Бул жерде аккаунттун негизги маалыматы көрсөтүлөт. Телефон номери кирүү жана билдирүүлөр үчүн колдонулат.'
                      : 'Здесь отображается основная информация аккаунта. Номер телефона используется для входа и уведомлений.',
                  style: TextStyle(color: colors.textMuted, height: 1.35, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        ],
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

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: colors.border)),
      child: Column(children: children),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: MobileChatTheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: colors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: colors.textStrong, fontSize: 16, fontWeight: FontWeight.w800)),
        ])),
      ]),
    );
  }
}
