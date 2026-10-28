import 'package:local_auth/local_auth.dart';

enum AppAuthenticationOutcome {
  success,
  canceled,
  unavailable,
  lockedOut,
  failed,
}

class AppAuthenticationResult {
  const AppAuthenticationResult(this.outcome, {this.message});

  final AppAuthenticationOutcome outcome;
  final String? message;

  bool get succeeded => outcome == AppAuthenticationOutcome.success;
  bool get canceled => outcome == AppAuthenticationOutcome.canceled;
}

class AppSecurityService {
  AppSecurityService({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  static const exportAuthorizationDuration = Duration(minutes: 30);

  final LocalAuthentication _localAuthentication;
  final Stopwatch _processClock = Stopwatch()..start();
  Duration? _lastSuccessfulExportAuthentication;
  Future<AppAuthenticationResult>? _activeAuthentication;

  bool get hasValidExportAuthorization {
    final authenticatedAt = _lastSuccessfulExportAuthentication;
    return authenticatedAt != null &&
        _processClock.elapsed - authenticatedAt <
            exportAuthorizationDuration;
  }

  Future<bool> isDeviceAuthenticationAvailable() async {
    try {
      return await _localAuthentication.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<AppAuthenticationResult> authenticate({
    required String localizedReason,
  }) {
    final active = _activeAuthentication;
    if (active != null) return active;

    final request = _authenticate(localizedReason);
    _activeAuthentication = request;
    return request.whenComplete(() {
      if (identical(_activeAuthentication, request)) {
        _activeAuthentication = null;
      }
    });
  }

  Future<AppAuthenticationResult> authorizeExport({
    required bool authenticationRequired,
    required String localizedReason,
  }) async {
    if (!authenticationRequired || hasValidExportAuthorization) {
      return const AppAuthenticationResult(
        AppAuthenticationOutcome.success,
      );
    }

    final result = await authenticate(localizedReason: localizedReason);
    if (result.succeeded) {
      _lastSuccessfulExportAuthentication = _processClock.elapsed;
    }
    return result;
  }

  void clearExportAuthorization() {
    _lastSuccessfulExportAuthentication = null;
  }

  Future<AppAuthenticationResult> _authenticate(
    String localizedReason,
  ) async {
    try {
      if (!await _localAuthentication.isDeviceSupported()) {
        return const AppAuthenticationResult(
          AppAuthenticationOutcome.unavailable,
        );
      }
      final authenticated = await _localAuthentication.authenticate(
        localizedReason: localizedReason,
        persistAcrossBackgrounding: true,
      );
      return AppAuthenticationResult(
        authenticated
            ? AppAuthenticationOutcome.success
            : AppAuthenticationOutcome.canceled,
      );
    } on LocalAuthException catch (exception) {
      final outcome = switch (exception.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.userRequestedFallback =>
          AppAuthenticationOutcome.canceled,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
        LocalAuthExceptionCode.uiUnavailable =>
          AppAuthenticationOutcome.unavailable,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          AppAuthenticationOutcome.lockedOut,
        _ => AppAuthenticationOutcome.failed,
      };
      return AppAuthenticationResult(
        outcome,
        message: exception.description,
      );
    } catch (exception) {
      return AppAuthenticationResult(
        AppAuthenticationOutcome.failed,
        message: exception.toString(),
      );
    }
  }
}
