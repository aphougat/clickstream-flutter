# Changelog

All notable changes to this package will be documented in this file.

## 1.0.0

- Initial release of the SurveyAnalytica Clickstream SDK for Flutter.
- `SAClickstream.init()` — initialise with workflowId, apiKey, and saEndpoint.
- `SAClickstream.track()` — track named events with optional properties.
- `SAClickstream.page()` — track screen views by name.
- `SAClickstream.identify()` — associate events with a known contact ID; emits a `uid_transition` event.
- `SAClickstream.setConsent()` — grant or revoke tracking consent.
- `SAClickstream.flush()` — manually flush queued events.
- `SAClickstream.routeObserver` — attach to `MaterialApp.navigatorObservers` for automatic screen-view tracking.
- Timer-based batching: flush every 500 ms or when 20 events are queued.
- Exponential back-off retry: up to 3 attempts (1 s, 2 s, 4 s delays).
- Pure-Dart UUID v4 generator (no external UUID package dependency).
- Persistent anonymous identity stored in `shared_preferences` under the key `sa_id`.
- Platform detection via `dart:io` `Platform` (returns `"ios"` / `"android"` / OS name).
