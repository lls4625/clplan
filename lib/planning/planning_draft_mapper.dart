import 'planning_models.dart';

class PlanningDraftMapper {
  const PlanningDraftMapper();

  PlanningDraft fromProposal(
    PlanningProposal proposal, {
    bool useRawTextAsTitle = false,
  }) => PlanningDraft(
    title: useRawTextAsTitle ? proposal.rawText.trim() : proposal.title.trim(),
    description: proposal.rawText.trim(),
    schedule: proposal.schedule,
    reminders: proposal.reminders,
    tags: proposal.tags,
  );
}
