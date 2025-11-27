import 'package:flutter/material.dart';
import '../../models/goal.dart';

class GoalChip extends StatelessWidget {
  final Goal goal;
  final bool selected;
  final VoidCallback onTap;

  const GoalChip({
    super.key,
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(goal.label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
