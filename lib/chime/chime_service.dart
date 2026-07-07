import 'dart:async';
import 'dart:convert';
import 'package:eggnstone_amazon_chime/eggnstone_amazon_chime.dart';

class ChimeService {
  StreamSubscription<dynamic>? _eventSubscription;
  void Function(String eventName, Map<String, dynamic> arguments)? _onEvent;

  /// Initializes the service and starts listening to Chime native events.
  void initialize(void Function(String name, Map<String, dynamic> args) onEvent) {
    _onEvent = onEvent;
    _eventSubscription = Chime.eventChannel.receiveBroadcastStream().listen((dynamic eventStr) {
      if (eventStr is String) {
        try {
          final Map<String, dynamic> event = jsonDecode(eventStr);
          final String name = event['Name'] ?? '';
          final Map<String, dynamic> arguments = event['Arguments'] != null 
              ? Map<String, dynamic>.from(event['Arguments']) 
              : {};
          _onEvent?.call(name, arguments);
        } catch (e) {
          // Ignore parse errors or pass log
        }
      }
    });
  }

  /// Disposes the service and stops listening to events.
  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _onEvent = null;
  }

  /// Configures the meeting session using data fetched from backend.
  Future<void> setupMeetingSession(Map<String, dynamic> apiData) async {
    final meeting = apiData['meeting'] as Map<String, dynamic>;
    final attendee = apiData['attendee'] as Map<String, dynamic>;
    final mediaPlacement = meeting['MediaPlacement'] as Map<String, dynamic>;

    // We must clean up any view IDs on native side to start clean
    await Chime.clearViewIds();

    final result = await Chime.createMeetingSession(
      meetingId: meeting['MeetingId'] ?? '',
      externalMeetingId: meeting['ExternalMeetingId'] ?? '',
      mediaRegion: meeting['MediaRegion'] ?? '',
      mediaPlacementAudioHostUrl: mediaPlacement['AudioHostUrl'] ?? '',
      mediaPlacementAudioFallbackUrl: mediaPlacement['AudioFallbackUrl'] ?? '',
      mediaPlacementSignalingUrl: mediaPlacement['SignalingUrl'] ?? '',
      mediaPlacementTurnControlUrl: mediaPlacement['TurnControlUrl'] ?? '',
      attendeeId: attendee['AttendeeId'] ?? '',
      externalUserId: attendee['ExternalUserId'] ?? '',
      joinToken: attendee['JoinToken'] ?? '',
    );

    if (result != null && result.isNotEmpty && result != 'OK') {
      throw Exception('Failed to create meeting session: $result');
    }
  }

  /// Starts audio and video.
  Future<void> startAudioVideo() async {
    await Chime.audioVideoStart();
    await Chime.audioVideoStartRemoteVideo();
  }

  /// Stops audio and video.
  Future<void> stopAudioVideo() async {
    await Chime.audioVideoStop();
  }

  /// Starts local video capture.
  Future<void> startLocalVideo() async {
    await Chime.audioVideoStartLocalVideo();
  }

  /// Stops local video capture.
  Future<void> stopLocalVideo() async {
    await Chime.audioVideoStopLocalVideo();
  }

  /// Mutes local microphone.
  Future<void> mute() async {
    await Chime.mute();
  }

  /// Unmutes local microphone.
  Future<void> unmute() async {
    await Chime.unmute();
  }

  /// Binds a native video view widget to a Chime video tile ID.
  Future<void> bindVideoView(int viewId, int tileId) async {
    await Chime.bindVideoView(viewId, tileId);
  }

  /// Unbinds a native video view widget from a Chime video tile ID.
  Future<void> unbindVideoView(int tileId) async {
    await Chime.unbindVideoView(tileId);
  }
}
