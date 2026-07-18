String formatRideStatusLabel(String? status) {
  final normalized = (status ?? 'pending').toLowerCase().trim();
  if (normalized.isEmpty) {
    return 'Pending';
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}
