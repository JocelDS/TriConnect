import 'package:flutter_test/flutter_test.dart';
import 'package:triconnect/UI/user_ui/widgets/ride_status_helper.dart';

void main() {
  group('formatRideStatusLabel', () {
    test('returns a readable label for pending rides', () {
      expect(formatRideStatusLabel('pending'), 'Pending');
    });

    test('returns a readable label for accepted rides', () {
      expect(formatRideStatusLabel('accepted'), 'Accepted');
    });

    test('falls back to pending when no status is provided', () {
      expect(formatRideStatusLabel(null), 'Pending');
    });
  });
}
