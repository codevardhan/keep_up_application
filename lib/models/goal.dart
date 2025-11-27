enum GoalType { internship, family, friends, wellness }

class Goal {
  final GoalType type;
  final String label;
  const Goal(this.type, this.label);
}
