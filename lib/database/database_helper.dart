import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton SQLite database manager with schema migrations.
class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static const String _dbName = 'tubigon_tourism.db';
  static const int _dbVersion = 9;

  /// Native SQLite is intentionally unavailable in browsers. Repositories
  /// use this single capability boundary to select their Laravel API path.
  static bool get isSupported => !kIsWeb;

  static Database? _database;
  Future<Database> get database async {
    if (!isSupported) {
      throw UnsupportedError(
        'Native SQLite is not supported on Flutter Web. Use the repository API path.',
      );
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      // ── Users ──────────────────────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE users (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          email TEXT UNIQUE NOT NULL,
          role TEXT NOT NULL DEFAULT 'tourist',
          avatar_url TEXT,
          phone TEXT,
          bio TEXT,
          language TEXT DEFAULT 'en',
          is_verified INTEGER DEFAULT 0,
          created_at TEXT,
          updated_at TEXT,
          sync_status TEXT DEFAULT 'synced',
          dirty INTEGER DEFAULT 0,
          pending_delete INTEGER DEFAULT 0,
          last_synced TEXT
        )
      ''');

      // ── Spot Categories ───────────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE spot_categories (
          id INTEGER PRIMARY KEY,
          uuid TEXT UNIQUE NOT NULL,
          name TEXT UNIQUE NOT NULL,
          slug TEXT UNIQUE NOT NULL,
          created_at TEXT,
          updated_at TEXT
        )
      ''');

      // ── Tourist Spots ─────────────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE tourist_spots (
          id INTEGER PRIMARY KEY,
          uuid TEXT UNIQUE NOT NULL,
          name TEXT NOT NULL,
          slug TEXT UNIQUE,
          short_description TEXT,
          description TEXT,
          aliases TEXT,
          category_id INTEGER,
          latitude REAL,
          longitude REAL,
          address TEXT,
          entrance_fee REAL DEFAULT 0,
          opening_hours TEXT,
          eco_tips TEXT,
          images TEXT,
          average_rating REAL DEFAULT 0,
          review_count INTEGER DEFAULT 0,
          is_featured INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1,
          is_published INTEGER DEFAULT 1,
          is_bookable INTEGER DEFAULT 0,
          booking_enabled INTEGER DEFAULT 0,
          booking_unavailable_reason_code TEXT,
          booking_unavailable_reason TEXT,
          booking_availability_updated_at TEXT,
          booking_mode TEXT DEFAULT 'no_reservation',
          booking_available_days TEXT,
          booking_time_slots TEXT,
          max_guests_per_reservation INTEGER,
          advance_booking_days INTEGER,
          minimum_notice_hours INTEGER,
          reservation_fee REAL,
          fee_configured INTEGER DEFAULT 0,
          booking_instructions TEXT,
          cancellation_policy TEXT,
          contact_information TEXT,
          visitor_instructions TEXT,
          amenities TEXT,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (category_id) REFERENCES spot_categories(id) ON DELETE SET NULL
        )
      ''');

      // ── Establishments ────────────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE establishments (
          id INTEGER PRIMARY KEY,
          uuid TEXT UNIQUE NOT NULL,
          name TEXT NOT NULL,
          category TEXT,
          description TEXT,
          latitude REAL,
          longitude REAL,
          address TEXT,
          phone TEXT,
          email TEXT,
          website TEXT,
          business_hours TEXT,
          images TEXT,
          average_rating REAL DEFAULT 0,
          review_count INTEGER DEFAULT 0,
          is_verified INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1,
          created_at TEXT,
          updated_at TEXT
        )
      ''');

      // ── MSMEs ─────────────────────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE msmes (
          id INTEGER PRIMARY KEY,
          uuid TEXT UNIQUE NOT NULL,
          profile_id TEXT,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          tagline TEXT,
          description TEXT,
          phone TEXT,
          address TEXT,
          latitude REAL,
          longitude REAL,
          business_hours TEXT,
          rating REAL DEFAULT 0,
          review_count INTEGER DEFAULT 0,
          color TEXT,
          icon TEXT,
          is_verified INTEGER DEFAULT 0,
          booking_enabled INTEGER DEFAULT 0,
          operational_status TEXT DEFAULT 'open',
          opening_hours TEXT,
          unavailable_dates TEXT,
          products TEXT,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (profile_id) REFERENCES users(id) ON DELETE SET NULL
        )
      ''');

      // ── Reservations ──────────────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE reservations (
          id TEXT PRIMARY KEY,
          public_reference TEXT,
          user_id TEXT NOT NULL,
          partner_id TEXT,
          reservable_type TEXT NOT NULL,
          reservable_id TEXT NOT NULL,
          reservation_date TEXT NOT NULL,
          start_time TEXT,
          end_time TEXT,
          guests INTEGER DEFAULT 1,
          status TEXT DEFAULT 'pending',
          notes TEXT,
          total_amount REAL DEFAULT 0,
          reservable_name TEXT,
          reservable_image TEXT,
          fee_configured INTEGER DEFAULT 0,
          booking_instructions TEXT,
          cancellation_policy TEXT,
          latitude REAL,
          longitude REAL,
          status_history TEXT,
          created_at TEXT,
          updated_at TEXT,
          sync_status TEXT DEFAULT 'synced',
          dirty INTEGER DEFAULT 0,
          pending_delete INTEGER DEFAULT 0,
          last_synced TEXT,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');

      // ── Reviews ───────────────────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE reviews (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          reviewable_type TEXT NOT NULL,
          reviewable_id TEXT NOT NULL,
          rating INTEGER NOT NULL,
          content TEXT,
          images TEXT,
          created_at TEXT,
          updated_at TEXT,
          sync_status TEXT DEFAULT 'synced',
          dirty INTEGER DEFAULT 0,
          pending_delete INTEGER DEFAULT 0,
          last_synced TEXT,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');

      // ── Favorites ─────────────────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE favorites (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          favoritable_type TEXT NOT NULL,
          favoritable_id TEXT NOT NULL,
          created_at TEXT,
          updated_at TEXT,
          sync_status TEXT DEFAULT 'synced',
          dirty INTEGER DEFAULT 0,
          pending_delete INTEGER DEFAULT 0,
          last_synced TEXT,
          UNIQUE(user_id, favoritable_type, favoritable_id),
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');

      // ── Waste Reports ─────────────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE waste_reports (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          category TEXT NOT NULL,
          description TEXT NOT NULL,
          location_description TEXT,
          latitude REAL,
          longitude REAL,
          images TEXT,
          status TEXT DEFAULT 'pending',
          created_at TEXT,
          updated_at TEXT,
          sync_status TEXT DEFAULT 'synced',
          dirty INTEGER DEFAULT 0,
          pending_delete INTEGER DEFAULT 0,
          last_synced TEXT,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
        )
      ''');

      // ── Ferry Schedules ───────────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE ferry_schedules (
          id INTEGER PRIMARY KEY,
          uuid TEXT UNIQUE NOT NULL,
          operator TEXT NOT NULL,
          route TEXT NOT NULL,
          departure_time TEXT NOT NULL,
          arrival_time TEXT,
          fare REAL,
          status TEXT DEFAULT 'on_time',
          days_of_week TEXT,
          updated_at TEXT
        )
      ''');

      // ── Eco Tips ──────────────────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE eco_tips (
          id INTEGER PRIMARY KEY,
          uuid TEXT UNIQUE NOT NULL,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          category TEXT,
          spot_id INTEGER,
          language TEXT DEFAULT 'en',
          updated_at TEXT,
          FOREIGN KEY (spot_id) REFERENCES tourist_spots(id) ON DELETE SET NULL
        )
      ''');

      // ── Emergency Contacts ────────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE emergency_contacts (
          id INTEGER PRIMARY KEY,
          uuid TEXT UNIQUE NOT NULL,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          phone TEXT NOT NULL,
          alternative_phone TEXT,
          address TEXT,
          description TEXT,
          operating_hours TEXT,
          classification TEXT DEFAULT 'emergency',
          is_active INTEGER DEFAULT 1,
          is_verified INTEGER DEFAULT 0,
          source TEXT,
          source_url TEXT,
          verified_at TEXT,
          last_verified_at TEXT,
          updated_by_name TEXT,
          verified_by_name TEXT,
          latitude REAL,
          longitude REAL,
          updated_at TEXT
        )
      ''');

      // ── Notifications ─────────────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE notifications (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          body TEXT,
          data TEXT,
          is_read INTEGER DEFAULT 0,
          created_at TEXT,
          updated_at TEXT,
          sync_status TEXT DEFAULT 'synced',
          dirty INTEGER DEFAULT 0,
          pending_delete INTEGER DEFAULT 0,
          last_synced TEXT,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');

      // ── Sync Queue ────────────────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          uuid TEXT UNIQUE NOT NULL,
          table_name TEXT NOT NULL,
          action TEXT NOT NULL,
          payload TEXT NOT NULL,
          retry_count INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          last_attempted_at TEXT
        )
      ''');

      // ── Indexes ───────────────────────────────────────────────────────────
      await txn.execute(
          'CREATE INDEX idx_spots_category ON tourist_spots(category_id)');
      await txn.execute(
          'CREATE INDEX idx_spots_featured ON tourist_spots(is_featured)');
      await txn.execute(
          'CREATE INDEX idx_reservations_user ON reservations(user_id)');
      await txn
          .execute('CREATE INDEX idx_favorites_user ON favorites(user_id)');
      await txn.execute(
          'CREATE INDEX idx_reviews_reviewable ON reviews(reviewable_type, reviewable_id)');
      await txn.execute(
          'CREATE INDEX idx_sync_queue_table ON sync_queue(table_name)');
      // ── Tourism Listings ──────────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE tourism_listings (
          id TEXT PRIMARY KEY,
          owner_id TEXT NOT NULL,
          listing_name TEXT NOT NULL,
          listing_type TEXT NOT NULL DEFAULT 'attraction',
          description TEXT,
          address TEXT,
          latitude REAL,
          longitude REAL,
          contact_number TEXT,
          email TEXT,
          operating_hours TEXT,
          images TEXT,
          status TEXT DEFAULT 'active',
          is_active INTEGER DEFAULT 1,
          average_rating REAL DEFAULT 0,
          review_count INTEGER DEFAULT 0,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');

      // ── Partner Notifications ─────────────────────────────────────────────
      await txn.execute('''
        CREATE TABLE partner_notifications (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          body TEXT,
          data TEXT,
          is_read INTEGER DEFAULT 0,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('DB upgrade from v$oldVersion to v$newVersion');
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS users');
      await db.execute('DROP TABLE IF EXISTS tourist_spots');
      await db.execute('DROP TABLE IF EXISTS establishments');
      await db.execute('DROP TABLE IF EXISTS reservations');
      await db.execute('DROP TABLE IF EXISTS reviews');
      await db.execute('DROP TABLE IF EXISTS favorites');
      await db.execute('DROP TABLE IF EXISTS ferry_schedules');
      await db.execute('DROP TABLE IF EXISTS eco_tips');
      await db.execute('DROP TABLE IF EXISTS emergency_contacts');
      await db.execute('DROP TABLE IF EXISTS notifications');
      await db.execute('DROP TABLE IF EXISTS sync_queue');
      await db.execute('DROP TABLE IF EXISTS spot_categories');
      await db.execute('DROP TABLE IF EXISTS msmes');
      await db.execute('DROP TABLE IF EXISTS waste_reports');
      await _onCreate(db, newVersion);
    } else if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE reservations ADD COLUMN partner_id TEXT');
      } catch (_) {}
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tourism_listings (
          id TEXT PRIMARY KEY,
          owner_id TEXT NOT NULL,
          listing_name TEXT NOT NULL,
          listing_type TEXT NOT NULL DEFAULT 'attraction',
          description TEXT,
          address TEXT,
          latitude REAL,
          longitude REAL,
          contact_number TEXT,
          email TEXT,
          operating_hours TEXT,
          images TEXT,
          status TEXT DEFAULT 'active',
          is_active INTEGER DEFAULT 1,
          average_rating REAL DEFAULT 0,
          review_count INTEGER DEFAULT 0,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS partner_notifications (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          body TEXT,
          data TEXT,
          is_read INTEGER DEFAULT 0,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion >= 2 && oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE msmes ADD COLUMN latitude REAL');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE msmes ADD COLUMN longitude REAL');
      } catch (_) {}
    }
    if (oldVersion >= 2 && oldVersion < 5) {
      const emergencyColumns = <String, String>{
        'alternative_phone': 'TEXT',
        'description': 'TEXT',
        'operating_hours': 'TEXT',
        'classification': "TEXT DEFAULT 'emergency'",
        'is_active': 'INTEGER DEFAULT 1',
        'is_verified': 'INTEGER DEFAULT 0',
        'source': 'TEXT',
        'source_url': 'TEXT',
        'verified_at': 'TEXT',
        'last_verified_at': 'TEXT',
        'updated_by_name': 'TEXT',
        'verified_by_name': 'TEXT',
      };
      for (final entry in emergencyColumns.entries) {
        try {
          await db.execute(
            'ALTER TABLE emergency_contacts ADD COLUMN ${entry.key} ${entry.value}',
          );
        } catch (_) {}
      }
    }
    if (oldVersion >= 2 && oldVersion < 6) {
      const touristSpotColumns = <String, String>{
        'is_published': 'INTEGER DEFAULT 1',
        'is_bookable': 'INTEGER DEFAULT 0',
        'booking_mode': "TEXT DEFAULT 'no_reservation'",
        'booking_available_days': 'TEXT',
        'booking_time_slots': 'TEXT',
        'max_guests_per_reservation': 'INTEGER',
        'advance_booking_days': 'INTEGER',
        'minimum_notice_hours': 'INTEGER',
        'reservation_fee': 'REAL',
        'fee_configured': 'INTEGER DEFAULT 0',
        'booking_instructions': 'TEXT',
        'cancellation_policy': 'TEXT',
      };
      for (final entry in touristSpotColumns.entries) {
        try {
          await db.execute(
            'ALTER TABLE tourist_spots ADD COLUMN ${entry.key} ${entry.value}',
          );
        } catch (_) {}
      }
      const reservationColumns = <String, String>{
        'public_reference': 'TEXT',
        'reservable_name': 'TEXT',
        'reservable_image': 'TEXT',
        'fee_configured': 'INTEGER DEFAULT 0',
        'booking_instructions': 'TEXT',
        'cancellation_policy': 'TEXT',
        'latitude': 'REAL',
        'longitude': 'REAL',
        'status_history': 'TEXT',
      };
      for (final entry in reservationColumns.entries) {
        try {
          await db.execute(
            'ALTER TABLE reservations ADD COLUMN ${entry.key} ${entry.value}',
          );
        } catch (_) {}
      }
    }
    if (oldVersion < 8) {
      const availabilityColumns = <String, String>{
        'booking_enabled': 'INTEGER DEFAULT 0',
        'booking_unavailable_reason_code': 'TEXT',
        'booking_unavailable_reason': 'TEXT',
        'booking_availability_updated_at': 'TEXT',
        'contact_information': 'TEXT',
        'visitor_instructions': 'TEXT',
        'amenities': 'TEXT',
      };
      for (final entry in availabilityColumns.entries) {
        try {
          await db.execute(
            'ALTER TABLE tourist_spots ADD COLUMN ${entry.key} ${entry.value}',
          );
        } catch (_) {}
      }
    }
    if (oldVersion < 9) {
      const msmeAvailabilityColumns = <String, String>{
        'booking_enabled': 'INTEGER DEFAULT 0',
        'operational_status': "TEXT DEFAULT 'open'",
        'opening_hours': 'TEXT',
        'unavailable_dates': 'TEXT',
      };
      for (final entry in msmeAvailabilityColumns.entries) {
        try {
          await db.execute(
            'ALTER TABLE msmes ADD COLUMN ${entry.key} ${entry.value}',
          );
        } catch (_) {}
      }
    }
    if (oldVersion >= 2 && oldVersion < 7) {
      const touristSpotContentColumns = <String, String>{
        'short_description': 'TEXT',
        'aliases': 'TEXT',
      };
      for (final entry in touristSpotContentColumns.entries) {
        try {
          await db.execute(
            'ALTER TABLE tourist_spots ADD COLUMN ${entry.key} ${entry.value}',
          );
        } catch (_) {}
      }
    }
  }

  // ─── Generic CRUD helpers ─────────────────────────────────────────────────

  Future<int> insert(String table, Map<String, dynamic> row) async {
    final db = await database;
    return db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> row, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return db.update(table, row, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }

  Future<void> close() async {
    if (!isSupported) return;
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
