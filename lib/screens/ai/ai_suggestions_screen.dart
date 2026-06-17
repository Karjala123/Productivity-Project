import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/productivity_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class AiSuggestionsScreen extends StatelessWidget {
  const AiSuggestionsScreen({super.key});

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'focus':
        return Icons.center_focus_strong_outlined;
      case 'break':
        return Icons.coffee_outlined;
      case 'schedule':
        return Icons.schedule_outlined;
      case 'app_usage':
        return Icons.phone_android_outlined;
      default:
        return Icons.lightbulb_outline;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'focus':
        return AppColors.primary;
      case 'break':
        return AppColors.accent;
      case 'schedule':
        return AppColors.info;
      case 'app_usage':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final productivity = context.watch<ProductivityProvider>();
    final user = auth.userModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Suggestions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh suggestions',
            onPressed: user == null
                ? null
                : () => productivity.refreshSuggestions(
                      user,
                      productivity.weeklyData,
                    ),
          ),
        ],
      ),
      body: Column(
        children: [
          // AI header banner
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C95FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Productivity Coach',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${productivity.suggestions.length} personalized insights based on your usage patterns',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.psychology_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: ['All', 'Focus', 'Schedule', 'App Usage', 'Break']
                  .map(
                    (label) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(
                          label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: label == 'All',
                        onSelected: (_) {},
                        selectedColor: AppColors.primaryLight,
                        checkmarkColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Suggestions list
          Expanded(
            child: productivity.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  )
                : productivity.suggestions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome_outlined,
                              size: 56,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No suggestions yet',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Complete a few focus sessions and\nwe\'ll generate personalized insights for you.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 24),
                            if (user != null)
                              ElevatedButton.icon(
                                onPressed: () =>
                                    productivity.refreshSuggestions(
                                  user,
                                  productivity.weeklyData,
                                ),
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('Generate Now'),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(200, 48),
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: productivity.suggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = productivity.suggestions[index];
                          final color = _categoryColor(suggestion.category);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider),
                              boxShadow: suggestion.isRead
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: color.withOpacity(0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _categoryIcon(suggestion.category),
                                        color: color,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        suggestion.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontSize: 15),
                                      ),
                                    ),
                                    PriorityBadge(
                                        priority: suggestion.priority),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  suggestion.description,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(height: 1.5),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (!suggestion.isApplied)
                                      TextButton.icon(
                                        onPressed: () {
                                          if (user != null) {
                                            productivity.markSuggestionRead(
                                              user.uid,
                                              suggestion.id,
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.check, size: 14),
                                        label: const Text(
                                          'Mark Applied',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.accent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          backgroundColor:
                                              AppColors.accentLight,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentLight,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          '✓ Applied',
                                          style: TextStyle(
                                            color: AppColors.accent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
