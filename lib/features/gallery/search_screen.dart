import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/ai_service.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/surfaces.dart';
import '../../core/providers/providers.dart';
import '../../data/models/painting.dart';
import 'painting_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  SearchQuery? _query;
  bool _listening = false;
  bool _speechReady = false;
  String _spoken = '';

  /// Live-search debounce: search is fully local (pure CPU), so results can
  /// update as the user types — but only after a short pause so every
  /// keystroke doesn't churn the list.
  static const _debounceDuration = Duration(milliseconds: 280);
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    // Speech is an optional enhancement — a missing plugin or mic failure
    // must never break opening or using search.
    try {
      final ok = await _speech.initialize();
      if (mounted) setState(() => _speechReady = ok);
    } catch (_) {
      _speechReady = false;
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {
      // Mic teardown can race with dispose — never let it throw.
    }
  }

  /// Live search as the user types (debounced), with an instant reset back
  /// to the suggestions screen once the field is cleared.
  void _onTextChanged(String text) {
    _debounce?.cancel();
    if (text.trim().isEmpty) {
      if (_query != null) setState(() => _query = null);
      return;
    }
    _debounce = Timer(_debounceDuration, () {
      if (mounted) _runSearch(text);
    });
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await _speech.stop();
      return;
    }
    if (!_speechReady) {
      final ok = await _speech.initialize();
      if (!ok) return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenFor: const Duration(seconds: 20),
        localeId: 'en_US',
      ),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _spoken = result.recognizedWords;
      if (result.finalResult) {
        _controller.text = _spoken;
        _runSearch(_spoken);
        _listening = false;
      }
    });
  }

  void _runSearch(String raw) {
    final artists = ref.read(artistsProvider).valueOrNull ?? const [];
    final query = AiService.instance.parseQuery(raw, artists: artists);
    setState(() => _query = query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paintings = ref.watch(paintingsProvider).valueOrNull ?? const [];
    final results = _query == null ? <Painting>[] : AiService.instance.applyQuery(paintings, _query!);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Try "blue oil paintings"…',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: _onTextChanged,
                onSubmitted: _runSearch,
              ),
            ),
            IconButton(
              tooltip: _listening ? 'Listening…' : 'Voice search',
              onPressed: _toggleListen,
              icon: Icon(
                _listening ? Icons.mic : Icons.mic_none,
                color: _listening ? scheme.primary : null,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _runSearch(_controller.text),
            child: const Text('Search'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_listening)
            Container(
              width: double.infinity,
              color: scheme.primary.withValues(alpha: 0.08),
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.graphic_eq, color: scheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _spoken.isEmpty ? 'Listening…' : _spoken,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(),
          if (_query == null)
            Expanded(
              child: _Suggestions(
                onSuggestion: (text) {
                  _controller.text = text;
                  _runSearch(text);
                },
              ),
            )
          else if (results.isEmpty)
            const Expanded(
              child: EmptyState(
                icon: Icons.search_off,
                title: 'No matches',
                subtitle: 'Try different words — artist names, mediums, colors or sizes.',
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      '${results.length} result${results.length == 1 ? '' : 's'} for "${_query.toString()}"',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  // Results cascade in one after another, echoing the
                  // gallery grid — each match settles into place.
                  for (final (i, painting) in results.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      key: ValueKey('search-${painting.id}'),
                      child: revealListItem(
                        PaintingListTile(painting: painting),
                        i,
                        context: context,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  final ValueChanged<String> onSuggestion;

  const _Suggestions({required this.onSuggestion});

  static const _chips = [
    'Show all oil paintings',
    'Find artworks by Ravi',
    'Open latest upload',
    'Find blue paintings',
    'Paintings larger than 100 cm',
    'Show watercolor landscapes',
    'Modern abstract art',
    'Gold accent pieces',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        Text(
          'Smart search',
          style: AppTheme.display(context, size: 22),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Speak or type naturally — "paintings larger than 100 cm" just works.',
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        GlassCard(
          padding: AppSpacing.cardPadding,
          child: Column(
            children: [
              for (var i = 0; i < _chips.length; i++) ...[
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.auto_awesome, size: 18),
                  title: Text(_chips[i], style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.north_west, size: 16),
                  onTap: () => onSuggestion(_chips[i]),
                ),
                if (i < _chips.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
