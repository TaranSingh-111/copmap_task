import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../data/models/duty_model.dart';
import '../../../data/models/user_profile.dart';
import '../controllers/admin_controller.dart';

class DutyFormPage extends StatefulWidget {
  const DutyFormPage({this.duty, super.key});

  final DutyModel? duty;

  @override
  State<DutyFormPage> createState() => _DutyFormPageState();
}

class _DutyFormPageState extends State<DutyFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  late final AdminController _controller;
  DateTime? _startTime;
  DateTime? _endTime;
  String? _assignedTo;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<AdminController>();
    final duty = widget.duty;
    _title.text = duty?.title ?? '';
    _description.text = duty?.description ?? '';
    _location.text = duty?.locationName ?? '';
    _latitude.text = duty?.latitude?.toString() ?? '';
    _longitude.text = duty?.longitude?.toString() ?? '';
    _assignedTo = duty?.assignedTo;
    final now = DateTime.now();
    _startTime = duty?.startTime ?? now.add(const Duration(hours: 1));
    _endTime = duty?.endTime ?? _startTime!.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.duty?.status.isTerminal == true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit duty')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Completed or cancelled duties cannot be edited.'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.duty == null ? 'Create duty' : 'Edit duty'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a duty title.'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'Location name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _coordinateField(_latitude, 'Latitude', -90, 90)),
              const SizedBox(width: 12),
              Expanded(child: _coordinateField(_longitude, 'Longitude', -180, 180)),
            ]),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              initialValue: _assignedTo,
              decoration: const InputDecoration(
                labelText: 'Assigned officer',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Unassigned'),
                ),
                ..._controller.officers.map(
                  (officer) => DropdownMenuItem<String?>(
                    value: officer.id,
                    child: Text(_officerName(officer)),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _assignedTo = value),
            ),
            const SizedBox(height: 18),
            _dateTimePicker(
              context,
              label: 'Scheduled start *',
              value: _startTime,
              onChanged: (value) => setState(() => _startTime = value),
            ),
            const SizedBox(height: 8),
            _dateTimePicker(
              context,
              label: 'Scheduled end *',
              value: _endTime,
              onChanged: (value) => setState(() => _endTime = value),
            ),
            const SizedBox(height: 8),
            Obx(() {
              final error = _controller.operationError.value;
              if (error == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            }),
            const SizedBox(height: 12),
            Obx(() => FilledButton(
              onPressed: _controller.isSaving.value ? null : _save,
              child: _controller.isSaving.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.duty == null ? 'Create duty' : 'Save changes'),
            )),
          ],
        ),
      ),
    );
  }

  Widget _coordinateField(
    TextEditingController textController,
    String label,
    double min,
    double max,
  ) {
    return TextFormField(
      controller: textController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.]'))],
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        final coordinate = double.tryParse(value.trim());
        if (coordinate == null || coordinate < min || coordinate > max) {
          return 'Enter a value from $min to $max.';
        }
        return null;
      },
    );
  }

  Widget _dateTimePicker(
    BuildContext context, {
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onChanged,
  }) {
    return OutlinedButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 10),
        );
        if (date == null || !context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value ?? now),
        );
        if (time == null || !context.mounted) return;
        onChanged(DateTime(
          date.year, date.month, date.day, time.hour, time.minute,
        ));
      },
      icon: const Icon(Icons.event),
      label: Text(value == null
          ? label
          : '$label: ${formatDutyDateTime(value)}'),
    );
  }

  String _officerName(UserProfile officer) {
    final name = officer.fullName?.trim();
    return name == null || name.isEmpty ? 'Officer ${officer.id}' : name;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final startTime = _startTime;
    final endTime = _endTime;
    if (startTime == null || endTime == null) {
      _showValidationError('Choose both scheduled times.');
      return;
    }
    if (!endTime.isAfter(startTime)) {
      _showValidationError('The end time must be after the start time.');
      return;
    }

    final latitudeText = _latitude.text.trim();
    final longitudeText = _longitude.text.trim();
    final latitude = latitudeText.isEmpty ? null : double.parse(latitudeText);
    final longitude = longitudeText.isEmpty ? null : double.parse(longitudeText);
    if ((latitude == null) != (longitude == null)) {
      _showValidationError('Enter both latitude and longitude, or leave both blank.');
      return;
    }

    final draft = DutyDraft(
      title: _title.text,
      description: _description.text,
      locationName: _location.text,
      latitude: latitude,
      longitude: longitude,
      assignedTo: _assignedTo,
      startTime: startTime,
      endTime: endTime,
    );
    final success = widget.duty == null
        ? await _controller.createDuty(draft)
        : await _controller.editDuty(widget.duty!, draft);
    if (success && mounted) Get.back(result: true);
  }

  void _showValidationError(String message) {
    _controller.operationError.value = message;
  }
}
