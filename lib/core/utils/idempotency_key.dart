import 'dart:math';

abstract final class IdempotencyKey {
  /// 2^32 as a literal: `1 << 32` evaluates to 0 when compiled to JavaScript (web).
  static const int _range = 0x100000000;
  static final Random _random = Random.secure();

  static String generate() => '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(_range)}';
}
