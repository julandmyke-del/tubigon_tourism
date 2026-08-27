import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../authentication/auth_provider.dart';
import '../place_category_style.dart';
import '../providers/map_provider.dart';
import '../repositories/map_location_management_repository.dart';

enum _ManagedLocationFilter { all, needsReview, verified, published, draft }

class MapLocationManagementPage extends ConsumerStatefulWidget {
  const MapLocationManagementPage({super.key});

  @override
  ConsumerState<MapLocationManagementPage> createState() =>
      _MapLocationManagementPageState();
}

class _MapLocationManagementPageState
    extends ConsumerState<MapLocationManagementPage> {
  String _search = '';
  _ManagedLocationFilter _filter = _ManagedLocationFilter.all;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(managedMapLocationsProvider);
    final role = ref.watch(authProvider).role;
    final title = role == UserRole.admin
        ? 'Map Location Management'
        : 'LGU Map Location Management';
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
          ),
          child: LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text(
                  'Review drafts, place exact pins, link existing entities, verify, and publish to Explore + Smart Map.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
              ],
            );
            final actions = Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _manageCategories,
                icon: const Icon(Icons.category_rounded),
                label: const Text('Categories'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black),
                onPressed: _busy ? null : () => _editLocation(),
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text('Add Location'),
              ),
            ]);
            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        heading,
                        const SizedBox(height: 12),
                        actions,
                      ])
                : Row(children: [Expanded(child: heading), actions]);
          }),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: TextField(
            onChanged: (value) => setState(() => _search = value.trim()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search name, category, or address',
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Color(0xFFF59E0B)),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF334155))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF334155))),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            children: _ManagedLocationFilter.values
                .map((filter) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                        label: Text(_filterLabel(filter)),
                        selectedColor: const Color(0xFFF59E0B),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: _filter == filter
                              ? Colors.black
                              : const Color(0xFFCBD5E1),
                          fontWeight: FontWeight.w700,
                        ),
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                    ))
                .toList(growable: false),
          ),
        ),
        Expanded(
          child: locations.when(
            loading: () => const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Color(0xFFF59E0B)),
                SizedBox(height: 10),
                Text('Loading managed locations…',
                    style: TextStyle(color: Color(0xFFCBD5E1))),
              ]),
            ),
            error: (_, __) => _ManagementError(onRetry: _refresh),
            data: (items) {
              final query = _search.toLowerCase();
              final filtered = items.where((item) {
                final value =
                    '${item.name} ${item.categoryName ?? ''} ${item.address ?? ''}'
                        .toLowerCase();
                return value.contains(query) && _matchesFilter(item);
              }).toList();
              if (filtered.isEmpty) {
                return const Center(
                  child: Text('No managed locations found.',
                      style: TextStyle(color: Color(0xFF94A3B8))),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _ManagedLocationCard(
                    location: filtered[index],
                    disabled: _busy,
                    onReview: () => _reviewLocation(filtered[index]),
                    onEdit: () => _editLocation(filtered[index]),
                    onVerify: () =>
                        _verify(filtered[index], !filtered[index].verified),
                    onPublish: () =>
                        _publish(filtered[index], !filtered[index].published),
                    onActive: () =>
                        _setActive(filtered[index], !filtered[index].active),
                    onArchive: () => _archive(filtered[index]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  String _filterLabel(_ManagedLocationFilter filter) => switch (filter) {
        _ManagedLocationFilter.all => 'All',
        _ManagedLocationFilter.needsReview => 'Needs Review',
        _ManagedLocationFilter.verified => 'Verified',
        _ManagedLocationFilter.published => 'Published',
        _ManagedLocationFilter.draft => 'Draft',
      };

  bool _matchesFilter(ManagedMapLocation item) => switch (_filter) {
        _ManagedLocationFilter.all => true,
        _ManagedLocationFilter.needsReview => !item.verified,
        _ManagedLocationFilter.verified => item.verified,
        _ManagedLocationFilter.published => item.published,
        _ManagedLocationFilter.draft => !item.published,
      };

  Future<void> _reviewLocation(ManagedMapLocation item) async {
    final result = await context.push<Map<String, dynamic>>(
      '/map/pick?mode=place&lat=${item.latitude ?? 9.9515}'
      '&lng=${item.longitude ?? 123.9618}',
    );
    if (result == null || !mounted) return;
    await _save(item, {
      'name': item.name,
      'latitude': (result['latitude'] as num?)?.toDouble(),
      'longitude': (result['longitude'] as num?)?.toDouble(),
      'entity_type': item.entityType,
      'entity_id': item.entityId,
    });
  }

  Future<void> _editLocation([ManagedMapLocation? existing]) async {
    final categories = await ref.read(managedMapCategoriesProvider.future);
    final activeCategories = categories.where((item) => item.active).toList();
    if (!mounted || activeCategories.isEmpty) {
      _message('Create an active place category first.');
      return;
    }
    final links = await ref.read(mapLinkOptionsProvider.future);
    if (!mounted) return;

    final name = TextEditingController(text: existing?.name);
    final description = TextEditingController(text: existing?.description);
    final address = TextEditingController(text: existing?.address);
    final image = TextEditingController(text: existing?.imageUrl);
    var categoryId = existing?.categoryId ?? activeCategories.first.id;
    var subcategoryId = existing?.subcategoryId;
    var entityType = existing?.entityType;
    var entityId = existing?.entityId;
    var markerIcon = existing?.markerIcon;
    var latitude = existing?.latitude;
    var longitude = existing?.longitude;
    var featured = existing?.isFeatured ?? false;
    var saving = false;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final children = activeCategories
              .where((item) => item.parentId == categoryId)
              .toList();
          final entityOptions = entityType == null
              ? const <LinkedPlaceOption>[]
              : links[entityType] ?? const <LinkedPlaceOption>[];
          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            title: Text(
                existing == null ? 'Add Map Location' : 'Edit Map Location',
                style: const TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 650,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _field(name, 'Place name *', Icons.place_rounded),
                  _field(description, 'Short description', Icons.notes_rounded,
                      maxLines: 3),
                  _field(address, 'Address', Icons.location_city_rounded),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: _input('Category *', Icons.category_rounded),
                    items: activeCategories
                        .where((item) => item.parentId == null)
                        .map((item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          categoryId = value;
                          subcategoryId = null;
                        });
                      }
                    },
                  ),
                  if (children.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: subcategoryId,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: _input('Subcategory', Icons.label_rounded),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('None')),
                        ...children.map((item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name),
                            )),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => subcategoryId = value),
                    ),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    initialValue: entityType,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        _input('Link existing entity', Icons.link_rounded),
                    items: const [
                      DropdownMenuItem(
                          value: null, child: Text('Standalone place')),
                      DropdownMenuItem(
                          value: 'msme', child: Text('Existing MSME')),
                      DropdownMenuItem(
                          value: 'tourist_spot',
                          child: Text('Existing Tourist Spot')),
                    ],
                    onChanged: (value) => setDialogState(() {
                      entityType = value;
                      entityId = null;
                    }),
                  ),
                  if (entityType != null) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue:
                          entityOptions.any((item) => item.id == entityId)
                              ? entityId
                              : null,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: _input('Choose existing record *',
                          Icons.manage_search_rounded),
                      items: entityOptions
                          .map((item) => DropdownMenuItem(
                              value: item.id, child: Text(item.name)))
                          .toList(),
                      onChanged: (value) {
                        final option = entityOptions
                            .where((item) => item.id == value)
                            .firstOrNull;
                        setDialogState(() {
                          entityId = value;
                          latitude ??= option?.latitude;
                          longitude ??= option?.longitude;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    initialValue: markerIcon,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration:
                        _input('Marker icon override', Icons.pin_drop_rounded),
                    items: const [
                      DropdownMenuItem(
                          value: null, child: Text('Use category icon')),
                      DropdownMenuItem(value: 'place', child: Text('Place')),
                      DropdownMenuItem(
                          value: 'shopping_bag', child: Text('Shopping')),
                      DropdownMenuItem(
                          value: 'fastfood', child: Text('Fast food')),
                      DropdownMenuItem(
                          value: 'restaurant', child: Text('Restaurant')),
                      DropdownMenuItem(
                          value: 'hotel', child: Text('Accommodation')),
                      DropdownMenuItem(
                          value: 'emergency', child: Text('Emergency')),
                      DropdownMenuItem(
                          value: 'directions_boat',
                          child: Text('Port / Transport')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => markerIcon = value),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.pin_drop_rounded,
                          color: Color(0xFFF59E0B)),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          latitude == null || longitude == null
                              ? 'No exact pin selected — record will remain a draft.'
                              : '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
                          style: const TextStyle(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final result =
                              await this.context.push<Map<String, dynamic>>(
                                    '/map/pick?mode=place&lat=${latitude ?? 9.9515}&lng=${longitude ?? 123.9618}',
                                  );
                          if (result != null) {
                            setDialogState(() {
                              latitude =
                                  (result['latitude'] as num?)?.toDouble();
                              longitude =
                                  (result['longitude'] as num?)?.toDouble();
                            });
                          }
                        },
                        icon: const Icon(Icons.map_rounded),
                        label:
                            Text(latitude == null ? 'Drop Pin' : 'Adjust Pin'),
                      ),
                    ]),
                  ),
                  _field(image, 'Image URL (HTTPS)', Icons.image_rounded),
                  SwitchListTile(
                    value: featured,
                    onChanged: (value) =>
                        setDialogState(() => featured = value),
                    activeThumbColor: const Color(0xFFF59E0B),
                    title: const Text('Featured place',
                        style: TextStyle(color: Colors.white)),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black),
                onPressed: saving
                    ? null
                    : () {
                        if (name.text.trim().isEmpty ||
                            categoryId.isEmpty ||
                            (entityType != null && entityId == null)) {
                          _message(
                              'Complete the required fields before saving.');
                          return;
                        }
                        setDialogState(() => saving = true);
                        Navigator.pop(dialogContext, {
                          'name': name.text.trim(),
                          'description': _nullable(description.text),
                          'address': _nullable(address.text),
                          'category_id': categoryId,
                          'subcategory_id': subcategoryId,
                          'entity_type': entityType,
                          'entity_id': entityId,
                          'latitude': latitude,
                          'longitude': longitude,
                          'marker_icon': markerIcon,
                          'image_url': _nullable(image.text),
                          'is_featured': featured,
                        });
                      },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Draft'),
              ),
            ],
          );
        },
      ),
    );
    name.dispose();
    description.dispose();
    address.dispose();
    image.dispose();
    if (payload == null || !mounted) return;
    await _save(existing, payload);
  }

  Future<void> _save(
      ManagedMapLocation? existing, Map<String, dynamic> payload) async {
    setState(() => _busy = true);
    final repository = ref.read(mapLocationManagementRepositoryProvider);
    try {
      await repository.save(payload, id: existing?.id);
      if (mounted) {
        _message(
            existing == null ? 'Draft location created.' : 'Location updated.');
      }
    } on PossibleDuplicateException catch (error) {
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              title: const Text('Possible existing location found',
                  style: TextStyle(color: Colors.white)),
              content: Text(
                error.matches
                    .map((item) =>
                        '• ${item['name']} (${item['source_type']})${item['distance_meters'] == null ? '' : ' · ${item['distance_meters']} m away'}')
                    .join('\n'),
                style: const TextStyle(color: Color(0xFFCBD5E1)),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Review')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save Anyway')),
              ],
            ),
          ) ??
          false;
      if (confirmed) {
        await repository.save(payload,
            id: existing?.id, overrideDuplicate: true);
        if (mounted) _message('Location saved after duplicate review.');
      }
    } catch (_) {
      if (mounted) {
        _message('Unable to save the location. Check the form and try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refresh();
      }
    }
  }

  Future<void> _verify(ManagedMapLocation item, bool value) => _runAction(
      () => ref
          .read(mapLocationManagementRepositoryProvider)
          .verify(item.id, value),
      value ? 'Location verified.' : 'Verification removed.');

  Future<void> _publish(ManagedMapLocation item, bool value) => _runAction(
      () => ref
          .read(mapLocationManagementRepositoryProvider)
          .publish(item.id, value),
      value ? 'Location published to Explore + Map.' : 'Location unpublished.');

  Future<void> _setActive(ManagedMapLocation item, bool value) => _runAction(
      () => ref
          .read(mapLocationManagementRepositoryProvider)
          .setActive(item.id, value),
      value ? 'Location activated.' : 'Location deactivated and unpublished.');

  Future<void> _archive(ManagedMapLocation item) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Archive location?'),
            content:
                Text('${item.name} will be hidden, not permanently deleted.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Archive')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _runAction(
        () =>
            ref.read(mapLocationManagementRepositoryProvider).archive(item.id),
        'Location archived.');
  }

  Future<void> _runAction(
      Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _message(success);
    } catch (_) {
      if (mounted) {
        _message(
            'Action could not be completed. Verify the workflow requirements.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refresh();
      }
    }
  }

  Future<void> _manageCategories() async {
    final categories = await ref.read(managedMapCategoriesProvider.future);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Place Categories',
            style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 560,
          height: 460,
          child: Column(children: [
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _editCategory();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Category'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: categories.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Color(0xFF334155)),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: placeCategoryColor(category.markerColor)
                          .withValues(alpha: .18),
                      child: Icon(placeCategoryIcon(category.icon),
                          color: placeCategoryColor(category.markerColor)),
                    ),
                    title: Text(category.name,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                        '${category.slug} · ${category.active ? 'Active' : 'Inactive'}',
                        style: const TextStyle(color: Color(0xFF94A3B8))),
                    trailing: IconButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        await _editCategory(category);
                      },
                      icon: const Icon(Icons.edit_rounded,
                          color: Color(0xFFF59E0B)),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _editCategory([MapPlaceCategory? existing]) async {
    final categories = await ref.read(managedMapCategoriesProvider.future);
    if (!mounted) return;
    final hasChildren = existing != null &&
        categories.any((category) => category.parentId == existing.id);
    final possibleParents = categories
        .where((category) =>
            category.parentId == null && category.id != existing?.id)
        .toList(growable: false);
    final name = TextEditingController(text: existing?.name);
    final slug = TextEditingController(text: existing?.slug);
    final color =
        TextEditingController(text: existing?.markerColor ?? '#F59E0B');
    var icon = existing?.icon ?? 'place';
    var active = existing?.active ?? true;
    var parentId = existing?.parentId;
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: Text(existing == null ? 'Add Category' : 'Edit Category',
              style: const TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _field(name, 'Name *', Icons.category_rounded),
              _field(slug, 'Slug', Icons.link_rounded),
              _field(color, 'Marker color (#RRGGBB)', Icons.palette_rounded),
              DropdownButtonFormField<String?>(
                initialValue: parentId,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration:
                    _input('Parent category', Icons.account_tree_rounded),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Top-level category')),
                  ...possibleParents.map((category) =>
                      DropdownMenuItem<String?>(
                          value: category.id, child: Text(category.name))),
                ],
                onChanged: hasChildren
                    ? null
                    : (value) => setState(() => parentId = value),
              ),
              if (hasChildren)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'A category with subcategories must remain top-level.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ),
              DropdownButtonFormField<String>(
                initialValue: icon,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: _input('Icon', Icons.pin_drop_rounded),
                items: const [
                  'place',
                  'landscape',
                  'storefront',
                  'shopping_bag',
                  'fastfood',
                  'restaurant',
                  'deck',
                  'hotel',
                  'forest',
                  'account_balance',
                  'emergency',
                  'directions_boat',
                  'account_balance_wallet'
                ]
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => icon = value);
                },
              ),
              SwitchListTile(
                value: active,
                onChanged: (value) => setState(() => active = value),
                title:
                    const Text('Active', style: TextStyle(color: Colors.white)),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'name': name.text.trim(),
                'parent_id': parentId,
                if (slug.text.trim().isNotEmpty) 'slug': slug.text.trim(),
                'icon': icon,
                'marker_color': color.text.trim(),
                'active': active,
                'sort_order': existing?.sortOrder ?? 500,
              }),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    slug.dispose();
    color.dispose();
    if (data == null) return;
    try {
      await ref
          .read(mapLocationManagementRepositoryProvider)
          .saveCategory(data, id: existing?.id);
      _message('Category saved.');
      ref.invalidate(managedMapCategoriesProvider);
      ref.invalidate(mapPlaceCategoriesProvider);
    } catch (_) {
      _message(
          'Unable to save category. Check unique name, slug, icon, and color.');
    }
  }

  InputDecoration _input(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, color: const Color(0xFFF59E0B)),
        filled: true,
        fillColor: const Color(0xFF111827),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155))),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _field(TextEditingController controller, String label, IconData icon,
          {int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: _input(label, icon),
        ),
      );

  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

  void _refresh() {
    ref.invalidate(managedMapLocationsProvider);
    ref.invalidate(mapMarkersProvider);
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF0F172A),
    ));
  }
}

