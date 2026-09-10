import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../core/constants/app_constants.dart';
import '../../admin/providers/admin_providers.dart';
import '../../lgupage/providers/lgu_providers.dart';
import '../models/role_application.dart';
import '../providers/role_application_providers.dart';

class RoleApplicationReviewPage extends ConsumerStatefulWidget {
  const RoleApplicationReviewPage(
      {super.key, required this.admin, this.initialId});
  final bool admin;
  final String? initialId;

  @override
  ConsumerState<RoleApplicationReviewPage> createState() =>
      _RoleApplicationReviewPageState();
}

class _RoleApplicationReviewPageState
    extends ConsumerState<RoleApplicationReviewPage> {
  final _search = TextEditingController();
  String? _type;
  String? _status;
  DateTimeRange? _dates;
  bool _openedInitial = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = RoleApplicationFilter(
      type: _type,
      status: _status,
      search: _search.text,
      dateFrom: _dates == null ? null : _date(_dates!.start),
      dateTo: _dates == null ? null : _date(_dates!.end),
    );
    final applications = widget.admin
        ? ref.watch(adminAccessRequestsProvider(filter))
        : ref.watch(lguRoleApplicationsProvider(filter));
    applications.whenData((items) {
      if (_openedInitial || widget.initialId == null) return;
      final matches = items.where((item) => item.id == widget.initialId);
      if (matches.isEmpty) return;
      _openedInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(matches.first, filter);
      });
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(widget.admin ? 'Access Requests' : 'Role Applications',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            widget.admin
                ? 'Final identity, role, and ownership provisioning. LGU recommendation is required.'
                : 'Verify legitimacy and operations. Role provisioning remains restricted to Admin.',
            style: const TextStyle(color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),
          Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(
                width: 310,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search applicant, business, organization…'),
                  onSubmitted: (_) => setState(() {}),
                )),
            SizedBox(
                width: 210,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _type,
                  decoration:
                      const InputDecoration(labelText: 'Application type'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All types')),
                    DropdownMenuItem(
                        value: 'msme_owner', child: Text('MSME Owner')),
                    DropdownMenuItem(
                        value: 'tourism_partner',
                        child: Text('Tourism Partner'))
                  ],
                  onChanged: (value) => setState(
                      () => _type = value?.isEmpty == true ? null : value),
                )),
            SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('Default queue')),
                    ...[
                      'submitted',
                      'under_review',
                      'needs_changes',
                      'recommended_for_approval',
                      'approved',
                      'rejected',
                      'withdrawn'
                    ].map((value) => DropdownMenuItem(
                        value: value, child: Text(value.replaceAll('_', ' '))))
                  ],
                  onChanged: (value) => setState(
                      () => _status = value?.isEmpty == true ? null : value),
                )),
            IconButton.filledTonal(
                tooltip: 'Refresh queue',
                onPressed: () => _refresh(filter),
                icon: const Icon(Icons.refresh)),
            OutlinedButton.icon(
              onPressed: _pickDates,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(_dates == null
                  ? 'Submission date'
                  : '${_date(_dates!.start)} – ${_date(_dates!.end)}'),
            ),
            if (_dates != null)
              IconButton(
                tooltip: 'Clear date filter',
                onPressed: () => setState(() => _dates = null),
                icon: const Icon(Icons.filter_alt_off),
              ),
          ]),
          const SizedBox(height: 18),
          applications.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator())),
            error: (error, _) => Card(
                child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(error.toString()),
                    trailing: TextButton(
                        onPressed: () => _refresh(filter),
                        child: const Text('Retry')))),
            data: (items) => items.isEmpty
                ? const Card(
                    child: Padding(
                        padding: EdgeInsets.all(36),
                        child: Center(
                            child: Text('No applications match this queue.'))))
                : LayoutBuilder(builder: (context, constraints) {
                    final count = constraints.maxWidth >= 1000 ? 2 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: count,
                          childAspectRatio: count == 2 ? 2.7 : 3.1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12),
                      itemCount: items.length,
                      itemBuilder: (_, index) => _ReviewCard(
                          application: items[index],
                          onTap: () => _open(items[index], filter)),
                    );
                  }),
          ),
        ],
      ),
    );
  }

  void _refresh(RoleApplicationFilter filter) {
    if (widget.admin) {
      ref.invalidate(adminAccessRequestsProvider(filter));
    } else {
      ref.invalidate(lguRoleApplicationsProvider(filter));
    }
  }

  Future<void> _pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dates,
    );
    if (range != null && mounted) {
      setState(() => _dates = range);
    }
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _open(
      RoleApplication application, RoleApplicationFilter filter) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _ReviewDialog(application: application, admin: widget.admin),
    );
    if (mounted) _refresh(filter);
  }
}

