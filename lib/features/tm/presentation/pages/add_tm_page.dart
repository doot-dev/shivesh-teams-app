import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dotted_border/dotted_border.dart';

import '../../../../core/providers/tech_api_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../orders/providers/orders_providers.dart';

class AddTmPage extends ConsumerStatefulWidget {
  const AddTmPage({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<AddTmPage> createState() => _AddTmPageState();
}

class _AddTmPageState extends ConsumerState<AddTmPage> {
  final _formKey = GlobalKey<FormState>();
  final _truckNoController = TextEditingController();
  final _quantityController = TextEditingController();
  final _challanNoController = TextEditingController();

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  /// W13: plant dispatch and site arrival times (optional).
  TimeOfDay? _dispatchTime;
  TimeOfDay? _arrivalTime;

  Future<void> _pickOptional(void Function(TimeOfDay) set) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => set(picked));
  }

  /// The picked challan. BOTH are needed: the name is what the technician sees,
  /// the path is what actually gets uploaded. An earlier version kept only the
  /// name, so the file was never sent and every challan silently went missing.
  String? _uploadedFileName;
  String? _uploadedFilePath;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _truckNoController.dispose();
    _quantityController.dispose();
    _challanNoController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.isNotEmpty) {
      final picked = result.files.first;
      setState(() {
        _uploadedFileName = picked.name;
        _uploadedFilePath = picked.path;
      });
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end time.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(techApiProvider).createTm(
            widget.orderId,
            truckNo: _truckNoController.text.trim(),
            qty: _quantityController.text.trim(),
            batchStartTime: _formatTime(_startTime!),
            batchEndTime: _formatTime(_endTime!),
            dispatchTime: _dispatchTime == null ? null : _formatTime(_dispatchTime!),
            arrivalTime: _arrivalTime == null ? null : _formatTime(_arrivalTime!),
            challanNo: _challanNoController.text.trim(),
            challanFilePath: _uploadedFilePath,
            challanFileName: _uploadedFileName,
          );
      ref.invalidate(orderByIdProvider(widget.orderId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TM details submitted successfully.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text('Add TM details'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _SectionHeader('Truck Info'),
            const SizedBox(height: 14),
            _FieldLabel('Truck no.'),
            const SizedBox(height: 6),
            _FormField(
              controller: _truckNoController,
              hint: 'Enter truck no.',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _FieldLabel('Material quantity'),
            const SizedBox(height: 6),
            _FormField(
              controller: _quantityController,
              hint: 'Enter material quantity',
              keyboardType: TextInputType.number,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _FieldLabel('Challan no.'),
            const SizedBox(height: 6),
            _FormField(
              controller: _challanNoController,
              hint: 'Enter challan no.',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 28),
            _SectionHeader('Batch Info'),
            const SizedBox(height: 14),
            _FieldLabel('Start time'),
            const SizedBox(height: 6),
            _TimePicker(
              hint: 'Select start time',
              value: _startTime?.format(context),
              onTap: () => _pickTime(true),
            ),
            const SizedBox(height: 16),
            _FieldLabel('End time'),
            const SizedBox(height: 6),
            _TimePicker(
              hint: 'Select end time',
              value: _endTime?.format(context),
              onTap: () => _pickTime(false),
            ),
            const SizedBox(height: 16),
            _FieldLabel('Dispatched from plant (optional)'),
            const SizedBox(height: 6),
            _TimePicker(
              hint: 'Select dispatch time',
              value: _dispatchTime?.format(context),
              onTap: () => _pickOptional((t) => _dispatchTime = t),
            ),
            const SizedBox(height: 16),
            _FieldLabel('Arrived at site (optional)'),
            const SizedBox(height: 6),
            _TimePicker(
              hint: 'Select arrival time',
              value: _arrivalTime?.format(context),
              onTap: () => _pickOptional((t) => _arrivalTime = t),
            ),
            const SizedBox(height: 28),
            _SectionHeader('Upload Challan'),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _pickFile,
              child: DottedBorder(
                color: AppColors.textMuted,
                strokeWidth: 1.5,
                dashPattern: const [6, 4],
                borderType: BorderType.RRect,
                radius: const Radius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.upload_file_outlined,
                          size: 36, color: AppColors.textMuted),
                      const SizedBox(height: 10),
                      Text(
                        _uploadedFileName ?? 'Upload a file',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _uploadedFileName != null
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PDF, JPG or PNG, up to 10 MB',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: AppColors.textMuted),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.validator,
  });
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: Theme.of(context).textTheme.bodySmall,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  const _TimePicker({
    required this.hint,
    required this.onTap,
    this.value,
  });
  final String hint;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: value != null
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
              ),
            ),
            const Icon(Icons.access_time_outlined,
                size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
