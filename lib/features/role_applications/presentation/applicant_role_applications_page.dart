import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../tourist_spots/repositories/tourist_spot_repository.dart';
import '../models/role_application.dart';
import '../providers/role_application_providers.dart';

class ApplicantRoleApplicationsPage extends ConsumerStatefulWidget {
  const ApplicantRoleApplicationsPage({super.key, this.initialApplicationId});
  final String? initialApplicationId;

  @override
  ConsumerState<ApplicantRoleApplicationsPage> createState() =>
      _ApplicantRoleApplicationsPageState();
}

class _ApplicantRoleApplicationsPageState
    extends ConsumerState<ApplicantRoleApplicationsPage> {
  bool _openedInitial = false;

  @override
  Widget build(BuildContext context) {
    final applications = ref.watch(myRoleApplicationsProvider);
    final options = ref.watch(roleApplicationOptionsProvider);
    final width = MediaQuery.sizeOf(context).width;

    applications.whenData((items) {
      if (_openedInitial || widget.initialApplicationId == null) return;
      final matches =
          items.where((item) => item.id == widget.initialApplicationId);
      if (matches.isEmpty) return;
      _openedInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openWizard(matches.first);
      });
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101B34),
        title: const Text('Business & Partner Access'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myRoleApplicationsProvider.future),
        child: ListView(
          padding: EdgeInsets.symmetric(
              horizontal: width > 900 ? (width - 900) / 2 : 18, vertical: 24),
          children: [
            const Text('Apply using your existing account',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'LGU Staff verifies legitimacy and operations. Admin performs final access approval. Applying never grants a privileged role by itself.',
              style: TextStyle(color: Color(0xFF94A3B8), height: 1.5),
            ),
            const SizedBox(height: 22),
            options.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _ErrorCard(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(roleApplicationOptionsProvider)),
              data: (data) => LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth >= 650;
                final cards = [
                  _AccessCard(
                    icon: Icons.storefront_rounded,
                    title: 'Apply as MSME Owner',
                    description:
                        'Register one real Tubigon business for LGU verification.',
                    enabled: data['msme_applications_enabled'] == true &&
                        data['eligible']?['msme_owner'] == true,
                    onTap: () => _start('msme_owner'),
                  ),
                  _AccessCard(
                    icon: Icons.handshake_rounded,
                    title: 'Apply as Tourism Partner',
                    description:
                        'Request management access to an existing Tourist Spot.',
                    enabled: data['partner_applications_enabled'] == true &&
                        data['eligible']?['tourism_partner'] == true,
                    onTap: () => _start('tourism_partner'),
                  ),
                ];
                return wide
                    ? Row(children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 14),
                        Expanded(child: cards[1])
                      ])
                    : Column(children: [
                        cards[0],
                        const SizedBox(height: 12),
                        cards[1]
                      ]);
              }),
            ),
            const SizedBox(height: 28),
            const Text('My applications',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            applications.when(
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.all(36),
                      child: CircularProgressIndicator())),
              error: (error, _) => _ErrorCard(
                  error: error,
                  onRetry: () => ref.invalidate(myRoleApplicationsProvider)),
              data: (items) => items.isEmpty
                  ? const _EmptyApplications()
                  : Column(
                      children: items
                          .map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ApplicationCard(
                                  application: item,
                                  onOpen: () => _openWizard(item),
                                  onWithdraw: item.withdrawable
                                      ? () => _withdraw(item)
                                      : null,
                                ),
                              ))
                          .toList()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _start(String type) async {
    final repository = ref.read(roleApplicationRepositoryProvider);
    try {
      final application = await repository.create(type);
      if (!mounted) return;
      ref.invalidate(myRoleApplicationsProvider);
      await _openWizard(application);
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  Future<void> _openWizard(RoleApplication application) async {
    if (!application.editable) {
      await showDialog<void>(
          context: context,
          builder: (_) => _StatusDialog(application: application));
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog.fullscreen(
          child: RoleApplicationWizard(application: application)),
    );
    if (!mounted) return;
    ref.invalidate(myRoleApplicationsProvider);
  }

  Future<void> _withdraw(RoleApplication application) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Withdraw application?'),
              content: const Text(
                  'The application history will be retained. You can start a new application later.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Withdraw'))
              ],
            ));
    if (confirmed != true || !mounted) return;
    final repository = ref.read(roleApplicationRepositoryProvider);
    try {
      await repository.withdraw(application.id);
      if (!mounted) return;
      ref.invalidate(myRoleApplicationsProvider);
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  void _message(Object error) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', ''))));
}

