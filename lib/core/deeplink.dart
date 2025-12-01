import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _tryLaunch(BuildContext context, Uri uri) async {
  final ok = await canLaunchUrl(uri);
  if (ok) {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) return;
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Cannot open: ${uri.toString()}')));
  }
}

/// tel: link
Future<void> launchCall(BuildContext context, String digits) async {
  final uri = Uri(scheme: 'tel', path: digits);
  await _tryLaunch(context, uri);
}

Future<void> _toast(BuildContext context, String msg) async {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

String _sanitizeDigits(String input) {
  // keep + if present, otherwise only digits
  final hasPlus = input.trim().startsWith('+');
  final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
  return hasPlus ? '+$digitsOnly' : digitsOnly;
}

Future<void> launchSms(
  BuildContext context,
  String rawDigits, {
  String? body,
}) async {
  final digits = _sanitizeDigits(rawDigits);
  if (digits.isEmpty) {
    await _toast(context, 'No valid phone number.');
    return;
  }
  final hasBody = body != null && body.trim().isNotEmpty;
  final encodedBody = hasBody ? Uri.encodeComponent(body) : null;

  // Variants (ordered by likelihood)
  final noPlus = digits.startsWith('+') ? digits.substring(1) : digits;
  final List<Uri> tries = [];

  if (Platform.isIOS) {
    // iOS prefers &body when recipient present
    tries.add(Uri.parse('sms:$digits${hasBody ? '&body=$encodedBody' : ''}'));
    if (digits != noPlus) {
      tries.add(Uri.parse('sms:$noPlus${hasBody ? '&body=$encodedBody' : ''}'));
    }
    // Open Messages without recipient (user can pick)
    tries.add(Uri.parse('sms:'));
  } else {
    // Android: smsto: most reliable; sms: also works on many
    tries.add(Uri.parse('smsto:$digits${hasBody ? '?body=$encodedBody' : ''}'));
    tries.add(Uri.parse('sms:$digits${hasBody ? '?body=$encodedBody' : ''}'));
    if (digits != noPlus) {
      tries.add(
        Uri.parse('smsto:$noPlus${hasBody ? '?body=$encodedBody' : ''}'),
      );
      tries.add(Uri.parse('sms:$noPlus${hasBody ? '?body=$encodedBody' : ''}'));
    }
    // Open Messages app without recipient as fallback
    tries.add(Uri.parse('sms:'));
  }

  debugPrint(
    'SMS launch — sanitized: "$digits"  body? ${hasBody ? 'yes' : 'no'}',
  );
  for (final uri in tries) {
    try {
      final can = await canLaunchUrl(uri);
      debugPrint('  try: $uri   canLaunch=$can');
      if (!can) continue;

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      debugPrint('    launchUrl -> $ok');
      if (ok) return;
    } catch (e, st) {
      debugPrint('    EXCEPTION launching $uri: $e\n$st');
    }
  }

  // Absolute last resort on Android: open dialer (not messages) so the user isn’t stuck.
  if (!Platform.isIOS) {
    final tel = Uri(scheme: 'tel', path: noPlus);
    try {
      final can = await canLaunchUrl(tel);
      debugPrint('  fallback tel: $tel   canLaunch=$can');
      if (can) {
        final ok = await launchUrl(tel, mode: LaunchMode.externalApplication);
        debugPrint('    launchUrl(tel) -> $ok');
        if (ok) {
          await _toast(
            context,
            'Opened dialer instead (SMS app not available).',
          );
          return;
        }
      }
    } catch (e, st) {
      debugPrint('    EXCEPTION launching tel: $e\n$st');
    }
  }

  await _toast(
    context,
    'Cannot open Messages for: $digits. '
    'If you\'re on a simulator/emulator, test on a physical device or install an SMS app.',
  );
}

/// WhatsApp: native scheme with HTTPS fallback
Future<void> launchWhatsApp(
  BuildContext context,
  String digits, {
  String? text,
}) async {
  final native = Uri(
    scheme: 'whatsapp',
    host: 'send',
    queryParameters: {
      'phone': digits, // should be international format, e.g., +15551234567
      if (text != null && text.isNotEmpty) 'text': text,
    },
  );
  if (await canLaunchUrl(native)) {
    await launchUrl(native, mode: LaunchMode.externalApplication);
    return;
  }
  final https = Uri.https('wa.me', '/$digits', {
    if (text != null && text.isNotEmpty) 'text': text,
  });
  await _tryLaunch(context, https);
}
