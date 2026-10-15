// © 2026 Tephra. All rights reserved.

import 'package:intl/intl.dart';

enum MomentFormatError {
  empty,
  unbalancedBracket,
  forbiddenCharacter,
  parentSegment,
  noDateTokens,
}

final _tokenRegex = RegExp(
  r'\[([^\]]*)\]|YYYY|YY|MMMM|MMM|MM|M|Do|DD|D|dddd|ddd|HH|H|hh|h|mm|m|ss|s|A|a',
);

String _getEnglishOrdinal(int day) {
  if (day == 11 || day == 12 || day == 13) {
    return '${day}th';
  }
  switch (day % 10) {
    case 1:
      return '${day}st';
    case 2:
      return '${day}nd';
    case 3:
      return '${day}rd';
    default:
      return '${day}th';
  }
}

const _monthsFullEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _monthsShortEn = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _weekdaysFullEn = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _weekdaysShortEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Formats [t] with a Moment-style [format]. Unknown characters are copied as written.
/// [locale] affects names (MMMM, ddd…) only; 'en' needs no initialisation.
String formatMoment(DateTime t, String format, {String locale = 'en'}) {
  if (format.isEmpty) return '';

  final sb = StringBuffer();
  var lastEnd = 0;

  for (final match in _tokenRegex.allMatches(format)) {
    if (match.start > lastEnd) {
      sb.write(format.substring(lastEnd, match.start));
    }

    final token = match.group(0)!;
    if (token.startsWith('[') && token.endsWith(']')) {
      sb.write(match.group(1)!);
    } else {
      switch (token) {
        case 'YYYY':
          sb.write(t.year.toString().padLeft(4, '0'));
          break;
        case 'YY':
          sb.write((t.year % 100).toString().padLeft(2, '0'));
          break;
        case 'MMMM':
          if (locale == 'en') {
            sb.write(_monthsFullEn[t.month - 1]);
          } else {
            sb.write(DateFormat('MMMM', locale).format(t));
          }
          break;
        case 'MMM':
          if (locale == 'en') {
            sb.write(_monthsShortEn[t.month - 1]);
          } else {
            sb.write(DateFormat('MMM', locale).format(t));
          }
          break;
        case 'MM':
          sb.write(t.month.toString().padLeft(2, '0'));
          break;
        case 'M':
          sb.write(t.month.toString());
          break;
        case 'DD':
          sb.write(t.day.toString().padLeft(2, '0'));
          break;
        case 'D':
          sb.write(t.day.toString());
          break;
        case 'Do':
          if (locale == 'en') {
            sb.write(_getEnglishOrdinal(t.day));
          } else {
            sb.write(t.day.toString());
          }
          break;
        case 'dddd':
          if (locale == 'en') {
            sb.write(_weekdaysFullEn[t.weekday - 1]);
          } else {
            sb.write(DateFormat('EEEE', locale).format(t));
          }
          break;
        case 'ddd':
          if (locale == 'en') {
            sb.write(_weekdaysShortEn[t.weekday - 1]);
          } else {
            sb.write(DateFormat('EEE', locale).format(t));
          }
          break;
        case 'HH':
          sb.write(t.hour.toString().padLeft(2, '0'));
          break;
        case 'H':
          sb.write(t.hour.toString());
          break;
        case 'hh':
          final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
          sb.write(h12.toString().padLeft(2, '0'));
          break;
        case 'h':
          final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
          sb.write(h12.toString());
          break;
        case 'mm':
          sb.write(t.minute.toString().padLeft(2, '0'));
          break;
        case 'm':
          sb.write(t.minute.toString());
          break;
        case 'ss':
          sb.write(t.second.toString().padLeft(2, '0'));
          break;
        case 's':
          sb.write(t.second.toString());
          break;
        case 'A':
          sb.write(t.hour < 12 ? 'AM' : 'PM');
          break;
        case 'a':
          sb.write(t.hour < 12 ? 'am' : 'pm');
          break;
        default:
          sb.write(token);
          break;
      }
    }
    lastEnd = match.end;
  }

  if (lastEnd < format.length) {
    sb.write(format.substring(lastEnd));
  }

  return sb.toString();
}

