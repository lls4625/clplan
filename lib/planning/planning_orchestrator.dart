import 'planning_engine.dart';
import 'planning_models.dart';

class PlanningOrchestrator implements PlanningEngine {
  const PlanningOrchestrator({
    required this.basicEngine,
    required this.modelEngine,
  });

  final PlanningEngine basicEngine;
  final PlanningEngine modelEngine;

  @override
  String get id => 'planning.orchestrator.v1';

  @override
  PlanningEngineKind get kind => PlanningEngineKind.basic;

  @override
  Future<PlanningAvailability> checkAvailability() =>
      basicEngine.checkAvailability();

  @override
  Future<PlanningResult> generate(PlanningRequest request) async {
    if (request.mode == PlanningMode.basic) {
      return basicEngine.generate(request);
    }

    final availability = await modelEngine.checkAvailability();
    if (availability.isAvailable) {
      try {
        return await modelEngine.generate(request);
      } catch (_) {
        return _basicFallback(request, PlanningFallbackReason.modelFailed);
      }
    }

    final reason = switch (availability.state) {
      PlanningAvailabilityState.notInstalled =>
        PlanningFallbackReason.modelNotInstalled,
      PlanningAvailabilityState.unsupported =>
        PlanningFallbackReason.modelUnsupported,
      PlanningAvailabilityState.unavailable =>
        PlanningFallbackReason.modelUnavailable,
      PlanningAvailabilityState.available => PlanningFallbackReason.modelFailed,
    };
    return _basicFallback(request, reason);
  }

  Future<PlanningResult> _basicFallback(
    PlanningRequest request,
    PlanningFallbackReason reason,
  ) async {
    final result = await basicEngine.generate(request);
    return PlanningResult(
      proposal: result.proposal,
      metadata: PlanningExecutionMetadata(
        requestId: result.metadata.requestId,
        requestedMode: request.mode,
        actualEngineId: result.metadata.actualEngineId,
        source: PlanningSource.basic,
        fallbackReason: reason,
        elapsed: result.metadata.elapsed,
      ),
    );
  }
}
