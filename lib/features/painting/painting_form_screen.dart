import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/file_storage_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_fields.dart';
import '../../core/widgets/art_image.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/providers/providers.dart';
import '../../data/models/artist.dart';
import '../../data/models/painting.dart';
import '../../data/repositories/artist_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/painting_repository.dart';

enum _ImageSource { gallery, camera, drive, dropbox }

/// Create & edit screen for an artwork. Runs the AI analysis pipeline
/// automatically as soon as a cover image is picked.
class PaintingFormScreen extends ConsumerStatefulWidget {
  final String? paintingId;

  const PaintingFormScreen({super.key, this.paintingId});

  @override
  ConsumerState<PaintingFormScreen> createState() => _PaintingFormScreenState();
}

class _PaintingFormScreenState extends ConsumerState<PaintingFormScreen> {
  final _formKey = GlobalKey<FormState>();

  Painting? _existing;
  final List<File> _newImages = [];
  bool _saving = false;
  bool _analyzing = false;

  // Controllers
  final _title = TextEditingController();
  final _artistName = TextEditingController();
  final _description = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  final _depth = TextEditingController();
  final _weight = TextEditingController();
  final _price = TextEditingController();
  final _location = TextEditingController();
  final _dateCreated = TextEditingController();

  // Selections
  String _category = '';
  String _medium = '';
  String _style = '';
  String _unit = 'cm';
  String _currency = 'USD';
  String _availability = 'Available';
  List<String> _tags = [];

  // Existing images removed during this edit session.
  final Set<String> _removedImages = {};

  // Documents attached to this painting before saving.
  final List<_PendingDoc> _pendingDocs = [];

  // AI results
  String _aiHash = '';
  List<String> _dominantColors = [];
  double _brightness = 0.5;
  double _contrast = 0.5;
  String _orientation = 'Landscape';
  double _complexity = 0.5;
  List<String> _suggestedTags = [];

  bool get isEdit => _existing != null;

  @override
  void initState() {
    super.initState();
    final id = widget.paintingId;
    if (id != null) {
      _existing = PaintingRepository.instance.get(id);
      _hydrate(_existing!);
    } else {
      // New artworks default to the user's preferred currency from Settings
      // instead of always starting as USD.
      _currency = ref.read(currencyProvider);
    }
  }

