import 'package:flutter/widgets.dart';

class GuideText {
  const GuideText(this.so, this.en);
  final String so;
  final String en;

  String of(bool somali) => somali ? so : en;
}

enum GuideActor {
  anyone(GuideText('Shaqaale kasta', 'Anyone')),
  ownerOrManager(GuideText('Milkiile ama Maamule', 'Owner or manager')),
  owner(GuideText('Milkiile', 'Owner')),
  app(GuideText('App-ka', 'The app'));

  const GuideActor(this.label);
  final GuideText label;
}

class GuideStep {
  const GuideStep({required this.icon, required this.title, required this.body, this.actor = GuideActor.anyone});
  final IconData icon;
  final GuideText title;
  final GuideText body;
  final GuideActor actor;
}

class GuideSequence {
  const GuideSequence({required this.id, required this.title, required this.roles, required this.steps});
  final String id;
  final GuideText title;
  final Set<String> roles;
  final List<GuideStep> steps;
}

class WorkflowGuide {
  const WorkflowGuide({required this.id, required this.icon, required this.title, required this.summary, required this.sequences});
  final String id;
  final IconData icon;
  final GuideText title;
  final GuideText summary;
  final List<GuideSequence> sequences;

  List<GuideSequence> sequencesFor(String role) => sequences.where((s) => s.roles.contains(role)).toList();
}