class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog({required this.application, required this.admin});
  final RoleApplication application;
  final bool admin;
  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  final _notes = TextEditingController();
  bool _busy = false;
  late final Map<String, bool> _checklist;
  String? _reviewCategoryId;

  @override
  void initState() {
    super.initState();
    final partner = widget.application.type == 'tourism_partner';
    _reviewCategoryId = widget.admin
        ? (widget.application.recommendedMsmeCategory?['id']?.toString() ??
            widget.application.requestedMsmeCategory?['id']?.toString())
        : widget.application.requestedMsmeCategory?['id']?.toString();
    _checklist = partner
        ? {
            'applicant_identity_complete': false,
            'organization_relationship_verified': false,
            'requested_destination_valid': false,
            'required_proof_complete': false,
            'destination_assignment_available': false
          }
        : {
            'applicant_identity_complete': false,
            'business_information_complete': false,
            'address_valid': false,
            'coordinates_valid': false,
            'category_appropriate': false,
            'contact_information_valid': false,
            'required_proof_complete': false
          };
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    final options =
        ref.watch(roleApplicationOptionsProvider).valueOrNull ?? const {};
    final categories = (options['msme_categories'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    return Dialog.fullscreen(
        child: Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
          backgroundColor: const Color(0xFF101B34),
          title: Text('${app.typeLabel} review'),
          leading: IconButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close))),
      body: ListView(padding: const EdgeInsets.all(22), children: [
        Wrap(spacing: 10, runSpacing: 8, children: [
          Chip(label: Text(app.status.replaceAll('_', ' '))),
          Chip(label: Text(app.applicant?['name']?.toString() ?? 'Applicant')),
          Chip(label: Text(app.applicant?['email']?.toString() ?? 'No email')),
        ]),
        const SizedBox(height: 18),
        _Section(
            title: 'Application details',
            child: Wrap(
                spacing: 22,
                runSpacing: 14,
                children: app.payload.entries
                    .map((entry) => SizedBox(
                        width: 300,
                        child: _Value(
                            label: entry.key.replaceAll('_', ' '),
                            value: entry.value.toString())))
                    .toList())),
        if (app.requestedSpot != null)
          _Section(
              title: 'Requested destination',
              child: _Value(
                  label: 'Tourist Spot',
                  value:
                      '${app.requestedSpot?['name']}\nCategory: ${app.requestedSpot?['category']?['name'] ?? 'Uncategorized'}\n${app.requestedSpot?['address'] ?? ''}')),
        if (app.type == 'msme_owner')
          _Section(
              title: 'Authoritative business category',
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Value(
                        label: 'Applicant requested',
                        value: app.requestedMsmeCategory?['name']?.toString() ??
                            app.payload['business_category']?.toString() ??
                            'Not selected'),
                    if (app.recommendedMsmeCategory != null)
                      _Value(
                          label: 'LGU recommended',
                          value: app.recommendedMsmeCategory?['name']
                                  ?.toString() ??
                              ''),
                    if (app.finalMsmeCategory != null)
                      _Value(
                          label: 'Admin final',
                          value:
                              app.finalMsmeCategory?['name']?.toString() ?? ''),
                    if ((!widget.admin && app.status == 'under_review') ||
                        (widget.admin &&
                            app.status == 'recommended_for_approval'))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: DropdownButtonFormField<String>(
                          initialValue: _reviewCategoryId,
                          decoration: InputDecoration(
                              labelText: widget.admin
                                  ? 'Final category'
                                  : 'Recommended category',
                              helperText:
                                  'The applicant’s original selection remains in history.'),
                          items: categories
                              .map((category) => DropdownMenuItem<String>(
                                  value: category['id']?.toString(),
                                  child: Text(category['name']?.toString() ??
                                      'Category')))
                              .toList(),
                          onChanged: _busy
                              ? null
                              : (value) =>
                                  setState(() => _reviewCategoryId = value),
                        ),
                      ),
                  ])),
        if (app.type == 'msme_owner' && app.payload['latitude'] != null)
          _Section(
              title: 'Map preview',
              child: SizedBox(
                  height: 260,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MapLibreMap(
                        styleString: AppConstants.mapStyleUrl,
                        initialCameraPosition: CameraPosition(
                            target: LatLng(
                                double.tryParse(
                                        app.payload['latitude'].toString()) ??
                                    9.9515,
                                double.tryParse(
                                        app.payload['longitude'].toString()) ??
                                    123.9618),
                            zoom: 15),
                        myLocationEnabled: false,
                        compassEnabled: false,
                      )))),
        if (app.lguNotes?.isNotEmpty == true)
          _Section(title: 'LGU notes', child: Text(app.lguNotes!)),
        _Section(
            title: 'Review history',
            child: Column(
                children: app.history
                    .map((entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.history),
                        title: Text((entry['action'] ?? 'updated')
                            .toString()
                            .replaceAll('_', ' ')),
                        subtitle: Text(
                            '${entry['notes'] ?? ''}\n${entry['created_at'] ?? ''}')))
                    .toList())),
        if (!widget.admin && app.status == 'under_review')
          _Section(
              title: 'LGU verification checklist',
              child: Column(
                  children: _checklist.entries
                      .map((entry) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: entry.value,
                          onChanged: _busy
                              ? null
                              : (value) => setState(
                                  () => _checklist[entry.key] = value ?? false),
                          title: Text(entry.key.replaceAll('_', ' ')),
                          controlAffinity: ListTileControlAffinity.leading))
                      .toList())),
        if ((!widget.admin && app.status == 'under_review') ||
            (widget.admin && app.status == 'recommended_for_approval'))
          _Section(
              title: widget.admin ? 'Admin decision notes' : 'LGU review notes',
              child: TextField(
                  controller: _notes,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      hintText: 'Record clear, actionable review notes…'))),
      ]),
      bottomNavigationBar: SafeArea(
          child: Container(
              color: const Color(0xFF101B34),
              padding: const EdgeInsets.all(14),
              child: _actions(app))),
    ));
  }

  Widget _actions(RoleApplication app) {
    if (widget.admin && app.status == 'recommended_for_approval') {
      return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        OutlinedButton(
            onPressed: _busy ? null : () => _act('reject', requireNotes: true),
            child: const Text('Reject')),
        const SizedBox(width: 10),
        FilledButton.icon(
            onPressed: _busy ? null : () => _act('approve'),
            icon: const Icon(Icons.verified_user),
            label: const Text('Approve & Provision')),
      ]);
    }
    if (!widget.admin && app.status == 'submitted') {
      return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        FilledButton(
            onPressed: _busy ? null : () => _act('start-review'),
            child: const Text('Start Review'))
      ]);
    }
    if (!widget.admin && app.status == 'under_review') {
      return Wrap(
          alignment: WrapAlignment.end,
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton(
                onPressed:
                    _busy ? null : () => _act('reject', requireNotes: true),
                child: const Text('Reject')),
            OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _act('needs-changes', requireNotes: true),
                child: const Text('Needs Changes')),
            FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _act('recommend', requireChecklist: true),
                icon: const Icon(Icons.recommend),
                label: const Text('Recommend Approval')),
          ]);
    }
    return const Text('No review action is available in this state.',
        textAlign: TextAlign.end);
  }

  Future<void> _act(String action,
      {bool requireNotes = false, bool requireChecklist = false}) async {
    if (requireNotes && _notes.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Review notes are required for this decision.')));
      return;
    }
    if (requireChecklist && _checklist.values.any((value) => !value)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Complete every verification checklist item before recommending.')));
      return;
    }
    if (widget.admin && action == 'approve') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Approve and provision access?'),
          content: Text(
              'This will change ${widget.application.applicant?['name'] ?? 'the applicant'} to ${widget.application.typeLabel} and create the authoritative ownership or destination assignment. MSME publication verification remains separate.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Approve & Provision')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    final repository = ref.read(roleApplicationRepositoryProvider);
    setState(() => _busy = true);
    try {
      if (widget.admin) {
        await repository.adminAction(widget.application.id, action,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            finalMsmeCategoryId:
                action == 'approve' && widget.application.type == 'msme_owner'
                    ? _reviewCategoryId
                    : null);
      } else {
        await repository.lguAction(widget.application.id, action,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            checklist: action == 'start-review' ? null : _checklist,
            recommendedMsmeCategoryId:
                action == 'recommend' && widget.application.type == 'msme_owner'
                    ? _reviewCategoryId
                    : null);
      }
      if (!mounted) return;
      if (widget.admin) {
        ref.invalidate(adminUsersProvider);
        ref.invalidate(adminDashboardStatsProvider);
      } else {
        ref.invalidate(lguDashboardStatsProvider);
      }
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', ''))));
    }
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.application, required this.onTap});
  final RoleApplication application;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: const Color(0xFF17223D),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                          application.type == 'msme_owner'
                              ? Icons.storefront
                              : Icons.handshake,
                          color: const Color(0xFFF59E0B)),
                      const Spacer(),
                      Chip(label: Text(application.status.replaceAll('_', ' ')))
                    ]),
                    Text(
                        application.applicant?['name']?.toString() ??
                            'Applicant',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17)),
                    Text(application.typeLabel,
                        style: const TextStyle(color: Color(0xFF94A3B8))),
                    const Spacer(),
                    Text(
                        application.type == 'msme_owner'
                            ? application.payload['business_name']
                                    ?.toString() ??
                                'Business draft'
                            : application.requestedSpot?['name']?.toString() ??
                                'Destination request',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ]))));
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
      color: const Color(0xFF17223D),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child
          ])));
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white))
      ]);
}
