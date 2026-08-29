/// Asset path constants — single source of truth for all asset references.
abstract final class AssetPaths {
  // ─── Base Directories ─────────────────────────────────────────────────────
  static const String _images = 'assets/images';
  static const String _icons = 'assets/icons';
  static const String _animations = 'assets/animations';
  static const String _data = 'assets/data';

  // ─── Brand / Logo ─────────────────────────────────────────────────────────
  static const String logo = '$_images/logo.png';
  static const String logoWhite = '$_images/logo_white.png';
  static const String logoSmall = '$_images/logo_small.png';
  static const String splash = '$_images/splash.png';

  // ─── Onboarding ───────────────────────────────────────────────────────────
  static const String onboarding1 = '$_images/onboarding_1.jpg';
  static const String onboarding2 = '$_images/onboarding_2.jpg';
  static const String onboarding3 = '$_images/onboarding_3.jpg';
  static const String onboarding4 = '$_images/onboarding_4.jpg';
  static const String onboarding5 = '$_images/onboarding_5.jpg';
  static const String onboarding6 = '$_images/onboarding_6.jpg';

  // ─── Tourist Spots ────────────────────────────────────────────────────────
  static const String cabganIsland = '$_images/spots/cabgan_island.jpg';
  static const String dumogIslet = '$_images/spots/dumog_islet.jpg';
  static const String enchantedIlijanHill =
      '$_images/spots/enchanted_ilijan_hill.jpg';
  static const String spotPlaceholder = '$_images/spots/placeholder.jpg';

  // ─── Categories ───────────────────────────────────────────────────────────
  static const String categoryBeach = '$_icons/category_beach.svg';
  static const String categoryNature = '$_icons/category_nature.svg';
  static const String categoryHistorical = '$_icons/category_historical.svg';
  static const String categoryCultural = '$_icons/category_cultural.svg';
  static const String categoryAdventure = '$_icons/category_adventure.svg';
  static const String categoryFood = '$_icons/category_food.svg';
  static const String categoryEco = '$_icons/category_eco.svg';
  static const String categoryAccommodation =
      '$_icons/category_accommodation.svg';

  // ─── Empty States ─────────────────────────────────────────────────────────
  static const String emptySearch = '$_images/empty_search.png';
  static const String emptyFavorites = '$_images/empty_favorites.png';
  static const String emptyReservations = '$_images/empty_reservations.png';
  static const String emptyNotifications = '$_images/empty_notifications.png';
  static const String emptyReviews = '$_images/empty_reviews.png';
  static const String emptyGeneral = '$_images/empty_general.png';

  // ─── Error States ─────────────────────────────────────────────────────────
  static const String errorOffline = '$_images/error_offline.png';
  static const String errorServer = '$_images/error_server.png';
  static const String errorGeneral = '$_images/error_general.png';

  // ─── Lottie Animations ────────────────────────────────────────────────────
  static const String animLoading = '$_animations/loading.json';
  static const String animSuccess = '$_animations/success.json';
  static const String animError = '$_animations/error.json';
  static const String animOffline = '$_animations/offline.json';
  static const String animSearch = '$_animations/search.json';
  static const String animLocation = '$_animations/location.json';
  static const String animNature = '$_animations/nature.json';

  // ─── Map Markers ─────────────────────────────────────────────────────────
  static const String markerBeach = '$_icons/marker_beach.png';
  static const String markerNature = '$_icons/marker_nature.png';
  static const String markerHistorical = '$_icons/marker_historical.png';
  static const String markerFood = '$_icons/marker_food.png';
  static const String markerHotel = '$_icons/marker_hotel.png';
  static const String markerDefault = '$_icons/marker_default.png';

  // ─── Static Data ─────────────────────────────────────────────────────────
  static const String ferrySchedulesData = '$_data/ferry_schedules.json';
  static const String emergencyContactsData = '$_data/emergency_contacts.json';
  static const String ecoTipsData = '$_data/eco_tips.json';
}
