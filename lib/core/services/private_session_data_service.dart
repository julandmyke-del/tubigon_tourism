import '../../database/database_helper.dart';
import 'local_storage_service.dart';

/// Defines which cached data may be shared and removes account-private state
/// before logout or account switching.
class PrivateSessionDataService {
  const PrivateSessionDataService._();

  static const _privateRoles = <String>{
    'admin',
    'lguStaff',
    'msmeOwner',
    'tourismPartner',
  };

  static String mapCacheKey({
    required bool isLoggedIn,
    required String role,
    String? userId,
  }) {
    if (!isLoggedIn || !_privateRoles.contains(role)) {
      return 'smart_map_cache_public';
    }

    final owner = (userId == null || userId.isEmpty) ? 'unknown' : userId;
    return 'smart_map_cache_private_${role}_$owner';
  }

  static Future<void> clear({
    required String? userId,
    required String role,
    bool clearLocalDatabase = true,
  }) async {
    final storage = LocalStorageService.instance;
    final owner = userId ?? '';
    final sessionOwner = '${role}_$owner';
    final removableKeys = storage.keys.where((key) {
      if (key.startsWith('smart_map_cache_private_')) return true;
      if (_privateRoles.contains(role) && key == 'smart_map_cache_$role') {
        return true; // Legacy role-only key.
      }
      if (owner.isEmpty) return false;
      return key == 'itineraries_cache_$owner' ||
          key == 'itinerary_pending_sync_$owner' ||
          key.startsWith('itinerary_detail_${owner}_') ||
          (key.startsWith('announcements_account_') &&
              key.endsWith(sessionOwner)) ||
          (key.startsWith('partner_offerings_') &&
              key.endsWith(sessionOwner)) ||
          (key.startsWith('partner_gallery_') && key.endsWith(sessionOwner));
    }).toList(growable: false);

    for (final key in removableKeys) {
      await storage.remove(key);
    }

    if (!clearLocalDatabase || !DatabaseHelper.isSupported || owner.isEmpty) {
      return;
    }
    final db = DatabaseHelper.instance;
    for (final table in const [
      'reservations',
      'reviews',
      'favorites',
      'waste_reports',
      'notifications',
      'partner_notifications',
    ]) {
      await db.delete(table, where: 'user_id = ?', whereArgs: [owner]);
    }
    // Queue rows contain mutation payloads and have no owner column. A queue is
    // only for the active session, so it must never survive an account switch.
    await db.delete('sync_queue', where: '1 = 1', whereArgs: const []);
  }
}
