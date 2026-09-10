import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/role_applications/models/role_application.dart';
import 'package:tubigon_tourism/features/role_applications/presentation/applicant_role_applications_page.dart';
import 'package:tubigon_tourism/features/role_applications/presentation/role_application_review_page.dart';
import 'package:tubigon_tourism/features/role_applications/providers/role_application_providers.dart';
import 'package:tubigon_tourism/features/tourist_spots/repositories/tourist_spot_repository.dart';
import 'package:tubigon_tourism/features/authentication/auth_provider.dart';

class _TouristAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isLoggedIn: true,
        role: UserRole.tourist,
        userId: 'tourist-applicant',
      );
}

void main() {
  const submitted = RoleApplication(
    id: 'application-1',
    type: 'msme_owner',
    status: 'submitted',
    payload: {'business_name': 'Tubigon Test Store'},
    history: [],
    applicant: {'name': 'Tourist Applicant', 'email': 'user@example.test'},
  );

  test('role application model exposes controlled edit states', () {
    final changes = RoleApplication.fromJson({
      'id': 'one',
      'application_type': 'tourism_partner',
      'status': 'needs_changes',
      'payload': {'organization': 'Tourism Group'},
      'history': [
        {'action': 'changes_requested'}
      ],
    });
    expect(changes.editable, isTrue);
    expect(changes.withdrawable, isTrue);
    expect(changes.typeLabel, 'Tourism Partner');
    expect(changes.history.single['action'], 'changes_requested');
  });

  testWidgets('applicant page shows real access types and application status',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_TouristAuthNotifier.new),
        roleApplicationOptionsProvider.overrideWith((ref) async => {
              'msme_applications_enabled': true,
              'partner_applications_enabled': true,
              'eligible': {
                'msme_owner': true,
                'tourism_partner': true,
              },
            }),
        myRoleApplicationsProvider.overrideWith((ref) async => [submitted]),
      ],
      child: const MaterialApp(home: ApplicantRoleApplicationsPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Apply as MSME Owner'), findsOneWidget);
    expect(find.text('Apply as Tourism Partner'), findsOneWidget);
    expect(find.textContaining('submitted'), findsOneWidget);
    expect(find.textContaining('Tubigon Test Store'), findsNothing);
  });

  testWidgets('LGU queue identifies verification responsibility',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        lguRoleApplicationsProvider
            .overrideWith((ref, filter) async => [submitted]),
      ],
      child: const MaterialApp(home: RoleApplicationReviewPage(admin: false)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Role Applications'), findsOneWidget);
    expect(find.textContaining('Role provisioning remains restricted to Admin'),
        findsOneWidget);
    expect(find.text('Tourist Applicant'), findsOneWidget);
  });

  testWidgets('application wizard is a five-step controlled form',
      (tester) async {
    const draft = RoleApplication(
      id: 'draft-1',
      type: 'msme_owner',
      status: 'draft',
      payload: {},
      history: [],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        roleApplicationOptionsProvider.overrideWith((ref) async => {
              'msme_categories': ['Food & Dining', 'Retail'],
            }),
        touristSpotsListProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(home: RoleApplicationWizard(application: draft)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Applicant Information'), findsOneWidget);
    expect(find.text('Business Information'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Supporting Evidence'), findsOneWidget);
    expect(find.text('Review & Submit'), findsOneWidget);
    expect(find.text('Save Draft'), findsOneWidget);
  });
}
