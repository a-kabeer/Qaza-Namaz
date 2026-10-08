enum PrayerType {
  fajr,
  zuhr,
  asr,
  maghrib,
  isha,
  witr,
}

extension PrayerTypeX on PrayerType {
  /// The single canonical Qaza completion order.
  ///
  /// Auto Sequence and Sahib al-Tartib both consume this definition so the
  /// prayer order cannot drift between targeting and business rules.
  static const List<PrayerType> qazaSequence = <PrayerType>[
    PrayerType.fajr,
    PrayerType.zuhr,
    PrayerType.asr,
    PrayerType.maghrib,
    PrayerType.isha,
    PrayerType.witr,
  ];

  int get qazaSequenceIndex => qazaSequence.indexOf(this);

  PrayerType get nextInQazaSequence {
    final index = qazaSequenceIndex;
    return qazaSequence[(index + 1) % qazaSequence.length];
  }

  /// Advances in canonical Qaza order while skipping Witr when it is disabled.
  PrayerType nextInQazaSequenceSkippingWitr({required bool witrEnabled}) {
    final next = nextInQazaSequence;
    return !witrEnabled && next == PrayerType.witr ? PrayerType.fajr : next;
  }

  String get label {
    switch (this) {
      case PrayerType.fajr:
        return 'Fajr';
      case PrayerType.zuhr:
        return 'Zuhr';
      case PrayerType.asr:
        return 'Asr';
      case PrayerType.maghrib:
        return 'Maghrib';
      case PrayerType.isha:
        return 'Isha';
      case PrayerType.witr:
        return 'Witr';
    }
  }
}

const allPrayerTypes = PrayerType.values;
