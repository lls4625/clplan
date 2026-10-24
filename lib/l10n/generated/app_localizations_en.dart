// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get planningPlanTitle => '智能规划计划';

  @override
  String get planningTaskTitle => '智能规划任务';

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
  String get tipTitle => 'Support the Developer';

  @override
  String get tipMenuTitle => 'Support the Developer';

  @override
  String get tipMenuSubtitle =>
      'Optional App Store support that unlocks no features';

  @override
  String get tipHeading => 'Thank You for Your Support';

  @override
  String get tipMotivation =>
      'Every bit of support helps ClPlan keep improving.';

  @override
  String get tipExplanation =>
      'Tips are entirely optional, repeatable App Store consumable purchases. They unlock no features or content, do not affect free use, and cannot be restored.';

  @override
  String get tipLoadingProducts => 'Loading products…';

  @override
  String get tipReloadProducts => 'Reload Products';

  @override
  String get tipNoProducts => 'Products are unavailable. Try again later.';

  @override
  String get tipSomeProductsUnavailable =>
      'Some products are temporarily unavailable. Try again later.';

  @override
  String get tipPurchasesNotAllowed =>
      'Purchases are not allowed on this device.';

  @override
  String get tipServiceUnavailable =>
      'Tips are temporarily unavailable. Try again later.';

  @override
  String get tipStorageError =>
      'Tip records cannot be saved. New purchases are paused. Check again; payments will not be retried automatically.';

  @override
  String get tipStorageCorrupt =>
      'Tip records cannot be read safely. Purchases are paused. Do not uninstall or clear data. Contact support: QQ group 1126527885.';

  @override
  String get tipUnresolved =>
      'The payment result or request association is unconfirmed. Check again first. Buying again may create another payment.';

  @override
  String get tipReconcile => 'Check again';

  @override
  String get tipChecking => 'Checking…';

  @override
  String get tipBuyAgain => 'Buy again';

  @override
  String get tipBuyAgainWarning =>
      'Your earlier request may still complete. Continuing starts a new purchase and may create another payment. Continue?';

  @override
  String get tipIosOnly => 'Support the developer from an iPhone or iPad.';

  @override
  String get tipProductsUnavailable =>
      'Products are unavailable. Reload them later.';

  @override
  String get tipPurchaseRestricted =>
      'Purchases are not allowed on this device.';

  @override
  String get tipProductsLoadFailed =>
      'Unable to load products. Check your network and try again.';

  @override
  String get tipPurchaseBusy => 'A purchase is being processed. Please wait.';

  @override
  String get tipProductInvalid => 'Reload the products first.';

  @override
  String get tipVerificationFailed =>
      'The purchase has not been verified. Check the payment status before buying again.';

  @override
  String get tipPurchasePending =>
      'The purchase is awaiting approval and will complete automatically afterward.';

  @override
  String get tipProductSmall => 'A Little Support';

  @override
  String get tipProductMedium => 'Warm Support';

  @override
  String get tipProductLarge => 'Special Support';

  @override
  String get tipProductXLarge => 'Big Support';

  @override
  String get tipProductPremium => 'Top Support';

  @override
  String get tipProductStrong => 'Ultimate Support';

  @override
  String tipThanks(String support) {
    return 'Thank you for “$support”!';
  }

  @override
  String get tipThanksStatic => 'Thank you for your support.';

  @override
  String get tipThanksEcho => 'May every passion find its echo.';

  @override
  String get tipClose => 'Close';

  @override
  String get tipSkip => 'Skip';

  @override
  String get tipCancel => 'Cancel';

  @override
  String tipProductSemantics(String name, String price) {
    return '$name, $price';
  }
}
