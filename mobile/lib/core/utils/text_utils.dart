/// Türkçe'ye uygun başlık biçimi: "hira nur karakuzu" -> "Hira Nur Karakuzu"
String toTitleCaseTr(String input) {
  String upperTr(String c) => c == 'i' ? 'İ' : (c == 'ı' ? 'I' : c.toUpperCase());
  String lowerTr(String s) =>
      s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

  return input
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => upperTr(w[0]) + lowerTr(w.substring(1)))
      .join(' ');
}