class _ManagedLocationCard extends StatelessWidget {
  const _ManagedLocationCard({
    required this.location,
    required this.disabled,
    required this.onReview,
    required this.onEdit,
    required this.onVerify,
    required this.onPublish,
    required this.onActive,
    required this.onArchive,
  });
  final ManagedMapLocation location;
  final bool disabled;
  final VoidCallback onReview;
  final VoidCallback onEdit;
  final VoidCallback onVerify;
  final VoidCallback onPublish;
  final VoidCallback onActive;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 7, runSpacing: 6, children: [
                _Status(
                    label: location.categoryName ?? 'Uncategorized',
                    color: const Color(0xFFF59E0B)),
                _Status(
                    label:
                        location.verified ? 'Verified' : 'Needs Verification',
                    color: location.verified
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFFFBBF24)),
                _Status(
                    label: location.published ? 'Published' : 'Draft',
                    color: location.published
                        ? const Color(0xFF34D399)
                        : const Color(0xFF94A3B8)),
                if (!location.active)
                  const _Status(label: 'Inactive', color: Color(0xFFFB7185)),
              ]),
              const SizedBox(height: 9),
              Text(location.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(location.description ?? 'No description',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 5),
              Text(
                location.latitude == null || location.longitude == null
                    ? 'Exact pin required before verification'
                    : '${location.address ?? 'Tubigon, Bohol'} · ${location.latitude!.toStringAsFixed(5)}, ${location.longitude!.toStringAsFixed(5)}',
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
              ),
              if (location.entityType != null)
                Text('Linked: ${location.entityType} · ${location.entityId}',
                    style: const TextStyle(
                        color: Color(0xFF38BDF8), fontSize: 10)),
            ],
          );
          final actions = Wrap(spacing: 4, runSpacing: 4, children: [
            _action('Review Location', Icons.map_rounded, onReview,
                color: const Color(0xFFF59E0B)),
            _action('Edit', Icons.edit_location_alt_rounded, onEdit),
            _action(location.verified ? 'Unverify' : 'Verify',
                Icons.verified_rounded, onVerify),
            _action(location.published ? 'Unpublish' : 'Publish',
                Icons.public_rounded, onPublish),
            _action(location.active ? 'Deactivate' : 'Activate',
                Icons.power_settings_new_rounded, onActive),
            _action('Archive', Icons.archive_rounded, onArchive,
                color: const Color(0xFFFB7185)),
          ]);
          return constraints.maxWidth < 760
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  details,
                  const SizedBox(height: 10),
                  actions,
                ])
              : Row(children: [Expanded(child: details), actions]);
        }),
      );

  Widget _action(String label, IconData icon, VoidCallback action,
          {Color color = const Color(0xFFCBD5E1)}) =>
      TextButton.icon(
        onPressed: disabled ? null : action,
        icon: Icon(icon, size: 17, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 11)),
      );
}

class _Status extends StatelessWidget {
  const _Status({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w800)),
      );
}

class _ManagementError extends StatelessWidget {
  const _ManagementError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded,
              size: 52, color: Color(0xFF64748B)),
          const SizedBox(height: 10),
          const Text('Unable to load map locations.',
              style: TextStyle(color: Colors.white)),
          TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry')),
        ]),
      );
}
