import 'package:flutter/material.dart';

import '../../../common/structs/horizontal_spacing.dart';
import '../../../common/structs/vertical_spacing.dart';
import '../../../common/utils/color.dart';
import '../../../common/utils/font.dart';
import '../../../document/attribute.dart';
import '../../../document/nodes/block.dart';
import '../../../document/nodes/line.dart';
import '../../../document/style.dart';
import '../../../editor_toolbar_shared/color.dart';
import '../default_styles.dart';
import '../delegate.dart';
import 'utils/text_block_utils.dart';

/// Widget-free text resolution extracted from [TextLine] and
/// [EditableTextBlock]. The editor widgets and static renderers
/// (e.g. canvas card flattening) must resolve identical styles,
/// leading and spacing through these functions.
///
/// These functions are pure: same inputs always produce the same
/// output and no [BuildContext] or widget state is involved.

/// Whether [line] carries the placeholder attribute on its first
/// operation (port of `_TextLineState.isPlaceholderLine`).
bool isPlaceholderLine(Line line) =>
    line.toDelta().first.attributes?.containsKey('placeholder') ?? false;

/// Resolves the line-level [TextStyle] for [line]
/// (port of `_TextLineState._getLineStyle`).
TextStyle resolveLineStyle(
  Line line,
  DefaultStyles defaultStyles, {
  CustomStyleBuilder? customStyleBuilder,
}) {
  var textStyle = const TextStyle();

  if (line.style.containsKey(Attribute.placeholder.key)) {
    return defaultStyles.placeHolder!.style;
  }

  final header = line.style.attributes[Attribute.header.key];
  final m = <Attribute, TextStyle>{
    Attribute.h1: defaultStyles.h1!.style,
    Attribute.h2: defaultStyles.h2!.style,
    Attribute.h3: defaultStyles.h3!.style,
    Attribute.h4: defaultStyles.h4!.style,
    Attribute.h5: defaultStyles.h5!.style,
    Attribute.h6: defaultStyles.h6!.style,
  };

  textStyle = textStyle.merge(m[header] ?? defaultStyles.paragraph!.style);

  // Only retrieve exclusive block format for the line style purpose
  Attribute? block;
  line.style.getBlocksExceptHeader().forEach((key, value) {
    if (Attribute.exclusiveBlockKeys.contains(key)) {
      block = value;
    }
  });

  TextStyle? toMerge;
  if (block == Attribute.blockQuote) {
    toMerge = defaultStyles.quote!.style;
  } else if (block == Attribute.codeBlock) {
    toMerge = defaultStyles.code!.style;
  } else if (block?.key == Attribute.list.key) {
    toMerge = defaultStyles.lists!.style;
  }

  textStyle = textStyle.merge(toMerge);

  final lineHeight = line.style.attributes[Attribute.lineHeight.key];
  final x = <Attribute, TextStyle>{
    LineHeightAttribute.lineHeightNormal:
        defaultStyles.lineHeightNormal!.style,
    LineHeightAttribute.lineHeightTight: defaultStyles.lineHeightTight!.style,
    LineHeightAttribute.lineHeightOneAndHalf:
        defaultStyles.lineHeightOneAndHalf!.style,
    LineHeightAttribute.lineHeightDouble:
        defaultStyles.lineHeightDouble!.style,
  };

  // If the lineHeight attribute isn't null, then get just the height param instead whole TextStyle
  // to avoid modify the current style of the text line
  textStyle =
      textStyle.merge(textStyle.copyWith(height: x[lineHeight]?.height));

  textStyle = _applyCustomAttributes(
      textStyle, line.style.attributes, customStyleBuilder);

  if (isPlaceholderLine(line)) {
    final oldStyle = textStyle;
    textStyle = defaultStyles.placeHolder!.style;
    textStyle = textStyle.merge(oldStyle.copyWith(
      color: textStyle.color,
      backgroundColor: textStyle.backgroundColor,
      background: textStyle.background,
    ));
  }

  return textStyle;
}

TextStyle _applyCustomAttributes(TextStyle textStyle,
    Map<String, Attribute> attributes, CustomStyleBuilder? customStyleBuilder) {
  if (customStyleBuilder == null) {
    return textStyle;
  }
  for (final key in attributes.keys) {
    final attr = attributes[key];
    if (attr != null) {
      /// Custom Attribute
      final customAttr = customStyleBuilder.call(attr);
      textStyle = textStyle.merge(customAttr);
    }
  }
  return textStyle;
}

