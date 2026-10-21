import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'contact_widgets.dart';
import 'models.dart';
import 'notification_service.dart';
import 'xlsx_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
    children: [
      _SettingsSection(
        title: '显示与通知',
        children: [
          _SettingsMenuItem(
            icon: Icons.palette_outlined,
            title: '外观与阅读',
            subtitle: '主题、字号与语言偏好',
            onTap: () => _openDetail(context, '外观与阅读', _appearanceDetail),
          ),
          _SettingsMenuItem(
            icon: Icons.calendar_view_month_outlined,
            title: '日历显示',
            subtitle: '日历密度与行高',
            onTap: () => _openDetail(context, '日历', _calendarDetail),
          ),
          _SettingsMenuItem(
            icon: Icons.notifications_active_outlined,
            title: '通知与闹铃',
            subtitle:
                controller.reminderPermission ==
                        ReminderPermissionState.authorized ||
                    controller.alarmPermission ==
                        AlarmPermissionState.authorized
                ? '通知 ${controller.scheduledReminderCount} 个 · '
                      '闹铃 ${controller.scheduledAlarmCount} 个'
                : '通知和闹铃未开启或不可用',
            onTap: () => _openDetail(context, '通知与闹铃', _reminderDetail),
          ),
        ],
      ),
      _SettingsSection(
        title: '计划配置',
        children: [
          _SettingsMenuItem(
            icon: Icons.folder_outlined,
            title: '分类',
            subtitle:
                '${controller.categoryDefinitions.length}/$maxCategoryDefinitionCount',
            onTap: () => _openDetail(context, '分类', _categoryDetail),
          ),
          _SettingsMenuItem(
            icon: Icons.route_outlined,
            title: '进度',
            subtitle:
                '${controller.progressTemplates.length}/$maxProgressTemplateCount',
            onTap: () => _openDetail(context, '进度', _progressDetail),
          ),
          _SettingsMenuItem(
            icon: Icons.sell_outlined,
            title: '标签',
            subtitle:
                '${controller.tagDefinitions.length}/$maxTagDefinitionCount',
            onTap: () => _openDetail(context, '标签', _tagDetail),
          ),
          _SettingsMenuItem(
            icon: Icons.contacts_outlined,
            title: '联系人',
            subtitle: '${controller.contacts.length} 人',
            onTap: () => _openDetail(context, '联系人', _contactDetail),
          ),
        ],
      ),
      _SettingsSection(
        title: '数据与安全',
        children: [
          _SettingsMenuItem(
            icon: Icons.table_chart_outlined,
            title: '表格与数据',
            subtitle: '查看、导入、导出与列设置',
            onTap: () => _openDetail(context, '表格与数据', _tableDetail),
          ),
          _SettingsMenuItem(
            icon: Icons.shield_outlined,
            title: '隐私与本地存储',
            subtitle: '数据边界与本地存储说明',
            onTap: () => _openDetail(context, '隐私与数据', _privacyDetail),
          ),
        ],
      ),
      _SettingsSection(
        title: '支持与关于',
        children: [
          _SettingsMenuItem(
            icon: Icons.help_outline,
            title: '帮助与反馈',
            subtitle: '使用帮助、问题反馈与版本记录',
            onTap: () => _openDetail(context, '帮助与反馈', _helpDetail),
          ),
          _SettingsMenuItem(
            icon: Icons.info_outline,
            title: '关于日序',
            subtitle: '应用信息、赞赏与评分',
            onTap: () => _openDetail(context, '关于', _aboutDetail),
          ),
        ],
      ),
    ],
  );

  Future<void> _openDetail(
    BuildContext context,
    String title,
    Widget Function(BuildContext) builder,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _SettingsDetailPage(
        title: title,
        controller: controller,
        contentBuilder: builder,
      ),
    ),
  );

  Widget _appearanceDetail(BuildContext context) => _Panel(
    title: '显示偏好',
    children: [
      _SelectRow(
        label: '主题',
        value: controller.preferences.theme,
        values: const {'system': '跟随系统', 'light': '浅色', 'dark': '深色'},
        onChanged: (value) => controller.setPreference('theme', value),
      ),
      _SelectRow(
        label: '字号',
        value: controller.preferences.font,
        values: const {'small': '小', 'normal': '标准', 'large': '大'},
        onChanged: (value) => controller.setPreference('font', value),
      ),
      _SelectRow(
        label: '语言偏好',
        value: controller.preferences.language,
        values: const {
          'zh': '简体中文',
          'tw': '繁體中文',
          'en': 'English',
          'ja': '日本語',
        },
        onChanged: (value) => controller.setPreference('language', value),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          '界面文案当前为简体中文；其他语言偏好已预留，后续版本逐步提供。',
          style: TextStyle(fontSize: 12),
        ),
      ),
    ],
  );

  Widget _calendarDetail(BuildContext context) =>
      _CalendarDensityEditor(controller: controller);

  Widget _reminderDetail(BuildContext context) {
    final authorized =
        controller.reminderPermission == ReminderPermissionState.authorized;
    final permissionText = switch (controller.reminderPermission) {
      ReminderPermissionState.authorized => '已允许',
      ReminderPermissionState.disabled => '未允许',
      ReminderPermissionState.unsupported => '当前平台不可用',
    };
    return _Panel(
      title: '通知与闹铃',
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            authorized
                ? Icons.notifications_active
                : Icons.notifications_off_outlined,
            color: authorized
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
          title: const Text('系统通知权限'),
          subtitle: Text(permissionText),
          trailing: TextButton(
            onPressed: () async {
              if (authorized) {
                await controller.openReminderSettings();
              } else {
                final granted = await controller.requestReminderPermission();
                if (!context.mounted) return;
                if (!granted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('通知未开启，可前往系统设置手动允许。')),
                  );
                }
              }
            },
            child: Text(authorized ? '系统设置' : '开启'),
          ),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.alarm_outlined,
            color: controller.alarmPermission == AlarmPermissionState.authorized
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          title: const Text('系统闹铃权限'),
          subtitle: Text(switch (controller.alarmPermission) {
            AlarmPermissionState.authorized => '已允许',
            AlarmPermissionState.denied => '未允许',
            AlarmPermissionState.notDetermined => '尚未请求',
            AlarmPermissionState.unsupported => '需要 iOS 26 或更高版本',
          }),
          trailing:
              controller.alarmPermission == AlarmPermissionState.unsupported
              ? null
              : TextButton(
                  onPressed: () async {
                    if (controller.alarmPermission ==
                            AlarmPermissionState.authorized ||
                        controller.alarmPermission ==
                            AlarmPermissionState.denied) {
                      await controller.openAlarmSettings();
                    } else {
                      await controller.requestAlarmPermission();
                    }
                  },
                  child: Text(
                    controller.alarmPermission ==
                                AlarmPermissionState.authorized ||
                            controller.alarmPermission ==
                                AlarmPermissionState.denied
                        ? '系统设置'
                        : '开启',
                  ),
                ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('闹铃调度状态'),
          subtitle: Text(
            '已调度 ${controller.scheduledAlarmCount} 个 · '
            '未生效 ${controller.inactiveAlarmCount} 个 · '
            '失败 ${controller.failedAlarmCount} 个',
          ),
        ),
        const Divider(),
        _SelectRow(
          label: '新任务默认提醒',
          value: '${controller.preferences.defaultReminderMinutes}',
          values: const {
            '-1': '不自动添加',
            '0': '任务开始时',
            '5': '提前 5 分钟',
            '15': '提前 15 分钟',
            '30': '提前 30 分钟',
            '60': '提前 1 小时',
            '1440': '提前 1 天',
          },
          onChanged: (value) =>
              controller.setPreference('default_reminder_minutes', value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('提醒声音'),
          subtitle: const Text('最终是否响铃仍受静音、专注模式和系统设置影响'),
          value: controller.preferences.reminderSound,
          onChanged: (value) =>
              controller.setPreference('reminder_sound', '$value'),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('调度状态'),
          subtitle: Text(
            '已登记 ${controller.scheduledReminderCount} 个 · '
            '等待 ${controller.waitingReminderCount} 个 · '
            '失败 ${controller.failedReminderCount} 个',
          ),
          trailing: IconButton(
            tooltip: '重新对账',
            onPressed: controller.refreshNotifications,
            icon: const Icon(Icons.refresh),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '计划和任务都可设置多个提醒。通知受静音和专注模式影响；闹铃使用 iOS 26 AlarmKit 并需要独立授权。',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _categoryDetail(BuildContext context) => _Panel(
    title: '分类模板',
    trailing: TextButton(
      onPressed: () => _editCategories(context),
      child: const Text('编辑'),
    ),
    children: [
      if (controller.categoryDefinitions.isEmpty)
        const Text('暂无可选分类。')
      else
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: controller.categoryDefinitions
              .map(
                (category) => Chip(
                  avatar: Icon(category.icon, color: category.color, size: 18),
                  label: Text(category.name),
                ),
              )
              .toList(),
        ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          '分类是新建时的可选模板。改名或删除不会修改已有计划和任务。',
          style: TextStyle(fontSize: 12),
        ),
      ),
    ],
  );

  Widget _progressDetail(BuildContext context) => _Panel(
    title: '进度方案',
    trailing: TextButton(
      onPressed: () => _editProgressTemplates(context),
      child: const Text('编辑'),
    ),
    children: [
      ...controller.progressTemplates.map(
        (template) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(template.name),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: template.nodes
                    .map(
                      (node) => Chip(
                        avatar: CircleAvatar(backgroundColor: node.color),
                        label: Text(
                          '${node.name}${node.kind == ProgressNodeKind.end ? ' ✓' : ''}',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      const Text(
        '每套进度包含一个开始节点、任意中间节点和至少一个结束节点。计划会保存整套快照。',
        style: TextStyle(fontSize: 12),
      ),
    ],
  );

  Widget _tagDetail(BuildContext context) => _Panel(
    title: '标签模板',
    trailing: TextButton(
      onPressed: () => _editTags(context),
      child: const Text('编辑'),
    ),
    children: [
      if (controller.tagDefinitions.isEmpty)
        const Text('暂无可选标签。')
      else
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: controller.tagDefinitions
              .map(
                (tag) => Chip(
                  avatar: Icon(tag.icon, color: tag.color, size: 18),
                  label: Text(tag.name),
                  side: BorderSide(color: tag.color),
                ),
              )
              .toList(),
        ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          '计划可选择多个标签或不选择。名称、颜色和图标都会写入历史快照。',
          style: TextStyle(fontSize: 12),
        ),
      ),
    ],
  );

  Widget _contactDetail(BuildContext context) => _Panel(
    title: '联系人',
    trailing: TextButton(
      onPressed: () => _editContacts(context),
      child: const Text('管理'),
    ),
    children: [
      if (controller.contacts.isEmpty)
        const Text('暂无联系人，可在这里或计划、任务表单中新增。')
      else
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('姓名')),
              DataColumn(label: Text('电话')),
              DataColumn(label: Text('备注')),
            ],
            rows: controller.contacts
                .map(
                  (contact) => DataRow(
                    cells: [
                      DataCell(Text(contact.name)),
                      DataCell(Text(contact.phone)),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            contact.remark,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          '编辑或删除联系人配置不会修改已保存计划和任务中的联系人快照。备注最多 100 个字符。',
          style: TextStyle(fontSize: 12),
        ),
      ),
    ],
  );

  Widget _tableDetail(BuildContext context) => _Panel(
    title: '表格与数据',
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: () => _editColumns(context),
            child: const Text('表格列显示与顺序'),
          ),
          OutlinedButton(
            onPressed: () => _showTable(context),
            child: const Text('查看计划表格'),
          ),
          OutlinedButton.icon(
            onPressed: () => _export(context),
            icon: const Icon(Icons.ios_share),
            label: const Text('导出 XLSX'),
          ),
          OutlinedButton.icon(
            onPressed: () => _import(context),
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('导入 XLSX'),
          ),
        ],
      ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          '支持固定字段模板，文件不超过 10 MB、记录不超过 5000 行。同 ID 差异逐字段确认，默认保留本地。',
          style: TextStyle(fontSize: 12),
        ),
      ),
    ],
  );

  Widget _privacyDetail(BuildContext context) => const _Panel(
    title: '本地数据与隐私',
    children: [
      Text('数据保存在设备 SQLite 数据库中，不连接云端。计划关联只保存 ID，不读取系统通讯录；一致性由应用逻辑维护。'),
    ],
  );

  Widget _helpDetail(BuildContext context) => _Panel(
    title: '支持',
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.menu_book_outlined),
        title: const Text('使用帮助'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _message(context, '使用帮助正在整理中'),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.chat_bubble_outline),
        title: const Text('意见反馈'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _message(context, '意见反馈入口即将开放'),
      ),
      const Text('帮助中心、问题反馈和版本记录将在后续版本接入。', style: TextStyle(fontSize: 12)),
    ],
  );

  Widget _aboutDetail(BuildContext context) => _Panel(
    title: '关于应用',
    children: [
      const Text('离线优先的个人计划应用。联系人均为手动文本，不读取系统通讯录。'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: () => _tips(context),
            child: const Text('赞赏'),
          ),
          OutlinedButton(
            onPressed: () => _rating(context),
            child: const Text('评分'),
          ),
        ],
      ),
    ],
  );

  Future<void> _export(BuildContext context) async {
    try {
      await XlsxService.exportTasks(controller.tasks);
    } catch (exception) {
      if (context.mounted) _message(context, '导出失败：$exception');
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      final result = await XlsxService.pickAndParse(controller.statuses);
      if (result == null || !context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ImportPreview(controller: controller, result: result),
      );
    } catch (exception) {
      if (context.mounted) _message(context, '导入失败：$exception');
    }
  }

  void _message(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _editProgressTemplates(BuildContext context) async =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _ProgressTemplateEditor(controller: controller),
        ),
      );

  Future<void> _editCategories(BuildContext context) async =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _CategoryEditor(controller: controller),
      );

  Future<void> _editTags(BuildContext context) async =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _TagEditor(controller: controller),
      );

  Future<void> _editContacts(BuildContext context) async =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ContactEditor(controller: controller),
      );

  Future<void> _editColumns(BuildContext context) async =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ColumnEditor(controller: controller),
      );

  void _showTable(BuildContext context) {
    final columns = controller.columns
        .where((column) => column.visible)
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .9,
        builder: (context, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '任务表格',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: columns
                        .map((column) => DataColumn(label: Text(column.label)))
                        .toList(),
                    rows: controller.tasks
                        .map(
                          (task) => DataRow(
                            cells: columns
                                .map(
                                  (column) => DataCell(
                                    Text(_field(task, column.keyName)),
                                  ),
                                )
                                .toList(),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _field(TaskItem task, String key) => switch (key) {
    'id' => task.id,
    'title' => task.title,
    'description' => task.description,
    'type' => task.type,
    'contact' => task.contact,
    'status' => task.statusId,
    'tags' => task.tags.join('，'),
    'startDate' => task.startDate,
    'startTime' => task.startTime,
    'reminderEnabled' => task.reminderEnabled ? 'true' : 'false',
    'reminders' =>
      task.reminders
          .map((item) => '${item.deliveryLabel}·${item.label}')
          .join('；'),
    'reason' => task.reason,
    'completedAt' => task.completedAt?.toIso8601String() ?? '',
    'originId' => task.originId ?? '',
    'parentTaskId' => task.parentTaskId ?? '',
    'updatedAt' => task.updatedAt.toIso8601String(),
    _ => '',
  };

  void _tips(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('让好用的工具慢慢长大'),
      content: const Text('赞赏功能即将开放。'),
      actions: [
        for (final amount in [6, 12, 30])
          TextButton(
            onPressed: () => _message(context, '赞赏功能即将开放'),
            child: Text('¥$amount'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );

  void _rating(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('使用感受'),
      content: const Text('App Store 评分功能即将开放。'),
      actions: [
        for (var star = 1; star <= 5; star++)
          TextButton(
            onPressed: () => _message(context, '评分功能即将开放'),
            child: Text('$star ★'),
          ),
      ],
    ),
  );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 9),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1)
                  const Divider(height: 1, indent: 70),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingsMenuItem extends StatelessWidget {
  const _SettingsMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      minTileHeight: 76,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: colors.primary, size: 23),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Icon(Icons.chevron_right, color: colors.primary),
      onTap: onTap,
    );
  }
}

class _SettingsDetailPage extends StatelessWidget {
  const _SettingsDetailPage({
    required this.title,
    required this.controller,
    required this.contentBuilder,
  });

  final String title;
  final AppController controller;
  final Widget Function(BuildContext) contentBuilder;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 36),
        children: [contentBuilder(context)],
      ),
    ),
  );
}

