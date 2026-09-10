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
  static const String updatePassword = '$_base/auth/password';
  static const String verifyEmailCode = '$_base/auth/verify-email-code';
  static const String resendVerificationEmail =
      '$_base/auth/resend-verification-code';
  static const String changeUnverifiedEmail =
      '$_base/auth/change-unverified-email';
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

  // ─── Tourist Spots ────────────────────────────────────────────────────────
  static const String touristSpots = '$_base/tourist-spots';
  static String touristSpotById(String id) => '$_base/tourist-spots/$id';
  static String touristSpotAvailability(String id) =>
      '$_base/tourist-spots/$id/availability';
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
  static const String wasteCategories = '$_base/waste-categories';
  static String wasteReportById(String uuid) => '$_base/waste-reports/$uuid';
  static String wasteReportImages(String uuid) =>
      '$_base/waste-reports/$uuid/images';
  static String wasteReportMedia(String uuid) =>
      '$_base/waste-reports/$uuid/media';
  static String wasteResolutionMedia(String uuid) =>
      '$_base/waste-reports/$uuid/resolution-media';
  static const String myWasteReports = '$_base/waste-reports/mine';

  // ─── Emergency Contacts ───────────────────────────────────────────────────
  static const String emergencyContacts = '$_base/emergency-contacts';

  static const String carbonFactors = '$_base/carbon/factors';
  static const String carbonEstimates = '$_base/carbon/estimates';
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

  // Controlled MSME Owner / Tourism Partner access applications
  static const String roleApplications = '$_base/role-applications';
  static const String roleApplicationOptions = '$roleApplications/options';
  static String roleApplication(String id) => '$roleApplications/$id';
  static String submitRoleApplication(String id) =>
      '${roleApplication(id)}/submit';
  static String withdrawRoleApplication(String id) =>
      '${roleApplication(id)}/withdraw';

  // ─── Analytics & Admin ────────────────────────────────────────────────────
  static const String analytics = '$_base/analytics';
  static const String adminDashboardStats = '$_base/admin/dashboard-stats';
  static const String adminActivityLogs = '$_base/admin/activity-logs';
  static const String adminReviews = '$_base/admin/reviews';
  static const String adminUsers = '$_base/admin/users';
  static String adminUser(String id) => '$adminUsers/$id';
  static const String adminRoles = '$_base/admin/roles';
  static String adminUpdateUserRole(String id) => '$_base/admin/users/$id/role';
  static String adminUpdatePartnerAssignment(String id) =>
      '$_base/admin/users/$id/partner-assignment';
  static String adminUpdateUserVerification(String id) =>
      '$_base/admin/users/$id/verify';
  static String adminUpdateUserStatus(String id) =>
      '$_base/admin/users/$id/status';
  static String adminRevokeUserSessions(String id) =>
      '$_base/admin/users/$id/sessions';
  static String adminDeleteUser(String id) => '$_base/admin/users/$id';
  static const String adminMsmes = '$_base/admin/msmes';
  static String adminUpdateMsmeVerification(String id) =>
      '$_base/admin/msmes/$id/verify';
  static String adminDeleteMsme(String id) => '$_base/admin/msmes/$id';
  static const String adminSpots = '$_base/admin/tourist-spots';
  static const String adminCreateSpot = '$_base/admin/tourist-spots';
  static String adminUpdateSpot(String id) => '$_base/admin/tourist-spots/$id';
  static String adminUpdateSpotBooking(String id) =>
      '$_base/admin/tourist-spots/$id/booking';
  static String adminDeleteSpot(String id) => '$_base/admin/tourist-spots/$id';
  static const String adminCreateCategory = '$_base/admin/spot-categories';
  static String adminUpdateCategory(String id) =>
      '$_base/admin/spot-categories/$id';
  static String adminDeleteCategory(String id) =>
      '$_base/admin/spot-categories/$id';
  static String adminUpdateReservationStatus(String id) =>
      '$_base/admin/reservations/$id/status';
  static String adminUpdateWasteReportStatus(String id) =>
      '$_base/admin/waste-reports/$id/status';
  static const String adminFerrySchedules = '$_base/admin/ferry-schedules';
  static String adminFerrySchedule(String id) => '$adminFerrySchedules/$id';
  static const String adminEcoTips = '$_base/admin/eco-tips';
  static String adminEcoTip(String id) => '$adminEcoTips/$id';
  static const String adminAnnouncements = '$_base/admin/announcements';
  static String adminAnnouncement(String id) => '$adminAnnouncements/$id';
  static String adminSystemSettings(String id) =>
      '$_base/admin/system-settings/$id';
  static const String adminAccessRequests = '$_base/admin/access-requests';
  static String adminAccessRequest(String id) => '$adminAccessRequests/$id';
  static String adminAccessRequestAction(String id, String action) =>
      '${adminAccessRequest(id)}/$action';

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
  static const String lguActivity = '$_base/lgu/activity';
  static const String lguAnnouncements = '$_base/lgu/announcements';
  static const String lguAnalytics = '$_base/lgu/analytics';
  static const String lguReports = '$_base/lgu/reports';
  static const String lguRoleApplications = '$_base/lgu/role-applications';
  static String lguRoleApplication(String id) => '$lguRoleApplications/$id';
  static String lguRoleApplicationAction(String id, String action) =>
      '${lguRoleApplication(id)}/$action';
  static const String lguEmergencyContacts = '$_base/lgu/emergency-contacts';
  static String lguEmergencyContact(String id) => '$lguEmergencyContacts/$id';
  static String lguEmergencyContactStatus(String id) =>
      '$lguEmergencyContacts/$id/status';
  static String lguVerifyEmergencyContact(String id) =>
      '$lguEmergencyContacts/$id/verify';
  static String lguEmergencyContactVerification(String id) =>
      '$lguEmergencyContacts/$id/verification';
  static String lguUpdateSpotStatus(String id) =>
      '$_base/lgu/tourist-spots/$id/status';
  static String lguVerifyMsme(String id) => '$_base/lgu/msmes/$id/verify';
  static String lguUpdateWasteStatus(String id) =>
      '$_base/lgu/waste-reports/$id/status';
  static const String lguMsmes = '$_base/lgu/msmes';
  static String lguMsme(String id) => '$lguMsmes/$id';
  static const String lguTouristSpots = '$_base/lgu/tourist-spots';
  static String lguUpdateTouristSpot(String id) =>
      '$_base/lgu/tourist-spots/$id';
  static String lguUpdateSpotBooking(String id) =>
      '$_base/lgu/tourist-spots/$id/booking';
  static const String lguReservations = '$_base/lgu/reservations';
  static String lguReservation(String id) => '$lguReservations/$id';
  static String lguUpdateReservationStatus(String id) =>
      '$lguReservations/$id/status';
  static const String lguTourismListings = '$_base/lgu/tourism-listings';
  static String lguReviewTourismListing(String id) =>
      '$lguTourismListings/$id/review';
  static const String lguFerrySchedules = '$_base/lgu/ferry-schedules';
  static const String lguFerryPorts = '$_base/lgu/ferry-ports';
  static const String lguFerryRoutes = '$_base/lgu/ferry-routes';
  static String lguFerryPort(String id) => '$lguFerryPorts/$id';
  static String lguFerryRoute(String id) => '$lguFerryRoutes/$id';
  static String lguFerrySchedule(String id) => '$lguFerrySchedules/$id';
  static const String lguEcoTips = '$_base/lgu/eco-tips';
  static String lguEcoTip(String id) => '$lguEcoTips/$id';

  // ─── MSME Owner Portal Endpoints ──────────────────────────────────────────
  static const String msmeDashboardStats = '$_base/msme/dashboard-stats';
  static const String createMsmeBusiness = '$_base/msmes';
  static const String msmePortalReservations = '$_base/msme/reservations';
  static String msmePortalReservationById(String id) =>
      '$_base/msme/reservations/$id';
  static String msmePortalUpdateReservationStatus(String id) =>
      '$_base/msme/reservations/$id/status';
  static const String msmePortalReviews = '$_base/msme/reviews';
  static const String msmePortalAnalytics = '$_base/msme/analytics';
  static const String msmePortalNotifications = notifications;
  static const String msmePortalProfile = '$_base/msme/profile';
  static const String msmeSubmitProfile = '$_base/msme/profile/submit';
  static const String msmePortalPromotions = '$_base/msme/promotions';
  static const String msmePortalReports = '$_base/msme/reports';

  // Tourism Partner
  static const String partnerBase = '$_base/partner';
  static const String partnerDashboardStats = '$partnerBase/dashboard-stats';
  static const String partnerAssignment = '$partnerBase/assignment';
  static const String partnerActivity = '$partnerBase/activity';
  static const String partnerListings = '$partnerBase/listings';
  static const String partnerTouristSpots = '$partnerBase/tourist-spots';
  static String partnerTouristSpot(String id) => '$partnerTouristSpots/$id';
  static String partnerTouristSpotBookingAvailability(String id) =>
      '${partnerTouristSpot(id)}/booking-availability';
  static String partnerListing(String id) => '$partnerListings/$id';
  static String partnerSubmitListing(String id) =>
      '$partnerListings/$id/submit';
  static const String partnerReservations = '$partnerBase/reservations';
  static String partnerReservation(String id) => '$partnerReservations/$id';
  static String partnerReservationStatus(String id) =>
      '$partnerReservations/$id/status';
  static const String partnerNotifications = '$partnerBase/notifications';
  static const String partnerNotificationsUnreadCount =
      '$partnerNotifications/unread-count';
  static String partnerNotificationRead(String id) =>
      '$partnerNotifications/$id/read';
  static const String partnerNotificationsReadAll =
      '$partnerNotifications/read-all';
  static String partnerNotification(String id) => '$partnerNotifications/$id';
  static const String partnerReviews = '$partnerBase/reviews';
  static const String partnerReviewStats = '$partnerBase/review-stats';
  static const String partnerAnalytics = '$partnerBase/analytics';
  static const String partnerProfile = '$partnerBase/profile';
  static const String partnerPassword = '$partnerBase/password';
  static const String partnerImageUpload = '$partnerBase/images/upload';
  static String publicBookingOfferings(String spotId) =>
      '$_base/tourist-spots/$spotId/booking-offerings';
  static const String offeringReservations = '$_base/offering-reservations';
  static String partnerOfferings(String spotId) =>
      '$partnerBase/tourist-spots/$spotId/offerings';
  static String partnerOffering(String spotId, String offeringId) =>
      '${partnerOfferings(spotId)}/$offeringId';
  static String publicSpotGallery(String spotId) =>
      '$_base/tourist-spots/$spotId/gallery';
  static String partnerSpotGallery(String spotId) =>
      '$partnerBase/tourist-spots/$spotId/gallery';
  static String partnerSpotMedia(String spotId, String mediaId) =>
      '${partnerSpotGallery(spotId)}/$mediaId';
  static String reservationMessages(String reservationId) =>
      '$_base/reservations/$reservationId/messages';
  static const String concernCategories = '$_base/concern-categories';
  static const String concerns = '$_base/concerns';
  static String concern(String id) => '$concerns/$id';
  static String concernMessages(String id) => '${concern(id)}/messages';
  static const String lguConcerns = '$_base/lgu/concerns';
  static String lguConcern(String id) => '$lguConcerns/$id';
  static const String adminConcerns = '$_base/admin/concerns';
  static String adminConcern(String id) => '$adminConcerns/$id';
  static const String publicAnnouncements = '$_base/announcements/public';
  static String announcementRead(String id) => '$_base/announcements/$id/read';
  static String announcementDismiss(String id) =>
      '$_base/announcements/$id/dismiss';
  static const String ferryCatalogs = '$_base/ferry-catalogs';
  static String lguTouristSpotBookingAvailability(String id) =>
      '$_base/lgu/tourist-spots/$id/booking-availability';
  static const String tourismListings = '$_base/tourism-listings';
  static String tourismListing(String id) => '$tourismListings/$id';
}
