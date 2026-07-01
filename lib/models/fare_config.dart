/// Editable fare parameters, kept in Firestore (`config/fares`) so a new
/// LTFRB/city fare memo can be applied by an admin in-app without rebuilding
/// the app. The fare formulas live in code; only these numbers change.
///
/// If the Firestore document is missing or a field is absent, the
/// corresponding default below is used, so the app always has working fares.
class FareConfig {
  // --- Jeepney: flat [jeepneyBaseFare] up to [jeepneyBaseDistanceKm], then
  //     [jeepneyPerKm] per succeeding km ---
  final double jeepneyBaseFare;
  final double jeepneyBaseDistanceKm;
  final double jeepneyPerKm;

  // --- Habal-habal: flat [habalBaseFare] up to [habalBaseDistanceKm], then
  //     [habalTier1PerKm] per km up to [habalTier1LimitKm], then
  //     [habalTier2PerKm] per km beyond that ---
  final double habalBaseFare;
  final double habalBaseDistanceKm;
  final double habalTier1PerKm;
  final double habalTier1LimitKm;
  final double habalTier2PerKm;

  // --- Sikad: flat [sikadBaseFare] up to [sikadBaseDistanceKm], then
  //     [sikadPerBlock] for each [sikadBlockSizeKm] block (partial blocks
  //     round up) ---
  final double sikadBaseFare;
  final double sikadBaseDistanceKm;
  final double sikadBlockSizeKm;
  final double sikadPerBlock;

  /// Amount added to the computed fare to form the displayed range
  /// (e.g. spread 5 → "₱13–₱18"). The computed fare is the low end.
  final double rangeSpread;

  const FareConfig({
    required this.jeepneyBaseFare,
    required this.jeepneyBaseDistanceKm,
    required this.jeepneyPerKm,
    required this.habalBaseFare,
    required this.habalBaseDistanceKm,
    required this.habalTier1PerKm,
    required this.habalTier1LimitKm,
    required this.habalTier2PerKm,
    required this.sikadBaseFare,
    required this.sikadBaseDistanceKm,
    required this.sikadBlockSizeKm,
    required this.sikadPerBlock,
    required this.rangeSpread,
  });

  /// Current published fares — used as the fallback when no Firestore doc
  /// exists yet. These mirror the values the app shipped with.
  factory FareConfig.defaults() => const FareConfig(
        jeepneyBaseFare: 13.0,
        jeepneyBaseDistanceKm: 4.0,
        jeepneyPerKm: 1.8,
        habalBaseFare: 50.0,
        habalBaseDistanceKm: 2.0,
        habalTier1PerKm: 9.0,
        habalTier1LimitKm: 8.0,
        habalTier2PerKm: 15.0,
        sikadBaseFare: 10.0,
        sikadBaseDistanceKm: 1.0,
        sikadBlockSizeKm: 0.5,
        sikadPerBlock: 10.0,
        rangeSpread: 5.0,
      );

  /// Reads a field, falling back to the default value when missing/invalid.
  static double _num(Map<String, dynamic> data, String key, double fallback) {
    final v = data[key];
    return v is num ? v.toDouble() : fallback;
  }

  factory FareConfig.fromJson(Map<String, dynamic> data, String id) {
    final d = FareConfig.defaults();
    return FareConfig(
      jeepneyBaseFare: _num(data, 'jeepneyBaseFare', d.jeepneyBaseFare),
      jeepneyBaseDistanceKm:
          _num(data, 'jeepneyBaseDistanceKm', d.jeepneyBaseDistanceKm),
      jeepneyPerKm: _num(data, 'jeepneyPerKm', d.jeepneyPerKm),
      habalBaseFare: _num(data, 'habalBaseFare', d.habalBaseFare),
      habalBaseDistanceKm:
          _num(data, 'habalBaseDistanceKm', d.habalBaseDistanceKm),
      habalTier1PerKm: _num(data, 'habalTier1PerKm', d.habalTier1PerKm),
      habalTier1LimitKm: _num(data, 'habalTier1LimitKm', d.habalTier1LimitKm),
      habalTier2PerKm: _num(data, 'habalTier2PerKm', d.habalTier2PerKm),
      sikadBaseFare: _num(data, 'sikadBaseFare', d.sikadBaseFare),
      sikadBaseDistanceKm:
          _num(data, 'sikadBaseDistanceKm', d.sikadBaseDistanceKm),
      sikadBlockSizeKm: _num(data, 'sikadBlockSizeKm', d.sikadBlockSizeKm),
      sikadPerBlock: _num(data, 'sikadPerBlock', d.sikadPerBlock),
      rangeSpread: _num(data, 'rangeSpread', d.rangeSpread),
    );
  }

  Map<String, dynamic> toJson() => {
        'jeepneyBaseFare': jeepneyBaseFare,
        'jeepneyBaseDistanceKm': jeepneyBaseDistanceKm,
        'jeepneyPerKm': jeepneyPerKm,
        'habalBaseFare': habalBaseFare,
        'habalBaseDistanceKm': habalBaseDistanceKm,
        'habalTier1PerKm': habalTier1PerKm,
        'habalTier1LimitKm': habalTier1LimitKm,
        'habalTier2PerKm': habalTier2PerKm,
        'sikadBaseFare': sikadBaseFare,
        'sikadBaseDistanceKm': sikadBaseDistanceKm,
        'sikadBlockSizeKm': sikadBlockSizeKm,
        'sikadPerBlock': sikadPerBlock,
        'rangeSpread': rangeSpread,
      };
}
