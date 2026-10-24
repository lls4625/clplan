import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('ja'),
    Locale('ko'),
    Locale('en'),
    Locale('zh'),
  ];

  /// 新建计划时智能规划面板的标题
  ///
  /// In zh_Hans, this message translates to:
  /// **'智能规划计划'**
  String get planningPlanTitle;

  /// 新建任务时智能规划面板的标题
  ///
  /// In zh_Hans, this message translates to:
  /// **'智能规划任务'**
  String get planningTaskTitle;

  /// No description provided for @planningClose.
  ///
  /// In zh_Hans, this message translates to:
  /// **'关闭'**
  String get planningClose;

  /// No description provided for @planningDiscardTitle.
  ///
  /// In zh_Hans, this message translates to:
  /// **'放弃本次输入？'**
  String get planningDiscardTitle;

  /// No description provided for @planningDiscardMessage.
  ///
  /// In zh_Hans, this message translates to:
  /// **'尚未保存的规划内容和选择将会丢失。'**
  String get planningDiscardMessage;

  /// No description provided for @planningContinueEditing.
  ///
  /// In zh_Hans, this message translates to:
  /// **'继续编辑'**
  String get planningContinueEditing;

  /// No description provided for @planningDiscard.
  ///
  /// In zh_Hans, this message translates to:
  /// **'放弃'**
  String get planningDiscard;

  /// No description provided for @planningPlanInputLabel.
  ///
  /// In zh_Hans, this message translates to:
  /// **'输入计划内容'**
  String get planningPlanInputLabel;

  /// No description provided for @planningTaskInputLabel.
  ///
  /// In zh_Hans, this message translates to:
  /// **'输入任务内容'**
  String get planningTaskInputLabel;

  /// No description provided for @planningInputHint.
  ///
  /// In zh_Hans, this message translates to:
  /// **'例如：明天下午四点到机场接人'**
  String get planningInputHint;

  /// No description provided for @planningSuggestedTitle.
  ///
  /// In zh_Hans, this message translates to:
  /// **'建议标题'**
  String get planningSuggestedTitle;

  /// No description provided for @planningAnalysisInProgress.
  ///
  /// In zh_Hans, this message translates to:
  /// **'正在分析输入内容'**
  String get planningAnalysisInProgress;

  /// No description provided for @planningAnalysisUnavailable.
  ///
  /// In zh_Hans, this message translates to:
  /// **'暂时无法分析，可按原文继续填写。'**
  String get planningAnalysisUnavailable;

  /// No description provided for @planningAlarmUnsupported.
  ///
  /// In zh_Hans, this message translates to:
  /// **'当前设备不支持闹铃，请先处理这条建议。'**
  String get planningAlarmUnsupported;

  /// No description provided for @planningConvertToNotification.
  ///
  /// In zh_Hans, this message translates to:
  /// **'改为通知'**
  String get planningConvertToNotification;

  /// No description provided for @planningRemoveReminder.
  ///
  /// In zh_Hans, this message translates to:
  /// **'移除提醒'**
  String get planningRemoveReminder;

  /// No description provided for @planningUseRawText.
  ///
  /// In zh_Hans, this message translates to:
  /// **'按原文填写'**
  String get planningUseRawText;

  /// No description provided for @planningApplyAndContinue.
  ///
  /// In zh_Hans, this message translates to:
  /// **'应用并继续'**
  String get planningApplyAndContinue;

  /// No description provided for @planningSourceBasicModelNotInstalled.
  ///
  /// In zh_Hans, this message translates to:
  /// **'由本机基础规则生成 · 当前未安装语言模型'**
  String get planningSourceBasicModelNotInstalled;

  /// No description provided for @planningSourceBasic.
  ///
  /// In zh_Hans, this message translates to:
  /// **'由本机基础规则生成'**
  String get planningSourceBasic;

  /// No description provided for @planningSourceModel.
  ///
  /// In zh_Hans, this message translates to:
  /// **'由本机语言模型生成'**
  String get planningSourceModel;

  /// No description provided for @planningScheduleDate.
  ///
  /// In zh_Hans, this message translates to:
  /// **'安排日期 {date}'**
  String planningScheduleDate(String date);

  /// No description provided for @planningSetScheduleDate.
  ///
  /// In zh_Hans, this message translates to:
  /// **'设置安排日期'**
  String get planningSetScheduleDate;

  /// No description provided for @planningScheduleTime.
  ///
  /// In zh_Hans, this message translates to:
  /// **'安排时间 {time}'**
  String planningScheduleTime(String time);

  /// No description provided for @planningSetScheduleTime.
  ///
  /// In zh_Hans, this message translates to:
  /// **'设置安排时间'**
  String get planningSetScheduleTime;

  /// No description provided for @planningRemoveScheduleTime.
  ///
  /// In zh_Hans, this message translates to:
  /// **'移除安排时间'**
  String get planningRemoveScheduleTime;

  /// No description provided for @planningRemoveSchedule.
  ///
  /// In zh_Hans, this message translates to:
  /// **'移除日期与时间'**
  String get planningRemoveSchedule;

  /// No description provided for @planningReminderUseDefault.
  ///
  /// In zh_Hans, this message translates to:
  /// **'提醒：使用当前默认设置'**
  String get planningReminderUseDefault;

  /// No description provided for @planningReminderNone.
  ///
  /// In zh_Hans, this message translates to:
  /// **'提醒：无'**
  String get planningReminderNone;

  /// No description provided for @planningRemoveReminderTooltip.
  ///
  /// In zh_Hans, this message translates to:
  /// **'移除提醒'**
  String get planningRemoveReminderTooltip;

  /// No description provided for @planningDeliveryAlarm.
  ///
  /// In zh_Hans, this message translates to:
  /// **'闹铃'**
  String get planningDeliveryAlarm;

  /// No description provided for @planningDeliveryNotification.
  ///
  /// In zh_Hans, this message translates to:
  /// **'通知'**
  String get planningDeliveryNotification;

  /// No description provided for @planningReminderOnTime.
  ///
  /// In zh_Hans, this message translates to:
  /// **'准时'**
  String get planningReminderOnTime;

  /// No description provided for @planningReminderMinutesBefore.
  ///
  /// In zh_Hans, this message translates to:
  /// **'提前 {minutes} 分钟'**
  String planningReminderMinutesBefore(int minutes);

  /// No description provided for @planningReminderHoursBefore.
  ///
  /// In zh_Hans, this message translates to:
  /// **'提前 {hours} 小时'**
  String planningReminderHoursBefore(int hours);

  /// No description provided for @planningReminderDaysBefore.
  ///
  /// In zh_Hans, this message translates to:
  /// **'提前 {days} 天'**
  String planningReminderDaysBefore(int days);

  /// No description provided for @planningReminderWithDelivery.
  ///
  /// In zh_Hans, this message translates to:
  /// **'{reminder} · {delivery}'**
  String planningReminderWithDelivery(String reminder, String delivery);

  /// No description provided for @planningReminderDayTime.
  ///
  /// In zh_Hans, this message translates to:
  /// **'提前 {days} 天 {time} · {delivery}'**
  String planningReminderDayTime(int days, String time, String delivery);

  /// No description provided for @planningReminderAbsolute.
  ///
  /// In zh_Hans, this message translates to:
  /// **'{time} · {delivery}'**
  String planningReminderAbsolute(String time, String delivery);

  /// No description provided for @planningSpecifiedTime.
  ///
  /// In zh_Hans, this message translates to:
  /// **'指定时间'**
  String get planningSpecifiedTime;

  /// No description provided for @planningTagSemantics.
  ///
  /// In zh_Hans, this message translates to:
  /// **'标签 {tag}'**
  String planningTagSemantics(String tag);

  /// No description provided for @planningNeedsConfirmation.
  ///
  /// In zh_Hans, this message translates to:
  /// **'需要确认'**
  String get planningNeedsConfirmation;

  /// No description provided for @planningAmbiguityBareHour.
  ///
  /// In zh_Hans, this message translates to:
  /// **'这个时间是凌晨还是下午？'**
  String get planningAmbiguityBareHour;

  /// No description provided for @planningAmbiguityTimeNeedsDate.
  ///
  /// In zh_Hans, this message translates to:
  /// **'这个时间安排在哪一天？'**
  String get planningAmbiguityTimeNeedsDate;

  /// No description provided for @planningAmbiguityFallback.
  ///
  /// In zh_Hans, this message translates to:
  /// **'请选择一个明确结果。'**
  String get planningAmbiguityFallback;

  /// No description provided for @planningChoiceNoTime.
  ///
  /// In zh_Hans, this message translates to:
  /// **'暂不设置时间'**
  String get planningChoiceNoTime;

  /// No description provided for @planningChoiceNoDate.
  ///
  /// In zh_Hans, this message translates to:
  /// **'暂不设置日期'**
  String get planningChoiceNoDate;

  /// No description provided for @planningWarningEmptyTitle.
  ///
  /// In zh_Hans, this message translates to:
  /// **'没有提取到可用标题，请修改输入或按原文填写。'**
  String get planningWarningEmptyTitle;

  /// No description provided for @planningWarningPastSchedule.
  ///
  /// In zh_Hans, this message translates to:
  /// **'识别到的安排时间已经过去，请修改日期或时间。'**
  String get planningWarningPastSchedule;

  /// No description provided for @planningWarningPastReminder.
  ///
  /// In zh_Hans, this message translates to:
  /// **'识别到的提醒时间已经过去，请修改或移除提醒。'**
  String get planningWarningPastReminder;

  /// No description provided for @planningWarningMissingDateForTime.
  ///
  /// In zh_Hans, this message translates to:
  /// **'安排时间需要同时设置日期，请选择日期或移除时间。'**
  String get planningWarningMissingDateForTime;

  /// No description provided for @planningWarningMissingReminderSchedule.
  ///
  /// In zh_Hans, this message translates to:
  /// **'相对提醒需要完整的安排日期和时间，请补充安排或移除提醒。'**
  String get planningWarningMissingReminderSchedule;

  /// No description provided for @planningWarningInputTooLong.
  ///
  /// In zh_Hans, this message translates to:
  /// **'输入最多 100 个字符。'**
  String get planningWarningInputTooLong;

  /// No description provided for @planningWarningLocaleNotSupported.
  ///
  /// In zh_Hans, this message translates to:
  /// **'当前只支持简体中文基础规划，将按原文处理。'**
  String get planningWarningLocaleNotSupported;

  /// No description provided for @planningWarningUnsupportedComplexTime.
  ///
  /// In zh_Hans, this message translates to:
  /// **'包含多个时间表达，当前基础规划无法可靠处理，请按原文填写。'**
  String get planningWarningUnsupportedComplexTime;

  /// No description provided for @planningWarningFallback.
  ///
  /// In zh_Hans, this message translates to:
  /// **'包含暂不支持的表达，可按原文继续填写。'**
  String get planningWarningFallback;

  /// No description provided for @planningBlockingWarningSemantics.
  ///
  /// In zh_Hans, this message translates to:
  /// **'阻断：{message}'**
  String planningBlockingWarningSemantics(String message);

  /// No description provided for @planningAdvisoryWarningSemantics.
  ///
  /// In zh_Hans, this message translates to:
  /// **'提示：{message}'**
  String planningAdvisoryWarningSemantics(String message);

  /// No description provided for @tipTitle.
  ///
  /// In zh_Hans, this message translates to:
  /// **'打赏开发者'**
  String get tipTitle;

  /// No description provided for @tipMenuTitle.
  ///
  /// In zh_Hans, this message translates to:
  /// **'打赏开发者'**
  String get tipMenuTitle;

  /// No description provided for @tipMenuSubtitle.
  ///
  /// In zh_Hans, this message translates to:
  /// **'通过 App Store 自愿支持，不解锁任何功能'**
  String get tipMenuSubtitle;

  /// No description provided for @tipHeading.
  ///
  /// In zh_Hans, this message translates to:
  /// **'感谢你的支持'**
  String get tipHeading;

  /// No description provided for @tipMotivation.
  ///
  /// In zh_Hans, this message translates to:
  /// **'你的每一份鼓励，都是 ClPlan 不断完善的动力。'**
  String get tipMotivation;

  /// No description provided for @tipExplanation.
  ///
  /// In zh_Hans, this message translates to:
  /// **'打赏完全自愿，是一次性、可重复购买的 App Store 消耗型项目；不解锁任何功能或内容，不影响免费使用，且不可恢复。'**
  String get tipExplanation;

  /// No description provided for @tipLoadingProducts.
  ///
  /// In zh_Hans, this message translates to:
  /// **'正在加载商品…'**
  String get tipLoadingProducts;

  /// No description provided for @tipReloadProducts.
  ///
  /// In zh_Hans, this message translates to:
  /// **'重新加载商品'**
  String get tipReloadProducts;

  /// No description provided for @tipNoProducts.
  ///
  /// In zh_Hans, this message translates to:
  /// **'暂未获取到商品，请稍后重试'**
  String get tipNoProducts;

  /// No description provided for @tipSomeProductsUnavailable.
  ///
  /// In zh_Hans, this message translates to:
  /// **'部分商品暂不可用，请稍后重试。'**
  String get tipSomeProductsUnavailable;

  /// No description provided for @tipPurchasesNotAllowed.
  ///
  /// In zh_Hans, this message translates to:
  /// **'当前设备不允许购买。'**
  String get tipPurchasesNotAllowed;

  /// No description provided for @tipServiceUnavailable.
  ///
  /// In zh_Hans, this message translates to:
  /// **'打赏服务暂不可用，请稍后重试'**
  String get tipServiceUnavailable;

  /// No description provided for @tipStorageError.
  ///
  /// In zh_Hans, this message translates to:
  /// **'打赏记录暂时无法保存，已暂停新的购买。请重新核对；已有支付不会自动重试。'**
  String get tipStorageError;

  /// No description provided for @tipStorageCorrupt.
  ///
  /// In zh_Hans, this message translates to:
  /// **'打赏记录无法安全读取，已暂停购买。请勿卸载或清空数据；可联系用户支持 QQ 群：1126527885。'**
  String get tipStorageCorrupt;

  /// No description provided for @tipUnresolved.
  ///
  /// In zh_Hans, this message translates to:
  /// **'支付结果或请求关联仍待确认。请先重新核对；再次购买可能产生另一笔付款。'**
  String get tipUnresolved;

  /// No description provided for @tipReconcile.
  ///
  /// In zh_Hans, this message translates to:
  /// **'重新核对'**
  String get tipReconcile;

  /// No description provided for @tipChecking.
  ///
  /// In zh_Hans, this message translates to:
  /// **'正在核对…'**
  String get tipChecking;

  /// No description provided for @tipBuyAgain.
  ///
  /// In zh_Hans, this message translates to:
  /// **'再次购买'**
  String get tipBuyAgain;

  /// No description provided for @tipBuyAgainWarning.
  ///
  /// In zh_Hans, this message translates to:
  /// **'之前的请求仍可能完成付款。本次将发起新的购买，可能产生另一笔付款。确定继续吗？'**
  String get tipBuyAgainWarning;

  /// No description provided for @tipIosOnly.
  ///
  /// In zh_Hans, this message translates to:
  /// **'请在 iPhone 或 iPad 上支持开发者'**
  String get tipIosOnly;

  /// No description provided for @tipProductsUnavailable.
  ///
  /// In zh_Hans, this message translates to:
  /// **'商品暂不可用，请稍后重新加载'**
  String get tipProductsUnavailable;

  /// No description provided for @tipPurchaseRestricted.
  ///
  /// In zh_Hans, this message translates to:
  /// **'当前设备不允许购买'**
  String get tipPurchaseRestricted;

  /// No description provided for @tipProductsLoadFailed.
  ///
  /// In zh_Hans, this message translates to:
  /// **'商品加载失败，请检查网络后重试'**
  String get tipProductsLoadFailed;

  /// No description provided for @tipPurchaseBusy.
  ///
  /// In zh_Hans, this message translates to:
  /// **'正在处理购买，请稍候'**
  String get tipPurchaseBusy;

  /// No description provided for @tipProductInvalid.
  ///
  /// In zh_Hans, this message translates to:
  /// **'请先重新加载商品'**
  String get tipProductInvalid;

  /// No description provided for @tipVerificationFailed.
  ///
  /// In zh_Hans, this message translates to:
  /// **'购买尚未通过验证，请重新核对支付结果，暂勿重复购买。'**
  String get tipVerificationFailed;

  /// No description provided for @tipPurchasePending.
  ///
  /// In zh_Hans, this message translates to:
  /// **'购买待批准，批准后会自动完成感谢'**
  String get tipPurchasePending;

  /// No description provided for @tipProductSmall.
  ///
  /// In zh_Hans, this message translates to:
  /// **'一份鼓励'**
  String get tipProductSmall;

  /// No description provided for @tipProductMedium.
  ///
  /// In zh_Hans, this message translates to:
  /// **'暖心支持'**
  String get tipProductMedium;

  /// No description provided for @tipProductLarge.
  ///
  /// In zh_Hans, this message translates to:
  /// **'特别支持'**
  String get tipProductLarge;

  /// No description provided for @tipProductXLarge.
  ///
  /// In zh_Hans, this message translates to:
  /// **'大力支持'**
  String get tipProductXLarge;

  /// No description provided for @tipProductPremium.
  ///
  /// In zh_Hans, this message translates to:
  /// **'顶级鼓励'**
  String get tipProductPremium;

  /// No description provided for @tipProductStrong.
  ///
  /// In zh_Hans, this message translates to:
  /// **'鼎力支持'**
  String get tipProductStrong;

  /// No description provided for @tipThanks.
  ///
  /// In zh_Hans, this message translates to:
  /// **'感谢你的「{support}」！'**
  String tipThanks(String support);

  /// No description provided for @tipThanksStatic.
  ///
  /// In zh_Hans, this message translates to:
  /// **'感谢你的支持。'**
  String get tipThanksStatic;

  /// No description provided for @tipThanksEcho.
  ///
  /// In zh_Hans, this message translates to:
  /// **'愿每一份热爱都有回响。'**
  String get tipThanksEcho;

  /// No description provided for @tipClose.
  ///
  /// In zh_Hans, this message translates to:
  /// **'关闭'**
  String get tipClose;

  /// No description provided for @tipSkip.
  ///
  /// In zh_Hans, this message translates to:
  /// **'跳过'**
  String get tipSkip;

  /// No description provided for @tipCancel.
  ///
  /// In zh_Hans, this message translates to:
  /// **'取消'**
  String get tipCancel;

  /// No description provided for @tipProductSemantics.
  ///
  /// In zh_Hans, this message translates to:
  /// **'{name}，{price}'**
  String tipProductSemantics(String name, String price);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
