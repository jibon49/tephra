// © 2026 Tephra. All rights reserved.

import 'moment_format.dart';

/// Context provided to the template expansion engine.
final class TemplateContext {
  const TemplateContext({
    required this.title,
    required this.date,
    required this.now,
    this.dateFormat = 'YYYY-MM-DD',
    this.timeFormat = 'HH:mm',
    this.locale = 'en',
  });

  final String title;
  final DateTime date;
  final DateTime now;
  final String dateFormat;
  final String timeFormat;
  final String locale;
}

final _varRegex = RegExp(r'\{\{\s*(title|date|time)\s*(?::([^}]*))?\}\}');

/// Expands template variables in [template] in a single pass.
///
/// Unknown variables such as `{{foo}}` are left as written.
String applyTemplate(String template, TemplateContext ctx) {
  if (template.isEmpty) return template;

  return template.replaceAllMapped(_varRegex, (match) {
    final name = match.group(1)!;
    final formatParam = match.group(2);

    switch (name) {
      case 'title':
        return ctx.title;
      case 'date':
        final fmt = (formatParam == null || formatParam.isEmpty)
            ? ctx.dateFormat
            : formatParam;
        return formatMoment(ctx.date, fmt, locale: ctx.locale);
      case 'time':
        final fmt = (formatParam == null || formatParam.isEmpty)
            ? ctx.timeFormat
            : formatParam;
        return formatMoment(ctx.now, fmt, locale: ctx.locale);
      default:
        return match.group(0)!;
    }
  });
}
