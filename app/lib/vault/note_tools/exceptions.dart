// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Thrown when the daily note date format is invalid.
final class DailyNotesConfigException extends TephraException {
  const DailyNotesConfigException(super.message);
}

/// Thrown when the templates folder is not configured.
final class TemplatesNotConfiguredException extends TephraException {
  const TemplatesNotConfiguredException([
    super.message = 'Templates folder not configured',
  ]);
}

/// Thrown when the unique note prefix format is invalid.
final class UniqueNoteConfigException extends TephraException {
  const UniqueNoteConfigException(super.message);
}
