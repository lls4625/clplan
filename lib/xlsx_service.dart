import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:characters/characters.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';
import 'l10n/preset_text.dart';
import 'l10n/ui_text.dart' show localizeUiTextForLocale;

class ImportResult {
  const ImportResult({required this.plans, required this.warnings});

  final List<PlanItem> plans;
  final List<String> warnings;
}

class ContactImportResult {
  const ContactImportResult({required this.contacts, required this.warnings});

  final List<ContactEntry> contacts;
  final List<String> warnings;
}

class XlsxService {
  static const _schemaSheetName = '_ClPlanSchema';
  static const _schemaVersion = '3';
  static const _exportLocales = <Locale>[
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('ja'),
    Locale('ko'),
    Locale('en'),
  ];
  static const maxImportFileSizeMegabytes = 50;
  static const maxImportDataRows = 10000;

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
    'completedAt': '完成时间',
    'updatedAt': '更新时间',
    'contactIds': '联系人ID',
    'milestones': '里程碑',
    'recurrenceRules': '周期任务',
    'categoryId': '分类ID',
    'progressTemplateId': '进度方案ID',
    'progressNodeId': '进度节点ID',
    'tagIds': '标签ID',
  };

  static const _calendarModes = <String, PlanCalendarDisplayMode>{
    '整个期间': PlanCalendarDisplayMode.wholePeriod,
    '仅起止日': PlanCalendarDisplayMode.endpoints,
    '仅开始日': PlanCalendarDisplayMode.startOnly,
    '仅目标日': PlanCalendarDisplayMode.targetOnly,
  };

  static const contactHeaders = <String, String>{
    'id': '联系人ID',
    'name': '姓名',
    'phone': '电话',
    'remark': '备注',
  };

  static String _text(Locale locale, String source) {
    final language = locale.languageCode;
    final exportTranslation = switch (language) {
      'en' => _xlsxEnglish[source],
      'ja' => _xlsxJapanese[source],
      'ko' => _xlsxKorean[source],
      _ => null,
    };
    return exportTranslation ?? localizeUiTextForLocale(locale, source);
  }

  static String localizedHeader(Locale locale, String key) =>
      _text(locale, headers[key] ?? contactHeaders[key] ?? key);

  static const _xlsxEnglish = <String, String>{
    '导出 ClPlan 计划': 'Export ClPlan plans',
    '导出 ClPlan 联系人': 'Export ClPlan contacts',
    'ClPlan 计划导入说明': 'ClPlan plan import instructions',
    '“计划名称、开始日期、目标日期”为必填项；计划ID是隐藏且锁定的主键，有主键时更新对应计划，无主键时新增计划。':
        '“Plan name”, “Start date”, and “Target date” are required. Plan ID is a hidden, locked primary key: matching IDs update plans; blank IDs create plans.',
    '再次导入只会新增计划或更新相同计划ID的数据，不会删除本地已有的其他计划。':
        'Reimporting only creates plans or updates matching plan IDs; it does not delete other local plans.',
    '分类、进度方案、进度节点、四象限标签均可在“计划”工作表下拉选择。':
        'Category, progress template, progress node, and quadrant tag can be selected from lists on the Plans sheet.',
    '普通标签和联系人可填写多个，请使用英文逗号 , 分隔；可选内容见下方。':
        'Multiple regular tags and contacts are allowed. Separate them with commas (,); available values are listed below.',
    '联系人ID、里程碑和周期任务用于完整备份；除非明确了解 JSON 结构，否则请保留导出值。':
        'Contact IDs, milestones, and recurring tasks are used for complete backups. Keep exported values unless you understand their JSON structure.',
    'ClPlan 联系人导入说明': 'ClPlan contact import instructions',
    '“姓名”为必填项；联系人ID是隐藏且锁定的主键，有主键时更新对应联系人，无主键时新增联系人。':
        '“Name” is required. Contact ID is a hidden, locked primary key: matching IDs update contacts; blank IDs create contacts.',
    '再次导入不会删除本地已有的其他联系人；备注最多 100 个字符。':
        'Reimporting does not delete other local contacts. Notes can contain up to 100 characters.',
    '普通标签（英文逗号分隔）': 'Regular tags (comma-separated)',
    '联系人（英文逗号分隔）': 'Contacts (comma-separated)',
    '选择分类': 'Select category',
    '请选择 App 内已有分类，也可留空。':
        'Select an existing app category or leave this blank.',
    '分类无效': 'Invalid category',
    '请从下拉列表选择分类。': 'Select a category from the list.',
    '选择进度方案': 'Select progress template',
    '选择方案后，进度节点下拉会显示对应节点。':
        'After selecting a template, the progress-node list shows its nodes.',
    '进度方案无效': 'Invalid progress template',
    '请从下拉列表选择进度方案。':
        'Select a progress template from the list.',
    '选择进度节点': 'Select progress node',
    '节点选项随本行进度方案变化。':
        'Node choices follow the progress template selected in this row.',
    '进度节点无效': 'Invalid progress node',
    '请选择当前进度方案中的节点。':
        'Select a node from the current progress template.',
    '选择四象限': 'Select quadrant',
    '四象限标签为单选，也可以留空。':
        'Choose one quadrant tag or leave this blank.',
    '四象限标签无效': 'Invalid quadrant tag',
    '请从下拉列表选择四象限标签。':
        'Select a quadrant tag from the list.',
    '日历显示无效': 'Invalid calendar display',
    '请从下拉列表选择日历显示方式。':
        'Select a calendar display mode from the list.',
    '提醒选项无效': 'Invalid reminder option',
    '请选择“是”或“否”。': 'Select “Yes” or “No”.',
  };

  static const _xlsxJapanese = <String, String>{
    '计划ID': '計画 ID',
    '联系人ID': '連絡先 ID',
    '四象限标签': '四象限タグ',
    '普通标签': '通常タグ',
    '更新时间': '更新日時',
    '导出 ClPlan 计划': 'ClPlan の計画をエクスポート',
    '导出 ClPlan 联系人': 'ClPlan の連絡先をエクスポート',
    'ClPlan 计划导入说明': 'ClPlan 計画インポートガイド',
    '“计划名称、开始日期、目标日期”为必填项；计划ID是隐藏且锁定的主键，有主键时更新对应计划，无主键时新增计划。':
        '「計画名」「開始日」「目標日」は必須です。計画 ID は非表示・ロック済みの主キーで、一致する ID は更新、空欄は新規作成されます。',
    '再次导入只会新增计划或更新相同计划ID的数据，不会删除本地已有的其他计划。':
        '再インポートでは計画の追加または同一 ID の更新のみを行い、他のローカル計画は削除しません。',
    '分类、进度方案、进度节点、四象限标签均可在“计划”工作表下拉选择。':
        'カテゴリー、進捗テンプレート、進捗ノード、四象限タグは「計画」シートのリストから選択できます。',
    '普通标签和联系人可填写多个，请使用英文逗号 , 分隔；可选内容见下方。':
        '通常タグと連絡先は複数入力できます。半角カンマ (,) で区切り、下の候補を参照してください。',
    '联系人ID、里程碑和周期任务用于完整备份；除非明确了解 JSON 结构，否则请保留导出值。':
        '連絡先 ID、マイルストーン、繰り返しタスクは完全なバックアップ用です。JSON 構造を理解していない場合は値を変更しないでください。',
    'ClPlan 联系人导入说明': 'ClPlan 連絡先インポートガイド',
    '“姓名”为必填项；联系人ID是隐藏且锁定的主键，有主键时更新对应联系人，无主键时新增联系人。':
        '「名前」は必須です。連絡先 ID は非表示・ロック済みの主キーで、一致する ID は更新、空欄は新規作成されます。',
    '再次导入不会删除本地已有的其他联系人；备注最多 100 个字符。':
        '再インポートで他のローカル連絡先は削除されません。メモは 100 文字までです。',
    '普通标签（英文逗号分隔）': '通常タグ（半角カンマ区切り）',
    '联系人（英文逗号分隔）': '連絡先（半角カンマ区切り）',
    '选择分类': 'カテゴリーを選択',
    '请选择 App 内已有分类，也可留空。': 'アプリ内のカテゴリーを選択するか、空欄にしてください。',
    '分类无效': '無効なカテゴリー',
    '请从下拉列表选择分类。': 'リストからカテゴリーを選択してください。',
    '选择进度方案': '進捗テンプレートを選択',
    '选择方案后，进度节点下拉会显示对应节点。': 'テンプレートを選択すると、対応する進捗ノードが表示されます。',
    '进度方案无效': '無効な進捗テンプレート',
    '请从下拉列表选择进度方案。': 'リストから進捗テンプレートを選択してください。',
    '选择进度节点': '進捗ノードを選択',
    '节点选项随本行进度方案变化。': 'ノード候補はこの行の進捗テンプレートに連動します。',
    '进度节点无效': '無効な進捗ノード',
    '请选择当前进度方案中的节点。': '現在の進捗テンプレート内のノードを選択してください。',
    '选择四象限': '四象限を選択',
    '四象限标签为单选，也可以留空。': '四象限タグは 1 つだけ選択でき、空欄にもできます。',
    '四象限标签无效': '無効な四象限タグ',
    '请从下拉列表选择四象限标签。': 'リストから四象限タグを選択してください。',
    '日历显示无效': '無効なカレンダー表示',
    '请从下拉列表选择日历显示方式。': 'リストからカレンダー表示方法を選択してください。',
    '提醒选项无效': '無効なリマインダー設定',
    '请选择“是”或“否”。': '「はい」または「いいえ」を選択してください。',
  };

  static const _xlsxKorean = <String, String>{
    '计划ID': '계획 ID',
    '联系人ID': '연락처 ID',
    '四象限标签': '4분면 태그',
    '普通标签': '일반 태그',
    '更新时间': '업데이트 시각',
    '导出 ClPlan 计划': 'ClPlan 계획 내보내기',
    '导出 ClPlan 联系人': 'ClPlan 연락처 내보내기',
    'ClPlan 计划导入说明': 'ClPlan 계획 가져오기 안내',
    '“计划名称、开始日期、目标日期”为必填项；计划ID是隐藏且锁定的主键，有主键时更新对应计划，无主键时新增计划。':
        '“계획 이름”, “시작 날짜”, “목표 날짜”는 필수입니다. 계획 ID는 숨겨진 잠긴 기본 키이며, 같은 ID는 업데이트하고 빈 ID는 새로 생성합니다.',
    '再次导入只会新增计划或更新相同计划ID的数据，不会删除本地已有的其他计划。':
        '다시 가져오면 계획을 추가하거나 같은 ID를 업데이트하며 다른 로컬 계획은 삭제하지 않습니다.',
    '分类、进度方案、进度节点、四象限标签均可在“计划”工作表下拉选择。':
        '카테고리, 진행 템플릿, 진행 단계, 4분면 태그는 계획 시트의 목록에서 선택할 수 있습니다.',
    '普通标签和联系人可填写多个，请使用英文逗号 , 分隔；可选内容见下方。':
        '일반 태그와 연락처는 여러 개를 입력할 수 있으며 영문 쉼표(,)로 구분합니다. 선택 항목은 아래에 있습니다.',
    '联系人ID、里程碑和周期任务用于完整备份；除非明确了解 JSON 结构，否则请保留导出值。':
        '연락처 ID, 마일스톤, 반복 작업은 완전한 백업에 사용됩니다. JSON 구조를 알지 못하면 내보낸 값을 유지하세요.',
    'ClPlan 联系人导入说明': 'ClPlan 연락처 가져오기 안내',
    '“姓名”为必填项；联系人ID是隐藏且锁定的主键，有主键时更新对应联系人，无主键时新增联系人。':
        '“이름”은 필수입니다. 연락처 ID는 숨겨진 잠긴 기본 키이며, 같은 ID는 업데이트하고 빈 ID는 새로 생성합니다.',
    '再次导入不会删除本地已有的其他联系人；备注最多 100 个字符。':
        '다시 가져와도 다른 로컬 연락처는 삭제되지 않습니다. 메모는 최대 100자입니다.',
    '普通标签（英文逗号分隔）': '일반 태그(영문 쉼표로 구분)',
    '联系人（英文逗号分隔）': '연락처(영문 쉼표로 구분)',
    '选择分类': '카테고리 선택',
    '请选择 App 内已有分类，也可留空。': '앱에 있는 카테고리를 선택하거나 비워 두세요.',
    '分类无效': '잘못된 카테고리',
    '请从下拉列表选择分类。': '목록에서 카테고리를 선택하세요.',
    '选择进度方案': '진행 템플릿 선택',
    '选择方案后，进度节点下拉会显示对应节点。': '템플릿을 선택하면 해당 진행 단계가 표시됩니다.',
    '进度方案无效': '잘못된 진행 템플릿',
    '请从下拉列表选择进度方案。': '목록에서 진행 템플릿을 선택하세요.',
    '选择进度节点': '진행 단계 선택',
    '节点选项随本行进度方案变化。': '단계 선택지는 이 행의 진행 템플릿에 따라 바뀍니다.',
    '进度节点无效': '잘못된 진행 단계',
    '请选择当前进度方案中的节点。': '현재 진행 템플릿의 단계를 선택하세요.',
    '选择四象限': '4분면 선택',
    '四象限标签为单选，也可以留空。': '4분면 태그는 하나만 선택하거나 비워 둘 수 있습니다.',
    '四象限标签无效': '잘못된 4분면 태그',
    '请从下拉列表选择四象限标签。': '목록에서 4분면 태그를 선택하세요.',
    '日历显示无效': '잘못된 달력 표시',
    '请从下拉列表选择日历显示方式。': '목록에서 달력 표시 방식을 선택하세요.',
    '提醒选项无效': '잘못된 미리 알림 옵션',
    '请选择“是”或“否”。': '“예” 또는 “아니요”를 선택하세요.',
  };

  static void _writeSchemaSheet(
    Sheet sheet, {
    required String entityType,
    required Locale locale,
    required String dataSheetName,
    required Iterable<String> fieldKeys,
  }) {
    sheet.appendRow([
      TextCellValue('ClPlanSchema'),
      TextCellValue(_schemaVersion),
      TextCellValue(entityType),
      TextCellValue(locale.toLanguageTag()),
      TextCellValue(dataSheetName),
    ]);
    sheet.appendRow(fieldKeys.map(TextCellValue.new).toList());
  }

  static ({String dataSheetName, List<String> fieldKeys})? _readSchema(
    Excel workbook,
    String expectedEntityType,
  ) {
    final sheet = workbook.tables[_schemaSheetName];
    if (sheet == null || sheet.rows.length < 2) return null;
    final metadata = sheet.rows.first;
    String cell(int index) => index < metadata.length
        ? metadata[index]?.value?.toString() ?? ''
        : '';
    if (cell(0) != 'ClPlanSchema' ||
        !{'2', _schemaVersion}.contains(cell(1)) ||
        cell(2) != expectedEntityType ||
        cell(4).isEmpty) {
      return null;
    }
    final fieldKeys = sheet.rows[1]
        .map((cell) => cell?.value?.toString() ?? '')
        .toList(growable: false);
    return (dataSheetName: cell(4), fieldKeys: fieldKeys);
  }

  static Future<void> exportPlans({
    required List<PlanItem> plans,
    required List<CategoryDefinition> categories,
    required List<ProgressTemplate> progressTemplates,
    required List<TaskTagDefinition> tags,
    required List<ContactEntry> contacts,
    required Locale locale,
  }) async {
    final workbook = Excel.createExcel();
    final defaultName = workbook.getDefaultSheet();
    final planSheetName = _text(locale, '计划');
    final guideSheetName = _text(locale, '填写说明');
    final sheet = workbook[planSheetName];
    final guide = workbook[guideSheetName];
    final schema = workbook[_schemaSheetName];
    if (defaultName != null &&
        defaultName != planSheetName &&
        defaultName != guideSheetName &&
        defaultName != _schemaSheetName) {
      workbook.delete(defaultName);
    }

    _writeSchemaSheet(
      schema,
      entityType: 'plans',
      locale: locale,
      dataSheetName: planSheetName,
      fieldKeys: headers.keys,
    );
    _writePlanSheet(
      sheet,
      plans,
      categories,
      progressTemplates,
      tags,
      locale,
    );
    _writeGuideSheet(
      guide,
      categories: categories,
      progressTemplates: progressTemplates,
      tags: tags,
      contacts: contacts,
      locale: locale,
    );

    final rawBytes = workbook.save();
    if (rawBytes == null) throw StateError('无法生成 XLSX 文件。');
    final bytes = _addWorkbookValidation(
      Uint8List.fromList(rawBytes),
      categories: categories,
      progressTemplates: progressTemplates,
      tags: tags,
      planSheetName: planSheetName,
      guideSheetName: guideSheetName,
      locale: locale,
    );
    final finalBytes = _hideSchemaSheet(bytes);

    final directory = await getTemporaryDirectory();
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final file = File(
      p.join(directory.path, 'ClPlan-${_text(locale, '计划')}-$date.xlsx'),
    );
    await file.writeAsBytes(finalBytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        title: _text(locale, '导出 ClPlan 计划'),
      ),
    );
  }

  static Future<void> exportContacts({
    required List<ContactEntry> contacts,
    required Locale locale,
  }) async {
    final workbook = Excel.createExcel();
    final defaultName = workbook.getDefaultSheet();
    final contactSheetName = _text(locale, '联系人');
    final guideSheetName = _text(locale, '填写说明');
    final sheet = workbook[contactSheetName];
    final guide = workbook[guideSheetName];
    final schema = workbook[_schemaSheetName];
    if (defaultName != null &&
        defaultName != contactSheetName &&
        defaultName != guideSheetName &&
        defaultName != _schemaSheetName) {
      workbook.delete(defaultName);
    }

    _writeSchemaSheet(
      schema,
      entityType: 'contacts',
      locale: locale,
      dataSheetName: contactSheetName,
      fieldKeys: contactHeaders.keys,
    );
    _writeContactSheet(sheet, contacts, locale);
    guide.appendRow([
      TextCellValue(_text(locale, 'ClPlan 联系人导入说明')),
    ]);
    guide.appendRow([
      TextCellValue(
        _text(
          locale,
          '“姓名”为必填项；联系人ID是隐藏且锁定的主键，有主键时更新对应联系人，无主键时新增联系人。',
        ),
      ),
    ]);
    guide.appendRow([
      TextCellValue(
        _text(
          locale,
          '再次导入不会删除本地已有的其他联系人；备注最多 100 个字符。',
        ),
      ),
    ]);
    guide.setColumnWidth(0, 96);

    final rawBytes = workbook.save();
    if (rawBytes == null) throw StateError('无法生成 XLSX 文件。');
    final bytes = _protectPrimaryKeyColumn(
      Uint8List.fromList(rawBytes),
      sheetName: contactSheetName,
    );
    final finalBytes = _hideSchemaSheet(bytes);

    final directory = await getTemporaryDirectory();
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final file = File(
      p.join(
        directory.path,
        'ClPlan-${_text(locale, '联系人')}-$date.xlsx',
      ),
    );
    await file.writeAsBytes(finalBytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        title: _text(locale, '导出 ClPlan 联系人'),
      ),
    );
  }

  static void _writePlanSheet(
    Sheet sheet,
    List<PlanItem> plans,
    List<CategoryDefinition> categories,
    List<ProgressTemplate> progressTemplates,
    List<TaskTagDefinition> definitions,
    Locale locale,
  ) {
    sheet.appendRow(
      headers.values
          .map((header) => TextCellValue(_text(locale, header)))
          .toList(),
    );
    final quadrantNames = definitions
        .where((tag) => tag.isQuadrant)
        .map((tag) => tag.name)
        .toSet();
    final categoriesById = {for (final item in categories) item.id: item};
    final templatesById = {
      for (final item in progressTemplates) item.id: item,
    };
    final nodesById = {
      for (final template in progressTemplates)
        for (final node in template.nodes) node.id: node,
    };
    final tagsById = {for (final item in definitions) item.id: item};
    String tagName(TaskTagSnapshot snapshot) {
      final definition = tagsById[snapshot.sourceTagId];
      return definition == null
          ? snapshot.name
          : tagDefinitionName(definition, locale);
    }
    for (final plan in plans) {
      String? quadrant;
      for (final tag in plan.tags) {
        if (quadrantNames.contains(tag.name)) {
          quadrant = tagName(tag);
          break;
        }
      }
      final ordinaryTags = plan.tags
          .where((tag) => !quadrantNames.contains(tag.name))
          .map(tagName)
          .join(',');
      sheet.appendRow(
        <String>[
          plan.id,
          plan.name,
          plan.description,
          switch (categoriesById[plan.sourceCategoryId]) {
            final category? => categoryDefinitionName(category, locale),
            null => plan.categoryName,
          },
          switch (templatesById[plan.progress.sourceTemplateId]) {
            final template? => progressTemplateName(template, locale),
            null => presetNameForLocale(
              locale: locale,
              id: plan.progress.sourceTemplateId ?? '',
              fallback: plan.progress.templateName,
              nameSource: plan.progress.templateNameSource,
            ),
          },
          plan.progress.currentNode == null
              ? ''
              : progressNodeName(
                  nodesById[plan.progress.currentNode!.sourceNodeId] ??
                      plan.progress.currentNode!,
                  locale,
                ),
          quadrant ?? '',
          ordinaryTags,
          plan.startDate,
          plan.targetDate,
          plan.contacts.map((contact) => contact.name).join(','),
          _text(locale, plan.calendarDisplayMode.label),
          _text(locale, plan.reminderEnabled ? '是' : '否'),
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
          plan.completedAt?.toIso8601String() ?? '',
          plan.updatedAt.toIso8601String(),
          plan.contacts.map((contact) => contact.id).join(','),
          jsonEncode(
            plan.milestones
                .map(
                  (item) => {
                    'id': item.id,
                    'name': item.name,
                    'date': item.date,
                    'description': item.description,
                    'completed': item.completed,
                  },
                )
                .toList(),
          ),
          jsonEncode(
            plan.rules
                .map(
                  (rule) => {
                    'id': rule.id,
                    'title': rule.title,
                    'description': rule.description,
                    'startDate': rule.startDate,
                    'endDate': rule.endDate,
                    'startTime': rule.startTime,
                    'weekdays': rule.weekdays.toList()..sort(),
                    'enabled': rule.enabled,
                    'progressTemplate': switch (templatesById[
                      rule.progress.sourceTemplateId
                    ]) {
                      final template? => progressTemplateName(template, locale),
                      null => presetNameForLocale(
                        locale: locale,
                        id: rule.progress.sourceTemplateId ?? '',
                        fallback: rule.progress.templateName,
                        nameSource: rule.progress.templateNameSource,
                      ),
                    },
                    'progressNode': rule.progress.currentNode == null
                        ? ''
                        : progressNodeName(
                            nodesById[
                                  rule.progress.currentNode!.sourceNodeId
                                ] ??
                                rule.progress.currentNode!,
                            locale,
                          ),
                  },
                )
                .toList(),
          ),
          plan.sourceCategoryId ?? '',
          plan.progress.sourceTemplateId ?? '',
          plan.progress.currentNode?.sourceNodeId ?? '',
          plan.tags
              .map((tag) => tag.sourceTagId ?? '')
              .where((id) => id.isNotEmpty)
              .join(','),
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
      24,
      30,
      48,
      56,
      24,
      24,
      24,
      36,
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

  static void _writeContactSheet(
    Sheet sheet,
    List<ContactEntry> contacts,
    Locale locale,
  ) {
    sheet.appendRow(
      contactHeaders.values
          .map((header) => TextCellValue(_text(locale, header)))
          .toList(),
    );
    for (final contact in contacts) {
      sheet.appendRow(
        [
          contact.id,
          contact.name,
          contact.phone,
          contact.remark,
        ].map(TextCellValue.new).toList(),
      );
    }
    const widths = <double>[26, 20, 22, 40];
    for (var index = 0; index < widths.length; index++) {
      sheet.setColumnWidth(index, widths[index]);
    }
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#315D8A'),
      verticalAlign: VerticalAlign.Center,
    );
    for (var index = 0; index < contactHeaders.length; index++) {
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
    required Locale locale,
  }) {
    const guideRows = <List<String>>[
      ['ClPlan 计划导入说明'],
      ['“计划名称、开始日期、目标日期”为必填项；计划ID是隐藏且锁定的主键，有主键时更新对应计划，无主键时新增计划。'],
      ['再次导入只会新增计划或更新相同计划ID的数据，不会删除本地已有的其他计划。'],
      ['分类、进度方案、进度节点、四象限标签均可在“计划”工作表下拉选择。'],
      ['普通标签和联系人可填写多个，请使用英文逗号 , 分隔；可选内容见下方。'],
      ['联系人ID、里程碑和周期任务用于完整备份；除非明确了解 JSON 结构，否则请保留导出值。'],
      [],
    ];
    for (final row in guideRows) {
      sheet.appendRow(
        row.map((value) => TextCellValue(_text(locale, value))).toList(),
      );
    }

    final quadrantTags = tags.where((tag) => tag.isQuadrant).toList();
    final ordinaryTags = tags.where((tag) => !tag.isQuadrant).toList();
    final headings = <String>[
      _text(locale, '分类'),
      _text(locale, '进度方案'),
      _text(locale, '四象限标签'),
      _text(locale, '普通标签（英文逗号分隔）'),
      _text(locale, '联系人（英文逗号分隔）'),
      _text(locale, '日历显示'),
      _text(locale, '启用提醒'),
      ...progressTemplates.map(
        (template) =>
            '${progressTemplateName(template, locale)}·${_text(locale, '节点')}',
      ),
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
        row < categories.length
            ? categoryDefinitionName(categories[row], locale)
            : '',
        row < progressTemplates.length
            ? progressTemplateName(progressTemplates[row], locale)
            : '',
        row < quadrantTags.length
            ? tagDefinitionName(quadrantTags[row], locale)
            : '',
        row < ordinaryTags.length
            ? tagDefinitionName(ordinaryTags[row], locale)
            : '',
        row < contacts.length ? contacts[row].name : '',
        row < _calendarModes.length
            ? _text(locale, _calendarModes.keys.elementAt(row))
            : '',
        row == 0
            ? _text(locale, '是')
            : row == 1
            ? _text(locale, '否')
            : '',
        ...progressTemplates.map(
          (template) =>
              row < template.nodes.length
              ? progressNodeName(template.nodes[row], locale)
              : '',
        ),
      ];
      sheet.appendRow(values.map(TextCellValue.new).toList());
    }
    for (var index = 0; index < headings.length; index++) {
      sheet.setColumnWidth(index, index == 3 || index == 4 ? 28 : 20);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: index, rowIndex: 7))
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
    if (bytes.length > maxImportFileSizeMegabytes * 1024 * 1024) {
      throw FormatException('文件不能超过 $maxImportFileSizeMegabytes MB。');
    }
    return parse(
      bytes,
      categories: categories,
      progressTemplates: progressTemplates,
      tags: tags,
      contacts: contacts,
    );
  }

  static Future<ContactImportResult?> pickAndParseContacts() async {
    final selected = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    if (selected.isEmpty) return null;
    final file = selected.single;
    final bytes = await file.readAsBytes();
    if (bytes.length > maxImportFileSizeMegabytes * 1024 * 1024) {
      throw FormatException('文件不能超过 $maxImportFileSizeMegabytes MB。');
    }
    return parseContacts(bytes);
  }

  static ContactImportResult parseContacts(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      throw FormatException('工作簿中没有可读取的工作表。');
    }
    final schema = _readSchema(workbook, 'contacts');
    final sheet = schema == null
        ? workbook.tables['联系人'] ??
              workbook.tables.values.firstWhere(
                (sheet) => sheet.sheetName != _schemaSheetName,
              )
        : workbook.tables[schema.dataSheetName] ??
              workbook.tables.values.firstWhere(
                (sheet) => sheet.sheetName != _schemaSheetName,
              );
    if (sheet.rows.isEmpty) throw FormatException('工作表为空。');
    if (sheet.maxRows > maxImportDataRows + 1) {
      throw FormatException('最多导入 $maxImportDataRows 行联系人。');
    }

    final aliases = <String, String>{};
    for (final entry in contactHeaders.entries) {
      aliases[_normalize(entry.key)] = entry.key;
      aliases[_normalize(entry.value)] = entry.key;
      for (final locale in _exportLocales) {
        aliases[_normalize(_text(locale, entry.value))] = entry.key;
      }
    }
    aliases['联系人姓名'] = 'name';
    aliases['手机'] = 'phone';
    aliases['手机号'] = 'phone';
    final mapping = <int, String>{};
    if (schema != null) {
      for (var index = 0; index < schema.fieldKeys.length; index++) {
        final key = schema.fieldKeys[index];
        if (contactHeaders.containsKey(key)) mapping[index] = key;
      }
    } else {
      for (var index = 0; index < sheet.rows.first.length; index++) {
        final raw = sheet.rows.first[index]?.value?.toString() ?? '';
        final key = aliases[_normalize(raw)];
        if (key != null) mapping[index] = key;
      }
    }
    if (!mapping.containsValue('name')) {
      throw FormatException('第一行必须包含“姓名”列。');
    }

    final contacts = <ContactEntry>[];
    final warnings = <String>[];
    final ids = <String>{};
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
        warnings.add('第 ${rowIndex + 1} 行缺少姓名，已跳过。');
        continue;
      }
      final remark = values['remark'] ?? '';
      if (remark.characters.length > maxContactRemarkLength) {
        warnings.add(
          '第 ${rowIndex + 1} 行备注超过 $maxContactRemarkLength 个字符，已跳过。',
        );
        continue;
      }
      final now = DateTime.now();
      final id = (values['id'] ?? '').isEmpty
          ? 'xlsx-contact-${now.microsecondsSinceEpoch}-$rowIndex'
          : values['id']!;
      if (!ids.add(id)) {
        warnings.add('第 ${rowIndex + 1} 行联系人 ID 重复，已跳过。');
        continue;
      }
      contacts.add(
        ContactEntry(
          id: id,
          name: name,
          phone: values['phone'] ?? '',
          remark: remark,
        ),
      );
    }
    return ContactImportResult(contacts: contacts, warnings: warnings);
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
    final schema = _readSchema(workbook, 'plans');
    final sheet = schema == null
        ? workbook.tables['计划'] ??
              workbook.tables.values.firstWhere(
                (sheet) => sheet.sheetName != _schemaSheetName,
              )
        : workbook.tables[schema.dataSheetName] ??
              workbook.tables.values.firstWhere(
                (sheet) => sheet.sheetName != _schemaSheetName,
              );
    if (sheet.rows.isEmpty) throw FormatException('工作表为空。');
    if (sheet.maxRows > maxImportDataRows + 1) {
      throw FormatException('最多导入 $maxImportDataRows 行计划。');
    }

    final aliases = <String, String>{};
    for (final entry in headers.entries) {
      aliases[_normalize(entry.key)] = entry.key;
      aliases[_normalize(entry.value)] = entry.key;
      for (final locale in _exportLocales) {
        aliases[_normalize(_text(locale, entry.value))] = entry.key;
      }
    }
    aliases.addAll({
      '标题': 'name',
      '计划标题': 'name',
      '描述': 'description',
      '标签': 'tags',
      '日期': 'startDate',
    });
    final mapping = <int, String>{};
    if (schema != null) {
      for (var index = 0; index < schema.fieldKeys.length; index++) {
        final key = schema.fieldKeys[index];
        if (headers.containsKey(key)) mapping[index] = key;
      }
    } else {
      for (var index = 0; index < sheet.rows.first.length; index++) {
        final raw = sheet.rows.first[index]?.value?.toString() ?? '';
        final key = aliases[_normalize(raw)];
        if (key != null) mapping[index] = key;
      }
    }
    if (!mapping.containsValue('name')) {
      throw FormatException('第一行必须包含“计划名称”列。');
    }

    final categoryByName = <String, CategoryDefinition>{};
    final categoryById = <String, CategoryDefinition>{};
    for (final category in categories) {
      categoryById[category.id] = category;
      categoryByName[category.name] = category;
      for (final locale in _exportLocales) {
        categoryByName[categoryDefinitionName(category, locale)] = category;
      }
    }
    final templateByName = <String, ProgressTemplate>{};
    final templateById = <String, ProgressTemplate>{};
    for (final template in progressTemplates) {
      templateById[template.id] = template;
      templateByName[template.name] = template;
      for (final locale in _exportLocales) {
        templateByName[progressTemplateName(template, locale)] = template;
      }
    }
    final tagByName = <String, TaskTagDefinition>{};
    final tagById = <String, TaskTagDefinition>{};
    for (final tag in tags) {
      tagById[tag.id] = tag;
      tagByName[tag.name] = tag;
      for (final locale in _exportLocales) {
        tagByName[tagDefinitionName(tag, locale)] = tag;
      }
    }
    final contactById = {for (final contact in contacts) contact.id: contact};
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
      final category = categoryById[values['categoryId']] ??
          categoryByName[categoryName];
      if (categoryName.isNotEmpty && category == null) {
        warnings.add('第 ${rowIndex + 1} 行分类不存在，已保留名称作为历史分类。');
      }

      final requestedTemplate = values['progressTemplate'] ?? '';
      final template = templateById[values['progressTemplateId']] ??
          templateByName[requestedTemplate] ??
          defaultTemplate;
      if (requestedTemplate.isNotEmpty &&
          templateById[values['progressTemplateId']] == null &&
          templateByName[requestedTemplate] == null) {
        warnings.add('第 ${rowIndex + 1} 行进度方案不存在，已使用“${template.name}”。');
      }
      final requestedNode = values['progressNode'] ?? '';
      final nodeByName = <String, ProgressNode>{};
      for (final item in template.nodes) {
        nodeByName[item.name] = item;
        for (final locale in _exportLocales) {
          nodeByName[progressNodeName(item, locale)] = item;
        }
      }
      final requestedNodeId = values['progressNodeId'] ?? '';
      final node = template.nodes.firstWhere(
        (item) => item.id == requestedNodeId,
        orElse: () => nodeByName[requestedNode] ?? template.nodes.first,
      );
      if (requestedNode.isNotEmpty &&
          requestedNodeId.isEmpty &&
          nodeByName[requestedNode] == null) {
        warnings.add('第 ${rowIndex + 1} 行进度节点不属于所选方案，已使用“${node.name}”。');
      }

      final importedTagNames = <String>{};
      final importedTagDefinitions = <String, TaskTagDefinition>{};
      for (final tagId in _splitComma(values['tagIds'] ?? '')) {
        final definition = tagById[tagId];
        if (definition != null) {
          importedTagDefinitions[definition.id] = definition;
        }
      }
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
      for (final definition in importedTagDefinitions.values) {
        snapshots.add(
          TaskTagSnapshot(
            sourceTagId: definition.id,
            name: definition.name,
            colorValue: definition.colorValue,
            iconName: definition.iconName,
          ),
        );
      }
      for (final tagName in importedTagNames) {
        final definition = tagByName[tagName];
        if (definition != null &&
            importedTagDefinitions.containsKey(definition.id)) {
          continue;
        }
        if (definition == null) {
          warnings.add('第 ${rowIndex + 1} 行标签“$tagName”不存在，已作为历史标签保留。');
        }
        snapshots.add(
          TaskTagSnapshot(
            sourceTagId: definition?.id,
            name: definition?.name ?? tagName,
            colorValue: definition?.colorValue ?? 0xff8e8e93,
            iconName: definition?.iconName ?? 'label',
          ),
        );
      }

      final importedContacts = <ContactEntry>[];
      final contactIds = _splitComma(values['contactIds'] ?? '');
      if (contactIds.isNotEmpty) {
        for (final contactId in contactIds) {
          final contact = contactById[contactId];
          if (contact == null) {
            warnings.add('第 ${rowIndex + 1} 行联系人 ID“$contactId”不存在，已忽略。');
          } else {
            importedContacts.add(contact);
          }
        }
      } else {
        for (final contactName in _splitComma(values['contacts'] ?? '')) {
          final matches = contacts
              .where((contact) => contact.name == contactName)
              .toList();
          if (matches.length == 1) {
            importedContacts.add(matches.single);
          } else if (matches.isEmpty) {
            warnings.add('第 ${rowIndex + 1} 行联系人“$contactName”不存在，已忽略。');
          } else {
            warnings.add(
              '第 ${rowIndex + 1} 行联系人“$contactName”存在同名记录，请填写联系人ID。',
            );
          }
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
              sourceNodeId: item.sourceNodeId ?? item.id,
              nameSource: item.nameSource,
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
          categoryName: category?.name ?? categoryName,
          sourceCategoryId: category?.id,
          categoryColorValue: category?.colorValue ?? 0xff8e8e93,
          categoryIconName: category?.iconName ?? 'project',
          tags: snapshots,
          progress: ProgressSnapshot(
            instanceId: progressInstanceId,
            sourceTemplateId: template.id,
            templateName: template.name,
            templateNameSource: template.nameSource,
            currentNodeId: currentNode.id,
            nodes: progressNodes,
          ),
          milestones: _parseMilestones(
            values['milestones'] ?? '',
            id,
            rowIndex + 1,
            warnings,
          ),
          rules: _parseRecurrenceRules(
            values['recurrenceRules'] ?? '',
            id,
            rowIndex + 1,
            warnings,
            templateByName,
            defaultTemplate,
          ),
          completedAt: DateTime.tryParse(values['completedAt'] ?? ''),
          updatedAt: DateTime.tryParse(values['updatedAt'] ?? '') ?? now,
          calendarDisplayMode:
              _parseCalendarDisplayMode(values['calendarDisplayMode'] ?? '') ??
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
    if (normalized == 'true' || normalized == '1') return true;
    return _exportLocales.any(
      (locale) => normalized == _text(locale, '是').trim().toLowerCase(),
    );
  }

  static PlanCalendarDisplayMode? _parseCalendarDisplayMode(String value) {
    final normalized = value.trim().toLowerCase();
    for (final entry in _calendarModes.entries) {
      if (normalized == entry.key.toLowerCase()) return entry.value;
      for (final locale in _exportLocales) {
        if (normalized == _text(locale, entry.key).trim().toLowerCase()) {
          return entry.value;
        }
      }
    }
    return null;
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

  static List<PlanMilestone> _parseMilestones(
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
        final map = Map<String, dynamic>.from(entry.$2 as Map);
        final name = (map['name'] as String? ?? '').trim();
        final date = _normalizeDate(map['date'] as String? ?? '');
        if (name.isEmpty || date == null) throw const FormatException();
        return PlanMilestone(
          id: (map['id'] as String?)?.trim().isNotEmpty == true
              ? map['id'] as String
              : 'milestone-$planId-${entry.$1}',
          name: name,
          date: date,
          description: map['description'] as String? ?? '',
          completed: map['completed'] == true,
          sortOrder: entry.$1,
        );
      }).toList();
    } catch (_) {
      warnings.add('第 $rowNumber 行里程碑格式无效，已忽略。');
      return const [];
    }
  }

  static List<RecurrenceRule> _parseRecurrenceRules(
    String raw,
    String planId,
    int rowNumber,
    List<String> warnings,
    Map<String, ProgressTemplate> templateByName,
    ProgressTemplate defaultTemplate,
  ) {
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException();
      return decoded.indexed.map((entry) {
        final map = Map<String, dynamic>.from(entry.$2 as Map);
        final title = (map['title'] as String? ?? '').trim();
        final start = _normalizeDate(map['startDate'] as String? ?? '');
        final end = _normalizeDate(map['endDate'] as String? ?? '');
        if (title.isEmpty ||
            start == null ||
            end == null ||
            start.compareTo(end) > 0) {
          throw const FormatException();
        }
        final template =
            templateByName[map['progressTemplate'] as String? ?? ''] ??
            defaultTemplate;
        final requestedNode = map['progressNode'] as String? ?? '';
        final instanceId = 'rule-progress-$planId-${entry.$1}';
        final nodes = template.nodes
            .map(
              (node) => ProgressNode(
                id: '$instanceId-${node.id}',
                name: node.name,
                sourceNodeId: node.sourceNodeId ?? node.id,
                nameSource: node.nameSource,
                colorValue: node.colorValue,
                kind: node.kind,
                sortOrder: node.sortOrder,
              ),
            )
            .toList();
        final requestedDefinitionNode = template.nodes.firstWhere(
          (node) =>
              node.name == requestedNode ||
              _exportLocales.any(
                (locale) => progressNodeName(node, locale) == requestedNode,
              ),
          orElse: () => template.nodes.first,
        );
        final current = nodes.firstWhere(
          (node) => node.sourceNodeId == requestedDefinitionNode.id,
          orElse: () => nodes.first,
        );
        final rawDays = map['weekdays'];
        final weekdays = rawDays is List
            ? rawDays.whereType<num>().map((value) => value.toInt()).toSet()
            : <int>{};
        return RecurrenceRule(
          id: (map['id'] as String?)?.trim().isNotEmpty == true
              ? map['id'] as String
              : 'recurrence-$planId-${entry.$1}',
          planId: planId,
          title: title,
          description: map['description'] as String? ?? '',
          startDate: start,
          endDate: end,
          startTime: map['startTime'] as String? ?? '',
          weekdays: weekdays,
          enabled: map['enabled'] != false,
          progress: ProgressSnapshot(
            instanceId: instanceId,
            sourceTemplateId: template.id,
            templateName: template.name,
            templateNameSource: template.nameSource,
            currentNodeId: current.id,
            nodes: nodes,
          ),
        );
      }).toList();
    } catch (_) {
      warnings.add('第 $rowNumber 行周期任务格式无效，已忽略。');
      return const [];
    }
  }

  static Uint8List _addWorkbookValidation(
    Uint8List bytes, {
    required List<CategoryDefinition> categories,
    required List<ProgressTemplate> progressTemplates,
    required List<TaskTagDefinition> tags,
    required String planSheetName,
    required String guideSheetName,
    required Locale locale,
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
    final planSheetPath = _worksheetPath(
      workbookXml,
      relationsXml,
      planSheetName,
    );
    if (planSheetPath == null) return bytes;
    final planSheetFile = archive.findFile(planSheetPath);
    if (planSheetFile == null) return bytes;

    const guideStartRow = 9;
    final quadrantCount = tags.where((tag) => tag.isQuadrant).length;
    final names = <String>[
      _definedName(
        'ClPlanCategories',
        'A',
        categories.length,
        guideStartRow,
        guideSheetName,
      ),
      _definedName(
        'ClPlanProgressTemplates',
        'B',
        progressTemplates.length,
        guideStartRow,
        guideSheetName,
      ),
      _definedName(
        'ClPlanQuadrants',
        'C',
        quadrantCount,
        guideStartRow,
        guideSheetName,
      ),
      _definedName(
        'ClPlanCalendarModes',
        'F',
        _calendarModes.length,
        guideStartRow,
        guideSheetName,
      ),
      _definedName(
        'ClPlanBooleans',
        'G',
        2,
        guideStartRow,
        guideSheetName,
      ),
      for (var index = 0; index < progressTemplates.length; index++)
        _definedName(
          'ClPlanProgressNodes_${index + 1}',
          _columnName(7 + index),
          progressTemplates[index].nodes.length,
          guideStartRow,
          guideSheetName,
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
    final cellXfsMatch = RegExp(r'<cellXfs count="(\d+)">')
        .firstMatch(stylesXml);
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
      if (minColumn <= 17 && maxColumn >= 17) {
        columnXml = _withXmlAttribute(columnXml, 'hidden', '1');
      }
      final containsContactIds = minColumn <= 17 && maxColumn >= 17;
      final containsStableIds = minColumn <= 23 && maxColumn >= 20;
      if (containsStableIds) {
        columnXml = _withXmlAttribute(columnXml, 'hidden', '1');
      }
      if (minColumn >= 2 && !containsContactIds && !containsStableIds) {
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
    sheetXml = sheetXml.replaceFirst('</sheetData>', '</sheetData>$protection');
    String message(String source) => _xmlAttribute(_text(locale, source));
    final validations = '''<dataValidations count="6">
<dataValidation type="list" allowBlank="1" showInputMessage="1" showErrorMessage="1" errorStyle="stop" promptTitle="${message('选择分类')}" prompt="${message('请选择 App 内已有分类，也可留空。')}" errorTitle="${message('分类无效')}" error="${message('请从下拉列表选择分类。')}" sqref="D2:D10001"><formula1>ClPlanCategories</formula1></dataValidation>
<dataValidation type="list" allowBlank="0" showInputMessage="1" showErrorMessage="1" errorStyle="stop" promptTitle="${message('选择进度方案')}" prompt="${message('选择方案后，进度节点下拉会显示对应节点。')}" errorTitle="${message('进度方案无效')}" error="${message('请从下拉列表选择进度方案。')}" sqref="E2:E10001"><formula1>ClPlanProgressTemplates</formula1></dataValidation>
<dataValidation type="list" allowBlank="0" showInputMessage="1" showErrorMessage="1" errorStyle="stop" promptTitle="${message('选择进度节点')}" prompt="${message('节点选项随本行进度方案变化。')}" errorTitle="${message('进度节点无效')}" error="${message('请选择当前进度方案中的节点。')}" sqref="F2:F10001"><formula1>INDIRECT("ClPlanProgressNodes_"&amp;MATCH(\$E2,ClPlanProgressTemplates,0))</formula1></dataValidation>
<dataValidation type="list" allowBlank="1" showInputMessage="1" showErrorMessage="1" errorStyle="stop" promptTitle="${message('选择四象限')}" prompt="${message('四象限标签为单选，也可以留空。')}" errorTitle="${message('四象限标签无效')}" error="${message('请从下拉列表选择四象限标签。')}" sqref="G2:G10001"><formula1>ClPlanQuadrants</formula1></dataValidation>
<dataValidation type="list" allowBlank="0" showErrorMessage="1" errorStyle="stop" errorTitle="${message('日历显示无效')}" error="${message('请从下拉列表选择日历显示方式。')}" sqref="L2:L10001"><formula1>ClPlanCalendarModes</formula1></dataValidation>
<dataValidation type="list" allowBlank="0" showErrorMessage="1" errorStyle="stop" errorTitle="${message('提醒选项无效')}" error="${message('请选择“是”或“否”。')}" sqref="M2:M10001"><formula1>ClPlanBooleans</formula1></dataValidation>
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

  static Uint8List _protectPrimaryKeyColumn(
    Uint8List bytes, {
    required String sheetName,
  }) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final workbookFile = archive.findFile('xl/workbook.xml');
    final relationsFile = archive.findFile('xl/_rels/workbook.xml.rels');
    final stylesFile = archive.findFile('xl/styles.xml');
    if (workbookFile == null || relationsFile == null || stylesFile == null) {
      return bytes;
    }

    final workbookXml = utf8.decode(workbookFile.content as List<int>);
    final relationsXml = utf8.decode(relationsFile.content as List<int>);
    final sheetPath = _worksheetPath(workbookXml, relationsXml, sheetName);
    if (sheetPath == null) return bytes;
    final sheetFile = archive.findFile(sheetPath);
    if (sheetFile == null) return bytes;

    var stylesXml = utf8.decode(stylesFile.content as List<int>);
    final cellXfsMatch = RegExp(r'<cellXfs count="(\d+)">')
        .firstMatch(stylesXml);
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

    var sheetXml = utf8.decode(sheetFile.content as List<int>);
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
    sheetXml = sheetXml.replaceFirst('</sheetData>', '</sheetData>$protection');
    final sheetData = utf8.encode(sheetXml);
    archive.addFile(ArchiveFile(sheetFile.name, sheetData.length, sheetData));
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static Uint8List _hideSchemaSheet(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final workbookFile = archive.findFile('xl/workbook.xml');
    if (workbookFile == null) return bytes;
    var workbookXml = utf8.decode(workbookFile.content as List<int>);
    final schemaSheet = RegExp(
      '<sheet\\b([^>]*\\bname="$_schemaSheetName"[^>]*)/>',
    );
    workbookXml = workbookXml.replaceFirstMapped(schemaSheet, (match) {
      var attributes = match.group(1)!;
      if (RegExp(r'\bstate="[^"]*"').hasMatch(attributes)) {
        attributes = attributes.replaceFirst(
          RegExp(r'\bstate="[^"]*"'),
          'state="veryHidden"',
        );
      } else {
        attributes = '$attributes state="veryHidden"';
      }
      return '<sheet$attributes/>';
    });
    final workbookData = utf8.encode(workbookXml);
    archive.addFile(
      ArchiveFile(workbookFile.name, workbookData.length, workbookData),
    );
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static String _definedName(
    String name,
    String column,
    int count,
    int startRow,
    String guideSheetName,
  ) {
    final endRow = startRow + (count <= 0 ? 0 : count - 1);
    final escapedSheetName = guideSheetName.replaceAll("'", "''");
    return '<definedName name="$name">\'$escapedSheetName\'!\$$column\$$startRow:\$$column\$$endRow</definedName>';
  }

  static String _xmlAttribute(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

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
