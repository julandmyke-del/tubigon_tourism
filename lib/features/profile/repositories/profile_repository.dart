import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../authentication/auth_provider.dart';

class ProfileRepository {
  const ProfileRepository(this._client);
  final ApiClient _client;

  Future<Map<String, dynamic>> getProfile(String userId) async {
    final response = await _client.get(ApiEndpoints.userProfile(userId));
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> updateProfile(
    String userId, {
    required String name,
    String? phone,
    String? bio,
  }) async {
    final response = await _client.put(
      ApiEndpoints.updateUserProfile(userId),
      data: {'name': name, 'phone': phone, 'bio': bio},
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

final currentProfileProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(authProvider).userId;
  if (userId == null || userId.isEmpty) return const {};
  return ref.watch(profileRepositoryProvider).getProfile(userId);
});
