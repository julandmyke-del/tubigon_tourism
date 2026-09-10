import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../data/connected_operations_repository.dart';

class PublicSpotGallery extends ConsumerWidget {
  const PublicSpotGallery({super.key, required this.spotId});
  final String spotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(publicGalleryProvider(spotId));
    return state.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Destination Gallery',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _Viewer(spotId: spotId, items: items),
                    ),
                  ),
                  child: Text('View All (${items.length})'),
                ),
              ],
            ),
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.take(8).length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) => Semantics(
                  key: ValueKey(
                      'gallery-thumbnail-$spotId-${items[index]['id']}'),
                  button: true,
                  label: 'Open photo ${index + 1} of ${items.length}',
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _Viewer(
                          spotId: spotId,
                          items: items,
                          initial: index,
                        ),
                      ),
                    ),
                    child: Hero(
                      tag: _galleryHeroTag(spotId, items[index]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          items[index]['url'].toString(),
                          width: 220,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const SizedBox(
                            width: 220,
                            child: Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Viewer extends StatefulWidget {
  const _Viewer({required this.spotId, required this.items, this.initial = 0});
  final String spotId;
  final List<Map<String, dynamic>> items;
  final int initial;

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late final PageController controller =
      PageController(initialPage: widget.initial);
  late int index = widget.initial;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (index > 0) {
            controller.previousPage(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut);
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (index < widget.items.length - 1) {
            controller.nextPage(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut);
          }
        },
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.maybePop(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text('${index + 1} / ${widget.items.length}'),
          ),
          body: Stack(
            children: [
              PageView.builder(
                controller: controller,
                itemCount: widget.items.length,
                onPageChanged: (value) => setState(() => index = value),
                itemBuilder: (context, itemIndex) => InteractiveViewer(
                  key: ValueKey(
                    'gallery-viewer-${widget.spotId}-${widget.items[itemIndex]['id']}',
                  ),
                  child: Center(
                    child: Hero(
                      tag: _galleryHeroTag(
                        widget.spotId,
                        widget.items[itemIndex],
                      ),
                      child: Image.network(
                        widget.items[itemIndex]['url'].toString(),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) => const Icon(
                          Icons.broken_image,
                          size: 60,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (MediaQuery.sizeOf(context).width > 700) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: index > 0
                        ? () => controller.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            )
                        : null,
                    icon: const Icon(Icons.chevron_left, size: 44),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: index < widget.items.length - 1
                        ? () => controller.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            )
                        : null,
                    icon: const Icon(Icons.chevron_right, size: 44),
                  ),
                ),
              ],
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  child: Text(
                    widget.items[index]['caption']?.toString() ?? '',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _galleryHeroTag(String spotId, Map<String, dynamic> item) =>
    'gallery-$spotId-${item['id']}';
