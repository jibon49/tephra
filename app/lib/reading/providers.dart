// © 2026 Tephra. All rights reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'parse_service.dart';

/// Provider for [ParseService].
final parseServiceProvider = Provider<ParseService>(
  (ref) => const ParseService(),
);
