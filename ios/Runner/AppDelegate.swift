import Flutter
import UIKit
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
import SwiftUI
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var alarmKitBridge: AlarmKitBridge?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    alarmKitBridge = AlarmKitBridge(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }
}

private final class AlarmKitBridge {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "vip.ichiki.javalee.clplan/alarm_kit",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      #if canImport(AlarmKit)
      if #available(iOS 26.0, *) { result(true) } else { result(false) }
      #else
      result(false)
      #endif
    case "authorizationState":
      #if canImport(AlarmKit)
      if #available(iOS 26.0, *) {
        result(Self.authorizationName(AlarmManager.shared.authorizationState))
      } else {
        result("unsupported")
      }
      #else
      result("unsupported")
      #endif
    case "requestAuthorization":
      requestAuthorization(result: result)
    case "scheduleAlarm":
      scheduleAlarm(call.arguments, result: result)
    case "cancelAlarm":
      changeAlarm(call.arguments, operation: "cancel", result: result)
    case "stopAlarm":
      changeAlarm(call.arguments, operation: "stop", result: result)
    case "listAlarms":
      listAlarms(result: result)
    case "openAppSettings":
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(false)
        return
      }
      UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestAuthorization(result: @escaping FlutterResult) {
    #if canImport(AlarmKit)
    guard #available(iOS 26.0, *) else { result("unsupported"); return }
    Task { @MainActor in
      do {
        let state = try await AlarmManager.shared.requestAuthorization()
        result(Self.authorizationName(state))
      } catch {
        result(FlutterError(
          code: "alarm_authorization",
          message: error.localizedDescription,
          details: nil
        ))
      }
    }
    #else
    result("unsupported")
    #endif
  }

  private func scheduleAlarm(_ rawArguments: Any?, result: @escaping FlutterResult) {
    #if canImport(AlarmKit)
    guard #available(iOS 26.0, *) else { result("unsupported"); return }
    guard
      let arguments = rawArguments as? [String: Any],
      let alarmIdText = arguments["alarmId"] as? String,
      let alarmId = UUID(uuidString: alarmIdText),
      let title = arguments["title"] as? String,
      let milliseconds = arguments["fireAtMilliseconds"] as? NSNumber
    else {
      result(FlutterError(code: "alarm_arguments", message: "闹铃参数无效", details: nil))
      return
    }
    let fireDate = Date(timeIntervalSince1970: milliseconds.doubleValue / 1000)
    let stopButton = AlarmButton(
      text: LocalizedStringResource(stringLiteral: "停止"),
      textColor: .white,
      systemImageName: "stop.fill"
    )
    let presentation = AlarmPresentation(
      alert: AlarmPresentation.Alert(
        title: LocalizedStringResource(stringLiteral: title),
        stopButton: stopButton
      )
    )
    let attributes = AlarmAttributes<ClPlanAlarmMetadata>(
      presentation: presentation,
      metadata: ClPlanAlarmMetadata(),
      tintColor: Color(
        red: 222.0 / 255.0,
        green: 88.0 / 255.0,
        blue: 63.0 / 255.0
      )
    )
    let configuration = AlarmManager.AlarmConfiguration.alarm(
      schedule: .fixed(fireDate),
      attributes: attributes
    )
    Task { @MainActor in
      do {
        _ = try await AlarmManager.shared.schedule(
          id: alarmId,
          configuration: configuration
        )
        result(nil)
      } catch {
        result(FlutterError(
          code: "alarm_schedule",
          message: error.localizedDescription,
          details: nil
        ))
      }
    }
    #else
    result("unsupported")
    #endif
  }

  private func changeAlarm(
    _ rawArguments: Any?,
    operation: String,
    result: @escaping FlutterResult
  ) {
    #if canImport(AlarmKit)
    guard #available(iOS 26.0, *) else { result("unsupported"); return }
    guard
      let arguments = rawArguments as? [String: Any],
      let alarmIdText = arguments["alarmId"] as? String,
      let alarmId = UUID(uuidString: alarmIdText)
    else {
      result(FlutterError(code: "alarm_arguments", message: "闹铃 ID 无效", details: nil))
      return
    }
    do {
      if operation == "stop" {
        try AlarmManager.shared.stop(id: alarmId)
      } else {
        try AlarmManager.shared.cancel(id: alarmId)
      }
      result(nil)
    } catch {
      result(FlutterError(
        code: "alarm_\(operation)",
        message: error.localizedDescription,
        details: nil
      ))
    }
    #else
    result("unsupported")
    #endif
  }

  private func listAlarms(result: FlutterResult) {
    #if canImport(AlarmKit)
    guard #available(iOS 26.0, *) else { result([String]()); return }
    do {
      result(try AlarmManager.shared.alarms.map { $0.id.uuidString.lowercased() })
    } catch {
      result(FlutterError(
        code: "alarm_list",
        message: error.localizedDescription,
        details: nil
      ))
    }
    #else
    result([String]())
    #endif
  }

  #if canImport(AlarmKit)
  @available(iOS 26.0, *)
  private static func authorizationName(
    _ state: AlarmManager.AuthorizationState
  ) -> String {
    switch state {
    case .notDetermined: return "not_determined"
    case .denied: return "denied"
    case .authorized: return "authorized"
    @unknown default: return "not_determined"
    }
  }
  #endif
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
private struct ClPlanAlarmMetadata: AlarmMetadata {}
#endif
