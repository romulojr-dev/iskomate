import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Add this import

import 'theme.dart';

// --- Define Colors for the 4-Line Graph and Legend (Based on the image) ---
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

  LineChartData _buildChartData(
    List<FlSpot> highlyEngaged,
    List<FlSpot> barelyEngaged,
    List<FlSpot> engaged,
    List<FlSpot> notEngaged,
  ) {
    double maxX = 5;
    if (highlyEngaged.isNotEmpty) maxX = highlyEngaged.last.x > maxX ? highlyEngaged.last.x : maxX;
    if (barelyEngaged.isNotEmpty) maxX = barelyEngaged.last.x > maxX ? barelyEngaged.last.x : maxX;
    if (engaged.isNotEmpty) maxX = engaged.last.x > maxX ? engaged.last.x : maxX;
    if (notEngaged.isNotEmpty) maxX = notEngaged.last.x > maxX ? notEngaged.last.x : maxX;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 25, 
        getDrawingHorizontalLine: (value) => const FlLine(
          color: Color(0x338E8E8E),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1, 
            getTitlesWidget: (value, meta) {
              return Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Text('Hour',
                  style: TextStyle(
                      color: kLightGreyColor.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              );
            },
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles( 
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 25,
            getTitlesWidget: (value, meta) {
              if (value == 0) return Container();
              return Text(
                '${value.toInt()}%',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: kLightGreyColor.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: kLightGreyColor.withOpacity(0.5), width: 2),
        ),
      ),
      minX: 0,
      maxX: maxX,
      minY: 0,
      maxY: 100,
      lineBarsData: [
        _buildLine('Highly Engaged', highlyEngaged, _highlyEngagedColor),
        _buildLine('Barely Engaged', barelyEngaged, _barelyEngagedColor),
        _buildLine('Engaged', engaged, _engagedColor),
        _buildLine('Not Engaged', notEngaged, _notEngagedColor),
      ],
    );
  }

  LineChartBarData _buildLine(String id, List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 4,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Listen specifically to this document in real-time
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sessions')
          .doc(widget.sessionId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text("Error loading data")));
        }

        var data = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!.data() as Map<String, dynamic>
            : widget.sessionData;

        final String sessionName = data['name'] ?? 'STUDY SESSION 1';
        final String sessionDateRaw = data['date'] ?? '';
        String sessionDate = sessionDateRaw;
        if (sessionDateRaw.isNotEmpty) {
          try {
            final dt = DateTime.parse(sessionDateRaw);
            sessionDate = DateFormat('yyyy-MM-dd   HH:mm:ss').format(dt);
          } catch (_) {
            sessionDate = sessionDateRaw;
          }
        }
        final String sessionDuration = data['duration'] != null ? data['duration'] as String : "00:00:00"; 

        // 2. Parse the Graph Data coming from Firebase (4 lines)
        List<FlSpot> highlyEngagedSpots = [];
        List<FlSpot> barelyEngagedSpots = [];
        List<FlSpot> engagedSpots = [];
        List<FlSpot> notEngagedSpots = [];

        if (data['graph_data'] != null) {
          List<dynamic> graphPoints = data['graph_data'];

          graphPoints.sort((a, b) => (a['time_index'] as num).compareTo(b['time_index'] as num));

          for (var point in graphPoints) {
            double x = (point['time_index'] as num).toDouble();
            
            double yHighlyEngaged = (point['highly_engaged'] as num?)?.toDouble() ?? 0.0;
            double yBarelyEngaged = (point['barely_engaged'] as num?)?.toDouble() ?? 0.0;
            double yEngaged = (point['engaged'] as num?)?.toDouble() ?? 0.0;
            double yNotEngaged = (point['not_engaged'] as num?)?.toDouble() ?? 0.0;

            highlyEngagedSpots.add(FlSpot(x, yHighlyEngaged));
            barelyEngagedSpots.add(FlSpot(x, yBarelyEngaged));
            engagedSpots.add(FlSpot(x, yEngaged));
            notEngagedSpots.add(FlSpot(x, yNotEngaged));
          }
        }

        if (highlyEngagedSpots.isEmpty) highlyEngagedSpots = [const FlSpot(0, 0)];
        if (barelyEngagedSpots.isEmpty) barelyEngagedSpots = [const FlSpot(0, 0)];
        if (engagedSpots.isEmpty) engagedSpots = [const FlSpot(0, 0)];
        if (notEngagedSpots.isEmpty) notEngagedSpots = [const FlSpot(0, 0)];

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
                  const SizedBox(height: 4),
                  Text(
                    "Duration $sessionDuration",
                    style: const TextStyle(
                      color: kLightGreyColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 3. The Chart Widget
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('sessions').doc(widget.sessionId).snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return const SizedBox(height: 220, child: Center(child: Text('Error loading graph', style: TextStyle(color: Colors.white))));
                      }
                      if (!snap.hasData || snap.data!.data() == null) {
                        return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
                      }

                      final doc = snap.data!.data()!;
                      debugPrint('VIEW_SESSION: session doc raw => $doc');

                      final rawGraph = doc['graph_data'];
                      final points = <Map<String, dynamic>>[];
                      if (rawGraph is List) {
                        for (var e in rawGraph) {
                          if (e is Map) points.add(Map<String, dynamic>.from(e));
                        }
                      }

                      debugPrint('VIEW_SESSION: graph_data count=${points.length}');

                      double _toDouble(dynamic v) {
                        if (v == null) return 0.0;
                        if (v is num) return v.toDouble();
                        return double.tryParse(v.toString()) ?? 0.0;
                      }

                      final spotsH = <FlSpot>[];
                      final spotsB = <FlSpot>[];
                      final spotsE = <FlSpot>[];
                      final spotsN = <FlSpot>[];

                      if (points.isNotEmpty) {
                        // use index as X so lines are visible immediately
                        for (var i = 0; i < points.length; i++) {
                          final p = points[i];
                          final x = i.toDouble();
                          spotsH.add(FlSpot(x, _toDouble(p['highly_engaged'])));
                          spotsB.add(FlSpot(x, _toDouble(p['barely_engaged'])));
                          spotsE.add(FlSpot(x, _toDouble(p['engaged'])));
                          spotsN.add(FlSpot(x, _toDouble(p['not_engaged'])));
                        }
                      } else {
                        // single empty point so chart draws consistent axes
                        spotsH.add(const FlSpot(0, 0));
                      }

                      final all = [...spotsH, ...spotsB, ...spotsE, ...spotsN];
                      double minX = 0, maxX = all.isNotEmpty ? all.map((s) => s.x).reduce((a,b)=> a<b?a:b) : 0;
                      if (all.isNotEmpty) {
                        minX = all.map((s) => s.x).reduce((a,b)=> a<b?a:b);
                        maxX = all.map((s) => s.x).reduce((a,b)=> a>b?a:b);
                        if (minX == maxX) maxX = minX + 1;
                      } else {
                        maxX = 1;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('Duration: ${doc['duration'] ?? '00:00:00'}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                          ),
                          SizedBox(
                            height: 260,
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(show: true, horizontalInterval: 25),
                                titlesData: FlTitlesData(
                                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 25, getTitlesWidget: (v, meta) => Text('${v.toInt()}%', style: const TextStyle(color: Colors.white70, fontSize: 12)))),
                                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: (maxX - minX) / 4, getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(color: Colors.white70, fontSize: 12)))),
                                ),
                                minX: minX,
                                maxX: maxX,
                                minY: 0,
                                maxY: 100,
                                lineBarsData: [
                                  LineChartBarData(spots: spotsH, isCurved: true, color: const Color(0xFFB11212), barWidth: 2, dotData: FlDotData(show: false)),
                                  LineChartBarData(spots: spotsE, isCurved: true, color: const Color(0xFFEBE0D2), barWidth: 2, dotData: FlDotData(show: false)),
                                  LineChartBarData(spots: spotsB, isCurved: true, color: const Color(0xFF8B3A3A), barWidth: 2, dotData: FlDotData(show: false)),
                                  LineChartBarData(spots: spotsN, isCurved: true, color: const Color(0xFFFFFFFF), barWidth: 2, dotData: FlDotData(show: false)),
                                ],
                                borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Colors.white24), left: BorderSide(color: Colors.white24))),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  
                  // REVISED LEGEND
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