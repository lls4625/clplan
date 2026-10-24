import 'planning_models.dart';

/// Produces task-planning proposals without owning UI or persistence concerns.
abstract interface class PlanningEngine {
  String get id;

  PlanningEngineKind get kind;

  Future<PlanningAvailability> checkAvailability();

  Future<PlanningResult> generate(PlanningRequest request);
}
