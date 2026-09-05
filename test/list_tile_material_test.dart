import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/authentication/auth_provider.dart';
import 'package:tubigon_tourism/features/userpage/presentation/pages/profile_page.dart';

class _GuestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(role: UserRole.guest);
}

void main() {
  testWidgets('profile menu ListTiles paint on their own Material surface',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authProvider.overrideWith(_GuestAuthNotifier.new)],
        child: const MaterialApp(home: ProfilePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
