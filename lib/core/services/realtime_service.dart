import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class RealtimeService {
  final SupabaseClient _supabase;

  // Storage for active channels: { channelName: RealtimeChannel }
  final Map<String, RealtimeChannel> _channels = {};

  // Storage for event controllers: { channelName: { eventName: StreamController } }
  final Map<String, Map<String, StreamController<Map<String, dynamic>>>>
  _controllers = {};

  final Map<String, StreamController<RealtimeSubscribeStatus>>
  _statusControllers = {};

  RealtimeService(this._supabase);

  /// Returns a stream for a specific broadcast event on a specific channel.
  /// If the channel isn't created yet, it will be initialized and subscribed.
  Stream<Map<String, dynamic>> onBroadcast({
    required String channel,
    required String event,
  }) {
    // 1. Ensure the channel exists and is subscribed
    final rtChannel = _getOrCreateChannel(channel);

    // 2. Ensure the controller map for this channel exists
    final channelControllers = _controllers.putIfAbsent(channel, () => {});

    // 3. Ensure the controller for this specific event exists
    return channelControllers.putIfAbsent(event, () {
      final controller = StreamController<Map<String, dynamic>>.broadcast();

      rtChannel.onBroadcast(
        event: event,
        callback: (payload) {
          if (kDebugMode) {
            print('📡 [RealtimeService] [$channel] Event: $event -> $payload');
          }
          controller.add(payload);
        },
      );

      return controller;
    }).stream;
  }

  /// Join and rejoin status for [channel]. `subscribed` fires on first join
  /// and again when the socket rejoins after a drop.
  Stream<RealtimeSubscribeStatus> onChannelStatus(String channel) {
    _getOrCreateChannel(channel);
    return _statusControllers[channel]!.stream;
  }

  RealtimeChannel _getOrCreateChannel(String channelName) {
    if (_channels.containsKey(channelName)) {
      return _channels[channelName]!;
    }

    final statusController =
        StreamController<RealtimeSubscribeStatus>.broadcast();
    _statusControllers[channelName] = statusController;

    final channel = _supabase.channel(channelName);
    _channels[channelName] = channel;

    channel.subscribe((status, [error]) {
      if (!statusController.isClosed) {
        statusController.add(status);
      }
      if (kDebugMode) {
        print(
          '📡 [RealtimeService] [$channelName] Status: $status ${error != null ? 'Error: $error' : ''}',
        );
      }
    });

    return channel;
  }

  /// Unsubscribes from and removes a specific channel.
  void leaveChannel(String channelName) {
    _channels[channelName]?.unsubscribe();
    _channels.remove(channelName);

    _controllers[channelName]?.values.forEach((c) => c.close());
    _controllers.remove(channelName);

    _statusControllers[channelName]?.close();
    _statusControllers.remove(channelName);

    if (kDebugMode) {
      print('📡 [RealtimeService] Left channel: $channelName');
    }
  }

  /// Clean up all channels and controllers (e.g. on logout).
  void reset() {
    final channelNames = _channels.keys.toList();
    for (var name in channelNames) {
      leaveChannel(name);
    }
    _controllers.clear();
    _channels.clear();

    if (kDebugMode) {
      print('📡 [RealtimeService] Reset all channels');
    }
  }
}
