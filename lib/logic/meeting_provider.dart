import 'package:flutter/foundation.dart';
import '../api/chime_api.dart';
import '../chime/chime_service.dart';

enum MeetingStatus {
  idle,
  joining,
  connected,
  disconnected,
}

class MeetingProvider with ChangeNotifier {
  final ChimeService _chimeService = ChimeService();

  MeetingStatus _status = MeetingStatus.idle;
  String? _meetingId;
  String? _attendeeId;
  String? _role;

  int? _localTileId;
  int? _remoteTileId;

  bool _isMicMuted = false;
  bool _isCameraEnabled = true;

  String _apiKey = 'rlN5zr6YKn1MKvqCJu8s';

  final List<String> _eventLogs = [];

  // Getters
  MeetingStatus get status => _status;
  String? get meetingId => _meetingId;
  String? get attendeeId => _attendeeId;
  String? get role => _role;
  int? get localTileId => _localTileId;
  int? get remoteTileId => _remoteTileId;
  bool get isMicMuted => _isMicMuted;
  bool get isCameraEnabled => _isCameraEnabled;
  String get apiKey => _apiKey;
  List<String> get eventLogs => List.unmodifiable(_eventLogs);

  void setApiKey(String key) {
    _apiKey = key;
    notifyListeners();
  }

  MeetingProvider() {
    _chimeService.initialize(_handleChimeEvent);
  }

  @override
  void dispose() {
    _chimeService.dispose();
    super.dispose();
  }