/// Resolves the effective [TextAlign] of [line]
/// (port of `_TextLineState._getTextAlign`).
TextAlign resolveTextAlign(Line line) {
  final alignment = line.style.attributes[Attribute.align.key];
  if (alignment == Attribute.leftAlignment) {
    return TextAlign.start;
  } else if (alignment == Attribute.centerAlignment) {
    return TextAlign.center;
  } else if (alignment == Attribute.rightAlignment) {
    return TextAlign.end;
  } else if (alignment == Attribute.justifyAlignment) {
    return TextAlign.justify;
  }
  return TextAlign.start;
}

/// Resolves the style of a single text run (port of
/// `_TextLineState._getInlineTextStyle`).
TextStyle resolveInlineTextStyle(
  Style nodeStyle,
  DefaultStyles defaultStyles,
  Style lineStyle,
  bool isLink, {
  CustomStyleBuilder? customStyleBuilder,
}) {
  var res = const TextStyle(); // This is inline text style
  final color = nodeStyle.attributes[Attribute.color.key];

  <String, TextStyle?>{
    Attribute.bold.key: defaultStyles.bold,
    Attribute.italic.key: defaultStyles.italic,
    Attribute.small.key: defaultStyles.small,
    Attribute.link.key: defaultStyles.link,
    Attribute.underline.key: defaultStyles.underline,
    Attribute.strikeThrough.key: defaultStyles.strikeThrough,
  }.forEach((k, s) {
    if (nodeStyle.values.any((v) => v.key == k)) {
      if (k == Attribute.underline.key || k == Attribute.strikeThrough.key) {
        var textColor = defaultStyles.color;
        if (color?.value is String) {
          textColor = stringToColor(color?.value, textColor, defaultStyles);
        }
        res = _mergeDecorations(res.copyWith(decorationColor: textColor),
            s!.copyWith(decorationColor: textColor));
      } else if (k == Attribute.link.key && !isLink) {
        // null value for link should be ignored
        // i.e. nodeStyle.attributes[Attribute.link.key]!.value == null
      } else {
        res = _mergeDecorations(res, s!);
      }
    }
  });

  if (nodeStyle.containsKey(Attribute.script.key)) {
    if (nodeStyle.attributes.values.contains(Attribute.subscript)) {
      res = _mergeDecorations(res, defaultStyles.subscript!);
    } else if (nodeStyle.attributes.values.contains(Attribute.superscript)) {
      res = _mergeDecorations(res, defaultStyles.superscript!);
    }
  }

  if (nodeStyle.containsKey(Attribute.inlineCode.key)) {
    res = _mergeDecorations(res, defaultStyles.inlineCode!.styleFor(lineStyle));
  }

  final font = nodeStyle.attributes[Attribute.font.key];
  if (font != null && font.value != null) {
    res = res.merge(TextStyle(fontFamily: font.value));
  }

  final size = nodeStyle.attributes[Attribute.size.key];
  if (size != null && size.value != null) {
    switch (size.value) {
      case 'small':
        res = res.merge(defaultStyles.sizeSmall);
        break;
      case 'large':
        res = res.merge(defaultStyles.sizeLarge);
        break;
      case 'huge':
        res = res.merge(defaultStyles.sizeHuge);
        break;
      default:
        res = res.merge(TextStyle(
          fontSize: getFontSize(
            size.value,
          ),
        ));
    }
  }

  if (color != null && color.value != null) {
    var textColor = defaultStyles.color;
    if (color.value is String) {
      textColor = stringToColor(color.value, null, defaultStyles);
    }
    if (textColor != null) {
      res = res.merge(TextStyle(color: textColor));
    }
  }

  final background = nodeStyle.attributes[Attribute.background.key];
  if (background != null && background.value != null) {
    final backgroundColor =
        stringToColor(background.value, null, defaultStyles);
    res = res.merge(TextStyle(backgroundColor: backgroundColor));
  }

  res = _applyCustomAttributes(res, nodeStyle.attributes, customStyleBuilder);
  return res;
}

