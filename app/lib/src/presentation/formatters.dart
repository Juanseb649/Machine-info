String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}

String formatDuration(Duration d) {
  final days = d.inDays;
  final hours = d.inHours.remainder(24);
  final minutes = d.inMinutes.remainder(60);
  if (days > 0) return '${days}d ${hours}h ${minutes}m';
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

String formatPercent(double ratio) => '${(ratio * 100).toStringAsFixed(1)} %';

String formatMhz(double mhz) {
  if (mhz <= 0) return 'N/D';
  return mhz >= 1000 ? '${(mhz / 1000).toStringAsFixed(2)} GHz' : '${mhz.toStringAsFixed(0)} MHz';
}

String orNa(String value) => value.isEmpty ? 'N/D' : value;
