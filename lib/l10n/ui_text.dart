import 'package:flutter/material.dart' as material;

/// Localizes legacy interface strings while the feature-specific ARB catalog is
/// retained for messages that need placeholders or translator metadata.
String localizeUiText(material.BuildContext context, String source) {
  return localizeUiTextForLocale(
    material.Localizations.localeOf(context),
    source,
  );
}

String localizeUiTextWithArguments(
  material.BuildContext context,
  String source,
  List<String> arguments,
) {
  var result = localizeUiText(context, source);
  for (var index = 0; index < arguments.length; index++) {
    result = result.replaceAll('{$index}', arguments[index]);
  }
  return result;
}

String localizeUiTextForLocale(material.Locale locale, String source) {
  if (_hasExactTranslation(locale, source)) {
    return _localizeUiTextForLocale(locale, source);
  }
  final protected = <String>[];
  final safeSource = source.replaceAllMapped(RegExp(r'“([^”]*)”'), (match) {
    final value = match.group(1)!;
    if (RegExp(r'^\{\d+\}$').hasMatch(value)) return match.group(0)!;
    final index = protected.length;
    protected.add(value);
    return '“\uE000$index\uE001”';
  });
  var result = _localizeUiTextForLocale(locale, safeSource);
  for (var index = 0; index < protected.length; index++) {
    result = result.replaceAll('\uE000$index\uE001', protected[index]);
  }
  return result;
}

bool _hasExactTranslation(material.Locale locale, String source) {
  final language = locale.languageCode;
  if (language == 'zh') {
    return locale.scriptCode != 'Hant' || _traditionalChinese.containsKey(source);
  }
  return switch (language) {
    'ja' => _japanese.containsKey(source) || _english.containsKey(source),
    'ko' => _korean.containsKey(source) || _english.containsKey(source),
    _ => _english.containsKey(source),
  };
}

String _localizeUiTextForLocale(material.Locale locale, String source) {
  final language = locale.languageCode;
  final traditionalChinese = language == 'zh' && locale.scriptCode == 'Hant';
  if (language == 'zh' && !traditionalChinese) return source;
  if (traditionalChinese) {
    return _traditionalChinese[source] ?? _toTraditional(source);
  }

  final translations = switch (language) {
    'ja' => _japanese,
    'ko' => _korean,
    _ => _english,
  };
  final exact = translations[source] ?? _english[source];
  if (exact != null) return exact;

  final countMatch = RegExp(r'^(计划|任务|联系人)[：:]\s*(\d+)$').firstMatch(source);
  if (countMatch != null) {
    final noun =
        translations[countMatch.group(1)] ?? _english[countMatch.group(1)];
    return language == 'ja'
        ? '$noun：${countMatch.group(2)}'
        : language == 'ko'
        ? '$noun: ${countMatch.group(2)}개'
        : '$noun: ${countMatch.group(2)}';
  }
  final completedMatch = RegExp(r'^(\d+)/(\d+) 已完成$').firstMatch(source);
  if (completedMatch != null) {
    return language == 'ja'
        ? '${completedMatch.group(1)}/${completedMatch.group(2)} 完了'
        : language == 'ko'
        ? '${completedMatch.group(1)}/${completedMatch.group(2)} 완료'
        : '${completedMatch.group(1)}/${completedMatch.group(2)} completed';
  }
  final itemCountMatch = RegExp(r'^(\d+) 条$').firstMatch(source);
  if (itemCountMatch != null) {
    return language == 'ja'
        ? '${itemCountMatch.group(1)} 件'
        : language == 'ko'
        ? '${itemCountMatch.group(1)}개'
        : '${itemCountMatch.group(1)} entries';
  }
  final enabledCountMatch = RegExp(r'^(\d+) 条已启用$').firstMatch(source);
  if (enabledCountMatch != null) {
    return language == 'ja'
        ? '${enabledCountMatch.group(1)} 件有効'
        : language == 'ko'
        ? '${enabledCountMatch.group(1)}개 활성화'
        : '${enabledCountMatch.group(1)} enabled';
  }
  final peopleMatch = RegExp(r'^(\d+) 人$').firstMatch(source);
  if (peopleMatch != null) {
    return language == 'ja'
        ? '${peopleMatch.group(1)} 人'
        : language == 'ko'
        ? '${peopleMatch.group(1)}명'
        : '${peopleMatch.group(1)} contacts';
  }
  final genericCountMatch = RegExp(r'^(\d+) 个(计划|联系人|提醒|分类|标签|节点|普通标签|四象限)$')
      .firstMatch(source);
  if (genericCountMatch != null) {
    final noun =
        translations[genericCountMatch.group(2)] ??
        _english[genericCountMatch.group(2)] ??
        genericCountMatch.group(2)!;
    return language == 'ja'
        ? '${genericCountMatch.group(1)} $noun'
        : language == 'ko'
        ? '$noun ${genericCountMatch.group(1)}개'
        : '${genericCountMatch.group(1)} $noun';
  }
  final taskCountMatch = RegExp(r'^(\d+) 项任务$').firstMatch(source);
  if (taskCountMatch != null) {
    return language == 'ja'
        ? '${taskCountMatch.group(1)} 件のタスク'
        : language == 'ko'
        ? '작업 ${taskCountMatch.group(1)}개'
        : '${taskCountMatch.group(1)} tasks';
  }
  final hiddenTagsMatch = RegExp(r'^还有 (\d+) 个标签$').firstMatch(source);
  if (hiddenTagsMatch != null) {
    return language == 'ja'
        ? 'ほか ${hiddenTagsMatch.group(1)} 件のタグ'
        : language == 'ko'
        ? '태그 ${hiddenTagsMatch.group(1)}개 더 있음'
        : '${hiddenTagsMatch.group(1)} more tags';
  }
  final countdownMatch = RegExp(r'^(\d+) 秒后自动进入$').firstMatch(source);
  if (countdownMatch != null) {
    return language == 'ja'
        ? '${countdownMatch.group(1)} 秒後に自動で開始'
        : language == 'ko'
        ? '${countdownMatch.group(1)}초 후 자동으로 시작'
        : 'Entering automatically in ${countdownMatch.group(1)} seconds';
  }
  final yearMatch = RegExp(r'^(\d+) 年$').firstMatch(source);
  if (yearMatch != null) return yearMatch.group(1)!;
  final monthMatch = RegExp(r'^(\d+) 月$').firstMatch(source);
  if (monthMatch != null) {
    return _localizedMonth(language, int.parse(monthMatch.group(1)!));
  }
  final compactMonthMatch = RegExp(r'^(\d+)月$').firstMatch(source);
  if (compactMonthMatch != null) {
    return _localizedMonth(language, int.parse(compactMonthMatch.group(1)!));
  }
  final dateMatch = RegExp(r'^(\d+)月(\d+)日$').firstMatch(source);
  if (dateMatch != null) {
    return _localizedDate(
      language,
      int.parse(dateMatch.group(1)!),
      dateMatch.group(2)!,
    );
  }
  final rangeMatch = RegExp(r'^(\d+)月(\d+)日 — (\d+)月(\d+)日$')
      .firstMatch(source);
  if (rangeMatch != null) {
    return '${_localizedDate(language, int.parse(rangeMatch.group(1)!), rangeMatch.group(2)!)} — '
        '${_localizedDate(language, int.parse(rangeMatch.group(3)!), rangeMatch.group(4)!)}';
  }
  final completedAtMatch = RegExp(r'^完成于 (.+)$').firstMatch(source);
  if (completedAtMatch != null) {
    return language == 'ja'
        ? '${completedAtMatch.group(1)} に完了'
        : language == 'ko'
        ? '${completedAtMatch.group(1)} 완료'
        : 'Completed ${completedAtMatch.group(1)}';
  }
  final scheduleDateMatch = RegExp(r'^安排日期 (.+)$').firstMatch(source);
  if (scheduleDateMatch != null) {
    return language == 'ja'
        ? '予定日：${scheduleDateMatch.group(1)}'
        : language == 'ko'
        ? '예정 날짜: ${scheduleDateMatch.group(1)}'
        : 'Schedule date: ${scheduleDateMatch.group(1)}';
  }
  final scheduleTimeMatch = RegExp(r'^安排时间 (.+)$').firstMatch(source);
  if (scheduleTimeMatch != null) {
    return language == 'ja'
        ? '予定時刻：${scheduleTimeMatch.group(1)}'
        : language == 'ko'
        ? '예정 시간: ${scheduleTimeMatch.group(1)}'
        : 'Schedule time: ${scheduleTimeMatch.group(1)}';
  }
  final reminderMatch = RegExp(r'^提前 (\d+) (分钟|小时|天)(.*)$').firstMatch(source);
  if (reminderMatch != null) {
    final unit = switch ((language, reminderMatch.group(2))) {
      ('ja', '分钟') => '分前',
      ('ja', '小时') => '時間前',
      ('ja', _) => '日前',
      ('ko', '分钟') => '분 전',
      ('ko', '小时') => '시간 전',
      ('ko', _) => '일 전',
      (_, '分钟') => 'minutes before',
      (_, '小时') => 'hours before',
      (_, _) => 'days before',
    };
    var suffix = reminderMatch.group(3) ?? '';
    suffix = suffix.replaceAll(
      '通知',
      language == 'ja'
          ? '通知'
          : language == 'ko'
          ? '알림'
          : 'Notification',
    );
    suffix = suffix.replaceAll(
      '闹铃',
      language == 'ja'
          ? 'アラーム'
          : language == 'ko'
          ? '알람'
          : 'Alarm',
    );
    return language == 'en'
        ? '${reminderMatch.group(1)} $unit$suffix'
        : '${reminderMatch.group(1)}$unit$suffix';
  }
  final tagMatch = RegExp(r'^标签 (.+)$').firstMatch(source);
  if (tagMatch != null) {
    return '${translations['标签'] ?? _english['标签']} ${tagMatch.group(1)}';
  }
  final warningMatch = RegExp(r'^(阻断|提示)：(.+)$').firstMatch(source);
  if (warningMatch != null) {
    final prefix = warningMatch.group(1) == '阻断'
        ? (language == 'ja'
              ? '要対応'
              : language == 'ko'
              ? '차단'
              : 'Blocking')
        : (language == 'ja'
              ? '案内'
              : language == 'ko'
              ? '안내'
              : 'Notice');
    return '$prefix: ${localizeUiTextForLocale(locale, warningMatch.group(2)!)}';
  }
  if (language == 'ja') return _replaceTerms(source, _japaneseTerms);
  if (language == 'ko') return _replaceTerms(source, _koreanTerms);
  return source;
}

