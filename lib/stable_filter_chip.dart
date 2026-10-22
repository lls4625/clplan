import 'package:flutter/material.dart';

class StableFilterChip extends StatelessWidget {
  const StableFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    avatar: SizedBox.square(
      dimension: 18,
      child: selected ? const Icon(Icons.check, size: 18) : null,
    ),
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    onSelected: onSelected,
  );
}
