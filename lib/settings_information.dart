import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fill these with verified publisher information before release.
abstract final class SettingsPublisherInformation {
  static const String? developerName = null;
  static const String? supportEmail = null;
  static const String? privacyPolicyUrl = null;
  static const documentDate = '2026-10-29';
}

enum SettingsInformationPage { privacy, terms, permissions, data, contact }

String _language(BuildContext context) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode == 'zh') {
    return locale.scriptCode == 'Hant' ? 'tw' : 'zh';
  }
  return switch (locale.languageCode) {
    'ja' => 'ja',
    'ko' => 'ko',
    _ => 'en',
  };
}

String settingsInformationLabel(BuildContext context, String source) =>
    _labels[_language(context)]?[source] ?? source;

class SettingsInformationContent extends StatelessWidget {
  const SettingsInformationContent({super.key, required this.page});

  final SettingsInformationPage page;

  @override
  Widget build(BuildContext context) {
    final sections = _documents[_language(context)]![page]!;
    final isPolicy = page == SettingsInformationPage.privacy ||
        page == SettingsInformationPage.terms;
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPolicy)
            _InformationCard(
              title: settingsInformationLabel(context, '文档状态'),
              body: '${settingsInformationLabel(context, '草案：开发者及联系信息待补充。正式发布前需完善。')}\n'
                  '${settingsInformationLabel(context, '文档日期')}：'
                  '${SettingsPublisherInformation.documentDate}',
            ),
          for (final (title, body) in sections)
            _InformationCard(title: title, body: body),
          if (page == SettingsInformationPage.privacy ||
              page == SettingsInformationPage.contact)
            const _PublisherCard(),
        ],
      ),
    );
  }
}

class SettingsAboutContent extends StatefulWidget {
  const SettingsAboutContent({super.key});

  @override
  State<SettingsAboutContent> createState() => _SettingsAboutContentState();
}

class _SettingsAboutContentState extends State<SettingsAboutContent> {
  static const _channel = MethodChannel('vip.ichiki.javalee.clplan/app_info');
  late final Future<Map<String, String>?> _appInfo = _readAppInfo();

  Future<Map<String, String>?> _readAppInfo() async {
    try {
      return await _channel.invokeMapMethod<String, String>('getAppInfo');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, String>?>(
    future: _appInfo,
    builder: (context, snapshot) {
      final info = snapshot.data;
      final version = info?['version'];
      final build = info?['build'];
      final versionLabel = version == null || version.isEmpty
          ? settingsInformationLabel(
              context,
              snapshot.connectionState == ConnectionState.waiting
                  ? '读取中…'
                  : '版本信息暂不可用',
            )
          : build == null || build.isEmpty
          ? version
          : '$version ($build)';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InformationCard(
            title: 'ClPlan',
            body: settingsInformationLabel(context, '离线记录个人行程、计划与任务。'),
            children: [
              const SizedBox(height: 16),
              _InformationField(
                label: settingsInformationLabel(context, '版本'),
                value: versionLabel,
              ),
              _InformationField(
                label: settingsInformationLabel(context, '开发者'),
                value: SettingsPublisherInformation.developerName ??
                    settingsInformationLabel(context, '待补充'),
              ),
            ],
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 14),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(settingsInformationLabel(context, '开源许可')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'ClPlan',
                applicationVersion: version == null || version.isEmpty
                    ? null
                    : build == null || build.isEmpty
                    ? version
                    : '$version ($build)',
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _PublisherCard extends StatelessWidget {
  const _PublisherCard();

  @override
  Widget build(BuildContext context) => _InformationCard(
    title: settingsInformationLabel(context, '开发者与联系信息'),
    children: [
      _InformationField(
        label: settingsInformationLabel(context, '开发者'),
        value: SettingsPublisherInformation.developerName ??
            settingsInformationLabel(context, '待补充'),
      ),
      _InformationField(
        label: settingsInformationLabel(context, '支持邮箱'),
        value: SettingsPublisherInformation.supportEmail ??
            settingsInformationLabel(context, '待补充'),
      ),
      _InformationField(
        label: settingsInformationLabel(context, '隐私政策网址'),
        value: SettingsPublisherInformation.privacyPolicyUrl ??
            settingsInformationLabel(context, '待补充'),
      ),
    ],
  );
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.title,
    this.body,
    this.children = const [],
  });

  final String title;
  final String? body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          if (body != null)
            Text(body!, style: const TextStyle(height: 1.6)),
          ...children,
        ],
      ),
    ),
  );
}

class _InformationField extends StatelessWidget {
  const _InformationField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        SelectableText(value),
      ],
    ),
  );
}

