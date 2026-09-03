import 'package:artvault/utils/io_shim.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/pro_limits.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/providers/providers.dart';
import '../../features/pro/pro_celebration.dart';
import '../../features/pro/upgrade_prompt.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_fields.dart';
import '../../core/widgets/bits.dart';
import '../../core/widgets/surfaces.dart';
import '../../data/models/artist.dart';
import '../../data/repositories/artist_repository.dart';

class ArtistFormScreen extends ConsumerStatefulWidget {
  final String? artistId;

  const ArtistFormScreen({super.key, this.artistId});

  @override
  ConsumerState<ArtistFormScreen> createState() => _ArtistFormScreenState();
}

class _ArtistFormScreenState extends ConsumerState<ArtistFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nationality = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();
  final _bio = TextEditingController();

  final List<String> _awards = [];
  final List<String> _exhibitions = [];
  File? _photo;
  Artist? _existing;
  bool _saving = false;

  bool get isEdit => _existing != null;

  @override
  void initState() {
    super.initState();
    final id = widget.artistId;
    if (id != null) {
      _existing = ArtistRepository.instance.get(id);
      final a = _existing;
      if (a != null) {
        _name.text = a.name;
        _nationality.text = a.nationality;
        _phone.text = a.phone;
        _email.text = a.email;
        _website.text = a.website;
        _instagram.text = a.instagram;
        _facebook.text = a.facebook;
        _bio.text = a.biography;
        _awards.addAll(a.awards);
        _exhibitions.addAll(a.exhibitions);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _nationality,
      _phone,
      _email,
      _website,
      _instagram,
      _facebook,
      _bio,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (file != null) setState(() => _photo = File(file.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Prevent duplicate artist names.
    final name = _name.text.trim();
    if (ArtistRepository.instance.existsByName(
      name,
      excludeId: _existing?.id,
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An artist named "$name" already exists.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Free-tier capacity gate for new artists.
    final isNew = _existing == null;
    if (isNew && !ref.read(authProvider).isPro) {
      final active =
          ref
              .read(artistsProvider)
              .valueOrNull
              ?.where((a) => !a.isDeleted)
              .length ??
          ArtistRepository.instance.readAll().where((a) => !a.isDeleted).length;
      if (active >= ProLimits.freeArtists) {
        await showUpgradePrompt(
          context,
          feature: 'Adding more than ${ProLimits.freeArtists} artists',
        );
        return;
      }
    }

    setState(() => _saving = true);

    final artist = Artist(
      id: _existing?.id ?? ArtistRepository.newId(),
      name: _name.text.trim(),
      photoPath: _existing?.photoPath ?? '',
      photoUrl: _existing?.photoUrl ?? '',
      biography: _bio.text.trim(),
      nationality: _nationality.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      website: _website.text.trim(),
      instagram: _instagram.text.trim(),
      facebook: _facebook.text.trim(),
      awards: _awards,
      exhibitions: _exhibitions,
      createdAt: _existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ArtistRepository.instance.save(artist, photoFile: _photo);
    if (!mounted) return;
    // New artists always get the celebration (replay skips the cooldown so
    // every addition fires confetti, however frequent).
    if (isNew) {
      await showConfettiCelebration(
        context,
        id: 'artist-added',
        title: 'Artist added!',
        message: '${artist.name} is now in your artists.',
        icon: Icons.person_add,
        iconLabel: 'Saved to collection',
        replay: true,
        celebratory: true,
      );
      if (!mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isEdit ? 'Artist updated' : 'Artist added')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit artist' : 'New artist')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            Center(
              child: Stack(
                children: [
                  Avatar(
                    name: _name.text.isEmpty ? 'New Artist' : _name.text,
                    imagePath: _photo?.path ?? _existing?.photoPath,
                    imageUrl: _existing?.photoUrl,
                    radius: 46,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Material(
                      color: Theme.of(context).colorScheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickPhoto,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _name,
              label: 'Full name *',
              icon: Icons.person_outline,
              validator: Validators.name,
              capitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _nationality,
              label: 'Nationality',
              icon: Icons.flag_outlined,
              capitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _bio,
              label: 'Biography',
              icon: Icons.article_outlined,
              maxLines: 5,
              hint: 'Life story, training, signature style…',
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(title: 'Contact'),
            AppTextField(
              controller: _phone,
              label: 'Phone',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _email,
              label: 'Email',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _website,
              label: 'Website',
              icon: Icons.public,
              keyboardType: TextInputType.url,
              validator: Validators.url,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _instagram,
              label: 'Instagram',
              icon: Icons.camera_alt_outlined,
              hint: '@handle',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _facebook,
              label: 'Facebook',
              icon: Icons.facebook,
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(title: 'Awards'),
            GlassCard(
              padding: AppSpacing.cardPadding,
              child: AppTagsField(
                tags: _awards,
                onChanged: (tags) => setState(
                  () => _awards
                    ..clear()
                    ..addAll(tags),
                ),
                hint: 'Add an award and press Enter',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(title: 'Exhibitions'),
            GlassCard(
              padding: AppSpacing.cardPadding,
              child: AppTagsField(
                tags: _exhibitions,
                onChanged: (tags) => setState(
                  () => _exhibitions
                    ..clear()
                    ..addAll(tags),
                ),
                hint: 'Add an exhibition and press Enter',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: isEdit ? 'Save changes' : 'Add artist',
              loading: _saving,
              onPressed: _save,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
