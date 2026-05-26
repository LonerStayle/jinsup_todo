/// 가벼운 한국어 날짜 포맷터. intl 의 locale data 초기화 의존성 없이 동작.
///
/// 예: 2026-05-27 → "5월 27일 화요일"
class KoDate {
  const KoDate._();

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  static String pretty(DateTime d) =>
      '${d.month}월 ${d.day}일 ${_weekdays[d.weekday - 1]}요일';

  /// 시간만 — "14:30". 24h.
  static String time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
