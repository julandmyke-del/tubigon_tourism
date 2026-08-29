import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/exceptions/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/sync_service.dart';
import '../../../database/database_helper.dart';
import '../../authentication/auth_provider.dart';

class Review {
  final String id;
  final String userId;
  final String authorName;
  final String reviewableType;
  final String reviewableId;
  final double rating;
  final String content;
  final String createdAt;

  Review({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.reviewableType,
    required this.reviewableId,
    required this.rating,
    required this.content,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final profile = json['user'] as Map<String, dynamic>?;
    final author = profile != null
        ? profile['name'] as String?
        : json['author_name'] as String?;
    return Review(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      authorName: author ?? 'Traveler',
      reviewableType: json['reviewable_type'] as String? ?? '',
      reviewableId: json['reviewable_id'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'author_name': authorName,
      'reviewable_type': reviewableType,
      'reviewable_id': reviewableId,
      'rating': rating.toInt(),
      'content': content,
      'created_at': createdAt,
    };
  }
}

class ReviewRepository {
  ReviewRepository({required this.apiClient, required this.ref});
  final ApiClient apiClient;
  final Ref ref;
  final dbHelper = DatabaseHelper.instance;

  String? get _userId => ref.read(authProvider).userId;

  Future<List<Review>> getReviews(
      String reviewableType, String reviewableId) async {
    if (!DatabaseHelper.isSupported) {
      return _fetchRemoteReviews(reviewableType, reviewableId);
    }

    final localResult = await dbHelper.query(
      'reviews',
      where: 'reviewable_type = ? AND reviewable_id = ? AND pending_delete = 0',
      whereArgs: [reviewableType, reviewableId],
      orderBy: 'created_at DESC',
    );

    List<Review> reviews = localResult.map((m) => Review.fromJson(m)).toList();

    if (SyncService.instance.isOnline) {
      try {
        final response = await apiClient.get(
          ApiEndpoints.reviews,
          queryParameters: {
            'reviewable_type': reviewableType,
            'reviewable_id': reviewableId,
          },
        );

        if (response.statusCode == 200 &&
            response.data['status'] == 'success') {
          final remoteData = response.data['data'] as List<dynamic>;

          for (final item in remoteData) {
            final row = item as Map<String, dynamic>;
            final uuid = row['id'] as String;
            final localReviewsResult = await dbHelper.query(
              'reviews',
              where: 'id = ?',
              whereArgs: [uuid],
            );

            final reviewModel = Review.fromJson(row);
            final reviewJson = reviewModel.toJson();

            if (localReviewsResult.isEmpty) {
              await dbHelper.insert('reviews', reviewJson);
            } else {
              final localRow = localReviewsResult.first;
              if ((localRow['dirty'] as int? ?? 0) == 0) {
                await dbHelper.update('reviews', reviewJson,
                    where: 'id = ?', whereArgs: [uuid]);
              }
            }
          }

          final updatedLocal = await dbHelper.query(
            'reviews',
            where:
                'reviewable_type = ? AND reviewable_id = ? AND pending_delete = 0',
            whereArgs: [reviewableType, reviewableId],
            orderBy: 'created_at DESC',
          );
          reviews = updatedLocal.map((m) => Review.fromJson(m)).toList();
        }
      } catch (_) {}
    }

    return reviews;
  }

  Future<bool> addReview({
    required String reviewableType,
    required String reviewableId,
    required double rating,
    required String content,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Must be logged in to leave a review.');
    final cleanContent = content.trim();
    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5.');
    }
    if (cleanContent.length < 3 || cleanContent.length > 1000) {
      throw Exception('Review must be between 3 and 1000 characters.');
    }

    if (!DatabaseHelper.isSupported) {
      return _addRemoteReview(
        reviewableType: reviewableType,
        reviewableId: reviewableId,
        rating: rating,
        content: cleanContent,
      );
    }

    final reviewId = const Uuid().v4();
    final authorName = ref.read(authProvider).name ?? 'You';

    final newReview = Review(
      id: reviewId,
      userId: userId,
      authorName: authorName,
      reviewableType: reviewableType,
      reviewableId: reviewableId,
      rating: rating,
      content: cleanContent,
      createdAt: DateTime.now().toIso8601String(),
    );

    final reviewJson = newReview.toJson();
    reviewJson['dirty'] = 1;
    reviewJson['sync_status'] = 'pending_insert';

    await dbHelper.insert('reviews', reviewJson);

    if (SyncService.instance.isOnline) {
      try {
        final response = await apiClient.post(
          ApiEndpoints.reviews,
          data: {
            'reviewable_type': reviewableType,
            'reviewable_id': reviewableId,
            'rating': rating.toInt(),
            'content': cleanContent,
          },
        );

        if (response.statusCode == 201 &&
            response.data['status'] == 'success') {
          final serverReview = Review.fromJson(
            response.data['data'] as Map<String, dynamic>,
          ).toJson()
            ..['sync_status'] = 'synced'
            ..['dirty'] = 0
            ..['pending_delete'] = 0;
          await dbHelper
              .delete('reviews', where: 'id = ?', whereArgs: [reviewId]);
          await dbHelper.insert('reviews', serverReview);
          return true;
        }
        throw Exception('The review could not be accepted by the server.');
      } catch (error) {
        if (error is NetworkException) return false;
        await dbHelper
            .delete('reviews', where: 'id = ?', whereArgs: [reviewId]);
        rethrow;
      }
    }
    return false;
  }

  Future<List<Review>> _fetchRemoteReviews(
      String reviewableType, String reviewableId) async {
    final response = await apiClient.get(
      ApiEndpoints.reviews,
      queryParameters: {
        'reviewable_type': reviewableType,
        'reviewable_id': reviewableId,
      },
    );
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw const FormatException('Invalid reviews response.');
    }
    final rows = response.data['data'];
    if (rows is! List) throw const FormatException('Invalid reviews data.');
    return rows
        .whereType<Map<String, dynamic>>()
        .map(Review.fromJson)
        .toList(growable: false);
  }

  Future<bool> _addRemoteReview({
    required String reviewableType,
    required String reviewableId,
    required double rating,
    required String content,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.reviews,
      data: {
        'reviewable_type': reviewableType,
        'reviewable_id': reviewableId,
        'rating': rating.toInt(),
        'content': content,
      },
    );
    if (response.statusCode != 201 || response.data['status'] != 'success') {
      throw Exception('Unable to submit the review. Please try again.');
    }
    return true;
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ReviewRepository(apiClient: client, ref: ref);
});

final spotReviewsProvider =
    FutureProvider.family<List<Review>, (String, String)>((ref, arg) async {
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getReviews(arg.$1, arg.$2);
});
