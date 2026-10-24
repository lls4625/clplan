import 'package:flutter/material.dart' hide Text;

import 'app_controller.dart';
import 'models.dart';
import 'l10n/ui_text.dart';
import 'ui/app_alert.dart';
import 'work_form_widgets.dart';

class ContactFormSection extends StatelessWidget {
  const ContactFormSection({
    super.key,
    required this.controller,
    required this.selectedContacts,
    required this.onChanged,
    this.readOnly = false,
    this.preserveSnapshots = false,
  });

  final AppController controller;
  final List<ContactEntry> selectedContacts;
  final ValueChanged<List<ContactEntry>> onChanged;
  final bool readOnly;
  final bool preserveSnapshots;

  @override
  Widget build(BuildContext context) {
    return WorkFormSection(
      title: '联系人',
      icon: Icons.people_outline,
      subtitle: selectedContacts.isEmpty
          ? '未选择'
          : '${selectedContacts.length} 人',
      trailing: readOnly
          ? null
          : IconButton(
              tooltip: localizeUiText(context, '选择或新增联系人'),
              onPressed: () => _pickContact(context),
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
      children: selectedContacts.isEmpty
          ? const []
          : [
              ContactSelectionField(
                controller: controller,
                selectedContacts: selectedContacts,
                readOnly: readOnly,
                preserveSnapshots: preserveSnapshots,
                onChanged: onChanged,
              ),
            ],
    );
  }

  Future<void> _pickContact(BuildContext context) async {
    final selected = await showContactPicker(
      context,
      controller,
      selectedContacts,
    );
    if (selected == null || !context.mounted) return;
    if (selectedContacts.any((item) => item.id == selected.id)) return;
    onChanged([...selectedContacts, selected]);
  }
}

class ContactSelectionField extends StatelessWidget {
  const ContactSelectionField({
    super.key,
    required this.controller,
    required this.selectedContacts,
    required this.onChanged,
    this.readOnly = false,
    this.preserveSnapshots = false,
  });

  final AppController controller;
  final List<ContactEntry> selectedContacts;
  final ValueChanged<List<ContactEntry>> onChanged;
  final bool readOnly;
  final bool preserveSnapshots;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...selectedContacts.map(
          (contact) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            contact.name,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (!readOnly) ...[
                          IconButton(
                            tooltip: localizeUiText(context, '编辑联系人配置'),
                            onPressed: _configuredContact(contact) == null
                                ? null
                                : () => _editContact(context, contact),
                            icon: const Icon(Icons.edit_outlined, size: 19),
                          ),
                          IconButton(
                            tooltip: localizeUiText(context, '取消选择'),
                            onPressed: () => onChanged(
                              selectedContacts
                                  .where((item) => item.id != contact.id)
                                  .toList(),
                            ),
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              size: 19,
                            ),
                          ),
                        ],
                      ],
                    ),
                    _ContactContent(value: contact.phone),
                    const SizedBox(height: 6),
                    _ContactContent(value: contact.remark, softWrap: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editContact(BuildContext context, ContactEntry contact) async {
    final updated = await showContactEditorDialog(
      context,
      controller,
      contact: _configuredContact(contact),
    );
    if (updated == null || !context.mounted || preserveSnapshots) return;
    onChanged(
      selectedContacts
          .map((item) => item.id == updated.id ? updated : item)
          .toList(),
    );
  }

  ContactEntry? _configuredContact(ContactEntry snapshot) {
    for (final contact in controller.contacts) {
      if (contact.id == snapshot.id) return contact;
    }
    return null;
  }
}

class _ContactContent extends StatelessWidget {
  const _ContactContent({required this.value, this.softWrap});

  final String value;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    return Text(
      value.trim().isEmpty ? '未填写' : value,
      softWrap: softWrap,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
    );
  }
}

Future<ContactEntry?> showContactPicker(
  BuildContext context,
  AppController controller,
  List<ContactEntry> selectedContacts,
) => showModalBottomSheet<ContactEntry>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final available = controller.contacts
          .where(
            (contact) => !selectedContacts.any((item) => item.id == contact.id),
          )
          .toList();
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '选择联系人',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (available.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('没有其他可选联系人')),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final contact = available[index];
                      final detail = [
                        contact.phone,
                        contact.remark,
                      ].where((value) => value.isNotEmpty).join(' · ');
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(contact.name),
                        subtitle: detail.isEmpty ? null : Text(detail),
                        trailing: IconButton(
                          tooltip: localizeUiText(context, '编辑联系人'),
                          onPressed: () async {
                            final updated = await showContactEditorDialog(
                              context,
                              controller,
                              contact: contact,
                            );
                            if (updated != null && sheetContext.mounted) {
                              Navigator.pop(sheetContext, updated);
                            }
                          },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        onTap: () => Navigator.pop(sheetContext, contact),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final created = await showContactEditorDialog(
                    context,
                    controller,
                  );
                  if (created != null && sheetContext.mounted) {
                    Navigator.pop(sheetContext, created);
                  }
                },
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('新增联系人'),
              ),
            ],
          ),
        ),
      );
    },
  ),
);

Future<ContactEntry?> showContactEditorDialog(
  BuildContext context,
  AppController controller, {
  ContactEntry? contact,
}) async {
  final name = TextEditingController(text: contact?.name ?? '');
  final phone = TextEditingController(text: contact?.phone ?? '');
  final remark = TextEditingController(text: contact?.remark ?? '');
  final result = await showDialog<ContactEntry>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(contact == null ? '新增联系人' : '编辑联系人'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: contact == null,
                decoration: InputDecoration(
                  labelText: localizeUiText(context, '姓名'),
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: localizeUiText(context, '电话'),
                ),
              ),
              TextField(
                controller: remark,
                maxLength: maxContactRemarkLength,
                decoration: InputDecoration(
                  labelText: localizeUiText(context, '备注'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: name.text.trim().isEmpty
                ? null
                : () async {
                    try {
                      final saved = await controller.saveContact(
                        id: contact?.id,
                        name: name.text,
                        phone: phone.text,
                        remark: remark.text,
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, saved);
                      }
                    } catch (exception) {
                      if (!dialogContext.mounted) return;
                      showAppAlert(
                        dialogContext,
                        title: '保存失败',
                        message: exception.toString().replaceFirst(
                          'Bad state: ',
                          '',
                        ),
                      );
                    }
                  },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  phone.dispose();
  remark.dispose();
  return result;
}
