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

  /// Todo 의 dueAt 기반 1 시간짜리 이벤트 생성. dueAt 이 null 이면 null 반환.
  /// 사용자가 OAuth 인증을 거부/실패하면 예외 전파 — 호출자가 graceful 처리.
  Future<String?> createEventForTodo(Todo todo) async {
    if (todo.dueAt == null) return null;

    final account = await _auth.tryRestore() ?? await _auth.signIn();
    final api = await _apiFor(account);
    if (api == null) return null;

    final event = _toEvent(todo);
    try {
      final created = await api.events.insert(event, 'primary');
      return created.id;
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

  gcal.Event _toEvent(Todo todo) {
    final start = todo.dueAt!.toUtc();
    final end = start.add(const Duration(hours: 1));
    return gcal.Event(
      summary: todo.title,
      description: '${todo.category.label} · Solo Todo 자동 등록',
      start: gcal.EventDateTime(dateTime: start, timeZone: 'UTC'),
      end: gcal.EventDateTime(dateTime: end, timeZone: 'UTC'),
    );
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
