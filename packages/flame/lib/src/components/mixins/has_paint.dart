import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/src/effects/provider_interfaces.dart';
import 'package:flame/src/palette.dart';
import 'package:meta/meta.dart';

mixin HasPaint<T extends Object> on Component
    implements OpacityProvider, PaintProvider {
  late final Map<T, Paint> _paints = {};

  @override
  Paint paint = BasicPalette.white.paint();

  @internal
  List<Paint>? paintLayersInternal;

  Paint getPaint([T? paintId]) {
    if (paintId == null) {
      return this.paint;
    }
    final paint = _paints[paintId];
    if (paint == null) {
      throw ArgumentError('No Paint found for $paintId');
    }
    return paint;
  }

  void setPaint(T paintId, Paint paint) {
    _paints[paintId] = paint;
  }

  void deletePaint(T paintId) {
    _paints.remove(paintId);
  }

  List<Paint> get paintLayers {
    if (!hasPaintLayers) {
      return paintLayersInternal = [];
    }
    return paintLayersInternal!;
  }

  set paintLayers(List<Paint> paintLayers) {
    paintLayersInternal = paintLayers;
  }

  bool get hasPaintLayers => paintLayersInternal?.isNotEmpty ?? false;

  void makeTransparent({T? paintId}) {
    setOpacity(0, paintId: paintId);
  }

  void makeOpaque({T? paintId}) {
    setOpacity(1, paintId: paintId);
  }

  void setOpacity(double opacity, {T? paintId}) {
    if (opacity < 0 || opacity > 1) {
      throw ArgumentError('Opacity needs to be between 0 and 1');
    }
    setColor(
      getPaint(paintId).color.withOpacity(opacity), // Fixed
      paintId: paintId,
    );
  }

  double getOpacity({T? paintId}) {
    return getPaint(paintId).color.opacity;
  }

  void setAlpha(int alpha, {T? paintId}) {
    if (alpha < 0 || alpha > 255) {
      throw ArgumentError('Alpha needs to be between 0 and 255');
    }
    setColor(getPaint(paintId).color.withAlpha(alpha), paintId: paintId);
  }

  int getAlpha({T? paintId}) {
    return (getPaint(paintId).color.opacity * 255).toInt();
  }

  void setColor(Color color, {T? paintId}) {
    getPaint(paintId).color = color;
  }

  void tint(Color color, {T? paintId}) {
    getPaint(paintId).colorFilter = ColorFilter.mode(color, BlendMode.srcATop);
  }

  @override
  double get opacity => paint.color.opacity;

  @override
  set opacity(double value) {
    paint.color = paint.color.withOpacity(value); // Fixed
    for (final paint in _paints.values) {
      paint.color = paint.color.withOpacity(value); // Fixed
    }
  }

  OpacityProvider opacityProviderOf(T paintId) {
    return _ProxyOpacityProvider(paintId, this);
  }

  OpacityProvider opacityProviderOfList({
    List<T?>? paintIds,
    bool includeLayers = true,
  }) {
    return _MultiPaintOpacityProvider(
      paintIds ?? (List<T?>.from(_paints.keys)..add(null)),
      this,
      includeLayers: includeLayers,
    );
  }
}

class _ProxyOpacityProvider<T extends Object> implements OpacityProvider {
  _ProxyOpacityProvider(this.paintId, this.target);

  final T paintId;
  final HasPaint<T> target;

  @override
  double get opacity => target.getOpacity(paintId: paintId);

  @override
  set opacity(double value) => target.setOpacity(value, paintId: paintId);
}

class _MultiPaintOpacityProvider<T extends Object> implements OpacityProvider {
  _MultiPaintOpacityProvider(
    this.paintIds,
    this.target, {
    required this.includeLayers,
  }) {
    final maxOpacity = opacity;

    _opacityRatios = [
      for (final paintId in paintIds)
        target.getOpacity(paintId: paintId) / maxOpacity,
    ];
    _layerOpacityRatios = target.paintLayersInternal
        ?.map(
          (paint) => paint.color.opacity / maxOpacity,
        )
        .toList(growable: false);
  }

  final List<T?> paintIds;
  final HasPaint<T> target;
  final bool includeLayers;
  late final List<double> _opacityRatios;
  late final List<double>? _layerOpacityRatios;

  @override
  double get opacity {
    var maxOpacity = 0.0;
    for (final paintId in paintIds) {
      maxOpacity = max(target.getOpacity(paintId: paintId), maxOpacity);
    }
    if (includeLayers) {
      final targetLayers = target.paintLayersInternal;
      if (targetLayers != null) {
        for (final paint in targetLayers) {
          maxOpacity = max(paint.color.opacity, maxOpacity);
        }
      }
    }
    return maxOpacity;
  }

  @override
  set opacity(double value) {
    for (var i = 0; i < paintIds.length; ++i) {
      target.setOpacity(
        value * _opacityRatios.elementAt(i),
        paintId: paintIds.elementAt(i),
      );
    }
    if (includeLayers) {
      final paintLayersInternal = target.paintLayersInternal;
      for (var i = 0; i < (paintLayersInternal?.length ?? 0); ++i) {
        paintLayersInternal![i].color = paintLayersInternal[i]
            .color
            .withOpacity(value * _layerOpacityRatios![i]); // Fixed
      }
    }
  }
}
