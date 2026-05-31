import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;

import '../../domain/todo.dart';
import 'google_auth_service.dart';

/// Google Calendar API wrapper. Todo ↔ Event 매핑 단일 출처.
///
/// 사용자가 [Todo.dueAt] 을 채운 채로 AddTodoSheet 의 "Calendar 등록" 토글을 켜면
/// AddTodoController 가 이 서비스를 호출 (다음 task 에서 wiring).
class CalendarService {
  CalendarService(this._auth);

  final GoogleAuthService _auth;

  /// Todo 의 dueAt 기반 이벤트 생성. dueAt 이 null 이면 null 반환.
  /// [isAllDay] true 면 시간 없는 종일 이벤트로 등록 (Google Calendar 의 `date` 필드).
  /// 사용자가 OAuth 인증을 거부/실패하면 예외 전파 — 호출자가 graceful 처리.
  Future<String?> createEventForTodo(Todo todo, {bool isAllDay = false}) async {
    if (todo.dueAt == null) return null;

    final account = await _auth.tryRestore() ?? await _auth.signIn();
    final api = await _apiFor(account);
    if (api == null) return null;

    final event = _toEvent(todo, isAllDay: isAllDay);
    try {
      final created = await api.events.insert(event, 'primary');
      return created.id;
    } finally {
      api.requester.close();
    }
  }

  /// 기존 캘린더 이벤트를 todo 의 최신 상태로 patch. dueAt 이 null 이 되면 이벤트 자체를
  /// 삭제 (호출자가 [deleteEvent] 로 별도 처리해도 OK 하지만, 이 경로가 더 명확).
  ///
  /// 사용자가 OAuth 를 끊은 경우 등 인가 실패는 예외 전파.
  Future<void> updateEventForTodo(Todo todo, String eventId) async {
    if (todo.dueAt == null) {
      await deleteEvent(eventId);
      return;
    }
    final account = await _auth.tryRestore() ?? await _auth.signIn();
    final api = await _apiFor(account);
    if (api == null) return;
    try {
      await api.events.update(_toEvent(todo), 'primary', eventId);
    } finally {
      api.requester.close();
    }
  }

  /// 캘린더 이벤트 삭제. 이미 삭제된 (404) 경우 silent — 멱등.
  Future<void> deleteEvent(String eventId) async {
    final account = await _auth.tryRestore() ?? await _auth.signIn();
    final api = await _apiFor(account);
    if (api == null) return;
    try {
      await api.events.delete('primary', eventId);
    } on gcal.DetailedApiRequestError catch (e) {
      if (e.status == 404 || e.status == 410) return; // 이미 없음 — 멱등
      rethrow;
    } finally {
      api.requester.close();
    }
  }

  Future<_AuthedCalendarApi?> _apiFor(GoogleSignInAccount account) async {
    final headers = await _auth.authHeadersForCalendar(account);
    if (headers == null) return null;
    final client = _GoogleAuthClient(headers);
    return _AuthedCalendarApi(gcal.CalendarApi(client), client);
  }

  gcal.Event _toEvent(Todo todo, {bool isAllDay = false}) =>
      buildEvent(todo, isAllDayHint: isAllDay);

