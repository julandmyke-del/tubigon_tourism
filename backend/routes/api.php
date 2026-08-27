<?php

use App\Http\Controllers\Api\V1\AnalyticsController;
use App\Http\Controllers\Api\V1\AnnouncementController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\EcoTipController;
use App\Http\Controllers\Api\V1\EmergencyContactController;
use App\Http\Controllers\Api\V1\EstablishmentController;
use App\Http\Controllers\Api\V1\FavoriteController;
use App\Http\Controllers\Api\V1\FerryScheduleController;
use App\Http\Controllers\Api\V1\ImageController;
use App\Http\Controllers\Api\V1\ItineraryController;
use App\Http\Controllers\Api\V1\LguController;
use App\Http\Controllers\Api\V1\MapController;
use App\Http\Controllers\Api\V1\MapLocationCategoryController;
use App\Http\Controllers\Api\V1\MapLocationController;
use App\Http\Controllers\Api\V1\MsmeController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\PartnerNotificationController;
use App\Http\Controllers\Api\V1\ReservationController;
use App\Http\Controllers\Api\V1\ReviewController;
use App\Http\Controllers\Api\V1\SettingController;
use App\Http\Controllers\Api\V1\SpotCategoryController;
use App\Http\Controllers\Api\V1\SyncController;
use App\Http\Controllers\Api\V1\TourismListingController;
use App\Http\Controllers\Api\V1\TouristSpotController;
use App\Http\Controllers\Api\V1\UserController;
use App\Http\Controllers\Api\V1\WasteReportController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {

    // ─── Public Routes ────────────────────────────────────────────────────────
    Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:10,1');
    Route::post('/auth/register', [AuthController::class, 'register'])->middleware('throttle:5,1');
    Route::post('/auth/google', [AuthController::class, 'googleAuth'])->middleware('throttle:10,1');
    Route::post('/auth/forgot-password', [AuthController::class, 'forgotPassword'])->middleware('throttle:5,1');
    Route::get('/auth/email/verify/{id}/{hash}', [AuthController::class, 'verifyEmail'])->name('verification.verify');
    Route::post('/auth/email/verification-notification', [AuthController::class, 'resendVerificationEmail'])->middleware('throttle:3,1');
    Route::get('/auth/verification-status', [AuthController::class, 'verificationStatus'])->middleware('throttle:30,1');

    Route::get('/tourist-spots', [TouristSpotController::class, 'index']);
    Route::get('/tourist-spots/{id}', [TouristSpotController::class, 'show']);
    Route::get('/spot-categories', [SpotCategoryController::class, 'index']);

    Route::get('/establishments', [EstablishmentController::class, 'index']);
    Route::get('/establishments/{id}', [EstablishmentController::class, 'show']);

    Route::get('/msmes', [MsmeController::class, 'index']);
    Route::get('/msmes/{id}', [MsmeController::class, 'show']);

    Route::get('/ferry-schedules', [FerryScheduleController::class, 'index']);
    Route::get('/eco-tips', [EcoTipController::class, 'index']);
    Route::get('/emergency-contacts', [EmergencyContactController::class, 'index']);
    Route::get('/announcements', [AnnouncementController::class, 'index']);
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

        // Reservations
        Route::get('/reservations', [ReservationController::class, 'index']);
        Route::get('/reservations/statuses', [ReservationController::class, 'statuses']);
        Route::get('/reservations/{id}', [ReservationController::class, 'show']);
        Route::post('/reservations', [ReservationController::class, 'store']);
        Route::put('/reservations/{id}/cancel', [ReservationController::class, 'cancel']);

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
        Route::post('/reviews', [ReviewController::class, 'store']);
        Route::delete('/reviews/{id}', [ReviewController::class, 'destroy']);

        // Favorites
        Route::get('/favorites', [FavoriteController::class, 'index']);
        Route::post('/favorites/toggle', [FavoriteController::class, 'toggle']);

        // Waste Reports
        Route::get('/waste-reports', [WasteReportController::class, 'index']);
        Route::post('/waste-reports', [WasteReportController::class, 'store']);
        Route::post('/waste-reports/{id}/images', [WasteReportController::class, 'uploadImages']);

        // Notifications
        Route::get('/notifications', [NotificationController::class, 'index']);
        Route::get('/notifications/unread-count', [NotificationController::class, 'unreadCount']);
        Route::put('/notifications/read-all', [NotificationController::class, 'markAllRead']);
        Route::put('/notifications/{id}/read', [NotificationController::class, 'markRead']);

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
        Route::post('/msmes', [MsmeController::class, 'store']);

        // ─── Tourism Partner Scoped Routes ────────────────────────────────────
        Route::middleware('role:tourism_partner,admin')->prefix('partner')->group(function () {
            Route::get('/dashboard-stats', [TourismListingController::class, 'dashboardStats']);
            Route::get('/listings', [TourismListingController::class, 'index']);
            Route::get('/listings/{id}', [TourismListingController::class, 'show']);
            Route::post('/listings', [TourismListingController::class, 'store']);
            Route::put('/listings/{id}', [TourismListingController::class, 'update']);
            Route::delete('/listings/{id}', [TourismListingController::class, 'destroy']);

            Route::get('/reservations', [TourismListingController::class, 'reservations']);
            Route::put('/reservations/{id}/status', [TourismListingController::class, 'updateReservationStatus']);

            Route::get('/reviews', [TourismListingController::class, 'reviews']);
            Route::get('/review-stats', [TourismListingController::class, 'reviewStats']);
            Route::get('/analytics', [TourismListingController::class, 'analytics']);

            Route::get('/notifications', [PartnerNotificationController::class, 'index']);
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
            Route::get('/roles', [UserController::class, 'roles']);
            Route::put('/users/{id}/role', [UserController::class, 'updateRole']);
            Route::put('/users/{id}/verify', [UserController::class, 'updateVerification']);
            Route::delete('/users/{id}', [UserController::class, 'destroy']);

            // MSME Management
            Route::put('/msmes/{id}/verify', [MsmeController::class, 'updateVerification']);
            Route::delete('/msmes/{id}', [MsmeController::class, 'destroy']);

            // Tourist Spots & Categories Management
            Route::post('/tourist-spots', [TouristSpotController::class, 'store']);
            Route::put('/tourist-spots/{id}', [TouristSpotController::class, 'update']);
            Route::delete('/tourist-spots/{id}', [TouristSpotController::class, 'destroy']);

            Route::post('/spot-categories', [SpotCategoryController::class, 'store']);
            Route::put('/spot-categories/{id}', [SpotCategoryController::class, 'update']);
            Route::delete('/spot-categories/{id}', [SpotCategoryController::class, 'destroy']);

            // Establishments Management
            Route::post('/establishments', [EstablishmentController::class, 'store']);
            Route::put('/establishments/{id}', [EstablishmentController::class, 'update']);
            Route::delete('/establishments/{id}', [EstablishmentController::class, 'destroy']);

            // Ferry Schedules Management
            Route::post('/ferry-schedules', [FerryScheduleController::class, 'store']);
            Route::put('/ferry-schedules/{id}', [FerryScheduleController::class, 'update']);
            Route::delete('/ferry-schedules/{id}', [FerryScheduleController::class, 'destroy']);

            // Eco Tips Management
            Route::post('/eco-tips', [EcoTipController::class, 'store']);
            Route::put('/eco-tips/{id}', [EcoTipController::class, 'update']);
            Route::delete('/eco-tips/{id}', [EcoTipController::class, 'destroy']);

            // Emergency Contacts Management
            Route::get('/emergency-contacts', [EmergencyContactController::class, 'managementIndex']);
            Route::post('/emergency-contacts', [EmergencyContactController::class, 'store']);
            Route::put('/emergency-contacts/{id}', [EmergencyContactController::class, 'update']);
            Route::patch('/emergency-contacts/{id}/status', [EmergencyContactController::class, 'setStatus']);
            Route::patch('/emergency-contacts/{id}/verify', [EmergencyContactController::class, 'verify']);
            Route::delete('/emergency-contacts/{id}', [EmergencyContactController::class, 'destroy']);

            // Reservations Management
            Route::put('/reservations/{id}/status', [ReservationController::class, 'updateStatus']);

            // Waste Reports Management
            Route::put('/waste-reports/{id}/status', [WasteReportController::class, 'updateStatus']);

            // Announcements Management
            Route::post('/announcements', [AnnouncementController::class, 'store']);
            Route::put('/announcements/{id}', [AnnouncementController::class, 'update']);
            Route::delete('/announcements/{id}', [AnnouncementController::class, 'destroy']);

            // System Settings Management
            Route::put('/system-settings/{id}', [SettingController::class, 'updateSystemSettings']);
        });

        // ─── LGU Staff Scoped Routes ─────────────────────────────────────────
        Route::middleware('role:lgu_staff,admin')->prefix('lgu')->group(function () {
            Route::get('/dashboard-stats', [LguController::class, 'dashboardStats']);
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
            Route::delete('/emergency-contacts/{id}', [EmergencyContactController::class, 'destroy']);
            Route::put('/tourist-spots/{id}/status', [LguController::class, 'updateSpotStatus']);
            Route::put('/msmes/{id}/verify', [LguController::class, 'verifyMsme']);
            Route::put('/waste-reports/{id}/status', [LguController::class, 'updateWasteStatus']);
            Route::get('/analytics', [LguController::class, 'analytics']);
            Route::get('/reports', [LguController::class, 'reports']);
        });

    });

});
