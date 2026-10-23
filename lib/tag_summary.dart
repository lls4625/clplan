import 'package:flutter/material.dart';

class CardTagItem {
  const CardTagItem({
    required this.name,
    required this.icon,
    this.color,
  });

  final String name;
  final IconData icon;
  final Color? color;
}

class CardTagSummary extends StatelessWidget {
  const CardTagSummary({super.key, required this.items});

  static const double _spacing = 5;
  static const double _chipChromeWidth = 30;

  final List<CardTagItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelLarge?.copyWith(fontSize: 12) ??
        const TextStyle(fontSize: 12);
    final overflowStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final visibleCount = _visibleCount(
          context,
          availableWidth,
          labelStyle,
          overflowStyle,
        );
        final hiddenCount = items.length - visibleCount;
        final overflowWidth = hiddenCount == 0
            ? 0.0
            : _textWidth(context, '+$hiddenCount', overflowStyle) + 2;
        final tagsWidth = availableWidth -
            (hiddenCount == 0 ? 0 : overflowWidth + _spacing);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var index = 0; index < visibleCount; index++) ...[
                      if (index > 0) const SizedBox(width: _spacing),
                      _buildChip(
                        context,
                        items[index],
                        labelStyle,
                        maxWidth: visibleCount == 1
                            ? (tagsWidth < 1 ? 1 : tagsWidth)
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (hiddenCount > 0) ...[
              const SizedBox(width: _spacing),
              Semantics(
                label: '还有 $hiddenCount 个标签',
                child: ExcludeSemantics(
                  child: Text('+$hiddenCount', style: overflowStyle),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  int _visibleCount(
    BuildContext context,
    double availableWidth,
    TextStyle labelStyle,
    TextStyle? overflowStyle,
  ) {
    for (var count = items.length; count >= 1; count--) {
      final hiddenCount = items.length - count;
      final overflowWidth = hiddenCount == 0
          ? 0.0
          : _textWidth(context, '+$hiddenCount', overflowStyle) + 2;
      final reservedWidth = hiddenCount == 0
          ? 0.0
          : overflowWidth + _spacing;
      final chipsWidth = items
              .take(count)
              .map(
                (item) =>
                    _textWidth(context, item.name, labelStyle) +
                    _chipChromeWidth,
              )
              .fold<double>(0, (sum, width) => sum + width) +
          _spacing * (count - 1);
      if (chipsWidth + reservedWidth <= availableWidth) return count;
    }
    return 1;
  }

  Widget _buildChip(
    BuildContext context,
    CardTagItem item,
    TextStyle labelStyle, {
    double? maxWidth,
  }) {
    final colors = Theme.of(context).colorScheme;
    final color = item.color ?? colors.onSurfaceVariant;
    final chip = Chip(
      avatar: Icon(item.icon, size: 14, color: color),
      avatarBoxConstraints: const BoxConstraints.tightFor(
        width: 16,
        height: 16,
      ),
      label: Text(
        item.name,
        maxLines: maxWidth == null ? 1 : 2,
        overflow: TextOverflow.ellipsis,
        softWrap: maxWidth != null,
      ),
      labelStyle: labelStyle,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      side: BorderSide(color: color),
      backgroundColor: color.withAlpha(24),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    if (maxWidth == null) return chip;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: chip,
    );
  }

  double _textWidth(
    BuildContext context,
    String text,
    TextStyle? style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

List<String> orderedSelectedTagNames({
  required Iterable<String> selectedNames,
  required Iterable<String> definitionOrder,
}) {
  final selectedOrder = <String>[];
  final remaining = <String>{};
  for (final name in selectedNames) {
    if (name.isNotEmpty && remaining.add(name)) selectedOrder.add(name);
  }
  final result = <String>[];
  for (final name in definitionOrder) {
    if (remaining.remove(name)) result.add(name);
  }
  for (final name in selectedOrder) {
    if (remaining.remove(name)) result.add(name);
  }
  return result;
}
