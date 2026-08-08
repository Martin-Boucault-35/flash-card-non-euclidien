const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

/// Date courte en français, sans dépendance (intl n'est pas dans le projet).
/// Ex. « 12 août 2026 · 14:03 ».
String formatEventDate(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_months[d.month - 1]} ${d.year} · $hh:$mm';
}
