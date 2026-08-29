import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/authentication/auth_provider.dart';

void main() {
  test('the five controlled account roles retain their portal destinations',
      () {
    const destinations = <UserRole, String>{
      UserRole.tourist: '/home',
      UserRole.msmeOwner: '/msme-portal',
      UserRole.lguStaff: '/lgu',
      UserRole.admin: '/admin',
      UserRole.tourismPartner: '/tourism-partner',
    };

    for (final entry in destinations.entries) {
      final state = AuthState(
        isLoggedIn: true,
        role: entry.key,
        email: '${entry.key.name}@example.test',
      );

      expect(state.isAuthenticated, isTrue);
      expect(state.role, entry.key);
      expect(state.homeRoute, entry.value);
    }
  });

  test('guest browsing remains on the tourist home destination', () {
    const guest = AuthState(isGuest: true, role: UserRole.guest);

    expect(guest.isAuthenticated, isTrue);
    expect(guest.homeRoute, '/home');
  });
}
