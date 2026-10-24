// © 2026 Tephra. All rights reserved.

import 'package:logging/logging.dart';

import 'sticky_color.dart';

final _logger = Logger('stickies.model');

bool _isValidDate(int year, int month, int day) {
  if (month < 1 || month > 12) return false;
  if (day < 1) return false;
  const daysInMonths = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  var maxDay = daysInMonths[month];
  if (month == 2) {
    final isLeap = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
    if (isLeap) maxDay = 29;
  }
  return day <= maxDay;
}

bool _isValidTime(int hour, int minute) {
  return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
}

/// A calendar date without time of day or timezone (wall-clock date).
final class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  /// Parses 'YYYY-MM-DD'. Returns null if invalid or ranges out of bounds.
  static LocalDate? tryParse(String s) {
    final trimmed = s.trim();
    final parts = trimmed.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (!_isValidDate(y, m, d)) return null;
    return LocalDate(y, m, d);
  }

  /// Formats as 'YYYY-MM-DD'.
  String format() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalDate &&
          year == other.year &&
          month == other.month &&
          day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => format();
}

/// A wall-clock date and time (no timezone offset attached).
final class LocalDateTime implements Comparable<LocalDateTime> {
  const LocalDateTime(this.year, this.month, this.day, this.hour, this.minute);

  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;

  /// Parses 'YYYY-MM-DDTHH:mm', 'YYYY-MM-DDTHH:mm:ss', or 'YYYY-MM-DD HH:mm'.
  /// Drops seconds. Returns null if invalid or date/time ranges out of bounds.
  static LocalDateTime? tryParse(String s) {
    final trimmed = s.trim();
    // Split on 'T' or space
    final isT = trimmed.contains('T');
    final sep = isT ? 'T' : ' ';
    final parts = trimmed.split(sep);
    if (parts.length != 2) return null;

    final datePart = parts[0].trim();
    final timePart = parts[1].trim();

    final date = LocalDate.tryParse(datePart);
    if (date == null) return null;

    final timeComponents = timePart.split(':');
    if (timeComponents.length < 2) return null;
    final h = int.tryParse(timeComponents[0]);
    final m = int.tryParse(timeComponents[1]);
    if (h == null || m == null) return null;
    if (!_isValidTime(h, m)) return null;

    return LocalDateTime(date.year, date.month, date.day, h, m);
  }

  /// Formats as 'YYYY-MM-DDTHH:mm'.
  String format() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    final h = hour.toString().padLeft(2, '0');
    final min = minute.toString().padLeft(2, '0');
    return '$y-$m-${d}T$h:$min';
  }

  @override
  int compareTo(LocalDateTime other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    if (day != other.day) return day.compareTo(other.day);
    if (hour != other.hour) return hour.compareTo(other.hour);
    return minute.compareTo(other.minute);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalDateTime &&
          year == other.year &&
          month == other.month &&
          day == other.day &&
          hour == other.hour &&
          minute == other.minute;

  @override
  int get hashCode => Object.hash(year, month, day, hour, minute);

  @override
  String toString() => format();
}

/// Metadata extracted from a note's frontmatter regarding its sticky state.
final class StickyMeta {
  const StickyMeta({
    required this.isSticky,
    this.color = StickyColor.fallback,
    this.pinned = false,
    this.remind,
    this.expire,
    this.locked = false,
  });

  final bool isSticky;
  final StickyColor color;
  final bool pinned;
  final LocalDateTime? remind;
  final LocalDate? expire;
  final bool locked;

  /// Extracts sticky metadata from a frontmatter map. Never throws.
  static StickyMeta fromFrontmatter(Map<String, Object?> fm) {
    final isSticky = _parseBool(fm['tephra-sticky']);
    final color = StickyColor.parse(fm['sticky-color']);
    final pinned = _parseBool(fm['sticky-pinned']);
    final locked = _parseBool(fm['sticky-locked']);

    LocalDateTime? remind;
    final rawRemind = fm['sticky-remind'];
    if (rawRemind is String) {
      remind = LocalDateTime.tryParse(rawRemind);
      if (remind == null) {
        _logger.warning('Invalid sticky-remind format');
      }
    } else if (rawRemind is DateTime) {
      if (_isValidDate(rawRemind.year, rawRemind.month, rawRemind.day) &&
          _isValidTime(rawRemind.hour, rawRemind.minute)) {
        remind = LocalDateTime(
          rawRemind.year,
          rawRemind.month,
          rawRemind.day,
          rawRemind.hour,
          rawRemind.minute,
        );
      } else {
        _logger.warning('Invalid sticky-remind DateTime values');
      }
    }

    LocalDate? expire;
    final rawExpire = fm['sticky-expire'];
    if (rawExpire is String) {
      expire = LocalDate.tryParse(rawExpire);
    } else if (rawExpire is DateTime) {
      if (_isValidDate(rawExpire.year, rawExpire.month, rawExpire.day)) {
        expire = LocalDate(rawExpire.year, rawExpire.month, rawExpire.day);
      }
    }

    return StickyMeta(
      isSticky: isSticky,
      color: color,
      pinned: pinned,
      remind: remind,
      expire: expire,
      locked: locked,
    );
  }

  static bool _parseBool(Object? val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is String) {
      final s = val.trim().toLowerCase();
      return s == 'true' || s == 'yes';
    }
    return false;
  }

  StickyMeta copyWith({
    bool? isSticky,
    StickyColor? color,
    bool? pinned,
    LocalDateTime? Function()? remind,
    LocalDate? Function()? expire,
    bool? locked,
  }) {
    return StickyMeta(
      isSticky: isSticky ?? this.isSticky,
      color: color ?? this.color,
      pinned: pinned ?? this.pinned,
      remind: remind != null ? remind() : this.remind,
      expire: expire != null ? expire() : this.expire,
      locked: locked ?? this.locked,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StickyMeta &&
          isSticky == other.isSticky &&
          color == other.color &&
          pinned == other.pinned &&
          remind == other.remind &&
          expire == other.expire &&
          locked == other.locked;

  @override
  int get hashCode =>
      Object.hash(isSticky, color, pinned, remind, expire, locked);

  @override
  String toString() =>
      'StickyMeta(isSticky: $isSticky, color: $color, pinned: $pinned, remind: $remind, expire: $expire, locked: $locked)';
}
