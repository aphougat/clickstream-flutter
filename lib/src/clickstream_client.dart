import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'uuid.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _kStorageKey = 'sa_id';
const _kMaxBatchSize = 20;
const _kFlushIntervalMs = 500;
const _kMaxRetryAttempts = 3;

// ---------------------------------------------------------------------------
// SARouteObserver
// ---------------------------------------------------------------------------

/// A [RouteObserver] that automatically tracks screen views via [SAClickstream].
///
/// Attach the singleton [SAClickstream.routeObserver] to
/// [MaterialApp.navigatorObservers]:
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [SAClickstream.routeObserver],
/// )
/// ```
///
/// Each time a [PageRoute] is pushed, popped, or replaced the current route
/// name is forwarded to [SAClickstream.page].
class SARouteObserver extends RouteObserver<PageRoute<dynamic>> {
  SARouteObserver._();

  static final SARouteObserver _instance = SARouteObserver._();

  /// The shared singleton used by [SAClickstream.routeObserver].
  static SARouteObserver get instance => _instance;

  void _trackPage(Route<dynamic>? route) {
    if (route == null) return;
    final name = route.settings.name;
    // Unnamed routes (null or empty) are silently ignored.
    if (name == null || name.isEmpty) return;
    SAClickstream.page(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackPage(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _trackPage(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _trackPage(newRoute);
  }
}

// ---------------------------------------------------------------------------
// SAClickstream — public singleton facade
// ---------------------------------------------------------------------------

/// The SurveyAnalytica Clickstream SDK.
///
/// Initialise once inside `main()` before calling any other method:
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await SAClickstream.init(
///     workflowId: '<WORKFLOW_ID>',
///     apiKey:     '<API_KEY>',
///     saEndpoint: 'https://your-sa-instance.com',
///   );
///   runApp(const MyApp());
/// }
/// ```
class SAClickstream {
  SAClickstream._();

  static final _SAClickstreamClient _client = _SAClickstreamClient();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// The [SARouteObserver] singleton for automatic screen-view tracking.
  ///
  /// Add this to [MaterialApp.navigatorObservers]:
  ///
  /// ```dart
  /// MaterialApp(
  ///   navigatorObservers: [SAClickstream.routeObserver],
  ///   ...
  /// )
  /// ```
  static SARouteObserver get routeObserver => SARouteObserver.instance;

  /// Initialises the SDK.
  ///
  /// Must be awaited before calling [track], [page], or [identify].
  ///
  /// [rootDomain] is not applicable for mobile and may be left `null`.
  static Future<void> init({
    required String workflowId,
    required String apiKey,
    required String saEndpoint,
    String? rootDomain,
  }) {
    return _client.init(
      workflowId: workflowId,
      apiKey: apiKey,
      saEndpoint: saEndpoint,
      rootDomain: rootDomain,
    );
  }

  /// Tracks a named event with optional [properties].
  ///
  /// ```dart
  /// SAClickstream.track('button_tap', properties: {'label': 'Buy Now'});
  /// ```
  static void track(String eventName, {Map<String, dynamic>? properties}) {
    _client.track(eventName, properties: properties);
  }

  /// Records a screen view for the given [screenName].
  ///
  /// Call this from `initState` / `didChangeDependencies`, or rely on the
  /// automatic tracking provided by [routeObserver].
  ///
  /// ```dart
  /// SAClickstream.page('ProductDetailScreen');
  /// ```
  static void page(String screenName) {
    _client.page(screenName);
  }

  /// Associates future events with a known contact ID (e.g. after login).
  ///
  /// Emits a `uid_transition` event and flushes any queued events that used
  /// the anonymous ID.
  ///
  /// ```dart
  /// await SAClickstream.identify('user_contact_id');
  /// ```
  static Future<void> identify(String contactId) {
    return _client.identify(contactId);
  }

  /// Grants or revokes tracking consent.
  ///
  /// When [given] is `false` a `consent_rejected` event is flushed
  /// immediately and all subsequent tracking calls are silently ignored
  /// until consent is re-granted.
  ///
  /// ```dart
  /// await SAClickstream.setConsent(false);
  /// ```
  static Future<void> setConsent(bool given) {
    return _client.setConsent(given);
  }

  /// Flushes any queued events immediately.
  ///
  /// The SDK flushes automatically every 500 ms or when 20 events are
  /// queued, so manual flushing is rarely needed. Call it before the app
  /// is suspended or terminated if you need to guarantee delivery.
  static Future<void> flush() {
    return _client.flush();
  }
}

// ---------------------------------------------------------------------------
// Internal implementation
// ---------------------------------------------------------------------------

class _SAClickstreamClient {
  // --- Config ---
  late String _workflowId;
  late String _apiKey;
  late String _saEndpoint;

  // --- State ---
  String? _contactId;
  late String _sessionId;
  bool _initialized = false;
  bool _consentGiven = true;

  // --- Batch queue ---
  final List<Map<String, dynamic>> _queue = [];
  Timer? _flushTimer;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  Future<void> init({
    required String workflowId,
    required String apiKey,
    required String saEndpoint,
    String? rootDomain,
  }) async {
    if (workflowId.isEmpty) {
      throw ArgumentError('workflowId must not be empty.');
    }
    if (apiKey.isEmpty) {
      throw ArgumentError('apiKey must not be empty.');
    }
    if (saEndpoint.isEmpty) {
      throw ArgumentError('saEndpoint must not be empty.');
    }

    _workflowId = workflowId;
    _apiKey = apiKey;
    _saEndpoint = saEndpoint.replaceAll(RegExp(r'/+$'), '');
    _sessionId = generateUuidV4();

    // Resolve persistent contact ID from shared_preferences.
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString(_kStorageKey);
    if (storedId == null || storedId.isEmpty) {
      storedId = generateUuidV4();
      await prefs.setString(_kStorageKey, storedId);
    }
    _contactId = storedId;

    _initialized = true;

    // Start the recurring flush timer.
    _startFlushTimer();
  }

  // ---------------------------------------------------------------------------
  // Public methods
  // ---------------------------------------------------------------------------

  void track(String eventName, {Map<String, dynamic>? properties}) {
    if (!_initialized) {
      _log('warn', 'Call init() before track().');
      return;
    }
    if (!_consentGiven) return;
    _enqueue(_buildEvent(eventName, properties ?? {}));
  }

  void page(String screenName) {
    if (!_initialized) {
      _log('warn', 'Call init() before page().');
      return;
    }
    if (!_consentGiven) return;
    _enqueue(_buildEvent('page_view', {'screen': screenName}));
  }

  Future<void> identify(String contactId) async {
    if (!_initialized) {
      _log('warn', 'Call init() before identify().');
      return;
    }
    if (!_consentGiven) return;
    if (contactId.isEmpty) {
      _log('warn', 'identify() requires a non-empty contactId.');
      return;
    }

    final oldId = _contactId;
    _contactId = contactId;

    // Persist the new ID.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStorageKey, contactId);

    // Emit uid_transition if the ID changed.
    if (oldId != contactId) {
      await _postUidTransition(oldId, contactId);
    }

    // Flush events that were queued under the old anonymous ID.
    await flush();
  }

  Future<void> setConsent(bool given) async {
    if (!given) {
      if (_initialized) {
        // Enqueue consent_rejected and flush immediately.
        _queue.add(_buildEvent('consent_rejected', {}));
        await flush();
      }
      _consentGiven = false;
    } else {
      _consentGiven = true;
    }
  }

  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;

    if (_queue.isEmpty) {
      _startFlushTimer();
      return;
    }

    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();

    await _sendBatchWithRetry(batch);

    _startFlushTimer();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _enqueue(Map<String, dynamic> event) {
    _queue.add(event);
    if (_queue.length >= _kMaxBatchSize) {
      // Don't await — fire and forget to keep track() synchronous.
      flush();
    }
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      const Duration(milliseconds: _kFlushIntervalMs),
      (_) => flush(),
    );
  }

  Map<String, dynamic> _buildEvent(
    String eventName,
    Map<String, dynamic> properties,
  ) {
    return {
      'type': 'event',
      'contactId': _contactId,
      'sessionId': _sessionId,
      'event': eventName,
      'properties': properties,
      'device': _deviceInfo(),
      'ts': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _deviceInfo() {
    final String platform;
    if (Platform.isIOS) {
      platform = 'ios';
    } else if (Platform.isAndroid) {
      platform = 'android';
    } else {
      platform = Platform.operatingSystem;
    }
    return {'platform': platform};
  }

  String _endpointUrl() {
    return '$_saEndpoint/api/v1/clickstream/$_workflowId';
  }

  Future<void> _postUidTransition(String? oldId, String newId) async {
    final payload = {
      'type': 'uid_transition',
      'oldId': oldId,
      'newId': newId,
      'sessionId': _sessionId,
      'ts': DateTime.now().toUtc().toIso8601String(),
    };
    await _sendBatchWithRetry([payload]);
  }

  Future<void> _sendBatchWithRetry(
    List<Map<String, dynamic>> batch, {
    int attempt = 1,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_endpointUrl()),
        headers: {
          'Content-Type': 'application/json',
          'code': _apiKey,
        },
        body: jsonEncode({'batch': batch}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      // Non-2xx response — treat as an error and schedule a retry.
      throw http.ClientException(
        'HTTP ${response.statusCode}',
        Uri.parse(_endpointUrl()),
      );
    } catch (e) {
      if (attempt >= _kMaxRetryAttempts) {
        // Silently drop after max retries to avoid blocking the app.
        _log('error', 'Dropping batch after $attempt attempts: $e');
        return;
      }

      // Exponential back-off: 1 s, 2 s, 4 s, …
      final delaySeconds = 1 << (attempt - 1); // 2^(attempt-1)
      await Future<void>.delayed(Duration(seconds: delaySeconds));
      await _sendBatchWithRetry(batch, attempt: attempt + 1);
    }
  }

  void _log(String level, String message) {
    // ignore: avoid_print
    print('[SAClickstream][$level] $message');
  }
}
