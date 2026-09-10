<?php

use App\Http\Controllers\Api\V1\AnalyticsController;
use App\Http\Controllers\Api\V1\AnnouncementController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BookingOfferingController;
use App\Http\Controllers\Api\V1\CarbonController;
use App\Http\Controllers\Api\V1\ConcernController;
use App\Http\Controllers\Api\V1\EcoTipController;
use App\Http\Controllers\Api\V1\EmergencyContactController;
use App\Http\Controllers\Api\V1\EstablishmentController;
use App\Http\Controllers\Api\V1\FavoriteController;
use App\Http\Controllers\Api\V1\FerryScheduleController;
use App\Http\Controllers\Api\V1\ImageController;
use App\Http\Controllers\Api\V1\ItineraryController;
use App\Http\Controllers\Api\V1\LguController;
use App\Http\Controllers\Api\V1\LguTouristSpotBookingAvailabilityController;
use App\Http\Controllers\Api\V1\MapController;
use App\Http\Controllers\Api\V1\MapLocationCategoryController;
use App\Http\Controllers\Api\V1\MapLocationController;
use App\Http\Controllers\Api\V1\MsmeController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\PartnerNotificationController;
use App\Http\Controllers\Api\V1\PartnerReservationController;
use App\Http\Controllers\Api\V1\PartnerTouristSpotController;
use App\Http\Controllers\Api\V1\ReservationController;
use App\Http\Controllers\Api\V1\ReservationMessageController;
use App\Http\Controllers\Api\V1\ReviewController;
use App\Http\Controllers\Api\V1\RoleApplicationController;
use App\Http\Controllers\Api\V1\SettingController;
use App\Http\Controllers\Api\V1\SpotCategoryController;
use App\Http\Controllers\Api\V1\SyncController;
use App\Http\Controllers\Api\V1\TourismListingController;
use App\Http\Controllers\Api\V1\TouristSpotController;
use App\Http\Controllers\Api\V1\TouristSpotGalleryController;
use App\Http\Controllers\Api\V1\UserController;
use App\Http\Controllers\Api\V1\WasteReportController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {

    // ─── Public Routes ────────────────────────────────────────────────────────
    Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:10,1');
    Route::post('/auth/register', [AuthController::class, 'register'])->middleware('throttle:5,1');
    Route::post('/auth/google', [AuthController::class, 'googleAuth'])->middleware('throttle:10,1');
    Route::post('/auth/forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:5,1');
    Route::post('/auth/reset-password', [AuthController::class, 'resetPassword'])->middleware('throttle:5,1');
    Route::get('/auth/email/verify/{id}/{hash}', [AuthController::class, 'verifyEmail'])->name('verification.verify');
    Route::post('/auth/verify-email-code', [AuthController::class, 'verifyEmailCode'])->middleware('throttle:10,1');
    Route::post('/auth/resend-verification-code', [AuthController::class, 'resendVerificationEmail'])->middleware('throttle:3,1');
    Route::post('/auth/change-unverified-email', [AuthController::class, 'changeUnverifiedEmail'])->middleware('throttle:3,1');
    Route::get('/auth/verification-status', [AuthController::class, 'verificationStatus'])->middleware('throttle:30,1');

    Route::get('/tourist-spots', [TouristSpotController::class, 'index']);
    Route::get('/tourist-spots/{id}', [TouristSpotController::class, 'show']);
    Route::get('/tourist-spots/{id}/availability', [TouristSpotController::class, 'availability']);
    Route::get('/tourist-spots/{spot}/booking-offerings', [BookingOfferingController::class, 'publicIndex']);
    Route::get('/tourist-spots/{spot}/gallery', [TouristSpotGalleryController::class, 'publicIndex']);
    Route::get('/tourist-spot-media/{media}', [TouristSpotGalleryController::class, 'content']);
    Route::get('/spot-categories', [SpotCategoryController::class, 'index']);

    Route::get('/establishments', [EstablishmentController::class, 'index']);
    Route::get('/establishments/{id}', [EstablishmentController::class, 'show']);

    Route::get('/msmes', [MsmeController::class, 'index']);
    Route::get('/msmes/{id}', [MsmeController::class, 'show']);
    Route::get('/tourism-listings', [TourismListingController::class, 'publicIndex']);
    Route::get('/tourism-listings/{id}', [TourismListingController::class, 'publicShow']);

    Route::get('/ferry-schedules', [FerryScheduleController::class, 'index']);
    Route::get('/ferry-catalogs', [FerryScheduleController::class, 'catalogs']);
    Route::get('/announcements/public', [AnnouncementController::class, 'publicIndex']);
    Route::get('/concern-categories', [ConcernController::class, 'categories']);
    Route::get('/eco-tips', [EcoTipController::class, 'index']);
    Route::get('/emergency-contacts', [EmergencyContactController::class, 'index']);
    Route::get('/waste-categories', [WasteReportController::class, 'categories']);
    Route::get('/carbon/factors', [CarbonController::class, 'factors']);
    Route::get('/reviews', [ReviewController::class, 'index']);
    Route::get('/system-settings', [SettingController::class, 'systemSettings']);
    Route::get('/map/locations', [MapController::class, 'publicIndex']);
    Route::get('/place-categories', [MapLocationCategoryController::class, 'index']);
    Route::get('/places/{id}', [MapLocationController::class, 'show']);

    // ─── Authenticated Routes (Sanctum) ───────────────────────────────────────
    Route::middleware('auth:sanctum')->group(function () {

        // Auth
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::put('/auth/password', [AuthController::class, 'updatePassword']);
        Route::get('/map/locations/authenticated', [MapController::class, 'authenticatedIndex']);

        // Users
        Route::get('/users/{id}', [UserController::class, 'show']);
        Route::put('/users/{id}', [UserController::class, 'update']);
        Route::post('/users/{id}/avatar', [UserController::class, 'uploadAvatar']);

        // Controlled privileged-role application workflow. Every applicant
        // endpoint scopes records to the authenticated user in the controller.
        Route::get('/role-applications/options', [RoleApplicationController::class, 'options']);
        Route::get('/role-applications', [RoleApplicationController::class, 'index']);
        Route::post('/role-applications', [RoleApplicationController::class, 'store']);
        Route::get('/role-applications/{id}', [RoleApplicationController::class, 'show']);
        Route::put('/role-applications/{id}', [RoleApplicationController::class, 'update']);
        Route::post('/role-applications/{id}/submit', [RoleApplicationController::class, 'submit']);
        Route::post('/role-applications/{id}/withdraw', [RoleApplicationController::class, 'withdraw']);

        // Reservations
        Route::get('/reservations', [ReservationController::class, 'index']);
        Route::get('/reservations/statuses', [ReservationController::class, 'statuses']);
        Route::get('/reservations/{id}', [ReservationController::class, 'show']);
        Route::post('/reservations', [ReservationController::class, 'store'])
            ->middleware('role:tourist');
        Route::post('/offering-reservations', [BookingOfferingController::class, 'reserve'])->middleware('role:tourist');
        Route::put('/reservations/{id}/cancel', [ReservationController::class, 'cancel'])
            ->middleware('role:tourist');
        Route::get('/reservations/{reservation}/messages', [ReservationMessageController::class, 'index']);
        Route::post('/reservations/{reservation}/messages', [ReservationMessageController::class, 'store']);
        Route::put('/reservations/{reservation}/messages/read', [ReservationMessageController::class, 'read']);

        Route::get('/concerns', [ConcernController::class, 'index']);
        Route::post('/concerns', [ConcernController::class, 'store']);
        Route::get('/concerns/{id}', [ConcernController::class, 'show']);
        Route::post('/concerns/{id}/messages', [ConcernController::class, 'reply']);
        Route::get('/concern-attachments/{attachment}', [ConcernController::class, 'attachment']);

        // Tourist itinerary planner. Ownership is enforced again in every controller action.
        Route::get('/itineraries', [ItineraryController::class, 'index']);
        Route::post('/itineraries', [ItineraryController::class, 'store']);
        Route::get('/itineraries/{id}', [ItineraryController::class, 'show']);
        Route::put('/itineraries/{id}', [ItineraryController::class, 'update']);
        Route::delete('/itineraries/{id}', [ItineraryController::class, 'destroy']);
        Route::post('/itineraries/{id}/items', [ItineraryController::class, 'storeItem']);
        Route::put('/itineraries/{id}/items/reorder', [ItineraryController::class, 'reorderItems']);
        Route::put('/itineraries/{id}/items/{item}', [ItineraryController::class, 'updateItem']);
        Route::delete('/itineraries/{id}/items/{item}', [ItineraryController::class, 'destroyItem']);

        // Reviews
        Route::post('/reviews', [ReviewController::class, 'store'])
            ->middleware('role:tourist');
        Route::delete('/reviews/{id}', [ReviewController::class, 'destroy']);

        // Favorites
        Route::get('/favorites', [FavoriteController::class, 'index'])
            ->middleware('role:tourist');
        Route::post('/favorites/toggle', [FavoriteController::class, 'toggle'])
            ->middleware('role:tourist');

        // Waste Reports
        Route::get('/waste-reports', [WasteReportController::class, 'index']);
        Route::get('/waste-reports/{id}', [WasteReportController::class, 'show']);
        Route::post('/waste-reports', [WasteReportController::class, 'store'])
            ->middleware('role:tourist');
        Route::post('/waste-reports/{id}/images', [WasteReportController::class, 'uploadImages']);
        Route::post('/waste-reports/{id}/media', [WasteReportController::class, 'uploadMedia']);
        Route::get('/waste-report-media/{media}', [WasteReportController::class, 'showMedia']);

        Route::get('/carbon/estimates', [CarbonController::class, 'index'])->middleware('role:tourist');
        Route::post('/carbon/estimates', [CarbonController::class, 'store'])->middleware('role:tourist');

        // Notifications
        Route::get('/notifications', [NotificationController::class, 'index']);
        Route::get('/notifications/unread-count', [NotificationController::class, 'unreadCount']);
        Route::put('/notifications/read-all', [NotificationController::class, 'markAllRead']);
        Route::put('/notifications/{id}/read', [NotificationController::class, 'markRead']);
        Route::get('/announcements', [AnnouncementController::class, 'index']);
        Route::get('/announcements/{id}', [AnnouncementController::class, 'show']);
        Route::put('/announcements/{id}/read', [AnnouncementController::class, 'markRead']);
        Route::put('/announcements/{id}/dismiss', [AnnouncementController::class, 'dismiss']);

        // Settings
        Route::get('/settings', [SettingController::class, 'index']);
        Route::put('/settings', [SettingController::class, 'update']);

        // Sync (Offline-first support)
        Route::post('/sync/push', [SyncController::class, 'push']);
        Route::get('/sync/pull', [SyncController::class, 'pull']);
        Route::get('/sync/status', [SyncController::class, 'status']);

        // Images
        Route::post('/images/upload', [ImageController::class, 'upload']);
        Route::delete('/images/{id}', [ImageController::class, 'destroy']);

        // MSME owner registration
        Route::post('/msmes', [MsmeController::class, 'store'])
            ->middleware('role:msme_owner,admin');

        Route::middleware('role:msme_owner,admin')->prefix('msme')->group(function () {
            Route::get('/dashboard-stats', [MsmeController::class, 'dashboardStats']);
            Route::get('/profile', [MsmeController::class, 'ownerProfile']);
            Route::put('/profile', [MsmeController::class, 'updateOwnerProfile']);
            Route::post('/profile/submit', [MsmeController::class, 'submitOwnerProfile']);
            Route::get('/reservations', [MsmeController::class, 'reservations']);
            Route::get('/reservations/{id}', [MsmeController::class, 'showReservation']);
            Route::put('/reservations/{id}/status', [MsmeController::class, 'updateReservationStatus']);
            Route::get('/reviews', [MsmeController::class, 'reviews']);
            Route::get('/analytics', [MsmeController::class, 'analytics']);
        });

        // ─── Tourism Partner Scoped Routes ────────────────────────────────────
        Route::middleware('role:tourism_partner')->prefix('partner')->group(function () {
            Route::get('/dashboard-stats', [TourismListingController::class, 'dashboardStats']);
            Route::get('/listings', [TourismListingController::class, 'index']);
            Route::get('/listings/{id}', [TourismListingController::class, 'show']);
            Route::post('/listings', [TourismListingController::class, 'store']);
            Route::put('/listings/{id}', [TourismListingController::class, 'update']);
            Route::delete('/listings/{id}', [TourismListingController::class, 'destroy']);
            Route::post('/listings/{id}/submit', [TourismListingController::class, 'submit']);

            Route::get('/assignment', [PartnerTouristSpotController::class, 'assignment'])
                ->middleware('role:tourism_partner');
            Route::get('/activity', [PartnerTouristSpotController::class, 'activity'])
                ->middleware('role:tourism_partner');
            Route::get('/tourist-spots', [PartnerTouristSpotController::class, 'index'])
                ->middleware('role:tourism_partner');
            Route::get('/tourist-spots/{id}', [PartnerTouristSpotController::class, 'show'])
                ->middleware('role:tourism_partner');
            Route::patch('/tourist-spots/{id}', [PartnerTouristSpotController::class, 'update'])
                ->middleware('role:tourism_partner');
            Route::patch('/tourist-spots/{id}/booking-availability', [PartnerTouristSpotController::class, 'updateBookingAvailability'])
                ->middleware('role:tourism_partner');
            Route::get('/tourist-spots/{spot}/offerings', [BookingOfferingController::class, 'partnerIndex']);
            Route::post('/tourist-spots/{spot}/offerings', [BookingOfferingController::class, 'store']);
            Route::put('/tourist-spots/{spot}/offerings/{offering}', [BookingOfferingController::class, 'update']);
            Route::delete('/tourist-spots/{spot}/offerings/{offering}', [BookingOfferingController::class, 'destroy']);
            Route::get('/tourist-spots/{spot}/gallery', [TouristSpotGalleryController::class, 'manageIndex']);
            Route::post('/tourist-spots/{spot}/gallery', [TouristSpotGalleryController::class, 'store']);
            Route::put('/tourist-spots/{spot}/gallery/reorder', [TouristSpotGalleryController::class, 'reorder']);
            Route::put('/tourist-spots/{spot}/gallery/{media}', [TouristSpotGalleryController::class, 'update']);

            Route::get('/reservations', [PartnerReservationController::class, 'index']);
            Route::get('/reservations/{id}', [PartnerReservationController::class, 'show']);
            Route::put('/reservations/{id}/status', [PartnerReservationController::class, 'updateStatus']);

            Route::get('/reviews', [TourismListingController::class, 'reviews']);
            Route::get('/review-stats', [TourismListingController::class, 'reviewStats']);
            Route::get('/analytics', [TourismListingController::class, 'analytics']);

            Route::get('/notifications', [PartnerNotificationController::class, 'index']);
            Route::get('/notifications/unread-count', [PartnerNotificationController::class, 'unreadCount']);
            Route::put('/notifications/read-all', [PartnerNotificationController::class, 'markAllRead']);
            Route::put('/notifications/{id}/read', [PartnerNotificationController::class, 'markRead']);
            Route::delete('/notifications/{id}', [PartnerNotificationController::class, 'destroy']);

            Route::get('/profile', [TourismListingController::class, 'profile']);
            Route::put('/profile', [TourismListingController::class, 'updateProfile']);
            Route::put('/password', [TourismListingController::class, 'updatePassword']);
            Route::post('/images/upload', [TourismListingController::class, 'uploadListingImage']);
        });

        // ─── Admin Scoped Routes ──────────────────────────────────────────────
        Route::middleware('role:admin')->prefix('admin')->group(function () {
            Route::get('/dashboard-stats', [AnalyticsController::class, 'dashboard']);
            Route::get('/activity-logs', [AnalyticsController::class, 'activityLogs']);
            Route::get('/reviews', [ReviewController::class, 'managementIndex']);

            Route::get('/map-locations', [MapLocationController::class, 'managementIndex']);
            Route::post('/map-locations/duplicates', [MapLocationController::class, 'duplicates']);
            Route::post('/map-locations', [MapLocationController::class, 'store']);
            Route::put('/map-locations/{id}', [MapLocationController::class, 'update']);
            Route::patch('/map-locations/{id}/verify', [MapLocationController::class, 'verify']);
            Route::patch('/map-locations/{id}/publish', [MapLocationController::class, 'publish']);
            Route::patch('/map-locations/{id}/status', [MapLocationController::class, 'setStatus']);
            Route::delete('/map-locations/{id}', [MapLocationController::class, 'destroy']);
            Route::get('/map-location-categories', [MapLocationCategoryController::class, 'managementIndex']);
            Route::post('/map-location-categories', [MapLocationCategoryController::class, 'store']);
            Route::put('/map-location-categories/{id}', [MapLocationCategoryController::class, 'update']);
            Route::delete('/map-location-categories/{id}', [MapLocationCategoryController::class, 'destroy']);

            // User Management
            Route::get('/users', [UserController::class, 'index']);
            Route::post('/users', [UserController::class, 'store']);
            Route::put('/users/{id}', [UserController::class, 'updateManaged']);
            Route::get('/roles', [UserController::class, 'roles']);
            Route::put('/users/{id}/role', [UserController::class, 'updateRole']);
            Route::put('/users/{id}/partner-assignment', [UserController::class, 'updatePartnerAssignment']);
            Route::put('/users/{id}/verify', [UserController::class, 'updateVerification']);
            Route::put('/users/{id}/status', [UserController::class, 'updateStatus']);
            Route::delete('/users/{id}/sessions', [UserController::class, 'revokeSessions']);
            Route::delete('/users/{id}', [UserController::class, 'destroy']);

            // MSME Management
            Route::get('/msmes', [MsmeController::class, 'managementIndex']);
            Route::put('/msmes/{id}/verify', [MsmeController::class, 'updateVerification']);
            Route::delete('/msmes/{id}', [MsmeController::class, 'destroy']);
            Route::get('/tourism-listings', [TourismListingController::class, 'managementIndex']);
            Route::put('/tourism-listings/{id}/review', [TourismListingController::class, 'review']);

            // Tourist Spots & Categories Management
            Route::get('/tourist-spots', [TouristSpotController::class, 'managementIndex']);
            Route::post('/tourist-spots', [TouristSpotController::class, 'store']);
            Route::put('/tourist-spots/{id}', [TouristSpotController::class, 'update']);
            Route::delete('/tourist-spots/{id}', [TouristSpotController::class, 'destroy']);
            Route::get('/tourist-spots/{spot}/gallery', [TouristSpotGalleryController::class, 'manageIndex']);
            Route::put('/tourist-spots/{spot}/gallery/reorder', [TouristSpotGalleryController::class, 'reorder']);
            Route::put('/tourist-spots/{spot}/gallery/{media}', [TouristSpotGalleryController::class, 'update']);

            Route::post('/spot-categories', [SpotCategoryController::class, 'store']);
            Route::put('/spot-categories/{id}', [SpotCategoryController::class, 'update']);
            Route::delete('/spot-categories/{id}', [SpotCategoryController::class, 'destroy']);

            // Establishments Management
            Route::post('/establishments', [EstablishmentController::class, 'store']);
            Route::put('/establishments/{id}', [EstablishmentController::class, 'update']);
            Route::delete('/establishments/{id}', [EstablishmentController::class, 'destroy']);

            // Ferry Schedules Management
            Route::get('/ferry-schedules', [FerryScheduleController::class, 'managementIndex']);
            Route::post('/ferry-schedules', [FerryScheduleController::class, 'store']);
            Route::put('/ferry-schedules/{id}', [FerryScheduleController::class, 'update']);
            Route::delete('/ferry-schedules/{id}', [FerryScheduleController::class, 'destroy']);
            Route::post('/ferry-ports', [FerryScheduleController::class, 'storePort']);
            Route::put('/ferry-ports/{port}', [FerryScheduleController::class, 'updatePort']);
            Route::post('/ferry-routes', [FerryScheduleController::class, 'storeRoute']);
            Route::put('/ferry-routes/{route}', [FerryScheduleController::class, 'updateRoute']);

            // Eco Tips Management
            Route::get('/eco-tips', [EcoTipController::class, 'managementIndex']);
            Route::post('/eco-tips', [EcoTipController::class, 'store']);
            Route::put('/eco-tips/{id}', [EcoTipController::class, 'update']);
            Route::delete('/eco-tips/{id}', [EcoTipController::class, 'destroy']);

            // Emergency Contacts Management
            Route::get('/emergency-contacts', [EmergencyContactController::class, 'managementIndex']);
            Route::post('/emergency-contacts', [EmergencyContactController::class, 'store']);
            Route::put('/emergency-contacts/{id}', [EmergencyContactController::class, 'update']);
            Route::patch('/emergency-contacts/{id}/status', [EmergencyContactController::class, 'setStatus']);
            Route::patch('/emergency-contacts/{id}/verify', [EmergencyContactController::class, 'verify']);
            Route::patch('/emergency-contacts/{id}/verification', [EmergencyContactController::class, 'setVerificationStatus']);
            Route::delete('/emergency-contacts/{id}', [EmergencyContactController::class, 'destroy']);
            // Reservations Management
            Route::put('/reservations/{id}/status', [ReservationController::class, 'updateStatus']);

            // Waste Reports Management
            Route::put('/waste-reports/{id}/status', [WasteReportController::class, 'updateStatus']);
            Route::post('/waste-reports/{id}/resolution-media', [WasteReportController::class, 'uploadResolutionMedia']);

            // Announcements Management
            Route::get('/announcements', [AnnouncementController::class, 'managementIndex']);
            Route::post('/announcements', [AnnouncementController::class, 'store']);
            Route::put('/announcements/{id}', [AnnouncementController::class, 'update']);
            Route::delete('/announcements/{id}', [AnnouncementController::class, 'destroy']);
            Route::get('/concerns', [ConcernController::class, 'index']);
            Route::get('/concerns/{id}', [ConcernController::class, 'show']);
            Route::put('/concerns/{id}', [ConcernController::class, 'manage']);
            Route::post('/concerns/{id}/messages', [ConcernController::class, 'reply']);

            // System Settings Management
            Route::put('/system-settings/{id}', [SettingController::class, 'updateSystemSettings']);

            // Admin alone performs final role and ownership provisioning.
            Route::get('/access-requests', [RoleApplicationController::class, 'adminIndex']);
            Route::get('/access-requests/{id}', [RoleApplicationController::class, 'adminShow']);
            Route::post('/access-requests/{id}/approve', [RoleApplicationController::class, 'approve']);
            Route::post('/access-requests/{id}/reject', [RoleApplicationController::class, 'adminReject']);
        });

        // ─── LGU Staff Scoped Routes ─────────────────────────────────────────
        Route::middleware('role:lgu_staff,admin')->prefix('lgu')->group(function () {
            Route::get('/dashboard-stats', [LguController::class, 'dashboardStats']);
            Route::get('/activity', [LguController::class, 'activity']);
            Route::get('/announcements', [AnnouncementController::class, 'lguIndex']);
            Route::get('/map-locations', [MapLocationController::class, 'managementIndex']);
            Route::post('/map-locations/duplicates', [MapLocationController::class, 'duplicates']);
            Route::post('/map-locations', [MapLocationController::class, 'store']);
            Route::put('/map-locations/{id}', [MapLocationController::class, 'update']);
            Route::patch('/map-locations/{id}/verify', [MapLocationController::class, 'verify']);
            Route::patch('/map-locations/{id}/publish', [MapLocationController::class, 'publish']);
            Route::patch('/map-locations/{id}/status', [MapLocationController::class, 'setStatus']);
            Route::delete('/map-locations/{id}', [MapLocationController::class, 'destroy']);
            Route::get('/map-location-categories', [MapLocationCategoryController::class, 'managementIndex']);
            Route::post('/map-location-categories', [MapLocationCategoryController::class, 'store']);
            Route::put('/map-location-categories/{id}', [MapLocationCategoryController::class, 'update']);
            Route::delete('/map-location-categories/{id}', [MapLocationCategoryController::class, 'destroy']);
            Route::get('/emergency-contacts', [EmergencyContactController::class, 'managementIndex']);
            Route::post('/emergency-contacts', [EmergencyContactController::class, 'store']);
            Route::put('/emergency-contacts/{id}', [EmergencyContactController::class, 'update']);
            Route::patch('/emergency-contacts/{id}/status', [EmergencyContactController::class, 'setStatus']);
            Route::patch('/emergency-contacts/{id}/verify', [EmergencyContactController::class, 'verify']);
            Route::patch('/emergency-contacts/{id}/verification', [EmergencyContactController::class, 'setVerificationStatus']);
            Route::delete('/emergency-contacts/{id}', [EmergencyContactController::class, 'destroy']);
            Route::get('/ferry-schedules', [FerryScheduleController::class, 'managementIndex']);
            Route::post('/ferry-schedules', [FerryScheduleController::class, 'store']);
            Route::put('/ferry-schedules/{id}', [FerryScheduleController::class, 'update']);
            Route::delete('/ferry-schedules/{id}', [FerryScheduleController::class, 'destroy']);
            Route::post('/ferry-ports', [FerryScheduleController::class, 'storePort']);
            Route::put('/ferry-ports/{port}', [FerryScheduleController::class, 'updatePort']);
            Route::post('/ferry-routes', [FerryScheduleController::class, 'storeRoute']);
            Route::put('/ferry-routes/{route}', [FerryScheduleController::class, 'updateRoute']);
            Route::get('/concerns', [ConcernController::class, 'index']);
            Route::get('/concerns/{id}', [ConcernController::class, 'show']);
            Route::put('/concerns/{id}', [ConcernController::class, 'manage']);
            Route::post('/concerns/{id}/messages', [ConcernController::class, 'reply']);
            Route::get('/eco-tips', [EcoTipController::class, 'managementIndex']);
            Route::post('/eco-tips', [EcoTipController::class, 'store']);
            Route::put('/eco-tips/{id}', [EcoTipController::class, 'update']);
            Route::delete('/eco-tips/{id}', [EcoTipController::class, 'destroy']);
            Route::put('/tourist-spots/{id}/status', [LguController::class, 'updateSpotStatus']);
            Route::get('/tourist-spots', [TouristSpotController::class, 'managementIndex']);
            Route::put('/tourist-spots/{id}', [TouristSpotController::class, 'update']);
            Route::get('/tourist-spots/{spot}/gallery', [TouristSpotGalleryController::class, 'manageIndex']);
            Route::put('/tourist-spots/{spot}/gallery/reorder', [TouristSpotGalleryController::class, 'reorder']);
            Route::put('/tourist-spots/{spot}/gallery/{media}', [TouristSpotGalleryController::class, 'update']);
            Route::put('/tourist-spots/{id}/booking', [TouristSpotController::class, 'updateBooking']);
            Route::patch('/tourist-spots/{id}/booking-availability', [LguTouristSpotBookingAvailabilityController::class, 'update'])
                ->middleware('role:lgu_staff');
            Route::get('/reservations', [ReservationController::class, 'index']);
            Route::get('/reservations/{id}', [ReservationController::class, 'show']);
            Route::put('/reservations/{id}/status', [ReservationController::class, 'updateStatus']);
            Route::get('/msmes', [MsmeController::class, 'managementIndex']);
            Route::get('/msmes/{id}', [MsmeController::class, 'managementShow']);
            Route::put('/msmes/{id}/verify', [LguController::class, 'verifyMsme']);
            Route::get('/tourism-listings', [TourismListingController::class, 'managementIndex']);
            Route::put('/tourism-listings/{id}/review', [TourismListingController::class, 'review']);
            Route::put('/waste-reports/{id}/status', [LguController::class, 'updateWasteStatus']);
            Route::post('/waste-reports/{id}/resolution-media', [WasteReportController::class, 'uploadResolutionMedia']);
            Route::get('/analytics', [LguController::class, 'analytics']);
            Route::get('/reports', [LguController::class, 'reports']);

            // LGU verification is intentionally separate from Admin access approval.
            Route::middleware('role:lgu_staff')->group(function () {
                Route::get('/role-applications', [RoleApplicationController::class, 'lguIndex']);
                Route::get('/role-applications/{id}', [RoleApplicationController::class, 'lguShow']);
                Route::post('/role-applications/{id}/start-review', [RoleApplicationController::class, 'startReview']);
                Route::post('/role-applications/{id}/needs-changes', [RoleApplicationController::class, 'needsChanges']);
                Route::post('/role-applications/{id}/recommend', [RoleApplicationController::class, 'recommend']);
                Route::post('/role-applications/{id}/reject', [RoleApplicationController::class, 'lguReject']);
            });
        });

    });

});
