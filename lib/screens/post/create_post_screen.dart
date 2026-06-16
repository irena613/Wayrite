import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/date_format.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../data/app_store.dart';
import '../../models/post.dart';

/// Екран за креирање објава (Achievement / Quit) со наслов, опис и датуми.
///
/// UI flow: Feed -> (FAB +) -> CreatePost -> "Објави" -> назад на Feed
/// (новата објава се појавува на врвот, бидејќи Feed е хронолошки сортиран).
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  PostType _type = PostType.achievement;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    appStore.createPost(
      type: _type,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Нова објава')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Тип на објава', style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<PostType>(
                segments: [
                  ButtonSegment(
                    value: PostType.achievement,
                    label: const Text('Постигнување'),
                    icon: Icon(AppIcons.forPostType(PostType.achievement)),
                  ),
                  ButtonSegment(
                    value: PostType.quit,
                    label: const Text('Откажување'),
                    icon: Icon(AppIcons.forPostType(PostType.quit)),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return _type.color.withValues(alpha: 0.15);
                    }
                    return null;
                  }),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Наслов',
                controller: _titleController,
                hint: 'пр. 30 дена редовно тренирање',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Внеси наслов' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Опис',
                controller: _descriptionController,
                hint: 'Кажи нешто повеќе за оваа објава...',
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Внеси опис' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Датуми', style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _DatePickerField(
                      label: 'Почетен датум',
                      date: _startDate,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _DatePickerField(
                      label: 'Краен датум (опц.)',
                      date: _endDate,
                      onTap: () => _pickDate(isStart: false),
                      onClear: _endDate == null ? null : () => setState(() => _endDate = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(label: 'Објави', onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          children: [
            const Icon(AppIcons.calendar, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.caption),
                  Text(
                    date != null ? formatDate(date!) : '—',
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
