import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/msme_portal_providers.dart';
import '../msme_theme.dart';

class MsmePortalListingsPage extends ConsumerWidget {
  const MsmePortalListingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(msmePortalListingsProvider);
    return Scaffold(
      backgroundColor: MsmeTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: businesses.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
              child: OutlinedButton(
                  onPressed: () => ref.invalidate(msmePortalListingsProvider),
                  child: Text('Retry: $error'))),
          data: (items) {
            if (items.isEmpty) {
              return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.storefront_rounded,
                    size: 56, color: MsmeTheme.primaryOrange),
                Text('No business profile yet.',
                    style: MsmeTheme.headingLarge()),
                const SizedBox(height: 12),
                ElevatedButton(
                    onPressed: () => context.push('/msme-portal/profile'),
                    child: const Text('Set up business')),
              ]));
            }
            final business = items.first;
            final status =
                business['verification_status']?.toString() ?? 'pending';
            return ListView(children: [
              Text('My Business', style: MsmeTheme.headingLarge()),
              const Text(
                  'The current schema represents one owned MSME business—not separate fake listings.',
                  style: TextStyle(color: MsmeTheme.textMuted)),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: MsmeTheme.cardDecoration(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(business['name']?.toString() ?? 'Business',
                          style: MsmeTheme.headingMedium()),
                      Text(
                          '${business['category'] ?? 'Uncategorized'} • ${business['address'] ?? 'Location not set'}',
                          style: const TextStyle(color: MsmeTheme.textMuted)),
                      const SizedBox(height: 8),
                      Chip(
                          label:
                              Text(status.replaceAll('_', ' ').toUpperCase())),
                      if ((business['verification_notes']?.toString() ?? '')
                          .isNotEmpty)
                        Text(business['verification_notes'].toString(),
                            style: const TextStyle(color: MsmeTheme.amber)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, children: [
                        ElevatedButton.icon(
                            onPressed: () =>
                                context.push('/msme-portal/profile'),
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit profile')),
                        OutlinedButton.icon(
                            onPressed: () => context
                                .push('/map?marker=msme:${business['id']}'),
                            icon: const Icon(Icons.visibility),
                            label: Text(status == 'verified'
                                ? 'View public marker'
                                : 'Private preview')),
                      ]),
                    ]),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
