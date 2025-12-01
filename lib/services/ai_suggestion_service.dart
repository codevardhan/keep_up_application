import '../models/app_contact.dart';
import '../models/goal.dart';
import 'llm/anthropic_client.dart';

/// AI suggestion service (public surface).
/// - Builds sanitized prompts
/// - Calls AnthropicClient under the hood
/// - Provides local fallbacks on failure
class AiSuggestionService {
  // Centralize model + system strings here to keep usage consistent.
  static const _model = 'claude-3-5-haiku-latest'; // or your provisioned model
  static const _systemMessage =
      'You are an AI assistant whos main goal is to send contextal notifications to an user '
      'Always start your response directly with the actual message text. '
      'Never include titles, headings, hashtags, labels, summaries, or sections. '
      'Never start with "#" or "Message". '
      'Begin with a conversational greeting like "Hey!" or "Hi!".';

  /// Future-based full message suggestion (for Compose prefill).
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

    final ai = await AnthropicClient.callClaude(
      model: _model,
      system: _systemMessage,
      userContent: prompt,
      maxTokens: 200,
    );

    if (ai != null && ai.trim().isNotEmpty) return ai.trim();

    // Fallback if AI fails
    return _localTemplateSuggestion(
      goalType: goalType,
      circleNames: circleNames,
      lastNote: lastNote,
    );
  }

  /// Streaming message suggestion (typing effect).
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

    return AnthropicClient.streamClaude(
      model: _model,
      system: _systemMessage,
      userContent: prompt,
      maxTokens: 200,
    );
  }

  /// Short, goal-aware notification line (concise, ~1 sentence).
  static Future<String> generateNotificationLine({
    required GoalType goalType,
    required List<String> circleNames,
    String? lastNote,
    int? daysSinceLast,
  }) async {
    final prompt = _buildSanitizedContextForNotification(
      goalType: goalType,
      circleNames: circleNames,
      lastNote: lastNote,
      daysSinceLast: daysSinceLast,
    );


    final ai = await AnthropicClient.callClaude(
      model: _model,
      system:
          'You write one concise, warm, respectful notification sentence for the user. '
          'No names, companies, phone numbers, or emails. No headers or hashtags.',
      userContent: prompt,
      maxTokens: 90,
    );

    if (ai != null && ai.trim().isNotEmpty) {
      final s = ai.replaceAll('\n', ' ').trim();
      return s.length > 100 ? '${s.substring(0, 100)}…' : s;
    }

    // Fallback
    final safeNote = (lastNote != null && lastNote.trim().isNotEmpty)
        ? '—maybe mention your last note.'
        : '';
    final prefix = (daysSinceLast != null && daysSinceLast >= 3)
        ? "It's been a while"
        : "Quick check-in";
    switch (goalType) {
      case GoalType.internship:
        return "$prefix—reach out for internship updates $safeNote";
      case GoalType.family:
        return "$prefix—say hi and see how things are going $safeNote";
      case GoalType.friends:
        return "$prefix—see how they’re doing $safeNote";
      case GoalType.wellness:
        return "$prefix—send a kind, low-pressure note $safeNote";
    }
  }

  // ------------------ Prompt building & sanitization ------------------

  static String _buildSanitizedContext({
    required GoalType goalType,
    required List<String> circleNames,
    String? lastNote,
  }) {
    final sb = StringBuffer()
      ..writeln('User goal: ${_goalDescription(goalType)}')
      ..writeln(
        circleNames.isNotEmpty
            ? 'Recipient is tagged as: ${circleNames.join(", ")}.'
            : 'Recipient relationship: unspecified.',
      );

    if (lastNote != null && lastNote.trim().isNotEmpty) {
      final safe = _sanitizeFreeText(lastNote);
      sb.writeln('Recent interaction notes (PII removed): $safe');
    }

    sb
      ..writeln(
        'Write a warm, natural, 2–4 sentence message the user can send.',
      )
      ..writeln(
        'Do NOT include any names, company names, phone numbers, or emails.',
      )
      ..writeln('Refer to the other person as "you" or "we".');

    return sb.toString();
  }

  static String _buildSanitizedContextForNotification({
    required GoalType goalType,
    required List<String> circleNames,
    String? lastNote,
    int? daysSinceLast,
  }) {
    final sb = StringBuffer()
      ..writeln(
        'Task: Write ONE short, natural notification sentence, inviting the user to reach out to the other person',
      )
      ..writeln('Tone: warm, respectful, non-judgmental. ~12–18 words.')
      ..writeln('No names/companies/phones/emails. No headers or hashtags.')
      ..writeln('Only refer to information you know for certain, from what is provided.')
      ..writeln('Speak to the USER about the other person.')
      ..writeln('User goal: ${_goalDescription(goalType)}');

    if (circleNames.isNotEmpty) {
      sb.writeln('Recipient tagged as: ${circleNames.join(", ")}.');
    }
    if (daysSinceLast != null) {
      sb.writeln('Days since last contact: $daysSinceLast.');
    }
    if (lastNote != null && lastNote.trim().isNotEmpty) {
      final safe = _sanitizeFreeText(lastNote);
      sb
        ..writeln('Relevant past note (PII removed): $safe')
        ..writeln(
          'If appropriate, reference an upcoming thing from the note (e.g., dentist).',
        );
    }

    sb
      ..writeln('Examples:')
      ..writeln(
        '- “It’s been a bit—check in about the dentist appointment and wish them well.”',
      )
      ..writeln('- “Quick nudge: say hi and ask how the onboarding is going.”')
      ..writeln(
        '- “Gentle check-in: see how they’re feeling after last week’s presentation.”',
      )
      ..writeln('Return only the sentence.');
    return sb.toString();
  }

  static String _sanitizeFreeText(String input) {
    var text = input;
    text = text.replaceAll(
      RegExp(r'\b\S+@\S+\.\S+\b'),
      '[email removed]',
    ); // emails
    text = text.replaceAll(
      RegExp(r'\+?\d[\d\-\s]{6,}\d'),
      '[phone removed]',
    ); // phones
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

  // ------------------ Local fallback text ------------------

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
