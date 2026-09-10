import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/core/constants/app_constants.dart';
import 'package:tubigon_tourism/features/admin/providers/admin_providers.dart';
import 'package:tubigon_tourism/features/role_applications/models/role_application.dart';

void main() {
  test('role application keeps requested recommended and final categories', () {
    final application = RoleApplication.fromJson({
      'id': 'application-1',
      'application_type': 'msme_owner',
      'status': 'approved',
      'payload': {'business_category': 'Food & Dining'},
      'requested_msme_category': {'id': 'food', 'name': 'Food & Dining'},
      'recommended_msme_category': {'id': 'retail', 'name': 'Retail'},
      'final_msme_category': {'id': 'transport', 'name': 'Transport'},
    });

    expect(application.requestedMsmeCategory?['id'], 'food');
    expect(application.recommendedMsmeCategory?['id'], 'retail');
    expect(application.finalMsmeCategory?['id'], 'transport');
    expect(application.payload['business_category'], 'Food & Dining');
  });

  test('activity log query identity includes all server-side filters', () {
    const first = AdminActivityLogQuery(
      page: 2,
      role: 'lgu_staff',
      action: 'profile_updated',
      dateFrom: '2026-09-01',
      dateTo: '2026-09-06',
      search: 'destination',
    );
    const same = AdminActivityLogQuery(
      page: 2,
      role: 'lgu_staff',
      action: 'profile_updated',
      dateFrom: '2026-09-01',
      dateTo: '2026-09-06',
      search: 'destination',
    );
    const otherPage = AdminActivityLogQuery(page: 3, role: 'lgu_staff');

    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(first, isNot(otherPage));
  });

  test('application brand is Tour Tubigon', () {
    expect(AppConstants.appName, 'Tour Tubigon');
  });
}
