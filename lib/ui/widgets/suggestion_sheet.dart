// lib/ui/widgets/suggestion_sheet.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/app_contact.dart';
import '../../models/goal.dart';
import '../../services/ai_suggestion_service.dart';

void showClaudeSuggestionSheet({
  required BuildContext context,
  required AppContact contact,
  required GoalType goalType,
  required List<String> circleNames,
  String? lastNote,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => ClaudeSuggestionSheet(
      contact: contact,
      goalType: goalType,
      circleNames: circleNames,
      lastNote: lastNote,
    ),
  );
}

class ClaudeSuggestionSheet extends StatefulWidget {
  final AppContact contact;
  final GoalType goalType;
  final List<String> circleNames;
  final String? lastNote;

  const ClaudeSuggestionSheet({
    super.key,
    required this.contact,
    required this.goalType,
    required this.circleNames,
    required this.lastNote,
  });

  @override
  State<ClaudeSuggestionSheet> createState() => _ClaudeSuggestionSheetState();
}

class _ClaudeSuggestionSheetState extends State<ClaudeSuggestionSheet> {
  String generatedText = "";
  bool isDone = false;

  late StreamSubscription<String> _sub;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _beginStreaming();
  }

  void _beginStreaming() {
    // print("🔥 Starting Claude stream…");

    final stream = AiSuggestionService.streamClaudeSuggestion(
      goalType: widget.goalType,
      circleNames: widget.circleNames,
      lastNote: widget.lastNote,
    );

    _sub = stream.listen((chunk) {
      // print("🟣 UI received chunk: '$chunk'");

      // ---------------------------------------------------------
      // REMOVE "Message" / "Suggestion" header chunks from Claude
      // ---------------------------------------------------------
      if (generatedText.isEmpty) {
        final trimmed = chunk.trim();
        if (trimmed == "Message" || trimmed == "Suggestion") {
          // print("🧹 Removing header token: '$trimmed'");
          return; // skip this chunk entirely
        }
      }

      // Normalize whitespace
      chunk = chunk.replaceAll("\r", "").replaceAll("\n\n", "\n");

      // Trim leading space on the very first real content
      if (generatedText.isEmpty) {
        chunk = chunk.trimLeft();
      }

      // Append
      setState(() {
        generatedText += chunk;
      });

      // Auto-scroll
      Future.delayed(const Duration(milliseconds: 25), () {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }, onDone: () {
      // print("✅ Claude streaming done");
      if (mounted) setState(() => isDone = true);
    }, onError: (e) {
      // print("❌ STREAM ERROR: $e");

      if (!mounted) return;
      setState(() {
        generatedText =
            "Sorry — something went wrong while generating the message.";
        isDone = true;
      });
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final number =
        widget.contact.phones.isNotEmpty ? widget.contact.phones.first : null;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          children: [
            // drag handle
            Container(
              width: 52,
              height: 6,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            const Text(
              "Suggested Message",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 14),

            // -------- STREAMED TEXT AREA --------
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    controller: _scroll,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.4,
                            color: Colors.black,
                          ),
                          child: Text(
                            generatedText.isEmpty
                                ? "Thinking…"
                                : generatedText,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // -------- BUTTONS --------
            Row(
              children: [
                // COPY BUTTON
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: generatedText.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(
                              ClipboardData(text: generatedText),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Copied to clipboard"),
                              ),
                            );
                          },
                    icon: const Icon(Icons.copy),
                    label: const Text("Copy"),
                  ),
                ),
                const SizedBox(width: 12),

                // SMS BUTTON
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (isDone &&
                            generatedText.isNotEmpty &&
                            number != null)
                        ? () {
                            final smsUri = Uri.parse(
                              "sms:$number?body=${Uri.encodeComponent(generatedText)}",
                            );
                            launchUrl(smsUri);
                          }
                        : null,
                    icon: const Icon(Icons.sms),
                    label: const Text("Send"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
