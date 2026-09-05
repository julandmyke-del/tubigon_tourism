import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/route_names.dart';
import '../../../authentication/auth_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final displayName =
        authState.isGuest ? 'Guest Explorer' : (authState.name ?? 'Explorer');
    final displayEmail =
        authState.isGuest ? 'Browsing as guest' : (authState.email ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      body: CustomScrollView(
        slivers: [
          // Header App Bar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF0F172A),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.settings_rounded,
                      color: Colors.white, size: 18),
                ),
                onPressed: () => context.goNamed(RouteNames.settings),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF1E293B),
                      Color(0xFF080F1A)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFF59E0B), width: 3),
                            ),
                            child: const CircleAvatar(
                              radius: 44,
                              backgroundColor: Color(0xFF1E293B),
                              child: Icon(Icons.person_rounded,
                                  color: Colors.white, size: 48),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: () =>
                                  context.goNamed(RouteNames.editProfile),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF59E0B),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit_rounded,
                                    size: 14, color: Colors.black),
                              ),
                            ),
                          ),
                        ],
                      )
                          .animate()
                          .scale(duration: 400.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 10),
                      Text(
                        displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800),
                      ),
                      Text(
                        displayEmail,
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Settings & Account Actions
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _MenuSection(
                  title: 'Account',
                  items: [
                    _MenuItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Edit Profile',
                      onTap: () => context.goNamed(RouteNames.editProfile),
                    ),
                    _MenuItem(
                      icon: Icons.password_rounded,
                      label: 'Change Password',
                      onTap: () => _showChangePasswordDialog(context, ref),
                    ),
                    _MenuItem(
                      icon: Icons.favorite_outline_rounded,
                      label: 'My Favorites',
                      onTap: () => context.push('/favorites'),
                    ),
                    _MenuItem(
                      icon: Icons.luggage_outlined,
                      label: 'My Itineraries',
                      onTap: () => context.push('/itineraries'),
                    ),
                    _MenuItem(
                      icon: Icons.calendar_month_outlined,
                      label: 'My Bookings',
                      onTap: () => context.push('/reservations'),
                    ),
                    _MenuItem(
                      icon: Icons.offline_pin_outlined,
                      label: 'Offline Maps',
                      onTap: () => context.push('/offline-maps'),
                    ),
                    _MenuItem(
                      icon: Icons.storefront_outlined,
                      label: 'Apply for Business / Partner Access',
                      onTap: () => context.push('/applications'),
                    ),
                  ],
                ).animate().fadeIn(duration: 350.ms, delay: 100.ms),
                const SizedBox(height: 18),
                _MenuSection(
                  title: 'Preferences',
                  items: [
                    _MenuItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () => context.goNamed(RouteNames.settings),
                    ),
                    _MenuItem(
                      icon: Icons.language_rounded,
                      label: 'Language',
                      value: 'English',
                      onTap: () => _showLanguageDialog(context),
                    ),
                  ],
                ).animate().fadeIn(duration: 350.ms, delay: 200.ms),
                const SizedBox(height: 18),
                _MenuSection(
                  title: 'Support & Information',
                  items: [
                    _MenuItem(
                      icon: Icons.info_outline_rounded,
                      label: 'About Tubigon',
                      onTap: () => _showAboutDialog(context),
                    ),
                    _MenuItem(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support',
                      onTap: () => _showHelpDialog(context),
                    ),
                    _MenuItem(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy Policy',
                      onTap: () => _showPrivacyDialog(context),
                    ),
                    _MenuItem(
                      icon: Icons.logout_rounded,
                      label: 'Sign Out',
                      labelColor: const Color(0xFFF87171),
                      iconColor: const Color(0xFFF87171),
                      onTap: () => _confirmSignOut(context, ref),
                    ),
                  ],
                ).animate().fadeIn(duration: 350.ms, delay: 300.ms),
                const SizedBox(height: 32),
                const Center(
                  child: Text(
                    'Tubigon Smart Tourism v1.0.0',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              ctx.pop();
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go('/onboarding?page=5&login=true');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF87171),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign Out',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(
      BuildContext context, WidgetRef ref) async {
    final currentController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmationController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var submitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentController,
                    enabled: !submitting,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Current password'),
                    validator: (value) => value?.isEmpty == true
                        ? 'Enter your current password.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    enabled: !submitting,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'New password'),
                    validator: (value) => (value?.length ?? 0) < 8
                        ? 'Use at least 8 characters.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmationController,
                    enabled: !submitting,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Confirm password'),
                    validator: (value) => value != passwordController.text
                        ? 'Passwords do not match.'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => dialogContext.pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() != true) return;
                      setDialogState(() => submitting = true);
                      try {
                        await ref.read(authProvider.notifier).changePassword(
                              currentPassword: currentController.text,
                              newPassword: passwordController.text,
                            );
                        if (!dialogContext.mounted) return;
                        dialogContext.pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password updated successfully.'),
                            ),
                          );
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(error
                                  .toString()
                                  .replaceFirst('Exception: ', '')),
                            ),
                          );
                          setDialogState(() => submitting = false);
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );

    currentController.dispose();
    passwordController.dispose();
    confirmationController.dispose();
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Select Language',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title:
                  const Text('English', style: TextStyle(color: Colors.white)),
              trailing:
                  const Icon(Icons.check_rounded, color: Color(0xFFF59E0B)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              title: const Text('Cebuano (Bisaya)',
                  style: TextStyle(color: Color(0xFF94A3B8))),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Cebuano localization is not available in this version.')),
                );
              },
            ),
            ListTile(
              title: const Text('Filipino (Tagalog)',
                  style: TextStyle(color: Color(0xFF94A3B8))),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Filipino localization is not available in this version.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('About Tubigon Smart Tourism',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            'Tubigon is a major seaport town and gateway to Bohol, Philippines. Known for its rich loomweaving heritage, coastal ecosystems, and eco-tourism destinations.\n\n'
            'The Tubigon Smart Tourism System connects tourists with verified destinations, local MSME businesses, ferry schedules, eco guidelines, and emergency services.\n\n'
            'Version 1.0.0 (Official Tourist Module)',
            style:
                TextStyle(color: Color(0xFFCBD5E1), height: 1.5, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Close', style: TextStyle(color: Color(0xFFF59E0B))),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Help & Support',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            'FAQ & Support:\n\n'
            '• How do I make a booking?\n'
            'Browse Explore or spots, tap "Book Now" and choose your date & guests.\n\n'
            '• How do I access offline mode?\n'
            'All destinations, bookings, and ferry schedules are automatically cached via SQLite for offline viewing.\n\n'
            'Contact: support@tubigontourism.gov.ph',
            style:
                TextStyle(color: Color(0xFFCBD5E1), height: 1.5, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Close', style: TextStyle(color: Color(0xFFF59E0B))),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Privacy Policy',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            'We value your privacy. All user profile data, offline caches, and preferences are stored securely. Location services are only requested for map centering.',
            style:
                TextStyle(color: Color(0xFFCBD5E1), height: 1.5, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Close', style: TextStyle(color: Color(0xFFF59E0B))),
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.items});

  final String title;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: items.asMap().entries.map((e) {
                final item = e.value;
                final isLast = e.key == items.length - 1;
                return Column(
                  children: [
                    item,
                    if (!isLast)
                      const Divider(
                          color: Color(0xFF1E293B), height: 1, indent: 56),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.labelColor,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;
  final Color? labelColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: (iconColor ?? const Color(0xFFF59E0B)).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child:
            Icon(icon, size: 20, color: iconColor ?? const Color(0xFFF59E0B)),
      ),
      title: Text(
        label,
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: labelColor ?? Colors.white),
      ),
      trailing: value != null
          ? Text(value!,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))
          : const Icon(Icons.chevron_right_rounded,
              size: 20, color: Color(0xFF64748B)),
    );
  }
}
