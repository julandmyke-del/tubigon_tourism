import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../providers/msme_portal_providers.dart';
import '../msme_theme.dart';

class MsmePortalCreateListingPage extends ConsumerStatefulWidget {
	const MsmePortalCreateListingPage({super.key, this.listingId});

	final String? listingId;

	@override
	ConsumerState<MsmePortalCreateListingPage> createState() => _MsmePortalCreateListingPageState();
}

class _MsmePortalCreateListingPageState extends ConsumerState<MsmePortalCreateListingPage> {
	final _formKey = GlobalKey<FormState>();
	final _nameCtrl = TextEditingController();
	final _priceCtrl = TextEditingController();
	final _capacityCtrl = TextEditingController();
	final _hoursCtrl = TextEditingController();
	final _descCtrl = TextEditingController();
	final _imageUrlCtrl = TextEditingController();
	String _selectedCategory = 'Handicrafts';
	bool _isFeatured = false;
	bool _saving = false;

	@override
	void dispose() {
		_nameCtrl.dispose();
		_priceCtrl.dispose();
		_capacityCtrl.dispose();
		_hoursCtrl.dispose();
		_descCtrl.dispose();
		_imageUrlCtrl.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: MsmeTheme.bgDark,
			body: SingleChildScrollView(
				padding: const EdgeInsets.all(AppSpacing.lg),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Row(
							children: [
								IconButton(
									icon: const Icon(Icons.arrow_back_rounded, color: MsmeTheme.textWhite),
									onPressed: () => context.go('/msme-portal/listings'),
								),
								const SizedBox(width: 8),
								Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text('Create Business Listing', style: MsmeTheme.headingLarge()),
										Text('Add a new handicraft product, dining menu item, or tour service.', style: MsmeTheme.body(color: MsmeTheme.textMuted)),
									],
								),
							],
						),
						const SizedBox(height: AppSpacing.lg),

						Container(
							decoration: MsmeTheme.cardDecoration(),
							padding: const EdgeInsets.all(AppSpacing.lg),
							child: Form(
								key: _formKey,
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Row(
											children: [
												Expanded(child: _buildInputField('Product / Service Name', _nameCtrl, Icons.inventory_2_rounded)),
												const SizedBox(width: AppSpacing.md),
												Expanded(
													child: Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: [
															Text('Category', style: GoogleFonts.inter(color: MsmeTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
															const SizedBox(height: 6),
															DropdownButtonFormField<String>(
																value: _selectedCategory,
																dropdownColor: MsmeTheme.surfaceDark,
																style: GoogleFonts.inter(color: MsmeTheme.textWhite, fontSize: 14),
																decoration: InputDecoration(
																	filled: true,
																	fillColor: MsmeTheme.surfaceDark,
																	contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
																	border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: MsmeTheme.cardBorder)),
																	enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: MsmeTheme.cardBorder)),
																),
																items: ['Handicrafts', 'Food & Dining', 'Tour Services', 'Agriculture', 'Accommodation']
																		.map((c) => DropdownMenuItem(value: c, child: Text(c)))
																		.toList(),
																onChanged: (val) => setState(() => _selectedCategory = val!),
															),
														],
													),
												),
											],
										),
										const SizedBox(height: AppSpacing.md),

										Row(
											children: [
												Expanded(child: _buildInputField('Price (PHP ₱)', _priceCtrl, Icons.payments_rounded, isNumeric: true)),
												const SizedBox(width: AppSpacing.md),
												Expanded(child: _buildInputField('Max Group Capacity / Stock', _capacityCtrl, Icons.groups_rounded, isNumeric: true)),
											],
										),
										const SizedBox(height: AppSpacing.md),

										Row(
											children: [
												Expanded(child: _buildInputField('Operating / Service Hours', _hoursCtrl, Icons.access_time_rounded)),
												const SizedBox(width: AppSpacing.md),
												Expanded(child: _buildInputField('Cover Image URL (Optional)', _imageUrlCtrl, Icons.image_rounded)),
											],
										),
										const SizedBox(height: AppSpacing.md),

										SwitchListTile(
											contentPadding: EdgeInsets.zero,
											activeColor: MsmeTheme.primaryOrange,
											title: Text('Feature on Tourist Homepage', style: GoogleFonts.inter(color: MsmeTheme.textWhite, fontWeight: FontWeight.w600)),
											subtitle: Text('Promote this listing as a highlighted attraction for visitors', style: GoogleFonts.inter(color: MsmeTheme.textMuted, fontSize: 12)),
											value: _isFeatured,
											onChanged: (val) => setState(() => _isFeatured = val),
										),
										const SizedBox(height: AppSpacing.md),

										_buildInputField('Description & Details', _descCtrl, Icons.description_rounded, maxLines: 4),
										const SizedBox(height: AppSpacing.xl),

										Row(
											mainAxisAlignment: MainAxisAlignment.end,
											children: [
												OutlinedButton(
													onPressed: () => context.go('/msme-portal/listings'),
													style: OutlinedButton.styleFrom(side: const BorderSide(color: MsmeTheme.cardBorder)),
													child: Text('Cancel', style: GoogleFonts.inter(color: MsmeTheme.textMuted)),
												),
												const SizedBox(width: AppSpacing.md),
												ElevatedButton.icon(
													style: ElevatedButton.styleFrom(
														backgroundColor: MsmeTheme.primaryOrange,
														foregroundColor: Colors.white,
														padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
														shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
													),
													onPressed: _saving ? null : _saveListing,
													icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_rounded, size: 18),
													label: Text(_saving ? 'Publishing...' : 'Publish Listing', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
												),
											],
										),
									],
								),
							),
						),
					],
				),
			),
		);
	}

	Widget _buildInputField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, bool isNumeric = false}) {
		return Column(
			crossAxisAlignment: CrossAxisAlignment.start,
			children: [
				Text(label, style: GoogleFonts.inter(color: MsmeTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
				const SizedBox(height: 6),
				TextFormField(
					controller: controller,
					maxLines: maxLines,
					keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
					style: GoogleFonts.inter(color: MsmeTheme.textWhite, fontSize: 14),
					decoration: InputDecoration(
						prefixIcon: Icon(icon, color: MsmeTheme.textMuted, size: 18),
						filled: true,
						fillColor: MsmeTheme.surfaceDark,
						contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
						border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: MsmeTheme.cardBorder)),
						enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: MsmeTheme.cardBorder)),
						focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: MsmeTheme.primaryOrange)),
					),
				),
			],
		);
	}

	void _saveListing() async {
		if (_nameCtrl.text.isEmpty) return;
		setState(() => _saving = true);
		final repo = ref.read(msmePortalRepositoryProvider);
		await repo.createListing({
			'name': _nameCtrl.text.trim(),
			'category': _selectedCategory,
			'price': double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
			'capacity': int.tryParse(_capacityCtrl.text.trim()) ?? 1,
			'hours': _hoursCtrl.text.trim(),
			'image': _imageUrlCtrl.text.trim(),
			'description': _descCtrl.text.trim(),
			'is_featured': _isFeatured,
			'status': 'Active',
		});
		setState(() => _saving = false);
		ref.invalidate(msmePortalListingsProvider);

		if (mounted) {
			context.go('/msme-portal/listings');
		}
	}
}
