import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/productivity_provider.dart';
import '../../theme/app_theme.dart';

class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({super.key});

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

class _FocusModeScreenState extends State<FocusModeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _timer;

  int _selectedMinutes = 25;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  bool _isPaused = false;
  int _focusScore = 80;

  final List<int> _presets = [15, 25, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _remainingSeconds = _selectedMinutes * 60;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() async {
    setState(() => _isRunning = true);
    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      final updatedUser =
          await context.read<ProductivityProvider>().startFocusMode(user.uid);
      if (updatedUser != null && mounted) {
        context.read<AuthProvider>().updateUserModel(updatedUser);
      }
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        _completeSession();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });
  }

  void _resumeTimer() {
    setState(() {
      _isRunning = true;
      _isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 0) {
        _completeSession();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _completeSession() async {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
    });

    final int actualDuration = (_selectedMinutes * 60) - _remainingSeconds;
    final int remainingMins = (_remainingSeconds / 60).round();

    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      final updatedUser =
          await context.read<ProductivityProvider>().endFocusMode(
                user,
                durationSeconds: actualDuration,
                focusScore: _focusScore,
                appUsage: remainingMins > 0
                    ? {'Early Exit': remainingMins}
                    : const {},
              );

      // Update the auth provider with refreshed user data (streak, score, etc.)
      if (updatedUser != null && mounted) {
        context.read<AuthProvider>().updateUserModel(updatedUser);
      }
    }

    if (mounted) {
      _showCompletionDialog();
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _remainingSeconds = _selectedMinutes * 60;
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppColors.accent,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Session Complete! 🎉',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'You completed a $_selectedMinutes-minute focus session. Great work!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '+$_focusScore Focus Points Earned',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Back to Dashboard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetTimer();
            },
            child: const Text('New Session'),
          ),
        ],
      ),
    );
  }

  String get _timeDisplay {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  double get _progress {
    final total = _selectedMinutes * 60;
    return 1 - (_remainingSeconds / total);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Focus Mode'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () async {
            if (_isRunning) {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text('End Session?'),
                  content: const Text(
                    'Your current session will be saved with partial credit.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('End Session'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _completeSession();
                if (mounted) Navigator.pop(context);
              }
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Preset duration selector
            if (!_isRunning && !_isPaused)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _presets.map((mins) {
                  final selected = mins == _selectedMinutes;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedMinutes = mins;
                      _remainingSeconds = mins * 60;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              selected ? AppColors.primary : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        '${mins}m',
                        style: TextStyle(
                          color:
                              selected ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 48),

            // Timer Ring
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulse =
                    _isRunning ? 1.0 + (_pulseController.value * 0.02) : 1.0;
                return Transform.scale(
                  scale: pulse,
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 240,
                          height: 240,
                          child: CircularProgressIndicator(
                            value: _progress,
                            strokeWidth: 12,
                            backgroundColor: AppColors.divider,
                            valueColor: AlwaysStoppedAnimation(
                              _isRunning ? AppColors.primary : AppColors.accent,
                            ),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _timeDisplay,
                              style: const TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isRunning
                                  ? 'Stay focused 💪'
                                  : _isPaused
                                      ? 'Paused'
                                      : 'Ready to focus?',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 48),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isRunning || _isPaused)
                  IconButton(
                    onPressed: _resetTimer,
                    icon: const Icon(Icons.refresh_rounded),
                    iconSize: 28,
                    color: AppColors.textSecondary,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                      side: const BorderSide(color: AppColors.divider),
                    ),
                  ),
                const SizedBox(width: 20),

                // Main button
                GestureDetector(
                  onTap: () {
                    if (_isRunning) {
                      _pauseTimer();
                    } else if (_isPaused) {
                      _resumeTimer();
                    } else {
                      _startTimer();
                    }
                  },
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF9C95FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),

                const SizedBox(width: 20),
                if (_isRunning || _isPaused)
                  IconButton(
                    onPressed: _completeSession,
                    icon: const Icon(Icons.check_rounded),
                    iconSize: 28,
                    color: AppColors.accent,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.accentLight,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                      side: BorderSide(
                        color: AppColors.accent.withOpacity(0.3),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 40),

            // Tips
            if (!_isRunning)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tips_and_updates_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Put your phone down, close distracting tabs, and take a deep breath before starting.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.primaryDark,
                              fontSize: 13,
                            ),
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
}
