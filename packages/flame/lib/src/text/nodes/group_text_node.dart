import 'package:flame/src/text/nodes/inline_text_node.dart';
import 'package:flame/text.dart';

/// An [InlineTextNode] to group other [InlineTextNode]s.
class GroupTextNode extends InlineTextNode {
  GroupTextNode(this.children);

  final List<InlineTextNode> children;

  @override
  void fillStyles(DocumentStyle stylesheet, InlineTextStyle parentTextStyle) {
    style = parentTextStyle;
    for (final node in children) {
      node.fillStyles(stylesheet, style);
    }
  }

  @override
  TextNodeLayoutBuilder get layoutBuilder => _GroupTextLayoutBuilder(this);
}

class _GroupTextLayoutBuilder extends TextNodeLayoutBuilder {
  _GroupTextLayoutBuilder(this.node);

  final GroupTextNode node;
  int _currentChildIndex = 0;
  TextNodeLayoutBuilder? _currentChildBuilder;

  @override
  bool get isDone => _currentChildIndex == node.children.length;

  @override
  InlineTextElement? layOutNextLine(
    double availableWidth, {
    required bool isStartOfLine,
  }) {
    assert(!isDone);
    final out = <InlineTextElement>[];
    var usedWidth = 0.0;
    while (true) {
      if (_currentChildBuilder?.isDone ?? false) {
        _currentChildBuilder = null;
        _currentChildIndex += 1;
        if (_currentChildIndex == node.children.length) {
          break;
        }
      }
      _currentChildBuilder ??= node.children[_currentChildIndex].layoutBuilder;

      final maybeLine = _currentChildBuilder!.layOutNextLine(
        availableWidth - usedWidth,
        isStartOfLine: isStartOfLine && out.isEmpty,
      );
      if (maybeLine == null) {
        break;
      } else {
        assert(maybeLine.metrics.left == 0 && maybeLine.metrics.baseline == 0);
        maybeLine.translate(usedWidth, 0);
        out.add(maybeLine);
        usedWidth += maybeLine.metrics.width;
      }
    }
    if (out.isEmpty) {
      return null;
    } else {
      return GroupTextElement(out);
    }
  }
}