/// Parses [text] written with [format]; null when it does not match or the date is invalid.
/// Needs year, month and day tokens; time tokens are optional.
DateTime? parseMoment(String text, String format, {String locale = 'en'}) {
  if (format.isEmpty || text.isEmpty) return null;

  var hasYear = false;
  var hasMonth = false;
  var hasDay = false;

  final patternBuffer = StringBuffer('^');
  final captures = <String>[];
  var lastEnd = 0;

  for (final match in _tokenRegex.allMatches(format)) {
    if (match.start > lastEnd) {
      patternBuffer.write(
        RegExp.escape(format.substring(lastEnd, match.start)),
      );
    }

    final token = match.group(0)!;
    if (token.startsWith('[') && token.endsWith(']')) {
      patternBuffer.write(RegExp.escape(match.group(1)!));
    } else {
      switch (token) {
        case 'YYYY':
          hasYear = true;
          captures.add('YYYY');
          patternBuffer.write(r'(\d{4})');
          break;
        case 'YY':
          hasYear = true;
          captures.add('YY');
          patternBuffer.write(r'(\d{2})');
          break;
        case 'MMMM':
          hasMonth = true;
          captures.add('MMMM');
          patternBuffer.write(r'([a-zA-Z]+)');
          break;
        case 'MMM':
          hasMonth = true;
          captures.add('MMM');
          patternBuffer.write(r'([a-zA-Z]+)');
          break;
        case 'MM':
          hasMonth = true;
          captures.add('MM');
          patternBuffer.write(r'(\d{2})');
          break;
        case 'M':
          hasMonth = true;
          captures.add('M');
          patternBuffer.write(r'(\d{1,2})');
          break;
        case 'Do':
          hasDay = true;
          captures.add('Do');
          patternBuffer.write(r'(\d{1,2})(?:st|nd|rd|th)');
          break;
        case 'DD':
          hasDay = true;
          captures.add('DD');
          patternBuffer.write(r'(\d{2})');
          break;
        case 'D':
          hasDay = true;
          captures.add('D');
          patternBuffer.write(r'(\d{1,2})');
          break;
        case 'dddd':
        case 'ddd':
          patternBuffer.write(r'(?:[a-zA-Z]+)');
          break;
        case 'HH':
          captures.add('HH');
          patternBuffer.write(r'(\d{2})');
          break;
        case 'H':
          captures.add('H');
          patternBuffer.write(r'(\d{1,2})');
          break;
        case 'hh':
          captures.add('hh');
          patternBuffer.write(r'(\d{2})');
          break;
        case 'h':
          captures.add('h');
          patternBuffer.write(r'(\d{1,2})');
          break;
        case 'mm':
          captures.add('mm');
          patternBuffer.write(r'(\d{2})');
          break;
        case 'm':
          captures.add('m');
          patternBuffer.write(r'(\d{1,2})');
          break;
        case 'ss':
          captures.add('ss');
          patternBuffer.write(r'(\d{2})');
          break;
        case 's':
          captures.add('s');
          patternBuffer.write(r'(\d{1,2})');
          break;
        case 'A':
        case 'a':
          captures.add('ampm');
          patternBuffer.write(r'(AM|PM|am|pm)');
          break;
        default:
          patternBuffer.write(RegExp.escape(token));
          break;
      }
    }
    lastEnd = match.end;
  }

  if (lastEnd < format.length) {
    patternBuffer.write(RegExp.escape(format.substring(lastEnd)));
  }
  patternBuffer.write(r'$');

  if (!hasYear || !hasMonth || !hasDay) {
    return null;
  }

  final regex = RegExp(patternBuffer.toString(), caseSensitive: false);
  final match = regex.firstMatch(text);
  if (match == null) return null;

  var year = 0;
  var month = 0;
  var day = 0;
  var hour = 0;
  var minute = 0;
  var second = 0;
  String? ampm;
  var is12Hour = false;

  for (var i = 0; i < captures.length; i++) {
    final capType = captures[i];
    final strVal = match.group(i + 1)!;

    switch (capType) {
      case 'YYYY':
        year = int.parse(strVal);
        break;
      case 'YY':
        final y = int.parse(strVal);
        year = y > 68 ? 1900 + y : 2000 + y;
        break;
      case 'MMMM':
        final idx = _monthsFullEn
            .map((m) => m.toLowerCase())
            .toList()
            .indexOf(strVal.toLowerCase());
        if (idx == -1) return null;
        month = idx + 1;
        break;
      case 'MMM':
        final idx = _monthsShortEn
            .map((m) => m.toLowerCase())
            .toList()
            .indexOf(strVal.toLowerCase());
        if (idx == -1) return null;
        month = idx + 1;
        break;
      case 'MM':
      case 'M':
        month = int.parse(strVal);
        break;
      case 'Do':
      case 'DD':
      case 'D':
        day = int.parse(strVal);
        break;
      case 'HH':
      case 'H':
        hour = int.parse(strVal);
        break;
      case 'hh':
      case 'h':
        hour = int.parse(strVal);
        is12Hour = true;
        break;
      case 'mm':
      case 'm':
        minute = int.parse(strVal);
        break;
      case 'ss':
      case 's':
        second = int.parse(strVal);
        break;
      case 'ampm':
        ampm = strVal.toUpperCase();
        break;
    }
  }

  if (is12Hour) {
    if (ampm == 'PM') {
      if (hour < 12) hour += 12;
    } else if (ampm == 'AM') {
      if (hour == 12) hour = 0;
    }
  }

  // Validate calendar bounds via DateTime round-trip
  final dt = DateTime(year, month, day, hour, minute, second);
  if (dt.year != year ||
      dt.month != month ||
      dt.day != day ||
      dt.hour != hour ||
      dt.minute != minute ||
      dt.second != second) {
    return null;
  }

  return dt;
}

