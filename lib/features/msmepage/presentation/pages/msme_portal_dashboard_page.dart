import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../providers/msme_portal_providers.dart';
import '../msme_theme.dart';

class MsmePortalDashboardPage extends ConsumerWidget {
	const MsmePortalDashboardPage({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final statsAsync = ref.watch(msmePortalDashboardStatsProvider);

		return Scaffold(
			backgroundColor: MsmeTheme.bgDark,
			body: statsAsync.when(
				data: (stats) {
					final totalListings = stats['totalListings'] ?? 8;
					final activeListings = stats['activeListings'] ?? 6;
					final totalReservations = stats['totalReservations'] ?? 142;
					final pendingReservations = stats['pendingReservations'] ?? 9;
					final completedReservations = stats['completedReservations'] ?? 118;
					final monthlyVisitors = stats['monthlyVisitors'] ?? 3450;
					final averageRating = (stats['averageRating'] as num?)?.toDouble() ?? 4.8;
					final totalRevenue = (stats['totalRevenue'] as num?)?.toDouble() ?? 184500.0;
					final profileCompletion = (stats['profileCompletion'] as num?)?.toDouble() ?? 0.85;

					return SingleChildScrollView(
						padding: const EdgeInsets.all(AppSpacing.lg),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Container(
									padding: const EdgeInsets.all(AppSpacing.lg),
									decoration: BoxDecoration(
										gradient: LinearGradient(colors: [MsmeTheme.primaryOrange.withValues(alpha: 0.15), MsmeTheme.cardDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
										borderRadius: BorderRadius.circular(16),
										border: Border.all(color: MsmeTheme.primaryOrange.withValues(alpha: 0.3)),
									),
									child: Row(children: [Container(width: 56, height: 56, decoration: BoxDecoration(color: MsmeTheme.primaryOrange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.storefront_rounded, color: MsmeTheme.primaryOrange, size: 28)), const SizedBox(width: AppSpacing.md), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Welcome back, Local Partner!', style: MsmeTheme.headingMedium()), const SizedBox(height: 4), Text('Tubigon Smart Tourism MSME Portal • Business Performance Overview', style: MsmeTheme.body(color: MsmeTheme.textMuted, size: 13))])), const SizedBox(width: AppSpacing.md), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: MsmeTheme.primaryOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => context.go('/msme-portal/listings/create'), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add Listing', style: TextStyle(fontWeight: FontWeight.bold))),]),
								),
								const SizedBox(height: AppSpacing.lg),
								Container(padding: const EdgeInsets.all(AppSpacing.md), decoration: MsmeTheme.cardDecoration(), child: Row(children: [const Icon(Icons.task_alt_rounded, color: MsmeTheme.green, size: 20), const SizedBox(width: 12), Text('Business Profile Completion', style: MsmeTheme.body(weight: FontWeight.w600, size: 13)), const SizedBox(width: 16), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: profileCompletion, minHeight: 8, backgroundColor: MsmeTheme.surfaceDark, valueColor: const AlwaysStoppedAnimation<Color>(MsmeTheme.primaryOrange)))), const SizedBox(width: 16), Text('${(profileCompletion * 100).toInt()}% Complete', style: MsmeTheme.body(color: MsmeTheme.primaryOrange, weight: FontWeight.bold, size: 13))])),
								const SizedBox(height: AppSpacing.lg),
								LayoutBuilder(builder: (context, constraints) { final width = constraints.maxWidth; final crossCount = width > 1100 ? 4 : (width > 600 ? 2 : 1); return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: crossCount, crossAxisSpacing: AppSpacing.md, mainAxisSpacing: AppSpacing.md, childAspectRatio: 1.8, children: [_KpiCard(title: 'Total Listings', value: '$totalListings', sub: 'Crafts & Dining', icon: Icons.inventory_2_rounded, color: MsmeTheme.blue), _KpiCard(title: 'Active Listings', value: '$activeListings', sub: 'Available online', icon: Icons.check_circle_rounded, color: MsmeTheme.green), _KpiCard(title: 'Total Reservations', value: '$totalReservations', sub: 'All time bookings', icon: Icons.calendar_month_rounded, color: MsmeTheme.purple), _KpiCard(title: 'Pending Reservations', value: '$pendingReservations', sub: 'Needs action', icon: Icons.hourglass_top_rounded, color: MsmeTheme.amber), _KpiCard(title: 'Completed Bookings', value: '$completedReservations', sub: 'Fulfilled orders', icon: Icons.verified_rounded, color: MsmeTheme.cyan), _KpiCard(title: 'Monthly Visitors', value: '$monthlyVisitors', sub: '+14% influx', icon: Icons.groups_rounded, color: MsmeTheme.orangeLight), _KpiCard(title: 'Average Rating', value: '$averageRating ⭐', sub: '46 total reviews', icon: Icons.star_rounded, color: MsmeTheme.amber), _KpiCard(title: 'Est. Revenue', value: '₱${totalRevenue.toStringAsFixed(0)}', sub: 'Gross bookings', icon: Icons.payments_rounded, color: MsmeTheme.green)]); }),
								const SizedBox(height: AppSpacing.lg),
								Text('Quick Business Actions', style: MsmeTheme.headingSmall()),
								const SizedBox(height: AppSpacing.md),
								Row(children: [_QuickActionTile(label: 'Manage Listings', icon: Icons.storefront_rounded, color: MsmeTheme.blue, onTap: () => context.go('/msme-portal/listings')), const SizedBox(width: AppSpacing.md), _QuickActionTile(label: 'View Reservations', icon: Icons.calendar_today_rounded, color: MsmeTheme.purple, onTap: () => context.go('/msme-portal/reservations')), const SizedBox(width: AppSpacing.md), _QuickActionTile(label: 'Customer Reviews', icon: Icons.rate_review_rounded, color: MsmeTheme.amber, onTap: () => context.go('/msme-portal/reviews')), const SizedBox(width: AppSpacing.md), _QuickActionTile(label: 'Export Reports', icon: Icons.download_rounded, color: MsmeTheme.green, onTap: () => context.go('/msme-portal/reports'))]),
								const SizedBox(height: AppSpacing.lg),
								Container(decoration: MsmeTheme.cardDecoration(), padding: const EdgeInsets.all(AppSpacing.lg), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Recent Business Activity', style: MsmeTheme.headingSmall()), TextButton(onPressed: () => context.go('/msme-portal/notifications'), child: Text('View All', style: GoogleFonts.inter(color: MsmeTheme.primaryOrange, fontWeight: FontWeight.bold)))]), const SizedBox(height: AppSpacing.md), const _ActivityRow(title: 'New Reservation #RES-2026-081', subtitle: 'Maria Santos booked 4 spots for Loomweaving Workshop', time: '10 mins ago', icon: Icons.bookmark_added_rounded, color: MsmeTheme.amber), const Divider(color: MsmeTheme.cardBorder), const _ActivityRow(title: 'New 5-Star Customer Review', subtitle: 'Carlos Gomez: "Authentic Boholano craftwork! Very impressed."', time: '2 hours ago', icon: Icons.star_rounded, color: MsmeTheme.green), const Divider(color: MsmeTheme.cardBorder), const _ActivityRow(title: 'LGU Tourism Office Verification Approved', subtitle: 'Your business profile is now publicly verified', time: '1 day ago', icon: Icons.verified_user_rounded, color: MsmeTheme.blue)])),
							],
						),
					);
				},
				loading: () => const Center(child: CircularProgressIndicator(color: MsmeTheme.primaryOrange)),
				error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: MsmeTheme.red))),
			),
		);
	}
}

