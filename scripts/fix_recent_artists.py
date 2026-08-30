import pathlib

p = pathlib.Path(r'lib/features/painting/painting_form_screen.dart')
c = p.read_text(encoding='utf-8')

# Replace the _ArtistField widget to include recently used artists
old_widget = '''class _ArtistField extends ConsumerWidget {
  final TextEditingController controller;
  final VoidCallback onManageArtists;

  const _ArtistField({required this.controller, required this.onManageArtists});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(artistsProvider).valueOrNull ?? const [];
    final activeArtists =
        artists.where((a) => !a.isDeleted).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          fieldViewBuilder:
              (context, textController, focusNode, onSubmitted) {
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
                labelText: 'Artist / painter',
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
        ),'''

new_widget = '''class _ArtistField extends ConsumerWidget {
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
    final activeArtists =
        artists.where((a) => !a.isDeleted).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    final recentNames = _recentArtistNames(paintings);
    // Map recent names to actual Artist objects when available
    final recentArtists = recentNames
        .map((name) => activeArtists.firstWhere(
              (a) => a.name.toLowerCase() == name.toLowerCase(),
              orElse: () => Artist(
                id: '',
                name: name,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            ))
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
              separatorBuilder: (_, __) => const SizedBox(width: 8),
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
                  label: Text(artist.name, style: const TextStyle(fontSize: 12)),
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
          fieldViewBuilder:
              (context, textController, focusNode, onSubmitted) {
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
        ),'''

c = c.replace(old_widget, new_widget)
p.write_text(c, encoding='utf-8')
print("Added recently used artists + required label")
