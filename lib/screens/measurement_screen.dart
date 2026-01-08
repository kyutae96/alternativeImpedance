// Measurement Screen - Alternative Impedance
// Combined measurement and chart analysis screen
// UX Flow: Left(BLE+Start) → Center(Charts) → Right(Calibration+Save)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/impedance_provider.dart';
import '../widgets/ble_status_card.dart';
import '../utils/constants.dart';
import '../utils/toast_manager.dart';
import '../services/cache_service.dart';
import 'ble_scan_dialog.dart';

class MeasurementScreen extends StatefulWidget {
  const MeasurementScreen({super.key});

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;

  // Chart analysis state - Channel 1-16
  int _clickCount1to16 = 0;
  int? _selectedMinIndex1to16;
  int? _selectedMaxIndex1to16;

  // Chart analysis state - Channel 17-32
  int _clickCount17to32 = 0;
  int? _selectedMinIndex17to32;
  int? _selectedMaxIndex17to32;

  // Previous connection state for auto-program
  bool _previouslyConnected = false;

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImpedanceProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 1100; // 3-column layout threshold
    final isTablet = screenWidth >= 768;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Auto-start program when connected
    _checkAutoProgram(provider);

    return Scaffold(
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          // Main content with fade animation
          FadeTransition(
            opacity: _fadeAnimation,
            child: provider.measurements.isEmpty
                ? _buildEmptyState(provider)
                : isWideScreen && isLandscape
                    ? _buildThreeColumnLayout(provider) // New 3-column UX layout
                    : isTablet && isLandscape
                        ? _buildTabletLayout(provider)
                        : _buildPortraitLayout(provider),
          ),

          // Loading overlay with blur effect
          if (_isLoading || provider.isMeasuring) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.show_chart,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text('임피던스 측정'),
        ],
      ),
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 2,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _resetSelection,
            tooltip: '선택 초기화',
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '측정 중...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '잠시만 기다려주세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Check and auto-start program when BLE connects
  void _checkAutoProgram(ImpedanceProvider provider) {
    if (provider.isConnected && !_previouslyConnected) {
      _previouslyConnected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoStartProgram(provider);
      });
    } else if (!provider.isConnected && _previouslyConnected) {
      _previouslyConnected = false;
    }
  }

  /// Auto start program and request inner device ID
  Future<void> _autoStartProgram(ImpedanceProvider provider) async {
    if (!provider.isProgrammed) {
      setState(() => _isLoading = true);

      _showMessage('프로그램 연결 중...');
      final success = await provider.sendProgramStart();

      setState(() => _isLoading = false);

      if (success) {
        _showMessage('프로그램이 연결되었습니다. 내부기 ID: ${provider.innerDeviceId}');
      } else {
        _showMessage('프로그램 연결에 실패했습니다.');
      }
    }
  }

  Widget _buildEmptyState(ImpedanceProvider provider) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 768;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isTablet && isLandscape) {
      return Row(
        children: [
          // Left: BLE Control Panel
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  BleStatusCard(
                    onScanPressed: _showBleScanDialog,
                    onDisconnectPressed: _disconnect,
                  ),
                  const SizedBox(height: 20),
                  _buildMeasurementButton(provider),
                ],
              ),
            ),
          ),
          // Right: Empty state message
          Expanded(
            child: _buildEmptyStateContent(provider),
          ),
        ],
      );
    }

    // Portrait layout
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          BleStatusCard(
            onScanPressed: _showBleScanDialog,
            onDisconnectPressed: _disconnect,
          ),
          const SizedBox(height: 20),
          _buildMeasurementButton(provider),
          const SizedBox(height: 40),
          _buildEmptyStateContent(provider),
        ],
      ),
    );
  }

  Widget _buildEmptyStateContent(ImpedanceProvider provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: provider.isConnected && provider.isProgrammed
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : provider.isConnected
                        ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                        : [const Color(0xFF64748B), const Color(0xFF475569)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (provider.isConnected && provider.isProgrammed
                          ? const Color(0xFF10B981)
                          : provider.isConnected
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF64748B))
                      .withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              provider.isConnected && provider.isProgrammed
                  ? Icons.play_circle_outline_rounded
                  : provider.isConnected
                      ? Icons.sync_rounded
                      : Icons.bluetooth_searching_rounded,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            provider.isConnected && provider.isProgrammed
                ? '측정 준비 완료'
                : provider.isConnected
                    ? '프로그램 연결 중...'
                    : 'BLE 기기를 연결해주세요',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            provider.isConnected && provider.isProgrammed
                ? '측정 시작 버튼을 눌러 측정을 시작하세요'
                : provider.isConnected
                    ? '내부기 연결을 기다리는 중입니다'
                    : '측정을 시작하려면 먼저 기기를 연결하세요',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          if (provider.isConnected && provider.isProgrammed) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '내부기 ID: ${provider.innerDeviceId}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMeasurementButton(ImpedanceProvider provider) {
    final canStart = _canStartMeasurement(provider);
    
    // 측정 시작 버튼 - 초록색
    const startColor = Color(0xFF10B981); // Green
    const startColorDark = Color(0xFF059669); // Dark Green

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: canStart
            ? const LinearGradient(
                colors: [startColor, startColorDark], // 초록색
              )
            : null,
        color: canStart ? null : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
        boxShadow: canStart
            ? [
                BoxShadow(
                  color: startColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canStart ? _startMeasurement : null,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                color: canStart ? Colors.white : Colors.grey.shade500,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                '측정 시작',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: canStart ? Colors.white : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// NEW: 3-Column Layout for optimal UX workflow
  /// Left: BLE Connection + Measurement Start
  /// Center: Charts (data visualization)
  /// Right: Calibration Results + Save
  Widget _buildThreeColumnLayout(ImpedanceProvider provider) {
    return Row(
      children: [
        // LEFT PANEL: BLE Control + Measurement Start
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step indicator
                _buildStepIndicator(1, '연결 & 측정', Icons.bluetooth_connected_rounded),
                const SizedBox(height: 16),
                BleStatusCard(
                  onScanPressed: _showBleScanDialog,
                  onDisconnectPressed: _disconnect,
                ),
                const SizedBox(height: 20),
                _buildMeasurementButton(provider),
              ],
            ),
          ),
        ),

        // CENTER PANEL: Charts
        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepIndicator(2, '그래프 분석 & 포인트 선택', Icons.show_chart_rounded),
                  const SizedBox(height: 16),
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
        ),

        // RIGHT PANEL: Calibration Results + Save
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepIndicator(3, '결과 확인 & 저장', Icons.save_rounded),
                const SizedBox(height: 16),
                _buildCalibrationCard1to16(provider),
                const SizedBox(height: 16),
                _buildCalibrationCard17to32(provider),
                const SizedBox(height: 24),
                if (provider.calibrationData.isValid) ...[
                  _buildSaveButton(provider),
                ] else ...[
                  _buildSaveButtonDisabled(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator(int step, String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(ImpedanceProvider provider) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _saveCalibration(provider),
          borderRadius: BorderRadius.circular(16),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text(
                '캘리브레이션 저장',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButtonDisabled() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.grey.shade500, size: 32),
          const SizedBox(height: 8),
          Text(
            '캘리브레이션 완료 후\n저장할 수 있습니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// Tablet landscape layout (2-column for medium screens)
  Widget _buildTabletLayout(ImpedanceProvider provider) {
    return Row(
      children: [
        // Left: BLE + Measurement + Calibration
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                BleStatusCard(
                  onScanPressed: _showBleScanDialog,
                  onDisconnectPressed: _disconnect,
                ),
                const SizedBox(height: 16),
                _buildMeasurementButton(provider),
                const SizedBox(height: 24),
                _buildCalibrationCard1to16(provider),
                const SizedBox(height: 16),
                _buildCalibrationCard17to32(provider),
                const SizedBox(height: 20),
                if (provider.calibrationData.isValid) _buildSaveButton(provider),
              ],
            ),
          ),
        ),
        // Right: Charts
        Expanded(
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
      ],
    );
  }

  /// Portrait layout
  Widget _buildPortraitLayout(ImpedanceProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          BleStatusCard(
            onScanPressed: _showBleScanDialog,
            onDisconnectPressed: _disconnect,
          ),
          const SizedBox(height: 16),
          _buildMeasurementButton(provider),
          const SizedBox(height: 20),
          _buildInteractiveChart(
            provider: provider,
            measurements: provider.measurements1to16,
            title: '채널 1-16 임피던스',
            isChannel1to16: true,
          ),
          const SizedBox(height: 12),
          _buildCalibrationCard1to16(provider),
          const SizedBox(height: 20),
          _buildInteractiveChart(
            provider: provider,
            measurements: provider.measurements17to32,
            title: '채널 17-32 임피던스',
            isChannel1to16: false,
          ),
          const SizedBox(height: 12),
          _buildCalibrationCard17to32(provider),
          const SizedBox(height: 20),
          if (provider.calibrationData.isValid) _buildSaveButton(provider),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Interactive chart widget
  Widget _buildInteractiveChart({
    required ImpedanceProvider provider,
    required Map<int, double> measurements,
    required String title,
    required bool isChannel1to16,
  }) {
    final selectedMin = isChannel1to16 ? _selectedMinIndex1to16 : _selectedMinIndex17to32;
    final selectedMax = isChannel1to16 ? _selectedMaxIndex1to16 : _selectedMaxIndex17to32;
    final channelOffset = isChannel1to16 ? 0 : 16;

    final spots = <FlSpot>[];
    final sortedKeys = measurements.keys.toList()..sort();

    for (int i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final channelIndex = ((key - 1) % 16) + 1;
      final frequency = AppConstants.frequencyMapping[channelIndex]?.toDouble() ?? 0;
      spots.add(FlSpot(frequency, measurements[key]!));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isChannel1to16
                          ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                          : [const Color(0xFFF97316), const Color(0xFFFB923C)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.show_chart_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '포인트 클릭으로 Min/Max 선택',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                _buildSelectionGuide(isChannel1to16),
              ],
            ),
            const SizedBox(height: 12),
            // X/Y축 라벨
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'X: 저항값 (Ω)  |  Y: 임피던스 Raw값',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 280, // 그래프 높이 증가 (220 → 280)
              child: spots.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bar_chart_rounded, size: 40, color: Colors.grey.shade300),
                          const SizedBox(height: 8),
                          Text('데이터 없음', style: TextStyle(color: Colors.grey.shade400)),
                        ],
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 1,
                          verticalInterval: 2000,
                          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                          getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                if (value <= 0) return const Text('');
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${(value / 1000).toStringAsFixed(0)}k',
                                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                                  ),
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
                                  style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            curveSmoothness: 0.3,
                            color: isChannel1to16 ? const Color(0xFF6366F1) : const Color(0xFFF97316),
                            barWidth: 2.5,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                Color dotColor = isChannel1to16 ? const Color(0xFF6366F1) : const Color(0xFFF97316);
                                double radius = 6; // 기본 점 크기 (적절한 크기로 조정)
                                if (index == selectedMin) {
                                  dotColor = const Color(0xFF10B981);
                                  radius = 10; // 선택된 점은 더 크게
                                } else if (index == selectedMax) {
                                  dotColor = const Color(0xFF3B82F6);
                                  radius = 10;
                                }
                                return FlDotCirclePainter(
                                  radius: radius,
                                  color: dotColor,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: isChannel1to16
                                    ? [const Color(0xFF6366F1).withValues(alpha: 0.15), const Color(0xFF6366F1).withValues(alpha: 0.0)]
                                    : [const Color(0xFFF97316).withValues(alpha: 0.15), const Color(0xFFF97316).withValues(alpha: 0.0)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchSpotThreshold: 12, // 터치 감지 영역 축소 (더 정확한 선택 가능)
                          touchTooltipData: LineTouchTooltipData(
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                return LineTooltipItem(
                                  '${spot.x.toInt()}Hz\n${spot.y.toStringAsFixed(2)}',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14),
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
    IconData statusIcon;

    switch (clickCount % 3) {
      case 0:
        statusText = 'Min';
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.arrow_downward_rounded;
        break;
      case 1:
        statusText = 'Max';
        statusColor = const Color(0xFF3B82F6);
        statusIcon = Icons.arrow_upward_rounded;
        break;
      default:
        statusText = '초기화';
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.refresh_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 12, color: statusColor),
          const SizedBox(width: 4),
          Text(statusText, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
        ],
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
            _selectedMinIndex1to16 = spotIndex;
            provider.setChannel1to16Min(impedance, frequency);
            break;
          case 1:
            _selectedMaxIndex1to16 = spotIndex;
            provider.setChannel1to16Max(impedance, frequency);
            break;
          case 2:
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

  Widget _buildCalibrationCard1to16(ImpedanceProvider provider) {
    final cal = provider.calibrationData;
    final isValid = cal.isChannel1to16Valid;

    return _buildCalibrationCardContent(
      title: 'CH 1-16',
      isValid: isValid,
      gradientColors: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      minValue: cal.combin1At1to16Min.isEmpty ? '---' : cal.combin1At1to16Min,
      maxValue: cal.combin1At1to16Max.isEmpty ? '---' : cal.combin1At1to16Max,
      slope: cal.combin1At1to16Inclin.isEmpty ? '---' : cal.combin1At1to16Inclin,
      intercept: cal.combin1At1to16Cap.isEmpty ? '---' : cal.combin1At1to16Cap,
    );
  }

  Widget _buildCalibrationCard17to32(ImpedanceProvider provider) {
    final cal = provider.calibrationData;
    final isValid = cal.isChannel17to32Valid;

    return _buildCalibrationCardContent(
      title: 'CH 17-32',
      isValid: isValid,
      gradientColors: [const Color(0xFFF97316), const Color(0xFFFB923C)],
      minValue: cal.combin1At17to32Min.isEmpty ? '---' : cal.combin1At17to32Min,
      maxValue: cal.combin1At17to32Max.isEmpty ? '---' : cal.combin1At17to32Max,
      slope: cal.combin1At17to32Inclin.isEmpty ? '---' : cal.combin1At17to32Inclin,
      intercept: cal.combin1At17to32Cap.isEmpty ? '---' : cal.combin1At17to32Cap,
    );
  }

  Widget _buildCalibrationCardContent({
    required String title,
    required bool isValid,
    required List<Color> gradientColors,
    required String minValue,
    required String maxValue,
    required String slope,
    required String intercept,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isValid
            ? Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 2)
            : Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: isValid
                  ? LinearGradient(colors: [const Color(0xFF10B981).withValues(alpha: 0.1), const Color(0xFF10B981).withValues(alpha: 0.05)])
                  : LinearGradient(colors: [gradientColors[0].withValues(alpha: 0.1), gradientColors[0].withValues(alpha: 0.05)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: isValid ? [const Color(0xFF10B981), const Color(0xFF059669)] : gradientColors),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tune_rounded, size: 14, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isValid ? const Color(0xFF059669) : const Color(0xFF334155),
                  ),
                ),
                const Spacer(),
                if (isValid)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 3),
                        Text('완료', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Content - Compact layout
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildCompactValueRow('Min', minValue)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCompactValueRow('Max', maxValue)),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildCompactValueRow('기울기', slope, highlight: true)),
                      Container(width: 1, height: 30, color: Colors.grey.shade300),
                      Expanded(child: _buildCompactValueRow('절편', intercept, highlight: true)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactValueRow(String label, String value, {bool highlight = false}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: highlight
                ? const Color(0xFF1565C0)
                : value == '---'
                    ? Colors.grey.shade400
                    : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  bool _canStartMeasurement(ImpedanceProvider provider) {
    return provider.isConnected && provider.isProgrammed && !provider.isMeasuring;
  }

  void _showBleScanDialog() {
    showDialog(context: context, builder: (context) => const BleScanDialog());
  }

  void _disconnect() async {
    final provider = Provider.of<ImpedanceProvider>(context, listen: false);
    if (provider.isProgrammed) await provider.sendProgramEnd();
    await provider.disconnect();
    _previouslyConnected = false;
  }

  void _startMeasurement() async {
    final provider = Provider.of<ImpedanceProvider>(context, listen: false);

    if (!provider.isConnected) {
      _showMessage('연결된 기기가 없습니다.');
      return;
    }

    if (!provider.isProgrammed) {
      _showMessage('프로그램이 연결되지 않았습니다.');
      return;
    }

    setState(() {
      _isLoading = true;
      _clickCount1to16 = 0;
      _clickCount17to32 = 0;
      _selectedMinIndex1to16 = null;
      _selectedMaxIndex1to16 = null;
      _selectedMinIndex17to32 = null;
      _selectedMaxIndex17to32 = null;
    });

    provider.clearMeasurements();
    await provider.startMeasurement();

    setState(() => _isLoading = false);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.save_rounded, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 12),
            const Text('캘리브레이션 저장'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.device_hub, size: 20, color: Color(0xFF64748B)),
                  const SizedBox(width: 10),
                  Text('내부기 ID: ${provider.innerDeviceId}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('이 캘리브레이션 데이터를 저장하시겠습니까?', style: TextStyle(fontSize: 15)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final firebaseSuccess = await provider.saveCalibrationToFirebase();
      setState(() => _isLoading = false);
      
      if (firebaseSuccess) {
        cacheService.invalidateCalibrationCache();
        toastManager.showSuccess(context, '저장이 완료되었습니다.');
      } else {
        toastManager.showError(context, '저장에 실패했습니다.');
      }
    }
  }

  void _showMessage(String message) {
    toastManager.showInfo(context, message);
  }
}
