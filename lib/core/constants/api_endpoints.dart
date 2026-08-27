import 'app_constants.dart';

/// All API endpoint paths — never hardcode these elsewhere.
abstract final class ApiEndpoints {
  static const String _base = AppConstants.apiPrefix;

  // ─── Auth ─────────────────────────────────────────────────────────────────
  static const String login = '$_base/auth/login';
  static const String register = '$_base/auth/register';
  static const String googleAuth = '$_base/auth/google';
  static const String logout = '$_base/auth/logout';
  static const String refreshToken = '$_base/auth/refresh';
  static const String forgotPassword = '$_base/auth/forgot-password';
  static const String resetPassword = '$_base/auth/reset-password';
  static const String verifyEmail = '$_base/auth/verify-email';
  static const String resendVerificationEmail =
      '$_base/auth/email/verification-notification';
  static const String verificationStatus = '$_base/auth/verification-status';
  static const String me = '$_base/auth/me';

  // ─── Users ────────────────────────────────────────────────────────────────
  static const String users = '$_base/users';
  static String userById(String id) => '$_base/users/$id';
  static String userProfile(String id) => '$_base/users/$id';
  static String updateUserProfile(String id) => '$_base/users/$id';
  static String uploadAvatar(String id) => '$_base/users/$id/avatar';
  static const String updateProfile = '$_base/users/profile';
  static const String updateAvatar = '$_base/users/avatar';
  static const String changePassword = '$_base/users/password';

  // ─── Tourist Spots ────────────────────────────────────────────────────────
  static const String touristSpots = '$_base/tourist-spots';
  static String touristSpotById(String id) => '$_base/tourist-spots/$id';
  static String touristSpotsByCategory(String categoryId) =>
      '$_base/tourist-spots?category=$categoryId';
  static String nearbySpots(double lat, double lng, double radiusKm) =>
      '$_base/tourist-spots/nearby?lat=$lat&lng=$lng&radius=$radiusKm';
  static const String spotCategories = '$_base/spot-categories';

  // ─── Establishments ───────────────────────────────────────────────────────
  static const String establishments = '$_base/establishments';
  static String establishmentById(String id) => '$_base/establishments/$id';
  static const String establishmentCategories =
      '$_base/establishment-categories';

  // ─── MSMEs ────────────────────────────────────────────────────────────────
  static const String msmes = '$_base/msmes';
  static String msmeById(String id) => '$_base/msmes/$id';
  static const String myMsme = '$_base/msmes/mine';
  static const String registerMsme = '$_base/msmes/register';

  // ─── Reservations ─────────────────────────────────────────────────────────
  static const String reservations = '$_base/reservations';
  static const String reservationStatuses = '$_base/reservations/statuses';
  static String reservationById(String uuid) => '$_base/reservations/$uuid';
  static const String myReservations = '$_base/reservations/mine';
  static String cancelReservation(String uuid) =>
      '$_base/reservations/$uuid/cancel';
  static String rescheduleReservation(String uuid) =>
      '$_base/reservations/$uuid/reschedule';

  // Itineraries
  static const String itineraries = '$_base/itineraries';
  static String itinerary(String id) => '$itineraries/$id';
  static String itineraryItems(String id) => '${itinerary(id)}/items';
  static String itineraryItem(String id, String itemId) =>
      '${itineraryItems(id)}/$itemId';
  static String reorderItineraryItems(String id) =>
      '${itineraryItems(id)}/reorder';

  // ─── Reviews ──────────────────────────────────────────────────────────────
  static const String reviews = '$_base/reviews';
  static String reviewsBySpot(String spotId) =>
      '$_base/tourist-spots/$spotId/reviews';
  static String reviewsByEstablishment(String estId) =>
      '$_base/establishments/$estId/reviews';
  static String reviewById(String id) => '$_base/reviews/$id';

  // ─── Favorites ────────────────────────────────────────────────────────────
  static const String favorites = '$_base/favorites';
  static const String toggleFavorite = '$_base/favorites/toggle';

  // ─── Ferry Schedules ──────────────────────────────────────────────────────
  static const String ferrySchedules = '$_base/ferry-schedules';
  static String ferryScheduleById(String id) => '$_base/ferry-schedules/$id';

  // ─── Eco Tips ─────────────────────────────────────────────────────────────
  static const String ecoTips = '$_base/eco-tips';
  static String ecoTipsBySpot(String spotId) =>
      '$_base/tourist-spots/$spotId/eco-tips';

  // ─── Waste Reports ────────────────────────────────────────────────────────
  static const String wasteReports = '$_base/waste-reports';
  static String wasteReportById(String uuid) => '$_base/waste-reports/$uuid';
  static const String myWasteReports = '$_base/waste-reports/mine';

  // ─── Emergency Contacts ───────────────────────────────────────────────────
  static const String emergencyContacts = '$_base/emergency-contacts';
  static const String adminEmergencyContacts =
      '$_base/admin/emergency-contacts';
  static String adminEmergencyContact(String id) =>
      '$adminEmergencyContacts/$id';
  static String adminEmergencyContactStatus(String id) =>
      '$adminEmergencyContacts/$id/status';
  static String adminVerifyEmergencyContact(String id) =>
      '$adminEmergencyContacts/$id/verify';

