import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../../document/nodes/line.dart';

/// Gap Apple Pencil Scribble asks for (press-and-hold) at document [offset]:
/// a line break plus an empty line [width] wide.
@immutable
class ScribblePlaceholder {
  const ScribblePlaceholder({required this.offset, required this.width});

  final int offset;
  final double width;

  /// Rendered characters the gap adds to its line.
  static const int length = 2;

  @override
  bool operator ==(Object other) =>
      other is ScribblePlaceholder &&
      other.offset == offset &&
      other.width == width;

  @override
  int get hashCode => Object.hash(offset, width);
}

/// Empty inline box of a fixed [size], ignoring the child's laid-out size.
class ScribblePlaceholderSpan extends WidgetSpan {
  const ScribblePlaceholderSpan({required this.size})
      : super(child: const SizedBox.shrink());

  final Size size;

  @override
  void build(
    ui.ParagraphBuilder builder, {
    TextScaler textScaler = TextScaler.noScaling,
    List<PlaceholderDimensions>? dimensions,
  }) {
    final hasStyle = style != null;
    if (hasStyle) {
      builder.pushStyle(style!.getTextStyle(textScaler: textScaler));
    }
    builder.addPlaceholder(size.width, size.height, alignment);
    if (hasStyle) {
      builder.pop();
    }
  }
}

/// Returns [root] with the gap spans inserted before rendered character
/// [index] (each non-text span counts as one character).
InlineSpan insertScribblePlaceholder(InlineSpan root, int index, double width) {
  final inserts = <InlineSpan>[
    const ScribblePlaceholderSpan(size: Size.zero),
    ScribblePlaceholderSpan(size: Size(width, 0)),
  ];
  final splicer = _Splicer(index, inserts);
  final result = splicer.visit(root);
  if (splicer.done) return result;
  return TextSpan(style: root.style, children: [result, ...inserts]);
}

class _Splicer {
  _Splicer(this.remaining, this.inserts);

  int remaining;
  final List<InlineSpan> inserts;
  bool done = false;

  InlineSpan visit(InlineSpan span) {
    if (done) return span;
    if (span is! TextSpan) {
      remaining -= 1;
      return span;
    }
    final text = span.text ?? '';
    if (text.isNotEmpty && remaining < text.length) {
      done = true;
      return TextSpan(
        style: span.style,
        locale: span.locale,
        spellOut: span.spellOut,
        children: [
          if (remaining > 0) _textPart(span, text.substring(0, remaining)),
          ...inserts,
          _textPart(span, text.substring(remaining)),
          ...?span.children,
        ],
      );
    }
    remaining -= text.length;
    final children = span.children;
    if (children == null) return span;
    var changed = false;
    final out = <InlineSpan>[];
    for (final child in children) {
      if (!done && remaining == 0) {
        out.addAll(inserts);
        done = true;
        changed = true;
      }
      final next = visit(child);
      if (!identical(next, child)) changed = true;
      out.add(next);
    }
    if (!changed) return span;
    return TextSpan(
      text: span.text,
      style: span.style,
      recognizer: span.recognizer,
      mouseCursor: span.mouseCursor,
      onEnter: span.onEnter,
      onExit: span.onExit,
      semanticsLabel: span.semanticsLabel,
      locale: span.locale,
      spellOut: span.spellOut,
      children: out,
    );
  }

  TextSpan _textPart(TextSpan span, String text) => TextSpan(
        text: text,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        locale: span.locale,
        spellOut: span.spellOut,
      );
}

/// Line-local offset of [placeholder] when it falls inside [line].
int? scribbleGapInLine(ScribblePlaceholder? placeholder, Line line) {
  if (placeholder == null) return null;
  final local = placeholder.offset - line.documentOffset;
  return local >= 0 && local < line.length ? local : null;
}
