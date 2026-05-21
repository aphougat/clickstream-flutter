/// SurveyAnalytica Clickstream SDK for Flutter.
///
/// Captures behavioral events from Flutter apps and sends them to the
/// SurveyAnalytica workflow engine in batches.
///
/// ## Quick start
///
/// ```dart
/// import 'package:sa_clickstream/sa_clickstream.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await SAClickstream.init(
///     workflowId: '<WORKFLOW_ID>',
///     apiKey:     '<API_KEY>',
///     saEndpoint: 'https://your-sa-instance.com',
///   );
///
///   runApp(const MyApp());
/// }
/// ```
///
/// ## Auto screen tracking
///
/// Attach [SAClickstream.routeObserver] to `MaterialApp.navigatorObservers`:
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [SAClickstream.routeObserver],
/// )
/// ```
library sa_clickstream;

export 'src/clickstream_client.dart' show SAClickstream, SARouteObserver;