String _replaceTerms(String source, Map<String, String> terms) {
  var result = source;
  for (final entry in terms.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}

String _localizedMonth(String language, int month) => switch (language) {
  'ja' => '$month月',
  'ko' => '$month월',
  _ => _monthName(month),
};

String _localizedDate(String language, int month, String day) =>
    switch (language) {
      'ja' => '$month月$day日',
      'ko' => '$month월 $day일',
      _ => '${_monthName(month)} $day',
    };

String _monthName(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

const Map<String, String> _english = {
  '给个好评': 'Rate the app',
  '前往 App Store 评价 ClPlan': 'Review ClPlan on the App Store',
  '暂时无法打开评价页面，请稍后重试': 'Unable to open the review page. Please try again later.',
  '计划': 'Plans',
  '任务': 'Tasks',
  '日历': 'Calendar',
  '统计': 'Statistics',
  '设置': 'Settings',
  '主题': 'Theme',
  '语言': 'Language',
  '字体大小': 'Text size',
  '跟随系统': 'Follow system',
  '浅色': 'Light',
  '深色': 'Dark',
  '简体中文': 'Simplified Chinese',
  '确定删除“{0}”吗？': 'Delete “{0}”?',
  '确定删除“{0}”吗？存在任务的计划需要先清空任务。':
      'Delete “{0}”? Remove its tasks first if it contains any.',
  '删除“{0}”联系人？': 'Delete contact “{0}”?',
  '删除“{0}”标签配置？': 'Delete tag configuration “{0}”?',
  '显示与通知': 'Display & notifications',
  '计划完成样式': 'Completed plan style',
  '月视图、周视图与四象限独立设置': 'Set month, week, and quadrant views independently',
  '通知与闹铃': 'Notifications & alarms',
  '计划配置': 'Plan configuration',
  '分类': 'Categories',
  '进度': 'Progress',
  '标签': 'Tags',
  '联系人': 'Contacts',
  '数据与安全': 'Data & security',
  '安全锁': 'Security lock',
  'App 启动验证': 'Authenticate at app launch',
  '导出验证': 'Export authentication',
  '下次启动并显示欢迎页时验证':
      'Authenticate next time the app launches and shows the welcome screen',
  '验证后 30 分钟内无需重复验证':
      'No additional authentication for 30 minutes',
  '启动验证开启': 'Launch authentication on',
  '启动验证关闭': 'Launch authentication off',
  '导出验证开启': 'Export authentication on',
  '导出验证关闭': 'Export authentication off',
  '验证中…': 'Authenticating…',
  '验证并进入': 'Authenticate and enter',
  '验证设备所有者以进入 ClPlan':
      'Authenticate as the device owner to enter ClPlan',
  '验证设备所有者以导出 ClPlan 数据':
      'Authenticate as the device owner to export ClPlan data',
  '验证设备所有者以修改安全锁设置':
      'Authenticate as the device owner to change security lock settings',
  '无法验证身份': 'Unable to authenticate',
  '请先在系统设置中设置设备密码或生物识别。':
      'Set up a device passcode or biometrics in system settings first.',
  '系统认证已暂时锁定，请稍后重试或使用设备密码。':
      'System authentication is temporarily locked. Try again later or use the device passcode.',
  '系统无法完成身份验证，请重试。':
      'System authentication could not be completed. Try again.',
  '安全锁设置保存失败，请重试。':
      'The security lock settings could not be saved. Try again.',
  '表格与数据': 'Tables & data',
  '查看、导入、导出与列设置': 'View, import, export, and configure columns',
  '隐私与本地存储': 'Privacy & local storage',
  '数据边界与本地存储说明': 'Data boundaries and local storage details',
  '支持与关于': 'Support & about',
  '关于 ClPlan': 'About ClPlan',
  '应用信息与赞赏': 'App information and support',
  '基本信息': 'Basic information',
  '时间与日历': 'Time & calendar',
  '分类与进度': 'Category & progress',
  '执行补充': 'Execution details',
  '计划名称': 'Plan name',
  '计划 ID': 'Plan ID',
  '计划内容': 'Plan details',
  '任务名称': 'Task name',
  '任务内容': 'Task details',
  '标题': 'Title',
  '内容': 'Details',
  '日期': 'Date',
  '开始日期': 'Start date',
  '结束日期': 'End date',
  '目标日期': 'Target date',
  '时间': 'Time',
  '日历显示': 'Calendar display',
  '整个期间': 'Entire period',
  '仅起止日': 'Start and end dates only',
  '仅开始日': 'Start date only',
  '仅目标日': 'Target date only',
  '启用提醒': 'Reminders enabled',
  '完成时间': 'Completed at',
  '修改时间': 'Updated at',
  '是': 'Yes',
  '否': 'No',
  '里程碑': 'Milestones',
  '周期任务': 'Recurring tasks',
  '重复日期': 'Repeat on',
  '名称': 'Name',
  '说明': 'Description',
  '保存': 'Save',
  '取消': 'Cancel',
  '删除': 'Delete',
  '编辑': 'Edit',
  '关闭': 'Close',
  '新增': 'Add',
  '清空': 'Clear',
  '全选': 'Select all',
  '未设置': 'Not set',
  '未命名': 'Untitled',
  '保存并建下一项': 'Save & create another',
  '清除日期和时间': 'Clear date and time',
  '四象限 · 单选': 'Quadrant · single selection',
  '跟进记录': 'Follow-ups',
  '变更历史': 'Change history',
  '追加跟进': 'Add follow-up',
  '未完成主要原因': 'Main reason not completed',
  '通知提醒': 'Notification',
  '闹铃提醒': 'Alarm',
  '去设置': 'Open settings',
  '等待关联时间': 'Waiting for a scheduled time',
  '查询日期': 'Filter date',
  '年度': 'Year',
  '月份': 'Month',
  '全部分类': 'All categories',
  '全部进度方案': 'All progress templates',
  '该方案全部节点': 'All nodes in this template',
  '进度方案': 'Progress template',
  '进度节点': 'Progress node',
  '暂无标签': 'No tags',
  '未完成': 'Incomplete',
  '已完成': 'Completed',
  '未开始': 'Not started',
  '进行中': 'In progress',
  '默认进度': 'Default progress',
  '工作': 'Work',
  '生活': 'Personal',
  '学习': 'Study',
  '重要且紧急': 'Important & urgent',
  '重要不紧急': 'Important, not urgent',
  '不重要但紧急': 'Not important, urgent',
  '不重要不紧急': 'Not important or urgent',
  '全部状态': 'All statuses',
  '四象限': 'Quadrants',
  '月': 'Month',
  '周': 'Week',
  '周一': 'Mon',
  '周二': 'Tue',
  '周三': 'Wed',
  '周四': 'Thu',
  '周五': 'Fri',
  '周六': 'Sat',
  '周日': 'Sun',
  '一': 'Mon',
  '二': 'Tue',
  '三': 'Wed',
  '四': 'Thu',
  '五': 'Fri',
  '六': 'Sat',
  '日': 'Sun',
  '未完成 · 当前状态': 'Incomplete · current status',
  '未完成 · 主要原因': 'Incomplete · main reason',
  '计划完成概览': 'Plan completion overview',
  '计划完成趋势': 'Plan completion trend',
  '当前进度分布': 'Current progress distribution',
  '计划与本周期的关系': 'Plans in this period',
  '分类分布': 'Category distribution',
  '其他标签统计': 'Other tag statistics',
  '统计周期': 'Statistics period',
  '这段时间没有未完成任务。': 'There are no incomplete tasks in this period.',
  '当前没有自定义标签，可先前往设置添加标签。':
      'There are no custom tags. Add one in Settings first.',
  '这一天还没有计划': 'No plans for this day',
  '新增计划': 'Add plan',
  '新增任务': 'Add task',
  '新增子任务': 'Add subtask',
  '新增联系人': 'Add contact',
  '没有其他可选联系人': 'No other contacts available',
  '姓名': 'Name',
  '电话': 'Phone',
  '备注': 'Notes',
  '分类名称': 'Category name',
  '方案名称': 'Template name',
  '节点名称': 'Node name',
  '标签名称': 'Tag name',
  '计划关键词': 'Plan keywords',
  '搜索计划名称或内容': 'Search plan name or details',
  '完成状态': 'Completion status',
  '输入姓名、电话或备注': 'Enter a name, phone number, or notes',
  '查看与设置': 'View & configure',
  '查看计划表格': 'View plan table',
  '在 App 内快速核对当前计划数据': 'Review current plan data in the app',
  '计划表格列设置': 'Plan table columns',
  '调整计划表格的显示字段与顺序': 'Choose and reorder visible plan fields',
  '导入与导出': 'Import & export',
  '导出': 'Export',
  '导入': 'Import',
  '导出计划数据': 'Export plan data',
  '导入计划数据': 'Import plan data',
  '导出联系人数据': 'Export contact data',
  '导入联系人数据': 'Import contact data',
  '模板内容': 'Template contents',
  '本地数据与隐私': 'Local data & privacy',
  '关于应用': 'About the app',
  '离线优先的个人计划应用。联系人均为手动文本，不读取系统通讯录。': 'An offline-first personal planning app. Contacts are entered manually; the system address book is never read.',
  '系统通知权限': 'System notification permission',
  '系统闹铃权限': 'System alarm permission',
  '闹铃调度状态': 'Alarm scheduling status',
  '提醒声音': 'Reminder sound',
  '调度状态': 'Scheduling status',
  '暂无可选分类。': 'No categories available.',
  '暂无可选标签。': 'No tags available.',
  '暂无联系人，可在这里或计划、任务表单中新增。':
      'No contacts yet. Add one here or from a plan or task.',
  '预览': 'Preview',
  '恢复默认（跟随系统）': 'Restore default (follow system)',
  '无样式': 'No special style',
  '添加分类': 'Add category',
  '编辑分类': 'Edit category',
  '颜色': 'Color',
  '图标': 'Icon',
  '添加进度方案': 'Add progress template',
  '编辑进度方案': 'Edit progress template',
  '开始': 'Start',
  '中间': 'Middle',
  '结束': 'End',
  '添加中间节点': 'Add middle node',
  '保存方案': 'Save template',
  '添加标签': 'Add tag',
  '删除配置': 'Delete configuration',
  '更新联系人': 'Updated contacts',
  '按隐藏的联系人 ID 匹配': 'Matched by hidden contact ID',
  '全量导出': 'Export all',
  '按条件导出': 'Filtered export',
  '计划日期范围': 'Plan date range',
  '查询联系人': 'Search contacts',
  '查询结果': 'Results',
  '删除任务？': 'Delete task?',
  '删除计划？': 'Delete plan?',
  '删除任务': 'Delete task',
  '删除计划': 'Delete plan',
  '回到当前': 'Go to current date',
  '查询条件': 'Filters',
  '统计条件': 'Statistics filters',
  '切换周卡片/月份视图': 'Switch week cards / month view',
  '恢复默认条件': 'Reset filters',
  '选择或新增联系人': 'Select or add a contact',
  '编辑联系人配置': 'Edit contact',
  '取消选择': 'Deselect',
  '编辑联系人': 'Edit contact',
  '删除联系人': 'Delete contact',
  '更多操作': 'More actions',
  '编辑标签': 'Edit tags',
  '新增里程碑': 'Add milestone',
  '编辑里程碑': 'Edit milestone',
  '删除里程碑': 'Delete milestone',
  '新增周期任务': 'Add recurring task',
  '编辑周期任务': 'Edit recurring task',
  '清除时间': 'Clear time',
  '删除提醒': 'Delete reminder',
  '重新对账': 'Reconcile again',
  '删除分类': 'Delete category',
  '删除进度方案': 'Delete progress template',
  '删除节点': 'Delete node',
  '删除标签配置': 'Delete tag configuration',
  '选择颜色': 'Choose color',
  '清除日期': 'Clear date',
  '清除查询': 'Clear search',
  '计划有序，\n行动从容。': 'Plan clearly.\nAct confidently.',
  '从一个目标、一项任务开始，让计划清晰落地，让每一步都有方向。': 'Start with one goal and one task. Turn clear plans into purposeful action.',
  '开始规划': 'Start planning',
  '无需账号 · 计划与任务数据保存在本机':
      'No account required · Plan and task data stays on this device',
  '月视图': 'Month view',
  '周视图': 'Week view',
  '字体色置灰': 'Dim text',
  '勾选': 'Checkmark',
  '边框': 'Border',
  '专注': 'Focus',
  '关于': 'About',
  '系统设置': 'System settings',
  '通知未开启': 'Notifications are off',
  '通知和闹铃未开启或不可用': 'Notifications and alarms are off or unavailable',
  '当前平台不可用': 'Unavailable on this platform',
  '尚未请求': 'Not requested',
  '已允许': 'Allowed',
  '未允许': 'Not allowed',
  '需要 iOS 26 或更高版本': 'Requires iOS 26 or later',
  '启用通知与闹铃': 'Enable notifications and alarms',
  '可设置多个通知或闹铃': 'Add multiple notifications or alarms',
  '分类模板': 'Category templates',
  '标签模板': 'Tag templates',
  '隐私与数据': 'Privacy & data',
  '表格列显示与顺序': 'Visible columns and order',
  '新建计划': 'New plan',
  '新建任务': 'New task',
  '新建子任务': 'New subtask',
  '任务详情': 'Task details',
  '计划详情': 'Plan details',
  '所属计划': 'Plan',
  '上级任务': 'Parent task',
  '尚未安排日期': 'No date scheduled',
  '未安排': 'Not scheduled',
  '未填写': 'Not provided',
  '未选择': 'Not selected',
  '未分类': 'Uncategorized',
  '未设置进度': 'No progress set',
  '保存中…': 'Saving…',
  '保存计划': 'Save plan',
  '保存任务': 'Save task',
  '保存失败': 'Save failed',
  '操作失败': 'Operation failed',
  '删除失败': 'Delete failed',
  '导入失败': 'Import failed',
  '导出失败': 'Export failed',
  '导入中…': 'Importing…',
  '导出中…': 'Exporting…',
  '确认导入': 'Confirm import',
  '确认导出': 'Confirm export',
  '导入预览': 'Import preview',
  '无数据': 'No data',
  '暂无计划': 'No plans',
  '暂无任务': 'No tasks',
  '暂无计划或任务': 'No plans or tasks',
  '知道了': 'OK',
  '全部': 'All',
  '不限日期': 'Any date',
  '自定义大小': 'Custom size',
  '自定义时间段': 'Custom range',
  '安排': 'Schedule',
  '待安排': 'To schedule',
  '待开始': 'Not started',
  '待规划': 'To plan',
  '执行中': 'In progress',
  '已达成': 'Achieved',
  '等待处理': 'Waiting',
  '等待反馈': 'Awaiting feedback',
  '持续保持': 'Maintain',
  '普通标签': 'Regular tags',
  '四象限标签': 'Quadrant tags',
  '标签事项': 'Tagged items',
  '象限事项': 'Quadrant items',
  '一个计划': 'one plan',
  '一个任务': 'one task',
  '一个计划或任务': 'one plan or task',
  '个计划': 'plans',
  '计划 + 任务': 'Plans + tasks',
  '季度': 'Quarter',
  '半年': 'Half year',
  '本周': 'This week',
  '本期内': 'Within period',
  '覆盖整个统计周期': 'Covers the whole period',
  '跨越整期': 'Spans the period',
  '前期延续': 'Continued from before',
  '后期延续': 'Continues afterward',
  '本期开始并收尾': 'Starts and ends this period',
  '本期开始，后续持续': 'Starts this period and continues',
  '前期开始，本期收尾': 'Started before and ends this period',
  '完成率': 'Completion rate',
  '计划表格': 'Plan table',
  '计划ID': 'Plan ID',
  '联系人ID': 'Contact ID',
  '提醒规则': 'Reminder rules',
  '更新时间': 'Updated at',
  '填写说明': 'Instructions',
  '任务时间': 'Task time',
  '计划期间': 'Plan period',
};

const Map<String, String> _japanese = {
  '给个好评': 'アプリを評価',
  '前往 App Store 评价 ClPlan': 'App Store で ClPlan を評価',
  '暂时无法打开评价页面，请稍后重试': '評価ページを開けません。しばらくしてからもう一度お試しください。',
  '计划': '計画',
  '任务': 'タスク',
  '日历': 'カレンダー',
  '统计': '統計',
  '设置': '設定',
  '主题': 'テーマ',
  '语言': '言語',
  '字体大小': '文字サイズ',
  '跟随系统': 'システムに従う',
  '浅色': 'ライト',
  '深色': 'ダーク',
  '简体中文': '簡体字中国語',
  '确定删除“{0}”吗？': '「{0}」を削除しますか？',
  '确定删除“{0}”吗？存在任务的计划需要先清空任务。':
      '「{0}」を削除しますか？タスクがある場合は先にすべて削除してください。',
  '删除“{0}”联系人？': '連絡先「{0}」を削除しますか？',
  '删除“{0}”标签配置？': 'タグ設定「{0}」を削除しますか？',
  '显示与通知': '表示と通知',
  '计划完成样式': '完了した計画の表示',
  '月视图、周视图与四象限独立设置': '月表示・週表示・四象限を個別に設定',
  '通知与闹铃': '通知とアラーム',
  '计划配置': '計画の設定',
  '分类': 'カテゴリー',
  '进度': '進捗',
  '标签': 'タグ',
  '联系人': '連絡先',
  '数据与安全': 'データとセキュリティ',
  '安全锁': 'セキュリティロック',
  'App 启动验证': 'App 起動時の認証',
  '导出验证': 'エクスポート認証',
  '下次启动并显示欢迎页时验证': '次回起動時にウェルカム画面で認証します',
  '验证后 30 分钟内无需重复验证': '認証後30分間は再認証しません',
  '启动验证开启': '起動時認証オン',
  '启动验证关闭': '起動時認証オフ',
  '导出验证开启': 'エクスポート認証オン',
  '导出验证关闭': 'エクスポート認証オフ',
  '验证中…': '認証中…',
  '验证并进入': '認証して開始',
  '验证设备所有者以进入 ClPlan': 'ClPlanを開くためにデバイス所有者を認証します',
  '验证设备所有者以导出 ClPlan 数据': 'ClPlanデータを書き出すためにデバイス所有者を認証します',
  '验证设备所有者以修改安全锁设置': 'セキュリティロック設定を変更するために認証します',
  '无法验证身份': '認証できません',
  '请先在系统设置中设置设备密码或生物识别。':
      '先にシステム設定でデバイスのパスコードまたは生体認証を設定してください。',
  '系统认证已暂时锁定，请稍后重试或使用设备密码。':
      'システム認証は一時的にロックされています。後でもう一度試すか、デバイスのパスコードを使用してください。',
  '系统无法完成身份验证，请重试。': 'システム認証を完了できませんでした。もう一度お試しください。',
  '安全锁设置保存失败，请重试。': 'セキュリティロック設定を保存できませんでした。もう一度お試しください。',
  '表格与数据': '表とデータ',
  '查看、导入、导出与列设置': '表示・インポート・エクスポート・列設定',
  '隐私与本地存储': 'プライバシーとローカル保存',
  '数据边界与本地存储说明': 'データ範囲とローカル保存の説明',
  '支持与关于': 'サポートと情報',
  '关于 ClPlan': 'ClPlan について',
  '应用信息与赞赏': 'アプリ情報と支援',
  '基本信息': '基本情報',
  '时间与日历': '日時とカレンダー',
  '分类与进度': 'カテゴリーと進捗',
  '执行补充': '実行メモ',
  '计划名称': '計画名',
  '计划 ID': '計画 ID',
  '计划内容': '計画内容',
  '任务名称': 'タスク名',
  '任务内容': 'タスク内容',
  '标题': 'タイトル',
  '内容': '内容',
  '日期': '日付',
  '开始日期': '開始日',
  '结束日期': '終了日',
  '目标日期': '目標日',
  '整个期间': '期間全体',
  '仅起止日': '開始日と終了日のみ',
  '仅开始日': '開始日のみ',
  '仅目标日': '目標日のみ',
  '启用提醒': 'リマインダー有効',
  '完成时间': '完了日時',
  '修改时间': '更新日時',
  '是': 'はい',
  '否': 'いいえ',
  '时间': '時刻',
  '日历显示': 'カレンダー表示',
  '里程碑': 'マイルストーン',
  '周期任务': '繰り返しタスク',
  '重复日期': '繰り返す曜日',
  '名称': '名前',
  '说明': '説明',
  '保存': '保存',
  '取消': 'キャンセル',
  '删除': '削除',
  '编辑': '編集',
  '关闭': '閉じる',
  '新增': '追加',
  '清空': 'クリア',
  '全选': 'すべて選択',
  '未设置': '未設定',
  '未命名': '名称未設定',
  '保存并建下一项': '保存して次を作成',
  '清除日期和时间': '日付と時刻を消去',
  '四象限 · 单选': '四象限・単一選択',
  '跟进记录': 'フォローアップ',
  '变更历史': '変更履歴',
  '追加跟进': 'フォローアップを追加',
  '未完成主要原因': '未完了の主な理由',
  '通知提醒': '通知',
  '闹铃提醒': 'アラーム',
  '去设置': '設定を開く',
  '等待关联时间': '関連する時刻を待機中',
  '查询日期': '日付で絞り込み',
  '年度': '年',
  '月份': '月',
  '全部分类': 'すべてのカテゴリー',
  '全部进度方案': 'すべての進捗テンプレート',
  '该方案全部节点': 'このテンプレートの全ノード',
  '进度方案': '進捗テンプレート',
  '进度节点': '進捗ノード',
  '暂无标签': 'タグなし',
  '未完成': '未完了',
  '已完成': '完了',
  '未开始': '未開始',
  '进行中': '進行中',
  '默认进度': '標準の進捗',
  '工作': '仕事',
  '生活': '生活',
  '学习': '学習',
  '重要且紧急': '重要かつ緊急',
  '重要不紧急': '重要だが緊急でない',
  '不重要但紧急': '重要でないが緊急',
  '不重要不紧急': '重要でも緊急でもない',
  '全部状态': 'すべての状態',
  '四象限': '四象限',
  '月': '月',
  '周': '週',
  '周一': '月',
  '周二': '火',
  '周三': '水',
  '周四': '木',
  '周五': '金',
  '周六': '土',
  '周日': '日',
  '一': '月',
  '二': '火',
  '三': '水',
  '四': '木',
  '五': '金',
  '六': '土',
  '日': '日',
  '未完成 · 当前状态': '未完了・現在の状態',
  '未完成 · 主要原因': '未完了・主な理由',
  '计划完成概览': '計画完了の概要',
  '计划完成趋势': '計画完了の推移',
  '当前进度分布': '現在の進捗分布',
  '计划与本周期的关系': 'この期間の計画',
  '分类分布': 'カテゴリー分布',
  '其他标签统计': 'その他のタグ統計',
  '统计周期': '集計期間',
  '这段时间没有未完成任务。': 'この期間に未完了のタスクはありません。',
  '当前没有自定义标签，可先前往设置添加标签。': 'カスタムタグがありません。設定で追加してください。',
  '这一天还没有计划': 'この日の計画はありません',
  '新增计划': '計画を追加',
  '新增任务': 'タスクを追加',
  '新增子任务': 'サブタスクを追加',
  '新增联系人': '連絡先を追加',
  '没有其他可选联系人': '選択できる連絡先がありません',
  '姓名': '名前',
  '电话': '電話',
  '备注': 'メモ',
  '分类名称': 'カテゴリー名',
  '方案名称': 'テンプレート名',
  '节点名称': 'ノード名',
  '标签名称': 'タグ名',
  '计划关键词': '計画のキーワード',
  '搜索计划名称或内容': '計画名または内容を検索',
  '完成状态': '完了状態',
  '输入姓名、电话或备注': '名前・電話・メモを入力',
  '查看与设置': '表示と設定',
  '查看计划表格': '計画表を表示',
  '在 App 内快速核对当前计划数据': 'アプリ内で現在の計画データを確認',
  '计划表格列设置': '計画表の列設定',
  '调整计划表格的显示字段与顺序': '表示する列と順序を変更',
  '导入与导出': 'インポートとエクスポート',
  '导出': 'エクスポート',
  '导入': 'インポート',
  '导出计划数据': '計画データをエクスポート',
  '导入计划数据': '計画データをインポート',
  '导出联系人数据': '連絡先をエクスポート',
  '导入联系人数据': '連絡先をインポート',
  '模板内容': 'テンプレート内容',
  '本地数据与隐私': 'ローカルデータとプライバシー',
  '关于应用': 'アプリについて',
  '系统通知权限': 'システム通知の権限',
  '系统闹铃权限': 'システムアラームの権限',
  '闹铃调度状态': 'アラーム予約状態',
  '提醒声音': 'リマインダー音',
  '调度状态': '予約状態',
  '暂无可选分类。': '利用できるカテゴリーはありません。',
  '暂无可选标签。': '利用できるタグはありません。',
  '暂无联系人，可在这里或计划、任务表单中新增。': '連絡先がありません。ここ、または計画・タスク画面から追加できます。',
  '预览': 'プレビュー',
  '恢复默认（跟随系统）': '既定値に戻す（システムに従う）',
  '无样式': 'スタイルなし',
  '添加分类': 'カテゴリーを追加',
  '编辑分类': 'カテゴリーを編集',
  '颜色': '色',
  '图标': 'アイコン',
  '添加进度方案': '進捗テンプレートを追加',
  '编辑进度方案': '進捗テンプレートを編集',
  '开始': '開始',
  '中间': '中間',
  '结束': '終了',
  '添加中间节点': '中間ノードを追加',
  '保存方案': 'テンプレートを保存',
  '添加标签': 'タグを追加',
  '删除配置': '設定を削除',
  '更新联系人': '連絡先を更新',
  '按隐藏的联系人 ID 匹配': '非表示の連絡先 ID で照合',
  '全量导出': 'すべてエクスポート',
  '按条件导出': '条件付きエクスポート',
  '计划日期范围': '計画の日付範囲',
  '查询联系人': '連絡先を検索',
  '查询结果': '検索結果',
  '删除任务？': 'タスクを削除しますか？',
  '删除计划？': '計画を削除しますか？',
  '删除任务': 'タスクを削除',
  '删除计划': '計画を削除',
  '回到当前': '今日に戻る',
  '查询条件': '絞り込み条件',
  '统计条件': '統計条件',
  '切换周卡片/月份视图': '週カード／月表示を切り替え',
  '恢复默认条件': '条件をリセット',
  '选择或新增联系人': '連絡先を選択または追加',
  '编辑联系人配置': '連絡先を編集',
  '取消选择': '選択解除',
  '编辑联系人': '連絡先を編集',
  '删除联系人': '連絡先を削除',
  '更多操作': 'その他の操作',
  '编辑标签': 'タグを編集',
  '新增里程碑': 'マイルストーンを追加',
  '编辑里程碑': 'マイルストーンを編集',
  '删除里程碑': 'マイルストーンを削除',
  '新增周期任务': '繰り返しタスクを追加',
  '编辑周期任务': '繰り返しタスクを編集',
  '清除时间': '時刻を消去',
  '删除提醒': 'リマインダーを削除',
  '重新对账': '再確認',
  '删除分类': 'カテゴリーを削除',
  '删除进度方案': '進捗テンプレートを削除',
  '删除节点': 'ノードを削除',
  '删除标签配置': 'タグ設定を削除',
  '选择颜色': '色を選択',
  '清除日期': '日付を消去',
  '清除查询': '検索を消去',
  '计划有序，\n行动从容。': '計画を整え、\n落ち着いて行動。',
  '从一个目标、一项任务开始，让计划清晰落地，让每一步都有方向。': '一つの目標と一つのタスクから始め、計画を着実な行動につなげましょう。',
  '开始规划': '計画を始める',
  '无需账号 · 计划与任务数据保存在本机': 'アカウント不要・計画とタスクは端末内に保存',
  '基础规划计划': '基本ルールで計画を作成',
  '基础规划任务': '基本ルールでタスクを作成',
  '放弃本次输入？': '今回の入力を破棄しますか？',
  '尚未保存的规划内容和选择将会丢失。': '未保存の内容と選択は失われます。',
  '继续编辑': '編集を続ける',
  '放弃': '破棄',
  '输入计划内容': '計画内容を入力',
  '输入任务内容': 'タスク内容を入力',
  '例如：明天下午四点到机场接人': '例：明日の午後4時に空港へ迎えに行く',
  '建议标题': '候補タイトル',
  '正在分析输入内容': '入力内容を解析中',
  '暂时无法分析，可按原文继续填写。': '現在解析できません。元の文章のまま続けられます。',
  '当前设备不支持闹铃，请先处理这条建议。': 'この端末ではアラームを利用できません。先にこの提案を処理してください。',
  '改为通知': '通知に変更',
  '移除提醒': 'リマインダーを削除',
  '按原文填写': '元の文章を使用',
  '应用并继续': '適用して続行',
  '由本机基础规则生成 · 当前未安装语言模型': '端末内の基本ルールで生成',
  '由本机基础规则生成': '端末内の基本ルールで生成',
  '由本机语言模型生成': '端末内の言語モデルで生成',
  '设置安排日期': '予定日を設定',
  '设置安排时间': '予定時刻を設定',
  '移除安排时间': '予定時刻を削除',
  '移除日期与时间': '日付と時刻を削除',
  '提醒：使用当前默认设置': 'リマインダー：現在の既定値を使用',
  '提醒：无': 'リマインダー：なし',
  '闹铃': 'アラーム',
  '通知': '通知',
  '准时': '予定時刻',
  '指定时间': '指定時刻',
  '需要确认': '確認が必要',
  '这个时间是凌晨还是下午？': 'この時刻は午前ですか、午後ですか？',
  '这个时间安排在哪一天？': 'この時刻をどの日に設定しますか？',
  '请选择一个明确结果。': '明確な結果を選択してください。',
  '暂不设置时间': '時刻を設定しない',
  '暂不设置日期': '日付を設定しない',
  '没有提取到可用标题，请修改输入或按原文填写。': '使用できるタイトルを抽出できませんでした。入力を修正するか元の文章を使用してください。',
  '识别到的安排时间已经过去，请修改日期或时间。': '検出した予定時刻は過去です。日付または時刻を変更してください。',
  '识别到的提醒时间已经过去，请修改或移除提醒。': '検出したリマインダー時刻は過去です。変更または削除してください。',
  '安排时间需要同时设置日期，请选择日期或移除时间。': '予定時刻には日付も必要です。日付を選択するか時刻を削除してください。',
  '相对提醒需要完整的安排日期和时间，请补充安排或移除提醒。': '相対リマインダーには日付と時刻が必要です。予定を補完するか削除してください。',
  '输入最多 100 个字符。': '入力は100文字までです。',
  '当前只支持简体中文基础规划，将按原文处理。': '基本ルール解析は現在、簡体字中国語に対応しています。元の文章を使用します。',
  '包含多个时间表达，当前基础规划无法可靠处理，请按原文填写。': '複数の時刻表現は正確に処理できません。元の文章を使用してください。',
  '包含暂不支持的表达，可按原文继续填写。': '未対応の表現があります。元の文章のまま続けられます。',
  '月视图': '月表示',
  '周视图': '週表示',
  '字体色置灰': '文字を薄く表示',
  '勾选': 'チェック',
  '边框': '枠線',
  '专注': '集中',
  '关于': '情報',
  '系统设置': 'システム設定',
  '通知未开启': '通知はオフです',
  '通知和闹铃未开启或不可用': '通知とアラームがオフまたは利用できません',
  '当前平台不可用': 'このプラットフォームでは利用できません',
  '尚未请求': '未要求',
  '已允许': '許可済み',
  '未允许': '未許可',
  '需要 iOS 26 或更高版本': 'iOS 26 以降が必要です',
  '启用通知与闹铃': '通知とアラームを有効にする',
  '分类模板': 'カテゴリーテンプレート',
  '标签模板': 'タグテンプレート',
  '隐私与数据': 'プライバシーとデータ',
  '新建计划': '新しい計画',
  '新建任务': '新しいタスク',
  '新建子任务': '新しいサブタスク',
  '任务详情': 'タスク詳細',
  '计划详情': '計画詳細',
  '所属计划': '所属計画',
  '上级任务': '親タスク',
  '尚未安排日期': '日付未設定',
  '未安排': '未予定',
  '未填写': '未入力',
  '未选择': '未選択',
  '未分类': '未分類',
  '未设置进度': '進捗未設定',
  '保存中…': '保存中…',
  '保存计划': '計画を保存',
  '保存任务': 'タスクを保存',
  '保存失败': '保存に失敗しました',
  '操作失败': '操作に失敗しました',
  '删除失败': '削除に失敗しました',
  '导入失败': 'インポートに失敗しました',
  '导出失败': 'エクスポートに失敗しました',
  '导入中…': 'インポート中…',
  '导出中…': 'エクスポート中…',
  '确认导入': 'インポートを確認',
  '确认导出': 'エクスポートを確認',
  '导入预览': 'インポートプレビュー',
  '无数据': 'データなし',
  '暂无计划': '計画なし',
  '暂无任务': 'タスクなし',
  '暂无计划或任务': '計画またはタスクなし',
  '知道了': 'OK',
  '全部': 'すべて',
  '不限日期': '日付指定なし',
  '自定义大小': 'カスタムサイズ',
  '自定义时间段': 'カスタム期間',
  '计划表格': '計画表',
  '提醒规则': 'リマインダールール',
  '填写说明': '入力ガイド',
  '任务时间': 'タスク時刻',
  '计划期间': '計画期間',
};

const Map<String, String> _korean = {
  '给个好评': '앱 평가하기',
  '前往 App Store 评价 ClPlan': 'App Store에서 ClPlan 평가하기',
  '暂时无法打开评价页面，请稍后重试': '평가 페이지를 열 수 없습니다. 나중에 다시 시도해 주세요.',
  '计划': '계획',
  '任务': '작업',
  '日历': '캘린더',
  '统计': '통계',
  '设置': '설정',
  '主题': '테마',
  '语言': '언어',
  '字体大小': '글자 크기',
  '跟随系统': '시스템 설정 따르기',
  '浅色': '라이트',
  '深色': '다크',
  '简体中文': '중국어 간체',
  '确定删除“{0}”吗？': '“{0}”을(를) 삭제할까요?',
  '确定删除“{0}”吗？存在任务的计划需要先清空任务。':
      '“{0}”을(를) 삭제할까요? 작업이 있는 계획은 먼저 작업을 모두 삭제해야 합니다.',
  '删除“{0}”联系人？': '연락처 “{0}”을(를) 삭제할까요?',
  '删除“{0}”标签配置？': '태그 설정 “{0}”을(를) 삭제할까요?',
  '显示与通知': '화면 및 알림',
  '计划完成样式': '완료된 계획 스타일',
  '月视图、周视图与四象限独立设置': '월·주·사분면 보기를 각각 설정',
  '通知与闹铃': '알림 및 알람',
  '计划配置': '계획 구성',
  '分类': '카테고리',
  '进度': '진행 상태',
  '标签': '태그',
  '联系人': '연락처',
  '数据与安全': '데이터 및 보안',
  '安全锁': '보안 잠금',
  'App 启动验证': '앱 시작 인증',
  '导出验证': '내보내기 인증',
  '下次启动并显示欢迎页时验证': '다음 실행 시 시작 화면에서 인증합니다',
  '验证后 30 分钟内无需重复验证': '인증 후 30분 동안 다시 인증하지 않습니다',
  '启动验证开启': '시작 인증 켜짐',
  '启动验证关闭': '시작 인증 꺼짐',
  '导出验证开启': '내보내기 인증 켜짐',
  '导出验证关闭': '내보내기 인증 꺼짐',
  '验证中…': '인증 중…',
  '验证并进入': '인증하고 들어가기',
  '验证设备所有者以进入 ClPlan': 'ClPlan에 들어가려면 기기 소유자를 인증하세요',
  '验证设备所有者以导出 ClPlan 数据': 'ClPlan 데이터를 내보내려면 기기 소유자를 인증하세요',
  '验证设备所有者以修改安全锁设置': '보안 잠금 설정을 변경하려면 기기 소유자를 인증하세요',
  '无法验证身份': '인증할 수 없음',
  '请先在系统设置中设置设备密码或生物识别。':
      '먼저 시스템 설정에서 기기 암호 또는 생체 인증을 설정하세요.',
  '系统认证已暂时锁定，请稍后重试或使用设备密码。':
      '시스템 인증이 일시적으로 잠겼습니다. 나중에 다시 시도하거나 기기 암호를 사용하세요.',
  '系统无法完成身份验证，请重试。': '시스템 인증을 완료하지 못했습니다. 다시 시도하세요.',
  '安全锁设置保存失败，请重试。': '보안 잠금 설정을 저장하지 못했습니다. 다시 시도하세요.',
  '表格与数据': '표 및 데이터',
  '查看、导入、导出与列设置': '보기·가져오기·내보내기·열 설정',
  '隐私与本地存储': '개인정보 및 로컬 저장소',
  '数据边界与本地存储说明': '데이터 범위 및 로컬 저장소 안내',
  '支持与关于': '지원 및 정보',
  '关于 ClPlan': 'ClPlan 정보',
  '应用信息与赞赏': '앱 정보 및 후원',
  '基本信息': '기본 정보',
  '时间与日历': '시간 및 캘린더',
  '分类与进度': '카테고리 및 진행 상태',
  '执行补充': '실행 메모',
  '计划名称': '계획 이름',
  '计划 ID': '계획 ID',
  '计划内容': '계획 내용',
  '任务名称': '작업 이름',
  '任务内容': '작업 내용',
  '标题': '제목',
  '内容': '내용',
  '日期': '날짜',
  '开始日期': '시작일',
  '结束日期': '종료일',
  '目标日期': '목표일',
  '时间': '시간',
  '日历显示': '캘린더 표시',
  '里程碑': '마일스톤',
  '整个期间': '전체 기간',
  '仅起止日': '시작일과 종료일만',
  '仅开始日': '시작일만',
  '仅目标日': '목표일만',
  '启用提醒': '미리 알림 사용',
  '完成时间': '완료 시간',
  '修改时间': '수정 시간',
  '是': '예',
  '否': '아니요',
  '周期任务': '반복 작업',
  '重复日期': '반복 요일',
  '名称': '이름',
  '说明': '설명',
  '保存': '저장',
  '取消': '취소',
  '删除': '삭제',
  '编辑': '편집',
  '关闭': '닫기',
  '新增': '추가',
  '清空': '지우기',
  '全选': '모두 선택',
  '未设置': '설정 안 됨',
  '未命名': '이름 없음',
  '保存并建下一项': '저장 후 다음 항목 만들기',
  '清除日期和时间': '날짜와 시간 지우기',
  '四象限 · 单选': '사분면 · 단일 선택',
  '跟进记录': '후속 기록',
  '变更历史': '변경 기록',
  '追加跟进': '후속 기록 추가',
  '未完成主要原因': '미완료 주요 원인',
  '通知提醒': '알림',
  '闹铃提醒': '알람',
  '去设置': '설정 열기',
  '等待关联时间': '연결된 시간 대기 중',
  '查询日期': '날짜 필터',
  '年度': '연도',
  '月份': '월',
  '全部分类': '모든 카테고리',
  '全部进度方案': '모든 진행 템플릿',
  '该方案全部节点': '이 템플릿의 모든 단계',
  '进度方案': '진행 템플릿',
  '进度节点': '진행 단계',
  '暂无标签': '태그 없음',
  '未完成': '미완료',
  '已完成': '완료',
  '未开始': '시작 전',
  '进行中': '진행 중',
  '默认进度': '기본 진행 상태',
  '工作': '업무',
  '生活': '생활',
  '学习': '학습',
  '重要且紧急': '중요하고 긴급함',
  '重要不紧急': '중요하지만 긴급하지 않음',
  '不重要但紧急': '중요하지 않지만 긴급함',
  '不重要不紧急': '중요하지도 긴급하지도 않음',
  '全部状态': '모든 상태',
  '四象限': '사분면',
  '月': '월',
  '周': '주',
  '周一': '월',
  '周二': '화',
  '周三': '수',
  '周四': '목',
  '周五': '금',
  '周六': '토',
  '周日': '일',
  '一': '월',
  '二': '화',
  '三': '수',
  '四': '목',
  '五': '금',
  '六': '토',
  '日': '일',
  '未完成 · 当前状态': '미완료 · 현재 상태',
  '未完成 · 主要原因': '미완료 · 주요 원인',
  '计划完成概览': '계획 완료 개요',
  '计划完成趋势': '계획 완료 추이',
  '当前进度分布': '현재 진행 분포',
  '计划与本周期的关系': '이 기간의 계획',
  '分类分布': '카테고리 분포',
  '其他标签统计': '기타 태그 통계',
  '统计周期': '통계 기간',
  '这段时间没有未完成任务。': '이 기간에는 미완료 작업이 없습니다.',
  '当前没有自定义标签，可先前往设置添加标签。': '사용자 태그가 없습니다. 설정에서 먼저 추가하세요.',
  '这一天还没有计划': '이 날짜에는 계획이 없습니다',
  '新增计划': '계획 추가',
  '新增任务': '작업 추가',
  '新增子任务': '하위 작업 추가',
  '新增联系人': '연락처 추가',
  '没有其他可选联系人': '선택할 다른 연락처가 없습니다',
  '姓名': '이름',
  '电话': '전화',
  '备注': '메모',
  '分类名称': '카테고리 이름',
  '方案名称': '템플릿 이름',
  '节点名称': '단계 이름',
  '标签名称': '태그 이름',
  '计划关键词': '계획 키워드',
  '搜索计划名称或内容': '계획 이름 또는 내용 검색',
  '完成状态': '완료 상태',
  '输入姓名、电话或备注': '이름, 전화번호 또는 메모 입력',
  '查看与设置': '보기 및 설정',
  '查看计划表格': '계획 표 보기',
  '在 App 内快速核对当前计划数据': '앱에서 현재 계획 데이터 확인',
  '计划表格列设置': '계획 표 열 설정',
  '调整计划表格的显示字段与顺序': '표시할 필드와 순서 조정',
  '导入与导出': '가져오기 및 내보내기',
  '导出': '내보내기',
  '导入': '가져오기',
  '导出计划数据': '계획 데이터 내보내기',
  '导入计划数据': '계획 데이터 가져오기',
  '导出联系人数据': '연락처 내보내기',
  '导入联系人数据': '연락처 가져오기',
  '模板内容': '템플릿 내용',
  '本地数据与隐私': '로컬 데이터 및 개인정보',
  '关于应用': '앱 정보',
  '系统通知权限': '시스템 알림 권한',
  '系统闹铃权限': '시스템 알람 권한',
  '闹铃调度状态': '알람 예약 상태',
  '提醒声音': '미리 알림 소리',
  '调度状态': '예약 상태',
  '暂无可选分类。': '사용 가능한 카테고리가 없습니다.',
  '暂无可选标签。': '사용 가능한 태그가 없습니다.',
  '暂无联系人，可在这里或计划、任务表单中新增。': '연락처가 없습니다. 여기 또는 계획·작업 양식에서 추가할 수 있습니다.',
  '预览': '미리보기',
  '恢复默认（跟随系统）': '기본값 복원(시스템 설정 따르기)',
  '无样式': '스타일 없음',
  '添加分类': '카테고리 추가',
  '编辑分类': '카테고리 편집',
  '颜色': '색상',
  '图标': '아이콘',
  '添加进度方案': '진행 템플릿 추가',
  '编辑进度方案': '진행 템플릿 편집',
  '开始': '시작',
  '中间': '중간',
  '结束': '종료',
  '添加中间节点': '중간 단계 추가',
  '保存方案': '템플릿 저장',
  '添加标签': '태그 추가',
  '删除配置': '설정 삭제',
  '更新联系人': '연락처 업데이트',
  '按隐藏的联系人 ID 匹配': '숨겨진 연락처 ID로 일치',
  '全量导出': '전체 내보내기',
  '按条件导出': '조건별 내보내기',
  '计划日期范围': '계획 날짜 범위',
  '查询联系人': '연락처 검색',
  '查询结果': '검색 결과',
  '删除任务？': '작업을 삭제할까요?',
  '删除计划？': '계획을 삭제할까요?',
  '删除任务': '작업 삭제',
  '删除计划': '계획 삭제',
  '回到当前': '오늘로 이동',
  '查询条件': '필터',
  '统计条件': '통계 필터',
  '切换周卡片/月份视图': '주 카드/월 보기 전환',
  '恢复默认条件': '필터 초기화',
  '选择或新增联系人': '연락처 선택 또는 추가',
  '编辑联系人配置': '연락처 편집',
  '取消选择': '선택 해제',
  '编辑联系人': '연락처 편집',
  '删除联系人': '연락처 삭제',
  '更多操作': '더보기',
  '编辑标签': '태그 편집',
  '新增里程碑': '마일스톤 추가',
  '编辑里程碑': '마일스톤 편집',
  '删除里程碑': '마일스톤 삭제',
  '新增周期任务': '반복 작업 추가',
  '编辑周期任务': '반복 작업 편집',
  '清除时间': '시간 지우기',
  '删除提醒': '미리 알림 삭제',
  '重新对账': '다시 확인',
  '删除分类': '카테고리 삭제',
  '删除进度方案': '진행 템플릿 삭제',
  '删除节点': '단계 삭제',
  '删除标签配置': '태그 설정 삭제',
  '选择颜色': '색상 선택',
  '清除日期': '날짜 지우기',
  '清除查询': '검색 지우기',
  '计划有序，\n行动从容。': '계획은 명확하게,\n실행은 여유롭게.',
  '从一个目标、一项任务开始，让计划清晰落地，让每一步都有方向。': '하나의 목표와 하나의 작업부터 시작해 계획을 분명한 행동으로 이어가세요.',
  '开始规划': '계획 시작',
  '无需账号 · 计划与任务数据保存在本机': '계정 불필요 · 계획과 작업은 기기에 저장됩니다',
  '基础规划计划': '기본 규칙으로 계획 만들기',
  '基础规划任务': '기본 규칙으로 작업 만들기',
  '放弃本次输入？': '이번 입력을 버릴까요?',
  '尚未保存的规划内容和选择将会丢失。': '저장하지 않은 내용과 선택이 사라집니다.',
  '继续编辑': '계속 편집',
  '放弃': '버리기',
  '输入计划内容': '계획 내용 입력',
  '输入任务内容': '작업 내용 입력',
  '例如：明天下午四点到机场接人': '예: 내일 오후 4시에 공항으로 마중 가기',
  '建议标题': '추천 제목',
  '正在分析输入内容': '입력 내용 분석 중',
  '暂时无法分析，可按原文继续填写。': '현재 분석할 수 없습니다. 원문으로 계속할 수 있습니다.',
  '当前设备不支持闹铃，请先处理这条建议。': '이 기기에서는 알람을 지원하지 않습니다. 먼저 이 제안을 처리하세요.',
  '改为通知': '알림으로 변경',
  '移除提醒': '미리 알림 제거',
  '按原文填写': '원문 사용',
  '应用并继续': '적용하고 계속',
  '由本机基础规则生成 · 当前未安装语言模型': '기기 내 기본 규칙으로 생성',
  '由本机基础规则生成': '기기 내 기본 규칙으로 생성',
  '由本机语言模型生成': '기기 내 언어 모델로 생성',
  '设置安排日期': '예정 날짜 설정',
  '设置安排时间': '예정 시간 설정',
  '移除安排时间': '예정 시간 제거',
  '移除日期与时间': '날짜와 시간 제거',
  '提醒：使用当前默认设置': '미리 알림: 현재 기본값 사용',
  '提醒：无': '미리 알림: 없음',
  '闹铃': '알람',
  '通知': '알림',
  '准时': '정시',
  '指定时间': '지정 시간',
  '需要确认': '확인 필요',
  '这个时间是凌晨还是下午？': '이 시간은 오전인가요, 오후인가요?',
  '这个时间安排在哪一天？': '이 시간을 어느 날짜에 지정할까요?',
  '请选择一个明确结果。': '명확한 결과를 선택하세요.',
  '暂不设置时间': '시간 설정 안 함',
  '暂不设置日期': '날짜 설정 안 함',
  '没有提取到可用标题，请修改输入或按原文填写。': '사용할 수 있는 제목을 찾지 못했습니다. 입력을 수정하거나 원문을 사용하세요.',
  '识别到的安排时间已经过去，请修改日期或时间。': '감지된 예정 시간이 지났습니다. 날짜나 시간을 변경하세요.',
  '识别到的提醒时间已经过去，请修改或移除提醒。': '감지된 미리 알림 시간이 지났습니다. 변경하거나 제거하세요.',
  '安排时间需要同时设置日期，请选择日期或移除时间。': '예정 시간에는 날짜도 필요합니다. 날짜를 선택하거나 시간을 제거하세요.',
  '相对提醒需要完整的安排日期和时间，请补充安排或移除提醒。':
      '상대 미리 알림에는 날짜와 시간이 모두 필요합니다. 일정을 완성하거나 제거하세요.',
  '输入最多 100 个字符。': '입력은 100자까지 가능합니다.',
  '当前只支持简体中文基础规划，将按原文处理。': '기본 규칙 분석은 현재 중국어 간체를 지원합니다. 원문을 사용합니다.',
  '包含多个时间表达，当前基础规划无法可靠处理，请按原文填写。': '여러 시간 표현은 안정적으로 처리할 수 없습니다. 원문을 사용하세요.',
  '包含暂不支持的表达，可按原文继续填写。': '지원하지 않는 표현이 있습니다. 원문으로 계속할 수 있습니다.',
  '月视图': '월 보기',
  '周视图': '주 보기',
  '字体色置灰': '텍스트 흐리게',
  '勾选': '체크',
  '边框': '테두리',
  '专注': '집중',
  '关于': '정보',
  '系统设置': '시스템 설정',
  '通知未开启': '알림이 꺼져 있습니다',
  '通知和闹铃未开启或不可用': '알림과 알람이 꺼져 있거나 사용할 수 없습니다',
  '当前平台不可用': '현재 플랫폼에서 사용할 수 없습니다',
  '尚未请求': '요청 전',
  '已允许': '허용됨',
  '未允许': '허용 안 됨',
  '需要 iOS 26 或更高版本': 'iOS 26 이상 필요',
  '启用通知与闹铃': '알림 및 알람 켜기',
  '分类模板': '카테고리 템플릿',
  '标签模板': '태그 템플릿',
  '隐私与数据': '개인정보 및 데이터',
  '新建计划': '새 계획',
  '新建任务': '새 작업',
  '新建子任务': '새 하위 작업',
  '任务详情': '작업 상세',
  '计划详情': '계획 상세',
  '所属计划': '소속 계획',
  '上级任务': '상위 작업',
  '尚未安排日期': '날짜 미정',
  '未安排': '일정 없음',
  '未填写': '입력 안 됨',
  '未选择': '선택 안 됨',
  '未分类': '분류 없음',
  '未设置进度': '진행 상태 미설정',
  '保存中…': '저장 중…',
  '保存计划': '계획 저장',
  '保存任务': '작업 저장',
  '保存失败': '저장 실패',
  '操作失败': '작업 실패',
  '删除失败': '삭제 실패',
  '导入失败': '가져오기 실패',
  '导出失败': '내보내기 실패',
  '导入中…': '가져오는 중…',
  '导出中…': '내보내는 중…',
  '确认导入': '가져오기 확인',
  '确认导出': '내보내기 확인',
  '导入预览': '가져오기 미리보기',
  '无数据': '데이터 없음',
  '暂无计划': '계획 없음',
  '暂无任务': '작업 없음',
  '暂无计划或任务': '계획 또는 작업 없음',
  '知道了': '확인',
  '全部': '전체',
  '不限日期': '날짜 제한 없음',
  '自定义大小': '사용자 지정 크기',
  '自定义时间段': '사용자 지정 기간',
  '计划表格': '계획 표',
  '提醒规则': '미리 알림 규칙',
  '填写说明': '입력 안내',
  '任务时间': '작업 시간',
  '计划期间': '계획 기간',
};

const Map<String, String> _traditionalChinese = {
  '给个好评': '給個好評',
  '前往 App Store 评价 ClPlan': '前往 App Store 評價 ClPlan',
  '暂时无法打开评价页面，请稍后重试': '暫時無法開啟評價頁面，請稍後重試',
  '简体中文': '簡體中文',
  '繁體中文': '繁體中文',
  '安全锁': '安全鎖',
  'App 启动验证': 'App 啟動驗證',
  '导出验证': '匯出驗證',
  '下次启动并显示欢迎页时验证': '下次啟動並顯示歡迎頁時驗證',
  '验证后 30 分钟内无需重复验证': '驗證後 30 分鐘內無需重複驗證',
  '启动验证开启': '啟動驗證開啟',
  '启动验证关闭': '啟動驗證關閉',
  '导出验证开启': '匯出驗證開啟',
  '导出验证关闭': '匯出驗證關閉',
  '验证中…': '驗證中…',
  '验证并进入': '驗證並進入',
  '验证设备所有者以进入 ClPlan': '驗證裝置擁有者以進入 ClPlan',
  '验证设备所有者以导出 ClPlan 数据': '驗證裝置擁有者以匯出 ClPlan 資料',
  '验证设备所有者以修改安全锁设置': '驗證裝置擁有者以修改安全鎖設定',
  '无法验证身份': '無法驗證身分',
  '请先在系统设置中设置设备密码或生物识别。':
      '請先在系統設定中設定裝置密碼或生物辨識。',
  '系统认证已暂时锁定，请稍后重试或使用设备密码。':
      '系統認證已暫時鎖定，請稍後重試或使用裝置密碼。',
  '系统无法完成身份验证，请重试。': '系統無法完成身分驗證，請重試。',
  '安全锁设置保存失败，请重试。': '安全鎖設定儲存失敗，請重試。',
};

const Map<String, String> _japaneseTerms = {
  '暂无': '現在ありません：',
  '当前': '現在',
  '计划': '計画',
  '任务': 'タスク',
  '联系人': '連絡先',
  '里程碑': 'マイルストーン',
  '周期': '繰り返し',
  '提醒': 'リマインダー',
  '闹铃': 'アラーム',
  '通知': '通知',
  '分类': 'カテゴリー',
  '进度': '進捗',
  '方案': 'テンプレート',
  '节点': 'ノード',
  '标签': 'タグ',
  '设置': '設定',
  '系统': 'システム',
  '数据': 'データ',
  '日期': '日付',
  '时间': '時刻',
  '开始': '開始',
  '结束': '終了',
  '目标': '目標',
  '完成': '完了',
  '未完成': '未完了',
  '已完成': '完了済み',
  '等待': '待機',
  '失败': '失敗',
  '允许': '許可',
  '保存': '保存',
  '导入': 'インポート',
  '导出': 'エクスポート',
  '新增': '追加',
  '更新': '更新',
  '删除': '削除',
  '编辑': '編集',
  '选择': '選択',
  '查询': '検索',
  '显示': '表示',
  '名称': '名前',
  '内容': '内容',
  '说明': '説明',
  '个': ' 件',
  '项': ' 件',
  '条': ' 件',
  '人': ' 人',
  '年': '年',
  '月': '月',
  '天': '日',
  '小时': '時間',
  '分钟': '分',
  '至': '～',
  '与': 'と',
  '或': 'または',
  '和': 'と',
  '已': '済み',
  '未': '未',
};

const Map<String, String> _koreanTerms = {
  '暂无': '현재 없음: ',
  '当前': '현재',
  '计划': '계획',
  '任务': '작업',
  '联系人': '연락처',
  '里程碑': '마일스톤',
  '周期': '반복',
  '提醒': '미리 알림',
  '闹铃': '알람',
  '通知': '알림',
  '分类': '카테고리',
  '进度': '진행',
  '方案': '템플릿',
  '节点': '단계',
  '标签': '태그',
  '设置': '설정',
  '系统': '시스템',
  '数据': '데이터',
  '日期': '날짜',
  '时间': '시간',
  '开始': '시작',
  '结束': '종료',
  '目标': '목표',
  '未完成': '미완료',
  '已完成': '완료',
  '完成': '완료',
  '等待': '대기',
  '失败': '실패',
  '允许': '허용',
  '保存': '저장',
  '导入': '가져오기',
  '导出': '내보내기',
  '新增': '추가',
  '更新': '업데이트',
  '删除': '삭제',
  '编辑': '편집',
  '选择': '선택',
  '查询': '검색',
  '显示': '표시',
  '名称': '이름',
  '内容': '내용',
  '说明': '설명',
  '个': '개',
  '项': '개',
  '条': '개',
  '人': '명',
  '年': '년',
  '月': '월',
  '天': '일',
  '小时': '시간',
  '分钟': '분',
  '至': '~',
  '与': ' 및 ',
  '或': ' 또는 ',
  '和': ' 및 ',
  '已': '완료 ',
  '未': '미',
};

String _toTraditional(String source) {
  const replacements = <String, String>{
    '计划': '計畫',
    '任务': '任務',
    '设置': '設定',
    '统计': '統計',
    '进度': '進度',
    '周': '週',
    '分类': '分類',
    '标签': '標籤',
    '联系人': '聯絡人',
    '数据': '資料',
    '导入': '匯入',
    '导出': '匯出',
    '查看': '檢視',
    '显示': '顯示',
    '通知': '通知',
    '闹铃': '鬧鐘',
    '隐私': '隱私',
    '本地存储': '本機儲存',
    '关于': '關於',
    '应用': '應用程式',
    '信息': '資訊',
    '时间': '時間',
    '日历': '日曆',
    '执行': '執行',
    '名称': '名稱',
    '内容': '內容',
    '开始': '開始',
    '结束': '結束',
    '目标': '目標',
    '里程碑': '里程碑',
    '周期': '週期',
    '重复': '重複',
    '说明': '說明',
    '保存': '儲存',
    '删除': '刪除',
    '编辑': '編輯',
    '关闭': '關閉',
    '新增': '新增',
    '清空': '清除',
    '全选': '全選',
    '未设置': '未設定',
    '未命名': '未命名',
    '记录': '記錄',
    '变更': '變更',
    '完成': '完成',
    '查询': '查詢',
    '年度': '年度',
    '月份': '月份',
    '方案': '方案',
    '节点': '節點',
    '默认': '預設',
    '进行中': '進行中',
    '学习': '學習',
    '紧急': '緊急',
    '这': '這',
    '没有': '沒有',
    '选择': '選擇',
    '电话': '電話',
    '备注': '備註',
    '关键词': '關鍵字',
    '搜索': '搜尋',
    '调整': '調整',
    '字段': '欄位',
    '顺序': '順序',
    '模板': '範本',
    '系统': '系統',
    '权限': '權限',
    '调度': '排程',
    '声音': '聲音',
    '恢复': '恢復',
    '颜色': '顏色',
    '图标': '圖示',
    '更新': '更新',
    '隐藏': '隱藏',
    '匹配': '比對',
    '条件': '條件',
    '当前': '目前',
    '自动': '自動',
    '进入': '進入',
    '无需': '無需',
    '账号': '帳號',
    '行动': '行動',
    '从': '從',
    '让': '讓',
    '项': '項',
  };
  var result = source;
  for (final entry in replacements.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}

/// Drop-in replacement for simple [material.Text] widgets. It keeps legacy
/// call sites const while resolving their display string at build time.
class Text extends material.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final material.TextStyle? style;
  final material.StrutStyle? strutStyle;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final material.Locale? locale;
  final bool? softWrap;
  final material.TextOverflow? overflow;
  final material.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final String? semanticsIdentifier;
  final material.TextWidthBasis? textWidthBasis;
  final material.TextHeightBehavior? textHeightBehavior;
  final material.Color? selectionColor;

  @override
  material.Widget build(material.BuildContext context) => material.Text(
    localizeUiText(context, data),
    style: style,
    strutStyle: strutStyle,
    textAlign: textAlign,
    textDirection: textDirection,
    locale: locale,
    softWrap: softWrap,
    overflow: overflow,
    textScaler: textScaler,
    maxLines: maxLines,
    semanticsLabel: semanticsLabel == null
        ? null
        : localizeUiText(context, semanticsLabel!),
    semanticsIdentifier: semanticsIdentifier,
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    selectionColor: selectionColor,
  );
}

/// Displays application or user-provided data exactly as stored.
///
/// Use this instead of the legacy localized [Text] wrapper for names, notes,
/// labels, imported values, and other content that must not change when the
/// application locale changes.
class RawText extends material.StatelessWidget {
  const RawText(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final material.TextStyle? style;
  final material.StrutStyle? strutStyle;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final material.Locale? locale;
  final bool? softWrap;
  final material.TextOverflow? overflow;
  final material.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final String? semanticsIdentifier;
  final material.TextWidthBasis? textWidthBasis;
  final material.TextHeightBehavior? textHeightBehavior;
  final material.Color? selectionColor;

  @override
  material.Widget build(material.BuildContext context) => material.Text(
    data,
    style: style,
    strutStyle: strutStyle,
    textAlign: textAlign,
    textDirection: textDirection,
    locale: locale,
    softWrap: softWrap,
    overflow: overflow,
    textScaler: textScaler,
    maxLines: maxLines,
    semanticsLabel: semanticsLabel,
    semanticsIdentifier: semanticsIdentifier,
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    selectionColor: selectionColor,
  );
}
