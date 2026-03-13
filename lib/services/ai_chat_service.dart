import 'dart:convert';
import 'package:http/http.dart' as http;

enum AiProvider { openai, gemini }

class AiChatService {
  static const _openaiUrl = 'https://api.openai.com/v1/chat/completions';

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
  }) async {
    switch (provider) {
      case AiProvider.openai:
        return _askOpenAi(apiKey, statsSummary, userMessage);
      case AiProvider.gemini:
        return _askGemini(apiKey, statsSummary, userMessage);
    }
  }

  static Future<String> _askOpenAi(
    String apiKey,
    String statsSummary,
    String userMessage,
  ) async {
    final response = await http.post(
      Uri.parse(_openaiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o-mini',
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

  static String? _cachedModel;

  static Future<String> _askGemini(
    String apiKey,
    String statsSummary,
    String userMessage,
  ) async {
    // Cache the model so we don't call ListModels every time
    _cachedModel ??= await _findGeminiModel(apiKey);
    final model = _cachedModel;
    if (model == null) {
      return 'No Gemini models available for your API key. '
          'Please check your key or try creating a new one at aistudio.google.com.';
    }

    final response = await http.post(
      Uri.parse(_geminiUrl(apiKey, model)),
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

  /// Calls ListModels to find a model that supports generateContent.
  static Future<String?> _findGeminiModel(String apiKey) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final models = data['models'] as List? ?? [];

    // Prefer newer flash models first
    final preferred = [
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
    ];

    for (final name in preferred) {
      for (final m in models) {
        final id = (m['name'] as String?) ?? '';
        final methods =
            (m['supportedGenerationMethods'] as List?)?.cast<String>() ?? [];
        if (id.contains(name) && methods.contains('generateContent')) {
          // id is like "models/gemini-2.0-flash", strip the prefix
          return id.replaceFirst('models/', '');
        }
      }
    }

    // Fallback: pick any model that supports generateContent
    for (final m in models) {
      final id = (m['name'] as String?) ?? '';
      final methods =
          (m['supportedGenerationMethods'] as List?)?.cast<String>() ?? [];
      if (methods.contains('generateContent')) {
        return id.replaceFirst('models/', '');
      }
    }

    return null;
  }
}
