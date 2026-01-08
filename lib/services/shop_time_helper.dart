import 'package:flutter/material.dart';

/// Utility class to check if the shop is currently open based on working hours.
class ShopTimeHelper {
  ShopTimeHelper._();

  /// Parses an "HH:mm" string into a [TimeOfDay].
  /// Returns null if parsing fails.
  static TimeOfDay? parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length != 2) return null;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  /// Converts a [TimeOfDay] to total minutes since midnight.
  static int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  /// Checks if the shop is currently open.
  ///
  /// [openStr] and [closeStr] should be in "HH:mm" format.
  /// Handles overnight hours correctly (e.g., open 18:00, close 02:00).
  ///
  /// Returns `true` if open, `false` if closed.
  /// Returns `true` if times are invalid or missing (fail-open behavior).
  static bool isShopOpen(String? openStr, String? closeStr) {
    // If no working hours set, assume always open
    if (openStr == null ||
        closeStr == null ||
        openStr.isEmpty ||
        closeStr.isEmpty) {
      return true;
    }

    final open = parseTime(openStr);
    final close = parseTime(closeStr);

    // If parsing fails, assume open (fail-open)
    if (open == null || close == null) {
      return true;
    }

    final now = TimeOfDay.now();
    final nowMinutes = _toMinutes(now);
    final openMinutes = _toMinutes(open);
    final closeMinutes = _toMinutes(close);

    // Case 1: Normal hours (open < close, same day)
    // Example: open 09:00, close 22:00
    if (openMinutes < closeMinutes) {
      return nowMinutes >= openMinutes && nowMinutes < closeMinutes;
    }

    // Case 2: Overnight hours (open > close, spans midnight)
    // Example: open 18:00, close 02:00
    // Shop is open from 18:00 to 23:59 OR from 00:00 to 02:00
    if (openMinutes > closeMinutes) {
      return nowMinutes >= openMinutes || nowMinutes < closeMinutes;
    }

    // Case 3: open == close (24-hour operation or edge case)
    // Treat as always open
    return true;
  }

  /// Formats a [TimeOfDay] to "HH:mm" string.
  static String formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
