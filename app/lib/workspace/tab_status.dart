// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tephra_core/tephra_core.dart';

/// Indicates whether a given file path has unsaved edits.
///
/// In Step 01.13 this always returns `false`. Step 01.20 updates this to read the
/// live document buffer state.
final tabDirtyProvider = Provider.family<bool, VaultPath>((ref, path) => false);
