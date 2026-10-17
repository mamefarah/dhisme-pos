import 'package:dhisme_pos/features/guides/data/workflow_guides.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> ids(String role) => guidesForRole(role).map((g) => g.id).toList();

  test('owner and manager see all four guides', () {
    const all = ['sell', 'purchase', 'credit', 'returns_closing'];
    expect(ids('owner'), all);
    expect(ids('manager'), all);
  });

  test('seller does not see purchases or returns', () {
    expect(ids('seller'), ['sell', 'credit', 'returns_closing']);
    final closing = guidesForRole('seller').last.sequencesFor('seller');
    expect(closing.map((s) => s.id), ['closing']);
  });

  test('unknown role sees nothing', () {
    expect(guidesForRole('guest'), isEmpty);
  });

  test('every guide, sequence and step has Somali and English text', () {
    for (final g in workflowGuides) {
      for (final t in [g.title, g.summary]) {
        expect(t.so.trim(), isNotEmpty);
        expect(t.en.trim(), isNotEmpty);
      }
      for (final s in g.sequences) {
        expect(s.steps.length, inInclusiveRange(4, 6));
        for (final step in s.steps) {
          expect(step.title.so.trim(), isNotEmpty);
          expect(step.title.en.trim(), isNotEmpty);
          expect(step.body.so.trim(), isNotEmpty);
          expect(step.body.en.trim(), isNotEmpty);
          expect(step.title.so, isNot(step.title.en));
        }
      }
    }
  });

  test('sell stages keep their order and name every supported payment mode', () {
    final steps = workflowGuides.firstWhere((g) => g.id == 'sell').sequences.single.steps;
    expect(steps.map((s) => s.title.en), [
      'Find the product',
      'Enter the quantity',
      'Check stock and price',
      'Choose how the customer pays',
      'Complete the sale',
      'Share the receipt',
    ]);
    final payment = steps[3].body.en.toLowerCase();
    for (final mode in ['cash', 'bank', 'mobile money', 'mixed', 'credit']) {
      expect(payment, contains(mode));
    }
  });

  test('credit guide never lets the seller decide and records debt only after approval', () {
    final steps = workflowGuides.firstWhere((g) => g.id == 'credit').sequences.single.steps;
    final titles = steps.map((s) => s.title.en).toList();
    expect(titles.indexOf('Send for Approval'), lessThan(titles.indexOf('Owner reviews')));
    expect(titles.indexOf('Owner reviews'), lessThan(titles.indexOf('If approved')));
    expect(steps.firstWhere((s) => s.title.en == 'Owner reviews').actor.name, 'owner');
    expect(steps.firstWhere((s) => s.title.en == 'Send for Approval').body.en, contains('no debt is recorded'));
  });
}
