import 'dart:convert';
import 'package:http/http.dart' as http;

enum AiProvider { openai, gemini }

class AiChatService {
  static const _openaiUrl = 'https://api.openai.com/v1/chat/completions';
  static const _openaiModelsUrl = 'https://api.openai.com/v1/models';
  static const _geminiModelsUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static String _geminiUrl(String apiKey, String model) =>
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

  static const _systemPrompt =
      'You are a helpful sleep coach. The user will share their sleep diary '
      'statistics. Provide brief, actionable, and friendly advice to help them '
      'improve their sleep. Keep responses concise (3-5 sentences). '
      'Focus on patterns you notice and one or two specific suggestions.';

  /// Send a message to the configured AI provider and return the response.
  static Future<String> ask({
    required String apiKey,
    required AiProvider provider,
    required String statsSummary,
    required String userMessage,
    String? model,
  }) async {
    switch (provider) {
      case AiProvider.openai:
        return _askOpenAi(apiKey, statsSummary, userMessage, model);
      case AiProvider.gemini:
        return _askGemini(apiKey, statsSummary, userMessage, model);
    }
  }

  static Future<String> _askOpenAi(
    String apiKey,
    String statsSummary,
    String userMessage,
    String? model,
  ) async {
    final selectedModel = model?.trim().isNotEmpty == true
        ? model!.trim()
        : 'gpt-4o-mini';
    final response = await http.post(
      Uri.parse(_openaiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': selectedModel,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {
            'role': 'user',
            'content': 'Here are my sleep stats:\n$statsSummary',
          },
          {'role': 'user', 'content': userMessage},
        ],
        'max_tokens': 1024,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List;
      if (choices.isNotEmpty) {
        return (choices[0]['message']['content'] as String).trim();
      }
      return 'No response received.';
    } else {
      if (response.statusCode == 401) {
        return 'Invalid API key. Please check your OpenAI key in settings.';
      }
      if (response.statusCode == 429) {
        return 'OpenAI quota exceeded. You need to add billing and purchase '
            'credits at platform.openai.com. Alternatively, switch to Gemini '
            'in settings — it offers a free tier.';
      }
      return 'OpenAI error (${response.statusCode}). Please try again later.';
    }
  }

  static final Map<String, String?> _cachedGeminiModels = {};

  static Future<List<String>> listOpenAiModels(String apiKey) async {
    final response = await http.get(
      Uri.parse(_openaiModelsUrl),
      headers: {'Authorization': 'Bearer $apiKey'},
    );
    if (response.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = data['data'] as List? ?? [];
    final availableModels = <String>[];

    for (final model in models) {
      final id = (model['id'] as String?) ?? '';
      final isChatModel =
          id.startsWith('gpt-') ||
          id.startsWith('o1') ||
          id.startsWith('o3') ||
          id.startsWith('o4');
      final isExcluded =
          id.contains('audio') ||
          id.contains('realtime') ||
          id.contains('search') ||
          id.contains('transcribe') ||
          id.contains('tts') ||
          id.contains('image') ||
          id.contains('embed');

      if (isChatModel && !isExcluded) {
        availableModels.add(id);
      }
    }

    const preferredOrder = [
      'gpt-4o-mini',
      'gpt-4.1-mini',
      'gpt-4.1',
      'gpt-4o',
      'o4-mini',
      'o3-mini',
      'o1-mini',
    ];

    availableModels.sort((a, b) {
      final ai = preferredOrder.indexOf(a);
      final bi = preferredOrder.indexOf(b);
      if (ai != -1 && bi != -1) return ai.compareTo(bi);
      if (ai != -1) return -1;
      if (bi != -1) return 1;
      return a.compareTo(b);
    });

    return availableModels;
  }

  static Future<String> _askGemini(
    String apiKey,
    String statsSummary,
    String userMessage,
    String? model,
  ) async {
    final selectedModel = await _resolveGeminiModel(apiKey, model);
    if (selectedModel == null) {
      return 'No Gemini models available for your API key. '
          'Please check your key or try creating a new one at aistudio.google.com.';
    }

    final response = await http.post(
      Uri.parse(_geminiUrl(apiKey, selectedModel)),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text':
                    '$_systemPrompt\n\nHere are my sleep stats:\n$statsSummary\n\nUser question: $userMessage',
              },
            ],
          },
        ],
        'generationConfig': {
          'maxOutputTokens': 2048,
          'temperature': 0.7,
          'thinkingConfig': {'thinkingBudget': 0},
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final parts = candidates[0]['content']['parts'] as List;
        if (parts.isNotEmpty) {
          return (parts[0]['text'] as String).trim();
        }
      }
      return 'No response received.';
    } else {
      if (response.statusCode == 400 || response.statusCode == 403) {
        return 'Invalid API key. Please check your Gemini key in settings.';
      }
      if (response.statusCode == 429) {
        return 'Gemini rate limit reached. The free tier allows ~15 requests '
            'per minute. Please wait a moment and try again.';
      }
      return 'Gemini error (${response.statusCode}): ${response.body}';
    }
  }

  static Future<String?> _resolveGeminiModel(
    String apiKey,
    String? requestedModel,
  ) async {
    if (requestedModel != null && requestedModel.trim().isNotEmpty) {
      return requestedModel.trim();
    }
    if (_cachedGeminiModels.containsKey(apiKey)) {
      return _cachedGeminiModels[apiKey];
    }
    final discoveredModel = await _findGeminiModel(apiKey);
    _cachedGeminiModels[apiKey] = discoveredModel;
    return discoveredModel;
  }

  static Future<List<String>> listGeminiModels(String apiKey) async {
    final response = await http.get(Uri.parse('$_geminiModelsUrl?key=$apiKey'));
    if (response.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = data['models'] as List? ?? [];
    final availableModels = <String>[];

    for (final model in models) {
      final id = (model['name'] as String?) ?? '';
      final methods =
          (model['supportedGenerationMethods'] as List?)?.cast<String>() ?? [];
      if (methods.contains('generateContent') && id.startsWith('models/')) {
        availableModels.add(id.replaceFirst('models/', ''));
      }
    }

    const preferredOrder = [
      'gemini-2.5-flash',
      'gemini-2.5-pro',
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
      'gemini-flash-latest',
      'gemini-pro-latest',
    ];

    availableModels.sort((a, b) {
      final ai = preferredOrder.indexOf(a);
      final bi = preferredOrder.indexOf(b);
      if (ai != -1 && bi != -1) return ai.compareTo(bi);
      if (ai != -1) return -1;
      if (bi != -1) return 1;
      return a.compareTo(b);
    });

    return availableModels;
  }

  /// Calls ListModels to find a model that supports generateContent.
  static Future<String?> _findGeminiModel(String apiKey) async {
    final models = await listGeminiModels(apiKey);
    if (models.isEmpty) return null;
    return models.first;
  }
}