  // ─── Announcements ────────────────────────────────────────────────────────
  static const String announcements = '$_base/announcements';

  // ─── Notifications ────────────────────────────────────────────────────────
  static const String notifications = '$_base/notifications';
  static const String markAllRead = '$_base/notifications/read-all';
  static String markRead(String id) => '$_base/notifications/$id/read';
  static const String unreadCount = '$_base/notifications/unread-count';

  // ─── Analytics & Admin ────────────────────────────────────────────────────
  static const String analytics = '$_base/analytics';
  static const String adminDashboardStats = '$_base/admin/dashboard-stats';
  static const String adminActivityLogs = '$_base/admin/activity-logs';
  static const String adminUsers = '$_base/admin/users';
  static const String adminRoles = '$_base/admin/roles';
  static String adminUpdateUserRole(String id) => '$_base/admin/users/$id/role';
  static String adminUpdateUserVerification(String id) =>
      '$_base/admin/users/$id/verify';
  static String adminDeleteUser(String id) => '$_base/admin/users/$id';
  static String adminUpdateMsmeVerification(String id) =>
      '$_base/admin/msmes/$id/verify';
  static String adminDeleteMsme(String id) => '$_base/admin/msmes/$id';
  static const String adminCreateSpot = '$_base/admin/tourist-spots';
  static String adminUpdateSpot(String id) => '$_base/admin/tourist-spots/$id';
  static String adminDeleteSpot(String id) => '$_base/admin/tourist-spots/$id';
  static const String adminCreateCategory = '$_base/admin/spot-categories';
  static String adminUpdateCategory(String id) =>
      '$_base/admin/spot-categories/$id';
  static String adminDeleteCategory(String id) =>
      '$_base/admin/spot-categories/$id';
  static String adminUpdateReservationStatus(String id) =>
      '$_base/admin/reservations/$id/status';

  // ─── System Settings ──────────────────────────────────────────────────────
  static const String systemSettings = '$_base/system-settings';
  static const String appSettings = '$_base/settings';
  static const String mapLocations = '$_base/map/locations';
  static const String authenticatedMapLocations =
      '$_base/map/locations/authenticated';
  static const String placeCategories = '$_base/place-categories';
  static String placeById(String id) => '$_base/places/$id';
  static String managedMapLocations(String scope) =>
      '$_base/$scope/map-locations';
  static String managedMapLocation(String scope, String id) =>
      '${managedMapLocations(scope)}/$id';
  static String managedMapLocationAction(
          String scope, String id, String action) =>
      '${managedMapLocation(scope, id)}/$action';
  static String managedMapLocationCategories(String scope) =>
      '$_base/$scope/map-location-categories';

  // ─── Sync ─────────────────────────────────────────────────────────────────
  static const String syncPush = '$_base/sync/push';
  static const String syncPull = '$_base/sync/pull';
  static const String syncStatus = '$_base/sync/status';

  // ─── Images ───────────────────────────────────────────────────────────────
  static const String uploadImage = '$_base/images/upload';
  static String deleteImage(String id) => '$_base/images/$id';

  // ─── LGU Staff Scoped Endpoints ───────────────────────────────────────────
  static const String lguDashboardStats = '$_base/lgu/dashboard-stats';
  static const String lguAnalytics = '$_base/lgu/analytics';
  static const String lguReports = '$_base/lgu/reports';
  static const String lguEmergencyContacts = '$_base/lgu/emergency-contacts';
  static String lguEmergencyContact(String id) => '$lguEmergencyContacts/$id';
  static String lguEmergencyContactStatus(String id) =>
      '$lguEmergencyContacts/$id/status';
  static String lguVerifyEmergencyContact(String id) =>
      '$lguEmergencyContacts/$id/verify';
  static String lguUpdateSpotStatus(String id) =>
      '$_base/lgu/tourist-spots/$id/status';
  static String lguVerifyMsme(String id) => '$_base/lgu/msmes/$id/verify';
  static String lguUpdateWasteStatus(String id) =>
      '$_base/lgu/waste-reports/$id/status';

  // ─── MSME Owner Portal Endpoints ──────────────────────────────────────────
  static const String msmeDashboardStats = '$_base/msme/dashboard-stats';
  static const String msmePortalListings = '$_base/msme/listings';
  static String msmePortalListingById(String id) => '$_base/msme/listings/$id';
  static const String msmePortalReservations = '$_base/msme/reservations';
  static String msmePortalReservationById(String id) =>
      '$_base/msme/reservations/$id';
  static String msmePortalUpdateReservationStatus(String id) =>
      '$_base/msme/reservations/$id/status';
  static const String msmePortalReviews = '$_base/msme/reviews';
  static const String msmePortalReviewStats = '$_base/msme/review-stats';
  static const String msmePortalAnalytics = '$_base/msme/analytics';
  static const String msmePortalNotifications = '$_base/msme/notifications';
  static const String msmePortalProfile = '$_base/msme/profile';
  static const String msmePortalPromotions = '$_base/msme/promotions';
  static const String msmePortalReports = '$_base/msme/reports';
}