class _CalendarDensityEditor extends StatefulWidget {
  const _CalendarDensityEditor({required this.controller});

  final AppController controller;

  @override
  State<_CalendarDensityEditor> createState() => _CalendarDensityEditorState();
}

class _CalendarDensityEditorState extends State<_CalendarDensityEditor> {
  late final TextEditingController smallController;
  late final TextEditingController mediumController;
  late final TextEditingController largeController;
  bool isEditing = false;
  bool showErrors = false;

  @override
  void initState() {
    super.initState();
    final preferences = widget.controller.preferences;
    smallController = TextEditingController(
      text: _numberText(preferences.calendarSmallHeight),
    );
    mediumController = TextEditingController(
      text: _numberText(preferences.calendarMediumHeight),
    );
    largeController = TextEditingController(
      text: _numberText(preferences.calendarLargeHeight),
    );
  }

  @override
  void dispose() {
    smallController.dispose();
    mediumController.dispose();
    largeController.dispose();
    super.dispose();
  }

  static String _numberText(double value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value';

  String? _error(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim());
    if (value == null) return '请输入数字';
    if (value < AppPreferences.minimumCalendarRowHeight ||
        value > AppPreferences.maximumCalendarRowHeight) {
      return '请输入 62–360';
    }
    return null;
  }

