// lib/services/ai_suggestion_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; 

import '../models/app_contact.dart';
import '../models/goal.dart';
import '../secrets.dart';

/// AI suggestion service supporting:
/// 1. Normal one-shot Claude calls
/// 2. Streaming Claude responses (typing effect)
///
/// IMPORTANT: All prompts must be sanitized — no PII allowed.
class AiSuggestionService {
  // ---------------------------------------------------------------------------
  // PUBLIC API
  // ---------------------------------------------------------------------------

  /// Future-based generation (used in your current code).
  /// Uses one-shot `_callClaude()` with a fallback template.
  static Future<String> generateSuggestion({
    required AppContact contact,
    required GoalType goalType,
    required List<String> circleNames,
    String? lastNote,
  }) async {
    final prompt = _buildSanitizedContext(
      goalType: goalType,
      circleNames: circleNames,
      lastNote: lastNote,
    );

    try {
      final claudeSuggestion = await _callClaude(prompt);
      if (claudeSuggestion != null && claudeSuggestion.trim().isNotEmpty) {
        return claudeSuggestion.trim();
      }
    } catch (_) {
      // ignore — fallback handles UX
    }

    return _localTemplateSuggestion(
      goalType: goalType,
      circleNames: circleNames,
      lastNote: lastNote,
    );
  }

  /// STREAMING Claude messages for typing effect.
  /// Returns each partial token as it arrives.
  static Stream<String> streamClaudeSuggestion({
  required GoalType goalType,
  required List<String> circleNames,
  String? lastNote,
}) {
  final prompt = _buildSanitizedContext(
    goalType: goalType,
    circleNames: circleNames,
    lastNote: lastNote,
  );

  return _streamClaude(prompt);
}

  // ---------------------------------------------------------------------------
  // STREAMING IMPLEMENTATION (Chunked HTTP Transfer)
  // ---------------------------------------------------------------------------

  /// Future-proof Claude streaming (NOT SSE — recommended by Anthropic).
static Stream<String> _streamClaude(String context) async* {
  final url = Uri.parse("https://api.anthropic.com/v1/messages");

    final requestBody = jsonEncode({
    "model": "claude-haiku-4-5",
    "system":
        "Write only the final message. Never include headings, titles, hashtags, "
        "or labels. Start your response immediately with a friendly greeting like "
        "\"Hey!\" or \"Hi!\", followed by the message.",
    "max_tokens": 200,
    "stream": true,
    "messages": [
        {
        "role": "user",
        "content": context
        }
    ]
    });


  final client = http.Client();

  try {
    final req = http.Request("POST", url)
      ..headers.addAll({
        "Content-Type": "application/json",
        "x-api-key": dotenv.env['ANTHROPIC_API_KEY']!,
        "anthropic-version": "2023-06-01",
      })
      ..body = requestBody;

    final response = await client.send(req);

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    final buffer = StringBuffer();

    await for (var line in lines) {
      line = line.trim();

      if (line.startsWith("data:")) {
        // accumulate data:
        buffer.write(line.substring(5).trim());
      } else if (line.isEmpty) {
        // end of event → parse JSON chunk
        final chunk = buffer.toString();
        buffer.clear();

        if (chunk.isEmpty) continue;

        try {
          final jsonObj = jsonDecode(chunk);

          // emit ONLY text deltas
          if (jsonObj["type"] == "content_block_delta") {
            final txt = jsonObj["delta"]?["text"];
            if (txt is String) yield txt;
          }
        } catch (e) {
          print("JSON parse failed: $e\nChunk: $chunk");
        }
      }
    }
  } finally {
    client.close();
  }
}


  // ---------------------------------------------------------------------------
  // ONE-SHOT CLAUDE REQUEST (Existing use in your app)
  // ---------------------------------------------------------------------------

