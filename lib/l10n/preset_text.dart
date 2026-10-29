import 'package:flutter/widgets.dart';

import '../models.dart';

const Map<String, Map<String, String>> _presetNames = {
  'zh-Hans': {
    '_new-progress': '新进度',
    '_new-node': '新节点',
    '_new-category': '新分类',
    '_new-tag': '新标签',
    'quadrant-important-urgent': '重要且紧急',
    'quadrant-important-not-urgent': '重要不紧急',
    'quadrant-not-important-urgent': '不重要但紧急',
    'quadrant-not-important-not-urgent': '不重要不紧急',
    'starter-tag-meeting': '会议',
    'starter-tag-review': '复习',
    'starter-tag-outside': '外出',
    'starter-category-work': '工作',
    'starter-category-study': '学习',
    'starter-category-life': '生活',
    'default-progress': '通用进度',
    'default-todo': '未开始',
    'default-doing': '进行中',
    'default-waiting': '等待反馈',
    'default-done': '已完成',
    'todo': '未开始',
    'doing': '进行中',
    'waiting': '等待反馈',
    'done': '已完成',
  },
  'zh-Hant': {
    '_new-progress': '新進度',
    '_new-node': '新節點',
    '_new-category': '新分類',
    '_new-tag': '新標籤',
    'quadrant-important-urgent': '重要且緊急',
    'quadrant-important-not-urgent': '重要不緊急',
    'quadrant-not-important-urgent': '不重要但緊急',
    'quadrant-not-important-not-urgent': '不重要不緊急',
    'starter-tag-meeting': '會議',
    'starter-tag-review': '複習',
    'starter-tag-outside': '外出',
    'starter-category-work': '工作',
    'starter-category-study': '學習',
    'starter-category-life': '生活',
    'default-progress': '通用進度',
    'default-todo': '未開始',
    'default-doing': '進行中',
    'default-waiting': '等待回饋',
    'default-done': '已完成',
    'todo': '未開始',
    'doing': '進行中',
    'waiting': '等待回饋',
    'done': '已完成',
  },
  'en': {
    '_new-progress': 'New progress',
    '_new-node': 'New node',
    '_new-category': 'New category',
    '_new-tag': 'New tag',
    'quadrant-important-urgent': 'Important & urgent',
    'quadrant-important-not-urgent': 'Important, not urgent',
    'quadrant-not-important-urgent': 'Not important, but urgent',
    'quadrant-not-important-not-urgent': 'Not important or urgent',
    'starter-tag-meeting': 'Meeting',
    'starter-tag-review': 'Review',
    'starter-tag-outside': 'Out',
    'starter-category-work': 'Work',
    'starter-category-study': 'Study',
    'starter-category-life': 'Life',
    'default-progress': 'General progress',
    'default-todo': 'Not started',
    'default-doing': 'In progress',
    'default-waiting': 'Waiting for feedback',
    'default-done': 'Completed',
    'todo': 'Not started',
    'doing': 'In progress',
    'waiting': 'Waiting for feedback',
    'done': 'Completed',
  },
  'ja': {
    '_new-progress': '新しい進捗',
    '_new-node': '新しいノード',
    '_new-category': '新しいカテゴリ',
    '_new-tag': '新しいタグ',
    'quadrant-important-urgent': '重要かつ緊急',
    'quadrant-important-not-urgent': '重要だが緊急ではない',
    'quadrant-not-important-urgent': '重要ではないが緊急',
    'quadrant-not-important-not-urgent': '重要でも緊急でもない',
    'starter-tag-meeting': '会議',
    'starter-tag-review': '復習',
    'starter-tag-outside': '外出',
    'starter-category-work': '仕事',
    'starter-category-study': '学習',
    'starter-category-life': '生活',
    'default-progress': '一般進捗',
    'default-todo': '未着手',
    'default-doing': '進行中',
    'default-waiting': 'フィードバック待ち',
    'default-done': '完了',
    'todo': '未着手',
    'doing': '進行中',
    'waiting': 'フィードバック待ち',
    'done': '完了',
  },
  'ko': {
    '_new-progress': '새 진행',
    '_new-node': '새 단계',
    '_new-category': '새 카테고리',
    '_new-tag': '새 태그',
    'quadrant-important-urgent': '중요하고 긴급함',
    'quadrant-important-not-urgent': '중요하지만 긴급하지 않음',
    'quadrant-not-important-urgent': '중요하지 않지만 긴급함',
    'quadrant-not-important-not-urgent': '중요하지도 긴급하지도 않음',
    'starter-tag-meeting': '회의',
    'starter-tag-review': '복습',
    'starter-tag-outside': '외출',
    'starter-category-work': '업무',
    'starter-category-study': '학습',
    'starter-category-life': '생활',
    'default-progress': '일반 진행',
    'default-todo': '시작 전',
    'default-doing': '진행 중',
    'default-waiting': '피드백 대기',
    'default-done': '완료',
    'todo': '시작 전',
    'doing': '진행 중',
    'waiting': '피드백 대기',
    'done': '완료',
  },
};

String _localeKey(Locale locale) {
  if (locale.languageCode != 'zh') return locale.languageCode;
  final region = locale.countryCode?.toUpperCase();
  final traditional =
      locale.scriptCode == 'Hant' ||
      region == 'TW' ||
      region == 'HK' ||
      region == 'MO';
  return traditional ? 'zh-Hant' : 'zh-Hans';
}

String presetNameForLocale({
  required Locale locale,
  required String id,
  required String fallback,
  required NameSource nameSource,
}) {
  if (nameSource == NameSource.user) return fallback;
  return _presetNames[_localeKey(locale)]?[id] ??
      _presetNames['en']?[id] ??
      fallback;
}

String categoryDefinitionName(CategoryDefinition value, Locale locale) =>
    presetNameForLocale(
      locale: locale,
      id: value.id,
      fallback: value.name,
      nameSource: value.nameSource,
    );

String tagDefinitionName(TaskTagDefinition value, Locale locale) =>
    presetNameForLocale(
      locale: locale,
      id: value.id,
      fallback: value.name,
      nameSource: value.nameSource,
    );

String progressTemplateName(ProgressTemplate value, Locale locale) =>
    presetNameForLocale(
      locale: locale,
      id: value.id,
      fallback: value.name,
      nameSource: value.nameSource,
    );

String progressNodeName(ProgressNode value, Locale locale) =>
    presetNameForLocale(
      locale: locale,
      id: value.sourceNodeId ?? value.id,
      fallback: value.name,
      nameSource: value.nameSource,
    );

String taskStatusName(TaskStatus value, Locale locale) => presetNameForLocale(
  locale: locale,
  id: value.id,
  fallback: value.name,
  nameSource: value.nameSource,
);
