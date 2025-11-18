import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // --- Widget for a single legend item ---
  // Adjusted font size to 14 to save space and reduce overflow risk
  Widget _buildLegendItem(Color color, String label, {bool hasBorder = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16, // Slightly smaller box
          height: 16,
          decoration: BoxDecoration(
            color: color,
            border: hasBorder
                ? Border.all(color: Colors.white, width: 1.0)
                : null,
            borderRadius: BorderRadius.circular(2), // Smaller border radius
          ),
        ),
        const SizedBox(width: 6), // Slightly smaller space
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14, // Reduced font size
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  // --- REVISED Widget for the 4-item Legend ---
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

  // Chart Configuration Logic (Kept the same)
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
        final String sessionDate = data['date'] ?? '2025-11-09';
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
                  SizedBox(
                    height: 300,
                    child: LineChart(
                      _buildChartData(highlyEngagedSpots, barelyEngagedSpots, engagedSpots, notEngagedSpots),
                      duration: const Duration(milliseconds: 250), 
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // REVISED LEGEND (No longer inside LayoutBuilder)
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