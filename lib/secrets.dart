import 'package:flutter_dotenv/flutter_dotenv.dart';

class Secrets {
  static String get anthropicApiKey =>
      dotenv.env['ANTHROPIC_API_KEY'] ?? '';
}
