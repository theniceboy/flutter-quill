import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../common/structs/horizontal_spacing.dart';
import '../../../../document/nodes/block.dart';
import '../../../../document/nodes/node.dart';
import '../../default_styles.dart';
import '../text_resolution.dart';

typedef LeadingBlockIndentWidth = HorizontalSpacing Function(
    Block block,
    BuildContext context,
    int count,
    LeadingBlockNumberPointWidth numberPointWidthDelegate);

typedef LeadingBlockNumberPointWidth = double Function(
    double fontSize, int count);

typedef TextSpanBuilder = InlineSpan Function(
  BuildContext context,
  Node node,
  int nodeOffset,
  String text,
  TextStyle? style,
  GestureRecognizer? recognizer,
);

TextSpan defaultSpanBuilder(
  BuildContext context,
  Node node,
  int textOffset,
  String text,
  TextStyle? style,
  GestureRecognizer? recognizer,
) =>
    TextSpan(
      text: text,
      style: style,
      recognizer: recognizer,
      mouseCursor: (recognizer != null) ? SystemMouseCursors.click : null,
    );

abstract final class TextBlockUtils {
  /// Get the horizontalSpacing using the default
  /// implementation provided by [Flutter Quill]
  static HorizontalSpacing defaultIndentWidthBuilder(
      Block block,
      BuildContext context,
      int count,
      LeadingBlockNumberPointWidth numberPointWidthBuilder) {
    return resolveIndentSpacing(
      block,
      QuillStyles.getStyles(context, false),
      count,
      numberPointWidthBuilder,
    );
  }

  /// Get the width for the number point leading using the default
  /// implementation provided by [Flutter Quill]
  static double defaultNumberPointWidthBuilder(double fontSize, int count) {
    final length = '$count'.length;
    switch (length) {
      case 1:
      case 2:
        return fontSize * 2;
      default:
        // 3 -> 2.5
        // 4 -> 3
        // 5 -> 3.5
        return fontSize * (length - (length - 2) / 2);
    }
  }
}
