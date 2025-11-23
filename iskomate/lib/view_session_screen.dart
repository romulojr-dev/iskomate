import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'theme.dart';

// --- Define Colors ---
const Color _highlyEngagedColor = Color(0xFFB11212); 
const Color _barelyEngagedColor = Color(0xFF8B3A3A); 
const Color _engagedColor = Color(0xFFEBE0D2); 
const Color _notEngagedColor = Color(0xFFFFFFFF); 

class ViewSessionScreen extends StatefulWidget {
  final Map<String, dynamic> sessionData;
  final String sessionId; 

  const ViewSessionScreen({
    super.key,
    required this.sessionData,
    required this.sessionId,
  });

  @override
  State<ViewSessionScreen> createState() => _ViewSessionScreenState();
}

class _ViewSessionScreenState extends State<ViewSessionScreen> {
  @override
  void initState() {
    super.initState();
    _setSystemUIOverlay();
  }

  void _setSystemUIOverlay() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: kBackgroundColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  // --- LEGEND WIDGETS ---
  Widget _buildLegendItem(Color color, String label, {bool hasBorder = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            border: hasBorder
                ? Border.all(color: Colors.white, width: 1.0)
                : null,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(child: _buildLegendItem(_highlyEngagedColor, 'HIGHLY ENGAGED')),
            Expanded(child: _buildLegendItem(_barelyEngagedColor, 'BARELY ENGAGED')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(child: _buildLegendItem(_engagedColor, 'ENGAGED', hasBorder: true)),
            Expanded(child: _buildLegendItem(_notEngagedColor, 'NOT ENGAGED', hasBorder: true)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the specific document for real-time graph updates
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text("Error loading data")));
        }

        // Fallback to passed data if snapshot isn't ready
        var data = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!.data() as Map<String, dynamic>
            : widget.sessionData;

        final String sessionName = data['name'] ?? 'STUDY SESSION';
        final String sessionDateRaw = data['date'] ?? '';
        
        // Parse Date
        String sessionDate = sessionDateRaw;
        if (sessionDateRaw.isNotEmpty) {
          try {
            final dt = DateTime.parse(sessionDateRaw);
            sessionDate = DateFormat('yyyy-MM-dd   HH:mm:ss').format(dt);
          } catch (_) {
            sessionDate = sessionDateRaw;
          }
        }

        // 1. Parse Graph Data
        List<FlSpot> highlyEngagedSpots = [];
        List<FlSpot> barelyEngagedSpots = [];
        List<FlSpot> engagedSpots = [];
        List<FlSpot> notEngagedSpots = [];

        if (data['graph_data'] != null) {
          List<dynamic> graphPoints = data['graph_data'];

          // Ensure points are sorted by time
          graphPoints.sort((a, b) => (a['time_index'] as num).compareTo(b['time_index'] as num));

          for (var point in graphPoints) {
            // X-Axis is the time_index (seconds since start)
            double x = (point['time_index'] as num).toDouble();
            
            double yHighly = (point['highly_engaged'] as num?)?.toDouble() ?? 0.0;
            double yBarely = (point['barely_engaged'] as num?)?.toDouble() ?? 0.0;
            double yEngaged = (point['engaged'] as num?)?.toDouble() ?? 0.0;
            double yNot = (point['not_engaged'] as num?)?.toDouble() ?? 0.0;

            highlyEngagedSpots.add(FlSpot(x, yHighly));
            barelyEngagedSpots.add(FlSpot(x, yBarely));
            engagedSpots.add(FlSpot(x, yEngaged));
            notEngagedSpots.add(FlSpot(x, yNot));
          }
        }

        // Add initial point if empty to prevent crashes
        if (highlyEngagedSpots.isEmpty) highlyEngagedSpots = [const FlSpot(0, 0)];
        if (barelyEngagedSpots.isEmpty) barelyEngagedSpots = [const FlSpot(0, 0)];
        if (engagedSpots.isEmpty) engagedSpots = [const FlSpot(0, 0)];
        if (notEngagedSpots.isEmpty) notEngagedSpots = [const FlSpot(0, 0)];

        // Calculate X-Axis Bounds
        final allSpots = [...highlyEngagedSpots, ...barelyEngagedSpots, ...engagedSpots, ...notEngagedSpots];
        double minX = 0;
        double maxX = 1;
        if (allSpots.isNotEmpty) {
          minX = allSpots.map((s) => s.x).reduce((a, b) => a < b ? a : b);
          maxX = allSpots.map((s) => s.x).reduce((a, b) => a > b ? a : b);
          if (minX == maxX) maxX = minX + 1; // Prevent zero width
        }

        return Scaffold(
          backgroundColor: kBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    sessionName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    sessionDate,
                    style: const TextStyle(
                      color: kLightGreyColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  
                  // 🗑️ DELETED: "Duration" Text below Date (As requested)

                  const SizedBox(height: 40),

                  // --- GRAPH SECTION ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Duration at Top Left of Graph
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Duration: ${data['duration'] ?? '00:00:00'}', 
                          style: const TextStyle(color: Colors.white70, fontSize: 16)
                        ),
                      ),
                      SizedBox(
                        height: 260,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true, horizontalInterval: 25),
                            titlesData: FlTitlesData(
                              // Y-Axis
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true, 
                                  interval: 25, 
                                  reservedSize: 40,
                                  getTitlesWidget: (v, meta) => Text('${v.toInt()}%', style: const TextStyle(color: Colors.white70, fontSize: 12))
                                )
                              ),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              
                              // X-Axis (Time)
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: (maxX - minX) > 0 ? (maxX - minX) / 4 : 1, // Prevent divide by zero
                                  getTitlesWidget: (value, meta) {
                                    // Convert seconds (value) to MM:SS format
                                    int totalSeconds = value.toInt();
                                    int minutes = totalSeconds ~/ 60;
                                    int seconds = totalSeconds % 60;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        '$minutes:${seconds.toString().padLeft(2, '0')}',
                                        style: const TextStyle(color: Colors.white70, fontSize: 12)
                                      ),
                                    );
                                  },
                                )
                              ),
                            ),
                            minX: minX,
                            maxX: maxX,
                            minY: 0,
                            maxY: 100,
                            lineBarsData: [
                              LineChartBarData(spots: highlyEngagedSpots, isCurved: true, color: _highlyEngagedColor, barWidth: 2, dotData: const FlDotData(show: false)),
                              LineChartBarData(spots: engagedSpots, isCurved: true, color: _engagedColor, barWidth: 2, dotData: const FlDotData(show: false)),
                              LineChartBarData(spots: barelyEngagedSpots, isCurved: true, color: _barelyEngagedColor, barWidth: 2, dotData: const FlDotData(show: false)),
                              LineChartBarData(spots: notEngagedSpots, isCurved: true, color: _notEngagedColor, barWidth: 2, dotData: const FlDotData(show: false)),
                            ],
                            borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.white24), left: BorderSide(color: Colors.white24))),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // LEGEND
                  _buildLegend(),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}