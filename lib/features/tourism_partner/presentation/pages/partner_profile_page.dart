import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerProfilePage extends ConsumerStatefulWidget {
  const PartnerProfilePage({super.key});
  @override
  ConsumerState<PartnerProfilePage> createState() => _State();
}

class _State extends ConsumerState<PartnerProfilePage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _bio = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(partnerProfileProvider);
    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
              child: OutlinedButton(
            onPressed: () => ref.invalidate(partnerProfileProvider),
            child: Text('Retry: $error'),
          )),
          data: (data) {
            if (!_initialized) {
              _name.text = data['name']?.toString() ?? '';
              _phone.text = data['phone']?.toString() ?? '';
              _bio.text = data['bio']?.toString() ?? '';
              _initialized = true;
            }
            return ListView(children: [
              Text('Partner Profile', style: PartnerTheme.headingLarge()),
              Text(
                  'This updates the owner profile. Listing business details remain on each listing.',
                  style: PartnerTheme.label()),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: PartnerTheme.cardDecoration(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account email', style: PartnerTheme.label()),
                      Text(data['email']?.toString() ?? '',
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 10),
                      Text('Role', style: PartnerTheme.label()),
                      const Text('Tourism Partner',
                          style: TextStyle(color: Colors.white)),
                      if ((data['managed_destinations'] as List? ?? const [])
                          .isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('Managed destination',
                            style: PartnerTheme.label()),
                        Text(
                          (data['managed_destinations'] as List)
                              .whereType<Map>()
                              .map((spot) => spot['name']?.toString() ?? '')
                              .where((name) => name.isNotEmpty)
                              .join(', '),
                          style: const TextStyle(
                              color: PartnerTheme.primaryOrange,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                          controller: _name,
                          decoration:
                              const InputDecoration(labelText: 'Display name')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _phone,
                          decoration:
                              const InputDecoration(labelText: 'Phone')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _bio,
                          maxLines: 4,
                          decoration:
                              const InputDecoration(labelText: 'About')),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 15,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_rounded),
                        label: const Text('Save profile'),
                      ),
                    ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(tourismPartnerRepositoryProvider).updateProfile({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'bio': _bio.text.trim(),
      });
      _initialized = false;
      ref.invalidate(partnerProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              backgroundColor: PartnerTheme.green,
              content: Text('Profile saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: PartnerTheme.red,
              content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
