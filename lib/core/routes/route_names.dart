/// Route name constants — single source of truth for all named GoRouter routes.
abstract final class RouteNames {
  // ─── Root ─────────────────────────────────────────────────────────────────
  static const String splash = 'splash';
  static const String onboarding = 'onboarding';

  // ─── Auth ─────────────────────────────────────────────────────────────────
  static const String login = 'login';
  static const String register = 'register';
  static const String forgotPassword = 'forgot-password';
  static const String resetPassword = 'reset-password';
  static const String verifyEmail = 'verify-email';

  // ─── Main Shell (Bottom Nav) ──────────────────────────────────────────────
  static const String home = 'home';
  static const String explore = 'explore';
  static const String map = 'map';
  static const String reservations = 'reservations';
  static const String profile = 'profile';

  // ─── Tourist Spots ────────────────────────────────────────────────────────
  static const String touristSpots = 'tourist-spots';
  static const String touristSpotDetail = 'tourist-spot-detail';
  static const String explorePlaceDetail = 'explore-place-detail';
  static const String touristSpotAdmin = 'tourist-spot-admin';

  // ─── Establishments ───────────────────────────────────────────────────────
  static const String establishments = 'establishments';
  static const String establishmentDetail = 'establishment-detail';

  // ─── MSMEs ────────────────────────────────────────────────────────────────
  static const String msmeDirectory = 'msme-directory';
  static const String msmeDetail = 'msme-detail';
  static const String msmeDashboard = 'msme-dashboard';
  static const String msmeRegistration = 'msme-registration';

  // ─── Reservations ─────────────────────────────────────────────────────────
  static const String reservationDetail = 'reservation-detail';
  static const String createReservation = 'create-reservation';
  static const String reservationHistory = 'reservation-history';

  // ─── Reviews ──────────────────────────────────────────────────────────────
  static const String writeReview = 'write-review';
  static const String reviewList = 'review-list';

  // ─── Favorites ────────────────────────────────────────────────────────────
  static const String favorites = 'favorites';
  static const String offlineMaps = 'offline-maps';

  // ─── Ferry ────────────────────────────────────────────────────────────────
  static const String ferrySchedule = 'ferry-schedule';
  static const String ferryDetail = 'ferry-detail';

  // ─── Itinerary ────────────────────────────────────────────────────────────
  static const String itinerary = 'itinerary';
  static const String createItinerary = 'create-itinerary';
  static const String itineraryDetail = 'itinerary-detail';
  static const String itineraryMap = 'itinerary-map';

  // ─── Notifications ────────────────────────────────────────────────────────
  static const String notifications = 'notifications';

  // ─── Eco ──────────────────────────────────────────────────────────────────
  static const String ecoTips = 'eco-tips';

  // ─── Waste Reporting ──────────────────────────────────────────────────────
  static const String wasteReport = 'waste-report';
  static const String wasteReportHistory = 'waste-report-history';

  // ─── Emergency ────────────────────────────────────────────────────────────
  static const String emergencyContacts = 'emergency-contacts';

  // ─── Settings & Profile ───────────────────────────────────────────────────
  static const String settings = 'settings';
  static const String editProfile = 'edit-profile';

  // ─── Analytics / Admin ────────────────────────────────────────────────────
  static const String analytics = 'analytics';
  static const String adminDashboard = 'admin-dashboard';
  static const String adminMapLocations = 'admin-map-locations';

  // ─── Tourism Partner ──────────────────────────────────────────────────────
  static const String partnerDashboard = 'partner-dashboard';
  static const String partnerListings = 'partner-listings';
  static const String partnerCreateListing = 'partner-create-listing';
  static const String partnerEditListing = 'partner-edit-listing';
  static const String partnerReservations = 'partner-reservations';
  static const String partnerReservationDetail = 'partner-reservation-detail';
  static const String partnerNotifications = 'partner-notifications';
  static const String partnerReviews = 'partner-reviews';
  static const String partnerAnalytics = 'partner-analytics';
  static const String partnerProfile = 'partner-profile';
  static const String partnerEditProfile = 'partner-edit-profile';
  static const String partnerSettings = 'partner-settings';
  static const String partnerBusinessInfo = 'partner-business-info';

  // ─── LGU Staff ────────────────────────────────────────────────────────────
  static const String lguDashboard = 'lgu-dashboard';
  static const String lguTouristSpots = 'lgu-tourist-spots';
  static const String lguMsme = 'lgu-msme';
  static const String lguReservations = 'lgu-reservations';
  static const String lguWasteReports = 'lgu-waste-reports';
  static const String lguEmergency = 'lgu-emergency';
  static const String lguFerry = 'lgu-ferry';
  static const String lguEcoTips = 'lgu-eco-tips';
  static const String lguAnnouncements = 'lgu-announcements';
  static const String lguAnalytics = 'lgu-analytics';
  static const String lguReports = 'lgu-reports';
  static const String lguNotifications = 'lgu-notifications';
  static const String lguProfile = 'lgu-profile';
  static const String lguMapLocations = 'lgu-map-locations';

  // ─── MSME Owner Portal ───────────────────────────────────────────────────
  static const String msmePortalDashboard = 'msme-portal-dashboard';
  static const String msmePortalProfile = 'msme-portal-profile';
  static const String msmePortalListings = 'msme-portal-listings';
  static const String msmePortalCreateListing = 'msme-portal-create-listing';
  static const String msmePortalEditListing = 'msme-portal-edit-listing';
  static const String msmePortalGallery = 'msme-portal-gallery';
  static const String msmePortalReservations = 'msme-portal-reservations';
  static const String msmePortalReviews = 'msme-portal-reviews';
  static const String msmePortalAnalytics = 'msme-portal-analytics';
  static const String msmePortalPromotions = 'msme-portal-promotions';
  static const String msmePortalNotifications = 'msme-portal-notifications';
  static const String msmePortalReports = 'msme-portal-reports';
  static const String msmePortalAvailability = 'msme-portal-availability';
  static const String msmePortalSettings = 'msme-portal-settings';
  static const String msmePortalHelp = 'msme-portal-help';
}
