// lib/services/contacts_sync.dart
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/app_contact.dart';
import '../core/phone_utils.dart';

class ContactsSync {
  /// Requests permission and returns a compact, cleaned list of contacts.
  static Future<List<AppContact>> fetchDeviceContacts() async {
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) return [];

    // Lightweight fetch: name + phones + emails only
    final contacts = await FlutterContacts.getContacts(
      withProperties: true, // includes phones/emails
      withPhoto: false,
    );

    final cleaned = contacts
        .map((c) {
          // Build displayName (fallback to first + last if displayName is empty)
          final dn = c.displayName.trim();
          final displayName = dn.isNotEmpty
              ? dn
              : [
                  c.name.first.trim(),
                  c.name.last.trim(),
                ].where((s) => s.isNotEmpty).join(' ').trim();

          // Normalize & validate phones; dedupe
          final cleanedPhones = c.phones
              .map(
                (p) =>
                    (p.normalizedNumber.trim().isNotEmpty)
                    ? p.normalizedNumber
                    : p.number,
              )
              .where((s) => s.trim().isNotEmpty)
              .map(normalizeAndValidatePhone) // -> String? (null if <10 digits)
              .where((s) => s != null)
              .cast<String>()
              .toSet()
              .toList();

          // Emails (optional); dedupe
          final emails = c.emails
              .map((e) => e.address.trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList();

          // Hard filters:
          if (displayName.isEmpty) return null; // reject nameless
          if (cleanedPhones.isEmpty) {
            return null; // reject no valid phones (e.g., "#123")
          }

          return AppContact(
            id: c.id,
            displayName: displayName,
            phones: cleanedPhones,
            emails: emails,
            circleIds: const [],
          );
        })
        .whereType<AppContact>() // drop nulls
        .toList();

    // Stable sort by display name
    cleaned.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return cleaned;
  }
}