  /// fast-tasks — Todo 의 날짜·기간 모델을 Google Calendar Event 로 매핑. 단일 출처.
  ///
  /// - 하루종일 / 기간+isAllDay → all-day 이벤트 (start.date / end.date,
  ///   end.date 는 종료+1일 — Google 의 exclusive 종료 규칙).
  /// - 단일 시간 (start/end anchor) → 그 시각 기준 기본 1시간 이벤트.
  /// - 기간(!isAllDay) → start.dateTime=dueAt, end.dateTime=endAt.
  ///
  /// [isAllDayHint] 는 호출자가 모델 없이 종일 의도를 줄 때의 fallback —
  /// todo 자체의 모드가 우선한다.
  @visibleForTesting
  static gcal.Event buildEvent(Todo todo, {bool isAllDayHint = false}) {
    final desc = '${todo.category.label} · Solo Todo 자동 등록';
    final due = todo.dueAt!;

    gcal.Event allDayEvent(DateTime start, DateTime endInclusive) {
      final s = start.toLocal();
      final e = endInclusive.toLocal();
      final startDate = DateTime(s.year, s.month, s.day);
      // Google 종일 이벤트의 end.date 는 exclusive → 종료 다음날.
      final endDate = DateTime(
        e.year,
        e.month,
        e.day,
      ).add(const Duration(days: 1));
      return gcal.Event(
        summary: todo.title,
        description: desc,
        start: gcal.EventDateTime(date: startDate),
        end: gcal.EventDateTime(date: endDate),
      );
    }

    gcal.Event timedEvent(DateTime start, DateTime end) => gcal.Event(
      summary: todo.title,
      description: desc,
      start: gcal.EventDateTime(dateTime: start.toUtc(), timeZone: 'UTC'),
      end: gcal.EventDateTime(dateTime: end.toUtc(), timeZone: 'UTC'),
    );

    final event = switch (todo.dateMode) {
      // none: dueAt!.toUtc() 가 위에서 보장되므로 도달 안 함. 안전상 종일로.
      TodoDateMode.none || TodoDateMode.allDay => allDayEvent(due, due),
      // 시각 기준 기본 1시간. (anchor 는 표시 의미라 캘린더는 동일하게 1h 블록.)
      TodoDateMode.startTime || TodoDateMode.endTime => timedEvent(
        due,
        due.add(const Duration(hours: 1)),
      ),
      TodoDateMode.range =>
        todo.isAllDay
            ? allDayEvent(due, todo.endAt ?? due)
            : timedEvent(due, todo.endAt ?? due),
    };

    // date-repeat: 반복 마스터면 RRULE 1개를 이벤트에 부착해 반복 일정으로 등록한다.
    // 인스턴스/일반 Todo 는 단일 이벤트 — 반복은 마스터의 RRULE 이 커버하므로 부착 X.
    final rule = todo.recurrence;
    if (todo.isRecurringMaster && rule != null) {
      event.recurrence = [rule.toRRule(todo.recurrenceEndAt)];
    }
    return event;
  }
}

class _AuthedCalendarApi {
  _AuthedCalendarApi(this._api, this.requester);
  final gcal.CalendarApi _api;
  final _GoogleAuthClient requester;
  gcal.EventsResource get events => _api.events;
}

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// CalendarService 인스턴스. GoogleAuthService 미설정 시 null.
final calendarServiceProvider = Provider<CalendarService?>((ref) {
  final auth = ref.watch(googleAuthServiceProvider);
  return auth == null ? null : CalendarService(auth);
});

/// AddTodoController 가 호출하는 헬퍼. 실패는 fatal X — todo 자체는 저장되어야 한다.
Future<String?> tryCreateCalendarEvent(Ref ref, Todo todo) async {
  final svc = ref.read(calendarServiceProvider);
  if (svc == null) return null;
  try {
    return await svc.createEventForTodo(todo);
  } catch (e) {
    debugPrint('[solo_todo] Calendar 이벤트 생성 실패: $e');
    return null;
  }
}

/// Todo 변경 시 (편집 / 삭제 흐름) 호출. eventId 가 있는 todo 만 처리.
Future<void> tryUpdateCalendarEvent(Ref ref, Todo todo) async {
  final eventId = todo.calendarEventId;
  if (eventId == null) return;
  final svc = ref.read(calendarServiceProvider);
  if (svc == null) return;
  try {
    await svc.updateEventForTodo(todo, eventId);
  } catch (e) {
    debugPrint('[solo_todo] Calendar 이벤트 갱신 실패: $e');
  }
}

Future<void> tryDeleteCalendarEvent(Ref ref, String? eventId) async {
  if (eventId == null) return;
  final svc = ref.read(calendarServiceProvider);
  if (svc == null) return;
  try {
    await svc.deleteEvent(eventId);
  } catch (e) {
    debugPrint('[solo_todo] Calendar 이벤트 삭제 실패: $e');
  }
}