class RoleApplicationWizard extends ConsumerStatefulWidget {
  const RoleApplicationWizard({super.key, required this.application});
  final RoleApplication application;

  @override
  ConsumerState<RoleApplicationWizard> createState() =>
      _RoleApplicationWizardState();
}

class _RoleApplicationWizardState extends ConsumerState<RoleApplicationWizard> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  int _step = 0;
  bool _busy = false;
  bool _declared = false;
  String? _category;
  String? _spotId;

  bool get _msme => widget.application.type == 'msme_owner';

  @override
  void initState() {
    super.initState();
    final p = widget.application.payload;
    _controllers = {
      for (final key in [
        'applicant_contact',
        'business_name',
        'business_address',
        'business_phone',
        'business_description',
        'latitude',
        'longitude',
        'organization',
        'contact_phone',
        'relationship',
        'reason',
        'supporting_evidence',
      ])
        key: TextEditingController(text: p[key]?.toString() ?? ''),
    };
    _category = p['business_category']?.toString();
    _spotId = widget.application.requestedSpot?['id']?.toString();
    _declared = p['declaration'] == true;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options =
        ref.watch(roleApplicationOptionsProvider).valueOrNull ?? const {};
    final spots = ref.watch(touristSpotsListProvider).valueOrNull ?? const [];
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101B34),
        title: Text('${widget.application.typeLabel} application'),
        leading: IconButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close)),
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _step,
          onStepTapped: (value) => setState(() => _step = value),
          controlsBuilder: (_, __) => const SizedBox.shrink(),
          steps: [
            Step(
                title: const Text('Applicant Information'),
                isActive: _step >= 0,
                content: _field('applicant_contact', 'Contact information',
                    required: true)),
            Step(
                title: Text(_msme
                    ? 'Business Information'
                    : 'Organization & Relationship'),
                isActive: _step >= 1,
                content: _businessStep(options)),
            Step(
                title: Text(_msme ? 'Location' : 'Requested Tourist Spot'),
                isActive: _step >= 2,
                content: _locationStep(spots)),
            Step(
                title: const Text('Supporting Evidence'),
                isActive: _step >= 3,
                content: _field('supporting_evidence',
                    'Permit/proof reference or evidence notes',
                    lines: 5)),
            Step(
                title: const Text('Review & Submit'),
                isActive: _step >= 4,
                content: _reviewStep()),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
          child: Container(
        color: const Color(0xFF101B34),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          if (_step > 0)
            OutlinedButton(
                onPressed: _busy ? null : () => setState(() => _step--),
                child: const Text('Back')),
          const Spacer(),
          TextButton(
              onPressed: _busy ? null : _saveDraft,
              child: const Text('Save Draft')),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _busy
                ? null
                : (_step < 4 ? () => setState(() => _step++) : _submit),
            child: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_step < 4 ? 'Next' : 'Submit Application'),
          ),
        ]),
      )),
    );
  }

  Widget _businessStep(Map<String, dynamic> options) => Column(
      children: _msme
          ? [
              _field('business_name', 'Business name', required: true),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration:
                    const InputDecoration(labelText: 'Business category'),
                items: (options['msme_categories'] as List? ?? const [])
                    .map((value) => DropdownMenuItem(
                        value: value.toString(), child: Text(value.toString())))
                    .toList(),
                onChanged: (value) => _category = value,
                validator: (value) =>
                    value == null ? 'Select a category.' : null,
              ),
              const SizedBox(height: 12),
              _field('business_address', 'Business address',
                  required: true, lines: 2),
              const SizedBox(height: 12),
              _field('business_phone', 'Business contact number',
                  required: true),
              const SizedBox(height: 12),
              _field('business_description', 'Business description',
                  required: true, lines: 4),
            ]
          : [
              _field('organization', 'Organization or group', required: true),
              const SizedBox(height: 12),
              _field('contact_phone', 'Contact number', required: true),
              const SizedBox(height: 12),
              _field('relationship', 'Relationship to the destination',
                  required: true, lines: 4),
            ]);

  Widget _locationStep(List<dynamic> spots) => _msme
      ? Column(children: [
          Row(children: [
            Expanded(
                child: _field('latitude', 'Latitude',
                    required: true, number: true)),
            const SizedBox(width: 10),
            Expanded(
                child: _field('longitude', 'Longitude',
                    required: true, number: true))
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map_rounded),
              label: const Text('Choose exact location on Smart Map')),
          const SizedBox(height: 8),
          const Text(
              'Coordinates must fall within the validated Tubigon municipal boundary.',
              style: TextStyle(color: Color(0xFF94A3B8))),
        ])
      : DropdownButtonFormField<String>(
          initialValue: _spotId,
          isExpanded: true,
          decoration:
              const InputDecoration(labelText: 'Requested Tourist Spot'),
          items: spots
              .map((spot) => DropdownMenuItem<String>(
                  value: spot.uuid as String, child: Text(spot.name as String)))
              .toList(),
          onChanged: (value) => setState(() => _spotId = value),
          validator: (value) =>
              value == null ? 'Select an existing Tourist Spot.' : null,
        );

  Widget _reviewStep() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _field('reason', 'Why are you requesting this access?',
            required: true, lines: 4),
        const SizedBox(height: 14),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _declared,
          onChanged: (value) => setState(() => _declared = value ?? false),
          title: const Text(
              'I declare that this information is accurate and I am authorized to make this request.'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        const Text(
            'Submission sends this same record to LGU review. Your account role remains Tourist until final Admin approval.',
            style: TextStyle(color: Color(0xFF94A3B8), height: 1.4)),
      ]);

  Widget _field(String key, String label,
          {bool required = false, int lines = 1, bool number = false}) =>
      TextFormField(
        controller: _controllers[key],
        maxLines: lines,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) =>
                value?.trim().isEmpty == true ? '$label is required.' : null
            : null,
      );

  Map<String, dynamic> _payload() {
    final data = <String, dynamic>{};
    for (final entry in _controllers.entries) {
      if (entry.value.text.trim().isNotEmpty) {
        data[entry.key] = entry.value.text.trim();
      }
    }
    if (_msme && _category != null) {
      data['business_category'] = _category;
    }
    if (!_msme && _spotId != null) {
      data['requested_tourist_spot_id'] = _spotId;
    }
    data['declaration'] = _declared;
    return data;
  }

  Future<void> _pickLocation() async {
    final result = await context.push<Object?>(
        '/map/pick?mode=place&lat=${_controllers['latitude']!.text}&lng=${_controllers['longitude']!.text}');
    if (!mounted || result is! Map) return;
    setState(() {
      _controllers['latitude']!.text = result['latitude']?.toString() ?? '';
      _controllers['longitude']!.text = result['longitude']?.toString() ?? '';
    });
  }

  Future<void> _saveDraft() async => _persist(submit: false);

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true || !_declared) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Complete the required fields and declaration before submitting.')));
      return;
    }
    await _persist(submit: true);
  }

  Future<void> _persist({required bool submit}) async {
    final repository = ref.read(roleApplicationRepositoryProvider);
    setState(() => _busy = true);
    try {
      if (submit) {
        await repository.submit(widget.application.id, _payload());
      } else {
        await repository.save(widget.application.id, _payload());
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard(
      {required this.icon,
      required this.title,
      required this.description,
      required this.enabled,
      required this.onTap});
  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF17223D),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon,
                        color: enabled
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF64748B),
                        size: 30),
                    const SizedBox(height: 12),
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17)),
                    const SizedBox(height: 6),
                    Text(
                        enabled
                            ? description
                            : 'Not currently available for this account.',
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), height: 1.4)),
                  ])),
        ),
      );
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard(
      {required this.application, required this.onOpen, this.onWithdraw});
  final RoleApplication application;
  final VoidCallback onOpen;
  final VoidCallback? onWithdraw;
  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF17223D),
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: CircleAvatar(
              backgroundColor: const Color(0xFFF59E0B).withValues(alpha: .16),
              child: Icon(
                  application.type == 'msme_owner'
                      ? Icons.storefront
                      : Icons.handshake,
                  color: const Color(0xFFF59E0B))),
          title: Text('${application.typeLabel} application',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${application.status.replaceAll('_', ' ')} • Updated ${application.updatedAt?.toLocal().toString().split('.').first ?? 'recently'}',
              style: const TextStyle(color: Color(0xFF94A3B8))),
          trailing: Wrap(children: [
            if (onWithdraw != null)
              IconButton(
                  tooltip: 'Withdraw',
                  onPressed: onWithdraw,
                  icon: const Icon(Icons.cancel_outlined)),
            IconButton(
                tooltip: 'Open application',
                onPressed: onOpen,
                icon: const Icon(Icons.chevron_right))
          ]),
        ),
      );
}

