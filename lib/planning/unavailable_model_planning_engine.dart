import 'planning_engine.dart';
import 'planning_models.dart';

class UnavailableModelPlanningEngine implements PlanningEngine {
  const UnavailableModelPlanningEngine({
    this.state = PlanningAvailabilityState.notInstalled,
  });

  final PlanningAvailabilityState state;

  @override
  String get id => 'model.unavailable';

  @override
  PlanningEngineKind get kind => PlanningEngineKind.model;

  @override
  Future<PlanningAvailability> checkAvailability() async =>
      PlanningAvailability(
        state: state,
        reasonCode: 'planning.model.${state.name}',
      );

  @override
  Future<PlanningResult> generate(PlanningRequest request) {
    throw StateError('The model planning engine is unavailable.');
  }
}
