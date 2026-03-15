import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;

import '../data/sleep_content.dart';
import '../services/ai_chat_service.dart';
import '../services/radio_browser_service.dart';
import '../services/sleep_audio_service.dart';
import '../services/storage_service.dart';
import '../widgets/ai_settings_dialog.dart';

class CantSleepScreen extends StatefulWidget {
  final StorageService storage;

  const CantSleepScreen({super.key, required this.storage});

  @override
  State<CantSleepScreen> createState() => _CantSleepScreenState();
}

class _CantSleepScreenState extends State<CantSleepScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Material(
          color: isDark ? Colors.grey[900] : Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: isDark ? Colors.white : Colors.deepPurple,
            unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[600],
            indicatorColor: Colors.deepPurple,
            tabs: const [
              Tab(icon: Icon(Icons.headphones), text: 'Listen'),
              Tab(icon: Icon(Icons.menu_book), text: 'Read'),
              Tab(icon: Icon(Icons.air), text: 'Breathe'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ListenTab(),
              _ReadTab(storage: widget.storage),
              const _BreatheTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Audiobooks Section Widget ---
// --- Audiobooks Section Widget ---
class _Audiobook {
  final String title;
  final String author;
  final String duration;
  final String url;
  const _Audiobook({
    required this.title,
    required this.author,
    required this.duration,
    required this.url,
  });
}

const _audiobooks = [
  _Audiobook(
    title: 'The Secret Garden',
    author: 'Frances Hodgson Burnett',
    duration: '7h 45m',
    url: 'https://www.archive.org/download/secretgarden_1007_librivox/secretgarden_1007_librivox.m3u',
  ),
  _Audiobook(
    title: 'A Child’s Garden of Verses',
    author: 'Robert Louis Stevenson',
    duration: '1h 20m',
    url: 'https://www.archive.org/download/childsgardenofverses_0907_librivox/childsgardenofverses_0907_librivox.m3u',
  ),
  _Audiobook(
    title: 'Fairy Tales by Hans Christian Andersen',
    author: 'Hans Christian Andersen',
    duration: '5h 10m',
    url: 'https://www.archive.org/download/fairytales_0707_librivox/fairytales_0707_librivox.m3u',
  ),
];

class _AudiobooksSection extends StatefulWidget {
  @override
  State<_AudiobooksSection> createState() => _AudiobooksSectionState();
}

class _AudiobooksSectionState extends State<_AudiobooksSection> {
  final AudioPlayer _player = AudioPlayer();
  int? _playingIndex;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Recommended Audiobooks',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ),
        for (int i = 0; i < _audiobooks.length; i++)
          Card(
            color: isDark ? Colors.deepPurple[900] : Colors.deepPurple[50],
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple,
                child: Icon(Icons.headphones, color: Colors.white),
              ),
              title: Text(_audiobooks[i].title),
              subtitle: Text('${_audiobooks[i].author} · ${_audiobooks[i].duration}'),
              trailing: _playingIndex == i && _player.playing
                  ? Icon(Icons.pause)
                  : Icon(Icons.play_arrow),
              onTap: () async {
                try {
                  if (_playingIndex == i && _player.playing) {
                    await _player.pause();
                    setState(() {});
                    return;
                  }
                  // Fetch M3U and extract first MP3 URL
                  final m3uResp = await http.get(Uri.parse(_audiobooks[i].url));
                  final lines = m3uResp.body.split(RegExp(r'\r?\n'));
                  final mp3Url = lines.firstWhere(
                    (l) => l.trim().endsWith('.mp3') && !l.trim().startsWith('#'),
                    orElse: () => '',
                  );
                  if (mp3Url.isEmpty) throw Exception('No MP3 found in playlist');
                  await _player.setUrl(mp3Url.trim());
                  await _player.play();
                  setState(() => _playingIndex = i);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Playback error: ${e.toString()}'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
          ),
      ],
    );
  }
}
// ─── Listen Tab ───

class _ListenTab extends StatefulWidget {
  @override
  State<_ListenTab> createState() => _ListenTabState();
}

class _ListenTabState extends State<_ListenTab> {
  final _audio = SleepAudioService();
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    // Refresh UI every second for timer countdown & player state
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive =
        _audio.player.processingState != ProcessingState.idle &&
        _audio.currentTitle.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Now Playing card
        if (isActive) ...[
          _buildNowPlaying(isDark),
          const SizedBox(height: 12),
        ],

        // Generated Sounds section
        _sectionHeader('Sleep Sounds', 'No ads · Works offline · Background play', isDark),
        const SizedBox(height: 8),
        _buildNoiseGrid(isDark),
        const SizedBox(height: 16),

        // Radio section
        _sectionHeader('Radio Stations', 'Ad-free streams · Background play · 40,000+ stations', isDark),
        const SizedBox(height: 8),
        _buildSearchBar(isDark),
        const SizedBox(height: 10),
        _buildBrowseCategories(isDark),
        const SizedBox(height: 10),
        Text(
          '  Recommended',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        ...radioStations.map((station) => _buildRadioTile(station, isDark)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _sectionHeader(String title, String subtitle, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Now Playing ───

  Widget _buildNowPlaying(bool isDark) {
    final isPlaying = _audio.player.playing;
    final timerRemaining = _audio.sleepTimerRemaining;

    return Card(
      color: isDark ? Colors.deepPurple[900] : Colors.deepPurple[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.music_note,
                  color: Colors.deepPurple[300],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _audio.currentTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _audio.currentCategory,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: () async {
                    await _audio.togglePlayPause();
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: () async {
                    await _audio.stop();
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Volume slider
            Row(
              children: [
                Icon(Icons.volume_down, size: 18,
                    color: isDark ? Colors.grey[400] : Colors.grey[600]),
                Expanded(
                  child: StreamBuilder<double>(
                    stream: _audio.player.volumeStream,
                    builder: (context, snapshot) {
                      final vol = snapshot.data ?? 1.0;
                      return Slider(
                        value: vol,
                        min: 0,
                        max: 1,
                        onChanged: (v) => _audio.player.setVolume(v),
                        activeColor: Colors.deepPurple,
                      );
                    },
                  ),
                ),
                Icon(Icons.volume_up, size: 18,
                    color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ],
            ),
            // Sleep timer row
            Row(
              children: [
                Icon(Icons.timer, size: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  timerRemaining != null
                      ? 'Stops in ${timerRemaining.inMinutes}:${(timerRemaining.inSeconds % 60).toString().padLeft(2, '0')}'
                      : 'Sleep Timer',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const Spacer(),
                ..._timerChips(timerRemaining != null),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _timerChips(bool timerActive) {
    if (timerActive) {
      return [
        ActionChip(
          label: const Text('Cancel', style: TextStyle(fontSize: 11)),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            _audio.cancelSleepTimer();
            setState(() {});
          },
        ),
      ];
    }
    return [
      for (final mins in [15, 30, 45, 60])
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: ActionChip(
            label: Text('${mins}m', style: const TextStyle(fontSize: 11)),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              _audio.setSleepTimer(Duration(minutes: mins));
              setState(() {});
            },
          ),
        ),
    ];
  }

  // ─── Noise Grid ───

  Widget _buildNoiseGrid(bool isDark) {
    const noiseItems = [
      (NoiseType.white, 'White Noise', Icons.graphic_eq, Color(0xFF78909C)),
      (NoiseType.pink, 'Pink Noise', Icons.waves, Color(0xFFE91E63)),
      (NoiseType.brown, 'Brown Noise', Icons.terrain, Color(0xFF795548)),
    ];

    return Row(
      children: noiseItems.map((item) {
        final (type, title, icon, color) = item;
        final isThis = _audio.currentTitle == title && _audio.player.playing;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: isThis
                  ? (isDark ? color.withValues(alpha: 0.4) : color.withValues(alpha: 0.2))
                  : (isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.08)),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  await _audio.playNoise(type);
                  setState(() {});
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(icon, size: 30, color: color),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey[800],
                        ),
                      ),
                      if (isThis) ...[
                        const SizedBox(height: 4),
                        Icon(Icons.equalizer, size: 14, color: color),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Radio Tiles ───

  Widget _buildRadioTile(RadioStation station, bool isDark) {
    final isThis =
        _audio.currentTitle == station.title && _audio.player.playing;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: isThis
          ? (isDark ? station.color.withValues(alpha: 0.3) : station.color.withValues(alpha: 0.1))
          : (isDark ? Colors.grey[850] : null),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: station.color,
          radius: 18,
          child: Icon(station.icon, color: Colors.white, size: 18),
        ),
        title: Text(station.title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          station.subtitle,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
        trailing: isThis
            ? Icon(Icons.equalizer, color: station.color)
            : const Icon(Icons.play_arrow, size: 20),
        onTap: () async {
          try {
            await _audio.playStream(station.streamUrl, station.title);
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Station unavailable — try another one'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          setState(() {});
        },
      ),
    );
  }

  // ─── Browse Categories ───

  Widget _buildBrowseCategories(bool isDark) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: radioBrowseCategories.map((cat) {
        return ActionChip(
          avatar: Icon(cat.icon, size: 16, color: cat.color),
          label: Text(cat.label, style: const TextStyle(fontSize: 12)),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _RadioBrowsePage(
                  title: cat.label,
                  tag: cat.tag,
                  color: cat.color,
                  audio: _audio,
                  onChanged: () { if (mounted) setState(() {}); },
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  // ─── Search Bar ───

  Widget _buildSearchBar(bool isDark) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search radio stations...',
        prefixIcon: const Icon(Icons.search, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: (query) {
        if (query.trim().isEmpty) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _RadioBrowsePage(
              title: 'Search: ${query.trim()}',
              searchQuery: query.trim(),
              color: Colors.deepPurple,
              audio: _audio,
              onChanged: () { if (mounted) setState(() {}); },
            ),
          ),
        );
      },
    );
  }
}

// ─── Radio Browse Page ───

class _RadioBrowsePage extends StatefulWidget {
  final String title;
  final String? tag;
  final String? searchQuery;
  final Color color;
  final SleepAudioService audio;
  final VoidCallback onChanged;

  const _RadioBrowsePage({
    required this.title,
    this.tag,
    this.searchQuery,
    required this.color,
    required this.audio,
    required this.onChanged,
  });

  @override
  State<_RadioBrowsePage> createState() => _RadioBrowsePageState();
}

class _RadioBrowsePageState extends State<_RadioBrowsePage> {
  List<RadioBrowserStation>? _stations;
  bool _loading = true;
  String? _error;
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _loadStations();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStations() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    List<RadioBrowserStation> results;
    if (widget.searchQuery != null) {
      results = await RadioBrowserService.searchByName(widget.searchQuery!);
    } else if (widget.tag != null) {
      results = await RadioBrowserService.searchByTag(widget.tag!);
    } else {
      results = [];
    }

    if (!mounted) return;

    setState(() {
      _stations = results;
      _loading = false;
      if (results.isEmpty) {
        _error = 'No stations found. Try a different search.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && (_stations == null || _stations!.isEmpty)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.radio, size: 48,
                            color: isDark ? Colors.grey[600] : Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _loadStations,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _stations!.length,
                  itemBuilder: (context, index) {
                    final station = _stations![index];
                    return _buildBrowseStationTile(station, isDark);
                  },
                ),
    );
  }

  Widget _buildBrowseStationTile(RadioBrowserStation station, bool isDark) {
    final isThis =
        widget.audio.currentTitle == station.name && widget.audio.player.playing;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      color: isThis
          ? (isDark
              ? widget.color.withValues(alpha: 0.3)
              : widget.color.withValues(alpha: 0.1))
          : (isDark ? Colors.grey[850] : null),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: widget.color.withValues(alpha: 0.8),
          radius: 18,
          child: const Icon(Icons.radio, color: Colors.white, size: 18),
        ),
        title: Text(
          station.name,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (station.country.isNotEmpty) station.country,
            if (station.tags.isNotEmpty)
              station.tags.split(',').take(3).join(', '),
          ].join(' · '),
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isThis
            ? Icon(Icons.equalizer, color: widget.color)
            : const Icon(Icons.play_arrow, size: 20),
        onTap: () async {
          try {
            await widget.audio.playStream(station.url, station.name);
            widget.onChanged();
          } catch (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Station unavailable — try another one'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          setState(() {});
        },
      ),
    );
  }
}

// ─── Read Tab ───

class _ReadTab extends StatelessWidget {
  final StorageService storage;

  const _ReadTab({required this.storage});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Gentle stories to quiet your mind',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        // AI story generator card
        _AiStoryCard(storage: storage),
        const SizedBox(height: 8),
        ...sleepStories.map(
          (story) => _StoryCard(story: story),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Audiobooks (Librivox)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.deepPurple[200] : Colors.deepPurple,
            ),
          ),
        ),
        _AudiobooksSection(),
      ],
    );
  }
}

class _StoryCard extends StatelessWidget {
  final SleepStory story;

  const _StoryCard({required this.story});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isDark ? Colors.grey[850] : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isDark ? Colors.deepPurple[300] : Colors.deepPurple[100],
          child: Icon(
            Icons.auto_stories,
            color: isDark ? Colors.white : Colors.deepPurple,
            size: 20,
          ),
        ),
        title: Text(story.title),
        subtitle: Text(
          '${story.duration} · ${story.preview}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _StoryReaderPage(story: story),
          ),
        ),
      ),
    );
  }
}

