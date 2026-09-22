import 'package:flutter/widgets.dart';

import '../domain/prayer_times_models.dart';
import '../domain/qaza_restriction_service.dart';

class PrayerTimesStrings {
  const PrayerTimesStrings._();

  static bool _isUrdu(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ur';

  static String title(BuildContext context) =>
      _isUrdu(context) ? 'نماز کے اوقات' : 'Prayer Times';

  static String locationUnavailable(BuildContext context) => _isUrdu(context)
      ? 'نماز کے اوقات دیکھنے کے لیے مقام منتخب کریں۔'
      : 'Choose a location to see prayer times.';

  static String useMyLocation(BuildContext context) =>
      _isUrdu(context) ? 'میرا مقام استعمال کریں' : 'Use My Location';

  static String chooseManually(BuildContext context) =>
      _isUrdu(context) ? 'مقام دستی منتخب کریں' : 'Choose Location Manually';

  static String changeLocation(BuildContext context) =>
      _isUrdu(context) ? 'مقام تبدیل کریں' : 'Change Location';

  static String refresh(BuildContext context) =>
      _isUrdu(context) ? 'تازہ کریں' : 'Refresh';

  static String currentPrayer(BuildContext context) =>
      _isUrdu(context) ? 'موجودہ نماز' : 'Current Prayer';

  static String nextPrayer(BuildContext context) =>
      _isUrdu(context) ? 'اگلی نماز' : 'Next Prayer';

  static String calculation(BuildContext context) =>
      _isUrdu(context) ? 'حساب کا طریقہ' : 'Calculation';

  static String calculationMethod(BuildContext context) =>
      _isUrdu(context) ? 'حساب کا طریقہ' : 'Calculation Method';

  static String asrMethod(BuildContext context) =>
      _isUrdu(context) ? 'عصر کا طریقہ' : 'Asr Method';

  static String standard(BuildContext context) =>
      _isUrdu(context) ? 'معمول' : 'Standard';

  static String hanafi(BuildContext context) =>
      _isUrdu(context) ? 'حنفی' : 'Hanafi';

  static String recommended(BuildContext context) => _isUrdu(context)
      ? 'خودکار (آف لائن)'
      : 'Automatic (Offline)';

  static String searchCity(BuildContext context) =>
      _isUrdu(context) ? 'شہر تلاش کریں' : 'Search city';

  static String manualCoordinates(BuildContext context) =>
      _isUrdu(context) ? 'دستی نقاط' : 'Manual coordinates';

  static String advanced(BuildContext context) =>
      _isUrdu(context) ? 'ایڈوانسڈ' : 'Advanced';

  static String latitude(BuildContext context) =>
      _isUrdu(context) ? 'عرضِ بلد' : 'Latitude';

  static String longitude(BuildContext context) =>
      _isUrdu(context) ? 'طولِ بلد' : 'Longitude';

  static String apply(BuildContext context) =>
      _isUrdu(context) ? 'لاگو کریں' : 'Use Coordinates';

  static String location(BuildContext context) =>
      _isUrdu(context) ? 'مقام' : 'Location';

  static String settings(BuildContext context) =>
      _isUrdu(context) ? 'نماز کے اوقات کی ترتیبات' : 'Prayer Times Settings';

  static String save(BuildContext context) =>
      _isUrdu(context) ? 'محفوظ کریں' : 'Save';

    static String refreshing(BuildContext context) =>
      _isUrdu(context) ? 'پس منظر میں تازہ کیا جا رہا ہے…' : 'Refreshing in background…';

  static String calculationError(BuildContext context) => _isUrdu(context)
      ? 'نماز کے اوقات کا حساب نہیں ہو سکا۔ مقام اور ترتیبات چیک کریں۔'
      : 'Prayer times could not be calculated. Check the location and settings.';

  static String locationError(BuildContext context) => _isUrdu(context)
      ? 'مقام حاصل نہیں ہو سکا۔ دوبارہ کوشش کریں یا دستی مقام منتخب کریں۔'
      : 'Your location could not be obtained. Try again or choose a location manually.';

  static String locationServiceDisabled(BuildContext context) =>
      _isUrdu(context) ? 'مقام کی سروس بند ہے۔' : 'Location services are turned off.';

  static String permissionDenied(BuildContext context) =>
      _isUrdu(context) ? 'مقام کی اجازت مسترد کر دی گئی۔' : 'Location permission was denied.';

  static String permissionPermanentlyDenied(BuildContext context) => _isUrdu(context)
      ? 'مقام کی اجازت مستقل طور پر بند ہے۔ ایپ کی ترتیبات سے اسے فعال کریں۔'
      : 'Location permission is permanently denied. Enable it in app settings.';

  static String openSettings(BuildContext context) =>
      _isUrdu(context) ? 'ترتیبات کھولیں' : 'Open Settings';

  static String tryAgain(BuildContext context) =>
      _isUrdu(context) ? 'دوبارہ کوشش کریں' : 'Try Again';

  static String attribution(BuildContext context) => _isUrdu(context)
      ? 'شہر اور مقام کا ڈیٹا آف لائن دستیاب ہے؛ انٹرنیٹ درکار نہیں۔'
      : 'City and location data is available offline; no internet is required.';

  static String privacyNote(BuildContext context) => _isUrdu(context)
      ? 'مقام صرف آپ کے آلے پر نماز کے اوقات کے مقامی حساب کے لیے استعمال ہوتا ہے۔'
      : 'Location is used locally on your device to calculate prayer times.';

  static String approximateLocation(BuildContext context) =>
      _isUrdu(context) ? 'تقریبی مقام' : 'Approximate location';

  static String preciseLocation(BuildContext context) =>
      _isUrdu(context) ? 'درست مقام' : 'Precise location';

  static String noResults(BuildContext context) =>
      _isUrdu(context) ? 'کوئی شہر نہیں ملا۔' : 'No cities found.';

  static String invalidCoordinates(BuildContext context) =>
      _isUrdu(context) ? 'درست latitude اور longitude درج کریں۔' : 'Enter valid latitude and longitude.';

  static String restrictionRemaining(BuildContext context, Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    final value = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return _isUrdu(context) ? 'مکروہ وقت باقی: $value' : 'Restricted time remaining: $value';
  }

  static String restrictionType(BuildContext context, RestrictionType type) {
    if (_isUrdu(context)) {
      return switch (type) {
        RestrictionType.sunrise => 'طلوعِ آفتاب',
        RestrictionType.zawal => 'زوال',
        RestrictionType.sunset => 'غروبِ آفتاب',
        RestrictionType.otherConfiguredRestriction => 'مقررہ پابندی',
      };
    }
    return switch (type) {
      RestrictionType.sunrise => 'Sunrise',
      RestrictionType.zawal => 'Zawal',
      RestrictionType.sunset => 'Sunset',
      RestrictionType.otherConfiguredRestriction => 'Configured restriction',
    };
  }

  static String qazaRestricted(BuildContext context, RestrictionType type) => _isUrdu(context)
      ? 'اس وقت ${restrictionType(context, type)} کے دوران قضا مکمل نہیں کی جا سکتی۔'
      : 'Qaza completion is unavailable during ${restrictionType(context, type).toLowerCase()} restriction.';

  static String settingsSaved(BuildContext context) =>
      _isUrdu(context) ? 'نماز کے اوقات کی ترتیبات محفوظ ہو گئیں۔' : 'Prayer time settings saved.';


  static String editLocation(BuildContext context) =>
      _isUrdu(context) ? 'مقام میں ترمیم' : 'Edit Location';

  static String today(BuildContext context) =>
      _isUrdu(context) ? 'آج' : 'Today';

  static String prayerTimes(BuildContext context) =>
      _isUrdu(context) ? 'نماز کے اوقات' : 'Prayer Times';

  static String restrictedTimes(BuildContext context) =>
      _isUrdu(context) ? 'ممنوع اوقات' : 'Restricted Times';

  static String restrictedNow(BuildContext context) =>
      _isUrdu(context) ? 'اس وقت ممنوع وقت ہے' : 'Restricted Now';

  static String restrictedFor(BuildContext context, int minutes) =>
      _isUrdu(context) ? '$minutes منٹ کی پابندی' : 'Restricted for $minutes min';

  static String timeWindow(BuildContext context, String start, String end) =>
      _isUrdu(context) ? '$start تا $end' : '$start — $end';

  static String restrictedNotifications(BuildContext context) =>
      _isUrdu(context) ? 'ممنوع اوقات کی یاد دہانیاں' : 'Restricted-time notifications';

  static String notifyBefore(BuildContext context) =>
      _isUrdu(context) ? 'کتنی دیر پہلے یاد دہانی؟' : 'Notify before restricted time';

  static String atStart(BuildContext context) =>
      _isUrdu(context) ? 'شروع ہوتے وقت' : 'At start';

  static String fiveMinutes(BuildContext context) =>
      _isUrdu(context) ? '5 منٹ پہلے' : '5 minutes before';

  static String tenMinutes(BuildContext context) =>
      _isUrdu(context) ? '10 منٹ پہلے' : '10 minutes before';

  static String notifications(BuildContext context) =>
      _isUrdu(context) ? 'یاد دہانیاں' : 'Notifications';

  static String notificationPermissionDenied(BuildContext context) =>
      _isUrdu(context)
          ? 'یاد دہانی کے لیے نوٹیفکیشن کی اجازت درکار ہے۔'
          : 'Notification permission is required for reminders.';

  static String currentLocation(BuildContext context) =>
      _isUrdu(context) ? 'موجودہ مقام' : 'Current Location';

  static String selectCountryAndCity(BuildContext context) =>
      _isUrdu(context) ? 'ملک اور شہر منتخب کریں' : 'Select Country & City';

  static String selectCountry(BuildContext context) =>
      _isUrdu(context) ? 'ملک منتخب کریں' : 'Select Country';

  static String selectCity(BuildContext context) =>
      _isUrdu(context) ? 'شہر منتخب کریں' : 'Select City';

  static String searchCountry(BuildContext context) =>
      _isUrdu(context) ? 'ملک تلاش کریں' : 'Search country';

  static String chooseCityFirst(BuildContext context) =>
      _isUrdu(context) ? 'پہلے ملک منتخب کریں۔' : 'Select a country first.';

  static String currentLocationPermission(BuildContext context) =>
      _isUrdu(context) ? 'مقام کی اجازت درکار ہوگی۔' : 'Location permission may be required.';

  static String calculationSettings(BuildContext context) =>
      _isUrdu(context) ? 'حساب کی ترتیبات' : 'Calculation Settings';

  static String countdown(Duration duration) {
    final seconds = duration.inSeconds;
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${remainingSeconds}s';
    return '${remainingSeconds}s';
  }

  static String prayerName(BuildContext context, PrayerName prayer) {
    if (_isUrdu(context)) {
      return switch (prayer) {
        PrayerName.fajr => 'فجر',
        PrayerName.sunrise => 'طلوعِ آفتاب',
        PrayerName.dhuhr => 'ظہر',
        PrayerName.asr => 'عصر',
        PrayerName.maghrib => 'مغرب',
        PrayerName.isha => 'عشاء',
      };
    }
    return switch (prayer) {
      PrayerName.fajr => 'Fajr',
      PrayerName.sunrise => 'Sunrise',
      PrayerName.dhuhr => 'Dhuhr',
      PrayerName.asr => 'Asr',
      PrayerName.maghrib => 'Maghrib',
      PrayerName.isha => 'Isha',
    };
  }

  static String methodName(BuildContext context, CalculationMethod method) {
    final urdu = _isUrdu(context);
    return switch (method) {
      CalculationMethod.recommended =>
        urdu ? 'خودکار (آف لائن)' : 'Automatic (Offline)',
      CalculationMethod.jafari => 'Jafari',
      CalculationMethod.karachi => urdu ? 'کراچی' : 'University of Islamic Sciences, Karachi',
      CalculationMethod.isna => 'ISNA',
      CalculationMethod.mwl => 'Muslim World League',
      CalculationMethod.makkah => 'Umm Al-Qura University, Makkah',
      CalculationMethod.egyptian => 'Egyptian General Authority of Survey',
      CalculationMethod.tehran => 'University of Tehran',
      CalculationMethod.gulf => 'Gulf Region',
      CalculationMethod.kuwait => 'Kuwait',
      CalculationMethod.qatar => 'Qatar',
      CalculationMethod.singapore => 'Singapore (MUIS)',
      CalculationMethod.france => 'Union Organization Islamic de France',
      CalculationMethod.turkey => 'Diyanet, Turkey',
      CalculationMethod.russia => 'Spiritual Administration of Muslims of Russia',
      CalculationMethod.moonsighting => 'Moonsighting Committee Worldwide',
      CalculationMethod.dubai => 'Dubai',
      CalculationMethod.jakim => 'JAKIM, Malaysia',
      CalculationMethod.tunisia => 'Tunisia',
      CalculationMethod.algeria => 'Algeria',
      CalculationMethod.kemenag => 'KEMENAG, Indonesia',
      CalculationMethod.morocco => 'Morocco',
      CalculationMethod.portugal => 'Islamic Community of Lisbon',
      CalculationMethod.jordan => 'Jordan Ministry of Awqaf',
    };
  }

  static String methodOption(BuildContext context, CalculationMethod method) =>
      methodName(context, method);
}
