import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';

class ImportResult {
  const ImportResult({required this.tasks, required this.warnings});
  final List<TaskItem> tasks;
  final List<String> warnings;
}

class XlsxService {
  static const headers = <String, String>{
    'id': '任务ID',
    'title': '标题',
    'description': '描述',
    'type': '分类',
    'contact': '联系人',
    'status': '状态ID',
    'tags': '标签',
    'startDate': '日期',
    'startTime': '时间',
    'reminderEnabled': '启用提醒',
    'reminders': '提醒规则',
    'reason': '原因',
    'completedAt': '完成时间',
    'originId': '来源任务ID',
    'parentTaskId': '主任务ID',
    'updatedAt': '更新时间',
  };

  static Future<void> exportTasks(List<TaskItem> tasks) async {
    final workbook = Excel.createExcel();
    final defaultName = workbook.getDefaultSheet();
    final sheet = workbook['任务'];
    if (defaultName != null && defaultName != '任务')
      workbook.delete(defaultName);
    sheet.appendRow(headers.values.map(TextCellValue.new).toList());
    for (final task in tasks) {
      final row = <String>[
        task.id,
        task.title,
        task.description,
        task.type,
        task.contact,
        task.statusId,
        task.tags.join('，'),
        task.startDate,
        task.startTime,
        task.reminderEnabled ? 'true' : 'false',
        jsonEncode(
          task.reminders
              .map(
                (item) => {
                  'type': item.typeName,
                  'deliveryType': item.deliveryTypeName,
                  'offsetMinutes': item.offsetMinutes,
                  'dayOffset': item.dayOffset,
                  'timeOfDay': item.timeOfDay,
                  'absoluteAt': item.absoluteAt?.toIso8601String(),
                },
              )
              .toList(),
        ),
        task.reason,
        task.completedAt?.toIso8601String() ?? '',
        task.originId ?? '',
        task.parentTaskId ?? '',
        task.updatedAt.toIso8601String(),
      ];
      sheet.appendRow(row.map(TextCellValue.new).toList());
    }
    final bytes = workbook.save();
    if (bytes == null) throw StateError('无法生成 XLSX 文件。');
    final directory = await getTemporaryDirectory();
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final file = File(p.join(directory.path, '日序-$date.xlsx'));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], title: '导出日序任务'),
    );
  }

  static Future<ImportResult?> pickAndParse(List<TaskStatus> statuses) async {
    final selected = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    if (selected.isEmpty) return null;
    final file = selected.single;
    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) throw FormatException('文件不能超过 10 MB。');
    return parse(bytes, statuses);
  }

  static ImportResult parse(Uint8List bytes, List<TaskStatus> statuses) {
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) throw FormatException('工作簿中没有可读取的工作表。');
    final sheet = workbook.tables['任务'] ?? workbook.tables.values.first;
    if (sheet.rows.isEmpty) throw FormatException('工作表为空。');
    if (sheet.maxRows > 5001) throw FormatException('最多导入 5000 行任务。');
    final aliases = <String, String>{};
    for (final entry in headers.entries) {
      aliases[_normalize(entry.key)] = entry.key;
      aliases[_normalize(entry.value)] = entry.key;
    }
    aliases.addAll({
      '任务编号': 'id',
      '任务标题': 'title',
      '任务名称': 'title',
      '计划日期': 'startDate',
    });
    final mapping = <int, String>{};
    for (var i = 0; i < sheet.rows.first.length; i++) {
      final raw = sheet.rows.first[i]?.value?.toString() ?? '';
      final key = aliases[_normalize(raw)];
      if (key != null) mapping[i] = key;
    }
    if (!mapping.containsValue('title')) throw FormatException('第一行必须包含“标题”列。');
    final statusIds = statuses.map((status) => status.id).toSet();
    final defaultStatus = statuses
        .firstWhere((status) => !status.completed, orElse: () => statuses.first)
        .id;
    final tasks = <TaskItem>[];
    final warnings = <String>[];
    for (var rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final row = sheet.rows[rowIndex];
      final values = <String, String>{};
      for (final entry in mapping.entries) {
        values[entry.value] = entry.key < row.length
            ? (row[entry.key]?.value?.toString().trim() ?? '')
            : '';
      }
      if (values.values.every((value) => value.isEmpty)) continue;
      final title = values['title'] ?? '';
      if (title.isEmpty) {
        warnings.add('第 ${rowIndex + 1} 行缺少标题，已跳过。');
        continue;
      }
      final rawStatus = values['status'] ?? '';
      final statusId = statusIds.contains(rawStatus)
          ? rawStatus
          : defaultStatus;
      if (rawStatus.isNotEmpty && rawStatus != statusId)
        warnings.add('第 ${rowIndex + 1} 行状态不存在，已使用默认状态。');
      final now = DateTime.now();
      final taskId = (values['id'] ?? '').isEmpty
          ? 'xlsx-${now.microsecondsSinceEpoch}-$rowIndex'
          : values['id']!;
      final reminders = _parseReminders(
        values['reminders'] ?? '',
        taskId,
        rowIndex + 1,
        warnings,
      );
      tasks.add(
        TaskItem(
          id: taskId,
          title: title,
          description: values['description'] ?? '',
          type: values['type'] ?? '',
          contact: values['contact'] ?? '',
          statusId: statusId,
          tags: (values['tags'] ?? '')
              .split(RegExp(r'[,，]'))
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList(),
          startDate: values['startDate'] ?? '',
          startTime: values['startTime'] ?? '',
          reason: values['reason'] ?? '',
          completedAt: DateTime.tryParse(values['completedAt'] ?? ''),
          originId: _nullable(values['originId']),
          parentTaskId: _nullable(values['parentTaskId']),
          updatedAt: DateTime.tryParse(values['updatedAt'] ?? '') ?? now,
          reminderEnabled:
              (values['reminderEnabled'] ?? '').toLowerCase() == 'true' &&
              reminders.isNotEmpty,
          reminders: reminders,
        ),
      );
    }
    return ImportResult(tasks: tasks, warnings: warnings);
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  static String? _nullable(String? value) =>
      value == null || value.isEmpty ? null : value;

  static List<TaskReminderRule> _parseReminders(
    String raw,
    String taskId,
    int rowNumber,
    List<String> warnings,
  ) {
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException();
      return decoded.indexed.map((entry) {
        final map = entry.$2 as Map<String, dynamic>;
        return TaskReminderRule(
          id: 'reminder-$taskId-${entry.$1}',
          taskId: taskId,
          type: reminderRuleTypeFromName(map['type'] as String?),
          deliveryType: reminderDeliveryTypeFromName(
            map['deliveryType'] as String?,
          ),
          offsetMinutes: map['offsetMinutes'] as int?,
          dayOffset: map['dayOffset'] as int?,
          timeOfDay: map['timeOfDay'] as String?,
          absoluteAt: DateTime.tryParse(map['absoluteAt'] as String? ?? ''),
          sortOrder: entry.$1,
        );
      }).toList();
    } catch (_) {
      warnings.add('第 $rowNumber 行提醒规则格式无效，已忽略。');
      return const [];
    }
  }
}