TextStyle _mergeDecorations(TextStyle a, TextStyle b) {
  final decorations = <TextDecoration?>[];
  if (a.decoration != null) {
    decorations.add(a.decoration);
  }
  if (b.decoration != null) {
    decorations.add(b.decoration);
  }
  return a.merge(b).apply(
      decoration: TextDecoration.combine(
          List.castFrom<dynamic, TextDecoration>(decorations)));
}

/// Style and vertical offset for a single subscript/superscript
/// character (pure part of `_TextLineState._scriptSpan`).
class ScriptCharStyle {
  const ScriptCharStyle(this.style, this.offset);

  final TextStyle style;
  final Offset offset;
}

/// Resolves the per-character style for script runs. [runStyle] is the
/// resolved inline style of the run and [resolvedLineStyle] the resolved
/// line style (used as fallback for missing fontSize/fontWeight).
ScriptCharStyle resolveScriptCharStyle(
  bool superScript,
  TextStyle runStyle,
  TextStyle resolvedLineStyle,
) {
  final fontWeight = FontWeight.lerp(
      runStyle.fontWeight ?? resolvedLineStyle.fontWeight ?? FontWeight.normal,
      FontWeight.w900,
      0.25);
  final fontSize = runStyle.fontSize ?? resolvedLineStyle.fontSize ?? 16;
  final y = (superScript ? -0.4 : 0.14) * fontSize;
  return ScriptCharStyle(
    runStyle.copyWith(
        fontFeatures: <FontFeature>[],
        fontWeight: fontWeight,
        fontSize: fontSize * 0.7),
    Offset(0, y),
  );
}

enum LeadingKind { bullet, number, checkbox, codeLineNumber }

/// Widget-free description of the leading of a list or code-block line
/// (pure part of `EditableTextBlock._buildLeading`).
class LeadingSpec {
  const LeadingSpec({
    required this.kind,
    required this.attribute,
    required this.checked,
    this.index,
    this.style,
    this.width,
    this.padding,
    this.lineSize,
  });

  final LeadingKind kind;
  final Attribute attribute;

  /// 1-based position of the line in its block, for ordered lists and
  /// code-block line numbers.
  final int? index;
  final TextStyle? style;
  final double? width;
  final double? padding;
  final double? lineSize;
  final bool checked;
}

/// Resolves the leading of [line] inside a block of [count] lines, or
/// `null` when the line has no leading (port of the pure part of
/// `EditableTextBlock._buildLeading`).
LeadingSpec? resolveLeading(
  Line line,
  DefaultStyles defaultStyles,
  int index,
  int count,
) {
  final fontSize = defaultStyles.paragraph?.style.fontSize ?? 16;
  final attrs = line.style.attributes;
  final numberPointWidthBuilder =
      defaultStyles.lists?.numberPointWidthBuilder ??
          TextBlockUtils.defaultNumberPointWidthBuilder;

  // Of the color button
  final fontColor =
      line.toDelta().operations.first.attributes?[Attribute.color.key] != null
          ? hexToColor(
              line.toDelta().operations.first.attributes?[Attribute.color.key],
            )
          : null;

  // Of the size button
  final size =
      line.toDelta().operations.first.attributes?[Attribute.size.key] != null
          ? getFontSizeAsDouble(
              line.toDelta().operations.first.attributes?[Attribute.size.key],
              defaultStyles: defaultStyles,
            )
          : null;

  final attribute =
      attrs[Attribute.list.key] ?? attrs[Attribute.codeBlock.key];
  final isUnordered = attribute == Attribute.ul;
  final isOrdered = attribute == Attribute.ol;
  final isCheck =
      attribute == Attribute.checked || attribute == Attribute.unchecked;
  final isCodeBlock = attrs.containsKey(Attribute.codeBlock.key);
  if (attribute == null) {
    return null;
  }
  return LeadingSpec(
    kind: isOrdered
        ? LeadingKind.number
        : isUnordered
            ? LeadingKind.bullet
            : isCheck
                ? LeadingKind.checkbox
                : LeadingKind.codeLineNumber,
    attribute: attribute,
    index: isOrdered || isCodeBlock ? index : null,
    checked: attribute == Attribute.checked,
    style: () {
      if (isOrdered) {
        return defaultStyles.leading!.style.copyWith(
          fontSize: size,
          color: fontColor,
        );
      }
      if (isUnordered) {
        return defaultStyles.leading!.style.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: size,
          color: fontColor,
        );
      }
      if (isCheck) {
        return null;
      }
      return defaultStyles.code!.style.copyWith(
        color: defaultStyles.code!.style.color!.withValues(alpha: 0.4),
      );
    }(),
    width: () {
      if (isOrdered || isCodeBlock) {
        return numberPointWidthBuilder(fontSize, count);
      }
      if (isUnordered) {
        return numberPointWidthBuilder(fontSize, 1); // same as fontSize * 2
      }
      return null;
    }(),
    padding: () {
      if (isOrdered || isUnordered) {
        return fontSize / 2;
      }
      if (isCodeBlock) {
        return fontSize;
      }
      return null;
    }(),
    lineSize: isCheck ? fontSize : null,
  );
}

