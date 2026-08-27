/// Generic wrapper for all API responses from the Laravel backend.
///
/// Laravel returns JSON in the format:
/// ```json
/// {
///   "success": true,
///   "message": "...",
///   "data": { ... },
///   "meta": { "current_page": 1, "total": 50, ... }
/// }
/// ```
class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    required this.message,
    required this.data,
    this.meta,
  });

  final bool success;
  final String message;
  final T data;
  final PaginationMeta? meta;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String? ?? '',
      data: fromJsonT(json['data']),
      meta: json['meta'] != null
          ? PaginationMeta.fromJson(json['meta'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isPaginated => meta != null;

  @override
  String toString() =>
      'ApiResponse(success: $success, message: $message, meta: $meta)';
}

/// Pagination metadata returned by paginated list endpoints.
class PaginationMeta {
  const PaginationMeta({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    this.from,
    this.to,
  });

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final int? from;
  final int? to;

  bool get hasNextPage => currentPage < lastPage;
  bool get hasPreviousPage => currentPage > 1;
  bool get isFirstPage => currentPage == 1;
  bool get isLastPage => currentPage == lastPage;

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      currentPage: json['current_page'] as int? ?? 1,
      lastPage: json['last_page'] as int? ?? 1,
      perPage: json['per_page'] as int? ?? 15,
      total: json['total'] as int? ?? 0,
      from: json['from'] as int?,
      to: json['to'] as int?,
    );
  }

  @override
  String toString() =>
      'PaginationMeta(page: $currentPage/$lastPage, total: $total)';
}
