class ClozeParser {
  /// Formats front text for Cloze deletion cards, replacing {{c1::answer}},
  /// or any {{...}} with "[ ... ]" to hide the answer during active recall.
  static String formatClozeQuestion(String frontText) {
    if (frontText.isEmpty) return '';
    // Match {{c1::something}} or {{c1:something}} or {{something}}
    final RegExp regex = RegExp(r'\{\{(?:c\d+[:]{1,2}\s*)?(.*?)\}\}');
    return frontText.replaceAllMapped(regex, (match) {
      return '`[ ... ]`';
    });
  }

  /// Formats front text when answer is revealed, showing the full sentence
  /// with the revealed answer emphasized in bold (**answer**).
  static String formatClozeAnswer(String frontText) {
    if (frontText.isEmpty) return '';
    final RegExp regex = RegExp(r'\{\{(?:c\d+[:]{1,2}\s*)?(.*?)\}\}');
    return frontText.replaceAllMapped(regex, (match) {
      final content = match.group(1) ?? '';
      final parts = content.split(RegExp(r'::|(?<=\w):(?=\w)'));
      final answer = (parts.isNotEmpty ? parts[0] : content).trim();
      return '**$answer**';
    });
  }
}
