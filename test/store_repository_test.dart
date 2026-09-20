import 'package:dhisme_pos/features/settings/data/store_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StoreRepository.assertUpdateApplied', () {
    test('throws when the update matched zero rows (RLS denied it)', () {
      expect(
        () => StoreRepository.assertUpdateApplied(const []),
        throwsA(isA<Exception>()),
        reason: 'A zero-row UPDATE (manager, seller, or wrong store id) must never be treated as success',
      );
    });

    test('does not throw when the update returned the updated row', () {
      expect(
        () => StoreRepository.assertUpdateApplied(const [
          {'id': 'store-1'},
        ]),
        returnsNormally,
        reason: 'Owner update of their own store returns exactly the updated row',
      );
    });
  });
}
