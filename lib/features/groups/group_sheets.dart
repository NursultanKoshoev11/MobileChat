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
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: SegmentedButton<String>(
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
                      label: Text(
                        text.isKy ? 'Чакыруу менен' : 'По приглашению',
                      ),
                    ),
                  ],
                  selected: {visibility},
                  onSelectionChanged: (value) {
                    setState(() => visibility = value.first);
                  },
                ),
              ),
            ),
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
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Material(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.key_rounded,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text.joinByCode,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            text.isKy
                                ? 'Чакыруу кодун жазыңыз'
                                : 'Введите код приглашения',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (!loading) submit();
                  },
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                  inputFormatters: [GroupInviteCodeFormatter()],
                  decoration: InputDecoration(
                    labelText: text.isKy ? 'Чакыруу коду' : 'Код приглашения',
                    hintText: 'AAA-666',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: error!),
                ],
                const SizedBox(height: 16),
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
                      : const Icon(Icons.login_rounded),
                  label: Text(
                    loading
                        ? (text.isKy ? 'Кирүүдө...' : 'Входим...')
                        : text.joinByCode,
                  ),
                ),
              ],
            ),
          ),
        ),
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
