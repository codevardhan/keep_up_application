import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/app_contact.dart';
import '../core/phone_utils.dart';

class ContactsSync {
  /// Requests permission and returns a compact list of contacts.
  static Future<List<AppContact>> fetchDeviceContacts() async {
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) return [];

    // Lightweight fetch: name + phones + emails only
    final contacts = await FlutterContacts.getContacts(
      withProperties: true, // includes phones/emails
      withPhoto: false,
    );


return contacts
        .map((c) {
          // Build displayName
          final dn = c.displayName.trim();
          final displayName = dn.isNotEmpty
              ? dn
              : [
                  c.name.first?.trim() ?? '',
                  c.name.last?.trim() ?? '',
                ].where((s) => s.isNotEmpty).join(' ').trim();

          // Clean & validate phones
          final cleanedPhones = c.phones
              .map(
                (p) => (p.normalizedNumber?.isNotEmpty == true)
                    ? p.normalizedNumber!
                    : p.number,
              )
              .where((s) => s != null && s!.trim().isNotEmpty)
              .map((s) => normalizeAndValidatePhone(s!))
              .where((s) => s != null)
              .cast<String>()
              .toSet()
              .toList();

          // Emails (optional)
          final emails = c.emails
              .map((e) => e.address)
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList();

          // Hard filters:
          if (displayName.isEmpty) return null; // reject nameless
          if (cleanedPhones.isEmpty) return null; // reject no valid phones

          return AppContact(
            id: c.id,
            displayName: displayName,
            phones: cleanedPhones,
            emails: emails,
          );
        })
        .whereType<AppContact>() // drop nulls
        .toList();
  }
}
