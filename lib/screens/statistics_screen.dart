import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

class StatisticsPage extends StatefulWidget {
  final int userId;

  const StatisticsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late Future<Map<String, dynamic>> _statisticsFuture;

  @override
  void initState() {
    super.initState();
    _statisticsFuture = fetchStatistics(widget.userId);
  }

  Future<Map<String, dynamic>> fetchStatistics(int userId) async {
    try {
      // First, try to fetch from the /statistics endpoint
      final statsResponse = await http.get(
        Uri.parse('https://sever-todo-app-1.onrender.com/api/users/$userId/statistics'),
        headers: {'Content-Type': 'application/json'},
      );

      if (statsResponse.statusCode == 200) {
        final data = jsonDecode(statsResponse.body) as Map<String, dynamic>;
        print('Statistics Data from API: $data');
        return data;
      } else {
        print('Statistics endpoint failed with status code: ${statsResponse.statusCode}');
        // Fallback to fetching tasks and calculating statistics locally
        final tasksResponse = await http.get(
          Uri.parse('https://sever-todo-app-1.onrender.com/api/users/$userId/tasks-with-reminders'),
          headers: {'Content-Type': 'application/json'},
        );

        if (tasksResponse.statusCode == 200) {
          final List<dynamic> tasks = jsonDecode(tasksResponse.body);

          // Calculate statistics locally
          int totalTasks = tasks.length;
          int completedTasks = tasks.where((task) => task['status'] == 'completed').length;
          int inProgressTasks = tasks.where((task) => task['status'] == 'in_progress').length;
          int pendingTasks = tasks.where((task) => task['status'] == 'not_started').length;

          // Calculate overdue tasks
          final now = DateTime.now();
          int overdueTasks = tasks.where((task) {
            final deadline = DateTime.parse(task['deadline']);
            return deadline.isBefore(now) && task['status'] != 'completed';
          }).length;

          // Calculate tasks by month and completed tasks by month
          Map<String, int> tasksByMonth = {};
          Map<String, int> completedByMonth = {};

          for (var task in tasks) {
            final deadline = DateTime.parse(task['deadline']);
            final monthKey = deadline.month.toString().padLeft(2, '0'); // e.g., "04" for April
            final displayMonth = 'Th$monthKey'; // e.g., "Th04"
            tasksByMonth[displayMonth] = (tasksByMonth[displayMonth] ?? 0) + 1;
            if (task['status'] == 'completed') {
              completedByMonth[displayMonth] = (completedByMonth[displayMonth] ?? 0) + 1;
            } else {
              completedByMonth[displayMonth] = (completedByMonth[displayMonth] ?? 0);
            }
          }

          final stats = {
            'user_id': userId,
            'total_tasks': totalTasks,
            'completed_tasks': completedTasks,
            'in_progress_tasks': inProgressTasks,
            'pending_tasks': pendingTasks,
            'overdue_tasks': overdueTasks,
            'tasks_by_month': tasksByMonth,
            'completed_by_month': completedByMonth,
          };

          print('Calculated Statistics: $stats');
          return stats;
        } else {
          throw Exception('Không thể tải danh sách công việc: Mã lỗi ${tasksResponse.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Lỗi khi tải thống kê: $e');
      return {
        'total_tasks': 0,
        'completed_tasks': 0,
        'in_progress_tasks': 0,
        'pending_tasks': 0,
        'overdue_tasks': 0,
        'tasks_by_month': {},
        'completed_by_month': {},
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống Kê'),
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _statisticsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              debugPrint('Lỗi trong FutureBuilder: ${snapshot.error}');
              return Center(child: Text('Lỗi: ${snapshot.error.toString()}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Không có dữ liệu'));
            }

            try {
              final stats = snapshot.data!;
              final total = stats['total_tasks'] as int? ?? 0;
              final completed = stats['completed_tasks'] as int? ?? 0;
              final inProgress = stats['in_progress_tasks'] as int? ?? 0;
              final pending = stats['pending_tasks'] as int? ?? 0;
              final overdue = stats['overdue_tasks'] as int? ?? 0;

              final tasksByMonth = (stats['tasks_by_month'] as Map).cast<String, int>();
              final completedByMonth = (stats['completed_by_month'] as Map).cast<String, int>();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(total, completed, inProgress, pending, overdue),
                    const SizedBox(height: 24),
                 
                    const SizedBox(height: 24),
                    _buildTrendCard(tasksByMonth, completedByMonth),
                  ],
                ),
              );
            } catch (e) {
              debugPrint('Lỗi khi xử lý dữ liệu thống kê: $e');
              return const Center(child: Text('Lỗi xử lý dữ liệu, vui lòng thử lại'));
            }
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCards(int total, int completed, int inProgress, int pending, int overdue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8.0, bottom: 16.0),
          child: Text(
            'Tổng Quan Công Việc',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          childAspectRatio: 2.0,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          physics: const NeverScrollableScrollPhysics(),
          clipBehavior: Clip.hardEdge,
          children: [
            _buildStatCard('Tổng Công Việc', total.toString(), Colors.blue, Icons.assignment),
            _buildStatCard('Đã Hoàn Thành', completed.toString(), Colors.green, Icons.check_circle),
            _buildStatCard('Đang Thực Hiện', inProgress.toString(), Colors.orange, Icons.timelapse),
            _buildStatCard('Quá Hạn', overdue.toString(), Colors.red, Icons.warning),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.only(top: 16.0, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                value,
                style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildLegendItem(String label, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text('$label ($count)', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTrendCard(Map<String, int> tasksByMonth, Map<String, int> completedByMonth) {
    // Map month formats to display format
    Map<String, String> monthDisplayMap = {
      '01': 'Th1', '02': 'Th2', '03': 'Th3', '04': 'Th4', '05': 'Th5', '06': 'Th6',
      '07': 'Th7', '08': 'Th8', '09': 'Th9', '10': 'Th10', '11': 'Th11', '12': 'Th12',
      'Jan': 'Th1', 'Feb': 'Th2', 'Mar': 'Th3', 'Apr': 'Th4', 'May': 'Th5', 'Jun': 'Th6',
      'Jul': 'Th7', 'Aug': 'Th8', 'Sep': 'Th9', 'Oct': 'Th10', 'Nov': 'Th11', 'Dec': 'Th12',
      'Th01': 'Th1', 'Th02': 'Th2', 'Th03': 'Th3', 'Th04': 'Th4', 'Th05': 'Th5', 'Th06': 'Th6',
      'Th07': 'Th7', 'Th08': 'Th8', 'Th09': 'Th9', 'Th10': 'Th10', 'Th11': 'Th11', 'Th12': 'Th12',
    };

    Map<String, int> tasksByMonthDisplay = {};
    Map<String, int> completedByMonthDisplay = {};

    tasksByMonth.forEach((key, value) {
      String displayKey = monthDisplayMap[key] ?? key;
      tasksByMonthDisplay[displayKey] = value;
    });

    completedByMonth.forEach((key, value) {
      String displayKey = monthDisplayMap[key] ?? key;
      completedByMonthDisplay[displayKey] = value;
    });

    final months = tasksByMonthDisplay.keys.toList();
    if (months.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('Chưa có dữ liệu tháng nào')),
        ),
      );
    }

    try {
      final Map<String, int> monthOrder = {
        'Th1': 1, 'Th2': 2, 'Th3': 3, 'Th4': 4, 'Th5': 5, 'Th6': 6,
        'Th7': 7, 'Th8': 8, 'Th9': 9, 'Th10': 10, 'Th11': 11, 'Th12': 12,
      };

      months.sort((a, b) {
        int orderA = monthOrder[a] ?? 0;
        int orderB = monthOrder[b] ?? 0;
        return orderA.compareTo(orderB);
      });
    } catch (e) {
      debugPrint('Lỗi khi sắp xếp danh sách tháng: $e');
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Xu Hướng Công Việc Theo Tháng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: tasksByMonthDisplay.isEmpty
                      ? 10
                      : (months.map((m) => tasksByMonthDisplay[m] ?? 0).reduce((a, b) => a > b ? a : b) * 1.2),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= months.length) return const Text('');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              months[value.toInt()],
                              style: const TextStyle(
                                  color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value % 5 != 0) return const Text('');
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                                color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 5,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: Colors.grey.withOpacity(0.3), strokeWidth: 1),
                  ),
                  barGroups: List.generate(
                    months.length,
                    (index) => BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: (tasksByMonthDisplay[months[index]] ?? 0).toDouble(),
                          color: Colors.blue.shade300,
                          width: 12,
                        ),
                        BarChartRodData(
                          toY: (completedByMonthDisplay[months[index]] ?? 0).toDouble(),
                          color: Colors.green.shade300,
                          width: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Tổng Công Việc', Colors.blue.shade300, tasksByMonthDisplay.values.fold(0, (a, b) => a + b)),
                const SizedBox(width: 24),
                _buildLegendItem('Đã Hoàn Thành', Colors.green.shade300, completedByMonthDisplay.values.fold(0, (a, b) => a + b)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}