  String _hint(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim());
    if (value == null ||
        value < AppPreferences.minimumCalendarRowHeight ||
        value > AppPreferences.maximumCalendarRowHeight) {
      return '输入有效高度后显示预计条数';
    }
    final count = AppPreferences.estimatedCalendarItemCount(value);
    return '大约显示 $count 条计划';
  }

  @override
  Widget build(BuildContext context) => _Panel(
    title: '日历间距',
    trailing: TextButton(
      onPressed: isEditing ? _save : _startEditing,
      child: Text(isEditing ? '保存' : '编辑'),
    ),
    children: [
      const Text(
        '分别设置小、中、大三个档位的日期格高度。档位数值不要求按大小排序。允许范围为 62–360 逻辑像素。',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 12),
      _heightField('小', smallController),
      _heightField('中', mediumController),
      _heightField('大', largeController),
    ],
  );

  Widget _heightField(String label, TextEditingController controller) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(label),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                readOnly: !isEditing,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '日期格高度',
                  helperText: _hint(controller),
                  errorText: showErrors ? _error(controller) : null,
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> _save() async {
    final controllers = [smallController, mediumController, largeController];
    if (controllers.any((controller) => _error(controller) != null)) {
      setState(() => showErrors = true);
      return;
    }
    await widget.controller.saveCalendarDensityHeights(
      small: double.parse(smallController.text.trim()),
      medium: double.parse(mediumController.text.trim()),
      large: double.parse(largeController.text.trim()),
    );
    if (!mounted) return;
    setState(() {
      isEditing = false;
      showErrors = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('日历间距已保存')));
  }

  void _startEditing() {
    final preferences = widget.controller.preferences;
    smallController.text = _numberText(preferences.calendarSmallHeight);
    mediumController.text = _numberText(preferences.calendarMediumHeight);
    largeController.text = _numberText(preferences.calendarLargeHeight);
    setState(() {
      isEditing = true;
      showErrors = false;
    });
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children, this.trailing});
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
}

