enum ToolWorkflowRunStatus { idle, running, succeeded, failed, stopped }

class ToolWorkflowStep {
  const ToolWorkflowStep({required this.id, required this.label});

  final String id;
  final String label;
}

class ToolWorkflowRecipe {
  const ToolWorkflowRecipe({
    required this.id,
    required this.name,
    required this.description,
    required this.steps,
    required this.inputKinds,
    required this.outputPolicy,
    this.enabled = true,
  });

  final String id;
  final String name;
  final String description;
  final List<ToolWorkflowStep> steps;
  final List<String> inputKinds;
  final String outputPolicy;
  final bool enabled;
}

class ToolWorkflowRun {
  const ToolWorkflowRun({
    required this.taskId,
    required this.status,
    required this.currentStep,
    required this.inputSummary,
    required this.outputPaths,
    required this.logs,
    required this.startedAt,
    this.finishedAt,
  });

  final String taskId;
  final ToolWorkflowRunStatus status;
  final String currentStep;
  final String inputSummary;
  final List<String> outputPaths;
  final List<String> logs;
  final DateTime startedAt;
  final DateTime? finishedAt;
}

class ToolDashboardSnapshot {
  const ToolDashboardSnapshot({
    required this.recentTasks,
    required this.runningTasks,
    required this.recommendedRecipes,
  });

  final List<Object> recentTasks;
  final List<ToolWorkflowRun> runningTasks;
  final List<ToolWorkflowRecipe> recommendedRecipes;
}