class _StoryReaderPage extends StatelessWidget {
  final SleepStory story;

  const _StoryReaderPage({required this.story});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(story.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              story.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'By ${story.author} · ${story.duration}',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              story.body,
              style: TextStyle(
                fontSize: 17,
                height: 1.8,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                '— sweet dreams —',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── AI Story Card ───

class _AiStoryCard extends StatefulWidget {
  final StorageService storage;

  const _AiStoryCard({required this.storage});

  @override
  State<_AiStoryCard> createState() => _AiStoryCardState();
}

class _AiStoryCardState extends State<_AiStoryCard> {
  bool _loading = false;

  static const _themes = [
    'a cozy cabin in the mountains during a snowstorm',
    'a slow boat ride through quiet canals at dusk',
    'a sleepy village surrounded by lavender fields',
    'a cat napping in a warm sunbeam in a library',
    'a gentle walk through a misty bamboo forest',
    'an old telescope pointed at a sky full of stars',
    'a cottage garden at twilight with fireflies',
    'drifting on a cloud above sleeping meadows',
    'a warm tea shop on a rainy autumn evening',
    'a quiet beach where bioluminescent waves glow softly',
  ];

  Future<void> _generateStory() async {
    final apiKey = widget.storage.aiApiKey;
    if (apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set up your AI API key in Dashboard → AI Settings first.',
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    final theme = _themes[Random().nextInt(_themes.length)];
    final providerStr = widget.storage.aiProvider;
    final provider =
        providerStr == 'openai' ? AiProvider.openai : AiProvider.gemini;
    final model = provider == AiProvider.openai
        ? widget.storage.aiOpenAiModel
        : widget.storage.aiGeminiModel;

    try {
      final story = await AiChatService.ask(
        apiKey: apiKey,
        provider: provider,
        statsSummary: '',
        userMessage:
            'Write a calming bedtime story (about 400 words) to help someone '
            'fall asleep. Theme: $theme. Use gentle, descriptive language with '
            'sensory details. No conflict or tension. End peacefully with the '
            'character falling asleep. Do not include a title — just the story.',
        model: model,
      );

      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _StoryReaderPage(
            story: SleepStory(
              title: 'AI Sleep Story',
              author: 'Generated by AI',
              duration: 'Just for you',
              preview: theme,
              body: story,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate story: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDark ? Colors.deepPurple[900] : Colors.deepPurple[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
        ),
        title: const Text('Generate a Sleep Story'),
        subtitle: Text(
          'AI writes a unique bedtime story just for you',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        trailing: _loading
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings, size: 20),
                    tooltip: 'AI Settings',
                    onPressed: () => showAiSettingsDialog(
                      context,
                      widget.storage,
                      onSaved: () => setState(() {}),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
        onTap: _loading ? null : _generateStory,
      ),
    );
  }
}

// ─── Breathe Tab ───

class _BreatheTab extends StatefulWidget {
  const _BreatheTab();

  @override
  State<_BreatheTab> createState() => _BreatheTabState();
}

class _BreatheTabState extends State<_BreatheTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isRunning = false;

  // 4-7-8 breathing: inhale 4s, hold 7s, exhale 8s = 19s cycle
  static const _inhale = 4;
  static const _hold = 7;
  static const _exhale = 8;
  static const _cycle = _inhale + _hold + _exhale; // 19 seconds

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _cycle),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      if (_isRunning) {
        _controller.stop();
        _controller.reset();
        _isRunning = false;
      } else {
        _controller.repeat();
        _isRunning = true;
      }
    });
  }

  String _getPhaseText(double value) {
    final second = value * _cycle;
    if (second < _inhale) return 'Breathe In';
    if (second < _inhale + _hold) return 'Hold';
    return 'Breathe Out';
  }

  int _getPhaseCountdown(double value) {
    final second = value * _cycle;
    if (second < _inhale) return _inhale - second.floor();
    if (second < _inhale + _hold) {
      return (_inhale + _hold) - second.floor();
    }
    return _cycle - second.floor();
  }

  double _getCircleScale(double value) {
    final second = value * _cycle;
    if (second < _inhale) {
      // Expanding during inhale
      return 0.5 + 0.5 * (second / _inhale);
    }
    if (second < _inhale + _hold) {
      // Full during hold
      return 1.0;
    }
    // Shrinking during exhale
    final exhaleProgress = (second - _inhale - _hold) / _exhale;
    return 1.0 - 0.5 * exhaleProgress;
  }

  Color _getPhaseColor(double value) {
    final second = value * _cycle;
    if (second < _inhale) return Colors.blue[300]!;
    if (second < _inhale + _hold) return Colors.purple[300]!;
    return Colors.teal[300]!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '4-7-8 Breathing',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A technique to calm your nervous system',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final value = _controller.value;
                final scale = _isRunning ? _getCircleScale(value) : 0.5;
                final color = _isRunning
                    ? _getPhaseColor(value)
                    : (isDark ? Colors.grey[700]! : Colors.grey[300]!);

                return SizedBox(
                  height: 220,
                  width: 220,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 180 * scale,
                      width: 180 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.3),
                        border: Border.all(color: color, width: 3),
                      ),
                      child: Center(
                        child: _isRunning
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _getPhaseText(value),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_getPhaseCountdown(value)}',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                ],
                              )
                            : Icon(
                                Icons.air,
                                size: 40,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[400],
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: _toggle,
              icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
              label: Text(_isRunning ? 'Stop' : 'Start Breathing'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!_isRunning)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey[850]
                      : Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'How it works',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _breatheStep(
                      '1',
                      'Breathe in through your nose',
                      '4 seconds',
                      Colors.blue[300]!,
                    ),
                    _breatheStep(
                      '2',
                      'Hold your breath',
                      '7 seconds',
                      Colors.purple[300]!,
                    ),
                    _breatheStep(
                      '3',
                      'Exhale slowly through your mouth',
                      '8 seconds',
                      Colors.teal[300]!,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _breatheStep(
    String step,
    String text,
    String duration,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: color,
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          Text(
            duration,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