class _KpiCard extends StatelessWidget { final String title; final String value; final String sub; final IconData icon; final Color color; const _KpiCard({required this.title, required this.value, required this.sub, required this.icon, required this.color}); @override Widget build(BuildContext context) { return Container(decoration: MsmeTheme.cardDecoration(), padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)), Text(sub, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))]), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: GoogleFonts.plusJakartaSans(color: MsmeTheme.textWhite, fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(title, style: GoogleFonts.inter(color: MsmeTheme.textMuted, fontSize: 12))]) ])); } }

class _QuickActionTile extends StatelessWidget { final String label; final IconData icon; final Color color; final VoidCallback onTap; const _QuickActionTile({required this.label, required this.icon, required this.color, required this.onTap}); @override Widget build(BuildContext context) { return Expanded(child: InkWell(onTap: onTap, child: Container(height: 96, decoration: MsmeTheme.cardDecoration(), padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color)), Text(label, style: GoogleFonts.inter(color: MsmeTheme.textWhite, fontWeight: FontWeight.w600, fontSize: 13))])))); } }

class _ActivityRow extends StatelessWidget { final String title; final String subtitle; final String time; final IconData icon; final Color color; const _ActivityRow({required this.title, required this.subtitle, required this.time, required this.icon, required this.color}); @override Widget build(BuildContext context) { return Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: GoogleFonts.inter(color: MsmeTheme.textWhite, fontWeight: FontWeight.w600, fontSize: 13)), Text(subtitle, style: GoogleFonts.inter(color: MsmeTheme.textMuted, fontSize: 12))])), Text(time, style: GoogleFonts.inter(color: MsmeTheme.textSubtle, fontSize: 11))]); } }

