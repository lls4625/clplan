import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';

class ImportResult {
  const ImportResult({required this.plans, required this.warnings});

  final List<PlanItem> plans;
  final List<String> warnings;
}

class XlsxService {
  static const headers = <String, String>{
    'id': '计划ID',
    'name': '计划名称',
    'description': '计划内容',
    'category': '分类',
    'progressTemplate': '进度方案',
    'progressNode': '进度节点',
    'quadrant': '四象限标签',
    'tags': '普通标签',
    'startDate': '开始日期',
    'targetDate': '目标日期',
    'contacts': '联系人',
    'calendarDisplayMode': '日历显示',
    'reminderEnabled': '启用提醒',
    'reminders': '提醒规则',
    'updatedAt': '更新时间',
  };

  static const _calendarModes = <String, PlanCalendarDisplayMode>{
    '整个期间': PlanCalendarDisplayMode.wholePeriod,
    '仅起止日': PlanCalendarDisplayMode.endpoints,
    '仅开始日': PlanCalendarDisplayMode.startOnly,
    '仅目标日': PlanCalendarDisplayMode.targetOnly,
  };

  static Future<void> exportPlans({
    required List<PlanItem> plans,
    required List<CategoryDefinition> categories,
    required List<ProgressTemplate> progressTemplates,
    required List<TaskTagDefinition> tags,
    required List<ContactEntry> contacts,
  }) async {
    final workbook = Excel.createExcel();
    final defaultName = workbook.getDefaultSheet();
    final sheet = workbook['计划'];
    final guide = workbook['填写说明'];
    if (defaultName != null && defaultName != '计划' && defaultName != '填写说明') {
      workbook.delete(defaultName);
    }

    _writePlanSheet(sheet, plans, tags);
    _writeGuideSheet(
      guide,
      categories: categories,
      progressTemplates: progressTemplates,
      tags: tags,
      contacts: contacts,
    );

    final rawBytes = workbook.save();
    if (rawBytes == null) throw StateError('无法生成 XLSX 文件。');
    final bytes = _addWorkbookValidation(
      Uint8List.fromList(rawBytes),
      categories: categories,
      progressTemplates: progressTemplates,
      tags: tags,
    );

    final directory = await getTemporaryDirectory();
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final file = File(p.join(directory.path, 'ClPlan-计划-$date.xlsx'));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], title: '导出 ClPlan 计划'),
    );
  }

  static void _writePlanSheet(
    Sheet sheet,
    List<PlanItem> plans,
    List<TaskTagDefinition> definitions,
  ) {
    sheet.appendRow(headers.values.map(TextCellValue.new).toList());
    final quadrantNames = definitions
        .where((tag) => tag.isQuadrant)
        .map((tag) => tag.name)
        .toSet();
    for (final plan in plans) {
      String? quadrant;
      for (final tag in plan.tags) {
        if (quadrantNames.contains(tag.name)) {
          quadrant = tag.name;
          break;
        }
      }
      final ordinaryTags = plan.tags
          .where((tag) => !quadrantNames.contains(tag.name))
          .map((tag) => tag.name)
          .join(',');
      sheet.appendRow(
        <String>[
          plan.id,
          plan.name,
          plan.description,
          plan.categoryName,
          plan.progress.templateName,
          plan.progress.currentNode?.name ?? '',
          quadrant ?? '',
          ordinaryTags,
          plan.startDate,
          plan.targetDate,
          plan.contacts.map((contact) => contact.name).join(','),
          plan.calendarDisplayMode.label,
          plan.reminderEnabled ? '是' : '否',
          jsonEncode(
            plan.reminders
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
          plan.updatedAt.toIso8601String(),
        ].map(TextCellValue.new).toList(),
      );
    }

    const widths = <double>[
      26,
      22,
      36,
      14,
      18,
      18,
      18,
      28,
      14,
      14,
      24,
      16,
      12,
      42,
      24,
    ];
    for (var index = 0; index < widths.length; index++) {
      sheet.setColumnWidth(index, widths[index]);
    }
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#315D8A'),
      verticalAlign: VerticalAlign.Center,
    );
    for (var index = 0; index < headers.length; index++) {
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: index, rowIndex: 0))
              .cellStyle =
          headerStyle;
    }
    sheet.setRowHeight(0, 26);
  }

  static void _writeGuideSheet(
    Sheet sheet, {
    required List<CategoryDefinition> categories,
    required List<ProgressTemplate> progressTemplates,
    required List<TaskTagDefinition> tags,
    required List<ContactEntry> contacts,
  }) {
    const guideRows = <List<String>>[
      ['ClPlan 计划导入说明'],
      ['“计划名称、开始日期、目标日期”为必填项；计划ID是隐藏且锁定的主键，有主键时更新对应计划，无主键时新增计划。'],
      ['再次导入只会新增计划或更新相同计划ID的数据，不会删除本地已有的其他计划。'],
      ['分类、进度方案、进度节点、四象限标签均可在“计划”工作表下拉选择。'],
      ['普通标签和联系人可填写多个，请使用英文逗号 , 分隔；可选内容见下方。'],
      [],
    ];
    for (final row in guideRows) {
      sheet.appendRow(row.map(TextCellValue.new).toList());
    }

    final quadrantTags = tags.where((tag) => tag.isQuadrant).toList();
    final ordinaryTags = tags.where((tag) => !tag.isQuadrant).toList();
    final headings = <String>[
      '分类',
      '进度方案',
      '四象限标签',
      '普通标签（英文逗号分隔）',
      '联系人（英文逗号分隔）',
      '日历显示',
      '启用提醒',
      ...progressTemplates.map((template) => '${template.name}·节点'),
    ];
    sheet.appendRow(headings.map(TextCellValue.new).toList());
    final maximum = <int>[
      categories.length,
      progressTemplates.length,
      quadrantTags.length,
      ordinaryTags.length,
      contacts.length,
      _calendarModes.length,
      2,
      ...progressTemplates.map((template) => template.nodes.length),
    ].fold(0, (current, value) => value > current ? value : current);
    for (var row = 0; row < maximum; row++) {
      final values = <String>[
        row < categories.length ? categories[row].name : '',
        row < progressTemplates.length ? progressTemplates[row].name : '',
        row < quadrantTags.length ? quadrantTags[row].name : '',
        row < ordinaryTags.length ? ordinaryTags[row].name : '',
        row < contacts.length ? contacts[row].name : '',
        row < _calendarModes.length ? _calendarModes.keys.elementAt(row) : '',
        row == 0
            ? '是'
            : row == 1
            ? '否'
            : '',
        ...progressTemplates.map(
          (template) =>
              row < template.nodes.length ? template.nodes[row].name : '',
        ),
      ];
      sheet.appendRow(values.map(TextCellValue.new).toList());
    }
    for (var index = 0; index < headings.length; index++) {
      sheet.setColumnWidth(index, index == 3 || index == 4 ? 28 : 20);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: index, rowIndex: 6))
          .cellStyle = CellStyle(
        bold: true,
        fontColorHex: ExcelColor.white,
        backgroundColorHex: ExcelColor.fromHexString('#66798D'),
      );
    }
    sheet.setColumnWidth(0, 28);
  }

  static Future<ImportResult?> pickAndParse({
    required List<CategoryDefinition> categories,
    required List<ProgressTemplate> progressTemplates,
    required List<TaskTagDefinition> tags,
    required List<ContactEntry> contacts,
  }) async {
    final selected = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    if (selected.isEmpty) return null;
    final file = selected.single;
    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      throw FormatException('文件不能超过 10 MB。');
    }
    return parse(
      bytes,
      categories: categories,
      progressTemplates: progressTemplates,
      tags: tags,
      contacts: contacts,
    );
  }

  static ImportResult parse(
    Uint8List bytes, {
    required List<CategoryDefinition> categories,
    required List<ProgressTemplate> progressTemplates,
    required List<TaskTagDefinition> tags,
    required List<ContactEntry> contacts,
  }) {
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      throw FormatException('工作簿中没有可读取的工作表。');
    }
    final sheet = workbook.tables['计划'] ?? workbook.tables.values.first;
    if (sheet.rows.isEmpty) throw FormatException('工作表为空。');
    if (sheet.maxRows > 5001) throw FormatException('最多导入 5000 行计划。');

    final aliases = <String, String>{};
    for (final entry in headers.entries) {
      aliases[_normalize(entry.key)] = entry.key;
      aliases[_normalize(entry.value)] = entry.key;
    }
    aliases.addAll({
      '标题': 'name',
      '计划标题': 'name',
      '描述': 'description',
      '标签': 'tags',
      '日期': 'startDate',
    });
    final mapping = <int, String>{};
    for (var index = 0; index < sheet.rows.first.length; index++) {
      final raw = sheet.rows.first[index]?.value?.toString() ?? '';
      final key = aliases[_normalize(raw)];
      if (key != null) mapping[index] = key;
    }
    if (!mapping.containsValue('name')) {
      throw FormatException('第一行必须包含“计划名称”列。');
    }

    final categoryByName = {
      for (final category in categories) category.name: category,
    };
    final templateByName = {
      for (final template in progressTemplates) template.name: template,
    };
    final tagByName = {for (final tag in tags) tag.name: tag};
    final contactByName = {
      for (final contact in contacts) contact.name: contact,
    };
    final defaultTemplate = progressTemplates.isEmpty
        ? null
        : progressTemplates.first;
    if (defaultTemplate == null || defaultTemplate.nodes.isEmpty) {
      throw StateError('请先在 App 中配置至少一个包含节点的进度方案。');
    }

    final plans = <PlanItem>[];
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
      final name = values['name'] ?? '';
      if (name.isEmpty) {
        warnings.add('第 ${rowIndex + 1} 行缺少计划名称，已跳过。');
        continue;
      }

      final startDate = _normalizeDate(values['startDate'] ?? '');
      final targetDate = _normalizeDate(values['targetDate'] ?? '');
      if (startDate == null || targetDate == null) {
        warnings.add('第 ${rowIndex + 1} 行开始日期或目标日期无效，已跳过。');
        continue;
      }
      if (startDate.compareTo(targetDate) > 0) {
        warnings.add('第 ${rowIndex + 1} 行开始日期晚于目标日期，已跳过。');
        continue;
      }

      final now = DateTime.now();
      final id = (values['id'] ?? '').isEmpty
          ? 'xlsx-plan-${now.microsecondsSinceEpoch}-$rowIndex'
          : values['id']!;
      final categoryName = values['category'] ?? '';
      final category = categoryByName[categoryName];
      if (categoryName.isNotEmpty && category == null) {
        warnings.add('第 ${rowIndex + 1} 行分类不存在，已保留名称作为历史分类。');
      }

      final requestedTemplate = values['progressTemplate'] ?? '';
      final template = templateByName[requestedTemplate] ?? defaultTemplate;
      if (requestedTemplate.isNotEmpty && requestedTemplate != template.name) {
        warnings.add('第 ${rowIndex + 1} 行进度方案不存在，已使用“${template.name}”。');
      }
      final requestedNode = values['progressNode'] ?? '';
      final node = template.nodes.firstWhere(
        (item) => item.name == requestedNode,
        orElse: () => template.nodes.first,
      );
      if (requestedNode.isNotEmpty && requestedNode != node.name) {
        warnings.add('第 ${rowIndex + 1} 行进度节点不属于所选方案，已使用“${node.name}”。');
      }

      final importedTagNames = <String>{};
      final quadrantName = values['quadrant'] ?? '';
      if (quadrantName.isNotEmpty) {
        final quadrant = tagByName[quadrantName];
        if (quadrant?.isQuadrant ?? quadrantTagNames.contains(quadrantName)) {
          importedTagNames.add(quadrantName);
        } else {
          warnings.add('第 ${rowIndex + 1} 行四象限标签无效，已忽略。');
        }
      }
      for (final tagName in _splitComma(values['tags'] ?? '')) {
        if (tagByName[tagName]?.isQuadrant ??
            quadrantTagNames.contains(tagName)) {
          warnings.add('第 ${rowIndex + 1} 行普通标签包含四象限标签“$tagName”，已忽略。');
          continue;
        }
        importedTagNames.add(tagName);
      }
      final snapshots = <TaskTagSnapshot>[];
      for (final tagName in importedTagNames) {
        final definition = tagByName[tagName];
        if (definition == null) {
          warnings.add('第 ${rowIndex + 1} 行标签“$tagName”不存在，已作为历史标签保留。');
        }
        snapshots.add(
          TaskTagSnapshot(
            sourceTagId: definition?.id,
            name: tagName,
            colorValue: definition?.colorValue ?? 0xff8e8e93,
            iconName: definition?.iconName ?? 'label',
          ),
        );
      }

      final importedContacts = <ContactEntry>[];
      for (final contactName in _splitComma(values['contacts'] ?? '')) {
        final contact = contactByName[contactName];
        if (contact == null) {
          warnings.add('第 ${rowIndex + 1} 行联系人“$contactName”不存在，已忽略。');
        } else {
          importedContacts.add(contact);
        }
      }
      final reminderRules = _parseReminders(
        values['reminders'] ?? '',
        id,
        rowIndex + 1,
        warnings,
      );
      final progressInstanceId = 'plan-progress-$id';
      final progressNodes = template.nodes
          .map(
            (item) => ProgressNode(
              id: '$progressInstanceId-${item.id}',
              name: item.name,
              colorValue: item.colorValue,
              kind: item.kind,
              sortOrder: item.sortOrder,
            ),
          )
          .toList();
      final currentNode = progressNodes.firstWhere(
        (item) => item.name == node.name,
        orElse: () => progressNodes.first,
      );
      plans.add(
        PlanItem(
          id: id,
          name: name,
          description: values['description'] ?? '',
          startDate: startDate,
          targetDate: targetDate,
          categoryName: categoryName,
          categoryColorValue: category?.colorValue ?? 0xff8e8e93,
          categoryIconName: category?.iconName ?? 'project',
          tags: snapshots,
          progress: ProgressSnapshot(
            instanceId: progressInstanceId,
            sourceTemplateId: template.id,
            templateName: template.name,
            currentNodeId: currentNode.id,
            nodes: progressNodes,
          ),
          milestones: const [],
          rules: const [],
          updatedAt: DateTime.tryParse(values['updatedAt'] ?? '') ?? now,
          calendarDisplayMode:
              _calendarModes[values['calendarDisplayMode']] ??
              PlanCalendarDisplayMode.wholePeriod,
          reminderEnabled:
              _parseBoolean(values['reminderEnabled'] ?? '') &&
              reminderRules.isNotEmpty,
          reminders: reminderRules,
          contacts: importedContacts,
        ),
      );
    }
    return ImportResult(plans: plans, warnings: warnings);
  }

  static List<String> _splitComma(String value) => value
      .split(RegExp(r'[,，]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();

  static bool _parseBoolean(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == '是' || normalized == 'true' || normalized == '1';
  }

  static String? _normalizeDate(String value) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return null;
    return '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');

  static List<TaskReminderRule> _parseReminders(
    String raw,
    String planId,
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
          id: 'reminder-$planId-${entry.$1}',
          taskId: planId,
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

  static Uint8List _addWorkbookValidation(
    Uint8List bytes, {
    required List<CategoryDefinition> categories,
    required List<ProgressTemplate> progressTemplates,
    required List<TaskTagDefinition> tags,
  }) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final workbookFile = archive.findFile('xl/workbook.xml');
    final relationsFile = archive.findFile('xl/_rels/workbook.xml.rels');
    final stylesFile = archive.findFile('xl/styles.xml');
    if (workbookFile == null || relationsFile == null || stylesFile == null) {
      return bytes;
    }

    var workbookXml = utf8.decode(workbookFile.content as List<int>);
    final relationsXml = utf8.decode(relationsFile.content as List<int>);
    final planSheetPath = _worksheetPath(workbookXml, relationsXml, '计划');
    if (planSheetPath == null) return bytes;
    final planSheetFile = archive.findFile(planSheetPath);
    if (planSheetFile == null) return bytes;

    const guideStartRow = 8;
    final quadrantCount = tags.where((tag) => tag.isQuadrant).length;
    final names = <String>[
      _definedName('ClPlanCategories', 'A', categories.length, guideStartRow),
      _definedName(
        'ClPlanProgressTemplates',
        'B',
        progressTemplates.length,
        guideStartRow,
      ),
      _definedName('ClPlanQuadrants', 'C', quadrantCount, guideStartRow),
      _definedName(
        'ClPlanCalendarModes',
        'F',
        _calendarModes.length,
        guideStartRow,
      ),
      _definedName('ClPlanBooleans', 'G', 2, guideStartRow),
      for (var index = 0; index < progressTemplates.length; index++)
        _definedName(
          'ClPlanProgressNodes_${index + 1}',
          _columnName(7 + index),
          progressTemplates[index].nodes.length,
          guideStartRow,
        ),
    ];
    final definedNames = '<definedNames>${names.join()}</definedNames>';
    workbookXml = workbookXml.contains('<definedNames>')
        ? workbookXml.replaceFirst(
            '</definedNames>',
            '${names.join()}</definedNames>',
          )
        : workbookXml.contains('<calcPr')
        ? workbookXml.replaceFirst('<calcPr', '$definedNames<calcPr')
        : workbookXml.replaceFirst('</workbook>', '$definedNames</workbook>');
    final workbookData = utf8.encode(workbookXml);
    archive.addFile(
      ArchiveFile(workbookFile.name, workbookData.length, workbookData),
    );

    var stylesXml = utf8.decode(stylesFile.content as List<int>);
    final cellXfsMatch = RegExp(
      r'<cellXfs count="(\d+)">',
    ).firstMatch(stylesXml);
    if (cellXfsMatch == null) return bytes;
    final unlockedStyleIndex = int.parse(cellXfsMatch.group(1)!);
    stylesXml = stylesXml.replaceFirst(
      cellXfsMatch.group(0)!,
      '<cellXfs count="${unlockedStyleIndex + 1}">',
    );
    const unlockedStyle =
        '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyProtection="1"><protection locked="0"/></xf>';
    stylesXml = stylesXml.replaceFirst(
      '</cellXfs>',
      '$unlockedStyle</cellXfs>',
    );
    final stylesData = utf8.encode(stylesXml);
    archive.addFile(
      ArchiveFile(stylesFile.name, stylesData.length, stylesData),
    );

    var sheetXml = utf8.decode(planSheetFile.content as List<int>);
    sheetXml = sheetXml.replaceAllMapped(RegExp(r'<col\b[^>]*/>'), (match) {
      var columnXml = match.group(0)!;
      final minimum = RegExp(r'\bmin="(\d+)"').firstMatch(columnXml);
      final maximum = RegExp(r'\bmax="(\d+)"').firstMatch(columnXml);
      final minColumn = int.tryParse(minimum?.group(1) ?? '');
      final maxColumn = int.tryParse(maximum?.group(1) ?? '');
      if (minColumn == null || maxColumn == null) return columnXml;
      if (minColumn <= 1 && maxColumn >= 1) {
        columnXml = _withXmlAttribute(columnXml, 'hidden', '1');
      }
      if (minColumn >= 2) {
        columnXml = _withXmlAttribute(
          columnXml,
          'style',
          '$unlockedStyleIndex',
        );
      }
      return columnXml;
    });
    const protection =
        '<sheetProtection sheet="1" objects="1" scenarios="1" formatColumns="1" selectLockedCells="1" selectUnlockedCells="0"/>';
    sheetXml = sheetXml.replaceFirst(
      '</sheetData>',
      '</sheetData>$protection',
    );
    const validations = '''<dataValidations count="6">
<dataValidation type="list" allowBlank="1" showInputMessage="1" showErrorMessage="1" errorStyle="stop" promptTitle="选择分类" prompt="请选择 App 内已有分类，也可留空。" errorTitle="分类无效" error="请从下拉列表选择分类。" sqref="D2:D5001"><formula1>ClPlanCategories</formula1></dataValidation>
<dataValidation type="list" allowBlank="0" showInputMessage="1" showErrorMessage="1" errorStyle="stop" promptTitle="选择进度方案" prompt="选择方案后，进度节点下拉会显示对应节点。" errorTitle="进度方案无效" error="请从下拉列表选择进度方案。" sqref="E2:E5001"><formula1>ClPlanProgressTemplates</formula1></dataValidation>
<dataValidation type="list" allowBlank="0" showInputMessage="1" showErrorMessage="1" errorStyle="stop" promptTitle="选择进度节点" prompt="节点选项随本行进度方案变化。" errorTitle="进度节点无效" error="请选择当前进度方案中的节点。" sqref="F2:F5001"><formula1>INDIRECT("ClPlanProgressNodes_"&amp;MATCH(\$E2,ClPlanProgressTemplates,0))</formula1></dataValidation>
<dataValidation type="list" allowBlank="1" showInputMessage="1" showErrorMessage="1" errorStyle="stop" promptTitle="选择四象限" prompt="四象限标签为单选，也可以留空。" errorTitle="四象限标签无效" error="请从下拉列表选择四象限标签。" sqref="G2:G5001"><formula1>ClPlanQuadrants</formula1></dataValidation>
<dataValidation type="list" allowBlank="0" showErrorMessage="1" errorStyle="stop" errorTitle="日历显示无效" error="请从下拉列表选择日历显示方式。" sqref="L2:L5001"><formula1>ClPlanCalendarModes</formula1></dataValidation>
<dataValidation type="list" allowBlank="0" showErrorMessage="1" errorStyle="stop" errorTitle="提醒选项无效" error="请选择“是”或“否”。" sqref="M2:M5001"><formula1>ClPlanBooleans</formula1></dataValidation>
</dataValidations>''';
    if (sheetXml.contains('<printOptions')) {
      sheetXml = sheetXml.replaceFirst(
        '<printOptions',
        '$validations<printOptions',
      );
    } else if (sheetXml.contains('<pageMargins')) {
      sheetXml = sheetXml.replaceFirst(
        '<pageMargins',
        '$validations<pageMargins',
      );
    } else {
      sheetXml = sheetXml.replaceFirst(
        '</worksheet>',
        '$validations</worksheet>',
      );
    }
    final sheetData = utf8.encode(sheetXml);
    archive.addFile(
      ArchiveFile(planSheetFile.name, sheetData.length, sheetData),
    );
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static String _definedName(
    String name,
    String column,
    int count,
    int startRow,
  ) {
    final endRow = startRow + (count <= 0 ? 0 : count - 1);
    return '<definedName name="$name">\'填写说明\'!\$$column\$$startRow:\$$column\$$endRow</definedName>';
  }

  static String? _worksheetPath(
    String workbookXml,
    String relationsXml,
    String sheetName,
  ) {
    final escapedName = RegExp.escape(sheetName);
    final sheetMatch = RegExp(
      '<sheet[^>]*name="$escapedName"[^>]*r:id="([^"]+)"[^>]*/>',
    ).firstMatch(workbookXml);
    final relationId = sheetMatch?.group(1);
    if (relationId == null) return null;
    final escapedId = RegExp.escape(relationId);
    final relationMatch = RegExp(
      '<Relationship[^>]*Id="$escapedId"[^>]*Target="([^"]+)"[^>]*/>',
    ).firstMatch(relationsXml);
    final target = relationMatch?.group(1);
    if (target == null) return null;
    if (target.startsWith('/')) return target.substring(1);
    return p.posix.normalize(p.posix.join('xl', target));
  }

  static String _columnName(int zeroBasedIndex) {
    var value = zeroBasedIndex + 1;
    var result = '';
    while (value > 0) {
      value--;
      result = String.fromCharCode(65 + value % 26) + result;
      value ~/= 26;
    }
    return result;
  }

  static String _withXmlAttribute(
    String element,
    String attribute,
    String value,
  ) {
    final expression = RegExp('\\b$attribute="[^"]*"');
    if (expression.hasMatch(element)) {
      return element.replaceFirst(expression, '$attribute="$value"');
    }
    return element.replaceFirst('/>', ' $attribute="$value"/>');
  }
}
