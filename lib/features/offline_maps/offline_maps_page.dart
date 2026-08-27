import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'offline_map_provider.dart';

class OfflineMapsPage extends ConsumerWidget {
  const OfflineMapsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final package = ref.watch(offlineMapProvider);
    final notifier = ref.read(offlineMapProvider.notifier);
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('Offline Maps'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _hero(package),
          const SizedBox(height: 16),
          if (package.isBusy || package.phase == OfflinePackagePhase.paused)
            _progressCard(package, notifier),
          if (package.error != null) ...[
            const SizedBox(height: 12),
            _errorCard(package.error!),
          ],
          const SizedBox(height: 16),
          _includesCard(package),
          if (package.canOpen) ...[
            const SizedBox(height: 16),
            _storageCard(package),
          ],
          const SizedBox(height: 18),
          if (!package.canOpen)
            FilledButton.icon(
              onPressed: package.isBusy
                  ? null
                  : () => _confirmDownload(context, notifier),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download Offline Map'),
            )
          else ...[
            FilledButton.icon(
              onPressed: package.isBusy
                  ? null
                  : () => context.push('/map?offline=true'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.map_rounded),
              label: const Text('Open Offline Map'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: package.isBusy ? null : notifier.downloadOrUpdate,
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Update Offline Data'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: package.isBusy
                  ? null
                  : () => _confirmDelete(context, notifier),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFF87171)),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete Offline Map'),
            ),
          ],
          const SizedBox(height: 26),
        ],
      ),
    );
  }

  Widget _hero(OfflineMapState package) {
    final ready = package.canOpen;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF172554), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: .16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.map_rounded, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tubigon, Bohol',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              Text('Tubigon Offline Map',
                  style: TextStyle(color: Color(0xFF94A3B8))),
            ]),
          ),
          _status(ready),
        ]),
        if (ready) ...[
          const SizedBox(height: 18),
          _meta('Downloaded', package.downloadedAt),
          _meta('Last synced', package.lastSyncedAt),
          _value('Places', package.placeCount.toString()),
          _value('Storage used', _bytes(package.totalBytes)),
        ],
      ]),
    );
  }

  Widget _status(bool ready) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (ready ? const Color(0xFF34D399) : const Color(0xFF64748B))
              .withValues(alpha: .16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(ready ? '✓ Ready' : 'Not Downloaded',
            style: TextStyle(
                color:
                    ready ? const Color(0xFF34D399) : const Color(0xFFCBD5E1),
                fontSize: 12,
                fontWeight: FontWeight.w800)),
      );

  Widget _includesCard(OfflineMapState package) => _card(
        title: 'Included offline',
        child: Column(children: [
          _include('Published locations and place details', package.dataReady),
          _include('Markers, labels, categories, and local search',
              package.dataReady),
          _include('GPS and straight-line distance', true),
          _include('Emergency and ferry snapshots', package.dataReady),
          _include(
              'Saved itinerary and reservation summaries', package.dataReady),
          _include(
            OfflineMapNotifier.supportsNativeMapResources
                ? 'Persistent MapLibre base-map resources'
                : 'Full base-map resources are unavailable on Web',
            package.baseMapReady,
            unavailable: !OfflineMapNotifier.supportsNativeMapResources,
          ),
        ]),
      );

  Widget _progressCard(OfflineMapState package, OfflineMapNotifier notifier) {
    final downloadingMap = package.phase == OfflinePackagePhase.downloadingMap;
    return _card(
      title: package.phase == OfflinePackagePhase.paused
          ? 'Download paused'
          : downloadingMap
              ? 'Downloading map resources'
              : 'Updating offline data',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (downloadingMap && package.mapProgress != null) ...[
          LinearProgressIndicator(
            value: package.mapProgress! / 100,
            color: const Color(0xFFF59E0B),
            backgroundColor: const Color(0xFF334155),
          ),
          const SizedBox(height: 8),
          Text('${package.mapProgress!.toStringAsFixed(0)}%',
              style: const TextStyle(color: Color(0xFFCBD5E1))),
        ] else if (package.phase != OfflinePackagePhase.paused)
          const LinearProgressIndicator(color: Color(0xFFF59E0B)),
        if (package.phase == OfflinePackagePhase.paused) ...[
          const Text('Your downloaded progress is retained.',
              style: TextStyle(color: Color(0xFFCBD5E1))),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: notifier.resume,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Resume'),
          ),
        ] else if (downloadingMap && package.regionId != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: notifier.pause,
            icon: const Icon(Icons.pause_rounded),
            label: const Text('Pause'),
          ),
        ],
      ]),
    );
  }

  Widget _storageCard(OfflineMapState package) => _card(
        title: 'Offline storage',
        child: Column(children: [
          _value(
              'Map resources',
              package.baseMapReady
                  ? _bytes(package.mapResourceBytes)
                  : 'Not downloaded'),
          _value('Place information', _bytes(package.placeDataBytes)),
          _value('Total measured', _bytes(package.totalBytes)),
          const SizedBox(height: 8),
          const Text(
            'Optional image-cache usage is managed separately by the platform and is not included in this measured total.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
        ]),
      );

  Widget _errorCard(String error) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF7F1D1D).withValues(alpha: .35),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: const Color(0xFFF87171).withValues(alpha: .5)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFF87171)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(error, style: const TextStyle(color: Colors.white))),
        ]),
      );

  Widget _card({required String title, required Widget child}) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1)),
          const SizedBox(height: 13),
          child,
        ]),
      );

  Widget _include(String label, bool included, {bool unavailable = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(children: [
          Icon(
            unavailable
                ? Icons.info_outline_rounded
                : included
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: unavailable
                ? const Color(0xFFFBBF24)
                : included
                    ? const Color(0xFF34D399)
                    : const Color(0xFF64748B),
          ),
          const SizedBox(width: 9),
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Color(0xFFCBD5E1)))),
        ]),
      );

  Widget _meta(String label, DateTime? value) => _value(
      label,
      value == null
          ? 'Not available'
          : DateFormat.yMMMd().add_jm().format(value.toLocal()));

  Widget _value(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Color(0xFF94A3B8)))),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  String _bytes(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _confirmDownload(
    BuildContext context,
    OfflineMapNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Tubigon Offline Map'),
        content: Text(
          OfflineMapNotifier.supportsNativeMapResources
              ? 'This downloads public place data, safety and trip snapshots, plus persistent MapLibre resources for Tubigon. Size depends on map resources and cached content.'
              : 'This downloads public place data and supported snapshots. Full offline base-map resources are not supported in this Web environment.',
        ),
        actions: [
          TextButton(
              onPressed: () => context.pop(false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => context.pop(true),
              child: const Text('Download')),
        ],
      ),
    );
    if (confirmed == true) await notifier.downloadOrUpdate();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    OfflineMapNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete downloaded Tubigon map?'),
        content: const Text(
          'This removes downloaded map resources and public offline map data. Server-saved Favorites, Itineraries, and Reservations are not deleted.',
        ),
        actions: [
          TextButton(
              onPressed: () => context.pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => context.pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await notifier.deletePackage();
  }
}
