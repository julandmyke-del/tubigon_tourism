import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_localization.dart';
import 'offline_map_provider.dart';

class OfflineMapsPage extends ConsumerWidget {
  const OfflineMapsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final package = ref.watch(offlineMapProvider);
    final notifier = ref.read(offlineMapProvider.notifier);
    final native = OfflineMapNotifier.supportsNativeMapResources;
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text(context.tr('offline_maps')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _hero(context, package),
          if (package.isBusy ||
              package.phase == OfflinePackagePhase.paused) ...[
            const SizedBox(height: 16),
            _progressCard(context, package, notifier),
          ],
          if (package.error != null) ...[
            const SizedBox(height: 12),
            _errorCard(context.tr(package.error!)),
          ],
          const SizedBox(height: 16),
          _includesCard(context, package, native),
          if (package.hasDataSnapshot) ...[
            const SizedBox(height: 16),
            _storageCard(context, package),
          ],
          const SizedBox(height: 18),
          if (!package.hasDataSnapshot)
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
              label: Text(context.tr(
                  native ? 'download_offline_map' : 'download_offline_data')),
            )
          else ...[
            if (package.canOpen)
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
                label: Text(context.tr('open_offline_map')),
              )
            else if (!native)
              _webLimitation(context),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: package.isBusy ? null : notifier.downloadOrUpdate,
              icon: const Icon(Icons.sync_rounded),
              label: Text(context.tr('update_offline_data')),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: package.isBusy
                  ? null
                  : () => _confirmDelete(context, notifier),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFF87171)),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(context.tr('delete_offline_package')),
            ),
          ],
          const SizedBox(height: 26),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, OfflineMapState package) {
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
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Tubigon, Bohol',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              Text(context.tr('tubigon_offline_map'),
                  style: const TextStyle(color: Color(0xFF94A3B8))),
            ]),
          ),
          _status(context, ready, package.hasDataSnapshot),
        ]),
        if (package.hasDataSnapshot) ...[
          const SizedBox(height: 18),
          _meta(context.tr('downloaded'), package.downloadedAt),
          _meta(context.tr('last_synced'), package.lastSyncedAt),
          _value(context.tr('places'), package.placeCount.toString()),
          _value(context.tr('storage_used'), _bytes(package.totalBytes)),
        ],
      ]),
    );
  }

  Widget _status(BuildContext context, bool ready, bool dataReady) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (ready ? const Color(0xFF34D399) : const Color(0xFF64748B))
              .withValues(alpha: .16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          context.tr(ready
              ? 'ready'
              : dataReady
                  ? 'data_only'
                  : 'not_downloaded'),
          style: TextStyle(
              color: ready ? const Color(0xFF34D399) : const Color(0xFFCBD5E1),
              fontSize: 12,
              fontWeight: FontWeight.w800),
        ),
      );

  Widget _includesCard(
          BuildContext context, OfflineMapState package, bool native) =>
      _card(
        title: context.tr('included_offline'),
        child: Column(children: [
          _include(context.tr('offline_places'), package.dataReady),
          _include(context.tr('offline_markers_search'), package.dataReady),
          _include(context.tr('offline_gps_distance'), true),
          _include(context.tr('offline_emergency_ferry'), package.dataReady),
          _include(context.tr('offline_trip_summaries'), package.dataReady),
          _include(
            context.tr(native
                ? 'offline_basemap_resources'
                : 'web_basemap_unavailable'),
            package.baseMapReady,
            unavailable: !native,
          ),
        ]),
      );

  Widget _progressCard(BuildContext context, OfflineMapState package,
      OfflineMapNotifier notifier) {
    final downloadingMap = package.phase == OfflinePackagePhase.downloadingMap;
    final titleKey = switch (package.phase) {
      OfflinePackagePhase.paused => 'download_paused',
      OfflinePackagePhase.validating => 'validating_download',
      OfflinePackagePhase.downloadingMap => 'downloading_map_resources',
      _ => 'updating_offline_data',
    };
    return _card(
      title: context.tr(titleKey),
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
          Text(context.tr('download_progress_retained'),
              style: const TextStyle(color: Color(0xFFCBD5E1))),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: notifier.resume,
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(context.tr('resume')),
          ),
        ] else if (downloadingMap && package.pendingRegionId != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: notifier.pause,
            icon: const Icon(Icons.pause_rounded),
            label: Text(context.tr('pause')),
          ),
        ],
      ]),
    );
  }

  Widget _storageCard(BuildContext context, OfflineMapState package) => _card(
        title: context.tr('offline_storage'),
        child: Column(children: [
          _value(
              context.tr('map_resources'),
              package.baseMapReady
                  ? _bytes(package.mapResourceBytes)
                  : context.tr('not_downloaded')),
          _value(
              context.tr('place_information'), _bytes(package.placeDataBytes)),
          _value(context.tr('total_measured'), _bytes(package.totalBytes)),
          const SizedBox(height: 8),
          Text(context.tr('offline_storage_note'),
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
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

  Widget _webLimitation(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF78350F).withValues(alpha: .35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(context.tr('web_data_only_explanation'),
            style: const TextStyle(color: Color(0xFFFDE68A))),
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
          ? '—'
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
                      color: Colors.white, fontWeight: FontWeight.w700))),
        ]),
      );

  String _bytes(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _confirmDownload(
      BuildContext context, OfflineMapNotifier notifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('download_tubigon_offline_map')),
        content: Text(context.tr(OfflineMapNotifier.supportsNativeMapResources
            ? 'download_native_explanation'
            : 'download_web_explanation')),
        actions: [
          TextButton(
              onPressed: () => dialogContext.pop(false),
              child: Text(context.tr('cancel'))),
          FilledButton(
              onPressed: () => dialogContext.pop(true),
              child: Text(context.tr('download'))),
        ],
      ),
    );
    if (confirmed == true) await notifier.downloadOrUpdate();
  }

  Future<void> _confirmDelete(
      BuildContext context, OfflineMapNotifier notifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('delete_offline_title')),
        content: Text(context.tr('delete_offline_explanation')),
        actions: [
          TextButton(
              onPressed: () => dialogContext.pop(false),
              child: Text(context.tr('cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => dialogContext.pop(true),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) await notifier.deletePackage();
  }
}