class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });
  final String label;
  final String value;
  final Map<String, String> values;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        DropdownButton<String>(
          value: value,
          items: values.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: (next) => onChanged(next!),
        ),
      ],
    ),
  );
}

class _ContactEditor extends StatelessWidget {
  const _ContactEditor({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .82,
    builder: (context, scroll) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '联系人',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Text('${controller.contacts.length} 个'),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Text(
            '在此统一新增、编辑和删除联系人。历史计划和任务保存独立快照，不随配置变化。',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (controller.contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('还没有联系人')),
            ),
          ...controller.contacts.map(
            (contact) => Card(
              key: ValueKey(contact.id),
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(contact.name),
                subtitle: Text(
                  [
                    contact.phone,
                    contact.remark,
                  ].where((value) => value.isNotEmpty).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '编辑联系人',
                      onPressed: () => showContactEditorDialog(
                        context,
                        controller,
                        contact: contact,
                      ),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: '删除联系人',
                      onPressed: () => _delete(context, contact),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => showContactEditorDialog(context, controller),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('新增联系人'),
          ),
        ],
      ),
    ),
  );

  Future<void> _delete(BuildContext context, ContactEntry contact) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('删除“${contact.name}”联系人？'),
            content: const Text('该联系人将不再出现在后续选择列表中；已保存计划和任务中的姓名、电话、备注保持不变。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await controller.deleteContact(contact.id);
  }
}

class _CategoryEditor extends StatelessWidget {
  const _CategoryEditor({required this.controller});
  final AppController controller;

