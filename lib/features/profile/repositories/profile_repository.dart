import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

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
    String? address,
    String? barangay,
    String? bio,
    String? language,
    Map<String, dynamic>? preferences,
  }) async {
    final response = await _client.put(
      ApiEndpoints.updateUserProfile(userId),
      data: {
        'name': name,
        'phone': phone,
        'address': address,
        'barangay': barangay,
        'bio': bio,
        if (language != null) 'language': language,
        if (preferences != null) 'preferences': preferences,
      },
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<String> uploadAvatar(
      String userId, List<int> bytes, String filename) async {
    final response = await _client.post(
      ApiEndpoints.uploadAvatar(userId),
      data: FormData.fromMap({
        'avatar': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
    return response.data['data']['avatar_url']?.toString() ?? '';
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
