import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../authentication/auth_provider.dart';
import '../../../profile/repositories/profile_repository.dart';
import '../../../../core/utils/auth_action_guard.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _bioCtrl;
  bool _isSaving = false;
  bool _loadedRemoteProfile = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _nameCtrl = TextEditingController(text: user.name ?? '');
    _emailCtrl = TextEditingController(text: user.email ?? '');
    _phoneCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid full name.')),
      );
      return;
    }
    final auth = ref.read(authProvider);
    if (auth.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to update your profile.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            auth.userId!,
            name: name,
            phone: _phoneCtrl.text.trim(),
            bio: _bioCtrl.text.trim(),
          );
      await ref.read(authProvider.notifier).reloadProfile();
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Color(0xFF10B981),
        content: Text('Profile updated successfully!'),
      ));
      context.pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update profile: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isLoggedIn || auth.userId == null) {
      return signedInRequiredPage(context, ref, title: 'Edit Profile');
    }
    final profile = ref.watch(currentProfileProvider);
    profile.whenData((data) {
      if (_loadedRemoteProfile || data.isEmpty) return;
      _loadedRemoteProfile = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _nameCtrl.text = data['name']?.toString() ?? _nameCtrl.text;
        _emailCtrl.text = data['email']?.toString() ?? _emailCtrl.text;
        _phoneCtrl.text = data['phone']?.toString() ?? '';
        _bioCtrl.text = data['bio']?.toString() ?? '';
        setState(() {});
      });
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
          'Edit Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFF59E0B), width: 3),
                ),
                child: const CircleAvatar(
                  radius: 48,
                  backgroundColor: Color(0xFF1E293B),
                  child:
                      Icon(Icons.person_rounded, color: Colors.white, size: 52),
                ),
              ),
            ),

            const SizedBox(height: 28),

            _EditField(
                label: 'Full Name',
                controller: _nameCtrl,
                icon: Icons.person_outline_rounded),
            const SizedBox(height: 16),
            _EditField(
                label: 'Email Address',
                controller: _emailCtrl,
                icon: Icons.email_outlined,
                enabled: false),
            const SizedBox(height: 16),
            _EditField(
                label: 'Phone Number',
                controller: _phoneCtrl,
                icon: Icons.phone_outlined),
            const SizedBox(height: 16),
            _EditField(
                label: 'Bio',
                controller: _bioCtrl,
                icon: Icons.notes_rounded,
                maxLines: 3),

            const SizedBox(height: 36),

            ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2))
                  : const Text('Save Changes',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.controller,
    required this.icon,
    this.enabled = true,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool enabled;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          style: TextStyle(color: enabled ? Colors.white : Colors.white54),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
          ),
        ),
      ],
    );
  }
}
