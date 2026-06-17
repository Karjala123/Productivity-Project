import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/productivity_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedRange = 'This Week';
  final List<String> _ranges = ['Today', 'This Week', 'This Month', 'All Time'];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().userModel;
      if (user != null) {
        context.read<ProductivityProvider>().loadData(user.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final productivity = context.watch<ProductivityProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;

    // Filter sessions based on selected range
    final filteredSessions = productivity.recentSessions.where((s) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final sessionDate = DateTime(
        s.startTime.year,
        s.startTime.month,
        s.startTime.day,
      );

      switch (_selectedRange) {
        case 'Today':
          return sessionDate.isAtSameMomentAs(today);
        case 'This Week':
          final weekAgo = today.subtract(const Duration(days: 7));
          return sessionDate.isAfter(weekAgo);
        case 'This Month':
          final monthAgo = DateTime(now.year, now.month - 1, now.day);
          return sessionDate.isAfter(monthAgo);
        case 'All Time':
        default:
          return true;
      }
    }).toList();

    final totalSeconds = _selectedRange == 'All Time'
        ? (user?.totalFocusSeconds ?? 0)
        : filteredSessions.fold(0, (sum, s) => sum + s.durationSeconds);

    final avgScore = filteredSessions.isEmpty
        ? 0
        : filteredSessions.map((s) => s.focusScore).reduce((a, b) => a + b) ~/
              filteredSessions.length;

    final sessionCount = _selectedRange == 'All Time'
        ? (user?.totalSessions ?? 0)
        : filteredSessions.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report export coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Range selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _ranges.map((range) {
                  final selected = range == _selectedRange;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedRange = range),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.divider,
                        ),
                      ),
                      child: Text(
                        range,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF9C95FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${user?.name ?? 'Personal'} Productivity Report',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedRange,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _ReportStat(
                        label: 'Total Focus',
                        value: _formatSeconds(totalSeconds),
                      ),
                      const SizedBox(width: 24),
                      _ReportStat(label: 'Avg Score', value: '$avgScore/100'),
                      const SizedBox(width: 24),
                      _ReportStat(label: 'Sessions', value: '$sessionCount'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Sessions breakdown
            const SectionHeader(title: 'Session Log'),
            const SizedBox(height: 12),

            if (filteredSessions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        size: 48,
                        color: AppColors.textHint,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No sessions found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start a focus session to generate reports.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...filteredSessions.map((session) {
                final date = DateFormat(
                  'MMM d, yyyy • h:mm a',
                ).format(session.startTime);
                final scoreColor = session.focusScore >= 80
                    ? AppColors.success
                    : session.focusScore >= 60
                    ? AppColors.warning
                    : AppColors.error;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.timer_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.sessionType == 'focus'
                                  ? 'Focus Session'
                                  : 'Deep Work',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              date,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatSeconds(session.durationSeconds),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${session.focusScore}pts',
                            style: TextStyle(
                              color: scoreColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 24),

            // Insights card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.insights_outlined,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Insights',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: const Color(0xFF065F46)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    filteredSessions.isEmpty
                        ? 'Complete focus sessions to get personalized AI insights about your productivity patterns.'
                        : 'You\'re most productive in your selected period. '
                              'Your average focus session lasts ${filteredSessions.isEmpty ? 0 : totalSeconds ~/ (filteredSessions.length * 60)} minutes. '
                              'Consider scheduling deep work tasks during peak hours for maximum effectiveness.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF065F46),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Download PDF Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Generating PDF Report...'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                  await _generateAndDownloadPdf(
                    _selectedRange,
                    totalSeconds,
                    avgScore,
                    sessionCount,
                    filteredSessions,
                    user?.name,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Download PDF Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatSeconds(int totalSeconds) {
    if (totalSeconds < 60) return '${totalSeconds}s';
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }

  Future<void> _generateAndDownloadPdf(
    String reportRange,
    int totalSeconds,
    int avgScore,
    int sessionCount,
    List<ProductivitySession> sessions,
    String? userName,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Productivity Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    DateFormat('MMM d, yyyy').format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'User: ${userName ?? 'Personal'}',
              style: const pw.TextStyle(fontSize: 16),
            ),
            pw.Text(
              'Range: $reportRange',
              style: const pw.TextStyle(fontSize: 16),
            ),
            pw.SizedBox(height: 20),

            // Summary Block
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfStat('Total Focus', _formatSeconds(totalSeconds)),
                  _buildPdfStat('Avg Score', '$avgScore/100'),
                  _buildPdfStat('Sessions', '$sessionCount'),
                ],
              ),
            ),

            pw.SizedBox(height: 30),
            pw.Text(
              'Session Log',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),

            if (sessions.isEmpty)
              pw.Text('No sessions found for this period.')
            else
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['Date/Time', 'Type', 'Duration', 'Score'],
                data: sessions.map((s) {
                  return [
                    DateFormat('MMM d, yyyy h:mm a').format(s.startTime),
                    s.sessionType == 'focus' ? 'Focus Session' : 'Deep Work',
                    _formatSeconds(s.durationSeconds),
                    '${s.focusScore} pts',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey800,
                ),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  ),
                ),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
              ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'productivity_report_${reportRange.replaceAll(' ', '_').toLowerCase()}.pdf',
    );
  }

  pw.Widget _buildPdfStat(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
      ],
    );
  }
}

class _ReportStat extends StatelessWidget {
  final String label;
  final String value;

  const _ReportStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}
