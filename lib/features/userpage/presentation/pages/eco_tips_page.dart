import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/route_names.dart';
import '../../../eco/repositories/eco_repository.dart';

class EcoTipsPage extends ConsumerWidget {
  const EcoTipsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tips = ref.watch(ecoTipsListProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed(RouteNames.home),
        ),
        title: const Text('Eco-Tourism Guidelines'),
      ),
      body: tips.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
        error: (error, _) => _EcoState(
          icon: Icons.cloud_off_rounded,
          title: 'Eco tips unavailable',
          message: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(ecoTipsListProvider),
        ),
        data: (items) => items.isEmpty
            ? const _EcoState(
                icon: Icons.eco_outlined,
                title: 'No guidelines published yet',
                message:
                    'Please check again when tourism guidance is available.',
              )
            : RefreshIndicator(
                onRefresh: () => ref.refresh(ecoTipsListProvider.future),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildBanner(),
                    const SizedBox(height: 24),
                    const Text(
                      'Green Travel Practices',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    ...items.asMap().entries.map((entry) {
                      final tip = entry.value;
                      return Semantics(
                        label: '${tip.category} eco tip: ${tip.title}',
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: tip.color.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    tip.color.withValues(alpha: 0.15),
                                child: Icon(tip.icon, color: tip.color),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tip.title,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(tip.content,
                                        style: const TextStyle(
                                            color: Color(0xFFCBD5E1),
                                            fontSize: 13,
                                            height: 1.5)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate(delay: (60 * entry.key).ms)
                            .fadeIn(duration: 300.ms),
                      );
                    }),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBanner() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF10B981)]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Row(
          children: [
            Icon(Icons.eco_rounded, color: Colors.white, size: 48),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preserve Tubigon',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text(
                      'Help protect our marine sanctuaries and coastal beauty for generations to come.',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _EcoState extends StatelessWidget {
  const _EcoState(
      {required this.icon,
      required this.title,
      required this.message,
      this.onRetry});

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: const Color(0xFF64748B)),
              const SizedBox(height: 12),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF94A3B8))),
              if (onRetry != null) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry')),
              ],
            ],
          ),
        ),
      );
}