const _labels = <String, Map<String, String>>{
  'zh': {},
  'tw': {
    '隐私与条款': '隱私與條款',
    '隐私政策': '隱私政策',
    '使用条款': '使用條款',
    '权限说明': '權限說明',
    '数据存储与删除': '資料儲存與刪除',
    '联系与反馈': '聯絡與回饋',
    '关于 ClPlan': '關於 ClPlan',
    '文档状态': '文件狀態',
    '草案：开发者及联系信息待补充。正式发布前需完善。': '草案：開發者及聯絡資訊待補充。正式發布前需完善。',
    '文档日期': '文件日期',
    '读取中…': '讀取中…',
    '版本信息暂不可用': '版本資訊暫不可用',
    '离线记录个人行程、计划与任务。': '離線記錄個人行程、計畫與任務。',
    '版本': '版本',
    '开发者': '開發者',
    '待补充': '待補充',
    '开源许可': '開源授權',
    '开发者与联系信息': '開發者與聯絡資訊',
    '支持邮箱': '支援信箱',
    '隐私政策网址': '隱私政策網址',
  },
  'en': {
    '隐私与条款': 'Privacy & terms',
    '隐私政策': 'Privacy policy',
    '使用条款': 'Terms of use',
    '权限说明': 'Permissions',
    '数据存储与删除': 'Data storage & deletion',
    '联系与反馈': 'Contact & feedback',
    '关于 ClPlan': 'About ClPlan',
    '文档状态': 'Document status',
    '草案：开发者及联系信息待补充。正式发布前需完善。': 'Draft: developer and contact details are pending. Complete them before release.',
    '文档日期': 'Document date',
    '读取中…': 'Loading…',
    '版本信息暂不可用': 'Version information unavailable',
    '离线记录个人行程、计划与任务。': 'Keep personal schedules, plans and tasks offline.',
    '版本': 'Version',
    '开发者': 'Developer',
    '待补充': 'To be provided',
    '开源许可': 'Open source licenses',
    '开发者与联系信息': 'Developer & contact details',
    '支持邮箱': 'Support email',
    '隐私政策网址': 'Privacy policy URL',
  },
  'ja': {
    '隐私与条款': 'プライバシーと規約',
    '隐私政策': 'プライバシーポリシー',
    '使用条款': '利用規約',
    '权限说明': 'アクセス権限',
    '数据存储与删除': 'データの保存と削除',
    '联系与反馈': 'お問い合わせ',
    '关于 ClPlan': 'ClPlan について',
    '文档状态': '文書の状態',
    '草案：开发者及联系信息待补充。正式发布前需完善。': '草案：開発者と連絡先は未設定です。正式公開前に補完が必要です。',
    '文档日期': '文書の日付',
    '读取中…': '読み込み中…',
    '版本信息暂不可用': 'バージョン情報を取得できません',
    '离线记录个人行程、计划与任务。': '個人の予定、計画、タスクをオフラインで記録します。',
    '版本': 'バージョン',
    '开发者': '開発者',
    '待补充': '未設定',
    '开源许可': 'オープンソースライセンス',
    '开发者与联系信息': '開発者と連絡先',
    '支持邮箱': 'サポートメール',
    '隐私政策网址': 'プライバシーポリシー URL',
  },
  'ko': {
    '隐私与条款': '개인정보 및 약관',
    '隐私政策': '개인정보 처리방침',
    '使用条款': '이용약관',
    '权限说明': '권한 안내',
    '数据存储与删除': '데이터 저장 및 삭제',
    '联系与反馈': '문의 및 피드백',
    '关于 ClPlan': 'ClPlan 정보',
    '文档状态': '문서 상태',
    '草案：开发者及联系信息待补充。正式发布前需完善。': '초안: 개발자 및 연락처 정보가 미정입니다. 정식 출시 전에 보완해야 합니다.',
    '文档日期': '문서 날짜',
    '读取中…': '불러오는 중…',
    '版本信息暂不可用': '버전 정보를 불러올 수 없습니다',
    '离线记录个人行程、计划与任务。': '개인 일정, 계획 및 할 일을 오프라인으로 기록합니다.',
    '版本': '버전',
    '开发者': '개발자',
    '待补充': '추후 제공',
    '开源许可': '오픈 소스 라이선스',
    '开发者与联系信息': '개발자 및 연락처',
    '支持邮箱': '지원 이메일',
    '隐私政策网址': '개인정보 처리방침 URL',
  },
};

