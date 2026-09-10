import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Wraps the /ws live-notification feed. ApiFileSystemRepository listens
/// to [events] to know when to re-fetch watchFolder()/watchDeletedItems()
/// streams — there's no Firestore-style native snapshot listener on this
/// provider, so this is what replaces it.
///
/// The socket is *not* opened from a repository constructor. The backend
/// binds each connection to the uid in its handshake token
/// (`app/api/websocket.py`), so a connection cannot outlive a sign-in: it
/// has to be torn down on sign-out and reopened for the next user. A
/// lazy-singleton repository is constructed once and can never react to a
/// second sign-in, so ownership lives at the composition root instead —
/// see the `authStateChanges` wiring in `core/di/injector.dart`.
class ApiWebSocketClient {
  ApiWebSocketClient({
    required String baseUrl,
    required Future<String?> Function() getIdToken,
  }) : _baseUrl = baseUrl,
       _getIdToken = getIdToken;

  static const _reconnectDelay = Duration(seconds: 3);

  final String _baseUrl;
  final Future<String?> Function() _getIdToken;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;

  /// The in-flight [_openSocket] call, if any. Held so two callers racing
  /// into [connect] share one attempt: the `_channel != null` check alone
  /// can't serialise them, because both pass it before either has awaited
  /// the token and installed a channel.
  Future<void>? _connecting;

  /// Bumped on every teardown. A socket carries the generation it was
  /// opened under, so callbacks from a connection we've already abandoned
  /// (an old user's socket, or a reconnect that raced a sign-out) can
  /// identify themselves as stale and do nothing.
  int _generation = 0;

  /// uid whose socket we currently want open — null when signed out.
  String? _ownerId;

  /// Serialises [setOwner]. A sign-out immediately followed by a sign-in
  /// would otherwise interleave two teardowns, and the slower one could
  /// finish last and leave the client disabled with a live socket — or
  /// enabled with none.
  Future<void> _ownerChange = Future<void>.value();

  bool _enabled = false;
  bool _disposed = false;

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  /// Point the feed at [uid], or tear it down when null. Called from the
  /// composition root on every auth transition. A no-op when the uid is
  /// unchanged, so a token refresh that re-emits the same user doesn't
  /// churn a healthy connection.
  Future<void> setOwner(String? uid) {
    if (_disposed || uid == _ownerId) return _ownerChange;
    _ownerId = uid;
    return _ownerChange = _ownerChange.then((_) => _applyOwner(uid));
  }

  Future<void> _applyOwner(String? uid) async {
    // A newer setOwner() can have superseded this one while it waited its
    // turn, in which case that call owns the socket now.
    if (_disposed || uid != _ownerId) return;
    try {
      await _reset();
      if (uid != null) await connect();
    } catch (_) {
      // Never let a teardown failure poison the chain — every later owner
      // change is queued behind this future.
    }
  }

  Future<void> connect() {
    if (_disposed) return Future<void>.value();
    _enabled = true;
    return _connecting ??= _openSocket().whenComplete(() => _connecting = null);
  }

  Future<void> _openSocket() async {
    if (_channel != null || _disposed) return;
    final generation = _generation;
    final String? token;
    try {
      token = await _getIdToken();
    } catch (_) {
      // Token fetch failed (offline, or a refresh mid-flight). Treat it
      // like a dropped socket and retry — never let it escape as an
      // unhandled async error from the fire-and-forget reconnect timer.
      _scheduleReconnect(generation);
      return;
    }

    // A sign-out, a dispose, or another teardown landed while we were
    // awaiting the token. Installing a channel now would attach an
    // orphaned listener to the shared event controller — one that keeps
    // pushing the previous user's events into every open folder window.
    if (_disposed || generation != _generation || _channel != null) return;
    if (token == null) return; // signed out before we got a token

    final wsBase = _baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    final channel = WebSocketChannel.connect(
      Uri.parse('$wsBase/ws?token=$token'),
    );
    _channel = channel;
    _sub = channel.stream.listen(
      (raw) {
        try {
          _eventController.add(
            jsonDecode(raw as String) as Map<String, dynamic>,
          );
        } catch (_) {
          // malformed frame — ignore, don't take the socket down over it
        }
      },
      onDone: () => _onSocketClosed(generation),
      onError: (_) => _onSocketClosed(generation),
    );
  }

  /// A failing socket fires `onError` *and* `onDone`, and a socket from a
  /// previous generation can close long after we stopped caring about it.
  /// Both are funnelled through here so at most one reconnect is ever
  /// scheduled, and only for the connection we currently own.
  void _onSocketClosed(int generation) {
    if (_disposed || generation != _generation) return;
    _generation++;
    _sub?.cancel();
    _sub = null;
    // The peer has already closed; there's no sink left worth closing.
    _channel = null;
    _scheduleReconnect(_generation);
  }

  /// Idempotent by construction: the pending timer is always cancelled
  /// first, so however many close/error callbacks arrive, exactly one
  /// reconnect is outstanding.
  void _scheduleReconnect(int generation) {
    if (_disposed || !_enabled || generation != _generation) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectTimer = null;
      if (_disposed || !_enabled) return;
      unawaited(connect());
    });
  }

  /// Drops the current connection and invalidates anything still in
  /// flight for it, leaving the client idle but reusable.
  Future<void> _reset() async {
    _generation++;
    _enabled = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    // Let a connect that's mid-token-fetch finish first — it will see the
    // bumped generation and bail without installing a channel. Awaiting it
    // here is what stops the next connect() from being handed the stale
    // future by `_connecting ??=`.
    final inFlight = _connecting;
    if (inFlight != null) await inFlight;

    await _sub?.cancel();
    _sub = null;
    final channel = _channel;
    _channel = null;
    try {
      await channel?.sink.close();
    } catch (_) {
      // Closing a socket the peer already dropped can complete with an
      // error. It's gone either way, and we've released our reference.
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _ownerId = null;
    await _reset();
    await _eventController.close();
  }
}