  static Future<String?> _callClaude(String context) async {
    final url = Uri.parse("https://api.anthropic.com/v1/messages");

    final response = await http
        .post(
          url,
          headers: {
            "Content-Type": "application/json",
            "x-api-key": Secrets.anthropicApiKey,
            "anthropic-version": "2023-06-01",
          },
          body: jsonEncode({
            "model": "claude-haiku-4-5",
            "max_tokens": 200,
            "messages": [
                {
                    "role": "system",
                    "content":
                        "You are an AI assistant that writes brief, natural, friendly messages. "
                        "Always start your response **directly with the actual message text**. "
                        "NEVER include titles, headings, hashtags, labels, summaries, or sections. "
                        "NEVER start with '#' or 'Message'. "
                        "Always begin with a conversational greeting like 'Hey!' or 'Hi!'."
                },
                {
                    "role": "user",
                    "content": context
                }
            ]
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      print("Claude error ${response.statusCode}: ${response.body}");
      return null;
    }

    final data = jsonDecode(response.body);

    print("Claude prompt:\n$context");
    print("Claude response:\n${response.body}");

    // Extract text
    final content = data["content"];
    if (content is List && content.isNotEmpty) {
      final first = content[0];
      if (first is Map && first["text"] is String) {
        return first["text"];
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // PROMPT BUILDING & SANITIZATION
  // ---------------------------------------------------------------------------

  static String _buildSanitizedContext({
    required GoalType goalType,
    required List<String> circleNames,
    String? lastNote,
  }) {
    final sb = StringBuffer();

    sb.writeln('User goal: ${_goalDescription(goalType)}');

    if (circleNames.isNotEmpty) {
      sb.writeln('Recipient is tagged as: ${circleNames.join(", ")}.');
    } else {
      sb.writeln('Recipient relationship: unspecified.');
    }

    if (lastNote != null && lastNote.trim().isNotEmpty) {
      final safe = _sanitizeFreeText(lastNote);
      sb.writeln(
        'Recent interaction notes (PII removed): $safe',
      );
    }

    sb.writeln(
        'Write a warm, natural, 2–4 sentence message the user can send. '
        'Do NOT include any names, company names, phone numbers, or emails.');
    sb.writeln('Refer to the other person as "you" or "we".');

    return sb.toString();
  }

  static String _sanitizeFreeText(String input) {
    var text = input;

    // Remove emails
    final emailRegex = RegExp(r'\b\S+@\S+\.\S+\b');
    text = text.replaceAll(emailRegex, '[email removed]');

    // Remove phone numbers
    final phoneRegex = RegExp(r'\+?\d[\d\-\s]{6,}\d');
    text = text.replaceAll(phoneRegex, '[phone removed]');

    return text;
  }

  static String _goalDescription(GoalType goalType) {
    switch (goalType) {
      case GoalType.internship:
        return 'Find or explore internships and career opportunities.';
      case GoalType.family:
        return 'Reconnect and stay close with family.';
      case GoalType.friends:
        return 'Stay in touch with friends.';
      case GoalType.wellness:
        return 'Support emotional balance and mental wellness.';
    }
  }

  // ---------------------------------------------------------------------------
  // LOCAL FALLBACK
  // ---------------------------------------------------------------------------

  static String _localTemplateSuggestion({
    required GoalType goalType,
    required List<String> circleNames,
    String? lastNote,
  }) {
    final noteClause = (lastNote != null && lastNote.trim().isNotEmpty)
        ? " I've been thinking about our last conversation."
        : '';

    switch (goalType) {
      case GoalType.internship:
        return "Hi! I hope you're doing well.$noteClause "
            "I'm exploring internship opportunities and would really value your perspective. "
            "If you have a moment, I'd love to ask a few quick questions.";

      case GoalType.family:
        return "Hey, I’ve been thinking of you and wanted to check in.$noteClause "
            "Life’s been pretty busy, but I don’t want to lose touch. "
            "How have you been lately?";

      case GoalType.friends:
        return "Hey! It feels like it’s been a while.$noteClause "
            "I'd love to catch up. "
            "Would you be up for a quick call or chat sometime this week?";

      case GoalType.wellness:
        return "Hi! I wanted to reach out and reconnect.$noteClause "
            "Things have been a bit intense recently, and staying in touch really helps me stay grounded. "
            "How are you doing these days?";
    }
  }
}
