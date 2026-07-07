import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:eggnstone_amazon_chime/eggnstone_amazon_chime.dart';
import '../logic/meeting_provider.dart';
import 'theme.dart';

class MeetingScreen extends StatefulWidget {
  const MeetingScreen({super.key});

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  bool _isLogExpanded = false;

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Meeting ID copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildStatusBadge(MeetingStatus status) {
    Color badgeColor;
    String label;
    bool pulse = false;

    switch (status) {
      case MeetingStatus.idle:
        badgeColor = AppTheme.textMuted;
        label = 'Idle';
        break;
      case MeetingStatus.joining:
        badgeColor = Colors.orangeAccent;
        label = 'Joining';
        pulse = true;
        break;
      case MeetingStatus.connected:
        badgeColor = AppTheme.accentGreen;
        label = 'Connected';
        break;
      case MeetingStatus.disconnected:
        badgeColor = AppTheme.errorRed;
        label = 'Disconnected';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse)
            const SizedBox(
              width: 8,
              height: 8,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
              ),
            )
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badgeColor,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MeetingProvider>(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await provider.leaveMeeting();
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              Text(
                provider.role == 'agent' ? 'Hosting Call' : 'Joined Call',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (provider.meetingId != null)
                GestureDetector(
                  onTap: () => _copyToClipboard(provider.meetingId!),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ID: ${provider.meetingId!.substring(0, 8)}...',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.copy, size: 12, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(child: _buildStatusBadge(provider.status)),
            ),
          ],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await provider.leaveMeeting();
              if (mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: Column(
          children: [
            // Video views container
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Stack(
                  children: [
                    // Main layout/Remote Video viewport
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        color: AppTheme.darkCard,
                        width: double.infinity,
                        height: double.infinity,
                        child: provider.remoteTileId != null
                            ? KeyedSubtree(
                                key: ValueKey(provider.remoteTileId),
                                child: ChimeDefaultVideoRenderView(
                                  onPlatformViewCreated: (viewId) {
                                    provider.bindVideoView(viewId, provider.remoteTileId!);
                                  },
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppTheme.textMuted.withOpacity(0.1),
                                      ),
                                      child: const Icon(
                                        Icons.person_outline_rounded,
                                        size: 64,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Waiting for remote participant...',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (provider.meetingId != null) ...[
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        onPressed: () => _copyToClipboard(provider.meetingId!),
                                        icon: const Icon(Icons.copy, size: 14, color: AppTheme.secondaryNeon),
                                        label: const Text(
                                          'Share Meeting ID',
                                          style: TextStyle(color: AppTheme.secondaryNeon, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                    ),

                    // Picture-in-Picture Local Video preview
                    if (provider.localTileId != null && provider.isCameraEnabled)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          width: 110,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryNeon, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: KeyedSubtree(
                              key: ValueKey(provider.localTileId),
                              child: ChimeDefaultVideoRenderView(
                                onPlatformViewCreated: (viewId) {
                                  provider.bindVideoView(viewId, provider.localTileId!);
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Controls & Event Log Container
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(
                  top: BorderSide(color: AppTheme.darkBorder, width: 1.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Collapsible Activity Log header
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isLogExpanded = !_isLogExpanded;
                      });
                    },
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.list_alt_rounded, size: 20, color: AppTheme.secondaryNeon),
                              SizedBox(width: 8),
                              Text(
                                'Meeting Activity Log',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            _isLogExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                            color: AppTheme.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Event Log body (scrolling list)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: _isLogExpanded ? 160 : 0,
                    curve: Curves.easeInOut,
                    child: ClipRect(
                      child: provider.eventLogs.isEmpty
                          ? const Center(
                              child: Text(
                                'No events logged yet.',
                                style: TextStyle(color: AppTheme.textMuted),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              itemCount: provider.eventLogs.length,
                              itemBuilder: (context, index) {
                                final log = provider.eventLogs[index];
                                final isSystem = log.contains('Error') || log.contains('connected');
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(
                                    log,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isSystem ? AppTheme.secondaryNeon : AppTheme.textSecondary,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),

                  const Divider(color: AppTheme.darkBorder, height: 1),

                  // Floating Toolbar controls
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 28.0, left: 24, right: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Toggle Mic
                        _buildControlButton(
                          icon: provider.isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          label: 'Mic',
                          color: provider.isMicMuted ? AppTheme.errorRed : AppTheme.darkBorder,
                          onPressed: () => provider.toggleMicrophone(),
                        ),

                        // End Call
                        GestureDetector(
                          onTap: () async {
                            await provider.leaveMeeting();
                            if (mounted) Navigator.pop(context);
                          },
                          child: Container(
                            height: 64,
                            width: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.errorRed,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.errorRed.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.call_end_rounded,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        // Toggle Camera
                        _buildControlButton(
                          icon: provider.isCameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                          label: 'Camera',
                          color: !provider.isCameraEnabled ? AppTheme.errorRed : AppTheme.darkBorder,
                          onPressed: () => provider.toggleCamera(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.all(14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: color == AppTheme.darkBorder ? AppTheme.darkBorder : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
          icon: Icon(icon, size: 24, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
