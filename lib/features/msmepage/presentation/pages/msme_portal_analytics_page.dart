import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../providers/msme_portal_providers.dart';
import '../msme_theme.dart';

class MsmePortalAnalyticsPage extends ConsumerWidget {
	const MsmePortalAnalyticsPage({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final analyticsAsync = ref.watch(msmePortalAnalyticsProvider);

		return Scaffold(
			backgroundColor: MsmeTheme.bgDark,
			body: analyticsAsync.when(
				data: (analytics) {
					final visitorTrend = List<int>.from(analytics['visitorTrend'] ?? [320, 450, 510, 680, 890, 1100, 1250, 1420]);
					final popularListings = List<Map<String, dynamic>>.from(analytics['popularListings'] ?? []);

					return SingleChildScrollView(
						padding: const EdgeInsets.all(AppSpacing.lg),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Row(
									mainAxisAlignment: MainAxisAlignment.spaceBetween,
									children: [
										Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Text('Business Analytics & Insights', style: MsmeTheme.headingLarge()),
												Text('Data-driven visitor statistics, booking trends, and revenue metrics.', style: MsmeTheme.body(color: MsmeTheme.textMuted)),
											],
										),
										const MsmeBadge(label: 'Realtime Analytics', type: MsmeBadgeType.green),
									],
								),
								const SizedBox(height: AppSpacing.lg),

								Container(
									decoration: MsmeTheme.cardDecoration(),
									padding: const EdgeInsets.all(AppSpacing.lg),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Row(
												mainAxisAlignment: MainAxisAlignment.spaceBetween,
												children: [
													Text('Monthly Visitor Growth (2026)', style: MsmeTheme.headingSmall()),
													Text('Peak: August (1,420 visitors)', style: GoogleFonts.inter(color: MsmeTheme.primaryOrange, fontWeight: FontWeight.bold, fontSize: 12)),
												],
											),
											const SizedBox(height: AppSpacing.lg),
											_BarChart(data: visitorTrend),
										],
									),
								),
								const SizedBox(height: AppSpacing.lg),

								Container(
									decoration: MsmeTheme.cardDecoration(),
									padding: const EdgeInsets.all(AppSpacing.lg),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text('Most Popular Listings by Booking Volume', style: MsmeTheme.headingSmall()),
											const SizedBox(height: AppSpacing.md),
											...popularListings.map((item) {
												final name = item['name'].toString();
												final bookings = item['bookings'] as int;
												return Padding(
													padding: const EdgeInsets.only(bottom: 12),
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: [
															Row(
																mainAxisAlignment: MainAxisAlignment.spaceBetween,
																children: [
																	Text(name, style: GoogleFonts.inter(color: MsmeTheme.textWhite, fontWeight: FontWeight.w600, fontSize: 13)),
																	Text('$bookings bookings', style: GoogleFonts.inter(color: MsmeTheme.primaryOrange, fontWeight: FontWeight.bold, fontSize: 13)),
																],
															),
															const SizedBox(height: 6),
															ClipRRect(
																borderRadius: BorderRadius.circular(4),
																child: LinearProgressIndicator(
																	value: bookings / 80.0,
																	minHeight: 8,
																	backgroundColor: MsmeTheme.surfaceDark,
																	valueColor: const AlwaysStoppedAnimation<Color>(MsmeTheme.primaryOrange),
																),
															),
														],
													),
												);
											}),
										],
									),
								),
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

class _BarChart extends StatelessWidget {
	final List<int> data;

	const _BarChart({required this.data});

	@override
	Widget build(BuildContext context) {
		final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug'];
		final maxVal = data.reduce((a, b) => a > b ? a : b);

		return SizedBox(
			height: 180,
			child: Row(
				mainAxisAlignment: MainAxisAlignment.spaceEvenly,
				crossAxisAlignment: CrossAxisAlignment.end,
				children: List.generate(data.length, (i) {
					final val = data[i];
					final pct = val / maxVal;
					return Column(
						mainAxisAlignment: MainAxisAlignment.end,
						children: [
							Container(
								width: 32,
								height: 130 * pct,
								decoration: BoxDecoration(
									color: MsmeTheme.primaryOrange.withValues(alpha: i == data.length - 1 ? 1.0 : 0.6),
									borderRadius: BorderRadius.circular(6),
								),
							),
							const SizedBox(height: 8),
							Text(months[i], style: GoogleFonts.inter(color: MsmeTheme.textMuted, fontSize: 11)),
						],
					);
				}),
			),
		);
	}
}

