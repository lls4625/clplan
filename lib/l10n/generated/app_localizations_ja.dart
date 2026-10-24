// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get planningPlanTitle => '基础规划计划';

  @override
  String get planningTaskTitle => '基础规划任务';

  @override
  String get planningClose => '关闭';

  @override
  String get planningDiscardTitle => '放弃本次输入？';

  @override
  String get planningDiscardMessage => '尚未保存的规划内容和选择将会丢失。';

  @override
  String get planningContinueEditing => '继续编辑';

  @override
  String get planningDiscard => '放弃';

  @override
  String get planningPlanInputLabel => '输入计划内容';

  @override
  String get planningTaskInputLabel => '输入任务内容';

  @override
  String get planningInputHint => '例如：明天下午四点到机场接人';

  @override
  String get planningSuggestedTitle => '建议标题';

  @override
  String get planningAnalysisInProgress => '正在分析输入内容';

  @override
  String get planningAnalysisUnavailable => '暂时无法分析，可按原文继续填写。';

  @override
  String get planningAlarmUnsupported => '当前设备不支持闹铃，请先处理这条建议。';

  @override
  String get planningConvertToNotification => '改为通知';

  @override
  String get planningRemoveReminder => '移除提醒';

  @override
  String get planningUseRawText => '按原文填写';

  @override
  String get planningApplyAndContinue => '应用并继续';

  @override
  String get planningSourceBasicModelNotInstalled => '由本机基础规则生成 · 当前未安装语言模型';

  @override
  String get planningSourceBasic => '由本机基础规则生成';

  @override
  String get planningSourceModel => '由本机语言模型生成';

  @override
  String planningScheduleDate(String date) {
    return '安排日期 $date';
  }

  @override
  String get planningSetScheduleDate => '设置安排日期';

  @override
  String planningScheduleTime(String time) {
    return '安排时间 $time';
  }

  @override
  String get planningSetScheduleTime => '设置安排时间';

  @override
  String get planningRemoveScheduleTime => '移除安排时间';

  @override
  String get planningRemoveSchedule => '移除日期与时间';

  @override
  String get planningReminderUseDefault => '提醒：使用当前默认设置';

  @override
  String get planningReminderNone => '提醒：无';

  @override
  String get planningRemoveReminderTooltip => '移除提醒';

  @override
  String get planningDeliveryAlarm => '闹铃';

  @override
  String get planningDeliveryNotification => '通知';

  @override
  String get planningReminderOnTime => '准时';

  @override
  String planningReminderMinutesBefore(int minutes) {
    return '提前 $minutes 分钟';
  }

  @override
  String planningReminderHoursBefore(int hours) {
    return '提前 $hours 小时';
  }

  @override
  String planningReminderDaysBefore(int days) {
    return '提前 $days 天';
  }

  @override
  String planningReminderWithDelivery(String reminder, String delivery) {
    return '$reminder · $delivery';
  }

  @override
  String planningReminderDayTime(int days, String time, String delivery) {
    return '提前 $days 天 $time · $delivery';
  }

  @override
  String planningReminderAbsolute(String time, String delivery) {
    return '$time · $delivery';
  }

  @override
  String get planningSpecifiedTime => '指定时间';

  @override
  String planningTagSemantics(String tag) {
    return '标签 $tag';
  }

  @override
  String get planningNeedsConfirmation => '需要确认';

  @override
  String get planningAmbiguityBareHour => '这个时间是凌晨还是下午？';

  @override
  String get planningAmbiguityTimeNeedsDate => '这个时间安排在哪一天？';

  @override
  String get planningAmbiguityFallback => '请选择一个明确结果。';

  @override
  String get planningChoiceNoTime => '暂不设置时间';

  @override
  String get planningChoiceNoDate => '暂不设置日期';

  @override
  String get planningWarningEmptyTitle => '没有提取到可用标题，请修改输入或按原文填写。';

  @override
  String get planningWarningPastSchedule => '识别到的安排时间已经过去，请修改日期或时间。';

  @override
  String get planningWarningPastReminder => '识别到的提醒时间已经过去，请修改或移除提醒。';

  @override
  String get planningWarningMissingDateForTime => '安排时间需要同时设置日期，请选择日期或移除时间。';

  @override
  String get planningWarningMissingReminderSchedule =>
      '相对提醒需要完整的安排日期和时间，请补充安排或移除提醒。';

  @override
  String get planningWarningInputTooLong => '输入最多 100 个字符。';

  @override
  String get planningWarningLocaleNotSupported => '当前只支持简体中文基础规划，将按原文处理。';

  @override
  String get planningWarningUnsupportedComplexTime =>
      '包含多个时间表达，当前基础规划无法可靠处理，请按原文填写。';

  @override
  String get planningWarningFallback => '包含暂不支持的表达，可按原文继续填写。';

  @override
  String planningBlockingWarningSemantics(String message) {
    return '阻断：$message';
  }

  @override
  String planningAdvisoryWarningSemantics(String message) {
    return '提示：$message';
  }

  @override
  String get tipTitle => '開発者を支援';

  @override
  String get tipMenuTitle => '開発者を支援';

  @override
  String get tipMenuSubtitle => 'App Store から任意で支援できます。機能の解除はありません';

  @override
  String get tipHeading => 'ご支援ありがとうございます';

  @override
  String get tipMotivation => '皆さまの応援が、ClPlan をより良くする力になります。';

  @override
  String get tipExplanation =>
      '支援は完全に任意の App Store 消耗型購入で、繰り返し購入できます。機能やコンテンツは解放されず、無料利用に影響せず、復元できません。';

  @override
  String get tipLoadingProducts => '商品を読み込み中…';

  @override
  String get tipReloadProducts => '商品を再読み込み';

  @override
  String get tipNoProducts => '商品を取得できません。後でもう一度お試しください';

  @override
  String get tipSomeProductsUnavailable => '一部の商品は現在利用できません。後でもう一度お試しください。';

  @override
  String get tipPurchasesNotAllowed => 'この端末では購入できません。';

  @override
  String get tipServiceUnavailable => '現在、開発者支援を利用できません';

  @override
  String get tipStorageError =>
      '支援記録を保存できないため、新しい購入を停止しています。状況を再確認してください。支払いは自動で再実行されません。';

  @override
  String get tipStorageCorrupt =>
      '支援記録を安全に読み込めないため、購入を停止しています。アプリやデータを削除せず、サポート QQ グループ 1126527885 にお問い合わせください。';

  @override
  String get tipUnresolved =>
      '支払い結果または購入との対応を確認中です。まず再確認してください。再購入すると別の支払いが発生する場合があります。';

  @override
  String get tipReconcile => '状況を再確認';

  @override
  String get tipChecking => '確認中…';

  @override
  String get tipBuyAgain => 'もう一度購入';

  @override
  String get tipBuyAgainWarning =>
      '以前の購入が完了する可能性があります。続行すると新しい購入となり、別の支払いが発生する場合があります。続行しますか？';

  @override
  String get tipIosOnly => 'iPhone または iPad から開発者を支援できます';

  @override
  String get tipProductsUnavailable => '商品を利用できません。後で再読み込みしてください';

  @override
  String get tipPurchaseRestricted => 'この端末では購入できません';

  @override
  String get tipProductsLoadFailed => '商品を読み込めませんでした。ネットワークを確認してください';

  @override
  String get tipPurchaseBusy => '購入処理中です。しばらくお待ちください';

  @override
  String get tipProductInvalid => '先に商品を再読み込みしてください';

  @override
  String get tipVerificationFailed => '購入の検証が完了していません。支払い状況を再確認し、重複購入をお控えください。';

  @override
  String get tipPurchasePending => '購入は承認待ちです。承認後に自動的に完了します';

  @override
  String get tipProductSmall => 'ひとつの応援';

  @override
  String get tipProductMedium => 'あたたかい応援';

  @override
  String get tipProductLarge => '特別な応援';

  @override
  String get tipProductXLarge => '力強い応援';

  @override
  String get tipProductPremium => '最高の応援';

  @override
  String get tipProductStrong => '全力応援';

  @override
  String tipThanks(String support) {
    return '「$support」のご支援ありがとうございます！';
  }

  @override
  String get tipThanksStatic => 'ご支援ありがとうございます。';

  @override
  String get tipThanksEcho => 'すべての情熱が実を結びますように。';

  @override
  String get tipClose => '閉じる';

  @override
  String get tipSkip => 'スキップ';

  @override
  String get tipCancel => 'キャンセル';

  @override
  String tipProductSemantics(String name, String price) {
    return '$name、$price';
  }
}
