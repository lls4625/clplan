import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final root = await getDatabasesPath();
    return openDatabase(
      p.join(root, 'clplan.sqlite3'),
      version: 13,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = OFF');
        await db.setJournalMode('WAL');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE task_statuses (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color_value INTEGER NOT NULL,
            completed INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            type TEXT NOT NULL DEFAULT '',
            contact TEXT NOT NULL DEFAULT '',
            status_id TEXT NOT NULL,
            start_date TEXT NOT NULL DEFAULT '',
            start_time TEXT NOT NULL DEFAULT '',
            reason TEXT NOT NULL DEFAULT '',
            completed_at TEXT,
            origin_id TEXT,
            parent_task_id TEXT,
            source_category_id TEXT,
            category_color_value INTEGER NOT NULL DEFAULT 4287532691,
            category_icon_name TEXT NOT NULL DEFAULT 'project',
            plan_id TEXT,
            recurrence_rule_id TEXT,
            occurrence_date TEXT,
            detached_from_rule INTEGER NOT NULL DEFAULT 0,
            reminder_enabled INTEGER NOT NULL DEFAULT 0,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX tasks_start_date_idx ON tasks(start_date)',
        );
        await db.execute('CREATE INDEX tasks_status_idx ON tasks(status_id)');
        await db.execute(
          'CREATE INDEX tasks_parent_idx ON tasks(parent_task_id)',
        );
        await db.execute('''
          CREATE TABLE task_tags (
            task_id TEXT NOT NULL,
            tag TEXT NOT NULL,
            source_tag_id TEXT,
            color_value INTEGER NOT NULL DEFAULT 4287532691,
            icon_name TEXT NOT NULL DEFAULT 'label',
            sort_order INTEGER NOT NULL,
            PRIMARY KEY (task_id, tag)
          )
        ''');
        await _createContactTables(db);
        await db.execute('''
          CREATE TABLE tag_definitions (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL COLLATE NOCASE UNIQUE,
            color_value INTEGER NOT NULL,
            icon_name TEXT NOT NULL,
            sort_order INTEGER NOT NULL
          )
        ''');
        await _seedQuadrantTags(db);
        await db.execute('''
          CREATE TABLE task_followups (
            id TEXT PRIMARY KEY,
            task_id TEXT NOT NULL,
            created_at TEXT NOT NULL,
            content TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX followups_task_idx ON task_followups(task_id)',
        );
        await db.execute('''
          CREATE TABLE task_history (
            id TEXT PRIMARY KEY,
            task_id TEXT NOT NULL,
            created_at TEXT NOT NULL,
            content TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX history_task_idx ON task_history(task_id)',
        );
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE table_columns (
            key_name TEXT PRIMARY KEY,
            label TEXT NOT NULL,
            visible INTEGER NOT NULL DEFAULT 1,
            sort_order INTEGER NOT NULL
          )
        ''');
        await _seed(db);
        await _createProductTables(db);
        await _createReminderTables(db);
        await _seedStarterDefinitions(db);
        await _bootstrapProductData(db);
        await _migrateLegacyContacts(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE tasks ADD COLUMN parent_task_id TEXT');
          await db.execute(
            'CREATE INDEX tasks_parent_idx ON tasks(parent_task_id)',
          );
        }
        if (oldVersion < 3) {
          await db.insert('table_columns', {
            'key_name': 'parentTaskId',
            'label': '主任务 ID',
            'visible': 1,
            'sort_order': 13,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE tag_definitions (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL COLLATE NOCASE UNIQUE,
              color_value INTEGER NOT NULL,
              icon_name TEXT NOT NULL,
              sort_order INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 5) {
          await _upgradeToVersion5(db);
          await db.update(
            'table_columns',
            {'label': '分类'},
            where: 'key_name = ?',
            whereArgs: ['type'],
          );
        }
        if (oldVersion < 6) {
          await _createContactTables(db);
          await _migrateLegacyContacts(db);
        }
        if (oldVersion < 7) {
          await db.execute(
            'ALTER TABLE tasks ADD COLUMN reminder_enabled INTEGER NOT NULL DEFAULT 0',
          );
          await _createReminderTables(db);
          await db.insert('table_columns', {
            'key_name': 'reminderEnabled',
            'label': '启用提醒',
            'visible': 1,
            'sort_order': 14,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          await db.insert('table_columns', {
            'key_name': 'reminders',
            'label': '提醒规则',
            'visible': 1,
            'sort_order': 15,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        if (oldVersion < 8) {
          await _seedQuadrantTags(db);
        }
        if (oldVersion < 9) {
          await _addColumnIfMissing(
            db,
            'plans',
            'calendar_display_mode',
            "TEXT NOT NULL DEFAULT 'whole_period'",
          );
          await _addColumnIfMissing(
            db,
            'plans',
            'reminder_enabled',
            'INTEGER NOT NULL DEFAULT 0',
          );
          await _addColumnIfMissing(
            db,
            'task_reminder_rules',
            'delivery_type',
            "TEXT NOT NULL DEFAULT 'notification'",
          );
          await _createPlanReminderTables(db);
          await _createAlarmTables(db);
        }
        if (oldVersion < 10) {
          await _createContactTables(db);
        }
        if (oldVersion < 12) {
          await db.update(
            'table_columns',
            {'visible': 0},
            where: 'key_name IN (?, ?)',
            whereArgs: ['id', 'status'],
          );
        }
        if (oldVersion < 13) {
          await _addColumnIfMissing(db, 'plans', 'completed_at', 'TEXT');
        }
      },
    );
  }

  Future<void> _seedQuadrantTags(DatabaseExecutor db) async {
    final existing = await db.query('tag_definitions');
    for (final row in existing) {
      final name = row['name']! as String;
      if (quadrantTagNames.contains(name)) continue;
      await db.update(
        'tag_definitions',
        {'sort_order': (row['sort_order']! as int) + 4},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    for (final tag in defaultQuadrantTags) {
      final matching = await db.query(
        'tag_definitions',
        where: 'name = ? COLLATE NOCASE',
        whereArgs: [tag.name],
        limit: 1,
      );
      if (matching.isEmpty) {
        await db.insert('tag_definitions', tag.toMap());
      } else {
        await db.update(
          'tag_definitions',
          {'name': tag.name, 'sort_order': tag.sortOrder},
          where: 'id = ?',
          whereArgs: [matching.first['id']],
        );
      }
      final saved = await db.query(
        'tag_definitions',
        columns: ['id'],
        where: 'name = ? COLLATE NOCASE',
        whereArgs: [tag.name],
        limit: 1,
      );
      if (saved.isNotEmpty) {
        await db.update(
          'task_tags',
          {'source_tag_id': saved.first['id']},
          where: 'tag = ? COLLATE NOCASE',
          whereArgs: [tag.name],
        );
      }
    }
  }

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (columns.any((item) => item['name'] == column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<void> _seedStarterDefinitions(DatabaseExecutor db) async {
    for (final category in defaultCategoryDefinitions) {
      await db.insert('category_definitions', category.toMap());
    }
    for (final tag in defaultOrdinaryTags) {
      await db.insert('tag_definitions', tag.toMap());
    }
    for (final template in defaultProgressTemplates) {
      await db.insert('progress_templates', {
        'id': template.id,
        'name': template.name,
        'sort_order': template.sortOrder,
      });
      for (final node in template.nodes) {
        await db.insert('progress_template_nodes', {
          'id': node.id,
          'template_id': template.id,
          'name': node.name,
          'color_value': node.colorValue,
          'kind': node.kind.name,
          'sort_order': node.sortOrder,
        });
      }
    }
  }

  Future<void> _createContactTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contacts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        remark TEXT NOT NULL DEFAULT '',
        UNIQUE(name, phone)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS task_contacts (
        task_id TEXT NOT NULL,
        contact_id TEXT NOT NULL,
        name TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        remark TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL,
        PRIMARY KEY (task_id, contact_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS task_contacts_task_idx ON task_contacts(task_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plan_contacts (
        plan_id TEXT NOT NULL,
        contact_id TEXT NOT NULL,
        name TEXT NOT NULL DEFAULT '',
        phone TEXT NOT NULL DEFAULT '',
        remark TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL,
        PRIMARY KEY (plan_id, contact_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS plan_contacts_plan_idx ON plan_contacts(plan_id)',
    );
  }

  Future<void> _migrateLegacyContacts(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      "SELECT id, contact FROM tasks WHERE TRIM(contact) <> ''",
    );
    for (final row in rows) {
      final name = row['contact']! as String;
      final contactId = 'contact-${name.hashCode.abs()}';
      await db.insert('contacts', {
        'id': contactId,
        'name': name,
        'phone': '',
        'remark': '',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final saved = await db.query(
        'contacts',
        columns: ['id'],
        where: 'name = ? AND phone = ?',
        whereArgs: [name, ''],
        limit: 1,
      );
      if (saved.isEmpty) continue;
      await db.insert('task_contacts', {
        'task_id': row['id'],
        'contact_id': saved.first['id'],
        'name': name,
        'phone': '',
        'remark': '',
        'sort_order': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _createProductTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS category_definitions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        color_value INTEGER NOT NULL,
        icon_name TEXT NOT NULL,
        sort_order INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS progress_templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL COLLATE NOCASE UNIQUE,
        sort_order INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS progress_template_nodes (
        id TEXT PRIMARY KEY,
        template_id TEXT NOT NULL,
        name TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        kind TEXT NOT NULL,
        sort_order INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS progress_instances (
        id TEXT PRIMARY KEY,
        owner_type TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        source_template_id TEXT,
        template_name TEXT NOT NULL,
        current_node_id TEXT NOT NULL,
        UNIQUE(owner_type, owner_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS progress_instance_nodes (
        id TEXT PRIMARY KEY,
        instance_id TEXT NOT NULL,
        source_node_id TEXT,
        name TEXT NOT NULL,
        color_value INTEGER NOT NULL,
        kind TEXT NOT NULL,
        sort_order INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plans (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        start_date TEXT NOT NULL,
        target_date TEXT NOT NULL,
        category_name TEXT NOT NULL DEFAULT '',
        category_color_value INTEGER NOT NULL DEFAULT 4287532691,
        category_icon_name TEXT NOT NULL DEFAULT 'project',
        calendar_display_mode TEXT NOT NULL DEFAULT 'whole_period',
        reminder_enabled INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plan_tags (
        plan_id TEXT NOT NULL,
        name TEXT NOT NULL,
        source_tag_id TEXT,
        color_value INTEGER NOT NULL,
        icon_name TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        PRIMARY KEY(plan_id, name)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plan_milestones (
        id TEXT PRIMARY KEY,
        plan_id TEXT NOT NULL,
        name TEXT NOT NULL,
        milestone_date TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        completed INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurrence_rules (
        id TEXT PRIMARY KEY,
        plan_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        start_time TEXT NOT NULL DEFAULT '',
        weekdays TEXT NOT NULL DEFAULT '',
        enabled INTEGER NOT NULL DEFAULT 1,
        progress_template_id TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS tasks_occurrence_idx
      ON tasks(recurrence_rule_id, occurrence_date)
      WHERE recurrence_rule_id IS NOT NULL AND occurrence_date IS NOT NULL
    ''');
  }

  Future<void> _createReminderTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS task_reminder_rules (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        rule_type TEXT NOT NULL,
        offset_minutes INTEGER,
        day_offset INTEGER,
        time_of_day TEXT,
        absolute_at TEXT,
        enabled INTEGER NOT NULL DEFAULT 1,
        delivery_type TEXT NOT NULL DEFAULT 'notification',
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS reminder_rules_task_idx
      ON task_reminder_rules(task_id, sort_order)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notification_jobs (
        request_id TEXT PRIMARY KEY,
        notification_id INTEGER NOT NULL,
        task_id TEXT NOT NULL,
        reminder_rule_id TEXT,
        fire_at_utc TEXT NOT NULL,
        state TEXT NOT NULL,
        last_error TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS notification_jobs_task_idx
      ON notification_jobs(task_id)
    ''');
    await _createPlanReminderTables(db);
    await _createAlarmTables(db);
  }

  Future<void> _createPlanReminderTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plan_reminder_rules (
        id TEXT PRIMARY KEY,
        plan_id TEXT NOT NULL,
        rule_type TEXT NOT NULL,
        offset_minutes INTEGER,
        day_offset INTEGER,
        time_of_day TEXT,
        absolute_at TEXT,
        enabled INTEGER NOT NULL DEFAULT 1,
        delivery_type TEXT NOT NULL DEFAULT 'notification',
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS plan_reminder_rules_plan_idx
      ON plan_reminder_rules(plan_id, sort_order)
    ''');
  }

  Future<void> _createAlarmTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS alarm_jobs (
        alarm_id TEXT PRIMARY KEY,
        request_id TEXT NOT NULL UNIQUE,
        owner_type TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        reminder_rule_id TEXT NOT NULL,
        fire_at_utc TEXT NOT NULL,
        state TEXT NOT NULL,
        last_error TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS alarm_jobs_owner_idx
      ON alarm_jobs(owner_type, owner_id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS alarm_jobs_rule_idx
      ON alarm_jobs(reminder_rule_id)
    ''');
  }

  Future<void> _upgradeToVersion5(Database db) async {
    await db.execute('ALTER TABLE tasks ADD COLUMN source_category_id TEXT');
    await db.execute(
      'ALTER TABLE tasks ADD COLUMN category_color_value INTEGER NOT NULL DEFAULT 4287532691',
    );
    await db.execute(
      "ALTER TABLE tasks ADD COLUMN category_icon_name TEXT NOT NULL DEFAULT 'project'",
    );
    await db.execute('ALTER TABLE tasks ADD COLUMN plan_id TEXT');
    await db.execute('ALTER TABLE tasks ADD COLUMN recurrence_rule_id TEXT');
    await db.execute('ALTER TABLE tasks ADD COLUMN occurrence_date TEXT');
    await db.execute(
      'ALTER TABLE tasks ADD COLUMN detached_from_rule INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('ALTER TABLE task_tags ADD COLUMN source_tag_id TEXT');
    await db.execute(
      'ALTER TABLE task_tags ADD COLUMN color_value INTEGER NOT NULL DEFAULT 4287532691',
    );
    await db.execute(
      "ALTER TABLE task_tags ADD COLUMN icon_name TEXT NOT NULL DEFAULT 'label'",
    );
    await _createProductTables(db);
    await _bootstrapProductData(db);
  }

  Future<void> _bootstrapProductData(DatabaseExecutor db) async {
    final types = await db.rawQuery(
      "SELECT DISTINCT type FROM tasks WHERE TRIM(type) <> '' ORDER BY type",
    );
    for (var i = 0; i < types.length; i++) {
      final name = types[i]['type']! as String;
      final id = 'category-migrated-$i';
      await db.insert('category_definitions', {
        'id': id,
        'name': name,
        'color_value': 0xff8e8e93,
        'icon_name': 'project',
        'sort_order': i,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await db.update(
        'tasks',
        {
          'source_category_id': id,
          'category_color_value': 0xff8e8e93,
          'category_icon_name': 'project',
        },
        where: 'type = ? AND source_category_id IS NULL',
        whereArgs: [name],
      );
    }

    final templateCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM progress_templates'),
    );
    if ((templateCount ?? 0) == 0) {
      await db.insert('progress_templates', {
        'id': 'default-progress',
        'name': '默认进度',
        'sort_order': 0,
      });
      final statuses = await db.query('task_statuses', orderBy: 'sort_order');
      final firstOpen = statuses.indexWhere((row) => row['completed'] == 0);
      final hasCompleted = statuses.any((row) => row['completed'] == 1);
      final offset = firstOpen == -1 ? 1 : 0;
      if (firstOpen == -1) {
        await db.insert('progress_template_nodes', {
          'id': 'default-migrated-start',
          'template_id': 'default-progress',
          'name': '未开始',
          'color_value': 0xff8e8e93,
          'kind': 'start',
          'sort_order': 0,
        });
      }
      for (var i = 0; i < statuses.length; i++) {
        final status = statuses[i];
        final completed = status['completed'] == 1;
        await db.insert('progress_template_nodes', {
          'id': 'default-${status['id']}',
          'template_id': 'default-progress',
          'name': status['name'],
          'color_value': status['color_value'],
          'kind': completed ? 'end' : (i == firstOpen ? 'start' : 'middle'),
          'sort_order': i + offset,
        });
      }
      if (!hasCompleted) {
        await db.insert('progress_template_nodes', {
          'id': 'default-migrated-end',
          'template_id': 'default-progress',
          'name': '已完成',
          'color_value': 0xff34c759,
          'kind': 'end',
          'sort_order': statuses.length + offset,
        });
      }
    }

    final tasks = await db.query('tasks');
    final nodes = await db.query(
      'progress_template_nodes',
      where: 'template_id = ?',
      whereArgs: ['default-progress'],
      orderBy: 'sort_order',
    );
    for (final task in tasks) {
      final taskId = task['id']! as String;
      final exists = Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT COUNT(*) FROM progress_instances WHERE owner_type = 'task' AND owner_id = ?",
          [taskId],
        ),
      );
      if ((exists ?? 0) > 0 || nodes.isEmpty) continue;
      final instanceId = 'task-progress-$taskId';
      final oldStatus = task['status_id'] as String;
      var currentId = 'task-$taskId-${nodes.first['id']}';
      for (final node in nodes) {
        final id = 'task-$taskId-${node['id']}';
        if (node['id'] == 'default-$oldStatus') currentId = id;
        await db.insert('progress_instance_nodes', {
          'id': id,
          'instance_id': instanceId,
          'source_node_id': node['id'],
          'name': node['name'],
          'color_value': node['color_value'],
          'kind': node['kind'],
          'sort_order': node['sort_order'],
        });
      }
      await db.insert('progress_instances', {
        'id': instanceId,
        'owner_type': 'task',
        'owner_id': taskId,
        'source_template_id': 'default-progress',
        'template_name': '默认进度',
        'current_node_id': currentId,
      });
    }

    final tags = await db.query('task_tags');
    final definitions = await db.query('tag_definitions');
    final byName = {
      for (final row in definitions)
        (row['name']! as String).toLowerCase(): row,
    };
    for (final tag in tags) {
      final definition = byName[(tag['tag']! as String).toLowerCase()];
      if (definition == null) continue;
      await db.update(
        'task_tags',
        {
          'source_tag_id': definition['id'],
          'color_value': definition['color_value'],
          'icon_name': definition['icon_name'],
        },
        where: 'task_id = ? AND tag = ?',
        whereArgs: [tag['task_id'], tag['tag']],
      );
    }
  }

  Future<void> _seed(Database db) async {
    const statuses = [
      TaskStatus(
        id: 'todo',
        name: '未开始',
        colorValue: 0xff8c91a3,
        completed: false,
        sortOrder: 0,
      ),
      TaskStatus(
        id: 'doing',
        name: '进行中',
        colorValue: 0xff497fc4,
        completed: false,
        sortOrder: 1,
      ),
      TaskStatus(
        id: 'waiting',
        name: '等待反馈',
        colorValue: 0xffc28a35,
        completed: false,
        sortOrder: 2,
      ),
      TaskStatus(
        id: 'done',
        name: '已完成',
        colorValue: 0xff3f9875,
        completed: true,
        sortOrder: 3,
      ),
    ];
    for (final status in statuses) {
      await db.insert('task_statuses', status.toMap());
    }
    const columns = {
      'id': '唯一 ID',
      'title': '标题',
      'description': '说明',
      'type': '分类',
      'contact': '联系人',
      'status': '状态 ID',
      'tags': '标签',
      'startDate': '开始日期',
      'startTime': '开始时间',
      'reminderEnabled': '启用提醒',
      'reminders': '提醒规则',
      'reason': '未完成原因',
      'completedAt': '完成时间',
      'originId': '来源 ID',
      'parentTaskId': '主任务 ID',
      'updatedAt': '修改时间',
    };
    var order = 0;
    for (final entry in columns.entries) {
      await db.insert('table_columns', {
        'key_name': entry.key,
        'label': entry.value,
        'visible': entry.key == 'id' || entry.key == 'status' ? 0 : 1,
        'sort_order': order++,
      });
    }
  }

  Future<List<TaskStatus>> getStatuses() async {
    final db = await database;
    final rows = await db.query('task_statuses', orderBy: 'sort_order');
    return rows.map(TaskStatus.fromMap).toList();
  }

  Future<List<TaskItem>> getTasks() async {
    final db = await database;
    final taskRows = await db.query('tasks');
    final tagRows = await db.query('task_tags', orderBy: 'sort_order');
    final taskContactRows = await db.rawQuery('''
      SELECT tc.task_id, tc.contact_id AS id, tc.name, tc.phone, tc.remark
      FROM task_contacts tc
      ORDER BY tc.task_id, tc.sort_order
    ''');
    final followRows = await db.query(
      'task_followups',
      orderBy: 'created_at DESC',
    );
    final historyRows = await db.query(
      'task_history',
      orderBy: 'created_at DESC',
    );
    final reminderRows = await db.query(
      'task_reminder_rules',
      orderBy: 'task_id, sort_order',
    );
    final progressRows = await db.query(
      'progress_instances',
      where: 'owner_type = ?',
      whereArgs: ['task'],
    );
    final progressNodeRows = await db.query(
      'progress_instance_nodes',
      orderBy: 'sort_order',
    );
    final tags = <String, List<String>>{};
    final tagSnapshots = <String, List<TaskTagSnapshot>>{};
    final followups = <String, List<TaskFollowup>>{};
    final history = <String, List<TaskHistory>>{};
    final contacts = <String, List<ContactEntry>>{};
    final reminders = <String, List<TaskReminderRule>>{};
    for (final row in reminderRows) {
      final reminder = TaskReminderRule.fromMap(row);
      reminders.putIfAbsent(reminder.taskId, () => []).add(reminder);
    }
    for (final row in taskContactRows) {
      contacts
          .putIfAbsent(row['task_id']! as String, () => [])
          .add(ContactEntry.fromMap(row));
    }
    for (final row in tagRows) {
      tags
          .putIfAbsent(row['task_id']! as String, () => [])
          .add(row['tag']! as String);
      tagSnapshots
          .putIfAbsent(row['task_id']! as String, () => [])
          .add(
            TaskTagSnapshot(
              sourceTagId: row['source_tag_id'] as String?,
              name: row['tag']! as String,
              colorValue: (row['color_value'] as int?) ?? 0xff8e8e93,
              iconName: (row['icon_name'] as String?) ?? 'label',
            ),
          );
    }
    for (final row in followRows) {
      followups
          .putIfAbsent(row['task_id']! as String, () => [])
          .add(
            TaskFollowup(
              id: row['id']! as String,
              at: DateTime.parse(row['created_at']! as String),
              text: row['content']! as String,
            ),
          );
    }
    for (final row in historyRows) {
      history
          .putIfAbsent(row['task_id']! as String, () => [])
          .add(
            TaskHistory(
              id: row['id']! as String,
              at: DateTime.parse(row['created_at']! as String),
              text: row['content']! as String,
            ),
          );
    }
    final nodesByInstance = <String, List<ProgressNode>>{};
    for (final row in progressNodeRows) {
      nodesByInstance
          .putIfAbsent(row['instance_id']! as String, () => [])
          .add(
            ProgressNode(
              id: row['id']! as String,
              name: row['name']! as String,
              colorValue: row['color_value']! as int,
              kind: progressNodeKindFromName(row['kind'] as String?),
              sortOrder: row['sort_order']! as int,
            ),
          );
    }
    final progressByOwner = <String, ProgressSnapshot>{};
    for (final row in progressRows) {
      final instanceId = row['id']! as String;
      progressByOwner[row['owner_id']! as String] = ProgressSnapshot(
        instanceId: instanceId,
        sourceTemplateId: row['source_template_id'] as String?,
        templateName: row['template_name']! as String,
        currentNodeId: row['current_node_id']! as String,
        nodes: nodesByInstance[instanceId] ?? const [],
      );
    }
    return taskRows.map((row) {
      final base = TaskItem.fromMap(row);
      return base.copyWith(
        tags: tags[base.id] ?? const [],
        tagSnapshots: tagSnapshots[base.id] ?? const [],
        progress: progressByOwner[base.id],
        contacts: contacts[base.id] ?? const [],
        followups: followups[base.id] ?? const [],
        history: history[base.id] ?? const [],
        reminders: reminders[base.id] ?? const [],
      );
    }).toList();
  }

  Future<List<ContactEntry>> getContacts() async {
    final db = await database;
    final rows = await db.query('contacts', orderBy: 'name COLLATE NOCASE');
    return rows.map(ContactEntry.fromMap).toList();
  }

  Future<void> saveContact(ContactEntry contact) async {
    final db = await database;
    final existing = await db.query(
      'contacts',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [contact.id],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('contacts', contact.toMap());
    } else {
      await db.update(
        'contacts',
        contact.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [contact.id],
      );
    }
  }

  Future<void> deleteContact(String id) async {
    final db = await database;
    await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TaskTagDefinition>> getTagDefinitions() async {
    final db = await database;
    final rows = await db.query('tag_definitions', orderBy: 'sort_order');
    return rows.map(TaskTagDefinition.fromMap).toList();
  }

  Future<List<CategoryDefinition>> getCategoryDefinitions() async {
    final db = await database;
    final rows = await db.query('category_definitions', orderBy: 'sort_order');
    return rows.map(CategoryDefinition.fromMap).toList();
  }

  Future<List<ProgressTemplate>> getProgressTemplates() async {
    final db = await database;
    final templates = await db.query(
      'progress_templates',
      orderBy: 'sort_order',
    );
    final nodeRows = await db.query(
      'progress_template_nodes',
      orderBy: 'sort_order',
    );
    return templates.map((row) {
      final id = row['id']! as String;
      final nodes = nodeRows
          .where((node) => node['template_id'] == id)
          .map(
            (node) => ProgressNode(
              id: node['id']! as String,
              name: node['name']! as String,
              colorValue: node['color_value']! as int,
              kind: progressNodeKindFromName(node['kind'] as String?),
              sortOrder: node['sort_order']! as int,
            ),
          )
          .toList();
      return ProgressTemplate(
        id: id,
        name: row['name']! as String,
        sortOrder: row['sort_order']! as int,
        nodes: nodes,
      );
    }).toList();
  }

  Future<List<PlanItem>> getPlans() async {
    final db = await database;
    final planRows = await db.query(
      'plans',
      orderBy: 'start_date, target_date',
    );
    final tagRows = await db.query('plan_tags', orderBy: 'sort_order');
    final milestoneRows = await db.query(
      'plan_milestones',
      orderBy: 'sort_order',
    );
    final ruleRows = await db.query('recurrence_rules', orderBy: 'start_date');
    final reminderRows = await db.query(
      'plan_reminder_rules',
      orderBy: 'plan_id, sort_order',
    );
    final contactRows = await db.rawQuery('''
      SELECT pc.plan_id, pc.contact_id AS id, pc.name, pc.phone, pc.remark
      FROM plan_contacts pc
      ORDER BY pc.plan_id, pc.sort_order
    ''');
    final progress = await _readProgressSnapshots(db);
    final tagsByPlan = <String, List<TaskTagSnapshot>>{};
    for (final row in tagRows) {
      tagsByPlan
          .putIfAbsent(row['plan_id']! as String, () => [])
          .add(
            TaskTagSnapshot(
              sourceTagId: row['source_tag_id'] as String?,
              name: row['name']! as String,
              colorValue: row['color_value']! as int,
              iconName: row['icon_name']! as String,
            ),
          );
    }
    final milestonesByPlan = <String, List<PlanMilestone>>{};
    for (final row in milestoneRows) {
      milestonesByPlan
          .putIfAbsent(row['plan_id']! as String, () => [])
          .add(
            PlanMilestone(
              id: row['id']! as String,
              name: row['name']! as String,
              date: row['milestone_date']! as String,
              description: row['description']! as String,
              completed: row['completed'] == 1,
              sortOrder: row['sort_order']! as int,
            ),
          );
    }
    final rulesByPlan = <String, List<RecurrenceRule>>{};
    final remindersByPlan = <String, List<TaskReminderRule>>{};
    final contactsByPlan = <String, List<ContactEntry>>{};
    for (final row in contactRows) {
      contactsByPlan
          .putIfAbsent(row['plan_id']! as String, () => [])
          .add(ContactEntry.fromMap(row));
    }
    for (final row in reminderRows) {
      final reminder = TaskReminderRule.fromMap({
        ...row,
        'task_id': row['plan_id'],
      });
      remindersByPlan.putIfAbsent(reminder.taskId, () => []).add(reminder);
    }
    for (final row in ruleRows) {
      final id = row['id']! as String;
      final ruleProgress = progress['rule:$id'];
      if (ruleProgress == null) continue;
      final weekdayText = row['weekdays']! as String;
      rulesByPlan
          .putIfAbsent(row['plan_id']! as String, () => [])
          .add(
            RecurrenceRule(
              id: id,
              planId: row['plan_id']! as String,
              title: row['title']! as String,
              description: row['description']! as String,
              startDate: row['start_date']! as String,
              endDate: row['end_date']! as String,
              startTime: row['start_time']! as String,
              weekdays: weekdayText.isEmpty
                  ? const {}
                  : weekdayText.split(',').map(int.parse).toSet(),
              enabled: row['enabled'] == 1,
              progress: ruleProgress,
            ),
          );
    }
    return planRows.map((row) {
      final id = row['id']! as String;
      final planProgress = progress['plan:$id'];
      if (planProgress == null) {
        throw StateError('计划“${row['name']}”缺少进度快照。');
      }
      return PlanItem(
        id: id,
        name: row['name']! as String,
        description: row['description']! as String,
        startDate: row['start_date']! as String,
        targetDate: row['target_date']! as String,
        categoryName: row['category_name']! as String,
        categoryColorValue: row['category_color_value']! as int,
        categoryIconName: row['category_icon_name']! as String,
        tags: tagsByPlan[id] ?? const [],
        progress: planProgress,
        milestones: milestonesByPlan[id] ?? const [],
        rules: rulesByPlan[id] ?? const [],
        updatedAt: DateTime.parse(row['updated_at']! as String),
        completedAt: DateTime.tryParse(
          (row['completed_at'] as String?) ?? '',
        ),
        calendarDisplayMode: planCalendarDisplayModeFromName(
          row['calendar_display_mode'] as String?,
        ),
        reminderEnabled: (row['reminder_enabled'] as int? ?? 0) == 1,
        reminders: remindersByPlan[id] ?? const [],
        contacts: contactsByPlan[id] ?? const [],
      );
    }).toList();
  }

  Future<Map<String, ProgressSnapshot>> _readProgressSnapshots(
    DatabaseExecutor db,
  ) async {
    final instances = await db.query('progress_instances');
    final nodeRows = await db.query(
      'progress_instance_nodes',
      orderBy: 'sort_order',
    );
    final nodes = <String, List<ProgressNode>>{};
    for (final row in nodeRows) {
      nodes
          .putIfAbsent(row['instance_id']! as String, () => [])
          .add(
            ProgressNode(
              id: row['id']! as String,
              name: row['name']! as String,
              colorValue: row['color_value']! as int,
              kind: progressNodeKindFromName(row['kind'] as String?),
              sortOrder: row['sort_order']! as int,
            ),
          );
    }
    return {
      for (final row in instances)
        '${row['owner_type']}:${row['owner_id']}': ProgressSnapshot(
          instanceId: row['id']! as String,
          sourceTemplateId: row['source_template_id'] as String?,
          templateName: row['template_name']! as String,
          currentNodeId: row['current_node_id']! as String,
          nodes: nodes[row['id']! as String] ?? const [],
        ),
    };
  }

  Future<void> savePlan(PlanItem plan) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('plans', {
        'id': plan.id,
        'name': plan.name,
        'description': plan.description,
        'start_date': plan.startDate,
        'target_date': plan.targetDate,
        'category_name': plan.categoryName,
        'category_color_value': plan.categoryColorValue,
        'category_icon_name': plan.categoryIconName,
        'calendar_display_mode': plan.calendarDisplayMode.storageName,
        'reminder_enabled': plan.reminderEnabled ? 1 : 0,
        'completed_at': plan.completedAt?.toIso8601String(),
        'updated_at': plan.updatedAt.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        'plan_reminder_rules',
        where: 'plan_id = ?',
        whereArgs: [plan.id],
      );
      for (var i = 0; i < plan.reminders.length; i++) {
        final reminder = plan.reminders[i];
        final values = reminder.toMap()..remove('task_id');
        await txn.insert('plan_reminder_rules', {
          ...values,
          'plan_id': plan.id,
          'sort_order': i,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.delete('plan_tags', where: 'plan_id = ?', whereArgs: [plan.id]);
      for (var i = 0; i < plan.tags.length; i++) {
        final tag = plan.tags[i];
        await txn.insert('plan_tags', {
          'plan_id': plan.id,
          'name': tag.name,
          'source_tag_id': tag.sourceTagId,
          'color_value': tag.colorValue,
          'icon_name': tag.iconName,
          'sort_order': i,
        });
      }
      await txn.delete(
        'plan_contacts',
        where: 'plan_id = ?',
        whereArgs: [plan.id],
      );
      for (var i = 0; i < plan.contacts.length; i++) {
        await txn.insert('plan_contacts', {
          'plan_id': plan.id,
          'contact_id': plan.contacts[i].id,
          'name': plan.contacts[i].name,
          'phone': plan.contacts[i].phone,
          'remark': plan.contacts[i].remark,
          'sort_order': i,
        });
      }
      await txn.delete(
        'plan_milestones',
        where: 'plan_id = ?',
        whereArgs: [plan.id],
      );
      for (var i = 0; i < plan.milestones.length; i++) {
        final milestone = plan.milestones[i];
        await txn.insert('plan_milestones', {
          'id': milestone.id,
          'plan_id': plan.id,
          'name': milestone.name,
          'milestone_date': milestone.date,
          'description': milestone.description,
          'completed': milestone.completed ? 1 : 0,
          'sort_order': i,
        });
      }
      final oldRules = await txn.query(
        'recurrence_rules',
        columns: ['id'],
        where: 'plan_id = ?',
        whereArgs: [plan.id],
      );
      for (final oldRule in oldRules) {
        await _deleteProgressSnapshot(txn, 'rule', oldRule['id']! as String);
      }
      await txn.delete(
        'recurrence_rules',
        where: 'plan_id = ?',
        whereArgs: [plan.id],
      );
      for (final rule in plan.rules) {
        await txn.insert('recurrence_rules', {
          'id': rule.id,
          'plan_id': plan.id,
          'title': rule.title,
          'description': rule.description,
          'start_date': rule.startDate,
          'end_date': rule.endDate,
          'start_time': rule.startTime,
          'weekdays': (rule.weekdays.toList()..sort()).join(','),
          'enabled': rule.enabled ? 1 : 0,
          'progress_template_id': rule.progress.sourceTemplateId ?? '',
        });
        await _saveProgressSnapshot(txn, 'rule', rule.id, rule.progress);
      }
      await _saveProgressSnapshot(txn, 'plan', plan.id, plan.progress);
    });
    await materializeRecurringTasks();
  }

  Future<void> deletePlan(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      final rules = await txn.query(
        'recurrence_rules',
        columns: ['id'],
        where: 'plan_id = ?',
        whereArgs: [id],
      );
      for (final rule in rules) {
        await _deleteProgressSnapshot(txn, 'rule', rule['id']! as String);
      }
      await _deleteProgressSnapshot(txn, 'plan', id);
      await txn.delete(
        'recurrence_rules',
        where: 'plan_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'plan_milestones',
        where: 'plan_id = ?',
        whereArgs: [id],
      );
      await txn.delete('plan_tags', where: 'plan_id = ?', whereArgs: [id]);
      await txn.delete('plan_contacts', where: 'plan_id = ?', whereArgs: [id]);
      await txn.delete(
        'plan_reminder_rules',
        where: 'plan_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'notification_jobs',
        where: 'task_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'alarm_jobs',
        where: 'owner_type = ? AND owner_id = ?',
        whereArgs: ['plan', id],
      );
      await txn.delete('plans', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> _deleteProgressSnapshot(
    DatabaseExecutor db,
    String ownerType,
    String ownerId,
  ) async {
    final rows = await db.query(
      'progress_instances',
      columns: ['id'],
      where: 'owner_type = ? AND owner_id = ?',
      whereArgs: [ownerType, ownerId],
    );
    for (final row in rows) {
      await db.delete(
        'progress_instance_nodes',
        where: 'instance_id = ?',
        whereArgs: [row['id']],
      );
    }
    await db.delete(
      'progress_instances',
      where: 'owner_type = ? AND owner_id = ?',
      whereArgs: [ownerType, ownerId],
    );
  }

  Future<void> materializeRecurringTasks() async {
    final plans = await getPlans();
    final db = await database;
    final defaultReminderRows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['default_reminder_minutes'],
      limit: 1,
    );
    final defaultReminderMinutes = defaultReminderRows.isEmpty
        ? -1
        : int.tryParse(defaultReminderRows.first['value']! as String) ?? -1;
    final today = DateTime.now();
    final windowStart = DateTime(today.year, today.month, today.day);
    final windowEnd = windowStart.add(const Duration(days: 30));
    final legacyStatuses = await db.query(
      'task_statuses',
      orderBy: 'completed, sort_order',
    );
    final legacyStatusId = legacyStatuses.isEmpty
        ? 'todo'
        : legacyStatuses.first['id']! as String;
    await db.transaction((txn) async {
      for (final plan in plans) {
        for (final rule in plan.rules.where((item) => item.enabled)) {
          final ruleStart = DateTime.parse(rule.startDate);
          final ruleEnd = DateTime.parse(rule.endDate);
          var date = ruleStart.isAfter(windowStart) ? ruleStart : windowStart;
          final end = ruleEnd.isBefore(windowEnd) ? ruleEnd : windowEnd;
          while (!date.isAfter(end)) {
            if (rule.occursOn(date)) {
              final occurrence =
                  '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final exists = Sqflite.firstIntValue(
                await txn.rawQuery(
                  'SELECT COUNT(*) FROM tasks WHERE recurrence_rule_id = ? AND occurrence_date = ?',
                  [rule.id, occurrence],
                ),
              );
              if ((exists ?? 0) == 0) {
                final taskId = 'occurrence-${rule.id}-$occurrence';
                await txn.insert('tasks', {
                  'id': taskId,
                  'title': rule.title,
                  'description': rule.description,
                  'type': plan.categoryName,
                  'contact': '',
                  'status_id': legacyStatusId,
                  'start_date': occurrence,
                  'start_time': rule.startTime,
                  'reason': '',
                  'completed_at': null,
                  'origin_id': null,
                  'parent_task_id': null,
                  'source_category_id': null,
                  'category_color_value': plan.categoryColorValue,
                  'category_icon_name': plan.categoryIconName,
                  'plan_id': plan.id,
                  'recurrence_rule_id': rule.id,
                  'occurrence_date': occurrence,
                  'detached_from_rule': 0,
                  'reminder_enabled':
                      rule.startTime.isNotEmpty && defaultReminderMinutes >= 0
                      ? 1
                      : 0,
                  'updated_at': DateTime.now().toIso8601String(),
                });
                if (rule.startTime.isNotEmpty && defaultReminderMinutes >= 0) {
                  await txn.insert('task_reminder_rules', {
                    'id': 'reminder-default-$taskId',
                    'task_id': taskId,
                    'rule_type': 'relative_duration',
                    'offset_minutes': defaultReminderMinutes,
                    'day_offset': null,
                    'time_of_day': null,
                    'absolute_at': null,
                    'enabled': 1,
                    'sort_order': 0,
                  });
                }
                for (var i = 0; i < plan.tags.length; i++) {
                  final tag = plan.tags[i];
                  await txn.insert('task_tags', {
                    'task_id': taskId,
                    'tag': tag.name,
                    'source_tag_id': tag.sourceTagId,
                    'color_value': tag.colorValue,
                    'icon_name': tag.iconName,
                    'sort_order': i,
                  });
                }
                final instanceId = 'task-progress-$taskId';
                final clonedNodes = rule.progress.nodes
                    .map(
                      (node) => ProgressNode(
                        id: '$instanceId-${node.id}',
                        name: node.name,
                        colorValue: node.colorValue,
                        kind: node.kind,
                        sortOrder: node.sortOrder,
                      ),
                    )
                    .toList();
                final start = clonedNodes.firstWhere(
                  (node) => node.kind == ProgressNodeKind.start,
                  orElse: () => clonedNodes.first,
                );
                await _saveProgressSnapshot(
                  txn,
                  'task',
                  taskId,
                  ProgressSnapshot(
                    instanceId: instanceId,
                    sourceTemplateId: rule.progress.sourceTemplateId,
                    templateName: rule.progress.templateName,
                    currentNodeId: start.id,
                    nodes: clonedNodes,
                  ),
                );
              }
            }
            date = date.add(const Duration(days: 1));
          }
        }
      }
    });
  }

  Future<AppPreferences> getPreferences() async {
    final db = await database;
    final rows = await db.query('app_settings');
    final values = {
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
    double calendarHeight(String key, double fallback) {
      final parsed = double.tryParse(values[key] ?? '');
      if (parsed == null ||
          parsed < AppPreferences.minimumCalendarRowHeight ||
          parsed > AppPreferences.maximumCalendarRowHeight) {
        return fallback;
      }
      return parsed;
    }

    Set<PlanCompletionStyle> completionStyles(
      String key,
      Set<PlanCompletionStyle> fallback, {
      required Set<PlanCompletionStyle> allowed,
    }) {
      if (!values.containsKey(key)) return fallback;
      final stored = values[key] ?? '';
      if (stored.isEmpty) return const {};
      final parsed = PlanCompletionStyle.values
          .where(
            (style) =>
                allowed.contains(style) && stored.split(',').contains(style.name),
          )
          .toSet();
      return parsed.isEmpty ? fallback : parsed;
    }

    final legacyDensity = values['compact'] == 'true' ? 'small' : 'medium';
    final storedDensity = values['calendar_density'];
    final calendarDensity = {'small', 'medium', 'large'}.contains(storedDensity)
        ? storedDensity!
        : legacyDensity;
    final legacyFontScale = switch (values['font']) {
      'small' => 0.88,
      'large' => 1.14,
      _ => 1.0,
    };
    final storedFontScale = double.tryParse(values['font_scale'] ?? '');
    final fontScale = storedFontScale != null &&
            storedFontScale >= AppPreferences.minimumFontScale &&
            storedFontScale <= AppPreferences.maximumFontScale
        ? storedFontScale
        : legacyFontScale;
    final storedFollowSystemFontScale = values['follow_system_font_scale'];
    final followSystemFontScale = storedFollowSystemFontScale == null
        ? !{'small', 'large'}.contains(values['font'])
        : storedFollowSystemFontScale != 'false';
    return AppPreferences(
      theme: values['theme'] ?? 'system',
      followSystemFontScale: followSystemFontScale,
      fontScale: fontScale,
      language: values['language'] ?? 'zh',
      calendarDensity: calendarDensity,
      calendarSmallHeight: calendarHeight('calendar_small_height', 62),
      calendarMediumHeight: calendarHeight('calendar_medium_height', 82),
      calendarLargeHeight: calendarHeight('calendar_large_height', 102),
      calendarWeeklyCardHeight: (() {
        final parsed = double.tryParse(
          values['calendar_weekly_card_height'] ?? '',
        );
        if (parsed == null ||
            !parsed.isFinite ||
            parsed <= 0 ||
            parsed > AppPreferences.maximumCalendarWeeklyCardHeight) {
          return 0.0;
        }
        return parsed;
      })(),
      calendarMonthCompletionStyles: completionStyles(
        'calendar_month_completion_styles',
        const {
          PlanCompletionStyle.dimText,
          PlanCompletionStyle.strikethrough,
        },
        allowed: const {
          PlanCompletionStyle.dimText,
          PlanCompletionStyle.border,
          PlanCompletionStyle.strikethrough,
        },
      ),
      calendarWeekCompletionStyles: completionStyles(
        'calendar_week_completion_styles',
        const {
          PlanCompletionStyle.dimText,
          PlanCompletionStyle.check,
        },
        allowed: PlanCompletionStyle.values.toSet(),
      ),
      quadrantCompletionStyles: completionStyles(
        'quadrant_completion_styles',
        const {
          PlanCompletionStyle.dimText,
          PlanCompletionStyle.check,
        },
        allowed: PlanCompletionStyle.values.toSet(),
      ),
      defaultReminderMinutes:
          int.tryParse(values['default_reminder_minutes'] ?? '') ?? -1,
      reminderSound: values['reminder_sound'] != 'false',
    );
  }

  Future<List<ColumnPreference>> getColumns() async {
    final db = await database;
    final rows = await db.query('table_columns', orderBy: 'sort_order');
    return rows
        .map(
          (row) => ColumnPreference(
            keyName: row['key_name']! as String,
            label: row['label']! as String,
            visible: row['visible']! as int == 1,
            sortOrder: row['sort_order']! as int,
          ),
        )
        .toList();
  }

  Future<void> saveTask(
    TaskItem task, {
    String? followup,
    List<String> history = const [],
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'tasks',
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete('task_tags', where: 'task_id = ?', whereArgs: [task.id]);
      await txn.delete(
        'task_reminder_rules',
        where: 'task_id = ?',
        whereArgs: [task.id],
      );
      for (var i = 0; i < task.reminders.length; i++) {
        final reminder = task.reminders[i];
        await txn.insert('task_reminder_rules', {
          ...reminder.toMap(),
          'task_id': task.id,
          'sort_order': i,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (var i = 0; i < task.tags.length; i++) {
        TaskTagSnapshot? snapshot;
        for (final item in task.tagSnapshots) {
          if (item.name == task.tags[i]) snapshot = item;
        }
        await txn.insert('task_tags', {
          'task_id': task.id,
          'tag': task.tags[i],
          'source_tag_id': snapshot?.sourceTagId,
          'color_value': snapshot?.colorValue ?? 0xff8e8e93,
          'icon_name': snapshot?.iconName ?? 'label',
          'sort_order': i,
        });
      }
      await txn.delete(
        'task_contacts',
        where: 'task_id = ?',
        whereArgs: [task.id],
      );
      for (var i = 0; i < task.contacts.length; i++) {
        final contact = task.contacts[i];
        await txn.insert('task_contacts', {
          'task_id': task.id,
          'contact_id': contact.id,
          'name': contact.name,
          'phone': contact.phone,
          'remark': contact.remark,
          'sort_order': i,
        });
      }
      if (task.progress != null) {
        await _saveProgressSnapshot(txn, 'task', task.id, task.progress!);
      }
      final now = DateTime.now().toIso8601String();
      if (followup != null && followup.trim().isNotEmpty) {
        await txn.insert('task_followups', {
          'id': '${task.id}-follow-${DateTime.now().microsecondsSinceEpoch}',
          'task_id': task.id,
          'created_at': now,
          'content': followup.trim(),
        });
      }
      for (final text in history) {
        await txn.insert('task_history', {
          'id':
              '${task.id}-history-${DateTime.now().microsecondsSinceEpoch}-${history.indexOf(text)}',
          'task_id': task.id,
          'created_at': now,
          'content': text,
        });
      }
    });
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('task_tags', where: 'task_id = ?', whereArgs: [id]);
      await txn.delete('task_contacts', where: 'task_id = ?', whereArgs: [id]);
      await txn.delete('task_followups', where: 'task_id = ?', whereArgs: [id]);
      await txn.delete('task_history', where: 'task_id = ?', whereArgs: [id]);
      await txn.delete(
        'task_reminder_rules',
        where: 'task_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'notification_jobs',
        where: 'task_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'alarm_jobs',
        where: 'owner_type = ? AND owner_id = ?',
        whereArgs: ['task', id],
      );
      final instances = await txn.query(
        'progress_instances',
        columns: ['id'],
        where: 'owner_type = ? AND owner_id = ?',
        whereArgs: ['task', id],
      );
      for (final instance in instances) {
        await txn.delete(
          'progress_instance_nodes',
          where: 'instance_id = ?',
          whereArgs: [instance['id']],
        );
      }
      await txn.delete(
        'progress_instances',
        where: 'owner_type = ? AND owner_id = ?',
        whereArgs: ['task', id],
      );
      await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> saveStatus(TaskStatus status) async {
    final db = await database;
    await db.insert(
      'task_statuses',
      status.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveTagDefinition(TaskTagDefinition tag) async {
    final db = await database;
    await db.insert(
      'tag_definitions',
      tag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveTagDefinitionOrder(
    List<TaskTagDefinition> definitions,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final definition in definitions) {
        await txn.update(
          'tag_definitions',
          {'sort_order': definition.sortOrder},
          where: 'id = ?',
          whereArgs: [definition.id],
        );
      }
    });
  }

  Future<void> saveCategoryDefinition(CategoryDefinition category) async {
    final db = await database;
    await db.insert(
      'category_definitions',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveCategoryDefinitionOrder(
    List<CategoryDefinition> definitions,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final definition in definitions) {
        await txn.update(
          'category_definitions',
          {'sort_order': definition.sortOrder},
          where: 'id = ?',
          whereArgs: [definition.id],
        );
      }
    });
  }

  Future<void> deleteCategoryDefinition(String id) async {
    final db = await database;
    await db.delete('category_definitions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveProgressTemplate(ProgressTemplate template) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('progress_templates', {
        'id': template.id,
        'name': template.name,
        'sort_order': template.sortOrder,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete(
        'progress_template_nodes',
        where: 'template_id = ?',
        whereArgs: [template.id],
      );
      for (var i = 0; i < template.nodes.length; i++) {
        final node = template.nodes[i];
        await txn.insert('progress_template_nodes', {
          'id': node.id,
          'template_id': template.id,
          'name': node.name,
          'color_value': node.colorValue,
          'kind': node.kind.name,
          'sort_order': i,
        });
      }
    });
  }

  Future<void> saveProgressTemplateOrder(
    List<ProgressTemplate> templates,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final template in templates) {
        await txn.update(
          'progress_templates',
          {'sort_order': template.sortOrder},
          where: 'id = ?',
          whereArgs: [template.id],
        );
      }
    });
  }

  Future<void> deleteProgressTemplate(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'progress_template_nodes',
        where: 'template_id = ?',
        whereArgs: [id],
      );
      await txn.delete('progress_templates', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> _saveProgressSnapshot(
    DatabaseExecutor db,
    String ownerType,
    String ownerId,
    ProgressSnapshot progress,
  ) async {
    final old = await db.query(
      'progress_instances',
      columns: ['id'],
      where: 'owner_type = ? AND owner_id = ?',
      whereArgs: [ownerType, ownerId],
    );
    for (final row in old) {
      await db.delete(
        'progress_instance_nodes',
        where: 'instance_id = ?',
        whereArgs: [row['id']],
      );
    }
    await db.delete(
      'progress_instances',
      where: 'owner_type = ? AND owner_id = ?',
      whereArgs: [ownerType, ownerId],
    );
    await db.insert('progress_instances', {
      'id': progress.instanceId,
      'owner_type': ownerType,
      'owner_id': ownerId,
      'source_template_id': progress.sourceTemplateId,
      'template_name': progress.templateName,
      'current_node_id': progress.currentNodeId,
    });
    for (var i = 0; i < progress.nodes.length; i++) {
      final node = progress.nodes[i];
      await db.insert('progress_instance_nodes', {
        'id': node.id,
        'instance_id': progress.instanceId,
        'source_node_id': null,
        'name': node.name,
        'color_value': node.colorValue,
        'kind': node.kind.name,
        'sort_order': i,
      });
    }
  }

  Future<void> deleteTagDefinition(String id) async {
    final db = await database;
    await db.delete('tag_definitions', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> deleteStatus(String id) async {
    final db = await database;
    final used =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM tasks WHERE status_id = ?', [
            id,
          ]),
        ) ??
        0;
    if (used > 0) return false;
    await db.delete('task_statuses', where: 'id = ?', whereArgs: [id]);
    return true;
  }

  Future<void> savePreference(String key, String value) async {
    final db = await database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<NotificationJob>> getNotificationJobs({String? taskId}) async {
    final db = await database;
    final rows = await db.query(
      'notification_jobs',
      where: taskId == null ? null : 'task_id = ?',
      whereArgs: taskId == null ? null : [taskId],
      orderBy: 'fire_at_utc',
    );
    return rows.map(NotificationJob.fromMap).toList();
  }

  Future<void> saveNotificationJob(NotificationJob job) async {
    final db = await database;
    await db.insert(
      'notification_jobs',
      job.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteNotificationJobsForTask(String taskId) async {
    final db = await database;
    await db.delete(
      'notification_jobs',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }

  Future<List<AlarmJob>> getAlarmJobs({
    String? ownerType,
    String? ownerId,
  }) async {
    final db = await database;
    final hasOwner = ownerType != null && ownerId != null;
    final rows = await db.query(
      'alarm_jobs',
      where: hasOwner ? 'owner_type = ? AND owner_id = ?' : null,
      whereArgs: hasOwner ? [ownerType, ownerId] : null,
      orderBy: 'fire_at_utc',
    );
    return rows.map(AlarmJob.fromMap).toList();
  }

  Future<void> saveAlarmJob(AlarmJob job) async {
    final db = await database;
    await db.insert(
      'alarm_jobs',
      job.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteAlarmJob(String alarmId) async {
    final db = await database;
    await db.delete('alarm_jobs', where: 'alarm_id = ?', whereArgs: [alarmId]);
  }

  Future<void> deleteAlarmJobsForOwner(String ownerType, String ownerId) async {
    final db = await database;
    await db.delete(
      'alarm_jobs',
      where: 'owner_type = ? AND owner_id = ?',
      whereArgs: [ownerType, ownerId],
    );
  }

  Future<void> saveColumns(List<ColumnPreference> columns) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var i = 0; i < columns.length; i++) {
        final column = columns[i];
        await txn.update(
          'table_columns',
          {'visible': column.visible ? 1 : 0, 'sort_order': i},
          where: 'key_name = ?',
          whereArgs: [column.keyName],
        );
      }
    });
  }
}
