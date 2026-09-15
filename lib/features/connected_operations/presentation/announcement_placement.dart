import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/local_storage_service.dart';
import '../data/connected_operations_repository.dart';

class AnnouncementPlacement extends ConsumerStatefulWidget {
  const AnnouncementPlacement({super.key, this.guest = false});

  final bool guest;

  @override
  ConsumerState<AnnouncementPlacement> createState() =>
      _AnnouncementPlacementState();
}

class _AnnouncementPlacementState extends ConsumerState<AnnouncementPlacement>
    with WidgetsBindingObserver {
  final page = PageController();
  Timer? timer;
  int index = 0;
  int _slideCount = 0;
  bool _reconcileScheduled = false;
  bool _appIsActive = true;
  bool _animationsDisabled = false;
  bool _openingAnnouncement = false;
  final Set<String> sessionDismissed = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    page.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    if (_appIsActive) {
      _restartTimer();
    } else {
      timer?.cancel();
      timer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final guest = widget.guest;
    _animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final state = ref.watch(publicAnnouncementsProvider(guest));
    return state.when(
      loading: () {
        _scheduleSlideReconciliation(0);
        return const SizedBox(height: 4, child: LinearProgressIndicator());
      },
      error: (error, stack) {
        _scheduleSlideReconciliation(0);
        return const SizedBox.shrink();
      },
      data: (all) {
        final locallyDismissed = guest && LocalStorageService.isInitialized
            ? LocalStorageService.instance
                    .getStringList('guest_dismissed_announcements') ??
                const <String>[]
            : const <String>[];
        final visible = all
            .where((item) =>
                ['banner', 'carousel', 'pinned', 'urgent_alert']
                    .contains(item['display_type']) &&
                item['is_dismissed'] != true &&
                !locallyDismissed.contains(item['id']?.toString()) &&
                !sessionDismissed.contains(item['id']?.toString()))
            .toList();
        if (visible.isEmpty) {
          _scheduleSlideReconciliation(0);
          return const SizedBox.shrink();
        }
        final urgent =
            visible.where((item) => item['priority'] == 'urgent').firstOrNull;
        final slides =
            visible.where((item) => item['priority'] != 'urgent').toList();
        _scheduleSlideReconciliation(slides.length);
        return Column(
          children: [
            if (urgent != null) _card(urgent, guest: guest, urgent: true),
            if (slides.isNotEmpty)
              SizedBox(
                height: 180,
                child: Stack(
                  children: [
                    Listener(
                      onPointerDown: (_) => timer?.cancel(),
                      onPointerUp: (_) => _restartTimer(),
                      onPointerCancel: (_) => _restartTimer(),
                      child: PageView.builder(
                        controller: page,
                        itemCount: slides.length,
                        onPageChanged: (value) => setState(() => index = value),
                        itemBuilder: (context, itemIndex) =>
                            _card(slides[itemIndex], guest: guest),
                      ),
                    ),
                    if (slides.length > 1 &&
                        MediaQuery.sizeOf(context).width > 700) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton.filledTonal(
                          onPressed: index > 0
                              ? () => page.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  )
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton.filledTonal(
                          onPressed: index < slides.length - 1
                              ? () => page.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  )
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (slides.length > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  slides.length,
                  (dot) => Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          dot == index ? const Color(0xFFF59E0B) : Colors.grey,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _scheduleSlideReconciliation(int slides) {
    if (_slideCount == slides && !_reconcileScheduled) return;
    _slideCount = slides;
    timer?.cancel();
    timer = null;
    if (_reconcileScheduled) return;
    _reconcileScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reconcileScheduled = false;
      if (!mounted) return;
      final nextIndex = _slideCount == 0 ? 0 : index.clamp(0, _slideCount - 1);
      if (nextIndex != index) setState(() => index = nextIndex);
      if (page.hasClients && page.page?.round() != nextIndex) {
        page.jumpToPage(nextIndex);
      }
      _restartTimer();
    });
  }

  void _restartTimer() {
    timer?.cancel();
    timer = null;
    if (!mounted || !_appIsActive || _animationsDisabled || _slideCount < 2) {
      return;
    }
    timer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || !_appIsActive || !page.hasClients || _slideCount < 2) {
        return;
      }
      final nextIndex = (index + 1) % _slideCount;
      page.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _card(Map<String, dynamic> announcement,
      {required bool guest, bool urgent = false}) {
    final image = announcement['image_url']?.toString();
    return Semantics(
      button: true,
      label: '${urgent ? 'Urgent ' : ''}announcement: ${announcement['title']}',
      child: Card(
        color: urgent ? const Color(0xFF7F1D1D) : const Color(0xFF111C2F),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openingAnnouncement ? null : () => _open(announcement, guest),
          child: Row(
            children: [
              if (image != null && image.isNotEmpty)
                Image.network(
                  image,
                  width: 130,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox(width: 0),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Wrap(
                        spacing: 6,
                        children: [
                          _badge(urgent
                              ? 'URGENT'
                              : _label(announcement['priority'])),
                          _badge(_label(announcement['category'])),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        announcement['title']?.toString() ?? 'Announcement',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        announcement['body']?.toString() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        announcement['cta_label']?.toString().isNotEmpty == true
                            ? announcement['cta_label'].toString()
                            : 'View details',
                        style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      );

  Future<void> _open(Map<String, dynamic> announcement, bool guest) async {
    if (_openingAnnouncement) return;
    _openingAnnouncement = true;
    timer?.cancel();
    final repository = ref.read(connectedOperationsRepositoryProvider);
    final id = announcement['id']?.toString();
    if (!guest && id != null && id.isNotEmpty) {
      unawaited(_markReadSafely(repository, id));
    }
    try {
      if (!mounted) return;
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_announcementText(announcement['title'], 'Announcement')),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (announcement['image_url']?.toString().isNotEmpty == true)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        announcement['image_url'].toString(),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(_announcementText(
                      announcement['body'], 'No additional details.')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'dismiss'),
              child: const Text('Dismiss'),
            ),
            if (announcement['related_type'] != null)
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, 'related'),
                child: Text(
                    announcement['cta_label']?.toString().isNotEmpty == true
                        ? announcement['cta_label'].toString()
                        : 'View related content'),
              ),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close')),
          ],
        ),
      );
      if (!mounted) return;
      if (action == 'dismiss' && id != null && id.isNotEmpty) {
        if (guest) {
          const key = 'guest_dismissed_announcements';
          sessionDismissed.add(id);
          if (LocalStorageService.isInitialized) {
            final dismissed =
                LocalStorageService.instance.getStringList(key) ?? <String>[];
            await LocalStorageService.instance.setStringList(
              key,
              {...dismissed, id}.toList(),
            );
          }
        } else {
          try {
            await repository.dismissAnnouncement(id);
          } catch (_) {
            // A receipt failure must never break close/back navigation.
          }
        }
        if (mounted) ref.invalidate(publicAnnouncementsProvider(guest));
      } else if (action == 'related') {
        final route = _relatedRoute(announcement['related_type']?.toString());
        if (route != null && mounted) context.push(route);
      } else if (!guest) {
        ref.invalidate(publicAnnouncementsProvider(false));
      }
    } finally {
      _openingAnnouncement = false;
      if (mounted) _restartTimer();
    }
  }

  Future<void> _markReadSafely(
      ConnectedOperationsRepository repository, String id) async {
    try {
      await repository.markAnnouncementRead(id);
      if (mounted) ref.invalidate(publicAnnouncementsProvider(false));
    } catch (_) {
      // Cached announcement content remains readable while offline.
    }
  }

  String? _relatedRoute(String? type) => switch (type) {
        'tourist_spot' => '/explore',
        'ferry_schedule' => '/ferry',
        'msme' => '/explore/msme',
        'eco_tip' => '/eco-tips',
        'emergency_advisory' => '/emergency',
        _ => null,
      };
}

String _label(dynamic value) => value
    .toString()
    .split('_')
    .map((part) =>
        part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _announcementText(dynamic value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
