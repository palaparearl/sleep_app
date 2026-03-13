import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/models.dart';
import '../services/sleep_stats_service.dart';
import '../services/smart_insights_service.dart';
import '../services/ai_chat_service.dart';
import '../services/storage_service.dart';
import '../app.dart';

class DashboardScreen extends StatefulWidget {
  final Map<DateTime, List<SleepRecord>> sleepData;
  final List<CoffeeRecord> coffeeRecords;
  final List<MedicineRecord> medicineRecords;
  final List<AlcoholRecord> alcoholRecords;
  final StorageService storage;

  const DashboardScreen({
    super.key,
    required this.sleepData,
    required this.coffeeRecords,
    required this.medicineRecords,
    required this.alcoholRecords,
    required this.storage,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const List<String> _openAiModelOptions = [
    'gpt-4o-mini',
    'gpt-4.1-mini',
    'gpt-4.1',
    'gpt-4o',
  ];

  final TextEditingController _aiInputController = TextEditingController();
  String? _aiResponse;
  bool _aiLoading = false;

  @override
  void dispose() {
    _aiInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MyApp.of(context)?.isDarkMode ?? false;
    final stats7 = SleepStatsService.dailyStats(widget.sleepData, 7);
    final stats30 = SleepStatsService.dailyStats(widget.sleepData, 30);
    final avg7 = SleepStatsService.averageDuration(stats7);
    final avgBedtime = SleepStatsService.averageBedtime(stats7);
    final avgWake = SleepStatsService.averageWakeTime(stats7);
    final consistency = SleepStatsService.consistencyScore(stats7);
    final totalNights = SleepStatsService.totalNightsTracked(widget.sleepData);
    final best = SleepStatsService.bestNight(stats30);
    final worst = SleepStatsService.worstNight(stats30);
    final (thisWeekAvg, lastWeekAvg) = SleepStatsService.weeklyComparison(
      widget.sleepData,
    );

    final coffeeCount7 = SleepStatsService.countActivitiesInRange(
      widget.coffeeRecords,
      (r) => r.startDate,
      7,
    );
    final alcoholCount7 = SleepStatsService.countActivitiesInRange(
      widget.alcoholRecords,
      (r) => r.startDate,
      7,
    );
    final medicineCount7 = SleepStatsService.countActivitiesInRange(
      widget.medicineRecords,
      (r) => r.startDate,
      7,
    );

    final insights = SmartInsightsService.generateInsights(
      sleepData: widget.sleepData,
      coffeeRecords: widget.coffeeRecords,
      alcoholRecords: widget.alcoholRecords,
      medicineRecords: widget.medicineRecords,
    );

    final cardColor = isDark ? const Color(0xFF1F2940) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Summary Cards Row ---
        _buildSummaryRow(
          avg7: avg7,
          avgBedtime: avgBedtime,
          avgWake: avgWake,
          totalNights: totalNights,
          cardColor: cardColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
        ),
        const SizedBox(height: 16),

        // --- Sleep Duration Chart (7 days) ---
        _buildChartCard(
          title: 'Sleep Duration — Last 7 Days',
          cardColor: cardColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
          child: SizedBox(
            height: 200,
            child: _SleepBarChart(stats: stats7, isDark: isDark),
          ),
        ),
        const SizedBox(height: 16),

        // --- Consistency & Weekly Comparison ---
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.speed,
                iconColor: _consistencyColor(consistency),
                label: 'Consistency',
                value: '${consistency.toInt()}%',
                subtitle: consistency >= 80
                    ? 'Great regularity!'
                    : consistency >= 50
                    ? 'Room to improve'
                    : 'Try a steady schedule',
                cardColor: cardColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: _weeklyTrendIcon(thisWeekAvg, lastWeekAvg),
                iconColor: _weeklyTrendColor(thisWeekAvg, lastWeekAvg),
                label: 'vs Last Week',
                value: SleepStatsService.formatHours(thisWeekAvg),
                subtitle: lastWeekAvg > 0
                    ? 'Last: ${SleepStatsService.formatHours(lastWeekAvg)}'
                    : 'No data last week',
                cardColor: cardColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // --- Best / Worst Night ---
        if (best != null && worst != null && best.date != worst.date)
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.star,
                  iconColor: Colors.amber,
                  label: 'Best Night (30d)',
                  value: SleepStatsService.formatHours(best.totalHours),
                  subtitle: _formatShortDate(best.date),
                  cardColor: cardColor,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.warning_amber_rounded,
                  iconColor: Colors.redAccent,
                  label: 'Worst Night (30d)',
                  value: SleepStatsService.formatHours(worst.totalHours),
                  subtitle: _formatShortDate(worst.date),
                  cardColor: cardColor,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                ),
              ),
            ],
          ),
        if (best != null && worst != null && best.date != worst.date)
          const SizedBox(height: 16),

        // --- Activity Summary ---
        _buildChartCard(
          title: 'Activity Summary — Last 7 Days',
          cardColor: cardColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActivityBadge(
                  label: 'Coffee',
                  count: coffeeCount7,
                  color: Colors.brown,
                  icon: Icons.coffee,
                ),
                _ActivityBadge(
                  label: 'Alcohol',
                  count: alcoholCount7,
                  color: Colors.redAccent,
                  icon: Icons.local_bar,
                ),
                _ActivityBadge(
                  label: 'Medicine',
                  count: medicineCount7,
                  color: Colors.green,
                  icon: Icons.medication,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // --- 30-Day Trend ---
        _buildChartCard(
          title: 'Sleep Trend — Last 30 Days',
          cardColor: cardColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
          child: SizedBox(
            height: 180,
            child: _SleepLineChart(stats: stats30, isDark: isDark),
          ),
        ),
        const SizedBox(height: 16),

        // --- Smart Insights ---
        _buildInsightsCard(
          insights: insights,
          cardColor: cardColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
        ),
        const SizedBox(height: 16),

        // --- Ask AI ---
        _buildAskAiCard(
          cardColor: cardColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
          isDark: isDark,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // --- Smart Insights Card ---

  Widget _buildInsightsCard({
    required List<SleepInsight> insights,
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Smart Insights',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...insights.map(
              (insight) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(insight.icon, color: insight.color, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            insight.description,
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: subtitleColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'These insights are generated from your data using simple rules '
                    'and are not medical advice. For sleep concerns, please consult '
                    'a healthcare professional or sleep specialist.',
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Ask AI Card ---

  Widget _buildAskAiCard({
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
    required bool isDark,
  }) {
    final hasKey = widget.storage.aiApiKey.isNotEmpty;
    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.deepPurple, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ask AI Sleep Coach',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.settings, size: 20, color: subtitleColor),
                  onPressed: () => _showAiSettingsDialog(context),
                  tooltip: 'AI Settings',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasKey)
              Text(
                'Configure your API key in settings (⚙) to ask AI for personalized sleep advice.',
                style: TextStyle(color: subtitleColor, fontSize: 12),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _aiInputController,
                      decoration: InputDecoration(
                        hintText: 'e.g. "How can I improve my sleep?"',
                        hintStyle: TextStyle(
                          color: subtitleColor,
                          fontSize: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                      style: TextStyle(color: textColor, fontSize: 13),
                      maxLines: 2,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _askAi(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _aiLoading
                      ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: Icon(Icons.send, color: Colors.deepPurple),
                          onPressed: _askAi,
                        ),
                ],
              ),
              if (_aiResponse != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.deepPurple.withValues(alpha: 0.15)
                        : Colors.deepPurple.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: Colors.deepPurple,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AI Response',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _aiResponse!,
                        style: TextStyle(color: textColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: subtitleColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'AI responses are for informational purposes only and not a substitute '
                    'for professional medical advice. Always consult a qualified healthcare '
                    'provider or sleep doctor for any sleep-related concerns.',
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _askAi() async {
    final message = _aiInputController.text.trim();
    if (message.isEmpty) return;

    final apiKey = widget.storage.aiApiKey;
    if (apiKey.isEmpty) return;

    final providerStr = widget.storage.aiProvider;
    final provider = providerStr == 'openai'
        ? AiProvider.openai
        : AiProvider.gemini;
    final model = provider == AiProvider.openai
        ? widget.storage.aiOpenAiModel
        : widget.storage.aiGeminiModel;

    final summary = SmartInsightsService.buildStatsSummary(
      sleepData: widget.sleepData,
      coffeeRecords: widget.coffeeRecords,
      alcoholRecords: widget.alcoholRecords,
      medicineRecords: widget.medicineRecords,
    );

    setState(() {
      _aiLoading = true;
      _aiResponse = null;
    });

    try {
      final response = await AiChatService.ask(
        apiKey: apiKey,
        provider: provider,
        statsSummary: summary,
        userMessage: message,
        model: model,
      );
      if (mounted) {
        setState(() {
          _aiResponse = response;
          _aiLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiResponse = 'Failed to connect: $e';
          _aiLoading = false;
        });
      }
    }
  }

  void _showAiSettingsDialog(BuildContext context) {
    final keyController = TextEditingController(text: widget.storage.aiApiKey);
    var selectedProvider = widget.storage.aiProvider;
    var selectedGeminiModel = widget.storage.aiGeminiModel;
    var selectedOpenAiModel = widget.storage.aiOpenAiModel;
    var geminiModels = <String>[];
    var openAiModels = <String>[];
    var isLoadingGeminiModels = false;
    var isLoadingOpenAiModels = false;
    String? geminiModelsError;
    String? openAiModelsError;

    Future<void> loadGeminiModels(StateSetter setDialogState) async {
      final apiKey = keyController.text.trim();
      if (apiKey.isEmpty) {
        setDialogState(() {
          geminiModels = [];
          geminiModelsError = 'Enter a Gemini API key to load models.';
          isLoadingGeminiModels = false;
        });
        return;
      }

      setDialogState(() {
        isLoadingGeminiModels = true;
        geminiModelsError = null;
      });

      final models = await AiChatService.listGeminiModels(apiKey);

      setDialogState(() {
        isLoadingGeminiModels = false;
        geminiModels = models;
        if (models.isEmpty) {
          geminiModelsError = 'No Gemini models were found for this key.';
          return;
        }
        geminiModelsError = null;
        if (!models.contains(selectedGeminiModel)) {
          selectedGeminiModel = models.first;
        }
      });
    }

    Future<void> loadOpenAiModels(StateSetter setDialogState) async {
      final apiKey = keyController.text.trim();
      if (apiKey.isEmpty) {
        setDialogState(() {
          openAiModels = [];
          openAiModelsError = 'Enter an OpenAI API key to load models.';
          isLoadingOpenAiModels = false;
        });
        return;
      }

      setDialogState(() {
        isLoadingOpenAiModels = true;
        openAiModelsError = null;
      });

      final models = await AiChatService.listOpenAiModels(apiKey);

      setDialogState(() {
        isLoadingOpenAiModels = false;
        openAiModels = models;
        if (models.isEmpty) {
          openAiModelsError = 'No OpenAI models were found for this key.';
          return;
        }
        openAiModelsError = null;
        if (!models.contains(selectedOpenAiModel)) {
          selectedOpenAiModel = models.first;
        }
      });
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (selectedProvider == 'gemini' &&
                geminiModels.isEmpty &&
                !isLoadingGeminiModels &&
                geminiModelsError == null) {
              Future.microtask(() => loadGeminiModels(setDialogState));
            }
            if (selectedProvider == 'openai' &&
                openAiModels.isEmpty &&
                !isLoadingOpenAiModels &&
                openAiModelsError == null) {
              Future.microtask(() => loadOpenAiModels(setDialogState));
            }

            return AlertDialog(
              title: const Text('AI Settings'),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 64,
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 96,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Provider',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'gemini',
                              label: Text('Gemini'),
                            ),
                            ButtonSegment(
                              value: 'openai',
                              label: Text('OpenAI'),
                            ),
                          ],
                          selected: {selectedProvider},
                          onSelectionChanged: (set) {
                            setDialogState(() {
                              selectedProvider = set.first;
                              if (selectedProvider == 'gemini' &&
                                  geminiModels.isEmpty) {
                                geminiModelsError = null;
                              }
                              if (selectedProvider == 'openai' &&
                                  openAiModels.isEmpty) {
                                openAiModelsError = null;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: keyController,
                          decoration: InputDecoration(
                            labelText: 'API Key',
                            hintText: selectedProvider == 'gemini'
                                ? 'Enter Gemini API key'
                                : 'Enter OpenAI API key',
                            border: const OutlineInputBorder(),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedProvider == 'gemini'
                                    ? 'Gemini Model'
                                    : 'OpenAI Model',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (selectedProvider == 'gemini')
                              IconButton(
                                icon: isLoadingGeminiModels
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh, size: 18),
                                onPressed: isLoadingGeminiModels
                                    ? null
                                    : () => loadGeminiModels(setDialogState),
                                tooltip: 'Load available Gemini models',
                                visualDensity: VisualDensity.compact,
                              )
                            else
                              IconButton(
                                icon: isLoadingOpenAiModels
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.refresh, size: 18),
                                onPressed: isLoadingOpenAiModels
                                    ? null
                                    : () => loadOpenAiModels(setDialogState),
                                tooltip: 'Load available OpenAI models',
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (selectedProvider == 'gemini') ...[
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: geminiModels.contains(selectedGeminiModel)
                                ? selectedGeminiModel
                                : null,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                              hintText: 'Load Gemini models for this key',
                            ),
                            items: geminiModels
                                .map(
                                  (model) => DropdownMenuItem<String>(
                                    value: model,
                                    child: Text(
                                      model == 'gemini-2.5-flash'
                                          ? '$model (free)'
                                          : model,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: geminiModels.isEmpty
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setDialogState(
                                      () => selectedGeminiModel = value,
                                    );
                                  },
                          ),
                          if (geminiModelsError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              geminiModelsError!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red[300],
                              ),
                            ),
                          ],
                        ] else ...[
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: openAiModels.contains(selectedOpenAiModel)
                                ? selectedOpenAiModel
                                : null,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                              hintText: 'Load OpenAI models for this key',
                            ),
                            items:
                                (openAiModels.isEmpty
                                        ? _openAiModelOptions
                                        : openAiModels)
                                    .map(
                                      (model) => DropdownMenuItem<String>(
                                        value: model,
                                        child: Text(model),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setDialogState(() => selectedOpenAiModel = value);
                            },
                          ),
                          if (openAiModelsError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              openAiModelsError!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red[300],
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 8),
                        Text(
                          selectedProvider == 'gemini'
                              ? 'Get a free key at aistudio.google.com'
                              : 'Get a key at platform.openai.com',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (selectedProvider == 'gemini') ...[
                          const SizedBox(height: 6),
                          Text(
                            'gemini-2.5-flash is the recommended free Gemini option.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await widget.storage.setAiApiKey(keyController.text.trim());
                    await widget.storage.setAiProvider(selectedProvider);
                    await widget.storage.setAiGeminiModel(selectedGeminiModel);
                    await widget.storage.setAiOpenAiModel(selectedOpenAiModel);
                    if (context.mounted) Navigator.pop(context);
                    setState(() {});
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Helpers ---

  Widget _buildSummaryRow({
    required double avg7,
    required TimeOfDay? avgBedtime,
    required TimeOfDay? avgWake,
    required int totalNights,
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'Avg Sleep',
            value: SleepStatsService.formatHours(avg7),
            icon: Icons.bedtime,
            iconColor: Colors.indigo,
            cardColor: cardColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            label: 'Bedtime',
            value: avgBedtime != null
                ? SleepStatsService.formatTime(avgBedtime)
                : '--:--',
            icon: Icons.nightlight_round,
            iconColor: Colors.deepPurple,
            cardColor: cardColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            label: 'Wake Up',
            value: avgWake != null
                ? SleepStatsService.formatTime(avgWake)
                : '--:--',
            icon: Icons.wb_sunny,
            iconColor: Colors.orange,
            cardColor: cardColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryTile(
            label: 'Tracked',
            value: '$totalNights',
            icon: Icons.calendar_today,
            iconColor: Colors.teal,
            cardColor: cardColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: subtitleColor, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
    required Widget child,
  }) {
    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Color _consistencyColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.redAccent;
  }

  IconData _weeklyTrendIcon(double thisWeek, double lastWeek) {
    if (lastWeek == 0) return Icons.horizontal_rule;
    if (thisWeek > lastWeek + 0.25) return Icons.trending_up;
    if (thisWeek < lastWeek - 0.25) return Icons.trending_down;
    return Icons.trending_flat;
  }

  Color _weeklyTrendColor(double thisWeek, double lastWeek) {
    if (lastWeek == 0) return Colors.grey;
    if (thisWeek > lastWeek + 0.25) return Colors.green;
    if (thisWeek < lastWeek - 0.25) return Colors.redAccent;
    return Colors.orange;
  }

  String _formatShortDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

// ---------- Summary Tile ----------

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color cardColor;
  final Color textColor;
  final Color subtitleColor;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.cardColor,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(color: subtitleColor, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Bar Chart (7 days) ----------

class _SleepBarChart extends StatelessWidget {
  final List<DailySleepStat> stats;
  final bool isDark;

  const _SleepBarChart({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final barColor = isDark ? const Color(0xFF5C6BC0) : Colors.indigo;
    final maxY = stats.fold(0.0, (m, s) => s.totalHours > m ? s.totalHours : m);
    final ceiling = (maxY + 2).ceilToDouble().clamp(4.0, 16.0);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: ceiling,
        minY: 0,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                SleepStatsService.formatHours(rod.toY),
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: ceiling > 8 ? 2 : 1,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}h',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= stats.length) return const SizedBox.shrink();
                final d = stats[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _shortDay(d),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ceiling > 8 ? 2 : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white12 : Colors.black12,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(stats.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: stats[i].totalHours,
                color: barColor,
                width: 18,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  String _shortDay(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }
}

// ---------- Line Chart (30 days) ----------

class _SleepLineChart extends StatelessWidget {
  final List<DailySleepStat> stats;
  final bool isDark;

  const _SleepLineChart({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final lineColor = isDark ? const Color(0xFF7986CB) : Colors.indigo;
    final spots = <FlSpot>[];
    for (int i = 0; i < stats.length; i++) {
      spots.add(FlSpot(i.toDouble(), stats[i].totalHours));
    }

    final maxY = stats.fold(0.0, (m, s) => s.totalHours > m ? s.totalHours : m);
    final ceiling = (maxY + 2).ceilToDouble().clamp(4.0, 16.0);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: ceiling,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItems: (spots) => spots.map((s) {
              final idx = s.x.toInt();
              final date = idx >= 0 && idx < stats.length
                  ? stats[idx].date
                  : null;
              final dateStr = date != null ? '${date.month}/${date.day}' : '';
              return LineTooltipItem(
                '$dateStr\n${SleepStatsService.formatHours(s.y)}',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: ceiling > 8 ? 2 : 1,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}h',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 7,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= stats.length) return const SizedBox.shrink();
                final d = stats[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${d.month}/${d.day}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ceiling > 8 ? 2 : 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? Colors.white12 : Colors.black12,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: lineColor,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Activity Badge ----------

class _ActivityBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _ActivityBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MyApp.of(context)?.isDarkMode ?? false;
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          '$count',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
