import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../partner_theme.dart';

class PartnerSettingsPage extends ConsumerStatefulWidget {
  const PartnerSettingsPage({super.key});

  @override
  ConsumerState<PartnerSettingsPage> createState() => _PartnerSettingsPageState();
}

class _PartnerSettingsPageState extends ConsumerState<PartnerSettingsPage> {
  // Notification Toggles
  bool _emailReservations = true;
  bool _emailReviews = true;
  bool _emailPayments = true;
  bool _pushReservations = true;
  bool _pushReviews = false;
  bool _pushSystem = true;
  bool _smsReservations = false;

  // Privacy Toggles
  bool _showPhone = true;
  bool _showEmail = false;
  bool _allowAnalytics = true;

  // Regional
  String _language = 'en';
  String _currency = 'PHP';
  String _timezone = 'Asia/Manila';

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully!'),
        backgroundColor: PartnerTheme.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Partner Settings', style: PartnerTheme.headingLarge()),
            Text('Configure your notifications, privacy preferences, and regional settings.', style: PartnerTheme.label()),
            const SizedBox(height: 24),

            // Notification Preferences
            _buildSection(
              title: 'Notification Preferences',
              children: [
                _toggleRow('Email Reservations', 'Receive email alerts for new bookings and cancellations', _emailReservations, (v) => setState(() => _emailReservations = v)),
                _toggleRow('Email Reviews', 'Receive email alerts when guests post new reviews', _emailReviews, (v) => setState(() => _emailReviews = v)),
                _toggleRow('Email Payments', 'Receive payout and transaction statements via email', _emailPayments, (v) => setState(() => _emailPayments = v)),
                _toggleRow('Push Booking Alerts', 'Instant push notifications on your device for reservations', _pushReservations, (v) => setState(() => _pushReservations = v)),
                _toggleRow('Push Review Alerts', 'Instant push notifications when a new review is posted', _pushReviews, (v) => setState(() => _pushReviews = v)),
                _toggleRow('Push System Alerts', 'Important system announcements and updates', _pushSystem, (v) => setState(() => _pushSystem = v)),
                _toggleRow('SMS Instant Alerts', 'Receive urgent reservation updates via SMS text', _smsReservations, (v) => setState(() => _smsReservations = v)),
              ],
            ),
            const SizedBox(height: 24),

            // Privacy Settings
            _buildSection(
              title: 'Privacy & Visibility',
              children: [
                _toggleRow('Display Contact Phone', 'Show your business phone number on public listings', _showPhone, (v) => setState(() => _showPhone = v)),
                _toggleRow('Display Email Address', 'Show your email address on public partner profile', _showEmail, (v) => setState(() => _showEmail = v)),
                _toggleRow('Allow Analytics Tracking', 'Help improve Tubigon Tourism app by sharing usage data', _allowAnalytics, (v) => setState(() => _allowAnalytics = v)),
              ],
            ),
            const SizedBox(height: 24),

            // Regional & System
            _buildSection(
              title: 'Regional & System Preferences',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _dropdownField(
                        'APP LANGUAGE',
                        _language,
                        const [
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'ceb', child: Text('Cebuano (Bisaya)')),
                        ],
                        (v) => setState(() => _language = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _dropdownField(
                        'CURRENCY DISPLAY',
                        _currency,
                        const [
                          DropdownMenuItem(value: 'PHP', child: Text('PHP (₱)')),
                          DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                        ],
                        (v) => setState(() => _currency = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _dropdownField(
                        'TIMEZONE',
                        _timezone,
                        const [
                          DropdownMenuItem(value: 'Asia/Manila', child: Text('Asia/Manila (GMT+8)')),
                        ],
                        (v) => setState(() => _timezone = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Save Button
            ElevatedButton.icon(
              onPressed: _saveSettings,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save Preferences'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PartnerTheme.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: PartnerTheme.headingMedium()),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _toggleRow(String label, String desc, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: PartnerTheme.textWhite)),
                Text(desc, style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.textDisabled)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: PartnerTheme.primaryOrange,
            activeTrackColor: PartnerTheme.primaryOrange.withValues(alpha: 0.3),
            inactiveThumbColor: PartnerTheme.textDisabled,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.06),
          ),
        ],
      ),
    );
  }

  Widget _dropdownField(String label, String val, List<DropdownMenuItem<String>> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: PartnerTheme.label()),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: val,
          dropdownColor: PartnerTheme.cardDark,
          style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textWhite),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
