import 'package:flutter/material.dart';

extension ColorWithValues on Color {
  /// Mimics withValues(alpha: ...) by setting the alpha channel (0.0~1.0)
  Color withValues({double? alpha}) {
    if (alpha == null) return this;
    return withOpacity(alpha);
  }
}
