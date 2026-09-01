import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:artvault/utils/image_helper.dart';
import 'package:artvault/utils/io_shim.dart';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/condition_report.dart';

/// What the user entered in the [ConditionReportDialog]; the caller persists
/// it via [ConditionReportRepository.add].
class ConditionReportDraft {
  final String condition;
  final String notes;
  final DateTime inspectedAt;
  final File? photo;

  const ConditionReportDraft({
    required this.condition,
    required this.notes,
    required this.inspectedAt,
    this.photo,
  });
}

/// Collects a condition report (state, optional photo, notes, date) and pops
/// a [ConditionReportDraft]. Owns its [TextEditingController] and disposes it
/// only when the route unmounts (never mid-exit).
class ConditionReportDialog extends StatefulWidget {
  final String paintingId;

  const ConditionReportDialog({super.key, required this.paintingId});

  @override
  State<ConditionReportDialog> createState() => _ConditionReportDialogState();
}

class _ConditionReportDialogState extends State<ConditionReportDialog> {
  final _notes = TextEditingController();
  String _condition = ConditionReport.levels.first;
  DateTime _inspectedAt = DateTime.now();
  File? _photo;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<_Source>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, _Source.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, _Source.camera),
            ),
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(context, _Source.remove),
              ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    switch (source) {
      case _Source.gallery:
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: AppConstants.maxUploadDimension.toDouble(),
          imageQuality: 92,
        );
        if (file != null) setState(() => _photo = File(file.path));
      case _Source.camera:
        final file = await ImagePicker().pickImage(
          source: ImageSource.camera,
          maxWidth: AppConstants.maxUploadDimension.toDouble(),
          imageQuality: 92,
        );
        if (file != null) setState(() => _photo = File(file.path));
      case _Source.remove:
        setState(() => _photo = null);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inspectedAt,
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
      helpText: 'When was this piece inspected?',
    );
    if (picked != null) setState(() => _inspectedAt = picked);
  }

  void _save() {
    Navigator.pop(
      context,
      ConditionReportDraft(
        condition: _condition,
        notes: _notes.text.trim(),
        inspectedAt: _inspectedAt,
        photo: _photo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Condition report'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Physical state at inspection time.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final level in ConditionReport.levels)
                  ChoiceChip(
                    label: Text(level),
                    selected: _condition == level,
                    onSelected: (_) => setState(() => _condition = level),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              onTap: _pickPhoto,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: _photo == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            color: scheme.primary,
                            size: 34,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text('Add a condition photo'),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd - 2,
                        ),
                        child: kIsWeb
                            ? const Icon(Icons.image, size: 48)
                            : nativeImage(
                                _photo!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _notes,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Scratches, frame wear, restoration history…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Inspection date'),
              subtitle: Text(Formatters.date(_inspectedAt)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save report')),
      ],
    );
  }
}

enum _Source { gallery, camera, remove }

