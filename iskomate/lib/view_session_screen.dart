import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'theme.dart';

class ViewSessionScreen extends StatefulWidget {
  final Map<String, dynamic> sessionData;
  final String sessionId; // We need the ID to listen for live updates

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

        // Use live data if available, otherwise fallback to the data passed in
        var data = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!.data() as Map<String, dynamic>
            : widget.sessionData;

        final String sessionName = data['name'] ?? 'Session';
        final String sessionDate = data['date'] ?? 'No Date';
        const String sessionDuration = "00:00:00"; 

        // 2. Parse the Graph Data coming from Firebase
        List<FlSpot> engagedSpots = [];
        List<FlSpot> notEngagedSpots = [];

        // We expect 'graph_data' to be an array of maps: 
        // [{time_index: 0, engaged: 50, not_engaged: 50}, ...]
        if (data['graph_data'] != null) {
          List<dynamic> graphPoints = data['graph_data'];
          
          // Sort points by time to ensure the line draws correctly
          graphPoints.sort((a, b) => (a['time_index'] as num).compareTo(b['time_index'] as num));

          for (var point in graphPoints) {
            double x = (point['time_index'] as num).toDouble();
            double yEngaged = (point['engaged'] as num).toDouble();
            double yNotEngaged = (point['not_engaged'] ?? 0).toDouble();

            engagedSpots.add(FlSpot(x, yEngaged));
            notEngagedSpots.add(FlSpot(x, yNotEngaged));
          }
        }

        // Prevents crash if data is empty
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
                      _buildChartData(engagedSpots, notEngagedSpots),
                      duration: const Duration(milliseconds: 250), // Animation speed
                    ),
                  ),
                  const SizedBox(height: 40),
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

  // Chart Configuration Logic
  LineChartData _buildChartData(List<FlSpot> engaged, List<FlSpot> notEngaged) {
    double maxX = engaged.isNotEmpty ? engaged.last.x : 5;
    if (maxX < 5) maxX = 5; // Minimum width of chart

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
                child: Text(
                  '${value.toInt()}',
                  style: TextStyle(
                      color: kLightGreyColor.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            interval: 25,
            getTitlesWidget: (value, meta) {
              if (value == 0) return Container();
              return Text(
                '${value.toInt()}%',
                textAlign: TextAlign.right,
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
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
        _buildLine('Engaged', engaged, kAccentColor),
        _buildLine('Not Engaged', notEngaged, kLightGreyColor),
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

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(kAccentColor, 'ENGAGED'),
        const SizedBox(width: 24),
        _buildLegendItem(kLightGreyColor, 'NOT ENGAGED'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: kLightGreyColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}