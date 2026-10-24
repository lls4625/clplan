// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

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
  String get tipTitle => '打赏开发者';

  @override
  String get tipMenuTitle => '打赏开发者';

  @override
  String get tipMenuSubtitle => '通过 App Store 自愿支持，不解锁任何功能';

  @override
  String get tipHeading => '感谢你的支持';

  @override
  String get tipMotivation => '你的每一份鼓励，都是 ClPlan 不断完善的动力。';

  @override
  String get tipExplanation =>
      '打赏完全自愿，是一次性、可重复购买的 App Store 消耗型项目；不解锁任何功能或内容，不影响免费使用，且不可恢复。';

  @override
  String get tipLoadingProducts => '正在加载商品…';

  @override
  String get tipReloadProducts => '重新加载商品';

  @override
  String get tipNoProducts => '暂未获取到商品，请稍后重试';

  @override
  String get tipSomeProductsUnavailable => '部分商品暂不可用，请稍后重试。';

  @override
  String get tipPurchasesNotAllowed => '当前设备不允许购买。';

  @override
  String get tipServiceUnavailable => '打赏服务暂不可用，请稍后重试';

  @override
  String get tipStorageError => '打赏记录暂时无法保存，已暂停新的购买。请重新核对；已有支付不会自动重试。';

  @override
  String get tipStorageCorrupt =>
      '打赏记录无法安全读取，已暂停购买。请勿卸载或清空数据；可联系用户支持 QQ 群：1126527885。';

  @override
  String get tipUnresolved => '支付结果或请求关联仍待确认。请先重新核对；再次购买可能产生另一笔付款。';

  @override
  String get tipReconcile => '重新核对';

  @override
  String get tipChecking => '正在核对…';

  @override
  String get tipBuyAgain => '再次购买';

  @override
  String get tipBuyAgainWarning => '之前的请求仍可能完成付款。本次将发起新的购买，可能产生另一笔付款。确定继续吗？';

  @override
  String get tipIosOnly => '请在 iPhone 或 iPad 上支持开发者';

  @override
  String get tipProductsUnavailable => '商品暂不可用，请稍后重新加载';

  @override
  String get tipPurchaseRestricted => '当前设备不允许购买';

  @override
  String get tipProductsLoadFailed => '商品加载失败，请检查网络后重试';

  @override
  String get tipPurchaseBusy => '正在处理购买，请稍候';

  @override
  String get tipProductInvalid => '请先重新加载商品';

  @override
  String get tipVerificationFailed => '购买尚未通过验证，请重新核对支付结果，暂勿重复购买。';

  @override
  String get tipPurchasePending => '购买待批准，批准后会自动完成感谢';

  @override
  String get tipProductSmall => '一份鼓励';

  @override
  String get tipProductMedium => '暖心支持';

  @override
  String get tipProductLarge => '特别支持';

  @override
  String get tipProductXLarge => '大力支持';

  @override
  String get tipProductPremium => '顶级鼓励';

  @override
  String get tipProductStrong => '鼎力支持';

  @override
  String tipThanks(String support) {
    return '感谢你的「$support」！';
  }

  @override
  String get tipThanksStatic => '感谢你的支持。';

  @override
  String get tipThanksEcho => '愿每一份热爱都有回响。';

  @override
  String get tipClose => '关闭';

  @override
  String get tipSkip => '跳过';

  @override
  String get tipCancel => '取消';

  @override
  String tipProductSemantics(String name, String price) {
    return '$name，$price';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hans`).
class AppLocalizationsZhHans extends AppLocalizationsZh {
  AppLocalizationsZhHans() : super('zh_Hans');

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
  String get tipTitle => '打赏开发者';

  @override
  String get tipMenuTitle => '打赏开发者';

  @override
  String get tipMenuSubtitle => '通过 App Store 自愿支持，不解锁任何功能';

  @override
  String get tipHeading => '感谢你的支持';

  @override
  String get tipMotivation => '你的每一份鼓励，都是 ClPlan 不断完善的动力。';

  @override
  String get tipExplanation =>
      '打赏完全自愿，是一次性、可重复购买的 App Store 消耗型项目；不解锁任何功能或内容，不影响免费使用，且不可恢复。';

  @override
  String get tipLoadingProducts => '正在加载商品…';

  @override
  String get tipReloadProducts => '重新加载商品';

  @override
  String get tipNoProducts => '暂未获取到商品，请稍后重试';

  @override
  String get tipSomeProductsUnavailable => '部分商品暂不可用，请稍后重试。';

  @override
  String get tipPurchasesNotAllowed => '当前设备不允许购买。';

  @override
  String get tipServiceUnavailable => '打赏服务暂不可用，请稍后重试';

  @override
  String get tipStorageError => '打赏记录暂时无法保存，已暂停新的购买。请重新核对；已有支付不会自动重试。';

  @override
  String get tipStorageCorrupt =>
      '打赏记录无法安全读取，已暂停购买。请勿卸载或清空数据；可联系用户支持 QQ 群：1126527885。';

  @override
  String get tipUnresolved => '支付结果或请求关联仍待确认。请先重新核对；再次购买可能产生另一笔付款。';

  @override
  String get tipReconcile => '重新核对';

  @override
  String get tipChecking => '正在核对…';

  @override
  String get tipBuyAgain => '再次购买';

  @override
  String get tipBuyAgainWarning => '之前的请求仍可能完成付款。本次将发起新的购买，可能产生另一笔付款。确定继续吗？';

  @override
  String get tipIosOnly => '请在 iPhone 或 iPad 上支持开发者';

  @override
  String get tipProductsUnavailable => '商品暂不可用，请稍后重新加载';

  @override
  String get tipPurchaseRestricted => '当前设备不允许购买';

  @override
  String get tipProductsLoadFailed => '商品加载失败，请检查网络后重试';

  @override
  String get tipPurchaseBusy => '正在处理购买，请稍候';

  @override
  String get tipProductInvalid => '请先重新加载商品';

  @override
  String get tipVerificationFailed => '购买尚未通过验证，请重新核对支付结果，暂勿重复购买。';

  @override
  String get tipPurchasePending => '购买待批准，批准后会自动完成感谢';

  @override
  String get tipProductSmall => '一份鼓励';

  @override
  String get tipProductMedium => '暖心支持';

  @override
  String get tipProductLarge => '特别支持';

  @override
  String get tipProductXLarge => '大力支持';

  @override
  String get tipProductPremium => '顶级鼓励';

  @override
  String get tipProductStrong => '鼎力支持';

  @override
  String tipThanks(String support) {
    return '感谢你的「$support」！';
  }

  @override
  String get tipThanksStatic => '感谢你的支持。';

  @override
  String get tipThanksEcho => '愿每一份热爱都有回响。';

  @override
  String get tipClose => '关闭';

  @override
  String get tipSkip => '跳过';

  @override
  String get tipCancel => '取消';

  @override
  String tipProductSemantics(String name, String price) {
    return '$name，$price';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get tipTitle => '贊助開發者';

  @override
  String get tipMenuTitle => '贊助開發者';

  @override
  String get tipMenuSubtitle => '透過 App Store 自願支持，不解鎖任何功能';

  @override
  String get tipHeading => '感謝你的支持';

  @override
  String get tipMotivation => '你的每一份鼓勵，都是 ClPlan 不斷完善的動力。';

  @override
  String get tipExplanation =>
      '贊助完全自願，是一次性、可重複購買的 App Store 消耗型項目；不解鎖任何功能或內容，不影響免費使用，且不可回復。';

  @override
  String get tipLoadingProducts => '正在載入商品…';

  @override
  String get tipReloadProducts => '重新載入商品';

  @override
  String get tipNoProducts => '暫時無法取得商品，請稍後再試';

  @override
  String get tipSomeProductsUnavailable => '部分商品暫時無法使用，請稍後再試。';

  @override
  String get tipPurchasesNotAllowed => '目前裝置不允許購買。';

  @override
  String get tipServiceUnavailable => '贊助服務暫時無法使用，請稍後再試';

  @override
  String get tipStorageError => '贊助記錄暫時無法儲存，已暫停新的購買。請重新核對；既有付款不會自動重試。';

  @override
  String get tipStorageCorrupt =>
      '贊助記錄無法安全讀取，已暫停購買。請勿解除安裝或清除資料；可聯絡使用者支援 QQ 群：1126527885。';

  @override
  String get tipUnresolved => '付款結果或請求關聯仍待確認。請先重新核對；再次購買可能產生另一筆付款。';

  @override
  String get tipReconcile => '重新核對';

  @override
  String get tipChecking => '正在核對…';

  @override
  String get tipBuyAgain => '再次購買';

  @override
  String get tipBuyAgainWarning => '先前的請求仍可能完成付款。本次將發起新的購買，可能產生另一筆付款。確定繼續嗎？';

  @override
  String get tipIosOnly => '請在 iPhone 或 iPad 上支持開發者';

  @override
  String get tipProductsUnavailable => '商品暫時無法使用，請稍後重新載入';

  @override
  String get tipPurchaseRestricted => '目前裝置不允許購買';

  @override
  String get tipProductsLoadFailed => '商品載入失敗，請檢查網路後再試';

  @override
  String get tipPurchaseBusy => '正在處理購買，請稍候';

  @override
  String get tipProductInvalid => '請先重新載入商品';

  @override
  String get tipVerificationFailed => '購買尚未通過驗證，請重新核對付款結果，暫勿重複購買。';

  @override
  String get tipPurchasePending => '購買等待核准，核准後會自動完成感謝';

  @override
  String get tipProductSmall => '一份鼓勵';

  @override
  String get tipProductMedium => '暖心支持';

  @override
  String get tipProductLarge => '特別支持';

  @override
  String get tipProductXLarge => '大力支持';

  @override
  String get tipProductPremium => '頂級鼓勵';

  @override
  String get tipProductStrong => '鼎力支持';

  @override
  String tipThanks(String support) {
    return '感謝你的「$support」！';
  }

  @override
  String get tipThanksStatic => '感謝你的支持。';

  @override
  String get tipThanksEcho => '願每一份熱愛都有回響。';

  @override
  String get tipClose => '關閉';

  @override
  String get tipSkip => '跳過';

  @override
  String get tipCancel => '取消';

  @override
  String tipProductSemantics(String name, String price) {
    return '$name，$price';
  }
}
