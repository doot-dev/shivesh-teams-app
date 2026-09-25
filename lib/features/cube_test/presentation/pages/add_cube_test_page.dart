import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/tech_api_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_animations.dart';
import '../../../../core/widgets/app_widgets.dart';
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
    final result = await FilePicker.pickFiles(
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
      await ref
          .read(techApiProvider)
          .createCubeTest(
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
      body: Column(
        children: [
          // ---------- Gradient header ----------
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppRadius.xxl),
                bottomRight: Radius.circular(AppRadius.xxl),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.xl,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Back',
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add cube test',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Record a cast sample',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.gutter,
                  AppSpacing.gutter,
                  AppSpacing.xxxl,
                ),
                children: [
                  // ---------- Sample info ----------
                  FadeSlideIn(
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sample info',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const FieldLabel('Casting date', required: true),
                          const SizedBox(height: AppSpacing.xs + 2),
                          _PickerField(
                            hint: 'Select casting date',
                            value: _castingDate == null
                                ? null
                                : _dateFmt.format(_castingDate!),
                            icon: Icons.calendar_today_outlined,
                            onTap: _pickCastingDate,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const FieldLabel('Quantity', required: true),
                          const SizedBox(height: AppSpacing.xs + 2),
                          TextFormField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter the number of cubes'
                                : null,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 6 cubes',
                              prefixIcon: Icon(Icons.scale_outlined, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ---------- Testing period ----------
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 70),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Testing period',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Standard periods calculate the testing date for you.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Wrap(
                            spacing: AppSpacing.sm + 2,
                            runSpacing: AppSpacing.sm + 2,
                            children: selectableCubeTestPeriods
                                .map(
                                  (p) => _PeriodChip(
                                    label: p.label,
                                    selected: _period == p,
                                    onTap: () => setState(() => _period = p),
                                  ),
                                )
                                .toList(),
                          ),
                          if (_period == CubeTestPeriod.custom) ...[
                            const SizedBox(height: AppSpacing.lg),
                            const FieldLabel('Testing date', required: true),
                            const SizedBox(height: AppSpacing.xs + 2),
                            _PickerField(
                              hint: 'Select testing date',
                              value: _customDate == null
                                  ? null
                                  : _dateFmt.format(_customDate!),
                              icon: Icons.event_outlined,
                              onTap: _pickCustomDate,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'A custom date records a test that has already '
                              'happened, so it cannot be in the future.',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                          // Live computed date — reassures the technician the
                          // app and the server agree before they submit.
                          AnimatedSize(
                            duration: AppMotion.mid,
                            curve: AppMotion.ease,
                            child:
                                testDate != null &&
                                    _period != CubeTestPeriod.custom
                                ? Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.lg,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md + 2,
                                        vertical: AppSpacing.md,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.blue50,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.md,
                                        ),
                                        border: Border.all(
                                          color: AppColors.blue100,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.event_available_rounded,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(
                                            width: AppSpacing.sm + 2,
                                          ),
                                          Expanded(
                                            child: Text(
                                              'Testing date: '
                                              '${_dateFmt.format(testDate)}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: AppColors.primary,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ---------- Report upload ----------
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 140),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Test report',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Optional — you can attach the result sheet later.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PressableScale(
                            onTap: _pickFile,
                            child: DottedBorder(
                              color: _fileName != null
                                  ? AppColors.primary
                                  : AppColors.borderStrong,
                              strokeWidth: 1.5,
                              dashPattern: const [6, 4],
                              borderType: BorderType.RRect,
                              radius: const Radius.circular(AppRadius.lg),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.xxxl,
                                ),
                                decoration: BoxDecoration(
                                  color: _fileName != null
                                      ? AppColors.blue50
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: _fileName != null
                                            ? AppColors.primary
                                            : AppColors.blue50,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _fileName != null
                                            ? Icons.description_rounded
                                            : Icons.cloud_upload_outlined,
                                        size: 24,
                                        color: _fileName != null
                                            ? Colors.white
                                            : AppColors.blue400,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.lg,
                                      ),
                                      child: Text(
                                        _fileName ?? 'Upload a file',
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: _fileName != null
                                                  ? AppColors.primary
                                                  : AppColors.textPrimary,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'PDF, JPG or PNG up to 10 MB',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: AppColors.textMuted,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 20),
                        label: Text(
                          _isSubmitting ? 'Submitting…' : 'Submit report',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: selected ? AppColors.shadowSm : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
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
    final theme = Theme.of(context);
    final filled = value != null;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: filled ? AppColors.blue200 : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: filled ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                value ?? hint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: filled ? AppColors.textPrimary : AppColors.textMuted,
                  fontWeight: filled ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
