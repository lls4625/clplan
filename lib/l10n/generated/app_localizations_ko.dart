// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

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
  String get tipTitle => '개발자 후원';

  @override
  String get tipMenuTitle => '개발자 후원';

  @override
  String get tipMenuSubtitle => 'App Store에서 자발적으로 후원하며 기능을 잠금 해제하지 않습니다';

  @override
  String get tipHeading => '후원해 주셔서 감사합니다';

  @override
  String get tipMotivation => '여러분의 응원이 ClPlan을 더 나아지게 만드는 힘입니다.';

  @override
  String get tipExplanation =>
      '후원은 완전히 자발적인 App Store 소모성 구매이며 반복 구매할 수 있습니다. 기능이나 콘텐츠를 잠금 해제하지 않고 무료 이용에 영향을 주지 않으며 복원할 수 없습니다.';

  @override
  String get tipLoadingProducts => '상품을 불러오는 중…';

  @override
  String get tipReloadProducts => '상품 다시 불러오기';

  @override
  String get tipNoProducts => '상품을 가져오지 못했습니다. 잠시 후 다시 시도해 주세요';

  @override
  String get tipSomeProductsUnavailable =>
      '일부 상품을 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get tipPurchasesNotAllowed => '현재 기기에서는 구매할 수 없습니다.';

  @override
  String get tipServiceUnavailable =>
      '후원 서비스를 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get tipStorageError =>
      '후원 기록을 저장할 수 없어 새 구매를 중지했습니다. 다시 확인해 주세요. 기존 결제는 자동으로 재시도되지 않습니다.';

  @override
  String get tipStorageCorrupt =>
      '후원 기록을 안전하게 읽을 수 없어 구매를 중지했습니다. 앱을 삭제하거나 데이터를 지우지 말고 사용자 지원 QQ 그룹 1126527885로 문의해 주세요.';

  @override
  String get tipUnresolved =>
      '결제 결과 또는 요청 연결을 아직 확인하지 못했습니다. 먼저 다시 확인해 주세요. 다시 구매하면 별도의 결제가 발생할 수 있습니다.';

  @override
  String get tipReconcile => '다시 확인';

  @override
  String get tipChecking => '확인 중…';

  @override
  String get tipBuyAgain => '다시 구매';

  @override
  String get tipBuyAgainWarning =>
      '이전 요청의 결제가 아직 완료될 수 있습니다. 계속하면 새 구매가 시작되어 별도의 결제가 발생할 수 있습니다. 계속할까요?';

  @override
  String get tipIosOnly => 'iPhone 또는 iPad에서 개발자를 후원할 수 있습니다.';

  @override
  String get tipProductsUnavailable => '상품을 일시적으로 사용할 수 없습니다. 잠시 후 다시 불러와 주세요.';

  @override
  String get tipPurchaseRestricted => '현재 기기에서는 구매할 수 없습니다.';

  @override
  String get tipProductsLoadFailed => '상품을 불러오지 못했습니다. 네트워크를 확인하고 다시 시도해 주세요.';

  @override
  String get tipPurchaseBusy => '구매를 처리 중입니다. 잠시 기다려 주세요.';

  @override
  String get tipProductInvalid => '먼저 상품을 다시 불러와 주세요.';

  @override
  String get tipVerificationFailed =>
      '구매가 아직 확인되지 않았습니다. 다시 구매하기 전에 결제 상태를 확인해 주세요.';

  @override
  String get tipPurchasePending => '구매 승인을 기다리고 있습니다. 승인 후 자동으로 완료됩니다.';

  @override
  String get tipProductSmall => '작은 응원';

  @override
  String get tipProductMedium => '따뜻한 후원';

  @override
  String get tipProductLarge => '특별 후원';

  @override
  String get tipProductXLarge => '큰 후원';

  @override
  String get tipProductPremium => '최고의 응원';

  @override
  String get tipProductStrong => '전폭적인 후원';

  @override
  String tipThanks(String support) {
    return '“$support” 후원에 감사드립니다!';
  }

  @override
  String get tipThanksStatic => '후원해 주셔서 감사합니다.';

  @override
  String get tipThanksEcho => '모든 열정이 좋은 울림으로 돌아오기를 바랍니다.';

  @override
  String get tipClose => '닫기';

  @override
  String get tipSkip => '건너뛰기';

  @override
  String get tipCancel => '취소';

  @override
  String tipProductSemantics(String name, String price) {
    return '$name, $price';
  }
}
