/// Помошни функции за прикажување на датуми на македонски, без надворешен
/// пакет (intl) — доволно за wireframe/MVP ниво.
String formatDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d.$m.${date.year}';
}

String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'сега';
  if (diff.inMinutes < 60) return 'пред ${diff.inMinutes} мин.';
  if (diff.inHours < 24) return 'пред ${diff.inHours} ч.';
  if (diff.inDays < 7) return 'пред ${diff.inDays} д.';
  return formatDate(date);
}
