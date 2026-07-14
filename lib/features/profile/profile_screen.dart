import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/localization.dart';
import '../../app/theme.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.api,
    required this.user,
  });

  final ApiClient api;
  final UserProfile user;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const int maxAvatarBytes = 512 * 1024;

  final ImagePicker imagePicker = ImagePicker();
  late UserProfile user;
  bool updatingPhoto = false;

  @override
  void initState() {
    super.initState();
    user = widget.user;
  }

  Uint8List? get avatarBytes {
    final value = user.avatarData.trim();
    if (value.isEmpty) return null;
    try {
      final separator = value.indexOf(',');
      final payload = separator >= 0 ? value.substring(separator + 1) : value;
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> changePhoto() async {
    if (updatingPhoto) return;
    final text = AppLanguageScope.textOf(context);
    try {
      final picked = await imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 82,
      );
      if (picked == null || !mounted) return;

      setState(() => updatingPhoto = true);
      final original = await picked.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        original,
        minWidth: 512,
        minHeight: 512,
        quality: 72,
        format: CompressFormat.jpeg,
      );
      if (compressed.isEmpty || compressed.length > maxAvatarBytes) {
        throw ApiException(
          text.isKy
              ? 'Сүрөт өтө чоң. Башка сүрөт тандаңыз.'
              : 'Фото слишком большое. Выберите другое изображение.',
        );
      }

      final dataUrl = 'data:image/jpeg;base64,${base64Encode(compressed)}';
      final updated = await widget.api.updateMyAvatar(dataUrl);
      if (!mounted) return;
      setState(() {
        user = updated;
        updatingPhoto = false;
      });
      showAppSnack(
        context,
        text.isKy ? 'Профиль сүрөтү жаңыртылды.' : 'Фото профиля обновлено.',
      );
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) return;
      setState(() => updatingPhoto = false);
      showAppSnack(context, localizedMessage(context, error.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    final colors = context.appColors;
    final phone = (user.mobile ?? '').trim();
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
                  Stack(
                    clipBehavior: Clip.none,
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
                          radius: 42,
                          background: Colors.white.withValues(alpha: 0.16),
                          imageBytes: avatarBytes,
                        ),
                      ),
                      Positioned(
                        right: -5,
                        bottom: -5,
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: updatingPhoto ? null : changePhoto,
                            child: SizedBox(
                              width: 34,
                              height: 34,
                              child: updatingPhoto
                                  ? const Padding(
                                      padding: EdgeInsets.all(9),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 18,
                                      color: MobileChatTheme.primaryDark,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
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
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: updatingPhoto ? null : changePhoto,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                    ),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(
                      text.isKy ? 'Сүрөттү өзгөртүү' : 'Изменить фото',
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
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

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
                Text(
                  value,
                  style: TextStyle(
                    color: colors.textStrong,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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
