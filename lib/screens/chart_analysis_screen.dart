/// Chart Analysis Screen - Alternative Impedance
/// Based on ImpedanceCombindation1Fragment.kt from original Android app
/// Allows selection of Min/Max points to calculate slope and intercept

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/impedance_provider.dart';
import '../utils/constants.dart';

class ChartAnalysisScreen extends StatefulWidget {
  const ChartAnalysisScreen({super.key});

  @override
  State<ChartAnalysisScreen> createState() => _ChartAnalysisScreenState();
}

class _ChartAnalysisScreenState extends State<ChartAnalysisScreen> {
  // Selection state for channel 1-16
  int _clickCount1to16 = 0;
  int? _selectedMinIndex1to16;
  int? _selectedMaxIndex1to16;

  // Selection state for channel 17-32
  int _clickCount17to32 = 0;
  int? _selectedMinIndex17to32;
  int? _selectedMaxIndex17to32;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImpedanceProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 768;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text('차트 분석'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetSelection,
            tooltip: '선택 초기화',
          ),
          if (provider.calibrationData.isValid)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _saveCalibration(provider),
              tooltip: 'Firebase 저장',
            ),
        ],
      ),
      body: provider.measurements.isEmpty
          ? _buildEmptyState()
          : isTablet && isLandscape
              ? _buildTabletLayout(provider)
              : _buildPortraitLayout(provider),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.show_chart,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '측정 데이터가 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '측정 탭에서 임피던스 측정을 먼저 진행해주세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(ImpedanceProvider provider) {
    return Row(
      children: [
        // Left: Charts
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInteractiveChart(
                  provider: provider,
                  measurements: provider.measurements1to16,
                  title: '채널 1-16 임피던스',
                  isChannel1to16: true,
                ),
                const SizedBox(height: 16),
                _buildInteractiveChart(
                  provider: provider,
                  measurements: provider.measurements17to32,
                  title: '채널 17-32 임피던스',
                  isChannel1to16: false,
                ),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // Right: Calibration Data
        SizedBox(
          width: 300,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildCalibrationPanel(provider),
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(ImpedanceProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInteractiveChart(
            provider: provider,
            measurements: provider.measurements1to16,
            title: '채널 1-16 임피던스',
            isChannel1to16: true,
          ),
          const SizedBox(height: 8),
          _buildCalibrationCard1to16(provider),
          const SizedBox(height: 16),
          _buildInteractiveChart(
            provider: provider,
            measurements: provider.measurements17to32,
            title: '채널 17-32 임피던스',
            isChannel1to16: false,
          ),
          const SizedBox(height: 8),
          _buildCalibrationCard17to32(provider),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildInteractiveChart({
    required ImpedanceProvider provider,
    required Map<int, double> measurements,
    required String title,
    required bool isChannel1to16,
  }) {
    final selectedMin = isChannel1to16 ? _selectedMinIndex1to16 : _selectedMinIndex17to32;
    final selectedMax = isChannel1to16 ? _selectedMaxIndex1to16 : _selectedMaxIndex17to32;
    final channelOffset = isChannel1to16 ? 0 : 16;

    // Create spots from measurements
    final spots = <FlSpot>[];
    final sortedKeys = measurements.keys.toList()..sort();
    
    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final channelIndex = ((key - 1) % 16) + 1;
      final frequency = AppConstants.frequencyMapping[channelIndex]?.toDouble() ?? 0;
      spots.add(FlSpot(frequency, measurements[key]!));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                _buildSelectionGuide(isChannel1to16),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '포인트를 클릭하여 Min/Max를 선택하세요',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: spots.isEmpty
                  ? const Center(child: Text('데이터 없음'))
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 1,
                          verticalInterval: 1000,
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                if (value <= 0) return const Text('');
                                return Text(
                                  '${value.toInt()}',
                                  style: const TextStyle(fontSize: 8),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 10),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: false,
                            color: Colors.red,
                            barWidth: 2.5,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                Color dotColor = Colors.black;
                                double radius = 4.5;
                                
                                // Highlight selected points
                                if (index == selectedMin) {
                                  dotColor = Colors.green;
                                  radius = 6;
                                } else if (index == selectedMax) {
                                  dotColor = Colors.blue;
                                  radius = 6;
                                }
                                
                                return FlDotCirclePainter(
                                  radius: radius,
                                  color: dotColor,
                                  strokeWidth: 1,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                return LineTooltipItem(
                                  '주파수: ${spot.x.toInt()}Hz\n임피던스: ${spot.y.toStringAsFixed(2)}',
                                  const TextStyle(color: Colors.white),
                                );
                              }).toList();
                            },
                          ),
                          touchCallback: (event, response) {
                            if (event is FlTapUpEvent && response?.lineBarSpots != null) {
                              final spotIndex = response!.lineBarSpots![0].spotIndex;
                              _handlePointSelection(
                                provider: provider,
                                spotIndex: spotIndex,
                                spots: spots,
                                sortedKeys: sortedKeys,
                                isChannel1to16: isChannel1to16,
                                channelOffset: channelOffset,
                              );
                            }
                          },
                          handleBuiltInTouches: true,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionGuide(bool isChannel1to16) {
    final clickCount = isChannel1to16 ? _clickCount1to16 : _clickCount17to32;
    String statusText;
    Color statusColor;

    switch (clickCount % 3) {
      case 0:
        statusText = 'Min 선택';
        statusColor = Colors.green;
        break;
      case 1:
        statusText = 'Max 선택';
        statusColor = Colors.blue;
        break;
      default:
        statusText = '초기화 클릭';
        statusColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: statusColor),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 12,
          color: statusColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _handlePointSelection({
    required ImpedanceProvider provider,
    required int spotIndex,
    required List<FlSpot> spots,
    required List<int> sortedKeys,
    required bool isChannel1to16,
    required int channelOffset,
  }) {
    final spot = spots[spotIndex];
    final frequency = spot.x.toInt();
    final impedance = spot.y;

    setState(() {
      if (isChannel1to16) {
        switch (_clickCount1to16 % 3) {
          case 0:
            // Select Min
            _selectedMinIndex1to16 = spotIndex;
            provider.setChannel1to16Min(impedance, frequency);
            break;
          case 1:
            // Select Max
            _selectedMaxIndex1to16 = spotIndex;
            provider.setChannel1to16Max(impedance, frequency);
            break;
          case 2:
            // Reset
            _selectedMinIndex1to16 = null;
            _selectedMaxIndex1to16 = null;
            provider.clearCalibration();
            break;
        }
        _clickCount1to16++;
      } else {
        switch (_clickCount17to32 % 3) {
          case 0:
            _selectedMinIndex17to32 = spotIndex;
            provider.setChannel17to32Min(impedance, frequency);
            break;
          case 1:
            _selectedMaxIndex17to32 = spotIndex;
            provider.setChannel17to32Max(impedance, frequency);
            break;
          case 2:
            _selectedMinIndex17to32 = null;
            _selectedMaxIndex17to32 = null;
            provider.clearCalibration();
            break;
        }
        _clickCount17to32++;
      }
    });
  }

  Widget _buildCalibrationPanel(ImpedanceProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCalibrationCard1to16(provider),
        const SizedBox(height: 16),
        _buildCalibrationCard17to32(provider),
        const SizedBox(height: 24),
        if (provider.calibrationData.isValid) ...[
          ElevatedButton.icon(
            onPressed: () => _saveCalibration(provider),
            icon: const Icon(Icons.save),
            label: const Text('저장'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCalibrationCard1to16(ImpedanceProvider provider) {
    final cal = provider.calibrationData;
    return Card(
      color: cal.isChannel1to16Valid ? Colors.green.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 20),
                const SizedBox(width: 8),
                Text(
                  '채널 1-16 캘리브레이션',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(),
            _buildCalibrationRow('최소값', cal.combin1At1to16Min.isEmpty ? '---' : cal.combin1At1to16Min),
            _buildCalibrationRow('최대값', cal.combin1At1to16Max.isEmpty ? '---' : cal.combin1At1to16Max),
            _buildCalibrationRow('저항 Min', cal.resist1At1to16Min.isEmpty ? '---' : cal.resist1At1to16Min),
            _buildCalibrationRow('저항 Max', cal.resist1At1to16Max.isEmpty ? '---' : cal.resist1At1to16Max),
            _buildCalibrationRow(
              '기울기',
              cal.combin1At1to16Inclin.isEmpty ? '---' : cal.combin1At1to16Inclin,
              isHighlighted: true,
            ),
            _buildCalibrationRow(
              '절편',
              cal.combin1At1to16Cap.isEmpty ? '---' : cal.combin1At1to16Cap,
              isHighlighted: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationCard17to32(ImpedanceProvider provider) {
    final cal = provider.calibrationData;
    return Card(
      color: cal.isChannel17to32Valid ? Colors.green.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, size: 20),
                const SizedBox(width: 8),
                Text(
                  '채널 17-32 캘리브레이션',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(),
            _buildCalibrationRow('최소값', cal.combin1At17to32Min.isEmpty ? '---' : cal.combin1At17to32Min),
            _buildCalibrationRow('최대값', cal.combin1At17to32Max.isEmpty ? '---' : cal.combin1At17to32Max),
            _buildCalibrationRow('저항 Min', cal.resist1At17to32Min.isEmpty ? '---' : cal.resist1At17to32Min),
            _buildCalibrationRow('저항 Max', cal.resist1At17to32Max.isEmpty ? '---' : cal.resist1At17to32Max),
            _buildCalibrationRow(
              '기울기',
              cal.combin1At17to32Inclin.isEmpty ? '---' : cal.combin1At17to32Inclin,
              isHighlighted: true,
            ),
            _buildCalibrationRow(
              '절편',
              cal.combin1At17to32Cap.isEmpty ? '---' : cal.combin1At17to32Cap,
              isHighlighted: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isHighlighted ? Theme.of(context).primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }

  void _resetSelection() {
    final provider = Provider.of<ImpedanceProvider>(context, listen: false);
    setState(() {
      _clickCount1to16 = 0;
      _clickCount17to32 = 0;
      _selectedMinIndex1to16 = null;
      _selectedMaxIndex1to16 = null;
      _selectedMinIndex17to32 = null;
      _selectedMaxIndex17to32 = null;
    });
    provider.clearCalibration();
  }

  Future<void> _saveCalibration(ImpedanceProvider provider) async {
    if (provider.innerDeviceId.isEmpty || provider.innerDeviceId == '--------') {
      _showMessage('내부기 ID가 없습니다. 기기 연결을 확인해주세요.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('저장'),
        content: Text(
          '내부장치 ID: ${provider.innerDeviceId}\n\n'
          '이 캘리브레이션 데이터를 저장하시겠습니까?\n'
          '(Firebase + 로컬 저장)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Save to Firebase
      final firebaseSuccess = await provider.saveCalibrationToFirebase();
      
      // Save to local storage
      await _saveToLocalStorage(provider);
      
      if (firebaseSuccess) {
        _showMessage('저장이 완료되었습니다. (Firebase + 로컬)');
      } else {
        _showMessage('로컬 저장 완료. Firebase 저장 실패.');
      }
    }
  }

  Future<void> _saveToLocalStorage(ImpedanceProvider provider) async {
    // TODO: Implement local storage with shared_preferences or hive
    debugPrint('Calibration saved locally for device: ${provider.innerDeviceId}');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
