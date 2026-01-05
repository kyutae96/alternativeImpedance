/// New Impedance Screen - Alternative Impedance
/// Based on NewImpedanceActivity.kt from original Android app
/// Shows diagnosed measurements and allows saving/exporting

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/impedance_provider.dart';
import '../models/impedance_data.dart';
import '../services/firebase_service.dart';
import '../services/excel_service.dart';
import '../utils/constants.dart';

class NewImpedanceScreen extends StatefulWidget {
  final VoidCallback? onNavigateToMeasurement;

  const NewImpedanceScreen({super.key, this.onNavigateToMeasurement});

  @override
  State<NewImpedanceScreen> createState() => _NewImpedanceScreenState();
}

class _NewImpedanceScreenState extends State<NewImpedanceScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  final ExcelService _excelService = ExcelService();

  bool _isLoading = false;
  bool _isExporting = false;
  List<DiagnosedMeasurement> _diagnosedMeasurements = [];
  CalibrationData? _calibrationData;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDiagnosedData();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDiagnosedData() async {
    final provider = Provider.of<ImpedanceProvider>(context, listen: false);

    if (provider.measurements.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Try to get calibration from Firebase
      _calibrationData = await provider.getCalibrationFromFirebase();

      if (_calibrationData != null) {
        _diagnosedMeasurements =
            await provider.diagnoseWithFirebaseCalibration();
      } else {
        // Use current calibration if available
        _diagnosedMeasurements = provider.diagnoseWithCurrentCalibration();
      }
    } catch (e) {
      debugPrint('Error loading diagnosed data: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImpedanceProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 768;

    return Scaffold(
      appBar: _buildAppBar(context),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: provider.measurements.isEmpty
            ? _buildEmptyState()
            : _isLoading
                ? _buildLoadingState()
                : isTablet
                    ? _buildTabletLayout(provider)
                    : _buildPhoneLayout(provider),
      ),
      bottomNavigationBar: _diagnosedMeasurements.isNotEmpty
          ? _buildBottomBar(provider)
          : null,
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
                  const Color(0xFF10B981),
                  const Color(0xFF059669),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.analytics_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text('임피던스 진단'),
        ],
      ),
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 2,
      actions: [
        if (_diagnosedMeasurements.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadDiagnosedData,
              tooltip: '새로고침',
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '진단 데이터 로딩 중...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon container
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey.shade300,
                    Colors.grey.shade400,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.assessment_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '진단할 측정 데이터가 없습니다',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '측정 탭에서 임피던스 측정을 먼저 진행해주세요',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onNavigateToMeasurement,
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bluetooth_searching_rounded,
                            color: Colors.white),
                        SizedBox(width: 10),
                        Text(
                          '측정 화면으로 이동',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout(ImpedanceProvider provider) {
    return Row(
      children: [
        // Left: Info Panel
        Container(
          width: 320,
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
                _buildDeviceInfoCard(provider),
                const SizedBox(height: 16),
                _buildCalibrationInfoCard(),
                const SizedBox(height: 16),
                _buildStatusSummaryCard(),
              ],
            ),
          ),
        ),
        // Right: Measurement List
        Expanded(
          child: _buildMeasurementList(),
        ),
      ],
    );
  }

  Widget _buildPhoneLayout(ImpedanceProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildDeviceInfoCard(provider),
          const SizedBox(height: 16),
          _buildCalibrationInfoCard(),
          const SizedBox(height: 16),
          _buildStatusSummaryCard(),
          const SizedBox(height: 20),
          _buildMeasurementGrid(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard(ImpedanceProvider provider) {
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.device_hub_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Text(
                  '내부기 정보',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow('내부기 ID', provider.innerDeviceId,
                icon: Icons.tag_rounded),
            _buildInfoRow('외부기', provider.deviceName,
                icon: Icons.bluetooth_rounded),
            _buildInfoRow('MAC 주소', provider.deviceAddress,
                icon: Icons.router_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationInfoCard() {
    if (_calibrationData == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFEF3C7),
              const Color(0xFFFDE68A).withValues(alpha: 0.5),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '캘리브레이션 데이터 없음',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '측정 화면에서 캘리브레이션을 진행해주세요',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFD1FAE5),
            const Color(0xFF6EE7B7).withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                '캘리브레이션 적용됨',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF065F46),
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _buildCalibrationInfoRow(
                  '채널 1-16 기울기',
                  _calibrationData!.combin1At1to16Inclin,
                ),
                const Divider(height: 16),
                _buildCalibrationInfoRow(
                  '채널 17-32 기울기',
                  _calibrationData!.combin1At17to32Inclin,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value.isEmpty ? '---' : value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
            color: Color(0xFF065F46),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSummaryCard() {
    int normalCount = 0;
    int shortCount = 0;
    int openCount = 0;

    for (final measurement in _diagnosedMeasurements) {
      switch (measurement.status) {
        case ElectrodeStatus.normal:
          normalCount++;
          break;
        case ElectrodeStatus.short:
          shortCount++;
          break;
        case ElectrodeStatus.open:
          openCount++;
          break;
        default:
          break;
      }
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Text(
                '전극 상태 요약',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                  child: _buildStatusBadge(
                      '정상', normalCount, const Color(0xFF10B981))),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatusBadge(
                      '쇼트', shortCount, const Color(0xFF3B82F6))),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatusBadge(
                      '오픈', openCount, const Color(0xFFEF4444))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _diagnosedMeasurements.length,
      itemBuilder: (context, index) {
        final measurement = _diagnosedMeasurements[index];
        return AnimatedContainer(
          duration: Duration(milliseconds: 200 + (index * 50)),
          child: _buildMeasurementTile(measurement),
        );
      },
    );
  }

  Widget _buildMeasurementGrid() {
    // Display as a table like NewImpedanceAdapter
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF97316), Color(0xFFFB923C)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.grid_view_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Text(
                  '측정 결과',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            ),
            child: Row(
              children: const [
                Expanded(
                    flex: 1,
                    child: Text('CH',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13))),
                Expanded(
                    flex: 2,
                    child: Text('주파수',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13))),
                Expanded(
                    flex: 3,
                    child: Text('측정값',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13))),
              ],
            ),
          ),
          // Data rows
          ...List.generate(16, (index) {
            final ch1 = _diagnosedMeasurements.length > index
                ? _diagnosedMeasurements[index]
                : null;
            final ch2 = _diagnosedMeasurements.length > (index + 16)
                ? _diagnosedMeasurements[index + 16]
                : null;

            return Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: Row(
                children: [
                  // Channel 1-16
                  Expanded(
                    child: _buildMeasurementRow(ch1, index + 1),
                  ),
                  Container(
                    width: 1,
                    height: 48,
                    color: Colors.grey.shade200,
                  ),
                  // Channel 17-32
                  Expanded(
                    child: _buildMeasurementRow(ch2, index + 17),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildMeasurementRow(DiagnosedMeasurement? measurement, int channel) {
    if (measurement == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            Expanded(
                flex: 1,
                child: Text('$channel',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w500))),
            Expanded(
                flex: 2,
                child: Text(
                    '${AppConstants.channelFrequencies[(channel - 1) % 16]}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600))),
            Expanded(
                flex: 3,
                child: Text('N/A',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade400))),
          ],
        ),
      );
    }

    Color textColor;
    Color bgColor;
    switch (measurement.status) {
      case ElectrodeStatus.short:
        textColor = const Color(0xFF3B82F6);
        bgColor = const Color(0xFF3B82F6).withValues(alpha: 0.1);
        break;
      case ElectrodeStatus.open:
        textColor = const Color(0xFFEF4444);
        bgColor = const Color(0xFFEF4444).withValues(alpha: 0.1);
        break;
      default:
        textColor = const Color(0xFF10B981);
        bgColor = Colors.transparent;
    }

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              '${measurement.channel}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${measurement.frequency}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              measurement.displayText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementTile(DiagnosedMeasurement measurement) {
    Color statusColor;
    IconData statusIcon;

    switch (measurement.status) {
      case ElectrodeStatus.normal:
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
        break;
      case ElectrodeStatus.short:
        statusColor = const Color(0xFF3B82F6);
        statusIcon = Icons.warning_rounded;
        break;
      case ElectrodeStatus.open:
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.error_rounded;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(statusIcon, color: statusColor, size: 24),
        ),
        title: Text(
          '채널 ${measurement.channel}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '주파수: ${measurement.frequency} Hz',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                measurement.displayText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '원시값: ${measurement.rawValue.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(ImpedanceProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isExporting ? null : _exportToExcel,
                    borderRadius: BorderRadius.circular(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isExporting)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          )
                        else
                          Icon(Icons.file_download_rounded,
                              color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Excel 내보내기',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _saveToFirebase(provider),
                    borderRadius: BorderRadius.circular(14),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Firebase 저장',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.grey.shade500),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Text(
            value.isEmpty ? '---' : value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    if (_diagnosedMeasurements.isEmpty) return;

    setState(() {
      _isExporting = true;
    });

    try {
      final measurementsMap = <int, String>{};
      for (final measurement in _diagnosedMeasurements) {
        measurementsMap[measurement.channel - 1] = measurement.displayText;
      }

      final filePath = await _excelService.exportNewImpedanceData(
        measurements: measurementsMap,
      );

      if (filePath != null) {
        final share = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 12),
                const Text('내보내기 완료'),
              ],
            ),
            content: const Text('Excel 파일이 생성되었습니다. 공유하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('닫기'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('공유'),
              ),
            ],
          ),
        );

        if (share == true) {
          await _excelService.shareExcelFile(filePath);
        }
      } else {
        _showMessage('Excel 내보내기에 실패했습니다.');
      }
    } catch (e) {
      _showMessage('오류: $e');
    }

    setState(() {
      _isExporting = false;
    });
  }

  Future<void> _saveToFirebase(ImpedanceProvider provider) async {
    if (_diagnosedMeasurements.isEmpty) return;

    if (provider.innerDeviceId.isEmpty ||
        provider.innerDeviceId == '--------') {
      _showMessage('내부기 ID가 없습니다.');
      return;
    }

    final measurementsMap = <String, String>{};
    for (final measurement in _diagnosedMeasurements) {
      measurementsMap[(measurement.channel - 1).toString()] =
          measurement.displayText;
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
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.cloud_upload_rounded,
                  color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            const Text('Firebase 저장'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.device_hub,
                          size: 18, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        '내부기 ID: ${provider.innerDeviceId}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.numbers,
                          size: 18, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        '측정 결과: ${measurementsMap.length}개',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '컬렉션: ${AppConstants.firestoreCollection}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
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
      final success = await provider.saveNewImpedanceToFirebase(measurementsMap);
      _showMessage(success ? '저장이 완료되었습니다.' : '저장에 실패했습니다.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
