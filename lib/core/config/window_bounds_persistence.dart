import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../database/settings_repository.dart';

class WindowBoundsPersistence with WindowListener {
  WindowBoundsPersistence(this.settings);

  final SettingsRepository settings;
  Timer? _saveTimer;

  static Rect? decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, dynamic>) return null;
      final left = (value['left'] as num?)?.toDouble();
      final top = (value['top'] as num?)?.toDouble();
      final width = (value['width'] as num?)?.toDouble();
      final height = (value['height'] as num?)?.toDouble();
      if (left == null || top == null || width == null || height == null) {
        return null;
      }
      if (!left.isFinite || !top.isFinite || !width.isFinite || !height.isFinite) {
        return null;
      }
      if (width < 860 || height < 600 || width > 10000 || height > 10000) {
        return null;
      }
      return Rect.fromLTWH(left, top, width, height);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  void onWindowResize() => _scheduleSave();

  @override
  void onWindowMove() => _scheduleSave();

  @override
  void onWindowResized() => _scheduleSave();

  @override
  void onWindowMoved() => _scheduleSave();

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 650), _save);
  }

  Future<void> _save() async {
    try {
      if (await windowManager.isMaximized() || await windowManager.isFullScreen()) {
        return;
      }
      final bounds = await windowManager.getBounds();
      if (bounds.width < 860 || bounds.height < 600) return;
      await settings.putString(
        'window.bounds',
        jsonEncode({
          'left': bounds.left,
          'top': bounds.top,
          'width': bounds.width,
          'height': bounds.height,
        }),
      );
    } catch (_) {
      // Window persistence is best-effort and must not interrupt playback/UI.
    }
  }
}
