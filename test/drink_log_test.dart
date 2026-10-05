import 'package:flutter_test/flutter_test.dart';
import 'package:water_app_mobile/models/drink_log.dart';

void main() {
  test('slug is read from the dashboard shape', () {
    final log = DrinkLog.fromJson({
      'id': 1,
      'drink_id': 2,
      'drink_name': 'Still water',
      'drink_slug': 'still-water',
      'volume_ml': 250,
      'consumed_at': '2026-10-05T08:00:00Z',
    });
    expect(log.drinkSlug, 'still-water');
  });

  test('slug is read from the nested drink-logs shape', () {
    final log = DrinkLog.fromJson({
      'id': 1,
      'volume_ml': 250,
      'consumed_at': '2026-10-05T08:00:00Z',
      'drink': {'id': 2, 'name': 'Latte', 'slug': 'latte'},
    });
    expect(log.drinkSlug, 'latte');
  });

  test('an older backend without a slug parses to null, not an error', () {
    final log = DrinkLog.fromJson({
      'id': 1,
      'drink_name': 'Latte',
      'volume_ml': 250,
      'consumed_at': '2026-10-05T08:00:00Z',
    });
    expect(log.drinkSlug, isNull);
  });
}
