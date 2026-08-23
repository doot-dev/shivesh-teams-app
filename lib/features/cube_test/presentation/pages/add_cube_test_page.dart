import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/tech_api_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/cube_test_model.dart';
import '../../providers/cube_test_providers.dart';

final _dateFmt = DateFormat('dd MMM yyyy');

/// Log a new cube test against an order, optionally attaching the result sheet.
class AddCubeTestPage extends ConsumerStatefulWidget {
  const AddCubeTestPage({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<AddCubeTestPage> createState() => _AddCubeTestPageState();
}

class _AddCubeTestPageState extends ConsumerState<AddCubeTestPage> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();

  DateTime? _castingDate;
  DateTime? _customDate;
  CubeTestPeriod _period = CubeTestPeriod.sevenDays;

  String? _filePath;
  String? _fileName;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  /// The date the cube will be tested — computed for standard periods, picked
  /// by the technician for CUSTOM. Mirrors the backend's resolveToDate so the
  /// technician sees the same date the server will store.
  DateTime? get _resolvedTestDate {
    if (_period == CubeTestPeriod.custom) return _customDate;
    final casting = _castingDate;
    if (casting == null) return null;
    return casting.add(Duration(days: _period.days!));
  }

  Future<void> _pickCastingDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _castingDate ?? now,
      // A cube is cast on site, so it cannot be cast in the future.
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      builder: _pickerTheme,
    );
    if (picked != null) setState(() => _castingDate = picked);
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? now,
      firstDate: DateTime(now.year - 2),
      // The backend rejects a future custom date — don't let it be chosen.
      lastDate: now,
      builder: _pickerTheme,
    );
    if (picked != null) setState(() => _customDate = picked);
  }

  Widget _pickerTheme(BuildContext context, Widget? child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      );

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.isNotEmpty) {
      final f = result.files.first;
      setState(() {
        _filePath = f.path;
        _fileName = f.name;
      });
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    if (_castingDate == null) {
      _toast('Please select the casting date.');
      return;
    }
    if (_period == CubeTestPeriod.custom && _customDate == null) {
      _toast('Please select the custom testing date.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(techApiProvider).createCubeTest(
            widget.orderId,
            castingDate: _castingDate!,
            quantity: _quantityController.text.trim(),
            period: _period,
            customDate: _customDate,
            filePath: _filePath,
            fileName: _fileName,
          );
      ref.invalidate(cubeTestsProvider(widget.orderId));
      if (mounted) {
        _toast('Cube test added successfully.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _toast('Failed to submit: ${_message(e)}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _message(Object e) {
    final s = e.toString();
    return s.length > 140 ? '${s.substring(0, 140)}…' : s;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final testDate = _resolvedTestDate;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text('Add Cube Test'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const _SectionHeader('Sample Info'),
            const SizedBox(height: 14),
            const _FieldLabel('Casting date'),
            const SizedBox(height: 6),
            _PickerField(
              hint: 'Select casting date',
              value: _castingDate == null ? null : _dateFmt.format(_castingDate!),
              icon: Icons.calendar_today_outlined,
              onTap: _pickCastingDate,
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Quantity'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _quantityController,
              style: theme.textTheme.bodySmall,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              decoration: _inputDecoration('e.g. 6 cubes'),
            ),
            const SizedBox(height: 28),
            const _SectionHeader('Testing Period'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: CubeTestPeriod.values
                  .map((p) => _PeriodChip(
                        label: p.label,
                        selected: _period == p,
                        onTap: () => setState(() => _period = p),
                      ))
                  .toList(),
            ),
            if (_period == CubeTestPeriod.custom) ...[
              const SizedBox(height: 16),
              const _FieldLabel('Testing date'),
              const SizedBox(height: 6),
              _PickerField(
                hint: 'Select testing date',
                value:
                    _customDate == null ? null : _dateFmt.format(_customDate!),
                icon: Icons.event_outlined,
                onTap: _pickCustomDate,
              ),
              const SizedBox(height: 6),
              Text(
                'A custom date records a test that has already happened, so it cannot be in the future.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
            if (testDate != null && _period != CubeTestPeriod.custom) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.science_outlined,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Testing date: ${_dateFmt.format(testDate)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            const _SectionHeader('Test Report'),
            const SizedBox(height: 6),
            Text(
              'Optional — you can attach the result sheet later.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),
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
                      Icon(
                        _fileName != null
                            ? Icons.description_outlined
                            : Icons.upload_file_outlined,
                        size: 36,
                        color: _fileName != null
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _fileName ?? 'Upload a file',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _fileName != null
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'supported formats: PDF, JPG, PNG up to 10 MB',
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

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    );

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.hint,
    required this.icon,
    required this.onTap,
    this.value,
  });
  final String hint;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
            Icon(icon, size: 20, color: AppColors.textMuted),
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
