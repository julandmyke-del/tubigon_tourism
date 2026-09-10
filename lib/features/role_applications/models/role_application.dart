class RoleApplication {
  const RoleApplication({
    required this.id,
    required this.type,
    required this.status,
    required this.payload,
    required this.history,
    this.applicant,
    this.requestedSpot,
    this.linkedMsme,
    this.requestedMsmeCategory,
    this.recommendedMsmeCategory,
    this.finalMsmeCategory,
    this.lguReviewer,
    this.adminReviewer,
    this.lguNotes,
    this.adminNotes,
    this.submittedAt,
    this.updatedAt,
  });

  final String id;
  final String type;
  final String status;
  final Map<String, dynamic> payload;
  final List<Map<String, dynamic>> history;
  final Map<String, dynamic>? applicant;
  final Map<String, dynamic>? requestedSpot;
  final Map<String, dynamic>? linkedMsme;
  final Map<String, dynamic>? requestedMsmeCategory;
  final Map<String, dynamic>? recommendedMsmeCategory;
  final Map<String, dynamic>? finalMsmeCategory;
  final Map<String, dynamic>? lguReviewer;
  final Map<String, dynamic>? adminReviewer;
  final String? lguNotes;
  final String? adminNotes;
  final DateTime? submittedAt;
  final DateTime? updatedAt;

  String get typeLabel =>
      type == 'msme_owner' ? 'MSME Owner' : 'Tourism Partner';
  bool get editable => status == 'draft' || status == 'needs_changes';
  bool get withdrawable =>
      status == 'draft' || status == 'submitted' || status == 'needs_changes';

  factory RoleApplication.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? map(dynamic value) =>
        value is Map ? Map<String, dynamic>.from(value) : null;
    return RoleApplication(
      id: json['id']?.toString() ?? '',
      type: json['application_type']?.toString() ?? '',
      status: json['status']?.toString() ?? 'draft',
      payload: map(json['payload']) ?? const {},
      history: (json['history'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList(growable: false),
      applicant: map(json['applicant']),
      requestedSpot: map(json['requested_tourist_spot']),
      linkedMsme: map(json['linked_msme']),
      requestedMsmeCategory: map(json['requested_msme_category']),
      recommendedMsmeCategory: map(json['recommended_msme_category']),
      finalMsmeCategory: map(json['final_msme_category']),
      lguReviewer: map(json['lgu_reviewer']),
      adminReviewer: map(json['admin_reviewer']),
      lguNotes: json['lgu_notes']?.toString(),
      adminNotes: json['admin_notes']?.toString(),
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }
}