/// Computes the displayed number of a numbered leading for [index]
/// (1-based) considering indent levels. Mutates [indentLevelCounts],
/// which must be threaded across the lines of the block in order
/// (port of `LeadingConfig.getIndexNumberByIndent`).
String? resolveIndexNumberByIndent(
  int? index,
  Map<String, Attribute> attrs,
  Map<int, int> indentLevelCounts,
) {
  if (index == null) return null;
  var s = index.toString();
  var level = 0;
  if (!attrs.containsKey(Attribute.indent.key) && indentLevelCounts.isEmpty) {
    indentLevelCounts.clear();
    indentLevelCounts[0] = 1;
    return s;
  }
  if (attrs.containsKey(Attribute.indent.key)) {
    level = attrs[Attribute.indent.key]!.value;
  } else if (!indentLevelCounts.containsKey(0)) {
    // first level but is back from previous indent level
    // supposed to be "2."
    indentLevelCounts[0] = 1;
  }
  if (indentLevelCounts.containsKey(level + 1)) {
    // last visited level is done, going up
    indentLevelCounts.remove(level + 1);
  }
  final count = (indentLevelCounts[level] ?? 0) + 1;
  indentLevelCounts[level] = count;

  s = count.toString();
  if (level % 3 == 1) {
    // a. b. c. d. e. ...
    s = _toExcelSheetColumnTitle(count);
  } else if (level % 3 == 2) {
    // i. ii. iii. ...
    s = _intToRoman(count);
  }
  return s;
}

String _toExcelSheetColumnTitle(int n) {
  final result = StringBuffer();
  while (n > 0) {
    n--;
    result.write(String.fromCharCode((n % 26).floor() + 97));
    n = (n / 26).floor();
  }

  return result.toString().split('').reversed.join();
}

String _intToRoman(int input) {
  var num = input;

  if (num < 0) {
    return '';
  } else if (num == 0) {
    return 'nulla';
  }

  final builder = StringBuffer();
  for (var a = 0; a < _arabianRomanNumbers.length; a++) {
    final times = (num / _arabianRomanNumbers[a])
        .truncate(); // equals 1 only when arabianRomanNumbers[a] = num
    // executes n times where n is the number of times you have to add
    // the current roman number to reach current num.
    builder.write(_romanNumbers[a] * times);
    num -= times *
        _arabianRomanNumbers[
            a]; // subtract previous roman number value from num
  }

  return builder.toString().toLowerCase();
}

const _arabianRomanNumbers = <int>[
  1000,
  900,
  500,
  400,
  100,
  90,
  50,
  40,
  10,
  9,
  5,
  4,
  1
];

const _romanNumbers = <String>[
  'M',
  'CM',
  'D',
  'CD',
  'C',
  'XC',
  'L',
  'XL',
  'X',
  'IX',
  'V',
  'IV',
  'I'
];