const _documents = <String, Map<SettingsInformationPage, List<(String, String)>>>{
  'zh': {
    SettingsInformationPage.privacy: [
      ('适用范围', '本政策说明 ClPlan 当前版本如何处理个人行程、计划和任务数据，以及系统权限、文件操作和 App Store 服务涉及的信息。'),
      ('本地处理的数据', '你录入的行程、计划、任务、日期时间、备注、进度、标签，以及手动添加的联系人姓名、电话和备注，保存在设备上的应用数据中，用于展示、检索、统计和提醒。应用还保存界面偏好和提醒调度记录。'),
      ('账号、服务器与分析', '当前版本无需注册账号，不提供开发者服务器上的云同步，未接入广告、行为分析或向开发者上传行程数据的服务。开发者无法通过应用远程读取或恢复你的本地计划。'),
      ('系统权限与提醒', '通知和闹铃由设备系统处理，提醒内容可能显示在锁屏或通知中心，可在系统设置中管理权限与预览。安全锁调用系统的 Face ID 或设备验证，应用只接收验证结果，不获取面容特征或设备密码。联系人为手动录入，不读取系统通讯录。'),
      ('文件与主动分享', '导入只处理你选择的表格文件。导出会在设备上生成临时表格，并交由系统分享界面发送或保存。你选择的接收应用、文件服务或接收人将获得导出内容；其后续处理适用各自规则。导出文件未由 ClPlan 加密，请妥善保管。'),
      ('Apple 服务与购买记录', '打赏通过 Apple App Store 内购完成，商品查询、购买和评价页面涉及 Apple 网络服务。ClPlan 在本地保存商品标识、交易标识、时间及处理状态，用于核验和防止重复处理；不接收银行卡资料。Apple 服务的数据处理适用 Apple 的相关政策。'),
      ('保留、删除与系统备份', '本地数据保留至你通过应用删除相关记录或通过系统删除应用数据。已经导出的文件、其他应用中的副本和系统备份需分别管理。当前应用未提供完整备份与恢复功能，也未提供应用自身的云同步；设备数据仍可能按你的系统设置进入 iCloud 或电脑备份。'),
      ('政策更新与联系', '后续版本如调整数据处理方式，应同步更新本政策及文档日期。隐私问题可通过下方支持联系方式联系开发者；尚未填写的主体、邮箱和公开政策地址将在正式发布前补齐。'),
    ],
    SettingsInformationPage.permissions: [
      ('通知', '用于按你设置的时间提醒计划和任务。拒绝或关闭通知不影响记录与查看，但会影响通知提醒。通知内容可能包含计划或任务名称，可在系统设置中调整通知预览。'),
      ('闹铃', '在支持 AlarmKit 的系统上，用于你主动设置的闹铃提醒。需要系统授权，当前实现要求 iOS 26 或更高版本；不支持或未授权时该提醒方式不可用。权限可在系统设置中管理。'),
      ('Face ID 与设备验证', '仅在启用安全锁后，用于启动应用或导出数据前验证设备所有者。验证由系统完成，ClPlan 不获取生物特征或设备密码。可在“安全锁”中调整验证范围；安全锁不等于数据库或表格文件加密。'),
      ('文件选择与系统分享', '导入使用系统文件选择器，导出使用系统分享界面。只在你主动操作时处理所选文件或交付导出内容；如果选择云盘等文件服务，其联网及保存行为由对应服务处理。'),
      ('其他系统数据', '当前版本不读取系统通讯录、系统日历、定位、相机、麦克风或照片库。应用内联系人及行程由你手动录入或通过所选表格导入。'),
    ],
    SettingsInformationPage.data: [
      ('存储与安全锁', '计划、任务、联系人和设置保存在设备本地。安全锁控制应用启动和导出前的系统验证，并不对业务数据库或导出表格另行加密。请同时保护设备密码及已经导出的文件。'),
      ('导出与备份范围', '“表格与数据”分别导出计划和联系人，可按模板再次导入。这些表格不等于完整数据库备份，不能据此保证恢复全部任务、历史记录、提醒与设置。导入前请确认预览和覆盖范围。'),
      ('修改与删除', '在相应的计划、任务或联系人入口管理记录。删除主任务前需先处理其子任务，删除计划前需先处理计划内任务。删除联系人配置不会移除已保存计划和任务中的联系人快照；如需删除这些信息，需一并编辑相关记录。删除本地记录不会删除已导出文件或其他位置的副本。'),
      ('卸载、换机与系统备份', '从系统中“删除 App”可能使本地数据丢失；“卸载 App”与“删除 App”的数据保留行为不同。换机或重新安装后能否恢复取决于可用的系统备份，不由 ClPlan 保证。请在操作前保存需要的导出文件，并单独管理系统备份及副本。'),
    ],
    SettingsInformationPage.terms: [
      ('应用用途', 'ClPlan 用于个人行程、计划与任务记录。你保留自行录入内容的权利，并应确保有权录入、导入或分享其中涉及的他人信息。'),
      ('提醒与重要事项', '通知和闹铃受系统版本、权限、设备状态及系统调度影响，不能保证所有情况下都准时送达。对重要事项请自行核对，并设置必要的备用提醒。'),
      ('本地数据与使用责任', '请在删除、导入、卸载或换机前确认数据处理范围并保存重要资料。表格导出不构成完整备份，开发者无法远程恢复只存于设备的记录。安全锁不替代设备安全措施。'),
      ('自愿打赏', '打赏为通过 App Store 完成的可重复消耗型购买，不解锁功能，不构成订阅，也不承诺具体开发排期。消耗型打赏不提供恢复购买；购买及退款按 Apple 的相关规则处理。'),
      ('第三方许可与更新', '应用使用的开源组件按各自许可证提供，可在“关于 ClPlan”的“开源许可”中查阅。后续版本如变更功能或条款，应同步更新说明。本草案不限制适用法律赋予用户的权利。'),
    ],
    SettingsInformationPage.contact: [
      ('问题反馈', '反馈时可提供应用版本、系统版本、操作步骤及错误现象。请遮盖截图中的私人行程、联系人和电话，不要发送设备密码或支付凭据。'),
      ('支持渠道', '支持邮箱和开发者信息尚待补充，当前页面不提供在线提交功能。ClPlan 不会自动上传计划或诊断文件。'),
    ],
  },
  'tw': {
    SettingsInformationPage.privacy: [
      ('適用範圍', '本政策說明 ClPlan 目前版本如何處理個人行程、計畫和任務資料，以及系統權限、檔案操作和 App Store 服務涉及的資訊。'),
      ('本機處理的資料', '你輸入的行程、計畫、任務、日期時間、備註、進度、標籤，以及手動新增的聯絡人姓名、電話和備註，儲存在裝置上的應用程式資料中，用於顯示、搜尋、統計和提醒。應用程式亦會儲存介面偏好和提醒排程紀錄。'),
      ('帳號、伺服器與分析', '目前版本無需註冊帳號，不提供開發者伺服器上的雲端同步，未接入廣告、行為分析或向開發者上傳行程資料的服務。開發者無法透過應用程式遠端讀取或復原你的本機計畫。'),
      ('系統權限與提醒', '通知和鬧鈴由裝置系統處理，提醒內容可能顯示在鎖定畫面或通知中心，可在系統設定中管理權限與預覽。安全鎖呼叫系統的 Face ID 或裝置驗證，應用程式只接收驗證結果，不取得面容特徵或裝置密碼。聯絡人為手動輸入，不讀取系統通訊錄。'),
      ('檔案與主動分享', '匯入只處理你選擇的試算表檔案。匯出會在裝置上產生暫存試算表，並交由系統分享介面傳送或儲存。你選擇的接收應用程式、檔案服務或接收人將取得匯出內容；其後續處理適用各自規則。匯出檔案未由 ClPlan 加密，請妥善保管。'),
      ('Apple 服務與購買紀錄', '打賞透過 Apple App Store App 內購買完成，商品查詢、購買和評價頁面涉及 Apple 網路服務。ClPlan 在本機儲存商品識別碼、交易識別碼、時間及處理狀態，用於核驗和防止重複處理；不接收銀行卡資料。Apple 服務的資料處理適用 Apple 的相關政策。'),
      ('保留、刪除與系統備份', '本機資料保留至你透過應用程式刪除相關紀錄或透過系統刪除應用程式資料。已匯出的檔案、其他應用程式中的副本和系統備份需分別管理。目前應用程式未提供完整備份與復原功能，也未提供自身的雲端同步；裝置資料仍可能依你的系統設定進入 iCloud 或電腦備份。'),
      ('政策更新與聯絡', '後續版本如調整資料處理方式，應同步更新本政策及文件日期。隱私問題可透過下方支援聯絡方式聯絡開發者；尚未填寫的主體、信箱和公開政策網址將在正式發布前補齊。'),
    ],
    SettingsInformationPage.permissions: [
      ('通知', '用於按你設定的時間提醒計畫和任務。拒絕或關閉通知不影響記錄與查看，但會影響通知提醒。通知內容可能包含計畫或任務名稱，可在系統設定中調整通知預覽。'),
      ('鬧鈴', '在支援 AlarmKit 的系統上，用於你主動設定的鬧鈴提醒。需要系統授權，目前實作要求 iOS 26 或更新版本；不支援或未授權時此提醒方式不可用。權限可在系統設定中管理。'),
      ('Face ID 與裝置驗證', '僅在啟用安全鎖後，用於啟動應用程式或匯出資料前驗證裝置擁有者。驗證由系統完成，ClPlan 不取得生物特徵或裝置密碼。可在「安全鎖」中調整驗證範圍；安全鎖不等於資料庫或試算表檔案加密。'),
      ('檔案選擇與系統分享', '匯入使用系統檔案選擇器，匯出使用系統分享介面。只在你主動操作時處理所選檔案或交付匯出內容；若選擇雲端硬碟等檔案服務，其連線及儲存行為由對應服務處理。'),
      ('其他系統資料', '目前版本不讀取系統通訊錄、系統行事曆、定位、相機、麥克風或照片圖庫。應用程式內聯絡人及行程由你手動輸入或透過所選試算表匯入。'),
    ],
    SettingsInformationPage.data: [
      ('儲存與安全鎖', '計畫、任務、聯絡人和設定儲存在裝置本機。安全鎖控制應用程式啟動和匯出前的系統驗證，並不對業務資料庫或匯出試算表另行加密。請同時保護裝置密碼及已匯出的檔案。'),
      ('匯出與備份範圍', '「表格與資料」分別匯出計畫和聯絡人，可按範本再次匯入。這些試算表不等於完整資料庫備份，不能據此保證復原全部任務、歷史紀錄、提醒與設定。匯入前請確認預覽和覆寫範圍。'),
      ('修改與刪除', '在對應的計畫、任務或聯絡人入口管理紀錄。刪除主任務前需先處理其子任務，刪除計畫前需先處理計畫內任務。刪除聯絡人設定不會移除已儲存計畫和任務中的聯絡人快照；如需刪除這些資訊，需一併編輯相關紀錄。刪除本機紀錄不會刪除已匯出檔案或其他位置的副本。'),
      ('移除、換機與系統備份', '在系統中「刪除 App」可能使本機資料遺失；「卸載 App」與「刪除 App」的資料保留行為不同。換機或重新安裝後能否復原取決於可用的系統備份，不由 ClPlan 保證。請在操作前儲存需要的匯出檔案，並單獨管理系統備份及副本。'),
    ],
    SettingsInformationPage.terms: [
      ('應用程式用途', 'ClPlan 用於個人行程、計畫與任務記錄。你保留自行輸入內容的權利，並應確保有權輸入、匯入或分享其中涉及的他人資訊。'),
      ('提醒與重要事項', '通知和鬧鈴受系統版本、權限、裝置狀態及系統排程影響，不能保證所有情況下都準時送達。對重要事項請自行核對，並設定必要的備用提醒。'),
      ('本機資料與使用責任', '請在刪除、匯入、移除 App 或換機前確認資料處理範圍並儲存重要資料。試算表匯出不構成完整備份，開發者無法遠端復原只存於裝置的紀錄。安全鎖不替代裝置安全措施。'),
      ('自願打賞', '打賞為透過 App Store 完成的可重複消耗型購買，不解鎖功能，不構成訂閱，也不承諾具體開發排程。消耗型打賞不提供恢復購買；購買及退款依 Apple 的相關規則處理。'),
      ('第三方授權與更新', '應用程式使用的開源元件依各自授權條款提供，可在「關於 ClPlan」的「開源授權」中查閱。後續版本如變更功能或條款，應同步更新說明。本草案不限制適用法律賦予使用者的權利。'),
    ],
    SettingsInformationPage.contact: [
      ('問題回饋', '回饋時可提供應用程式版本、系統版本、操作步驟及錯誤現象。請遮蓋截圖中的私人行程、聯絡人和電話，不要傳送裝置密碼或付款憑證。'),
      ('支援管道', '支援信箱和開發者資訊尚待補充，目前頁面不提供線上提交功能。ClPlan 不會自動上傳計畫或診斷檔案。'),
    ],
  },
  'en': {
    SettingsInformationPage.privacy: [
      ('Scope', 'This policy describes how the current version of ClPlan handles personal schedules, plans and tasks, and information involved in system permissions, file operations and App Store services.'),
      ('Data processed on your device', 'Schedules, plans, tasks, dates, times, notes, progress, tags and manually added contact names, phone numbers and notes are stored in app data on your device for display, search, statistics and reminders. The app also stores interface preferences and reminder scheduling records.'),
      ('Accounts, servers and analytics', 'The current version requires no account, provides no cloud sync through a developer server, and includes no advertising, behavioral analytics or service that uploads your schedules to the developer. The developer cannot remotely read or recover your local plans through the app.'),
      ('System permissions and reminders', 'The device handles notifications and alarms. Reminder content may appear on the Lock Screen or in Notification Center; manage permissions and previews in system settings. The security lock uses system Face ID or device authentication. The app receives only the result, not facial features or your device passcode. Contacts are entered manually; the app does not read system contacts.'),
      ('Files and sharing', 'Import processes only spreadsheet files you select. Export creates a temporary spreadsheet on the device and passes it to the system share sheet for sending or saving. The receiving app, file service or person you select receives the exported content and handles it under their own rules. ClPlan does not encrypt exported files; keep them secure.'),
      ('Apple services and purchase records', 'Tips use Apple App Store in-app purchases. Product queries, purchases and review pages involve Apple network services. ClPlan locally stores product and transaction identifiers, timestamps and processing status for verification and to prevent duplicate processing. It does not receive bank card details. Apple services handle data under Apple’s applicable policies.'),
      ('Retention, deletion and system backups', 'Local data remains until you delete the relevant records in the app or remove app data through the system. Exported files, copies in other apps and system backups must be managed separately. The app currently provides neither full backup and restore nor its own cloud sync. Device data may still be included in iCloud or computer backups according to your system settings.'),
      ('Policy updates and contact', 'Changes to data handling in future versions should be reflected in this policy and its document date. For privacy questions, use the support contact below. The publisher identity, email and public policy URL that are still missing must be completed before release.'),
    ],
    SettingsInformationPage.permissions: [
      ('Notifications', 'Used to remind you about plans and tasks at the times you set. Denying or disabling notifications does not prevent recording or viewing data, but affects notification delivery. Notifications may include plan or task names; adjust previews in system settings.'),
      ('Alarms', 'Used for alarms you explicitly set on systems supporting AlarmKit. System permission is required; the current implementation requires iOS 26 or later. This delivery method is unavailable on unsupported systems or without authorization. Manage permissions in system settings.'),
      ('Face ID and device authentication', 'When the security lock is enabled, the system verifies the device owner before app access or data export. ClPlan does not receive biometric data or the device passcode. Adjust the verification scope under Security lock. The lock does not encrypt the database or spreadsheet files.'),
      ('File selection and sharing', 'Import uses the system file picker; export uses the system share sheet. Selected files are processed or exports handed over only when you initiate the operation. If you choose a cloud file service, that service controls its own network and storage behavior.'),
      ('Other system data', 'The current version does not read system contacts, system calendars, location, camera, microphone or photo library data. In-app contacts and schedules are entered manually or imported from spreadsheets you select.'),
    ],
    SettingsInformationPage.data: [
      ('Storage and security lock', 'Plans, tasks, contacts and settings are stored locally on your device. The security lock controls system authentication before app access and export; it does not separately encrypt the app database or exported spreadsheets. Protect your device passcode and exported files.'),
      ('Export and backup scope', 'Tables & data exports plans and contacts separately for reimport using the templates. These spreadsheets are not a full database backup and cannot guarantee restoration of all tasks, history, reminders or settings. Review the preview and overwrite scope before importing.'),
      ('Editing and deletion', 'Manage records in their plan, task or contact screens. Handle subtasks before deleting a parent task and tasks within a plan before deleting the plan. Deleting a contact definition does not remove contact snapshots already saved in plans or tasks; edit those records separately. Deleting local records does not delete exported files or copies elsewhere.'),
      ('App removal, new devices and backups', 'Using Delete App in system settings may remove local data. Offload App and Delete App retain data differently. Recovery after reinstalling or changing devices depends on available system backups and is not guaranteed by ClPlan. Save any exports you need beforehand and manage system backups and other copies separately.'),
    ],
    SettingsInformationPage.terms: [
      ('Purpose', 'ClPlan is for recording personal schedules, plans and tasks. You retain rights to content you enter and should ensure you have permission to enter, import or share information about others.'),
      ('Reminders and important events', 'Notification and alarm delivery depends on system version, permissions, device state and system scheduling. Delivery on time cannot be guaranteed in every situation. Verify important events yourself and arrange backup reminders where needed.'),
      ('Local data and your responsibilities', 'Before deleting, importing, removing the app or changing devices, confirm the affected data and save important information. Spreadsheet exports are not full backups. The developer cannot remotely restore records held only on your device. The security lock does not replace device security measures.'),
      ('Voluntary tips', 'Tips are repeatable consumable purchases through the App Store. They do not unlock features, create a subscription or promise a development schedule. Consumable tips do not offer purchase restoration. Purchases and refunds are subject to Apple’s applicable rules.'),
      ('Third-party licenses and updates', 'Open source components are provided under their respective licenses, available under About ClPlan → Open source licenses. Changes to features or terms in future versions should be reflected in these documents. This draft does not limit rights granted by applicable law.'),
    ],
    SettingsInformationPage.contact: [
      ('Reporting a problem', 'Include the app version, system version, steps and error symptoms when reporting an issue. Hide private schedules, contacts and phone numbers in screenshots. Do not send device passcodes or payment credentials.'),
      ('Support channels', 'The support email and developer details have yet to be provided. This page currently offers no online submission. ClPlan does not automatically upload plans or diagnostic files.'),
    ],
  },
  'ja': {
    SettingsInformationPage.privacy: [
      ('適用範囲', '本ポリシーは、ClPlan の現行バージョンにおける個人の予定、計画、タスクの取り扱いと、システム権限、ファイル操作、App Store サービスに関する情報の取り扱いを説明します。'),
      ('端末内で扱うデータ', '入力した予定、計画、タスク、日時、メモ、進捗、タグ、および手動で追加した連絡先の氏名、電話番号、メモを端末のアプリデータに保存し、表示、検索、集計、リマインダーに使用します。表示設定とリマインダーのスケジュール記録も保存します。'),
      ('アカウント、サーバー、分析', '現行バージョンはアカウント登録が不要です。開発者サーバーによるクラウド同期、広告、行動分析、開発者への予定データ送信サービスは組み込まれていません。開発者はアプリ経由で端末内の計画を遠隔で読み取ったり復元したりできません。'),
      ('システム権限と通知', '通知とアラームは端末のシステムが処理します。内容はロック画面や通知センターに表示される場合があり、権限とプレビューはシステム設定で管理できます。セキュリティロックはシステムの Face ID または端末認証を利用し、アプリは認証結果のみを受け取ります。顔の特徴や端末パスコードは取得しません。連絡先は手動入力で、システムの連絡先は読み取りません。'),
      ('ファイルと共有', 'インポートでは選択した表計算ファイルのみを処理します。エクスポートでは端末内に一時ファイルを作成し、システムの共有画面で送信または保存します。選択したアプリ、ファイルサービス、受信者にデータが渡り、その後の取り扱いには各自の規則が適用されます。ClPlan は出力ファイルを暗号化しないため、適切に保管してください。'),
      ('Apple サービスと購入記録', 'チップは Apple App Store のアプリ内課金で処理します。商品照会、購入、レビュー画面では Apple のネットワークサービスを利用します。ClPlan は検証と重複処理防止のため、商品 ID、取引 ID、日時、処理状態を端末内に保存します。カード情報は受け取りません。Apple サービスのデータ処理には Apple の関連ポリシーが適用されます。'),
      ('保存、削除、システムバックアップ', '端末内のデータは、アプリで該当記録を削除するか、システムでアプリデータを削除するまで保存されます。出力ファイル、他のアプリ内のコピー、システムバックアップは別途管理が必要です。現在、完全なバックアップと復元、独自のクラウド同期は提供していません。ただし、システム設定により iCloud やコンピュータのバックアップに含まれる場合があります。'),
      ('更新とお問い合わせ', '今後データの取り扱いを変更する場合は、本ポリシーと文書の日付も更新する必要があります。プライバシーに関するお問い合わせ先は下記をご覧ください。未設定の運営主体、メール、公開ポリシー URL は正式公開前に補完が必要です。'),
    ],
    SettingsInformationPage.permissions: [
      ('通知', '設定した日時に計画やタスクを通知します。拒否または無効化しても記録と閲覧はできますが、通知によるリマインダーに影響します。計画名やタスク名が表示される場合があるため、プレビューはシステム設定で調整してください。'),
      ('アラーム', 'AlarmKit 対応システムで、明示的に設定したアラームに使用します。システムの許可が必要で、現行実装は iOS 26 以降に対応します。非対応または未許可の場合は使用できません。権限はシステム設定で管理できます。'),
      ('Face ID と端末認証', 'セキュリティロックを有効にすると、起動時やエクスポート前にシステムが端末所有者を認証します。ClPlan は生体情報や端末パスコードを取得しません。認証範囲は「セキュリティロック」で設定できます。データベースや表計算ファイルを暗号化する機能ではありません。'),
      ('ファイル選択と共有', 'インポートにはシステムのファイル選択、エクスポートにはシステムの共有画面を使用します。選択したファイルの処理や出力データの受け渡しは、自分で操作した場合のみ行います。クラウドストレージを選択した場合、その通信や保存は該当サービスが処理します。'),
      ('その他のシステムデータ', '現行バージョンは、システムの連絡先、カレンダー、位置情報、カメラ、マイク、写真ライブラリを読み取りません。アプリ内の連絡先と予定は手動入力または選択した表計算ファイルからのインポートで登録します。'),
    ],
    SettingsInformationPage.data: [
      ('保存とセキュリティロック', '計画、タスク、連絡先、設定は端末内に保存します。セキュリティロックは起動時とエクスポート前のシステム認証を制御し、業務データベースや出力ファイルを別途暗号化しません。端末パスコードと出力ファイルを適切に管理してください。'),
      ('エクスポートとバックアップの範囲', '「表とデータ」では計画と連絡先を別々に出力し、テンプレート形式で再インポートできます。完全なデータベースバックアップではなく、すべてのタスク、履歴、通知、設定の復元は保証できません。インポート前にプレビューと上書き範囲を確認してください。'),
      ('編集と削除', '各計画、タスク、連絡先の画面で管理します。親タスクの削除前に子タスクを、計画の削除前に計画内タスクを処理する必要があります。連絡先設定を削除しても、保存済みの計画やタスク内の連絡先スナップショットは消えません。該当記録を個別に編集してください。端末内の記録を削除しても、出力ファイルや他の場所のコピーは削除されません。'),
      ('アプリ削除、機種変更、バックアップ', 'システムの「App を削除」で端末内データが失われる場合があります。「App を取り除く」と「App を削除」ではデータの保持方法が異なります。再インストールや機種変更後の復元は、利用可能なシステムバックアップに依存し、ClPlan は保証しません。事前に必要なファイルを保存し、バックアップやコピーは別途管理してください。'),
    ],
    SettingsInformationPage.terms: [
      ('用途', 'ClPlan は個人の予定、計画、タスクを記録するアプリです。入力内容に関する権利は利用者に帰属します。他者の情報を入力、インポート、共有する場合は、必要な権限があることを確認してください。'),
      ('リマインダーと重要な予定', '通知とアラームはシステムのバージョン、権限、端末状態、システムのスケジュール処理に影響され、常に時間どおり届くとは保証できません。重要な予定は自分で確認し、必要に応じて予備のリマインダーを用意してください。'),
      ('端末内データと利用上の責任', '削除、インポート、アプリの削除、機種変更の前に対象データを確認し、重要な資料を保存してください。表計算ファイルの出力は完全なバックアップではありません。開発者は端末内だけにある記録を遠隔で復元できません。セキュリティロックは端末の安全対策を代替しません。'),
      ('任意のチップ', 'チップは App Store の繰り返し購入可能な消耗型課金です。機能の解放やサブスクリプションではなく、具体的な開発日程を約束しません。消耗型チップの購入復元は提供しません。購入と返金には Apple の関連規則が適用されます。'),
      ('第三者ライセンスと更新', 'オープンソース部品は各ライセンスに従って提供され、「ClPlan について」の「オープンソースライセンス」で確認できます。機能や規約を変更する場合は説明も更新する必要があります。本草案は適用法が利用者に認める権利を制限しません。'),
    ],
    SettingsInformationPage.contact: [
      ('不具合の報告', 'アプリとシステムのバージョン、操作手順、エラーの状況をお知らせください。スクリーンショット内の個人的な予定、連絡先、電話番号は隠してください。端末パスコードや支払い認証情報は送らないでください。'),
      ('サポート窓口', 'サポートメールと開発者情報は未設定です。現在、このページにオンライン送信機能はありません。ClPlan が計画や診断ファイルを自動送信することはありません。'),
    ],
  },
  'ko': {
    SettingsInformationPage.privacy: [
      ('적용 범위', '이 방침은 현재 버전의 ClPlan이 개인 일정, 계획, 할 일 데이터와 시스템 권한, 파일 작업 및 App Store 서비스 관련 정보를 처리하는 방식을 설명합니다.'),
      ('기기에서 처리하는 데이터', '입력한 일정, 계획, 할 일, 날짜와 시간, 메모, 진행 상황, 태그 및 직접 추가한 연락처 이름, 전화번호와 메모는 기기의 앱 데이터에 저장되어 표시, 검색, 통계 및 알림에 사용됩니다. 화면 설정과 알림 예약 기록도 저장합니다.'),
      ('계정, 서버 및 분석', '현재 버전은 계정 등록이 필요 없으며 개발자 서버를 통한 클라우드 동기화를 제공하지 않습니다. 광고, 행동 분석 또는 개발자에게 일정을 업로드하는 서비스도 포함하지 않습니다. 개발자는 앱을 통해 로컬 계획을 원격으로 읽거나 복구할 수 없습니다.'),
      ('시스템 권한 및 알림', '알림과 알람은 기기 시스템이 처리합니다. 내용이 잠금 화면이나 알림 센터에 표시될 수 있으며 권한과 미리보기는 시스템 설정에서 관리할 수 있습니다. 보안 잠금은 시스템 Face ID 또는 기기 인증을 사용합니다. 앱은 인증 결과만 받으며 얼굴 특징이나 기기 암호는 받지 않습니다. 연락처는 직접 입력하며 시스템 연락처를 읽지 않습니다.'),
      ('파일 및 공유', '가져오기는 선택한 스프레드시트 파일만 처리합니다. 내보내기는 기기에 임시 파일을 만들고 시스템 공유 화면으로 전달하여 전송하거나 저장합니다. 선택한 앱, 파일 서비스 또는 수신자가 내보낸 내용을 받으며 이후 처리는 각자의 규칙에 따릅니다. ClPlan은 내보낸 파일을 암호화하지 않으므로 안전하게 보관해 주세요.'),
      ('Apple 서비스 및 구매 기록', '후원은 Apple App Store 앱 내 구입으로 처리됩니다. 상품 조회, 구매 및 평가 페이지는 Apple 네트워크 서비스를 사용합니다. ClPlan은 검증 및 중복 처리 방지를 위해 상품 식별자, 거래 식별자, 시간 및 처리 상태를 기기에 저장하며 카드 정보는 받지 않습니다. Apple 서비스의 데이터 처리는 Apple의 관련 정책에 따릅니다.'),
      ('보관, 삭제 및 시스템 백업', '로컬 데이터는 앱에서 해당 기록을 삭제하거나 시스템에서 앱 데이터를 제거할 때까지 보관됩니다. 내보낸 파일, 다른 앱의 사본 및 시스템 백업은 별도로 관리해야 합니다. 현재 전체 백업과 복원 및 앱 자체 클라우드 동기화를 제공하지 않습니다. 다만 시스템 설정에 따라 데이터가 iCloud 또는 컴퓨터 백업에 포함될 수 있습니다.'),
      ('방침 변경 및 문의', '향후 데이터 처리 방식이 변경되면 이 방침과 문서 날짜도 업데이트해야 합니다. 개인정보 관련 문의는 아래 지원 연락처를 이용해 주세요. 아직 입력되지 않은 운영 주체, 이메일 및 공개 방침 URL은 정식 출시 전에 보완해야 합니다.'),
    ],
    SettingsInformationPage.permissions: [
      ('알림', '설정한 시간에 계획과 할 일을 알려 줍니다. 거부하거나 끄더라도 기록과 조회는 가능하지만 알림 전달에 영향을 줍니다. 계획이나 할 일 이름이 포함될 수 있으므로 시스템 설정에서 미리보기를 조정해 주세요.'),
      ('알람', 'AlarmKit을 지원하는 시스템에서 직접 설정한 알람에 사용됩니다. 시스템 권한이 필요하며 현재 구현은 iOS 26 이상을 요구합니다. 지원하지 않거나 권한이 없으면 이 방식은 사용할 수 없습니다. 권한은 시스템 설정에서 관리할 수 있습니다.'),
      ('Face ID 및 기기 인증', '보안 잠금을 켠 경우 앱 시작 또는 데이터 내보내기 전에 시스템이 기기 소유자를 인증합니다. ClPlan은 생체 정보나 기기 암호를 받지 않습니다. 인증 범위는 보안 잠금에서 설정할 수 있습니다. 이 잠금은 데이터베이스나 스프레드시트 암호화가 아닙니다.'),
      ('파일 선택 및 공유', '가져오기는 시스템 파일 선택기를, 내보내기는 시스템 공유 화면을 사용합니다. 직접 작업할 때만 선택한 파일을 처리하거나 내보낸 내용을 전달합니다. 클라우드 파일 서비스를 선택하면 해당 서비스가 네트워크 및 저장 동작을 처리합니다.'),
      ('기타 시스템 데이터', '현재 버전은 시스템 연락처, 캘린더, 위치, 카메라, 마이크 또는 사진 보관함 데이터를 읽지 않습니다. 앱 내 연락처와 일정은 직접 입력하거나 선택한 스프레드시트에서 가져옵니다.'),
    ],
    SettingsInformationPage.data: [
      ('저장 및 보안 잠금', '계획, 할 일, 연락처 및 설정은 기기에 로컬로 저장됩니다. 보안 잠금은 앱 시작과 내보내기 전 시스템 인증을 제어하며 앱 데이터베이스나 내보낸 파일을 별도로 암호화하지 않습니다. 기기 암호와 내보낸 파일을 안전하게 관리해 주세요.'),
      ('내보내기 및 백업 범위', '표 및 데이터에서 계획과 연락처를 각각 내보내고 템플릿 형식으로 다시 가져올 수 있습니다. 전체 데이터베이스 백업이 아니므로 모든 할 일, 기록, 알림 및 설정 복원을 보장할 수 없습니다. 가져오기 전에 미리보기와 덮어쓰기 범위를 확인해 주세요.'),
      ('수정 및 삭제', '해당 계획, 할 일 또는 연락처 화면에서 기록을 관리합니다. 상위 할 일을 삭제하기 전에 하위 할 일을, 계획을 삭제하기 전에 계획 안의 할 일을 처리해야 합니다. 연락처 설정을 삭제해도 이미 저장된 계획과 할 일의 연락처 사본은 제거되지 않습니다. 해당 기록을 별도로 수정해야 합니다. 로컬 기록 삭제는 내보낸 파일이나 다른 위치의 사본을 삭제하지 않습니다.'),
      ('앱 제거, 기기 변경 및 백업', '시스템에서 앱 삭제를 선택하면 로컬 데이터가 사라질 수 있습니다. 앱 정리하기와 앱 삭제는 데이터를 보관하는 방식이 다릅니다. 재설치나 기기 변경 후 복구 여부는 사용 가능한 시스템 백업에 달려 있으며 ClPlan이 보장하지 않습니다. 작업 전에 필요한 파일을 저장하고 시스템 백업과 사본은 별도로 관리해 주세요.'),
    ],
    SettingsInformationPage.terms: [
      ('앱의 용도', 'ClPlan은 개인 일정, 계획 및 할 일을 기록하는 앱입니다. 직접 입력한 콘텐츠에 대한 권리는 사용자에게 있습니다. 타인에 관한 정보를 입력, 가져오기 또는 공유할 때 필요한 권한이 있는지 확인해 주세요.'),
      ('알림과 중요한 일정', '알림과 알람은 시스템 버전, 권한, 기기 상태 및 시스템 예약 처리의 영향을 받으므로 모든 상황에서 정시 전달을 보장할 수 없습니다. 중요한 일정은 직접 확인하고 필요한 경우 보조 알림을 설정해 주세요.'),
      ('로컬 데이터 및 사용 책임', '삭제, 가져오기, 앱 제거 또는 기기 변경 전에 대상 데이터를 확인하고 중요한 정보를 저장해 주세요. 스프레드시트 내보내기는 전체 백업이 아닙니다. 개발자는 기기에만 있는 기록을 원격으로 복원할 수 없습니다. 보안 잠금은 기기 보안 조치를 대신하지 않습니다.'),
      ('자발적 후원', '후원은 App Store를 통한 반복 가능한 소모성 구입입니다. 기능 잠금 해제나 구독이 아니며 특정 개발 일정을 약속하지 않습니다. 소모성 후원은 구입 복원을 제공하지 않습니다. 구매 및 환불에는 Apple의 관련 규칙이 적용됩니다.'),
      ('타사 라이선스 및 변경', '오픈 소스 구성 요소에는 각각의 라이선스가 적용되며 ClPlan 정보의 오픈 소스 라이선스에서 확인할 수 있습니다. 향후 기능이나 약관이 변경되면 설명도 업데이트해야 합니다. 이 초안은 관련 법률이 사용자에게 부여한 권리를 제한하지 않습니다.'),
    ],
    SettingsInformationPage.contact: [
      ('문제 신고', '앱 버전, 시스템 버전, 작업 단계 및 오류 증상을 함께 알려 주세요. 스크린샷의 개인 일정, 연락처 및 전화번호는 가려 주세요. 기기 암호나 결제 인증 정보는 보내지 마세요.'),
      ('지원 채널', '지원 이메일과 개발자 정보는 추후 제공됩니다. 현재 이 페이지에는 온라인 제출 기능이 없습니다. ClPlan은 계획이나 진단 파일을 자동으로 업로드하지 않습니다.'),
    ],
  },
};
