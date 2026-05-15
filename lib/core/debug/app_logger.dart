import 'package:flutter/foundation.dart';

/// Debug-only activity logger. All methods are no-ops in release builds.
///
/// Output format:
///   [HH:MM:SS.mmm][CATEGORY] message
///
/// Categories:
///   NAV   — screen / route changes
///   KEY   — hardware keyboard events
///   TAP   — button / tap events
///   TXT   — text field content changes
///   TOOL  — agent tool dispatch & result
///   STATE — provider state transitions
///   NET   — WebSocket / API events
///   ERR   — unexpected errors / exceptions
class AppLogger {
  AppLogger._();

  static void log(String category, String message) {
    if (!kDebugMode) return;
    final ts = DateTime.now();
    final h = ts.hour.toString().padLeft(2, '0');
    final m = ts.minute.toString().padLeft(2, '0');
    final s = ts.second.toString().padLeft(2, '0');
    final ms = ts.millisecond.toString().padLeft(3, '0');
    debugPrint('[$h:$m:$s.$ms][$category] $message');
  }

  static void nav(String msg) => log('NAV  ', msg);
  static void key(String msg) => log('KEY  ', msg);
  static void tap(String msg) => log('TAP  ', msg);
  static void text(String msg) => log('TXT  ', msg);
  static void tool(String msg) => log('TOOL ', msg);
  static void state(String msg) => log('STATE', msg);
  static void net(String msg) => log('NET  ', msg);
  static void err(String msg) => log('ERR ⚠', msg);

  /// Truncate long strings for readability in logs.
  static String trunc(String s, [int max = 120]) =>
      s.length <= max ? s : '${s.substring(0, max)}…';
}