/// Resolves the vertical spacing of the line at 1-based [index] within a
/// block of [count] lines (port of `EditableTextBlock._getSpacingForLine`).
VerticalSpacing resolveSpacingForLine(
  Block block,
  int index,
  int count,
  DefaultStyles? defaultStyles,
) {
  var top = 0.0, bottom = 0.0;

  final attrs = block.style.attributes;
  if (attrs.containsKey(Attribute.header.key)) {
    final level = attrs[Attribute.header.key]!.value;
    switch (level) {
      case 1:
        top = defaultStyles!.h1!.verticalSpacing.top;
        bottom = defaultStyles.h1!.verticalSpacing.bottom;
        break;
      case 2:
        top = defaultStyles!.h2!.verticalSpacing.top;
        bottom = defaultStyles.h2!.verticalSpacing.bottom;
        break;
      case 3:
        top = defaultStyles!.h3!.verticalSpacing.top;
        bottom = defaultStyles.h3!.verticalSpacing.bottom;
        break;
      case 4:
        top = defaultStyles!.h4!.verticalSpacing.top;
        bottom = defaultStyles.h4!.verticalSpacing.bottom;
        break;
      case 5:
        top = defaultStyles!.h5!.verticalSpacing.top;
        bottom = defaultStyles.h5!.verticalSpacing.bottom;
        break;
      case 6:
        top = defaultStyles!.h6!.verticalSpacing.top;
        bottom = defaultStyles.h6!.verticalSpacing.bottom;
        break;
      default:
        throw ArgumentError('Invalid level $level');
    }
  } else {
    final VerticalSpacing lineSpacing;
    if (attrs.containsKey(Attribute.blockQuote.key)) {
      lineSpacing = defaultStyles!.quote!.lineSpacing;
    } else if (attrs.containsKey(Attribute.indent.key)) {
      lineSpacing = defaultStyles!.indent!.lineSpacing;
    } else if (attrs.containsKey(Attribute.list.key)) {
      lineSpacing = defaultStyles!.lists!.lineSpacing;
    } else if (attrs.containsKey(Attribute.codeBlock.key)) {
      lineSpacing = defaultStyles!.code!.lineSpacing;
    } else if (attrs.containsKey(Attribute.align.key)) {
      lineSpacing = defaultStyles!.align!.lineSpacing;
    } else {
      // use paragraph linespacing as a default
      lineSpacing = defaultStyles!.paragraph!.lineSpacing;
    }
    top = lineSpacing.top;
    bottom = lineSpacing.bottom;
  }

  if (index == 1) {
    top = 0.0;
  }

  if (index == count) {
    bottom = 0.0;
  }

  return VerticalSpacing(top, bottom);
}

/// Resolves the block-level decoration (quote bar, code background) of
/// [block] (port of `EditableTextBlock._getDecorationForBlock`).
BoxDecoration? resolveBlockDecoration(
  Block block,
  DefaultStyles? defaultStyles,
  TextDirection textDirection,
) {
  final attrs = block.style.attributes;
  if (attrs.containsKey(Attribute.blockQuote.key)) {
    // Verify if the direction is RTL and avoid passing the decoration
    // to the left when need to be on right side
    if (textDirection == TextDirection.rtl) {
      return defaultStyles!.quote!.decoration?.copyWith(
        border: Border(
          right: BorderSide(width: 4, color: Colors.grey.shade300),
        ),
      );
    }
    return defaultStyles!.quote!.decoration;
  }
  if (attrs.containsKey(Attribute.codeBlock.key)) {
    return defaultStyles!.code!.decoration;
  }
  return null;
}

/// Resolves the horizontal indent spacing of [block]
/// (pure core of `TextBlockUtils.defaultIndentWidthBuilder`).
HorizontalSpacing resolveIndentSpacing(
  Block block,
  DefaultStyles? defaultStyles,
  int count,
  LeadingBlockNumberPointWidth numberPointWidthBuilder,
) {
  final fontSize = defaultStyles?.paragraph?.style.fontSize ?? 16;
  final attrs = block.style.attributes;

  final indent = attrs[Attribute.indent.key];
  var extraIndent = 0.0;
  if (indent != null && indent.value != null) {
    extraIndent = fontSize * indent.value;
  }

  if (attrs.containsKey(Attribute.blockQuote.key)) {
    return HorizontalSpacing(fontSize + extraIndent, 0);
  }

  var baseIndent = 0.0;

  if (attrs.containsKey(Attribute.list.key)) {
    baseIndent = fontSize * 2;
    if (attrs[Attribute.list.key] == Attribute.ol) {
      baseIndent = numberPointWidthBuilder(fontSize, count);
    } else if (attrs.containsKey(Attribute.codeBlock.key)) {
      baseIndent = numberPointWidthBuilder(fontSize, count);
    }
  }

  return HorizontalSpacing(baseIndent + extraIndent, 0);
}
