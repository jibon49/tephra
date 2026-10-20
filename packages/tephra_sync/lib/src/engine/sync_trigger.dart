// © 2026 Tephra. All rights reserved.

/// Event trigger that initiated a sync cycle.
enum SyncTrigger {
  /// User initiated sync manually via UI button or command.
  manual,

  /// Triggered after a local file save / debounced edit.
  save,

  /// Triggered on initial app launch.
  appStart,

  /// Triggered when the application returns to foreground.
  appResume,

  /// Triggered by periodic remote changes poll timer.
  remotePoll,

  /// Triggered by OS background execution worker.
  background,

  /// Triggered on an automated standing schedule.
  schedule,

  /// Triggered during initial vault setup / remote vault connection.
  setup,
}
