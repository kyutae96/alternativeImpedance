/// Settings Screen - Alternative Impedance
/// Includes measurement parameters with admin password protection

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/impedance_provider.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isParamsUnlocked = false;

  // Parameter controllers
  late TextEditingController _repeatCountController;
  late TextEditingController _narrowPulseController;
  late TextEditingController _widePulseController;
  late TextEditingController _stimLevelController;

  // Firebase collection selections
  late String _selectedMeasurementCollection;
  late String _selectedCalibrationCollection;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ImpedanceProvider>(context, listen: false);
    final params = provider.measurementParams;

    _repeatCountController = TextEditingController(text: params.repeatCount.toString());
    _narrowPulseController = TextEditingController(text: params.narrowPulseWidth.toString());
    _widePulseController = TextEditingController(text: params.widePulseWidth.toString());
    _stimLevelController = TextEditingController(text: params.stimulationLevel.toString());

    // Initialize Firebase collection selections
    _selectedMeasurementCollection = FirebaseSettings.measurementCollection;
    _selectedCalibrationCollection = FirebaseSettings.calibrationCollection;
  }

  @override
  void dispose() {
    _repeatCountController.dispose();
    _narrowPulseController.dispose();
    _widePulseController.dispose();
    _stimLevelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Measurement Parameters Section (with password protection)
            _buildMeasurementParamsSection(),
            const SizedBox(height: 24),

            // App Info Section
            _buildSection(
              title: '앱 정보',
              icon: Icons.info_outline,
              children: [
                _buildInfoTile('앱 이름', AppConstants.appName),
                _buildInfoTile('버전', AppConstants.appVersion),
                _buildInfoTile('빌드', 'Flutter'),
              ],
            ),
            const SizedBox(height: 16),

            // Firebase Settings Section
            _buildFirebaseSettingsSection(),
            const SizedBox(height: 16),

            // BLE Settings Section
            _buildSection(
              title: 'BLE 통신 설정',
              icon: Icons.bluetooth,
              children: [
                _buildInfoTile('Service UUID', AppConstants.bleServiceUuid),
                _buildInfoTile('TX UUID', AppConstants.bleCharacteristicTxUuid),
                _buildInfoTile('RX UUID', AppConstants.bleCharacteristicRxUuid),
              ],
            ),
            const SizedBox(height: 16),

            // Frequency Mapping Section
            _buildSection(
              title: '주파수 매핑 (채널 1-16)',
              icon: Icons.waves,
              children: [
                _buildFrequencyTable(),
              ],
            ),
            const SizedBox(height: 16),

            // Calculation Method Section
            _buildCalculationMethodSection(),
            const SizedBox(height: 16),

            // Copyright
            Center(
              child: Text(
                '© 2026 TODOC',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementParamsSection() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.tune,
                  color: _isParamsUnlocked ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '측정 파라미터',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        _isParamsUnlocked ? '수정 가능' : '관리자 비밀번호 필요',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isParamsUnlocked ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isParamsUnlocked)
                  TextButton.icon(
                    onPressed: _lockParams,
                    icon: const Icon(Icons.lock, size: 18),
                    label: const Text('잠금'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _showPasswordDialog,
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: const Text('잠금 해제'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildParamField(
                  controller: _repeatCountController,
                  label: '측정 반복 횟수',
                  suffix: '회',
                  enabled: _isParamsUnlocked,
                ),
                const SizedBox(height: 12),
                _buildParamField(
                  controller: _narrowPulseController,
                  label: 'Narrow Pulse Width',
                  suffix: 'μs',
                  enabled: _isParamsUnlocked,
                ),
                const SizedBox(height: 12),
                _buildParamField(
                  controller: _widePulseController,
                  label: 'Wide Pulse Width',
                  suffix: 'μs',
                  enabled: _isParamsUnlocked,
                ),
                const SizedBox(height: 12),
                _buildParamField(
                  controller: _stimLevelController,
                  label: '자극 크기',
                  suffix: '',
                  enabled: _isParamsUnlocked,
                ),
                if (_isParamsUnlocked) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _resetToDefaults,
                          icon: const Icon(Icons.restore),
                          label: const Text('기본값 복원'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _applyParams,
                          icon: const Icon(Icons.check),
                          label: const Text('적용'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required bool enabled,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey.shade100,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        value,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      dense: true,
    );
  }

  Widget _buildFrequencyTable() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Table(
        border: TableBorder.all(color: Colors.grey.shade300),
        children: [
          TableRow(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.1)),
            children: const [
              TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('CH', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))),
              TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('주파수', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))),
              TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('CH', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))),
              TableCell(child: Padding(padding: EdgeInsets.all(8), child: Text('주파수', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)))),
            ],
          ),
          ...List.generate(8, (index) {
            final ch1 = index + 1;
            final ch2 = index + 9;
            return TableRow(
              children: [
                TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text('$ch1', textAlign: TextAlign.center))),
                TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text('${AppConstants.channelFrequencies[ch1 - 1]} Hz', textAlign: TextAlign.center))),
                TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text('$ch2', textAlign: TextAlign.center))),
                TableCell(child: Padding(padding: const EdgeInsets.all(8), child: Text('${AppConstants.channelFrequencies[ch2 - 1]} Hz', textAlign: TextAlign.center))),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _showPasswordDialog() {
    final passwordController = TextEditingController();
    bool obscureText = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('관리자 인증'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('측정 파라미터를 수정하려면 관리자 비밀번호를 입력하세요.'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscureText,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setDialogState(() {
                        obscureText = !obscureText;
                      });
                    },
                  ),
                ),
                onSubmitted: (_) => _verifyPassword(passwordController.text),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => _verifyPassword(passwordController.text),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  void _verifyPassword(String password) {
    if (password == AppConstants.adminPassword) {
      Navigator.pop(context);
      setState(() {
        _isParamsUnlocked = true;
      });
      _showMessage('인증 성공! 파라미터를 수정할 수 있습니다.');
    } else {
      _showMessage('비밀번호가 올바르지 않습니다.');
    }
  }

  void _lockParams() {
    setState(() {
      _isParamsUnlocked = false;
    });
    _showMessage('파라미터가 잠겼습니다.');
  }

  void _resetToDefaults() {
    setState(() {
      _repeatCountController.text = AppConstants.defaultRepeatCount.toString();
      _narrowPulseController.text = AppConstants.defaultNarrowPulseWidth.toString();
      _widePulseController.text = AppConstants.defaultWidePulseWidth.toString();
      _stimLevelController.text = AppConstants.defaultStimulationLevel.toString();
    });
    _showMessage('기본값으로 복원되었습니다.');
  }

  void _applyParams() {
    final provider = Provider.of<ImpedanceProvider>(context, listen: false);

    final repeatCount = int.tryParse(_repeatCountController.text) ?? AppConstants.defaultRepeatCount;
    final narrowPulse = int.tryParse(_narrowPulseController.text) ?? AppConstants.defaultNarrowPulseWidth;
    final widePulse = int.tryParse(_widePulseController.text) ?? AppConstants.defaultWidePulseWidth;
    final stimLevel = int.tryParse(_stimLevelController.text) ?? AppConstants.defaultStimulationLevel;

    provider.updateMeasurementParams(MeasurementParams(
      repeatCount: repeatCount,
      narrowPulseWidth: narrowPulse,
      widePulseWidth: widePulse,
      stimulationLevel: stimLevel,
    ));

    _showMessage('파라미터가 적용되었습니다.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Firebase Settings Section with collection selection
  Widget _buildFirebaseSettingsSection() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.cloud, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  'Firebase 설정',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Project ID (read-only)
          ListTile(
            title: const Text('프로젝트 ID'),
            subtitle: const Text(
              'artificialcochleadev',
              style: TextStyle(fontFamily: 'monospace'),
            ),
            dense: true,
          ),
          const Divider(height: 1),
          // Measurement Collection Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '측정 결과 컬렉션',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ...AppConstants.measurementCollectionOptions.map((collection) {
                  final isSelected = _selectedMeasurementCollection == collection;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedMeasurementCollection = collection;
                      });
                      FirebaseSettings().setMeasurementCollection(collection);
                      _showMessage('측정 결과 컬렉션이 변경되었습니다: $collection');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: collection,
                            groupValue: _selectedMeasurementCollection,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedMeasurementCollection = value;
                                });
                                FirebaseSettings().setMeasurementCollection(value);
                                _showMessage('측정 결과 컬렉션이 변경되었습니다: $value');
                              }
                            },
                          ),
                          Expanded(
                            child: Text(
                              collection,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Theme.of(context).primaryColor : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),
          // Calibration Collection Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '캘리브레이션 컬렉션',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                ...AppConstants.calibrationCollectionOptions.map((collection) {
                  final isSelected = _selectedCalibrationCollection == collection;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCalibrationCollection = collection;
                      });
                      FirebaseSettings().setCalibrationCollection(collection);
                      _showMessage('캘리브레이션 컬렉션이 변경되었습니다: $collection');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: collection,
                            groupValue: _selectedCalibrationCollection,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedCalibrationCollection = value;
                                });
                                FirebaseSettings().setCalibrationCollection(value);
                                _showMessage('캘리브레이션 컬렉션이 변경되었습니다: $value');
                              }
                            },
                          ),
                          Expanded(
                            child: Text(
                              collection,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Theme.of(context).primaryColor : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Calculation Method Section - explains impedance calculation formulas
  Widget _buildCalculationMethodSection() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.calculate, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  '계산 방법',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // Impedance Calculation
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFormulaCard(
                  title: '임피던스 측정값 계산',
                  icon: Icons.show_chart,
                  formulas: [
                    'Narrow Avg = Σ(NarrowPulse) / N - Offset',
                    'Wide Avg = Σ(WidePulse) / N - Offset',
                    'Impedance = (Narrow Avg + Wide Avg) / 2',
                  ],
                  description: 'Offset = ${AppConstants.impedanceOffset}',
                ),
                const SizedBox(height: 16),
                
                _buildFormulaCard(
                  title: '캘리브레이션 (기울기/절편)',
                  icon: Icons.tune,
                  formulas: [
                    'Slope (기울기) = (Max - Min) / (fMax - fMin)',
                    'Intercept (절편) = Min - Slope × fMin',
                  ],
                  description: 'Min/Max: 선택한 포인트의 임피던스 값\nfMin/fMax: 선택한 포인트의 주파수',
                ),
                const SizedBox(height: 16),
                
                _buildFormulaCard(
                  title: '진단 판정 기준',
                  icon: Icons.assessment,
                  formulas: [
                    '정상: Min ≤ 측정값 ≤ Max',
                    '쇼트: 측정값 < Min (${AppConstants.defaultMinThreshold})',
                    '오픈: 측정값 > Max (${AppConstants.defaultMaxThreshold})',
                  ],
                  description: '캘리브레이션 데이터 기반 또는 기본 임계값 사용',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaCard({
    required String title,
    required IconData icon,
    required List<String> formulas,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...formulas.map((formula) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    formula,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
