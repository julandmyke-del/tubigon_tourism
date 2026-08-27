import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/exceptions/app_exception.dart';
import '../models/itinerary.dart';
import '../repositories/itinerary_repository.dart';

class ItineraryFormPage extends ConsumerStatefulWidget {
  const ItineraryFormPage({super.key});

  @override
  ConsumerState<ItineraryFormPage> createState() => _ItineraryFormPageState();
}

class _ItineraryFormPageState extends ConsumerState<ItineraryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _travelers = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _travelers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF080F1A),
        appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            title: const Text('Create Itinerary')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF172554), Color(0xFF431407)]),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: .4)),
                ),
                child: const Row(children: [
                  Icon(Icons.route_rounded, color: Color(0xFFF59E0B), size: 38),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                        'Start with the basics. You can add places, times, notes, and reservations next.',
                        style:
                            TextStyle(color: Color(0xFFE2E8F0), height: 1.4)),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                style: const TextStyle(color: Colors.white),
                decoration: _input('Trip name', Icons.luggage_rounded),
                maxLength: 120,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a trip name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                style: const TextStyle(color: Colors.white),
                decoration:
                    _input('Description (optional)', Icons.notes_rounded),
                maxLines: 3,
                maxLength: 2000,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final vertical = constraints.maxWidth < 520;
                final fields = [
                  Expanded(
                      child: _DateField(
                          label: 'Start date',
                          value: _start,
                          onTap: _pickStart)),
                  SizedBox(width: vertical ? 0 : 12, height: vertical ? 12 : 0),
                  Expanded(
                      child: _DateField(
                          label: 'End date', value: _end, onTap: _pickEnd)),
                ];
                return vertical
                    ? Column(
                        children: fields
                            .map((field) =>
                                field is Expanded ? field.child : field)
                            .toList())
                    : Row(children: fields);
              }),
              const SizedBox(height: 12),
              TextFormField(
                controller: _travelers,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _input('Travelers (optional)', Icons.group_rounded),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final count = int.tryParse(value);
                  return count == null || count < 1 || count > 100
                      ? 'Use a number from 1 to 100.'
                      : null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(54)),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.check_rounded),
                label: const Text('Create Trip'),
              ),
            ],
          ),
        ),
      );

  Future<void> _pickStart() async {
    final value = await showDatePicker(
        context: context,
        initialDate: _start,
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 730)));
    if (value != null) {
      setState(() {
        _start = value;
        if (_end.isBefore(_start)) _end = _start;
      });
    }
  }

  Future<void> _pickEnd() async {
    final value = await showDatePicker(
        context: context,
        initialDate: _end.isBefore(_start) ? _start : _end,
        firstDate: _start,
        lastDate: _start.add(const Duration(days: 30)));
    if (value != null) setState(() => _end = value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final trip = await ref.read(itineraryRepositoryProvider).createItinerary({
        'name': _name.text.trim(),
        'description':
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        'start_date': itineraryDate(_start),
        'end_date': itineraryDate(_end),
        'travelers': int.tryParse(_travelers.text),
        'status': _start.isAfter(DateTime.now()) ? 'upcoming' : 'draft',
      });
      refreshItineraries(ref, trip.id);
      if (mounted) context.pushReplacement('/itineraries/${trip.id}');
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: _input(label, Icons.calendar_month_rounded),
          child: Text(DateFormat('MMM d, y').format(value),
              style: const TextStyle(color: Colors.white)),
        ),
      );
}

InputDecoration _input(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, color: const Color(0xFFF59E0B)),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155))),
    );