class _StatusDialog extends StatelessWidget {
  const _StatusDialog({required this.application});
  final RoleApplication application;
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
            '${application.typeLabel} • ${application.status.replaceAll('_', ' ')}'),
        content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  if (application.lguNotes?.isNotEmpty == true)
                    _note('LGU feedback', application.lguNotes!),
                  if (application.adminNotes?.isNotEmpty == true)
                    _note('Admin decision', application.adminNotes!),
                  const Text('Application timeline',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._workflowSteps(application),
                  const Divider(),
                  ...application.history.map((entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text((entry['action'] ?? 'Updated')
                          .toString()
                          .replaceAll('_', ' ')),
                      subtitle: Text(entry['created_at']?.toString() ?? ''))),
                ]))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      );
  Widget _note(String title, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: DecoratedBox(
          decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10)),
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(value)
                  ]))));

  List<Widget> _workflowSteps(RoleApplication application) {
    final status = application.status;
    final submitted = status != 'draft';
    final lguComplete =
        ['recommended_for_approval', 'approved', 'rejected'].contains(status);
    final steps = <(String, bool, bool)>[
      ('Application created', true, status == 'draft'),
      ('Submitted', submitted, status == 'submitted'),
      (
        'LGU review',
        lguComplete,
        ['under_review', 'needs_changes'].contains(status)
      ),
      (
        'Admin approval',
        status == 'approved',
        status == 'recommended_for_approval'
      ),
      ('Role activation', status == 'approved', false),
    ];
    return steps
        .map((step) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                step.$2
                    ? Icons.check_circle
                    : step.$3
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                color: step.$2
                    ? const Color(0xFF22C55E)
                    : step.$3
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF94A3B8),
              ),
              title: Text(step.$1),
            ))
        .toList(growable: false);
  }
}

class _EmptyApplications extends StatelessWidget {
  const _EmptyApplications();
  @override
  Widget build(BuildContext context) => const Card(
      child: Padding(
          padding: EdgeInsets.all(28),
          child: Center(
              child: Text(
                  'No applications yet. Choose an access type above to begin.'))));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: Text(error.toString()),
          trailing:
              TextButton(onPressed: onRetry, child: const Text('Retry'))));
}
