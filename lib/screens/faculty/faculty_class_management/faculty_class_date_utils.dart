class FacultyClassDateUtils {
  static const Map<String, int> weekdayByName = {
    'monday': DateTime.monday,
    'mon': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'tue': DateTime.tuesday,
    'tues': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'wed': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'thu': DateTime.thursday,
    'thur': DateTime.thursday,
    'thurs': DateTime.thursday,
    'friday': DateTime.friday,
    'fri': DateTime.friday,
    'saturday': DateTime.saturday,
    'sat': DateTime.saturday,
    'sunday': DateTime.sunday,
    'sun': DateTime.sunday,
  };

  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static DateTime dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Today, tomorrow, and the next three calendar days after tomorrow.
  static List<DateTime> upcomingWindowDates({DateTime? referenceDate}) {
    final today = dateOnly(referenceDate ?? DateTime.now());
    final dates = <DateTime>[today];

    var cursor = today.add(const Duration(days: 1));
    dates.add(cursor);

    for (var index = 0; index < 3; index++) {
      cursor = cursor.add(const Duration(days: 1));
      dates.add(cursor);
    }

    return dates;
  }

  static int? weekdayFromDayName(String dayName) {
    final normalized = dayName.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    return weekdayByName[normalized];
  }

  static String resolveDayName({
    required String dayName,
    required String dayUid,
    required Map<String, String> dayUidToName,
  }) {
    final directName = dayName.trim();
    if (directName.isNotEmpty) {
      return directName;
    }
    return dayUidToName[dayUid.trim()] ?? '';
  }

  static String formatSectionLabel(
    DateTime date,
    DateTime referenceDate, {
    int? count,
  }) {
    late final String label;
    if (isSameDay(date, referenceDate)) {
      label = 'Today';
    } else if (isSameDay(date, referenceDate.add(const Duration(days: 1)))) {
      label = 'Tomorrow';
    } else {
      const weekdayLabels = [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ];
      final weekday = weekdayLabels[date.weekday - 1];
      final month = _monthNames[date.month - 1];
      label = '$weekday, ${date.day} $month';
    }

    if (count != null) {
      return '$label ($count)';
    }
    return label;
  }

  static String formatCompletedDate(DateTime date) {
    const weekdayLabels = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final weekday = weekdayLabels[date.weekday - 1];
    final month = _monthNames[date.month - 1];
    return '$weekday, ${date.day} $month ${date.year}';
  }

  static int timeToMinutes(String time) {
    final trimmed = time.trim();
    if (trimmed.isEmpty) {
      return 9999;
    }

    final parts = trimmed.split(':');
    if (parts.length < 2) {
      return 9999;
    }

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }
}
