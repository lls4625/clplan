import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'models.dart';

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
    final divider = BorderSide(
      color: Theme.of(context).colorScheme.outlineVariant,
      width: .5,
    );
    return InputDecorator(
      decoration: const InputDecoration(labelText: '联系人'),
      child: Column(
        children: [
          if (selectedContacts.isNotEmpty)
            Table(
              border: TableBorder(
                horizontalInside: divider,
                verticalInside: divider,
              ),
              columnWidths: {
                0: const FlexColumnWidth(),
                1: const FlexColumnWidth(),
                2: const FlexColumnWidth(),
                if (!readOnly) 3: const FixedColumnWidth(80),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    const _ContactCell(child: Text('姓名')),
                    const _ContactCell(child: Text('电话')),
                    const _ContactCell(child: Text('备注')),
                    if (!readOnly) const SizedBox.shrink(),
                  ],
                ),
                for (final contact in selectedContacts)
                  TableRow(
                    children: [
                      _ContactCell(
                        child: Text(
                          contact.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _ContactCell(
                        child: Text(
                          contact.phone,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _ContactCell(
                        child: Text(
                          contact.remark,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!readOnly)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '编辑联系人配置',
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 40,
                              ),
                              padding: const EdgeInsets.all(8),
                              onPressed: _configuredContact(contact) == null
                                  ? null
                                  : () async {
                                      final updated =
                                          await showContactEditorDialog(
                                            context,
                                            controller,
                                            contact: _configuredContact(
                                              contact,
                                            ),
                                          );
                                      if (updated == null ||
                                          !context.mounted ||
                                          preserveSnapshots) {
                                        return;
                                      }
                                      onChanged(
                                        selectedContacts
                                            .map(
                                              (item) => item.id == updated.id
                                                  ? updated
                                                  : item,
                                            )
                                            .toList(),
                                      );
                                    },
                              icon: const Icon(Icons.edit_outlined, size: 18),
                            ),
                            IconButton(
                              tooltip: '取消选择',
                              constraints: const BoxConstraints.tightFor(
                                width: 36,
                                height: 40,
                              ),
                              padding: const EdgeInsets.all(8),
                              onPressed: () => onChanged(
                                selectedContacts
                                    .where((item) => item.id != contact.id)
                                    .toList(),
                              ),
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
              ],
            ),
          if (!readOnly)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final selected = await showContactPicker(
                    context,
                    controller,
                    selectedContacts,
                  );
                  if (selected == null || !context.mounted) return;
                  if (selectedContacts.any((item) => item.id == selected.id)) {
                    return;
                  }
                  onChanged([...selectedContacts, selected]);
                },
                icon: const Icon(Icons.add),
                label: const Text('选择或新增联系人'),
              ),
            ),
        ],
      ),
    );
  }

  ContactEntry? _configuredContact(ContactEntry snapshot) {
    for (final contact in controller.contacts) {
      if (contact.id == snapshot.id) return contact;
    }
    return null;
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
                          tooltip: '编辑联系人',
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
                decoration: const InputDecoration(labelText: '姓名'),
                onChanged: (_) => setDialogState(() {}),
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '电话'),
              ),
              TextField(
                controller: remark,
                maxLength: maxContactRemarkLength,
                decoration: const InputDecoration(labelText: '备注'),
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
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            exception.toString().replaceFirst(
                              'Bad state: ',
                              '',
                            ),
                          ),
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

class _ContactCell extends StatelessWidget {
  const _ContactCell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    child: child,
  );
}
