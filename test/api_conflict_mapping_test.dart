import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/core/exceptions/app_exception.dart';
import 'package:tubigon_tourism/core/network/api_client.dart';

void main() {
  test('HTTP 409 maps to a user-safe typed conflict', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 409,
              data: {
                'message':
                    'This reservation was updated in another session. Refresh and try again.',
                'code': 'stale_record',
              },
            ),
          ),
        );
      }),
    );

    await expectLater(
      ApiClient(dio).put<dynamic>('/reservation/1'),
      throwsA(
        isA<ConflictException>()
            .having((error) => error.statusCode, 'statusCode', 409)
            .having((error) => error.code, 'code', 'stale_record')
            .having(
              (error) => error.message,
              'message',
              contains('updated in another session'),
            ),
      ),
    );
  });
}
