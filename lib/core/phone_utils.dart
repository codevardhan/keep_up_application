/// Keep only digits (and leading '+'), then validate.
/// Rules (MVP):
/// - Strip all non-digits (except leading '+').
/// - If resulting digit count < 10  -> drop (invalid / too short).
/// - Otherwise return the cleaned number (digits only for storage).
String? normalizeAndValidatePhone(String raw) {
  if (raw.isEmpty) return null;

  // Allow leading '+' temporarily, count digits afterwards
  final hasPlus = raw.trim().startsWith('+');
  final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');

  // Count digits (ignore '+')
  if (digitsOnly.length < 10) return null; // drop short numbers (e.g., #123)

  // Store digits only (simple MVP). If you prefer E.164 later, format here.
  return hasPlus ? '+$digitsOnly' : digitsOnly;
}
