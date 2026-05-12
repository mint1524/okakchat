import 'package:flutter/foundation.dart';

class PlatformUtils {
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;
  static bool get isMobile => isIOS || isAndroid;
  static bool get isDesktop =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
  static bool get isWeb => kIsWeb;
  static bool get supportsAgentMode => isDesktop; // web excluded — dart:io unavailable
  static bool get supportsCommands => isDesktop;
}
