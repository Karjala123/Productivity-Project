import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/productivity_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final productivity = context.watch<ProductivityProvider>();
    final user = auth.userModel;

    if (user == null) return const SizedBox.shrink();

    String formattedTime;
    final secs = user.totalFocusSeconds;
    if (secs < 60) {
      formattedTime = '${secs}s';
    } else if (secs < 3600) {
      formattedTime = '${secs ~/ 60}m';
    } else {
      final hours = secs ~/ 3600;
      final mins = (secs % 3600) ~/ 60;
      formattedTime = mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }

    // Calculate Best Records
    final Map<String, int> sessionsPerDay = {};
    final Map<String, int> scorePerDay = {};
    for (var s in productivity.recentSessions) {
      final key = '${s.startTime.year}-${s.startTime.month}-${s.startTime.day}';
      sessionsPerDay[key] = (sessionsPerDay[key] ?? 0) + 1;
      scorePerDay[key] = (scorePerDay[key] ?? 0) + 10;
    }
    final int maxSessions = sessionsPerDay.isEmpty
        ? 0
        : sessionsPerDay.values.reduce((a, b) => a > b ? a : b);
    final int maxScore = scorePerDay.isEmpty
        ? 0
        : scorePerDay.values.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditNameDialog(context, user.name),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar & basic info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF9C95FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ProfileStat(
                        label: 'Score',
                        value: '${user.productivityScore}',
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      _ProfileStat(
                        label: 'Streak',
                        value: '${user.streak}d 🔥',
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      _ProfileStat(label: 'Focus Time', value: formattedTime),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Best Records
            const SectionHeader(title: 'Best Records'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                _RecordBadge(
                  emoji: '🔥',
                  label: 'Highest Streak',
                  value: '${user.streak} Days',
                ),
                _RecordBadge(
                  emoji: '⏱️',
                  label: 'Most Sessions',
                  value: '$maxSessions /day',
                ),
                _RecordBadge(
                  emoji: '🏆',
                  label: 'Highest Score',
                  value: '$maxScore Pts',
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Account
            const SectionHeader(title: 'Account'),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () => _showNotificationsDialog(context),
            ),
            _SettingsTile(
              icon: Icons.lock_outline,
              label: 'Privacy & Security',
              onTap: () => _showPrivacyDialog(context),
            ),
            _SettingsTile(
              icon: Icons.help_outline,
              label: 'Help & Support',
              onTap: () => _showHelpDialog(context),
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              label: 'About App',
              onTap: () => _showAboutDialog(context),
            ),

            const SizedBox(height: 16),

            // Sign out
            OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text('Sign Out?'),
                    content: const Text(
                      'You will need to sign in again to access your data.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                        ),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await auth.signOut();
                }
              },
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text(
                'Sign Out',
                style: TextStyle(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Update your display name below.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Display Name',
                hintText: 'Enter your name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;

              final auth = context.read<AuthProvider>();
              final success = await auth.updateName(newName);
              if (context.mounted) {
                Navigator.pop(context);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        auth.errorMessage ?? 'Failed to update name',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final settings = auth.userModel?.settings ?? {};
    bool sessionReminders = settings['sessionReminders'] ?? true;
    bool dailySummary = settings['dailySummary'] ?? true;
    bool streakAlerts = settings['streakAlerts'] ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.notifications_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Notifications'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Session Reminders',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text(
                  'Remind me to start focus sessions',
                  style: TextStyle(fontSize: 12),
                ),
                value: sessionReminders,
                activeColor: AppColors.primary,
                onChanged: (v) => setModalState(() => sessionReminders = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Daily Summary',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text(
                  'End-of-day productivity recap',
                  style: TextStyle(fontSize: 12),
                ),
                value: dailySummary,
                activeColor: AppColors.primary,
                onChanged: (v) => setModalState(() => dailySummary = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Streak Alerts',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text(
                  'Notify when streak is at risk',
                  style: TextStyle(fontSize: 12),
                ),
                value: streakAlerts,
                activeColor: AppColors.primary,
                onChanged: (v) => setModalState(() => streakAlerts = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await auth.updateNotificationSettings(
                  sessionReminders: sessionReminders,
                  dailySummary: dailySummary,
                  streakAlerts: streakAlerts,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Notification preferences saved!'
                            : 'Failed to save preferences. Please try again.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Privacy & Security'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _privacyRow(
              Icons.cloud_outlined,
              'Data Storage',
              'Your data is stored securely on Firebase Cloud.',
            ),
            const Divider(height: 20),
            _privacyRow(
              Icons.visibility_off_outlined,
              'Data Sharing',
              'We never share or sell your personal data.',
            ),
            const Divider(height: 20),
            _privacyRow(
              Icons.security_outlined,
              'Authentication',
              'Protected by Firebase Authentication.',
            ),
            const Divider(height: 20),
            _privacyRow(
              Icons.delete_outline,
              'Delete Data',
              'Contact support to request full data deletion.',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _privacyRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    final faqs = [
      {
        'q': 'How do I start a focus session?',
        'a': 'Tap "Start Focus Session" on the Dashboard.',
      },
      {
        'q': 'How is my score calculated?',
        'a': 'Score increases by 10 points per completed focus session.',
      },
      {
        'q': 'What happens if I end a session early?',
        'a': 'Remaining time is logged as an "Early Exit" in Analytics.',
      },
      {
        'q': 'How do I view app usage?',
        'a': 'Go to Analytics → App Usage tab for a daily breakdown.',
      },
    ];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Help & Support'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: faqs.length,
            separatorBuilder: (_, __) => const Divider(height: 16),
            itemBuilder: (context, i) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Q: ${faqs[i]['q']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A: ${faqs[i]['a']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Text('About App'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ProductivityAI',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'An AI-powered productivity analytics platform to help you track, analyze, and improve your daily focus habits.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Built with Flutter & Firebase',
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

class _RecordBadge extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _RecordBadge({
    required this.emoji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
