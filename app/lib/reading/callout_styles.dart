// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

/// Style representation of a callout block.
final class CalloutStyle {
  const CalloutStyle({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}

const _calloutStyles = <String, CalloutStyle>{
  'note': CalloutStyle(color: Color(0xFF086DDD), icon: Icons.edit_outlined),
  'abstract': CalloutStyle(
    color: Color(0xFF00BFBC),
    icon: Icons.assignment_outlined,
  ),
  'summary': CalloutStyle(
    color: Color(0xFF00BFBC),
    icon: Icons.assignment_outlined,
  ),
  'tldr': CalloutStyle(
    color: Color(0xFF00BFBC),
    icon: Icons.assignment_outlined,
  ),
  'info': CalloutStyle(color: Color(0xFF086DDD), icon: Icons.info_outline),
  'todo': CalloutStyle(
    color: Color(0xFF086DDD),
    icon: Icons.check_circle_outline,
  ),
  'tip': CalloutStyle(
    color: Color(0xFF00BFBC),
    icon: Icons.local_fire_department_outlined,
  ),
  'hint': CalloutStyle(
    color: Color(0xFF00BFBC),
    icon: Icons.local_fire_department_outlined,
  ),
  'important': CalloutStyle(
    color: Color(0xFF00BFBC),
    icon: Icons.local_fire_department_outlined,
  ),
  'success': CalloutStyle(color: Color(0xFF08B94E), icon: Icons.check),
  'check': CalloutStyle(color: Color(0xFF08B94E), icon: Icons.check),
  'done': CalloutStyle(color: Color(0xFF08B94E), icon: Icons.check),
  'question': CalloutStyle(color: Color(0xFFDB7800), icon: Icons.help_outline),
  'help': CalloutStyle(color: Color(0xFFDB7800), icon: Icons.help_outline),
  'faq': CalloutStyle(color: Color(0xFFDB7800), icon: Icons.help_outline),
  'warning': CalloutStyle(
    color: Color(0xFFDB7800),
    icon: Icons.warning_amber_outlined,
  ),
  'caution': CalloutStyle(
    color: Color(0xFFDB7800),
    icon: Icons.warning_amber_outlined,
  ),
  'attention': CalloutStyle(
    color: Color(0xFFDB7800),
    icon: Icons.warning_amber_outlined,
  ),
  'failure': CalloutStyle(color: Color(0xFFE9314C), icon: Icons.close),
  'fail': CalloutStyle(color: Color(0xFFE9314C), icon: Icons.close),
  'missing': CalloutStyle(color: Color(0xFFE9314C), icon: Icons.close),
  'danger': CalloutStyle(color: Color(0xFFE9314C), icon: Icons.bolt),
  'error': CalloutStyle(color: Color(0xFFE9314C), icon: Icons.bolt),
  'bug': CalloutStyle(
    color: Color(0xFFE9314C),
    icon: Icons.bug_report_outlined,
  ),
  'example': CalloutStyle(
    color: Color(0xFF7852EE),
    icon: Icons.format_list_bulleted,
  ),
  'quote': CalloutStyle(color: Color(0xFF9E9E9E), icon: Icons.format_quote),
  'cite': CalloutStyle(color: Color(0xFF9E9E9E), icon: Icons.format_quote),
};

const _defaultCalloutStyle = CalloutStyle(
  color: Color(0xFF086DDD),
  icon: Icons.edit_outlined,
);

/// Returns the [CalloutStyle] corresponding to [type] (case-insensitive).
CalloutStyle calloutStyleFor(String type) {
  final lower = type.trim().toLowerCase();
  return _calloutStyles[lower] ?? _defaultCalloutStyle;
}
