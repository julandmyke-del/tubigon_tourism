import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/utils/auth_action_guard.dart';
import '../../../authentication/auth_provider.dart';
import '../../../profile/repositories/profile_repository.dart';
import '../../../tourist_spots/repositories/tourist_spot_repository.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _barangay;
  late final TextEditingController _bio;
  late final TextEditingController _accessibilityNotes;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _loaded = false;
  String? _avatarUrl;
  String _language = 'en';
  String? _pace;
  String? _group;
  String? _transport;
  final Set<String> _categoryIds = {};
  final Set<String> _interests = {};
  final Map<String, bool> _toggles = {
    'personalization_enabled': false,
    'eco_tourism_interest': false,
    'nearby_suggestions': false,
    'wheelchair_friendly': false,
    'limited_walking': false,
    'senior_friendly': false,
    'child_friendly': false,
    'reservation_updates': true,
    'tourism_announcements': true,
    'eco_tips': true,
    'ferry_alerts': true,
    'waste_report_updates': true,
    'application_updates': true,
    'location_recommendations': false,
    'remember_last_map_location': false,
  };

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    _name = TextEditingController(text: auth.name ?? '');
    _email = TextEditingController(text: auth.email ?? '');
    _phone = TextEditingController();
    _address = TextEditingController();
    _barangay = TextEditingController();
    _bio = TextEditingController();
    _accessibilityNotes = TextEditingController();
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _phone,
      _address,
      _barangay,
      _bio,
      _accessibilityNotes
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _load(Map<String, dynamic> data) {
    if (_loaded || data.isEmpty) return;
    _loaded = true;
    _name.text = data['name']?.toString() ?? _name.text;
    _email.text = data['email']?.toString() ?? _email.text;
    _phone.text = data['phone']?.toString() ?? '';
    _address.text = data['address']?.toString() ?? '';
    _barangay.text = data['barangay']?.toString() ?? '';
    _bio.text = data['bio']?.toString() ?? '';
    _avatarUrl = data['avatar_url']?.toString();
    _language = data['language']?.toString() == 'ceb' ? 'ceb' : 'en';
    final preferences = data['preferences'] is Map
        ? Map<String, dynamic>.from(data['preferences'])
        : const <String, dynamic>{};
    for (final key in _toggles.keys) {
      if (preferences[key] is bool) _toggles[key] = preferences[key] as bool;
    }
    _pace = preferences['travel_pace']?.toString();
    _group = preferences['group_type']?.toString();
    _transport = preferences['preferred_transport_mode']?.toString();
    _categoryIds.addAll(
        (preferences['preferred_destination_category_ids'] as List? ?? const [])
            .map((e) => e.toString()));
    _interests.addAll((preferences['travel_interests'] as List? ?? const [])
        .map((e) => e.toString()));
    _accessibilityNotes.text =
        preferences['accessibility_notes']?.toString() ?? '';
  }

  Map<String, dynamic> get _preferences => {
        ..._toggles,
        'preferred_destination_category_ids': _categoryIds.toList(),
        'travel_interests': _interests.toList(),
        'travel_pace': _pace,
        'group_type': _group,
        'preferred_transport_mode': _transport,
        'accessibility_notes': _accessibilityNotes.text.trim().isEmpty
            ? null
            : _accessibilityNotes.text.trim(),
      };

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final id = ref.read(authProvider).userId;
    if (id == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            id,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            address: _address.text.trim(),
            barangay: _barangay.text.trim(),
            bio: _bio.text.trim(),
            language: _language,
            preferences: _preferences,
          );
      await ref.read(authProvider.notifier).reloadProfile();
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text('Profile and preferences saved.')));
      context.pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadAvatar() async {
    final id = ref.read(authProvider).userId;
    if (id == null || _uploadingAvatar) return;
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 88,
    );
    if (image == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final url = await ref.read(profileRepositoryProvider).uploadAvatar(
            id,
            await image.readAsBytes(),
            image.name,
          );
      await ref.read(authProvider.notifier).reloadProfile();
      ref.invalidate(currentProfileProvider);
      if (mounted) setState(() => _avatarUrl = url);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to upload avatar: $error')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
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
      if (!_loaded && data.isNotEmpty) {
        _load(data);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    });
    final categories =
        ref.watch(spotCategoriesProvider).valueOrNull ?? const [];
    final role = profile.valueOrNull?['role']?.toString() ?? 'tourist';
    final linkedMsmes =
        profile.valueOrNull?['linked_msmes'] as List? ?? const [];
    final linkedSpots =
        profile.valueOrNull?['linked_tourist_spots'] as List? ?? const [];

    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Profile & Preferences'),
        actions: [
          TextButton(
              onPressed: _saving ? null : _save, child: const Text('SAVE'))
        ],
      ),
      body: profile.isLoading && !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                Center(
                    child: Stack(clipBehavior: Clip.none, children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFF1E293B),
                    backgroundImage: _avatarUrl?.isNotEmpty == true
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: _avatarUrl?.isNotEmpty == true
                        ? null
                        : const Icon(Icons.person_rounded,
                            color: Colors.white, size: 52),
                  ),
                  Positioned(
                      right: -4,
                      bottom: -4,
                      child: IconButton.filled(
                        tooltip: 'Upload profile photo',
                        onPressed: _uploadingAvatar ? null : _uploadAvatar,
                        icon: _uploadingAvatar
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.photo_camera_outlined),
                      )),
                ])),
                const SizedBox(height: 16),
                const Text('Basic information', style: _heading),
                const SizedBox(height: 12),
                _field(_name, 'Full name', Icons.person_outline,
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter at least 2 characters.'
                        : null),
                _field(_email, 'Email address', Icons.email_outlined,
                    enabled: false),
                _field(_phone, 'Phone number', Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) => value != null &&
                            value.isNotEmpty &&
                            !RegExp(r'^[0-9+()\-\s]{7,30}$').hasMatch(value)
                        ? 'Enter a valid phone number.'
                        : null),
                _field(_address, 'Address', Icons.home_outlined, maxLines: 2),
                _field(_barangay, 'Barangay', Icons.location_city_outlined),
                _field(_bio, 'Bio', Icons.notes_rounded,
                    maxLines: 3,
                    validator: (value) => (value?.length ?? 0) > 2000
                        ? 'Bio must be 2,000 characters or fewer.'
                        : null),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  decoration: const InputDecoration(
                      labelText: 'Language', prefixIcon: Icon(Icons.language)),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'ceb', child: Text('Cebuano'))
                  ],
                  onChanged: (value) =>
                      setState(() => _language = value ?? 'en'),
                ),
                const SizedBox(height: 22),
                if (role == 'msme_owner' || role == 'tourism_partner')
                  _roleCard(role, linkedMsmes, linkedSpots),
                _section(
                    'Personalization',
                    'Optional choices used only when personalization is enabled',
                    [
                      _toggle(
                          'Enable personalization', 'personalization_enabled'),
                      if (_toggles['personalization_enabled'] == true) ...[
                        const Text('Preferred destination categories',
                            style: _subheading),
                        Wrap(
                            spacing: 8,
                            children: categories
                                .map((category) => FilterChip(
                                      label: Text(category.name),
                                      selected:
                                          _categoryIds.contains(category.uuid),
                                      onSelected: (selected) => setState(() =>
                                          selected
                                              ? _categoryIds.add(category.uuid)
                                              : _categoryIds
                                                  .remove(category.uuid)),
                                    ))
                                .toList()),
                        const SizedBox(height: 12),
                        const Text('Travel interests', style: _subheading),
                        Wrap(
                            spacing: 8,
                            children: [
                              'beaches',
                              'heritage',
                              'nature',
                              'food',
                              'adventure',
                              'culture',
                              'shopping',
                              'wellness'
                            ]
                                .map((interest) => FilterChip(
                                    label: Text(interest),
                                    selected: _interests.contains(interest),
                                    onSelected: (selected) => setState(() =>
                                        selected
                                            ? _interests.add(interest)
                                            : _interests.remove(interest))))
                                .toList()),
                        _choice(
                            'Travel pace',
                            _pace,
                            ['relaxed', 'balanced', 'packed'],
                            (value) => _pace = value),
                        _choice(
                            'Group type',
                            _group,
                            ['solo', 'couple', 'family', 'friends', 'business'],
                            (value) => _group = value),
                        _choice(
                            'Preferred transport',
                            _transport,
                            [
                              'walking',
                              'bicycle',
                              'motorcycle',
                              'car',
                              'public_transport',
                              'boat',
                              'mixed'
                            ],
                            (value) => _transport = value),
                        _toggle('Eco-tourism recommendations',
                            'eco_tourism_interest'),
                        _toggle('Nearby suggestions', 'nearby_suggestions'),
                      ],
                    ]),
                _section(
                    'Accessibility',
                    'Explicit preferences only; Tour Tubigon does not infer disability information',
                    [
                      _toggle(
                          'Wheelchair-friendly options', 'wheelchair_friendly'),
                      _toggle('Limit walking', 'limited_walking'),
                      _toggle('Senior-friendly options', 'senior_friendly'),
                      _toggle('Child-friendly options', 'child_friendly'),
                      _field(_accessibilityNotes,
                          'Optional accessibility notes', Icons.accessible,
                          maxLines: 2),
                    ]),
                _section(
                    'Notifications',
                    'Security and account-protection messages are always delivered when required',
                    [
                      _toggle('Reservation updates', 'reservation_updates'),
                      _toggle('Tourism announcements', 'tourism_announcements'),
                      _toggle('Eco tips', 'eco_tips'),
                      _toggle('Ferry alerts', 'ferry_alerts'),
                      _toggle('Waste report updates', 'waste_report_updates'),
                      _toggle(
                          'Role application updates', 'application_updates'),
                    ]),
                _section(
                    'Privacy',
                    'Location-based choices are off by default and can be changed anytime',
                    [
                      _toggle('Location-based recommendations',
                          'location_recommendations'),
                      _toggle('Remember last map location',
                          'remember_last_map_location'),
                    ]),
                const SizedBox(height: 18),
                FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: Text(
                        _saving ? 'Saving…' : 'Save profile & preferences')),
                const SizedBox(height: 12),
                const Text(
                    'Password, privacy policy, support, and sign-out controls remain available on the main Profile page.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ]),
            ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon,
          {bool enabled = true,
          int maxLines = 1,
          TextInputType? keyboardType,
          String? Function(String?)? validator}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            maxLines: maxLines,
            keyboardType: keyboardType,
            validator: validator,
            decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14))),
          ));

  Widget _toggle(String title, String key) => SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      value: _toggles[key] ?? false,
      onChanged: (value) => setState(() => _toggles[key] = value));

  Widget _choice(String label, String? value, List<String> values,
          ValueChanged<String?> onChanged) =>
      Padding(
          padding: const EdgeInsets.only(top: 10),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(labelText: label),
            items: values
                .map((item) => DropdownMenuItem(
                    value: item, child: Text(item.replaceAll('_', ' '))))
                .toList(),
            onChanged: (next) => setState(() => onChanged(next)),
          ));

  Widget _section(String title, String subtitle, List<Widget> children) => Card(
      margin: const EdgeInsets.only(top: 16),
      color: const Color(0xFF0F172A),
      child: ExpansionTile(
          initiallyExpanded: title == 'Personalization',
          title: Text(title, style: _heading),
          subtitle: Text(subtitle),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: children));

  Widget _roleCard(String role, List<dynamic> msmes, List<dynamic> spots) {
    final names = role == 'msme_owner' ? msmes : spots;
    return Card(
        color: const Color(0xFF172554),
        child: ListTile(
          leading:
              Icon(role == 'msme_owner' ? Icons.storefront : Icons.landscape),
          title: Text(role == 'msme_owner'
              ? 'Linked business'
              : 'Assigned destination'),
          subtitle: Text(names.isEmpty
              ? 'No authoritative record is linked yet.'
              : names.whereType<Map>().map((item) => item['name']).join(', ')),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => context
              .go(role == 'msme_owner' ? '/msme-portal' : '/tourism-partner'),
        ));
  }
}

const _heading =
    TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700);
const _subheading = TextStyle(color: Colors.white, fontWeight: FontWeight.w600);
