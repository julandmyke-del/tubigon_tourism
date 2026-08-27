import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/core/constants/api_endpoints.dart';
import 'package:tubigon_tourism/core/network/api_client.dart';
import 'package:tubigon_tourism/database/database_helper.dart';
import 'package:tubigon_tourism/features/eco/repositories/eco_repository.dart';
import 'package:tubigon_tourism/features/emergency/repositories/emergency_repository.dart';
import 'package:tubigon_tourism/features/ferry/repositories/ferry_repository.dart';

void main() {
  if (!kIsWeb) {
    test('Web storage boundary tests run in Chrome', () {}, skip: true);
    return;
  }

  late ApiClient apiClient;

  setUp(() {
    final dio = Dio();
    dio.interceptors.add(_FixtureInterceptor({
      ApiEndpoints.ferrySchedules: {
        'status': 'success',
        'data': [
          {
            'id': 'ferry-uuid',
            'integer_id': 1,
            'operator': 'Lite Ferries',
            'route': 'Cebu City → Tubigon',
            'departure_time': '07:00 AM',
            'arrival_time': '09:00 AM',
            'fare': null,
            'status': 'scheduled',
            'days_of_week': ['Mon', 'Tue'],
          },
        ],
      },
      ApiEndpoints.ecoTips: {
        'status': 'success',
        'data': [
          {
            'id': 'eco-uuid',
            'integer_id': 1,
            'title': 'Leave No Trace',
            'content': 'Leave natural sites as you found them.',
            'category': 'Nature',
          },
        ],
      },
      ApiEndpoints.emergencyContacts: {
        'status': 'success',
        'data': [
          {
            'id': 'contact-uuid',
            'integer_id': 1,
            'name': 'Emergency Hotline',
            'category': 'National Emergency Hotline',
            'phone': '911',
            'classification': 'emergency',
            'is_active': true,
            'is_verified': false,
          },
        ],
      },
    }));
    apiClient = ApiClient(dio);
  });

  test('native SQLite fails before path_provider can be called', () async {
    expect(DatabaseHelper.isSupported, isFalse);
    await expectLater(
      DatabaseHelper.instance.database,
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('ferry repository reads and parses the API directly', () async {
    final rows =
        await FerryRepository(apiClient: apiClient).getFerrySchedules();
    expect(rows, hasLength(1));
    expect(rows.single.operator, 'Lite Ferries');
    expect(rows.single.duration, '2h 00m');
    expect(rows.single.fare, isNull);
  });

  test('eco repository reads and parses the API directly', () async {
    final rows = await EcoRepository(apiClient: apiClient).getEcoTips();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Leave No Trace');
  });

  test('emergency repository reads and parses the API directly', () async {
    final rows =
        await EmergencyRepository(apiClient: apiClient).getEmergencyContacts();
    expect(rows, hasLength(1));
    expect(rows.single.phone, '911');
  });
}

class _FixtureInterceptor extends Interceptor {
  _FixtureInterceptor(this.fixtures);

  final Map<String, Object?> fixtures;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final fixture = fixtures[options.path];
    if (fixture == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: options,
            statusCode: 404,
          ),
        ),
      );
      return;
    }
    handler.resolve(
      Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: fixture,
      ),
    );
  }
}
