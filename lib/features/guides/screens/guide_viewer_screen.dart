import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../models/workflow_guide.dart';

class GuideViewerScreen extends StatefulWidget {
  const GuideViewerScreen({super.key, required this.guide, required this.role});
  final WorkflowGuide guide;
  final String role;

  @override
  State<GuideViewerScreen> createState() => _GuideViewerScreenState();
}

class _GuideViewerScreenState extends State<GuideViewerScreen> {
  late final List<GuideSequence> _sequences = widget.guide.sequencesFor(widget.role);
  int _sequence = 0;
  int _step = 0;

  GuideSequence get _current => _sequences[_sequence];
  bool get _isFirst => _step == 0;
  bool get _isLast => _step == _current.steps.length - 1;

  void _selectSequence(int index) => setState(() {
        _sequence = index;
        _step = 0;
      });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) {
        final somali = AppLanguage.instance.isSomali;
        final steps = _current.steps;
        final step = steps[_step];
        return Scaffold(
          appBar: AppBar(title: Text(widget.guide.title.of(somali))),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_sequences.length > 1) ...[
                        SegmentedButton<int>(
                          style: const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
                          segments: [
                            for (var i = 0; i < _sequences.length; i++) ButtonSegment(value: i, label: Text(_sequences[i].title.of(somali))),
                          ],
                          selected: {_sequence},
                          onSelectionChanged: (s) => _selectSequence(s.first),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ExcludeSemantics(child: _StepTrack(count: steps.length, current: _step)),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
                        child: _StepCard(
                          key: ValueKey('${_current.id}-$_step'),
                          step: step,
                          number: _step + 1,
                          total: steps.length,
                          somali: somali,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          onPressed: _isFirst ? null : () => setState(() => _step--),
                          child: Text(context.tr('Dib', 'Back')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          onPressed: _isLast ? () => Navigator.of(context).pop() : () => setState(() => _step++),
                          child: Text(_isLast ? context.tr('Dhammaad', 'Done') : context.tr('Xiga', 'Next')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StepTrack extends StatelessWidget {
  const _StepTrack({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) Expanded(child: Container(height: 2, color: i <= current ? scheme.primary : Colors.black12)),
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current ? scheme.secondary : (i < current ? scheme.primary : Colors.white),
              border: Border.all(color: i <= current ? Colors.transparent : Colors.black26),
            ),
            child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: i <= current ? Colors.white : Colors.black54)),
          ),
        ],
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({super.key, required this.step, required this.number, required this.total, required this.somali});
  final GuideStep step;
  final int number;
  final int total;
  final bool somali;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stepOf = somali ? 'Tallaabo $number / $total' : 'Step $number of $total';
    final actor = step.actor.label.of(somali);
    return Semantics(
      container: true,
      label: '$stepOf. ${step.title.of(somali)}. $actor. ${step.body.of(somali)}',
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 28, backgroundColor: scheme.primary, child: Icon(step.icon, color: Colors.white, size: 28)),
                const SizedBox(height: 16),
                Text(stepOf, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                const SizedBox(height: 4),
                Text(step.title.of(somali), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Chip(
                  avatar: const Icon(Icons.person_outline, size: 18),
                  label: Text(actor),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(height: 12),
                Text(step.body.of(somali), style: const TextStyle(fontSize: 16, height: 1.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