  /// Appends a message to the event logs with a formatted timestamp.
  void logEvent(String message) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _eventLogs.insert(0, '[$timeStr] $message');
    notifyListeners();
  }

  /// Clears the event logs.
  void clearLogs() {
    _eventLogs.clear();
    notifyListeners();
  }

  /// Handles incoming events from the Chime native wrapper.
  void _handleChimeEvent(String eventName, Map<String, dynamic> arguments) {
    switch (eventName) {
      case 'OnAudioSessionStarted':
        _status = MeetingStatus.connected;
        logEvent('Meeting connected (Audio session started)');
        notifyListeners();
        break;

      case 'OnAudioSessionStopped':
        _status = MeetingStatus.disconnected;
        logEvent('Meeting disconnected (Audio session stopped)');
        notifyListeners();
        break;

      case 'OnVideoSessionStarted':
        logEvent('Video session started successfully');
        break;

      case 'OnVideoSessionStopped':
        logEvent('Video session stopped');
        break;

      case 'OnVideoTileAdded':
        final int? tileId = arguments['TileId'];
        final bool? isLocal = arguments['IsLocalTile'];
        final String? attendee = arguments['AttendeeId'];

        if (tileId != null) {
          if (isLocal == true) {
            _localTileId = tileId;
            logEvent('Local video tile added (Tile ID: $tileId)');
          } else {
            _remoteTileId = tileId;
            logEvent('Remote video tile added (Tile ID: $tileId, Attendee: $attendee)');
          }
          notifyListeners();
        }
        break;

      case 'OnVideoTileRemoved':
        final int? tileId = arguments['TileId'];
        final bool? isLocal = arguments['IsLocalTile'];

        if (tileId != null) {
          if (isLocal == true) {
            _localTileId = null;
            logEvent('Local video tile removed');
          } else {
            _remoteTileId = null;
            logEvent('Remote video tile removed');
          }
          notifyListeners();
        }
        break;

      case 'OnAttendeesJoined':
        final List<dynamic>? attendeeInfos = arguments['AttendeeInfos'];
        if (attendeeInfos != null) {
          for (var info in attendeeInfos) {
            final extUser = info['ExternalUserId'];
            final id = info['AttendeeId'];
            logEvent('Participant joined: $extUser ($id)');
          }
        }
        break;

      case 'OnAttendeesLeft':
        final List<dynamic>? attendeeInfos = arguments['AttendeeInfos'];
        if (attendeeInfos != null) {
          for (var info in attendeeInfos) {
            final extUser = info['ExternalUserId'];
            final id = info['AttendeeId'];
            logEvent('Participant left: $extUser ($id)');
          }
        }
        break;

      case 'OnAttendeesMuted':
        final List<dynamic>? attendeeInfos = arguments['AttendeeInfos'];
        if (attendeeInfos != null) {
          for (var info in attendeeInfos) {
            final extUser = info['ExternalUserId'];
            logEvent('Participant muted: $extUser');
          }
        }
        break;

      case 'OnAttendeesUnmuted':
        final List<dynamic>? attendeeInfos = arguments['AttendeeInfos'];
        if (attendeeInfos != null) {
          for (var info in attendeeInfos) {
            final extUser = info['ExternalUserId'];
            logEvent('Participant unmuted: $extUser');
          }
        }
        break;

      default:
        // Other events like OnSignalStrengthChanged or OnVolumeChanged can be ignored or logged
        break;
    }
  }

  /// Creates a meeting session as the host agent.
  Future<void> createMeeting() async {
    if (_status != MeetingStatus.idle) return;

    _status = MeetingStatus.joining;
    clearLogs();
    logEvent('Requesting meeting creation from backend API...');
    notifyListeners();

    try {
      final apiData = await ChimeApi.createMeeting(apiKey: _apiKey);
      final meeting = apiData['meeting'] as Map<String, dynamic>;
      final attendee = apiData['attendee'] as Map<String, dynamic>;

      _meetingId = meeting['MeetingId'];
      _attendeeId = attendee['AttendeeId'];
      _role = 'agent';

      logEvent('Meeting created successfully: $_meetingId');
      logEvent('Configuring native Chime session...');
      await _chimeService.setupMeetingSession(apiData);

      logEvent('Connecting to Chime audio/video server...');
      await _chimeService.startAudioVideo();

      if (_isCameraEnabled) {
        logEvent('Enabling local camera...');
        await _chimeService.startLocalVideo();
      }

      if (_isMicMuted) {
        await _chimeService.mute();
      } else {
        await _chimeService.unmute();
      }
    } catch (e) {
      _status = MeetingStatus.idle;
      logEvent('Error starting meeting: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Joins an existing meeting session.
  Future<void> joinMeetingRoom(String targetMeetingId, String selectedRole) async {
    if (_status != MeetingStatus.idle) return;

    _status = MeetingStatus.joining;
    clearLogs();
    logEvent('Requesting join credentials for meeting: $targetMeetingId...');
    notifyListeners();

    try {
      final apiData = await ChimeApi.joinMeeting(
        meetingId: targetMeetingId,
        role: selectedRole,
        apiKey: _apiKey,
      );

      final meeting = apiData['meeting'] as Map<String, dynamic>;
      final attendee = apiData['attendee'] as Map<String, dynamic>;

      _meetingId = meeting['MeetingId'];
      _attendeeId = attendee['AttendeeId'];
      _role = selectedRole;

      logEvent('Join credentials retrieved successfully.');
      logEvent('Configuring native Chime session...');
      await _chimeService.setupMeetingSession(apiData);

      logEvent('Connecting to Chime audio/video server...');
      await _chimeService.startAudioVideo();

      if (_isCameraEnabled) {
        logEvent('Enabling local camera...');
        await _chimeService.startLocalVideo();
      }

      if (_isMicMuted) {
        await _chimeService.mute();
      } else {
        await _chimeService.unmute();
      }
    } catch (e) {
      _status = MeetingStatus.idle;
      logEvent('Error joining meeting: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Toggles the local microphone mute state.
  Future<void> toggleMicrophone() async {
    _isMicMuted = !_isMicMuted;
    notifyListeners();

    if (_status == MeetingStatus.connected || _status == MeetingStatus.joining) {
      if (_isMicMuted) {
        await _chimeService.mute();
        logEvent('Microphone disabled (muted)');
      } else {
        await _chimeService.unmute();
        logEvent('Microphone enabled (unmuted)');
      }
    }
  }

  /// Toggles local video capture.
  Future<void> toggleCamera() async {
    _isCameraEnabled = !_isCameraEnabled;
    notifyListeners();

    if (_status == MeetingStatus.connected || _status == MeetingStatus.joining) {
      if (_isCameraEnabled) {
        logEvent('Enabling camera...');
        await _chimeService.startLocalVideo();
      } else {
        logEvent('Disabling camera...');
        await _chimeService.stopLocalVideo();
      }
    }
  }

  /// Leaves the meeting and resets the state.
  Future<void> leaveMeeting() async {
    if (_status == MeetingStatus.idle) return;

    logEvent('Leaving the meeting...');
    try {
      await _chimeService.stopAudioVideo();
    } catch (e) {
      logEvent('Error stopping session: $e');
    }

    _status = MeetingStatus.idle;
    _meetingId = null;
    _attendeeId = null;
    _role = null;
    _localTileId = null;
    _remoteTileId = null;
    notifyListeners();
  }

  /// Binds a native view to a video tile. Called by UI when PlatformView is ready.
  Future<void> bindVideoView(int viewId, int tileId) async {
    try {
      await _chimeService.bindVideoView(viewId, tileId);
    } catch (e) {
      logEvent('Error binding video view: $e');
    }
  }

  /// Unbinds a video tile.
  Future<void> unbindVideoView(int tileId) async {
    try {
      await _chimeService.unbindVideoView(tileId);
    } catch (e) {
      logEvent('Error unbinding video view: $e');
    }
  }
}
