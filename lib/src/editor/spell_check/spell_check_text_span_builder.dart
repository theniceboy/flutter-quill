import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../document/nodes/node.dart';
import '../widgets/text/utils/text_block_utils.dart';
import 'spell_check_controller.dart';

const _misspelledStyle = TextStyle(
  decoration: TextDecoration.underline,
  decorationColor: Color(0xFFFF0000),
  decorationStyle: TextDecorationStyle.wavy,
);

InlineSpan buildSpellCheckTextSpan(
  BuildContext context,
  Node node,
  int nodeOffset,
  String text,
  TextStyle? style,
  GestureRecognizer? recognizer,
  QuillSpellCheckController spellCheckController, {
  bool useSecondaryTap = false,
}) {
  final errors = spellCheckController.errors;
  if (errors.isEmpty || text.isEmpty) {
    return defaultSpanBuilder(
        context, node, nodeOffset, text, style, recognizer);
  }

  final nodeStart = node.documentOffset + nodeOffset;
  final nodeEnd = nodeStart + text.length;

  final overlapping = <SpellError>[];
  for (final error in errors) {
    final errorEnd = error.offset + error.length;
    if (error.offset < nodeEnd && errorEnd > nodeStart) {
      overlapping.add(error);
    }
  }

  if (overlapping.isEmpty) {
    return defaultSpanBuilder(
        context, node, nodeOffset, text, style, recognizer);
  }

  final children = <InlineSpan>[];
  var cursor = 0;

  for (final error in overlapping) {
    final errorStartInNode = (error.offset - nodeStart).clamp(0, text.length);
    final errorEndInNode =
        (error.offset + error.length - nodeStart).clamp(0, text.length);

    if (errorStartInNode > cursor) {
      children.add(TextSpan(
        text: text.substring(cursor, errorStartInNode),
        style: style,
        recognizer: recognizer,
        mouseCursor: recognizer != null ? SystemMouseCursors.click : null,
      ));
    }

    final spellRecognizer = TapGestureRecognizer();
    if (useSecondaryTap) {
      spellRecognizer.onSecondaryTapUp = (details) {
        _showSuggestionPopup(
            context, details.globalPosition, error, spellCheckController);
      };
    } else {
      spellRecognizer.onTapUp = (details) {
        _showSuggestionPopup(
            context, details.globalPosition, error, spellCheckController);
      };
    }

    children.add(TextSpan(
      text: text.substring(errorStartInNode, errorEndInNode),
      style: (style ?? const TextStyle()).merge(_misspelledStyle),
      recognizer: spellRecognizer,
      mouseCursor:
          useSecondaryTap ? SystemMouseCursors.text : SystemMouseCursors.click,
    ));

    cursor = errorEndInNode;
  }

  if (cursor < text.length) {
    children.add(TextSpan(
      text: text.substring(cursor),
      style: style,
      recognizer: recognizer,
      mouseCursor: recognizer != null ? SystemMouseCursors.click : null,
    ));
  }

  return TextSpan(children: children);
}

void _showSuggestionPopup(
  BuildContext context,
  Offset globalPosition,
  SpellError error,
  QuillSpellCheckController controller,
) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) {
      return _SpellSuggestionPopup(
        position: globalPosition,
        error: error,
        onSelect: (replacement) {
          controller.replaceWord(error, replacement);
          entry.remove();
        },
        onLearn: () {
          controller.learnWord(error);
          entry.remove();
        },
        onDismiss: () => entry.remove(),
      );
    },
  );

  overlay.insert(entry);
}

class _SpellSuggestionPopup extends StatelessWidget {
  final Offset position;
  final SpellError error;
  final void Function(String) onSelect;
  final VoidCallback onLearn;
  final VoidCallback onDismiss;

  const _SpellSuggestionPopup({
    required this.position,
    required this.error,
    required this.onSelect,
    required this.onLearn,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = error.suggestions;

    return Stack(
      children: [
        GestureDetector(
          onTap: onDismiss,
          onSecondaryTap: onDismiss,
          behavior: HitTestBehavior.opaque,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: position.dx,
          top: position.dy + 4,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 200,
                maxHeight: 300,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (suggestions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Text(
                        'No suggestions for "${error.word}"',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Text(
                        error.word,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    for (final suggestion in suggestions)
                      InkWell(
                        onTap: () => onSelect(suggestion),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Text(
                            suggestion,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                  ],
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.1),
                  ),
                  InkWell(
                    borderRadius:
                        const BorderRadius.vertical(bottom: Radius.circular(8)),
                    onTap: onLearn,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Text(
                        'Learn "${error.word}"',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
