import pathlib

p = pathlib.Path(r'lib/features/painting/painting_form_screen.dart')
content = p.read_text(encoding='utf-8')

# Replace the entire Autocomplete block with a cleaner implementation
old_autocomplete = """        Autocomplete<Artist>(
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
            // The Autocomplete widget sets its internal controller to the
            // display string. We also sync the external form controller.
            controller.text = artist.name;
            // Force the form to pick up the change
            controller.selection = TextSelection.collapsed(
              offset: artist.name.length,
            );
          },
          fieldViewBuilder:
              (context, textController, focusNode, onSubmitted) {
            // Sync external controller changes
            if (textController.text != controller.text) {
              textController.text = controller.text;
              textController.selection = TextSelection.collapsed(
                offset: controller.text.length,
              );
            }
            return TextFormField(
              controller: textController,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
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
          // Allow free-text input (new artist name) even if no match
        ),"""

new_autocomplete = """        Autocomplete<Artist>(
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
        ),"""

content = content.replace(old_autocomplete, new_autocomplete)
p.write_text(content, encoding='utf-8')
print("PaintingForm: fixed Autocomplete sync with onChanged")
