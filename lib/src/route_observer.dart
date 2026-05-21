/// Re-exports [SARouteObserver] from [clickstream_client.dart].
///
/// [SARouteObserver] is defined alongside [SAClickstream] in
/// `clickstream_client.dart` so that [SAClickstream.routeObserver] can
/// reference it without a circular import.  This file exists so that
/// consumers can import `route_observer.dart` directly if they prefer, and
/// so the public barrel (`sa_clickstream.dart`) has a stable export target.
export 'clickstream_client.dart' show SARouteObserver;
