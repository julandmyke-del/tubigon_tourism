import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme_provider.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../settings/repositories/settings_repository.dart';
import '../../../../core/utils/auth_action_guard.dart';
import '../../../authentication/auth_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _offlineSyncEnabled = true;
  bool _locationEnabled = true;
  bool _loadedSettings = false;
  final Set<String> _savingSettings = {};

  Future<void> _updateSetting(String key, bool value, bool previous) async {
    if (_savingSettings.contains(key)) return;
    setState(() {
      _savingSettings.add(key);
      _setLocalSetting(key, value);
    });
    try {
      final saved = await ref
          .read(settingsRepositoryProvider)
          .updateSettings({key: value});
      if (!mounted) return;
      setState(
          () => _setLocalSetting(key, saved[key] == true || saved[key] == 1));
      ref.invalidate(touristSettingsProvider);
    } catch (error) {
      if (!mounted) return;
      setState(() => _setLocalSetting(key, previous));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save setting: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingSettings.remove(key));
    }
  }

  void _setLocalSetting(String key, bool value) {
    switch (key) {
      case 'notifications_enabled':
        _notificationsEnabled = value;
      case 'offline_mode':
        _offlineSyncEnabled = value;
      case 'location_enabled':
        _locationEnabled = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isLoggedIn || auth.userId == null) {
      return signedInRequiredPage(context, ref, title: 'Settings');
    }
    final themeModeAsync = ref.watch(themeModeProvider);
    final isDarkMode = themeModeAsync.valueOrNull == ThemeMode.dark;
    final settings = ref.watch(touristSettingsProvider);
    final connectivity = ref.watch(connectivityProvider);
    final online = connectivity.valueOrNull == ConnectivityStatus.online;
    settings.whenData((data) {
      if (_loadedSettings) return;
      _loadedSettings = true;
      _notificationsEnabled = data['notifications_enabled'] != false &&
          data['notifications_enabled'] != 0;
      _offlineSyncEnabled =
          data['offline_mode'] == true || data['offline_mode'] == 1;
      _locationEnabled =
          data['location_enabled'] != false && data['location_enabled'] != 0;
    });

    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'APPEARANCE & DISPLAY',
            style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                title: const Text('Dark Navy Theme',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                subtitle: const Text('Use high-contrast dark theme',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                secondary: const Icon(Icons.dark_mode_rounded,
                    color: Color(0xFFF59E0B)),
                activeThumbColor: const Color(0xFFF59E0B),
                value: isDarkMode,
                onChanged: (val) {
                  ref.read(themeModeProvider.notifier).toggleTheme();
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'SYSTEM & SYNC',
            style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Push Notifications',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    subtitle: const Text('Booking updates & travel advisories',
                        style:
                            TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    secondary: const Icon(Icons.notifications_active_rounded,
                        color: Color(0xFF38BDF8)),
                    activeThumbColor: const Color(0xFF38BDF8),
                    value: _notificationsEnabled,
                    onChanged: _savingSettings.contains('notifications_enabled')
                        ? null
                        : (val) => _updateSetting('notifications_enabled', val,
                            _notificationsEnabled),
                  ),
                  const Divider(
                      color: Color(0xFF1E293B), height: 1, indent: 56),
                  SwitchListTile(
                    title: const Text('SQLite Offline Cache',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    subtitle: const Text('Auto-sync spots and bookings locally',
                        style:
                            TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    secondary: const Icon(Icons.sync_rounded,
                        color: Color(0xFF34D399)),
                    activeThumbColor: const Color(0xFF34D399),
                    value: _offlineSyncEnabled,
                    onChanged: _savingSettings.contains('offline_mode')
                        ? null
                        : (val) => _updateSetting(
                            'offline_mode', val, _offlineSyncEnabled),
                  ),
                  const Divider(
                      color: Color(0xFF1E293B), height: 1, indent: 56),
                  SwitchListTile(
                    title: const Text('Location Services',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    subtitle: const Text(
                        'Allow map centering and nearby places',
                        style:
                            TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    secondary: const Icon(Icons.location_on_rounded,
                        color: Color(0xFFF59E0B)),
                    activeThumbColor: const Color(0xFFF59E0B),
                    value: _locationEnabled,
                    onChanged: _savingSettings.contains('location_enabled')
                        ? null
                        : (val) => _updateSetting(
                            'location_enabled', val, _locationEnabled),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'ABOUT APPLICATION',
            style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.info_outline_rounded,
                        color: Color(0xFFF59E0B)),
                    title: Text('Application Version',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    trailing: Text('1.0.0 (Build 1)',
                        style:
                            TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ),
                  const Divider(
                      color: Color(0xFF1E293B), height: 1, indent: 56),
                  ListTile(
                    leading: Icon(
                        online
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_off_rounded,
                        color: online
                            ? const Color(0xFF34D399)
                            : const Color(0xFFF59E0B)),
                    title: const Text('Connection Status',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    trailing: Text(online ? 'Online' : 'Offline',
                        style: TextStyle(
                            color: online
                                ? const Color(0xFF34D399)
                                : const Color(0xFFF59E0B),
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
