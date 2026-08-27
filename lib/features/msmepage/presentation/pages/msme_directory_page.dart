import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/routes/route_names.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../models/msme.dart';
import '../../repositories/msme_repository.dart';

class MsmeDirectoryPage extends ConsumerStatefulWidget {
  const MsmeDirectoryPage({super.key});

  @override
  ConsumerState<MsmeDirectoryPage> createState() => _MsmeDirectoryPageState();
}

class _MsmeDirectoryPageState extends ConsumerState<MsmeDirectoryPage> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msmesAsync = ref.watch(msmeListProvider);

    return Scaffold(
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppGradients.premium),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    leading: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: AppColors.white),
                        onPressed: () => context.pop()),
                    title: Text('MSME Directory',
                        style: AppTypography.titleLarge
                            .copyWith(color: AppColors.white)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.white),
                      decoration: InputDecoration(
                        hintText: 'Search businesses…',
                        hintStyle: AppTypography.bodyMedium.copyWith(
                            color: AppColors.white.withValues(alpha: 0.6)),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppColors.white),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    color: AppColors.white),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                })
                            : null,
                        fillColor: AppColors.white.withValues(alpha: 0.15),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: AppSpacing.roundedFull,
                            borderSide: BorderSide(
                                color: AppColors.white.withValues(alpha: 0.3))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: AppSpacing.roundedFull,
                            borderSide:
                                const BorderSide(color: AppColors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              scrollDirection: Axis.horizontal,
              itemCount: msmeCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, i) {
                final cat = msmeCategories[i];
                final selected = cat == _selectedCategory;
                return FilterChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  selectedColor: AppColors.primary,
                  labelStyle: AppTypography.chip.copyWith(
                      color: selected ? AppColors.white : AppColors.grey600,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                  showCheckmark: false,
                );
              },
            ),
          ),
          Expanded(
            child: msmesAsync.when(
              loading: () => ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: 3,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (_, __) => const ListTileShimmer()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (msmes) {
                final filtered = msmes.where((m) {
                  final matchCat = _selectedCategory == 'All' ||
                      m.category == _selectedCategory;
                  final matchSearch =
                      m.name.toLowerCase().contains(_searchQuery.toLowerCase());
                  return matchCat && matchSearch;
                }).toList();
                if (filtered.isEmpty) {
                  return Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        const Icon(Icons.store_outlined,
                            size: 64, color: AppColors.grey300),
                        const SizedBox(height: AppSpacing.md),
                        Text('No businesses found',
                            style: AppTypography.titleMedium
                                .copyWith(color: AppColors.grey400))
                      ]));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(msmeListProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, i) {
                      return _MsmeCard(msme: filtered[i])
                          .animate(delay: (60 * i).ms)
                          .fadeIn(duration: 350.ms)
                          .slideY(
                              begin: 0.2,
                              end: 0,
                              duration: 350.ms,
                              curve: Curves.easeOut);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MsmeCard extends StatelessWidget {
  const _MsmeCard({required this.msme});
  final Msme msme;
  Future<void> _call() async {
    if (msme.phone == null) return;
    final uri = Uri(scheme: 'tel', path: msme.phone!.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppSpacing.roundedXl,
          border: Border.all(color: AppColors.lightOutline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
                color: msme.color.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppSpacing.radiusXl),
                    topRight: Radius.circular(AppSpacing.radiusXl))),
            child: Row(children: [
              Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: msme.color.withValues(alpha: 0.15),
                      borderRadius: AppSpacing.roundedXl),
                  child: Icon(msme.icon, color: msme.color, size: 26)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: msme.color.withValues(alpha: 0.12),
                            borderRadius: AppSpacing.roundedFull),
                        child: Text(msme.category,
                            style: AppTypography.labelSmall.copyWith(
                                color: msme.color,
                                fontWeight: FontWeight.w600))),
                    const SizedBox(height: 4),
                    Text(msme.name,
                        style: AppTypography.titleSmall
                            .copyWith(fontWeight: FontWeight.w700))
                  ])),
              if (msme.rating != null)
                Column(children: [
                  const Icon(Icons.star_rounded,
                      color: AppColors.warning, size: 16),
                  Text(msme.rating!.toStringAsFixed(1),
                      style: AppTypography.labelSmall
                          .copyWith(fontWeight: FontWeight.w700))
                ])
            ])),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(msme.description,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.grey600, height: 1.5)),
            const SizedBox(height: AppSpacing.sm),
            if (msme.address != null && msme.address!.isNotEmpty)
              _InfoRow(Icons.place_outlined, msme.address!),
            if (msme.businessHours != null && msme.businessHours!.isNotEmpty)
              _InfoRow(Icons.access_time_rounded, msme.businessHours!),
            if (msme.phone != null && msme.phone!.isNotEmpty)
              _InfoRow(Icons.phone_outlined, msme.phone!),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              if (msme.phone != null && msme.phone!.isNotEmpty)
                Expanded(
                    child: ElevatedButton.icon(
                        onPressed: _call,
                        icon: const Icon(Icons.phone_rounded, size: 16),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: msme.color,
                            minimumSize: const Size(0, 40)))),
              if (msme.phone != null && msme.phone!.isNotEmpty)
                const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => context.goNamed(RouteNames.msmeDetail,
                          pathParameters: {'id': msme.id.toString()}),
                      icon: const Icon(Icons.info_outline_rounded, size: 16),
                      label: const Text('Details'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: msme.color,
                          side: BorderSide(color: msme.color),
                          minimumSize: const Size(0, 40))))
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(children: [
          Icon(icon, size: 14, color: AppColors.grey400),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.grey600)))
        ]));
  }
}
