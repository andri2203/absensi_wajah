List<String> listBulan = [
  "Januari",
  "Februari",
  "Maret",
  "April",
  "Mei",
  "Juni",
  "Juli",
  "Agustus",
  "September",
  "Oktober",
  "November",
  "Desember",
];

String dateTime(
  DateTime dateTime, {
  bool disabledDay = false,
  bool disabledHour = false,
}) {
  String format(String dt) {
    return dt.length == 1 ? "0$dt" : dt;
  }

  String tanggal = format(dateTime.day.toString());
  String bulan = listBulan[dateTime.month - 1];
  String tahun = dateTime.year.toString();

  String jam = format(dateTime.hour.toString());
  String menit = format(dateTime.minute.toString());
  String detik = format(dateTime.second.toString());

  if (disabledDay == true) {
    return "$jam:$menit:$detik";
  }

  if (disabledHour == true) {
    return "$tanggal $bulan $tahun";
  }

  return "$tanggal $bulan $tahun $jam:$menit:$detik";
}

Map<String, int> startEndDay(DateTime dateTime) {
  String start = "start";
  String end = "end";
  DateTime startDay =
      DateTime(dateTime.year, dateTime.month, dateTime.day, 0, 0, 0);
  DateTime endDay =
      DateTime(dateTime.year, dateTime.month, dateTime.day, 23, 59, 59);

  return {
    start: startDay.millisecondsSinceEpoch,
    end: endDay.millisecondsSinceEpoch
  };
}
