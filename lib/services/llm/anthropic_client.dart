import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../secrets.dart';

/// Minimal Anthropic Messages API client (one-shot + streaming).
/// Internal use only — keep your domain logic outside this file.
final class AnthropicClient {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _version = '2023-06-01';

  /// One-shot text generation. Returns `null` on API errors.
  static Future<String?> callClaude({
    required String model,
    required String system,
    required String userContent,
    int maxTokens = 200,
  }) async {
    final url = Uri.parse(_endpoint);
    final body = jsonEncode({
      'model': model,
      'max_tokens': maxTokens,
      'system': system, // <-- top-level system, NOT a message role
      'messages': [
        {'role': 'user', 'content': userContent},
      ],
    });

    final resp = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': Secrets.anthropicApiKey,
            'anthropic-version': _version,
          },
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      // Swallow details; return null so caller can fallback locally.
      return null;
    }

    final data = jsonDecode(resp.body);
    final content = data['content'];
    if (content is List && content.isNotEmpty) {
      final first = content.first;
      if (first is Map && first['text'] is String) {
        return first['text'] as String;
      }
    }
    return null;
  }

  /// Streaming tokens as they arrive. Emits only delta text.
  static Stream<String> streamClaude({
    required String model,
    required String system,
    required String userContent,
    int maxTokens = 200,
  }) async* {
    final url = Uri.parse(_endpoint);
    final reqBody = jsonEncode({
      'model': model,
      'system': system,
      'max_tokens': maxTokens,
      'stream': true,
      'messages': [
        {'role': 'user', 'content': userContent},
      ],
    });

    final client = http.Client();
    try {
      final req = http.Request('POST', url)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'x-api-key': Secrets.anthropicApiKey,
          'anthropic-version': _version,
        })
        ..body = reqBody;

      final resp = await client.send(req);
      final lines = resp.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      final buffer = StringBuffer();
      await for (var line in lines) {
        line = line.trim();
        if (line.startsWith('data:')) {
          buffer.write(line.substring(5).trim());
        } else if (line.isEmpty) {
          final chunk = buffer.toString();
          buffer.clear();
          if (chunk.isEmpty) continue;
          try {
            final obj = jsonDecode(chunk);
            if (obj['type'] == 'content_block_delta') {
              final txt = obj['delta']?['text'];
              if (txt is String) yield txt;
            }
          } catch (_) {
            // ignore malformed line; continue
          }
        }
      }
    } finally {
      client.close();
    }
  }
}
