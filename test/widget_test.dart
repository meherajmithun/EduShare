// EduShare widget tests — Contributor Dashboard smoke tests.
//
// These tests verify the key data-flow fixes introduced for the dashboard:
//   1. MyUploadsScreen accepts an initialFilter parameter
//   2. ContributorDashboardScreen can be instantiated without errors

import 'package:flutter_test/flutter_test.dart';
import 'package:edushare/views/upload/my_uploads_screen.dart';
import 'package:edushare/views/home/contributor_dashboard_screen.dart';

void main() {
  group('MyUploadsScreen', () {
    test('defaults initialFilter to all', () {
      const screen = MyUploadsScreen();
      expect(screen.initialFilter, equals('all'));
    });

    test('accepts approved initialFilter', () {
      const screen = MyUploadsScreen(initialFilter: 'approved');
      expect(screen.initialFilter, equals('approved'));
    });

    test('accepts pending initialFilter', () {
      const screen = MyUploadsScreen(initialFilter: 'pending');
      expect(screen.initialFilter, equals('pending'));
    });

    test('accepts rejected initialFilter', () {
      const screen = MyUploadsScreen(initialFilter: 'rejected');
      expect(screen.initialFilter, equals('rejected'));
    });
  });

  group('ContributorDashboardScreen', () {
    test('can be instantiated', () {
      const screen = ContributorDashboardScreen();
      expect(screen, isNotNull);
    });
  });
}
