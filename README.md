# sa_clickstream

SurveyAnalytica Clickstream SDK for Flutter. Captures behavioral events from Flutter apps and sends them in batches to the SurveyAnalytica workflow engine.

## Features

- Automatic batching (500 ms debounce or 20 events)
- Exponential backoff retry (3 attempts)
- Persistent anonymous identity via `shared_preferences`
- `uid_transition` events for identity resolution after login
- Consent management — `setConsent(false)` stops all tracking
- `SARouteObserver` for automatic screen tracking via Flutter's `NavigatorObserver`

## Installation

```yaml
dependencies:
  sa_clickstream: ^1.0.0
```

```
flutter pub get
```

## Setup

### 1. Initialize in `main.dart`

```dart
import 'package:sa_clickstream/sa_clickstream.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SAClickstream.initialize(
    workflowId: 'YOUR_WORKFLOW_ID',
    apiKey: 'YOUR_API_KEY',
    saEndpoint: 'https://your-sa-integration-url',
  );

  runApp(const MyApp());
}
```

### 2. Add `SARouteObserver` for automatic screen tracking

```dart
final _routeObserver = SARouteObserver();

MaterialApp(
  navigatorObservers: [_routeObserver],
  ...
)
```

## Usage

```dart
// Track a named event
SAClickstream.track('button_tapped', properties: {'label': 'Buy Now'});

// Track a screen view manually
SAClickstream.page('ProductDetailScreen');

// Identify a user after login
SAClickstream.identify('user-123');

// Revoke consent
SAClickstream.setConsent(false);
```

## How it works

Events are queued locally and flushed every 500 ms (or when the queue reaches 20 events). Each flush sends a `POST /api/v1/clickstream/{workflowId}` request with the `code` header set to your API key. Failed requests are retried up to 3 times with exponential backoff.

Anonymous identity is persisted in `shared_preferences` so users are consistently identified across sessions until `identify()` is called.

## License

MIT
