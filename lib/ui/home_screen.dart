import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../logic/meeting_provider.dart';
import 'meeting_screen.dart';
import 'theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _meetingIdController = TextEditingController();
  late final TextEditingController _apiKeyController;
  String _selectedRole = 'client'; // Default joining role
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<MeetingProvider>(context, listen: false);
    _apiKeyController = TextEditingController(text: provider.apiKey);
  }

  @override
  void dispose() {
    _meetingIdController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<bool> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (cameraStatus.isGranted && micStatus.isGranted) {
      return true;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppTheme.darkCard,
          title: const Text('Permissions Required'),
          content: const Text(
            'Camera and Microphone permissions are necessary for video and audio calls. Please grant them in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Open Settings', style: TextStyle(color: AppTheme.secondaryNeon)),
            ),
          ],
        ),
      );
    }
    return false;
  }

  Future<void> _handleHostMeeting() async {
    final permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) return;

    setState(() => _isLoading = true);
    final provider = Provider.of<MeetingProvider>(context, listen: false);
    provider.setApiKey(_apiKeyController.text.trim());

    try {
      await provider.createMeeting();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MeetingScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to host meeting: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleJoinMeeting() async {
    final meetingId = _meetingIdController.text.trim();
    if (meetingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Meeting ID'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    final permissionsGranted = await _requestPermissions();
    if (!permissionsGranted) return;

    setState(() => _isLoading = true);
    final provider = Provider.of<MeetingProvider>(context, listen: false);
    provider.setApiKey(_apiKeyController.text.trim());

    try {
      await provider.joinMeetingRoom(meetingId, _selectedRole);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MeetingScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join meeting: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Orbs for depth
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryNeon.withOpacity(0.15),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondaryNeon.withOpacity(0.12),
                    blurRadius: 120,
                    spreadRadius: 80,
                  ),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Logo / Icon
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryNeon.withOpacity(0.1),
                          border: Border.all(color: AppTheme.primaryNeon.withOpacity(0.3), width: 1.5),
                        ),
                        child: const Icon(
                          Icons.videocam_rounded,
                          size: 48,
                          color: AppTheme.secondaryNeon,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    const Text(
                      'Amazon Chime SDK',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Text(
                      'Real-time Video Calling',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Actions Container
                    if (_isLoading)
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondaryNeon),
                            ),
                            SizedBox(height: 20),
                            Text(
                              'Establishing real-time session...',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                            )
                          ],
                        ),
                      )
                    else ...[
                      // API KEY CONFIGURATION FIELD
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.darkBorder, width: 1.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.vpn_key_rounded, size: 18, color: AppTheme.secondaryNeon),
                                SizedBox(width: 8),
                                Text(
                                  'API Settings (x-api-key)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _apiKeyController,
                              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                              decoration: const InputDecoration(
                                hintText: 'Enter API Key',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // HOST MEETING CARD
                      GestureDetector(
                        onTap: _handleHostMeeting,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryNeon, Color(0xFF3B2FFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryNeon.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add_call, size: 32, color: Colors.white),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Host Meeting',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Create a new call as Agent',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // JOIN MEETING CARD
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.darkBorder, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Join Existing Meeting',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _meetingIdController,
                              decoration: const InputDecoration(
                                hintText: 'Enter Meeting ID',
                                prefixIcon: Icon(Icons.link, color: AppTheme.textSecondary),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text(
                                  'Join as: ',
                                  style: TextStyle(color: AppTheme.textSecondary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedRole,
                                    dropdownColor: AppTheme.darkCard,
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppTheme.darkBorder),
                                      ),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'client',
                                        child: Text('Client (User B)'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'agent',
                                        child: Text('Agent (User A)'),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedRole = val);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _handleJoinMeeting,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.secondaryNeon, AppTheme.primaryNeon],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  height: 52,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.login, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        'Join Call',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
