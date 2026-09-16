import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_record.dart';

enum HistorySortOrder { newestFirst, oldestFirst }

@immutable
class HistoryQuery {
  const HistoryQuery({
    this.prayer,
    this.status,
    this.originalDateRange,
    this.sortOrder = HistorySortOrder.newestFirst,
  });

  final PrayerType? prayer;
  final QazaStatus? status;
  final DateTimeRange? originalDateRange;
  final HistorySortOrder sortOrder;

  bool get hasFilters => prayer != null || status != null || originalDateRange != null;

  HistoryQuery copyWith({
    Object? prayer = _unset,
    Object? status = _unset,
    Object? originalDateRange = _unset,
    HistorySortOrder? sortOrder,
  }) {
    return HistoryQuery(
      prayer: identical(prayer, _unset) ? this.prayer : prayer as PrayerType?,
      status: identical(status, _unset) ? this.status : status as QazaStatus?,
      originalDateRange: identical(originalDateRange, _unset)
          ? this.originalDateRange
          : originalDateRange as DateTimeRange?,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  HistoryQuery clearFilters() => HistoryQuery(sortOrder: sortOrder);

  @override
  bool operator ==(Object other) =>
      other is HistoryQuery &&
      other.prayer == prayer &&
      other.status == status &&
      other.originalDateRange?.start == originalDateRange?.start &&
      other.originalDateRange?.end == originalDateRange?.end &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(
        prayer,
        status,
        originalDateRange?.start,
        originalDateRange?.end,
        sortOrder,
      );
}

const _unset = Object();
