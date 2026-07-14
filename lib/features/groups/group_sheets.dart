import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/localization.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../shared/koom_ui.dart';
import '../../shared/ui_helpers.dart';

class CreateGroupSheet extends StatefulWidget {
  const CreateGroupSheet({super.key, required this.api});
  final ApiClient api;

  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  String visibility = 'public';
  bool loading = false;
  String? error;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final group = await widget.api.createGroup(
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        visibility: visibility,
      );
      if (mounted) Navigator.of(context).pop(group);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return KoomSheetFrame(
      title: text.createGroup,
      subtitle: text.isKy
          ? 'Коомчулуктун аталышын жана кирүү режимин тандаңыз'
          : 'Укажите название сообщества и режим доступа',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: text.isKy ? 'Топтун аты' : 'Название группы',
              prefixIcon: const Icon(Icons.groups_2_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: text.description,
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: 'public',
                icon: const Icon(Icons.public_rounded),
                label: Text(text.isKy ? 'Ачык' : 'Открытая'),
              ),
              ButtonSegment(
                value: 'private',
                icon: const Icon(Icons.lock_outline_rounded),
                label: Text(text.isKy ? 'Чакыруу менен' : 'По приглашению'),
              ),
            ],
            selected: {visibility},
            onSelectionChanged: (value) {
              setState(() => visibility = value.first);
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(message: error!),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: loading ? null : submit,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_rounded),
            label: Text(
              loading
                  ? (text.isKy ? 'Түзүлүп жатат...' : 'Создаётся...')
                  : text.createGroup,
            ),
          ),
        ],
      ),
    );
  }
}

class JoinByCodeSheet extends StatefulWidget {
  const JoinByCodeSheet({super.key, required this.api});
  final ApiClient api;

  @override
  State<JoinByCodeSheet> createState() => _JoinByCodeSheetState();
}

class _JoinByCodeSheetState extends State<JoinByCodeSheet> {
  final codeController = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final group = await widget.api
          .joinByInviteCode(formatGroupInviteCode(codeController.text));
      if (mounted) Navigator.of(context).pop(group);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLanguageScope.textOf(context);
    return KoomSheetFrame(
      title: text.joinByCode,
      subtitle: text.isKy
          ? 'Коомчулуктун чакыруу кодун жазыңыз'
          : 'Введите код приглашения сообщества',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: codeController,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
            inputFormatters: [GroupInviteCodeFormatter()],
            decoration: InputDecoration(
              labelText: text.isKy ? 'Чакыруу коду' : 'Код приглашения',
              hintText: 'AAA-666',
              prefixIcon: const Icon(Icons.key_rounded),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(message: error!),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: loading ? null : submit,
            icon: const Icon(Icons.login_rounded),
            label: Text(
              loading
                  ? (text.isKy ? 'Кирүүдө...' : 'Входим...')
                  : text.joinByCode,
            ),
          ),
        ],
      ),
    );
  }
}

String formatGroupInviteCode(String input) {
  final compact = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final shortened = compact.length > 6 ? compact.substring(0, 6) : compact;
  if (shortened.length > 3)
    return '${shortened.substring(0, 3)}-${shortened.substring(3)}';
  return shortened;
}

class GroupInviteCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = formatGroupInviteCode(newValue.text);
    return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length));
  }
}