  /// Opens the calendar picker for the artwork's creation date.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final parsed = DateTime.tryParse(_dateCreated.text);
    final initial = parsed ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'When was this artwork created?',
      cancelText: 'Cancel',
      confirmText: 'OK',
    );
    if (picked != null && mounted) {
      setState(() {
        _dateCreated.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _hydrate(Painting p) {
    _title.text = p.title;
    _artistName.text = p.artistName;
    _description.text = p.description;
    _width.text = p.width?.toString() ?? '';
    _height.text = p.height?.toString() ?? '';
    _depth.text = p.depth?.toString() ?? '';
    _weight.text = p.weight?.toString() ?? '';
    _price.text = p.price?.toString() ?? '';
    _location.text = p.location;
    _dateCreated.text = p.dateCreated ?? '';
    _category = p.category;
    _medium = p.medium;
    _style = p.style;
    _unit = p.dimensionUnit;
    _currency = p.currency;
    _availability = p.availability;
    _tags = [...p.tags];
    _aiHash = p.aiHash;
    _dominantColors = [...p.dominantColors];
    _brightness = p.brightness;
    _contrast = p.contrast;
    _orientation = p.orientation;
    _complexity = p.complexity;
    _suggestedTags = [...p.aiTags];
  }

  @override
  void dispose() {
    for (final c in [
      _title, _artistName, _description, _width, _height, _depth,
      _weight, _price, _location, _dateCreated,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------- Images --

  Future<void> _pickImage(_ImageSource source) async {
    final picker = ImagePicker();
    switch (source) {
      case _ImageSource.gallery:
        final file = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: AppConstants.maxUploadDimension.toDouble(),
          imageQuality: 92,
        );
        if (file != null) await _onImagePicked(File(file.path));
      case _ImageSource.camera:
        final file = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: AppConstants.maxUploadDimension.toDouble(),
          imageQuality: 92,
        );
        if (file != null) await _onImagePicked(File(file.path));
      case _ImageSource.drive:
      case _ImageSource.dropbox:
        // Google Drive & Dropbox surface through the OS document picker when
        // the corresponding apps are installed (Android SAF / iOS Files).
        final result = await FilePicker.pickFiles(type: FileType.image);
        if (result != null) {
          for (final f in result.files) {
            if (f.path != null) await _onImagePicked(File(f.path!));
          }
        }
    }
  }

  Future<void> _onImagePicked(File file) async {
    setState(() {
      _newImages.add(file);
      _analyzing = _newImages.length == 1;
    });
    if (_newImages.length == 1) {
      await _analyze(file);
    }
    if (mounted) setState(() => _analyzing = false);
  }

  /// Picks a certificate / invoice / provenance document and queues it to be
  /// attached to the painting when it is saved.
  Future<void> _pickDocument() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final path = file.path;
    if (path == null || !mounted) return;

    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final type in AppConstants.documentTypes)
              ListTile(
                leading: const Icon(Icons.folder_copy_outlined),
                title: Text(type),
                onTap: () => Navigator.pop(context, type),
              ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) return;
    setState(() {
      _pendingDocs.add(_PendingDoc(type: type, name: file.name, file: File(path)));
    });
  }

  Future<void> _analyze(File file) async {
    setState(() => _analyzing = true);
    try {
      final bytes = await file.readAsBytes();
      final hash = await AiService.instance.hashOfFile(file);
      final analysis = await AiService.instance.analyzeImage(bytes);
      final tags = AiService.instance.suggestTags(analysis);
      if (!mounted) return;
      setState(() {
        _aiHash = hash;
        _dominantColors = analysis.dominantColors;
        _brightness = analysis.brightness;
        _contrast = analysis.contrast;
        _orientation = analysis.orientation;
        _complexity = analysis.complexity;
        _suggestedTags = tags;
        if (_title.text.isEmpty) _title.text = _suggestedTitle();
      });
    } catch (_) {}
  }

  String _suggestedTitle() {
    final mood = _brightness > 0.6 ? 'Bright' : _brightness < 0.35 ? 'Moody' : '';
    final style = _contrast > 0.6 ? 'High Contrast' : '';
    return [mood, style, _suggestedTags.isEmpty ? 'Untitled Artwork' : _suggestedTags.first]
        .where((s) => s.isNotEmpty)
        .join(' ');
  }

  // --------------------------------------------------------------- Save --

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Resolve or create the artist.
    var artistId = _existing?.artistId ?? '';
    final artistName = _artistName.text.trim();
    if (artistName.isNotEmpty) {
      final found = ArtistRepository.instance.findByName(artistName);
      if (found != null) {
        artistId = found.id;
      } else {
        final artist = Artist(
          id: ArtistRepository.newId(),
          name: artistName,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await ArtistRepository.instance.save(artist);
        artistId = artist.id;
      }
    }

    setState(() => _saving = true);
    final now = DateTime.now();

    // Keep existing images that were not removed, mirroring their remote URLs.
    final existingImages = _existing?.images ?? const [];
    final existingUrls = _existing?.imageUrls ?? const [];
    final keptImages = <String>[];
    final keptUrls = <String>[];
    for (var i = 0; i < existingImages.length; i++) {
      if (!_removedImages.contains(existingImages[i])) {
        keptImages.add(existingImages[i]);
        if (i < existingUrls.length) keptUrls.add(existingUrls[i]);
      }
    }
    final originalCover = _existing?.coverImagePath ?? '';
    final keptCover = originalCover.isNotEmpty && !_removedImages.contains(originalCover)
        ? originalCover
        : (keptImages.isNotEmpty ? keptImages.first : '');

    final painting = Painting(
      id: _existing?.id ?? PaintingRepository.newId(),
      title: _title.text.trim(),
      artistId: artistId,
      artistName: artistName.isEmpty ? 'Unknown' : artistName,
      category: _category,
      medium: _medium,
      style: _style,
      description: _description.text.trim(),
      tags: _tags,
      width: double.tryParse(_width.text),
      height: double.tryParse(_height.text),
      depth: double.tryParse(_depth.text),
      dimensionUnit: _unit,
      weight: double.tryParse(_weight.text),
      weightUnit: 'kg',
      price: double.tryParse(_price.text),
      currency: _currency,
      availability: _availability,
      location: _location.text.trim(),
      coverImagePath: keptCover,
      coverImageUrl: _existing?.coverImageUrl ?? '',
      images: keptImages,
      imageUrls: keptUrls,
      aiHash: _aiHash,
      aiTags: _suggestedTags,
      dominantColors: _dominantColors,
      brightness: _brightness,
      contrast: _contrast,
      orientation: _orientation,
      complexity: _complexity,
      styleConfidence: 'Medium',
      isFavorite: _existing?.isFavorite ?? false,
      dateCreated: _dateCreated.text.trim().isEmpty ? null : _dateCreated.text,
      createdAt: _existing?.createdAt ?? now,
      updatedAt: now,
    );

    final saved = await PaintingRepository.instance.save(
      painting,
      newImageFiles: _newImages.isEmpty ? null : _newImages,
    );

    // Attach any documents picked in the form.
    for (final doc in _pendingDocs) {
      await DocumentRepository.instance.add(
        paintingId: saved.id,
        type: doc.type,
        name: doc.name,
        file: doc.file,
      );
    }

    // Physically remove images that were deleted from disk.
    for (final path in _removedImages) {
      await FileStorageService.instance.deleteFile(path);
    }

    // AI duplicate detection for new uploads.
    final duplicates = await PaintingRepository.instance.detectDuplicates(saved);
    setState(() => _saving = false);

    if (!mounted) return;

    if (duplicates.isNotEmpty) {
      final proceed = await _showDuplicateDialog(duplicates.first);
      if (!proceed && mounted) {
        context.pop();
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEdit ? 'Painting updated' : 'Painting added to your vault')),
      );
      context.pop();
    }
  }

  Future<bool> _showDuplicateDialog(DuplicateMatch match) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.content_copy, color: Colors.orange, size: 32),
            title: const Text('Possible duplicate found'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI found "${match.painting.title}" looks '
                  '${Formatters.percent(match.similarity)} similar.',
                ),
                const SizedBox(height: AppSpacing.md),
                if (match.painting.coverImagePath.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: ArtImage(
                      path: match.painting.coverImagePath,
                      url: match.painting.coverImageUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Discard'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Keep anyway'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ------------------------------------------------------------- Build --

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(authProvider).canEdit;
    if (!canEdit) {
      return const Scaffold(
        body: Center(child: Text('You have read-only access.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit painting' : 'Add painting'),
        actions: [
          if (_existing != null)
            IconButton(
              tooltip: 'Duplicate scan',
              icon: const Icon(Icons.auto_fix_high),
              onPressed: () async {
                final dups = await PaintingRepository.instance.detectDuplicates(_existing!);
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Duplicate scan'),
                    content: Text(dups.isEmpty
                        ? 'No likely duplicates found in your collection.'
                        : 'Found ${dups.length} possible duplicate(s):\n${dups.map((d) => '• ${d.painting.title} (${Formatters.percent(d.similarity)})').join('\n')}'),
                  ),
                );
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            _ImagePickerGrid(
              existingPaths: (_existing?.images ?? const [])
                  .where((p) => !_removedImages.contains(p))
                  .toList(),
              newFiles: _newImages,
              analyzing: _analyzing,
              onPick: _pickImage,
              onRemoveNew: (file) => setState(() => _newImages.remove(file)),
              onRemoveExisting: (path) =>
                  setState(() => _removedImages.add(path)),
            ),
            if (_suggestedTags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _AiTagBanner(
                tags: _suggestedTags,
                colors: _dominantColors,
                onAccept: (tag) {
                  if (!_tags.contains(tag)) setState(() => _tags.add(tag));
                },
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _title,
              label: 'Title *',
              icon: Icons.title,
              validator: Validators.required,
            ),
            const SizedBox(height: AppSpacing.md),
            _ArtistField(
              controller: _artistName,
              onManageArtists: () => context.push('/artist/new'),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppDropdown<String>(
                    label: 'Category',
                    value: _category.isEmpty ? null : _category,
                    items: AppConstants.categories,
                    labelFor: (v) => v,
                    icon: Icons.category_outlined,
                    onChanged: (v) => setState(() => _category = v ?? ''),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppDropdown<String>(
                    label: 'Medium',
                    value: _medium.isEmpty ? null : _medium,
                    items: AppConstants.mediums,
                    labelFor: (v) => v,
                    icon: Icons.brush_outlined,
                    onChanged: (v) => setState(() => _medium = v ?? ''),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String>(
              label: 'Style',
              value: _style.isEmpty ? null : _style,
              items: AppConstants.styles,
              labelFor: (v) => v,
              icon: Icons.auto_awesome,
              onChanged: (v) => setState(() => _style = v ?? ''),
            ),
            const SizedBox(height: AppSpacing.md),
            SectionHeader(title: 'Dimensions & weight'),
            Row(
              children: [
                Expanded(child: AppTextField(
                  controller: _width,
                  label: 'Width',
                  icon: Icons.swap_horiz,
                  keyboardType: TextInputType.number,
                  validator: Validators.positiveNumber,
                )),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: AppTextField(
                  controller: _height,
                  label: 'Height',
                  icon: Icons.swap_vert,
                  keyboardType: TextInputType.number,
                  validator: Validators.positiveNumber,
                )),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: AppTextField(
                  controller: _depth,
                  label: 'Depth',
                  icon: Icons.straighten,
                  keyboardType: TextInputType.number,
                  validator: Validators.positiveNumber,
                )),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppDropdown<String>(
                    label: 'Unit',
                    value: _unit,
                    items: AppConstants.dimensionUnits,
                    labelFor: (v) => v,
                    onChanged: (v) => setState(() => _unit = v ?? 'cm'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    controller: _weight,
                    label: 'Weight (kg)',
                    icon: Icons.scale_outlined,
                    keyboardType: TextInputType.number,
                    validator: Validators.positiveNumber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(title: 'Value'),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _price,
                    label: 'Price',
                    prefixText: Formatters.currencySymbol(_currency),
                    keyboardType: TextInputType.number,
                    validator: Validators.positiveNumber,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppDropdown<String>(
                    label: 'Currency',
                    value: _currency,
                    items: AppConstants.currencies,
                    labelFor: (v) => v,
                    onChanged: (v) => setState(() => _currency = v ?? 'USD'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<String>(
              label: 'Availability',
              value: _availability,
              items: AppConstants.availabilityOptions,
              labelFor: (v) => v,
              icon: Icons.sell_outlined,
              onChanged: (v) => setState(() => _availability = v ?? 'Available'),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _location,
              label: 'Location',
              icon: Icons.location_on_outlined,
              hint: 'Studio, gallery, storage…',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _dateCreated,
              label: 'Date created',
              icon: Icons.calendar_month,
              hint: 'Tap the calendar to pick a date',
              readOnly: true,
              onTap: _pickDate,
              // Single highlighted leading calendar: tapping the icon (or the
              // field) opens the picker — no duplicate suffix button.
              onIconTap: _pickDate,
              iconSize: 22,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _description,
              label: 'Description',
              icon: Icons.notes,
              maxLines: 4,
              hint: 'Provenance, story, condition notes…',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTagsField(
              tags: _tags,
              onChanged: (tags) => setState(() => _tags = tags),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(title: 'Documents'),
            _DocumentsPicker(
              pending: _pendingDocs,
              onAdd: _pickDocument,
              onRemove: (doc) => setState(() => _pendingDocs.remove(doc)),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: isEdit ? 'Save changes' : 'Save painting',
              loading: _saving,
              icon: Icons.check_circle_outline,
              onPressed: _save,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _ImagePickerGrid extends StatelessWidget {
  final List<String> existingPaths;
  final List<File> newFiles;
  final bool analyzing;
  final ValueChanged<_ImageSource> onPick;
  final ValueChanged<File> onRemoveNew;
  final ValueChanged<String> onRemoveExisting;

  const _ImagePickerGrid({
    required this.existingPaths,
    required this.newFiles,
    required this.analyzing,
    required this.onPick,
    required this.onRemoveNew,
    required this.onRemoveExisting,
  });

  @override
  Widget build(BuildContext context) {
    final allNew = newFiles.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Images',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1,
          children: [
            for (final path in existingPaths)
              Stack(
                fit: StackFit.expand,
                children: [
                  ArtImage(path: path, borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton(
                      iconSize: 16,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => onRemoveExisting(path),
                    ),
                  ),
                ],
              ),
            for (final file in newFiles)
              Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    child: Image.file(file, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton(
                      iconSize: 16,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => onRemoveNew(file),
                    ),
                  ),
                  if (allNew == 1 && analyzing)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black38,
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            if (existingPaths.length + allNew < AppConstants.maxImagesPerPainting)
              _PickTile(onPick: onPick),
          ],
        ),
      ],
    );
  }
}

class _PickTile extends StatelessWidget {
  final ValueChanged<_ImageSource> onPick;

  const _PickTile({required this.onPick});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        onTap: () => showModalBottomSheet<_ImageSource>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Photo gallery'),
                  onTap: () => Navigator.pop(context, _ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(context, _ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('Google Drive'),
                  onTap: () => Navigator.pop(context, _ImageSource.drive),
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('Dropbox'),
                  onTap: () => Navigator.pop(context, _ImageSource.dropbox),
                ),
              ],
            ),
          ),
        ).then((source) {
          if (source != null) onPick(source);
        }),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined),
            SizedBox(height: AppSpacing.xs),
            Text('Add', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _AiTagBanner extends StatelessWidget {
  final List<String> tags;
  final List<String> colors;
  final ValueChanged<String> onAccept;

  const _AiTagBanner({
    required this.tags,
    required this.colors,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withValues(alpha: 0.10),
            scheme.primary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'AI detected',
                style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final tag in tags)
                ActionChip(
                  label: Text(tag),
                  onPressed: () => onAccept(tag),
                ),
              for (final hex in colors)
                Tooltip(
                  message: 'Add colour ${hex.toUpperCase()}',
                  child: InkWell(
                    onTap: () => onAccept(hex.toUpperCase()),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: ImageUtils.colorFromHex(hex),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArtistField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onManageArtists;

  const _ArtistField({required this.controller, required this.onManageArtists});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField(
            controller: controller,
            label: 'Artist / painter',
            icon: Icons.person_outline,
            hint: 'Type a name or pick from artists',
            capitalization: TextCapitalization.words,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            onPressed: onManageArtists,
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('New'),
          ),
        ),
      ],
    );
  }
}

/// A document queued in the form and attached after the painting is saved.
class _PendingDoc {
  final String type;
  final String name;
  final File file;

  const _PendingDoc({required this.type, required this.name, required this.file});
}

/// Document upload section inside the painting form.
class _DocumentsPicker extends StatelessWidget {
  final List<_PendingDoc> pending;
  final VoidCallback onAdd;
  final ValueChanged<_PendingDoc> onRemove;

  const _DocumentsPicker({
    required this.pending,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  pending.isEmpty
                      ? 'Attach certificates, invoices, provenance, insurance…'
                      : '${pending.length} document(s) to attach',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            for (final doc in pending)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(Icons.description_outlined, size: 20, color: scheme.primary),
                title: Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(doc.type, style: const TextStyle(fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onRemove(doc),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
