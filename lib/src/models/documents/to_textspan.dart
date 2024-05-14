import 'package:flutter/material.dart';

import '../../../flutter_quill.dart';
import '../../widgets/quill/text_line.dart';

extension DocToTextSpanExt on Document {
  TextSpan toTextSpan(BuildContext context,
      QuillRawEditorConfigurations configurations, QuillController controller) {
    final spans = <InlineSpan>[];
    final textspan = TextSpan(children: spans);

    Future<LinkMenuAction> linkActionPicker(Node linkNode) async {
      final link = linkNode.style.attributes[Attribute.link.key]!.value!;
      return configurations.linkActionPickerDelegate(context, link, linkNode);
    }

    var styles = DefaultStyles.getInstance(context);
    if (configurations.customStyles != null) {
      styles = styles.merge(configurations.customStyles!);
    }

    for (final node in root.children) {
      if (!node.isFirst) {
        spans.add(const TextSpan(text: '\n'));
      }

      if (node is Line) {
        final lineIsEmpty = node.toPlainText() == '\n';
        final widget = TextLine(
          line: node,
          textDirection: Directionality.of(context),
          embedBuilder: configurations.embedBuilder,
          customStyleBuilder: configurations.customStyleBuilder,
          customRecognizerBuilder: configurations.customRecognizerBuilder,
          styles: styles,
          readOnly: configurations.readOnly,
          controller: controller,
          linkActionPicker: linkActionPicker,
          onLaunchUrl: configurations.onLaunchUrl,
          customLinkPrefixes: configurations.customLinkPrefixes,
        );
        final textSpan =
            TextLineState.getTextSpanForWholeLine(widget, context, null);
        if (lineIsEmpty) spans.add(TextSpan(text: ' ', style: textSpan.style));
        spans.add(textSpan);
      } else if (node is Block) {
        final block = node;
        // final blockSpans = <InlineSpan>[];
        for (final node in block.children) {
          // print("${node.runtimeType} ${node.toString()}");
          if (!node.isFirst) {
            spans.add(const TextSpan(text: '\n'));
          }
          if (node is Line) {
            final indent =
                (node.style.attributes[Attribute.indent.key]?.value ?? 0) + 1;
            final indentStr = '       ' * indent;
            final widget = TextLine(
              line: node,
              textDirection: Directionality.of(context),
              embedBuilder: configurations.embedBuilder,
              customStyleBuilder: configurations.customStyleBuilder,
              customRecognizerBuilder: configurations.customRecognizerBuilder,
              styles: styles,
              readOnly: configurations.readOnly,
              controller: controller,
              linkActionPicker: linkActionPicker,
              onLaunchUrl: configurations.onLaunchUrl,
              customLinkPrefixes: configurations.customLinkPrefixes,
            );
            final textSpan =
                TextLineState.getTextSpanForWholeLine(widget, context, null);
            spans
              ..add(TextSpan(
                  text: '${indentStr.substring(0, indentStr.length - 2)}- '))
              ..add(textSpan);
          }
        }
      }
    }
    return textspan;
  }
}