  static const colors = [
    0xff8e8e93,
    0xffff383c,
    0xffff8d28,
    0xffffcc00,
    0xff34c759,
    0xff00c7be,
    0xff30b0c7,
    0xff32ade6,
    0xff007aff,
    0xff6155f5,
    0xffcb30e0,
    0xffff2d55,
  ];

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .82,
    builder: (context, scroll) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '分类',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Text(
                '${controller.categoryDefinitions.length}/$maxCategoryDefinitionCount',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Text(
            '分类定义仅用于以后选择；已有计划和任务保存独立快照。',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 10),
          ...controller.categoryDefinitions.map(
            (category) => Card(
              child: ListTile(
                leading: Icon(category.icon, color: category.color),
                title: Text(category.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '编辑分类',
                      onPressed: () => _edit(context, category),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: '删除分类',
                      onPressed: () =>
                          controller.deleteCategoryDefinition(category.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
          FilledButton.icon(
            onPressed:
                controller.categoryDefinitions.length >=
                    maxCategoryDefinitionCount
                ? null
                : () => _edit(
                    context,
                    CategoryDefinition(
                      id: 'category-${DateTime.now().microsecondsSinceEpoch}',
                      name: '新分类',
                      colorValue: colors.first,
                      iconName: taskTagIconChoices.keys.first,
                      sortOrder: controller.categoryDefinitions.length,
                    ),
                  ),
            icon: const Icon(Icons.add),
            label: const Text('添加分类'),
          ),
        ],
      ),
    ),
  );

  Future<void> _edit(BuildContext context, CategoryDefinition original) async {
    final name = TextEditingController(text: original.name);
    var color = original.colorValue;
    var iconName = original.iconName;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('编辑分类'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: name,
                  maxLength: maxCategoryNameLength,
                  decoration: const InputDecoration(
                    labelText: '分类名称',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('颜色'),
                GridView.count(
                  crossAxisCount: 6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: colors
                      .map(
                        (value) => IconButton(
                          onPressed: () => setLocalState(() => color = value),
                          icon: Icon(
                            color == value
                                ? Icons.radio_button_checked
                                : Icons.circle,
                            color: Color(value),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const Text('图标'),
                GridView.count(
                  crossAxisCount: 6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: taskTagIconChoices.entries
                      .map(
                        (entry) => IconButton(
                          onPressed: () =>
                              setLocalState(() => iconName = entry.key),
                          icon: Icon(
                            entry.value,
                            color: iconName == entry.key ? Color(color) : null,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      try {
        await controller.saveCategoryDefinition(
          original.copyWith(
            name: name.text,
            colorValue: color,
            iconName: iconName,
          ),
        );
      } catch (exception) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                exception.toString().replaceFirst('Bad state: ', ''),
              ),
            ),
          );
        }
      }
    }
    name.dispose();
  }
}

class _ProgressTemplateEditor extends StatelessWidget {
  const _ProgressTemplateEditor({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('进度方案'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.route_outlined),
                SizedBox(width: 12),
                Expanded(child: Text('为不同类型的计划设置专属流程。每套方案需要一个开始节点和至少一个结束节点。')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '全部方案 ${controller.progressTemplates.length}/$maxProgressTemplateCount',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...controller.progressTemplates.map(
            (template) => _ProgressTemplateCard(
              template: template,
              onEdit: () => _openTemplate(context, template),
              onDelete: () async {
                final deleted = await controller.deleteProgressTemplate(
                  template.id,
                );
                if (!deleted && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('至少保留一套进度方案。')));
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '删除方案不会影响已保存的任务与计划。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        child: FilledButton.icon(
          onPressed:
              controller.progressTemplates.length >= maxProgressTemplateCount
              ? null
              : () => _openTemplate(context, _newTemplate()),
          icon: const Icon(Icons.add),
          label: const Text('添加进度方案'),
        ),
      ),
    ),
  );

  ProgressTemplate _newTemplate() {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return ProgressTemplate(
      id: 'progress-$stamp',
      name: '新进度',
      sortOrder: controller.progressTemplates.length,
      nodes: [
        ProgressNode(
          id: 'progress-$stamp-start',
          name: '未开始',
          colorValue: 0xff8e8e93,
          kind: ProgressNodeKind.start,
          sortOrder: 0,
        ),
        ProgressNode(
          id: 'progress-$stamp-end',
          name: '已完成',
          colorValue: 0xff34c759,
          kind: ProgressNodeKind.end,
          sortOrder: 1,
        ),
      ],
    );
  }

  Future<void> _openTemplate(BuildContext context, ProgressTemplate template) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              _ProgressTemplateForm(controller: controller, template: template),
        ),
      );
}

class _ProgressTemplateCard extends StatelessWidget {
  const _ProgressTemplateCard({
    required this.template,
    required this.onEdit,
    required this.onDelete,
  });

  final ProgressTemplate template;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.route_outlined, color: colors.secondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${template.nodes.length} 个节点',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '编辑进度方案',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: '删除进度方案',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (
                      var index = 0;
                      index < template.nodes.length;
                      index++
                    ) ...[
                      _ProgressNodeLabel(node: template.nodes[index]),
                      if (index < template.nodes.length - 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 17,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressNodeLabel extends StatelessWidget {
  const _ProgressNodeLabel({required this.node});

  final ProgressNode node;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: node.color.withAlpha(24),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: node.color.withAlpha(90)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: node.color, size: 9),
        const SizedBox(width: 6),
        Text(node.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _ProgressTemplateForm extends StatefulWidget {
  const _ProgressTemplateForm({
    required this.controller,
    required this.template,
  });
  final AppController controller;
  final ProgressTemplate template;

  @override
  State<_ProgressTemplateForm> createState() => _ProgressTemplateFormState();
}

class _ProgressTemplateFormState extends State<_ProgressTemplateForm> {
  late final TextEditingController name;
  late List<ProgressNode> nodes;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.template.name);
    nodes = [...widget.template.nodes];
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('编辑进度方案'), centerTitle: true),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        Text(
          '基本信息',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: name,
          maxLength: maxProgressTemplateNameLength,
          decoration: const InputDecoration(labelText: '方案名称', counterText: ''),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                '节点流程',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text('${nodes.length}/$maxProgressNodeCount'),
          ],
        ),
        const SizedBox(height: 4),
        Text('中间节点会自动添加到结束节点之前。', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 10),
        ...nodes.asMap().entries.map((entry) {
          final index = entry.key;
          final node = entry.value;
          return Card(
            key: ValueKey(node.id),
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle, color: node.color, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '节点 ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<ProgressNodeKind>(
                          value: node.kind,
                          borderRadius: BorderRadius.circular(12),
                          items: const [
                            DropdownMenuItem(
                              value: ProgressNodeKind.start,
                              child: Text('开始'),
                            ),
                            DropdownMenuItem(
                              value: ProgressNodeKind.middle,
                              child: Text('中间'),
                            ),
                            DropdownMenuItem(
                              value: ProgressNodeKind.end,
                              child: Text('结束'),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => nodes[index] = node.copyWith(kind: value),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '删除节点',
                        onPressed: nodes.length <= 2
                            ? null
                            : () => setState(() => nodes.removeAt(index)),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: node.name,
                    maxLength: maxProgressNodeNameLength,
                    decoration: const InputDecoration(
                      labelText: '节点名称',
                      counterText: '',
                    ),
                    onChanged: (value) =>
                        nodes[index] = node.copyWith(name: value),
                  ),
                ],
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: nodes.length >= maxProgressNodeCount
              ? null
              : () => setState(() {
                  final stamp = DateTime.now().microsecondsSinceEpoch;
                  final firstEndIndex = nodes.indexWhere(
                    (node) => node.kind == ProgressNodeKind.end,
                  );
                  final insertionIndex = firstEndIndex == -1
                      ? nodes.length
                      : firstEndIndex;
                  nodes.insert(
                    insertionIndex,
                    ProgressNode(
                      id: '${widget.template.id}-node-$stamp',
                      name: '新节点',
                      colorValue: 0xff007aff,
                      kind: ProgressNodeKind.middle,
                      sortOrder: insertionIndex,
                    ),
                  );
                }),
          icon: const Icon(Icons.add),
          label: const Text('添加中间节点'),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      child: FilledButton(
        onPressed: () async {
          try {
            await widget.controller.saveProgressTemplate(
              widget.template.copyWith(
                name: name.text,
                nodes: nodes
                    .asMap()
                    .entries
                    .map((entry) => entry.value.copyWith(sortOrder: entry.key))
                    .toList(),
              ),
            );
            if (context.mounted) Navigator.pop(context);
          } catch (exception) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    exception.toString().replaceFirst('Bad state: ', ''),
                  ),
                ),
              );
            }
          }
        },
        child: const Text('保存方案'),
      ),
    ),
  );
}

class _StatusEditor extends StatefulWidget {
  const _StatusEditor({required this.controller});
  final AppController controller;
  @override
  State<_StatusEditor> createState() => _StatusEditorState();
}

class _StatusEditorState extends State<_StatusEditor> {
  static const colors = [
    0xff8c91a3,
    0xff497fc4,
    0xffc28a35,
    0xff3f9875,
    0xffde583f,
    0xff8f63c7,
  ];
  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .78,
    builder: (context, scroll) => ListView(
      controller: scroll,
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '进度',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        ...widget.controller.statuses.map(
          (status) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: status.name,
                    decoration: const InputDecoration(labelText: '名称'),
                    onFieldSubmitted: (name) => widget.controller.saveStatus(
                      status.copyWith(
                        name: name.trim().isEmpty ? status.name : name.trim(),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Text('颜色'),
                      const SizedBox(width: 8),
                      ...colors.map(
                        (value) => IconButton(
                          onPressed: () => widget.controller.saveStatus(
                            status.copyWith(colorValue: value),
                          ),
                          icon: Icon(
                            status.colorValue == value
                                ? Icons.radio_button_checked
                                : Icons.circle,
                            color: Color(value),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('视为已完成'),
                          value: status.completed,
                          onChanged: (value) => widget.controller.saveStatus(
                            status.copyWith(completed: value),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '删除状态',
                        onPressed: () async {
                          final deleted = await widget.controller.deleteStatus(
                            status.id,
                          );
                          if (!deleted && context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('正在使用的状态或最后一个状态不能删除。'),
                              ),
                            );
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: () {
            final id = 'status-${DateTime.now().microsecondsSinceEpoch}';
            widget.controller.saveStatus(
              TaskStatus(
                id: id,
                name: '新状态',
                colorValue: colors.first,
                completed: false,
                sortOrder: widget.controller.statuses.length,
              ),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('添加状态'),
        ),
      ],
    ),
  );
}

class _TagEditor extends StatefulWidget {
  const _TagEditor({required this.controller});

  final AppController controller;

  @override
  State<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<_TagEditor> {
  final Set<String> _editingTagIds = {};
  final Map<String, String> _draftTagNames = {};

  static const colors = [
    0xff8e8e93,
    0xffff383c,
    0xffff8d28,
    0xffffcc00,
    0xff34c759,
    0xff00c7be,
    0xff30b0c7,
    0xff32ade6,
    0xff007aff,
    0xff6155f5,
    0xffcb30e0,
    0xffff2d55,
  ];

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .9,
    builder: (context, scroll) => AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '标签',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Text(
                '${widget.controller.tagDefinitions.length}/$maxTagDefinitionCount',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (widget.controller.tagDefinitions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('还没有可选标签')),
            ),
          ...widget.controller.tagDefinitions.map(
            (tag) => Card(
              key: ValueKey(tag.id),
              child: _editingTagIds.contains(tag.id)
                  ? _buildEditor(context, tag)
                  : _buildSummary(context, tag),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed:
                widget.controller.tagDefinitions.length >= maxTagDefinitionCount
                ? null
                : () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('添加标签'),
          ),
        ],
      ),
    ),
  );

  Widget _buildSummary(BuildContext context, TaskTagDefinition tag) => ListTile(
    leading: Icon(tag.icon, color: tag.color),
    title: Text(tag.name),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '编辑标签',
          onPressed: () => setState(() {
            _editingTagIds.add(tag.id);
            _draftTagNames[tag.id] = tag.name;
          }),
          icon: const Icon(Icons.edit_outlined),
        ),
        if (!tag.isQuadrant)
          IconButton(
            tooltip: '删除标签配置',
            onPressed: () => _delete(context, tag),
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    ),
  );

  Widget _buildEditor(BuildContext context, TaskTagDefinition tag) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(tag.icon, color: tag.color),
            const SizedBox(width: 10),
            Expanded(
              child: tag.isQuadrant
                  ? InputDecorator(
                      decoration: const InputDecoration(labelText: '标签名称'),
                      child: Row(
                        children: [
                          Expanded(child: Text(tag.name)),
                          const Icon(Icons.lock_outline, size: 18),
                        ],
                      ),
                    )
                  : TextFormField(
                      key: ValueKey('${tag.id}-${tag.name}'),
                      initialValue: tag.name,
                      maxLength: maxTagNameLength,
                      decoration: const InputDecoration(
                        labelText: '标签名称',
                        counterText: '',
                      ),
                      onChanged: (name) => _draftTagNames[tag.id] = name,
                      onFieldSubmitted: (name) =>
                          _submitName(context, tag, name),
                    ),
            ),
            if (!tag.isQuadrant)
              IconButton(
                tooltip: '删除标签配置',
                onPressed: () => _delete(context, tag),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        const SizedBox(height: 10),
        const Text('颜色'),
        GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          children: colors
              .map(
                (value) => IconButton(
                  tooltip: '选择颜色',
                  onPressed: () =>
                      _save(context, tag.copyWith(colorValue: value)),
                  icon: Icon(
                    tag.colorValue == value
                        ? Icons.radio_button_checked
                        : Icons.circle,
                    color: Color(value),
                    size: 21,
                  ),
                ),
              )
              .toList(),
        ),
        const Text('图标'),
        GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          children: taskTagIconChoices.entries
              .map(
                (entry) => IconButton(
                  tooltip: entry.key,
                  onPressed: () =>
                      _save(context, tag.copyWith(iconName: entry.key)),
                  icon: Icon(
                    entry.value,
                    color: tag.iconName == entry.key ? tag.color : null,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );

  Future<bool> _save(BuildContext context, TaskTagDefinition tag) async {
    try {
      await widget.controller.saveTagDefinition(tag);
      return true;
    } catch (exception) {
      if (context.mounted) _message(context, exception);
      return false;
    }
  }

  Future<void> _add(BuildContext context) async {
    final editingTags = widget.controller.tagDefinitions
        .where((tag) => _editingTagIds.contains(tag.id))
        .toList();
    for (final tag in editingTags) {
      final saved = await _save(
        context,
        tag.copyWith(name: _draftTagNames[tag.id] ?? tag.name),
      );
      if (!saved) return;
    }

    var suffix = 1;
    var name = '新标签';
    final names = widget.controller.tagDefinitions
        .map((tag) => tag.name.toLowerCase())
        .toSet();
    while (names.contains(name.toLowerCase())) {
      suffix++;
      name = '新标签 $suffix';
    }
    final tag = TaskTagDefinition(
      id: 'tag-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      colorValue: colors.first,
      iconName: taskTagIconChoices.keys.first,
      sortOrder: widget.controller.tagDefinitions.length,
    );
    final saved = await _save(context, tag);
    if (!saved || !mounted) return;
    setState(() {
      _editingTagIds
        ..clear()
        ..add(tag.id);
      _draftTagNames
        ..clear()
        ..[tag.id] = tag.name;
    });
  }

  Future<void> _submitName(
    BuildContext context,
    TaskTagDefinition tag,
    String name,
  ) async {
    final saved = await _save(context, tag.copyWith(name: name));
    if (!saved || !mounted) return;
    setState(() {
      _editingTagIds.remove(tag.id);
      _draftTagNames.remove(tag.id);
    });
  }

  Future<void> _delete(BuildContext context, TaskTagDefinition tag) async {
    if (tag.isQuadrant) {
      _message(context, StateError('四象限默认标签不能删除。'));
      return;
    }
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('删除“${tag.name}”标签配置？'),
            content: const Text('历史任务中已经保存的标签名称会继续保留，并显示为历史标签。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除配置'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await widget.controller.deleteTagDefinition(tag.id);
    if (mounted)
      setState(() {
        _editingTagIds.remove(tag.id);
        _draftTagNames.remove(tag.id);
      });
  }

  void _message(BuildContext context, Object exception) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exception.toString().replaceFirst('Bad state: ', '')),
        ),
      );
}

class _ColumnEditor extends StatefulWidget {
  const _ColumnEditor({required this.controller});
  final AppController controller;
  @override
  State<_ColumnEditor> createState() => _ColumnEditorState();
}

class _ColumnEditorState extends State<_ColumnEditor> {
  late List<ColumnPreference> columns;
  @override
  void initState() {
    super.initState();
    columns = [...widget.controller.columns];
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .85,
    builder: (context, scroll) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '表格列显示与顺序',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton(
                onPressed: () async {
                  await widget.controller.saveColumns(columns);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            scrollController: scroll,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: columns.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = columns.removeAt(oldIndex);
                columns.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final column = columns[index];
              return SwitchListTile(
                key: ValueKey(column.keyName),
                secondary: const Icon(Icons.drag_handle),
                title: Text(column.label),
                subtitle: Text(column.keyName),
                value: column.visible,
                onChanged: (value) => setState(
                  () => columns[index] = column.copyWith(visible: value),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _ImportPreview extends StatefulWidget {
  const _ImportPreview({required this.controller, required this.result});
  final AppController controller;
  final ImportResult result;
  @override
  State<_ImportPreview> createState() => _ImportPreviewState();
}

class _ImportPreviewState extends State<_ImportPreview> {
  final selectedFields = <String, Set<String>>{};
  bool importing = false;
  static const fields = [
    'title',
    'description',
    'type',
    'contact',
    'status',
    'tags',
    'startDate',
    'startTime',
    'reminderEnabled',
    'reminders',
    'reason',
    'completedAt',
    'originId',
    'parentTaskId',
  ];

  @override
  Widget build(BuildContext context) {
    final incoming = widget.result.tasks;
    final conflicts = incoming
        .where((task) => widget.controller.taskById(task.id) != null)
        .toList();
    final additions = incoming
        .where((task) => widget.controller.taskById(task.id) == null)
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '导入预览',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                Text(
                  '新增 ${additions.length} 项 · 冲突 ${conflicts.length} 项 · 警告 ${widget.result.warnings.length} 条',
                ),
                if (widget.result.warnings.isNotEmpty)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(widget.result.warnings.join('\n')),
                    ),
                  ),
                if (additions.isNotEmpty)
                  ExpansionTile(
                    title: Text('新增任务（${additions.length}）'),
                    children: additions
                        .map(
                          (task) => ListTile(
                            title: Text(task.title),
                            subtitle: Text(task.id),
                          ),
                        )
                        .toList(),
                  ),
                ...conflicts.map((remote) {
                  final local = widget.controller.taskById(remote.id)!;
                  final changed = fields
                      .where(
                        (field) =>
                            _value(local, field) != _value(remote, field),
                      )
                      .toList();
                  final selected = selectedFields.putIfAbsent(
                    remote.id,
                    () => <String>{},
                  );
                  return ExpansionTile(
                    title: Text(remote.title),
                    subtitle: Text('${changed.length} 个字段不同；默认保留本地'),
                    children: changed
                        .map(
                          (field) => CheckboxListTile(
                            value: selected.contains(field),
                            onChanged: (value) => setState(
                              () => value!
                                  ? selected.add(field)
                                  : selected.remove(field),
                            ),
                            title: Text(_label(field)),
                            subtitle: Text(
                              '本地：${_value(local, field)}\n导入：${_value(remote, field)}',
                            ),
                          ),
                        )
                        .toList(),
                  );
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: importing ? null : _confirm,
                child: Text(importing ? '导入中…' : '确认导入'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() => importing = true);
    try {
      final merged = <TaskItem>[];
      for (final remote in widget.result.tasks) {
        final local = widget.controller.taskById(remote.id);
        merged.add(
          local == null
              ? remote
              : _merge(local, remote, selectedFields[remote.id] ?? const {}),
        );
      }
      await widget.controller.importTasks(
        merged,
        merged.map((task) => task.id).toSet(),
      );
      if (mounted) Navigator.pop(context);
    } catch (exception) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败：$exception')));
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  TaskItem _merge(
    TaskItem local,
    TaskItem remote,
    Set<String> selected,
  ) => TaskItem(
    id: local.id,
    title: selected.contains('title') ? remote.title : local.title,
    description: selected.contains('description')
        ? remote.description
        : local.description,
    type: selected.contains('type') ? remote.type : local.type,
    contact: selected.contains('contact') ? remote.contact : local.contact,
    statusId: selected.contains('status') ? remote.statusId : local.statusId,
    tags: selected.contains('tags') ? remote.tags : local.tags,
    startDate: selected.contains('startDate')
        ? remote.startDate
        : local.startDate,
    startTime: selected.contains('startTime')
        ? remote.startTime
        : local.startTime,
    reason: selected.contains('reason') ? remote.reason : local.reason,
    completedAt: selected.contains('completedAt')
        ? remote.completedAt
        : local.completedAt,
    originId: selected.contains('originId') ? remote.originId : local.originId,
    parentTaskId: selected.contains('parentTaskId')
        ? remote.parentTaskId
        : local.parentTaskId,
    updatedAt: DateTime.now(),
    sourceCategoryId: selected.contains('type') ? null : local.sourceCategoryId,
    categoryColorValue: local.categoryColorValue,
    categoryIconName: local.categoryIconName,
    tagSnapshots: selected.contains('tags') ? const [] : local.tagSnapshots,
    progress: local.progress,
    planId: local.planId,
    recurrenceRuleId: local.recurrenceRuleId,
    occurrenceDate: local.occurrenceDate,
    detachedFromRule: local.detachedFromRule || local.recurrenceRuleId != null,
    reminderEnabled: selected.contains('reminderEnabled')
        ? remote.reminderEnabled
        : local.reminderEnabled,
    reminders: selected.contains('reminders')
        ? remote.reminders
        : local.reminders,
    followups: local.followups,
    history: local.history,
  );

  String _value(TaskItem task, String field) => switch (field) {
    'title' => task.title,
    'description' => task.description,
    'type' => task.type,
    'contact' => task.contact,
    'status' => task.statusId,
    'tags' => task.tags.join('，'),
    'startDate' => task.startDate,
    'startTime' => task.startTime,
    'reminderEnabled' => task.reminderEnabled ? 'true' : 'false',
    'reminders' =>
      task.reminders
          .map((item) => '${item.deliveryLabel}·${item.label}')
          .join('；'),
    'reason' => task.reason,
    'completedAt' => task.completedAt?.toIso8601String() ?? '',
    'originId' => task.originId ?? '',
    'parentTaskId' => task.parentTaskId ?? '',
    _ => '',
  };

  String _label(String field) => XlsxService.headers[field] ?? field;
}
