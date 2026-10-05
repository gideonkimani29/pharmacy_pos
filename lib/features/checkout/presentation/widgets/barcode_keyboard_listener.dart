import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_config.dart';

/// Detects HID (keyboard-emulating) barcode scanners.
///
/// Scanners send characters faster than a human types, followed by Enter. This
/// buffers rapid keystrokes and reports the code on Enter. Key events are not
/// consumed except for the terminating Enter of a detected scan, so manual
/// typing in text fields keeps working. Scans are ignored while a dialog or
/// other route is on top of the page that owns this widget.
class BarcodeKeyboardListener extends StatefulWidget {
  const BarcodeKeyboardListener({super.key, required this.onBarcode, required this.child});

  final ValueChanged<String> onBarcode;
  final Widget child;

  @override
  State<BarcodeKeyboardListener> createState() => _BarcodeKeyboardListenerState();
}

class _BarcodeKeyboardListenerState extends State<BarcodeKeyboardListener> {
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKeyAt;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    super.dispose();
  }

  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (ModalRoute.of(context)?.isCurrent != true) {
      _buffer.clear();
      return false;
    }

    final now = DateTime.now();
    final last = _lastKeyAt;
    if (last != null && now.difference(last) > AppConfig.scannerMaxKeyGap) _buffer.clear();
    _lastKeyAt = now;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      final code = _buffer.toString();
      _buffer.clear();
      if (code.length >= AppConfig.scannerMinLength) {
        widget.onBarcode(code);
        return true;
      }
      return false;
    }

    final character = event.character;
    if (character != null && character.length == 1 && _isBarcodeCharacter(character)) {
      _buffer.write(character);
    }
    return false;
  }

  bool _isBarcodeCharacter(String character) => RegExp(r'^[A-Za-z0-9\-]$').hasMatch(character);

  @override
  Widget build(BuildContext context) => widget.child;
}
