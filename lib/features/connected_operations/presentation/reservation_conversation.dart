import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notifications/repositories/notification_repository.dart';
import '../../reservations/repositories/reservation_repository.dart';
import '../../tourism_partner/providers/tourism_partner_providers.dart';
import '../data/connected_operations_repository.dart';

class ReservationConversation extends ConsumerStatefulWidget {
  const ReservationConversation(
      {super.key, required this.reservationId, this.partner = false});
  final String reservationId;
  final bool partner;
  @override
  ConsumerState<ReservationConversation> createState() =>
      _ReservationConversationState();
}

class _ReservationConversationState
    extends ConsumerState<ReservationConversation> {
  final controller = TextEditingController();
  bool internal = false, sending = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reservationMessagesProvider(widget.reservationId));
    return SizedBox(
        width: double.infinity,
        child: Material(
          color: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E293B)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Reservation Messages',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const Text(
                  'This thread is available only to this Tourist and the assigned Partner.',
                  style: TextStyle(color: Color(0xFF94A3B8))),
              const SizedBox(height: 10),
              state.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => TextButton(
                      onPressed: () => ref.invalidate(
                          reservationMessagesProvider(widget.reservationId)),
                      child: const Text('Retry messages')),
                  data: (items) => items.isEmpty
                      ? const Text('No messages yet.',
                          style: TextStyle(color: Color(0xFF94A3B8)))
                      : Column(
                          children: items
                              .map((m) => ListTile(
                                  dense: true,
                                  leading: Icon(
                                      m['message_type'] == 'system_update'
                                          ? Icons.info_outline
                                          : m['is_internal'] == true
                                              ? Icons.lock_outline
                                              : Icons.chat_bubble_outline,
                                      size: 18),
                                  title: Text(m['message']?.toString() ?? ''),
                                  subtitle: Text(m['is_internal'] == true
                                      ? 'Internal — not visible to Tourist'
                                      : m['sender'] is Map
                                          ? (m['sender'] as Map)['name']
                                                  ?.toString() ??
                                              'System'
                                          : 'System')))
                              .toList())),
              const Divider(),
              TextField(
                  controller: controller,
                  maxLength: 3000,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Message')),
              if (widget.partner)
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: internal,
                    onChanged: (v) => setState(() => internal = v),
                    title: const Text('Internal note'),
                    subtitle: const Text('Not visible to the Tourist')),
              FilledButton.icon(
                  onPressed: sending ? null : _send,
                  icon: const Icon(Icons.send),
                  label: const Text('Send'))
            ]),
          ),
        ));
  }

  Future<void> _send() async {
    if (controller.text.trim().isEmpty) return;
    setState(() => sending = true);
    try {
      await ref
          .read(connectedOperationsRepositoryProvider)
          .sendReservationMessage(widget.reservationId, controller.text,
              internal: internal);
      controller.clear();
      ref.invalidate(reservationMessagesProvider(widget.reservationId));
      ref.invalidate(reservationsListProvider);
      ref.invalidate(partnerReservationsProvider);
      ref.invalidate(partnerNotificationsProvider);
      ref.invalidate(touristNotificationsProvider);
      ref.invalidate(touristUnreadCountProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('The reservation message could not be sent.')));
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
}
