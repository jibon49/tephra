// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Thrown when the index database file is corrupt or unrecoverable.
class IndexCorruptException extends TephraException {
  const IndexCorruptException(super.message);
}

/// Thrown when an index query is invalid or fails.
class IndexQueryException extends TephraException {
  const IndexQueryException(super.message);
}

/// Thrown when the index is not available on this platform (e.g. web preview).
class IndexUnavailableException extends TephraException {
  const IndexUnavailableException([super.message = 'index unavailable on web']);
}
