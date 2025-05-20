class FileHelper {
  /// Ekstrak tanggal dan waktu mentah dari nama file (20250520_00-12-10)
  static String? extractTanggalDanWaktu(String filename) {
    final regExp = RegExp(r"(\d{8}_\d{2}-\d{2}-\d{2})");
    final match = regExp.firstMatch(filename);
    if (match != null) {
      return match.group(1); // 20250520_00-12-10
    }
    return null;
  }

  /// Format tanggal dan waktu mentah menjadi "20 Mei 2025, 00:12:10"
  static String? formatTanggalDenganWaktu(String? raw) {
    if (raw == null || !raw.contains('_')) return null;

    final parts = raw.split('_');
    final tanggal = parts[0]; // 20250520
    final waktu = parts[1].replaceAll('-', ':'); // 00:12:10

    if (tanggal.length != 8) return null;

    String tahun = tanggal.substring(0, 4);
    String bulan = tanggal.substring(4, 6);
    String hari = tanggal.substring(6, 8);

    Map<String, String> namaBulan = {
      '01': 'Januari',
      '02': 'Februari',
      '03': 'Maret',
      '04': 'April',
      '05': 'Mei',
      '06': 'Juni',
      '07': 'Juli',
      '08': 'Agustus',
      '09': 'September',
      '10': 'Oktober',
      '11': 'November',
      '12': 'Desember',
    };

    final namaBln = namaBulan[bulan];
    if (namaBln == null) return null;

    return "$hari $namaBln $tahun, $waktu";
  }
}
