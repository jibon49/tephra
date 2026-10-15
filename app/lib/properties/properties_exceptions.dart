// © 2026 Tephra. All rights reserved.

import 'package:tephra_core/tephra_core.dart';

/// Thrown when attempting to rename a property key to an existing key.
final class PropertyKeyExistsException extends TephraException {
  const PropertyKeyExistsException(this.key)
    : super('Property key already exists: $key');

  final String key;
}

/// Thrown when raw YAML frontmatter cannot be parsed or is not a map.
final class PropertiesYamlException extends TephraException {
  const PropertiesYamlException(super.message, this.line);

  final int line;
}
