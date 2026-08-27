import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityStatus { online, offline }

/// Riverpod provider that streams network connectivity changes.
final connectivityProvider = StreamProvider<ConnectivityStatus>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    final hasConnection = results.any(
      (r) => r != ConnectivityResult.none,
    );
    return hasConnection ? ConnectivityStatus.online : ConnectivityStatus.offline;
  });
});

/// One-shot check — true if currently connected.
final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return connectivity.when(
    data: (status) => status == ConnectivityStatus.online,
    loading: () => true, // optimistically assume online during loading
    error: (_, __) => false,
  );
});

/// Checks connectivity once without watching the stream.
Future<bool> checkConnectivity() async {
  final results = await Connectivity().checkConnectivity();
  return results.any((r) => r != ConnectivityResult.none);
}
