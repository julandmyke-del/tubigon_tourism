import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../reservations/repositories/reservation_repository.dart';
import '../../../tourist_spots/repositories/tourist_spot_repository.dart';
import '../../../../core/utils/auth_action_guard.dart';
import '../../../authentication/auth_provider.dart';

class CreateReservationPage extends ConsumerStatefulWidget {
  const CreateReservationPage({super.key, this.initialSpotUuid});

  final String? initialSpotUuid;

  @override
  ConsumerState<CreateReservationPage> createState() =>
      _CreateReservationPageState();
}

class _CreateReservationPageState extends ConsumerState<CreateReservationPage> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  int _guests = 2;
  double _pricePerGuest = 150.0;
  final _notesCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _selectedSpotUuid;

  @override
  void initState() {
    super.initState();
    _selectedSpotUuid = widget.initialSpotUuid;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF59E0B),
              onPrimary: Colors.black,
              surface: Color(0xFF0F172A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF59E0B),
              onPrimary: Colors.black,
              surface: Color(0xFF0F172A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitReservation() async {
    if (_selectedSpotUuid == null || _selectedSpotUuid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a valid destination.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Confirm Reservation',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Book for $_guests guest(s) on ${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year} at ${_selectedTime.format(context)}?',
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Review')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isSubmitting = true);
    try {
      final dateStr =
          "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      final timeStr =
          "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}";

      final synced =
          await ref.read(reservationRepositoryProvider).createReservation(
                reservableType: 'spot',
                reservableId: _selectedSpotUuid ?? 'default-spot-uuid',
                date: dateStr,
                startTime: timeStr,
                guests: _guests,
                pricePerGuest: _pricePerGuest,
                notes: _notesCtrl.text.trim(),
              );

      ref.invalidate(reservationsListProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor:
            synced ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        content: Text(synced
            ? 'Reservation created successfully!'
            : 'You are offline. The reservation is saved and pending synchronization.'),
      ));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isLoggedIn || auth.userId == null) {
      return signedInRequiredPage(context, ref, title: 'New Booking');
    }
    final spotsAsync = ref.watch(touristSpotsListProvider);
    final totalCost = _guests * _pricePerGuest;

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
          'Create Reservation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Destination Selector
            const Text(
              'Select Destination',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            spotsAsync.when(
              loading: () => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('Loading spots…',
                    style: TextStyle(color: Colors.white54)),
              ),
              error: (_, __) => Container(),
              data: (spots) {
                if (spots.isNotEmpty && _selectedSpotUuid == null) {
                  _selectedSpotUuid = spots.first.uuid;
                  _pricePerGuest = spots.first.entranceFee > 0
                      ? spots.first.entranceFee
                      : 150.0;
                }
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSpotUuid,
                      dropdownColor: const Color(0xFF0F172A),
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFFF59E0B)),
                      items: spots.map((spot) {
                        return DropdownMenuItem<String>(
                          value: spot.uuid,
                          child: Text(
                            spot.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final spot = spots.firstWhere((s) => s.uuid == val);
                          setState(() {
                            _selectedSpotUuid = val;
                            _pricePerGuest =
                                spot.entranceFee > 0 ? spot.entranceFee : 150.0;
                          });
                        }
                      },
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Date & Time Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF1E293B)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded,
                                  color: Color(0xFFF59E0B), size: 18),
                              const SizedBox(width: 10),
                              Text(
                                "${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Time',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickTime,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF1E293B)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  color: Color(0xFF38BDF8), size: 18),
                              const SizedBox(width: 10),
                              Text(
                                _selectedTime.format(context),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Number of Guests Counter
            const Text('Number of Guests',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.group_rounded,
                      color: Color(0xFF34D399), size: 22),
                  const SizedBox(width: 12),
                  const Text('Guests',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Color(0xFF1E293B), shape: BoxShape.circle),
                      child: const Icon(Icons.remove_rounded,
                          color: Colors.white, size: 18),
                    ),
                    onPressed: () {
                      if (_guests > 1) setState(() => _guests--);
                    },
                  ),
                  Text('$_guests',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Color(0xFF1E293B), shape: BoxShape.circle),
                      child: const Icon(Icons.add_rounded,
                          color: Colors.white, size: 18),
                    ),
                    onPressed: () => setState(() => _guests++),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Special Notes / Requests
            const Text('Special Notes (Optional)',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText:
                    'Add dietary preferences, equipment requests, or arrival details…',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF1E293B)),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Cost Breakdown Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Fee per guest',
                          style: TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 13)),
                      Text('₱${_pricePerGuest.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Guests count',
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 13)),
                      Text('x $_guests',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ],
                  ),
                  const Divider(color: Color(0xFF1E293B), height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Estimated Cost',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text('₱${totalCost.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReservation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2))
                  : const Text('Confirm & Book Now',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
