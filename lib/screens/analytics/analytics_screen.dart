import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../providers/productivity_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';


class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAppLimitDialog(BuildContext context, String appName, String packageName) async {
    int limitMinutes = 30;
    
    // Check overlay permission
    bool isPermissionGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isPermissionGranted) {
      await FlutterOverlayWindow.requestPermission();
      // If still not granted, maybe show another warning
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 24, right: 24, top: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Set Limit for $appName", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                      "This will trigger a full-screen block card when you reach your limit while using $appName.",
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Daily limit (minutes):", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      Text("${limitMinutes}m", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                    ],
                  ),
                  Slider(
                    value: limitMinutes.toDouble(),
                    min: 5,
                    max: 300,
                    divisions: 59,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setModalState(() {
                        limitMinutes = val.toInt();
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setDouble('limit_$packageName', limitMinutes.toDouble());
                      
                      if (context.mounted) Navigator.pop(ctx);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Strict $limitMinutes min limit saved for $appName!"),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        )
                      );
                    },
                    child: const Text("Save Limit"),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      }
    );
  }


  @override
  Widget build(BuildContext context) {
    final productivity = context.watch<ProductivityProvider>();
    final chartData = productivity.getThisWeekChartData();
    final appUsage = productivity.weeklyData['appUsageTotals'] as Map<String, dynamic>? ?? {};
    
    final appUsageList = appUsage.entries.map((e) => {
      'name': e.key,
      'minutes': e.value is int ? e.value : (e.value as num).toInt(),
      'productive': !['YouTube', 'Instagram', 'TikTok', 'Facebook', 'Early Exit'].contains(e.key),
    }).toList()..sort((a, b) => (b['minutes'] as int).compareTo(a['minutes'] as int));



    // Calculate Today's App Usage
    final Map<String, Map<String, dynamic>> todayAppUsageData = {};
    if (productivity.systemAppUsage.isNotEmpty) {
      for (var info in productivity.systemAppUsage) {
        if (info.usage.inMinutes > 0) {
          todayAppUsageData[info.appName] = {
            'minutes': info.usage.inMinutes,
            'packageName': info.packageName,
          };
        }
      }
    } else {
      for (var session in productivity.todaySessions) {
        session.appUsageMinutes.forEach((app, minutes) {
          final existing = todayAppUsageData[app];
          todayAppUsageData[app] = {
            'minutes': (existing?['minutes'] ?? 0) + minutes,
            'packageName': '', // No package name for manual sessions
          };
        });
      }
    }

    final List<Map<String, dynamic>> todayAppUsageList = todayAppUsageData.entries.map((e) => <String, dynamic>{
      'name': e.key,
      'minutes': e.value['minutes'],
      'packageName': e.value['packageName'],
      'productive': !['YouTube', 'Instagram', 'TikTok', 'Facebook', 'Early Exit'].contains(e.key),
    }).toList()..sort((a, b) => (b['minutes'] as int).compareTo(a['minutes'] as int));


    final todayTotalUsage = todayAppUsageList.fold(0, (sum, a) => sum + (a['minutes'] as int));

    // Calculate Avg Daily Focus
    final totalWeeklySeconds = chartData.fold<int>(0, (sum, day) => sum + ((day['seconds'] as num).toInt()));
    final avgWeeklySeconds = totalWeeklySeconds / 7;
    
    String avgFocusStr;
    if (avgWeeklySeconds >= 3600) {
      avgFocusStr = '${(avgWeeklySeconds / 3600).floor()}h ${((avgWeeklySeconds % 3600) / 60).floor()}m';
    } else if (avgWeeklySeconds >= 60) {
      avgFocusStr = '${(avgWeeklySeconds / 60).floor()}m ${avgWeeklySeconds.toInt() % 60}s';
    } else {
      avgFocusStr = '${avgWeeklySeconds.toInt()}s';
    }

    // Dynamic Distractions & Productive %
    final totalWeeklyMinutes = totalWeeklySeconds ~/ 60;
    final distractionMinutes = appUsageList
        .where((a) => a['productive'] == false)
        .fold(0, (sum, a) => sum + (a['minutes'] as int));
        
    int productivePercent = 0;
    if (totalWeeklyMinutes > 0) {
      final productiveMinutes = (totalWeeklyMinutes - distractionMinutes).clamp(0, totalWeeklyMinutes);
      productivePercent = ((productiveMinutes / totalWeeklyMinutes) * 100).round();
    } else {
      productivePercent = totalWeeklySeconds == 0 && distractionMinutes > 0 ? 0 : 100;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analytics'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'App Usage'),
            Tab(text: 'Trends'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Overview Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weekly overview cards
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    StatCard(
                      label: 'Avg. Daily Focus',
                      value: avgFocusStr,
                      subtitle: 'This week',
                      icon: Icons.timer_outlined,
                      iconColor: AppColors.primary,
                    ),
                    StatCard(
                      label: 'Peak Hours',
                      value: productivity.getPeakHours(),
                      subtitle: 'Your best time',
                      icon: Icons.wb_sunny_outlined,
                      iconColor: AppColors.warning,
                    ),
                    StatCard(
                      label: 'Productive %',
                      value: '$productivePercent%',
                      subtitle: 'Weekly average',
                      icon: Icons.trending_up,
                      iconColor: AppColors.accent,
                    ),
                    StatCard(
                      label: 'Distractions',
                      value: '${distractionMinutes}m',
                      subtitle: 'Time disrupted',
                      icon: Icons.block_outlined,
                      iconColor: AppColors.error,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Focus Score Line Chart
                const SectionHeader(title: 'Focus Score — Last 7 Days'),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: LineChart(
                    LineChartData(
                      lineTouchData: const LineTouchData(enabled: true),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppColors.divider,
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= chartData.length) return const SizedBox.shrink();
                              return Text(chartData[value.toInt()]['day'],
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary));
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (value, meta) => Text(
                              '${value.toInt()}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 6,
                      minY: 0,
                      maxY: 100,
                      lineBarsData: [
                        LineChartBarData(
                          spots: chartData.asMap().entries.map((entry) {
                            final score = (entry.value['score'] as num?)?.toDouble() ?? 0.0;
                            return FlSpot(entry.key.toDouble(), score);
                          }).toList(),
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                              radius: 4,
                              color: AppColors.primary,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.2),
                                AppColors.primary.withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // App Usage Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pie chart
                if (todayAppUsageList.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      const SectionHeader(title: 'Today\'s Screen Time Breakdown'),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 50,
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                setState(() {
                                  _touchedIndex = response?.touchedSection
                                          ?.touchedSectionIndex ??
                                      -1;
                                });
                              },
                            ),
                            sections: todayAppUsageList
                                .asMap()
                                .entries
                                .map((entry) {
                              final isTouched =
                                  entry.key == _touchedIndex;
                              return PieChartSectionData(
                                  value: (entry.value['minutes'] as int).toDouble(),
                                  title: isTouched
                                      ? entry.value['name'] as String
                                      : '',
                                  radius: isTouched ? 70 : 60,
                                  color: entry.value['productive'] as bool
                                    ? AppColors.chartColors[
                                        entry.key % 3]
                                    : AppColors.chartColors[3 +
                                        entry.key % 3],
                                titleStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const SectionHeader(title: 'Today\'s App Breakdown'),
                const SizedBox(height: 12),

                if (todayAppUsageList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text('No app usage recorded today', 
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),

                ...todayAppUsageList.map((app) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: AppUsageBar(
                        appName: app['name'] as String,
                        minutes: app['minutes'] as int,
                        totalMinutes: todayTotalUsage,
                        color: app['productive'] as bool
                            ? AppColors.primary
                            : AppColors.error,
                        onTap: () => _showAppLimitDialog(context, app['name'] as String, app['packageName'] as String),

                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),

          // Trends Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          Text('AI Trend Analysis',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                      color: const Color(0xFF065F46))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _TrendItem(
                          icon: Icons.trending_up,
                          color: AppColors.accent,
                          text:
                              'Your focus sessions have increased by 23% this week'),
                      _TrendItem(
                          icon: Icons.warning_amber_outlined,
                          color: AppColors.warning,
                          text:
                              'Social media usage peaks between 1–3 PM, affecting afternoon productivity'),
                      _TrendItem(
                          icon: Icons.star_outline,
                          color: AppColors.primary,
                          text:
                              'You perform best on Thursdays — schedule critical tasks accordingly'),
                      _TrendItem(
                          icon: Icons.nightlight_outlined,
                          color: AppColors.info,
                          text:
                              'Reducing screen time after 9 PM could improve your morning focus by 30%'),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Monthly Progress
                const SectionHeader(title: 'Monthly Score Progress'),
                const SizedBox(height: 16),
                Container(
                  height: 160,
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: const [
                            FlSpot(0, 50), FlSpot(1, 55),
                            FlSpot(2, 60), FlSpot(3, 58),
                            FlSpot(4, 70), FlSpot(5, 75),
                            FlSpot(6, 72), FlSpot(7, 80),
                            FlSpot(8, 85), FlSpot(9, 82),
                            FlSpot(10, 88), FlSpot(11, 92),
                          ],
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.15),
                                AppColors.primary.withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _TrendItem(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF065F46), height: 1.4)),
          ),
        ],
      ),
    );
  }
}
