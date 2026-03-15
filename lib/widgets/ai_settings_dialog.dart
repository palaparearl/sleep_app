import 'package:flutter/material.dart';

import '../services/ai_chat_service.dart';
import '../services/storage_service.dart';

const List<String> openAiModelOptions = [
  'gpt-4o-mini',
  'gpt-4.1-mini',
  'gpt-4.1',
  'gpt-4o',
];

Future<void> showAiSettingsDialog(
  BuildContext context,
  StorageService storage, {
  VoidCallback? onSaved,
}) async {
  final keyController = TextEditingController(text: storage.aiApiKey);
  var selectedProvider = storage.aiProvider;
  var selectedGeminiModel = storage.aiGeminiModel;
  var selectedOpenAiModel = storage.aiOpenAiModel;
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
                          items: openAiModels
                              .map(
                                (model) => DropdownMenuItem<String>(
                                  value: model,
                                  child: Text(model),
                                ),
                              )
                              .toList(),
                          onChanged: openAiModels.isEmpty
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setDialogState(
                                      () => selectedOpenAiModel = value);
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
                  await storage.setAiApiKey(keyController.text.trim());
                  await storage.setAiProvider(selectedProvider);
                  await storage.setAiGeminiModel(selectedGeminiModel);
                  await storage.setAiOpenAiModel(selectedOpenAiModel);
                  if (context.mounted) Navigator.pop(context);
                  onSaved?.call();
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