/// Null when valid. [forFileName] also rejects characters that cannot appear in a file name;
/// [requireDate] demands year, month and day tokens (daily notes).
MomentFormatError? validateMomentFormat(
  String format, {
  bool forFileName = false,
  bool requireDate = false,
}) {
  if (format.isEmpty) return MomentFormatError.empty;

  // Check unbalanced brackets
  var inBracket = false;
  for (var i = 0; i < format.length; i++) {
    final c = format[i];
    if (c == '[') {
      if (inBracket) return MomentFormatError.unbalancedBracket;
      inBracket = true;
    } else if (c == ']') {
      if (!inBracket) return MomentFormatError.unbalancedBracket;
      inBracket = false;
    }
  }
  if (inBracket) return MomentFormatError.unbalancedBracket;

  // Check parent segment `..`
  final parts = format.split('/');
  for (final p in parts) {
    if (p == '..') return MomentFormatError.parentSegment;
  }

  // Check forbidden characters for file name: \ : * ? " < > |
  if (forFileName) {
    final forbidden = RegExp(r'[\\:*?"<>|]');
    if (forbidden.hasMatch(format)) {
      return MomentFormatError.forbiddenCharacter;
    }
  }

  // Check requireDate: year, month, and day tokens outside brackets
  if (requireDate) {
    var hasYear = false;
    var hasMonth = false;
    var hasDay = false;

    for (final match in _tokenRegex.allMatches(format)) {
      final token = match.group(0)!;
      if (token.startsWith('[') && token.endsWith(']')) {
        continue;
      }
      if (token == 'YYYY' || token == 'YY') {
        hasYear = true;
      } else if (token == 'MMMM' ||
          token == 'MMM' ||
          token == 'MM' ||
          token == 'M') {
        hasMonth = true;
      } else if (token == 'DD' || token == 'D' || token == 'Do') {
        hasDay = true;
      }
    }

    if (!hasYear || !hasMonth || !hasDay) {
      return MomentFormatError.noDateTokens;
    }
  }

  return null;
}
