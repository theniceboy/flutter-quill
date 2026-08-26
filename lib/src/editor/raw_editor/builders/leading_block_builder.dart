import 'package:flutter/material.dart';
import '../../../document/attribute.dart';
import '../../../document/nodes/node.dart';
import '../../style_widgets/checkbox_point.dart';
import '../../widgets/text/text_resolution.dart';

typedef LeadingBlockNodeBuilder = Widget? Function(Node, LeadingConfig);

/// This class contains all necessary values
/// to build the leading for lists and codeblocks
///
/// If you want to customize the number point of the codeblock
/// please, take care about it, because the default
/// implementation uses the same leading of
/// ordered list to show lines with correct format
class LeadingConfig {
  LeadingConfig({
    required this.attribute,
    required this.indentLevelCounts,
    required this.count,
    required this.style,
    required this.width,
    required this.padding,
    required this.value,
    required this.onCheckboxTap,
    required this.attrs,
    this.withDot = true,
    this.index,
    this.lineSize,
    this.enabled,
    this.uiBuilder,
  });

  final Attribute attribute;
  final Map<String, Attribute> attrs;
  final bool withDot;
  final Map<int, int> indentLevelCounts;
  // if is a list that contains a number as its leading then this is non null
  final int? index;
  final int count;
  final TextStyle? style;
  final double? width;
  final double? padding;

  // these values are used if the leading is from a check list
  final QuillCheckboxBuilder? uiBuilder;
  final double? lineSize;
  final bool? enabled;
  final bool value;
  final void Function(bool) onCheckboxTap;

  String? get getIndexNumberByIndent => resolveIndexNumberByIndent(
        index,
        attrs,
        indentLevelCounts,
      );
}
