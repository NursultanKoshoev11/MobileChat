import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/localization.dart';
import '../../data/api_client.dart';
import '../../data/models.dart';
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
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(text.createGroup, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(controller: titleController, decoration: InputDecoration(labelText: text.isKy ? 'Топтун аты' : 'Название группы')),
        const SizedBox(height: 12),
        TextField(controller: descriptionController, decoration: InputDecoration(labelText: text.description)),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'public', label: Text(text.isKy ? 'Ачык' : 'Открытая')),
            ButtonSegment(value: 'private', label: Text(text.isKy ? 'Чакыруу менен' : 'По приглашению')),
          ],
          selected: {visibility},
          onSelectionChanged: (value) => setState(() => visibility = value.first),
        ),
        if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
        const SizedBox(height: 16),
        FilledButton(onPressed: loading ? null : submit, child: Text(loading ? (text.isKy ? 'Түзүлүп жатат...' : 'Создаётся...') : text.createGroup)),
      ]),
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
      final group = await widget.api.joinByInviteCode(formatGroupInviteCode(codeController.text));
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
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(text.joinByCode, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(
          controller: codeController,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [GroupInviteCodeFormatter()],
          decoration: InputDecoration(labelText: text.isKy ? 'Чакыруу коду' : 'Код приглашения', hintText: 'AAA-666'),
        ),
        if (error != null) ...[const SizedBox(height: 12), ErrorBanner(message: error!)],
        const SizedBox(height: 16),
        FilledButton(onPressed: loading ? null : submit, child: Text(loading ? (text.isKy ? 'Кирүүдө...' : 'Входим...') : text.joinByCode)),
      ]),
    );
  }
}

String formatGroupInviteCode(String input) {
  final compact = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final shortened = compact.length > 6 ? compact.substring(0, 6) : compact;
  if (shortened.length > 3) return '${shortened.substring(0, 3)}-${shortened.substring(3)}';
  return shortened;
}

class GroupInviteCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = formatGroupInviteCode(newValue.text);
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}
