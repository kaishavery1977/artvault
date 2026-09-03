import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:artvault/utils/image_helper.dart';
// ignore_for_file: deprecated_member_use
import 'package:artvault/utils/io_shim.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/pro_limits.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/file_storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_fields.dart';
import '../../core/widgets/art_image.dart';
import '../../core/providers/providers.dart';
import '../../features/pro/pro_celebration.dart';
import '../../features/pro/upgrade_prompt.dart';
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
  final _lat = TextEditingController();
  final _lng = TextEditingController();
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
    _lat.text = p.lat?.toString() ?? '';
    _lng.text = p.lng?.toString() ?? '';
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
      _title,
      _artistName,
      _description,
      _width,
      _height,
      _depth,
      _weight,
      _price,
      _location,
      _lat,
      _lng,
      _dateCreated,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _buildPriceHistory(
    Painting? existing,
    double? newPrice,
  ) {
    if (existing == null || newPrice == null || newPrice == existing.price) {
      return existing?.priceHistory ?? const [];
    }
    final entry = {
      'date': DateTime.now().toIso8601String(),
      'value': newPrice,
      'currency': _currency,
    };
    return [...existing.priceHistory, entry];
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
        final result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'heic'],
          allowMultiple: true,
          withData: false,
        );
        if (result != null) {
          for (final f in result.files) {
            if (f.path != null) await _onImagePicked(File(f.path!));
          }
        }
    }
  }

  Future<void> _onImagePicked(File file) async {
    const maxBytes = 5 * 1024 * 1024;
    final len = await file.length();
    if (len > maxBytes) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Large image'),
          content: Text(
            'This image is ${(len / 1024 / 1024).toStringAsFixed(1)} MB — over the 5 MB limit. '
            'We can compress it to under 5 MB with high quality so you can add it now. Proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Compress & add'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      // Compress on isolate, keep quality 85 and max 2400, loop reducing quality until <5MB
      file = await _compressUnder5MB(file);
      final newLen = await file.length();
      if (newLen > maxBytes && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Still ${(newLen / 1024 / 1024).toStringAsFixed(1)} MB after compression — try a smaller image.',
            ),
          ),
        );
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Compressed to ${(newLen / 1024 / 1024).toStringAsFixed(1)} MB — quality kept high.',
            ),
          ),
        );
      }
    }
    // Free-tier storage gate: originals beyond 100 MB need Pro.
    if (!ref.read(authProvider.select((a) => a.isPro))) {
      final usage = ref.read(storageUsageProvider).valueOrNull;
      final current = usage?.countedBytes ?? 0;
      if (current + await file.length() > ProLimits.freeStorageBytes) {
        if (!mounted) return;
        await showUpgradePrompt(
          context,
          feature:
              'Storing more than ${ProLimits.freeStorageBytes ~/ (1024 * 1024)} MB '
              'of original artwork files',
        );
        return;
      }
    }
    setState(() {
      _newImages.add(file);
      _analyzing = _newImages.length == 1;
    });
    if (_newImages.length == 1) {
      await _analyze(file);
    }
    if (mounted) setState(() => _analyzing = false);
  }

  Future<File> _compressUnder5MB(File file) async {
    for (final q in [85, 80, 75]) {
      final out = await ImageUtils.compress(
        file,
        maxDimension: 2400,
        quality: q,
      );
      if (await out.length() < 5 * 1024 * 1024) return out;
      file = out;
      if (await file.length() < 5 * 1024 * 1024) return file;
    }
    return file;
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
      _pendingDocs.add(
        _PendingDoc(type: type, name: file.name, file: File(path)),
      );
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
    final mood = _brightness > 0.6
        ? 'Bright'
        : _brightness < 0.35
        ? 'Moody'
        : '';
    final style = _contrast > 0.6 ? 'High Contrast' : '';
    return [
      mood,
      style,
      _suggestedTags.isEmpty ? 'Untitled Artwork' : _suggestedTags.first,
    ].where((s) => s.isNotEmpty).join(' ');
  }

  // --------------------------------------------------------------- Save --

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isNew = _existing == null;

    // Block empty paintings: require at least a title or an image.
    if (isNew) {
      final hasTitle = _title.text.trim().isNotEmpty;
      final hasImages = _newImages.isNotEmpty;
      // Keep existing images that were not removed.
      final existingKept = (_existing?.images ?? const []).any(
        (p) => p.isNotEmpty && !_removedImages.contains(p),
      );
      if (!hasTitle && !hasImages && !existingKept) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add a title or at least one image')),
          );
        }
        return;
      }
    }

    // Require an artist name for new paintings.
    if (isNew && _artistName.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select or create an artist for this painting',
            ),
          ),
        );
      }
      return;
    }

    // Free-tier capacity gate: block new paintings past the cap and point
    // the user at the upgrade flow.
    if (isNew && !ref.read(authProvider).isPro) {
      final active =
          ref.read(paintingsProvider).valueOrNull?.length ??
          PaintingRepository.instance.countActive();
      if (active >= ProLimits.freePaintings) {
        await showUpgradePrompt(
          context,
          feature: 'Adding more than ${ProLimits.freePaintings} artworks',
        );
        return;
      }
    }

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
    final keptCover =
        originalCover.isNotEmpty && !_removedImages.contains(originalCover)
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
      lat: double.tryParse(_lat.text),
      lng: double.tryParse(_lng.text),
      provenance: _existing?.provenance ?? const [],
      priceHistory: _buildPriceHistory(_existing, double.tryParse(_price.text)),
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
    final duplicates = await PaintingRepository.instance.detectDuplicates(
      saved,
    );
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
      // New artworks always get the full celebration — every addition is
      // its own moment, so the confetti replays no matter how often the
      // user adds (replay skips the once-per-cooldown suppression).
      if (isNew) {
        await showConfettiCelebration(
          context,
          id: 'painting-added',
          title: 'Painting added!',
          message: '\u201c${painting.title}\u201d is now part of your vault.',
          icon: Icons.brush,
          iconLabel: 'Saved to vault',
          replay: true,
          celebratory: true,
        );
        if (!mounted) return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit ? 'Painting updated' : 'Painting added to your vault',
          ),
        ),
      );
      context.pop();
    }
  }

  Future<bool> _showDuplicateDialog(DuplicateMatch match) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.content_copy,
              color: Colors.orange,
              size: 32,
            ),
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
    final canEdit = ref.watch(authProvider.select((a) => a.canEdit));
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
                final dups = await PaintingRepository.instance.detectDuplicates(
                  _existing!,
                );
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Duplicate scan'),
                    content: Text(
                      dups.isEmpty
                          ? 'No likely duplicates found in your collection.'
                          : 'Found ${dups.length} possible duplicate(s):\n${dups.map((d) => '• ${d.painting.title} (${Formatters.percent(d.similarity)})').join('\n')}',
                    ),
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
            // ── Basics section (expanded by default) ──
            _FormSection(
              title: 'Basics',
              icon: Icons.info_outline,
              child: Column(
                children: [
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
                ],
              ),
            ),
            // ── Dimensions section (expanded by default)
            _FormSection(
              title: 'Dimensions & weight',
              icon: Icons.straighten,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _width,
                          label: 'Width',
                          icon: Icons.swap_horiz,
                          keyboardType: TextInputType.number,
                          validator: Validators.positiveNumber,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField(
                          controller: _height,
                          label: 'Height',
                          icon: Icons.swap_vert,
                          keyboardType: TextInputType.number,
                          validator: Validators.positiveNumber,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField(
                          controller: _depth,
                          label: 'Depth',
                          icon: Icons.straighten,
                          keyboardType: TextInputType.number,
                          validator: Validators.positiveNumber,
                        ),
                      ),
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
                ],
              ),
            ),
            // ── Value section (expanded by default)
            _FormSection(
              title: 'Value & location',
              icon: Icons.account_balance_wallet,
              child: Column(
                children: [
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
                          onChanged: (v) =>
                              setState(() => _currency = v ?? 'USD'),
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
                    onChanged: (v) =>
                        setState(() => _availability = v ?? 'Available'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _location,
                    label: 'Location',
                    icon: Icons.location_on_outlined,
                    hint: 'Studio, gallery, storage…',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _lat,
                          label: 'Latitude',
                          icon: Icons.map_outlined,
                          hint: 'e.g. 48.86',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField(
                          controller: _lng,
                          label: 'Longitude',
                          icon: Icons.map_outlined,
                          hint: 'e.g. 2.33',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_lat.text.isNotEmpty && _lng.text.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          final lat = _lat.text.trim();
                          final lng = _lng.text.trim();
                          launchUrl(
                            Uri.parse(
                              'https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=15/$lat/$lng',
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open in map'),
                      ),
                    ),
                ],
              ),
            ),
            // ── Details section (expanded by default)
            _FormSection(
              title: 'Details & description',
              icon: Icons.notes,
              child: Column(
                children: [
                  AppTextField(
                    controller: _dateCreated,
                    label: 'Date created',
                    icon: Icons.calendar_month,
                    hint: 'Tap the calendar to pick a date',
                    readOnly: true,
                    onTap: _pickDate,
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
                ],
              ),
            ),
            // ── Documents section (collapsed by default)
            _FormSection(
              title: 'Documents',
              icon: Icons.folder_outlined,
              initiallyExpanded: false,
              child: _DocumentsPicker(
                pending: _pendingDocs,
                onAdd: _pickDocument,
                onRemove: (doc) => setState(() => _pendingDocs.remove(doc)),
              ),
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
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Only JPEG, PNG, WEBP, HEIC (max 5 MB each) — larger images will be compressed with high quality.',
          style: TextStyle(
            fontSize: 11.5,
            color: Color(0xFF6B7280),
            height: 1.3,
          ),
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
                  ArtImage(
                    path: path,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton(
                      tooltip: 'Remove image',
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
                    child: kIsWeb
                        ? const Icon(Icons.image, size: 48)
                        : nativeImage(file),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: IconButton(
                      tooltip: 'Remove image',
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
            if (existingPaths.length + allNew <
                AppConstants.maxImagesPerPainting)
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
        onTap: () =>
            showModalBottomSheet<_ImageSource>(
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
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final tag in tags)
                ActionChip(label: Text(tag), onPressed: () => onAccept(tag)),
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

/// Collapsible accordion section for the painting form.
/// Shows a header with icon + title + chevron, expands/collapses on tap.
class _FormSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  const _FormSection({
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = true,
  });

  @override
  State<_FormSection> createState() => _FormSectionState();
}

class _FormSectionState extends State<_FormSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late final AnimationController _animCtrl;
  late final Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: _expanded ? 1.0 : 0.0,
    );
    _heightFactor = _animCtrl.drive(CurveTween(curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: _expanded
                  ? scheme.primary.withValues(alpha: 0.15)
                  : scheme.outlineVariant.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  child: Row(
                    children: [
                      Icon(widget.icon, size: 18, color: scheme.primary),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: _heightFactor.value,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArtistField extends ConsumerWidget {
  final TextEditingController controller;
  final VoidCallback onManageArtists;

  const _ArtistField({required this.controller, required this.onManageArtists});

  /// Returns the most recently used artist names (unique, newest first)
  /// by scanning the latest paintings sorted by updatedAt.
  List<String> _recentArtistNames(List<dynamic> paintings) {
    final seen = <String>{};
    final result = <String>[];
    // paintings come sorted from provider; iterate newest first
    for (final p in paintings.reversed) {
      final name = (p as dynamic).artistName as String;
      if (name.isNotEmpty && !seen.contains(name.toLowerCase())) {
        seen.add(name.toLowerCase());
        result.add(name);
      }
      if (result.length >= 5) break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(artistsProvider).valueOrNull ?? const [];
    final paintings = ref.watch(paintingsProvider).valueOrNull ?? const [];
    final activeArtists = artists.where((a) => !a.isDeleted).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final recentNames = _recentArtistNames(paintings);
    // Map recent names to actual Artist objects when available
    final recentArtists = recentNames
        .map(
          (name) => activeArtists.firstWhere(
            (a) => a.name.toLowerCase() == name.toLowerCase(),
            orElse: () => Artist(
              id: '',
              name: name,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
        )
        .toList();

    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recently used artists chips (shown when field is empty)
        if (recentArtists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              'Recently used',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recentArtists.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final artist = recentArtists[index];
                return ActionChip(
                  avatar: CircleAvatar(
                    radius: 10,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      artist.name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  label: Text(
                    artist.name,
                    style: const TextStyle(fontSize: 12),
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    controller.text = artist.name;
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Autocomplete<Artist>(
          initialValue: TextEditingValue(
            text: controller.text,
            selection: TextSelection.collapsed(offset: controller.text.length),
          ),
          displayStringForOption: (a) => a.name,
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.toLowerCase();
            if (query.isEmpty) return activeArtists;
            return activeArtists
                .where((a) => a.name.toLowerCase().contains(query))
                .toList();
          },
          onSelected: (artist) {
            controller.text = artist.name;
          },
          fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
            // Sync external controller changes (e.g. from edit mode)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (textController.text != controller.text) {
                textController.text = controller.text;
                textController.selection = TextSelection.collapsed(
                  offset: controller.text.length,
                );
              }
            });
            return TextFormField(
              controller: textController,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
              onChanged: (value) {
                // Keep external controller in sync as user types
                controller.text = value;
              },
              decoration: InputDecoration(
                labelText: 'Artist / painter *',
                hintText: activeArtists.isEmpty
                    ? 'Type a name or add artists first'
                    : 'Start typing to search existing artists',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final artist = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: scheme.primaryContainer,
                          child: Text(
                            artist.name.isNotEmpty
                                ? artist.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        title: Text(
                          artist.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: artist.nationality.isNotEmpty
                            ? Text(
                                artist.nationality,
                                style: const TextStyle(fontSize: 11),
                              )
                            : null,
                        onTap: () => onSelected(artist),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onManageArtists,
            icon: const Icon(Icons.person_add, size: 16),
            label: const Text(
              'Create new artist',
              style: TextStyle(fontSize: 12),
            ),
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

  const _PendingDoc({
    required this.type,
    required this.name,
    required this.file,
  });
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
                leading: Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: scheme.primary,
                ),
                title: Text(
                  doc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(doc.type, style: const TextStyle(fontSize: 11)),
                trailing: IconButton(
                  tooltip: 'Remove document',
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
