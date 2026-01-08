// BLE Status Card Widget
// Shows current BLE connection status with modern UI

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/impedance_provider.dart';
import '../models/impedance_data.dart';

class BleStatusCard extends StatelessWidget {
  final VoidCallback? onScanPressed;
  final VoidCallback? onDisconnectPressed;

  const BleStatusCard({
    super.key,
    this.onScanPressed,
    this.onDisconnectPressed,
  });

  // BLE 연결 상태 색상 - 파란색
  static const Color _connectedColor = Color(0xFF3B82F6); // Blue
  static const Color _connectedColorDark = Color(0xFF2563EB); // Dark Blue

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImpedanceProvider>(context);
    final theme = Theme.of(context);
    final isConnected = provider.isConnected;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with gradient background - 연결시 파란색
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isConnected
                    ? [_connectedColor, _connectedColorDark] // 파란색으로 변경
                    : [const Color(0xFF64748B), const Color(0xFF475569)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                _buildConnectionIndicator(provider),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BLE 연결 상태',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getConnectionStateText(provider.connectionState),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isConnected)
                  Material(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: onDisconnectPressed,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.link_off, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Device info section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(
                  context,
                  icon: Icons.bluetooth,
                  label: '외부 기기',
                  value: provider.deviceName,
                  isHighlighted: provider.deviceName.startsWith('TD'),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  icon: Icons.router_outlined,
                  label: 'MAC 주소',
                  value: provider.deviceAddress,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  context,
                  icon: Icons.memory,
                  label: '내부기 ID',
                  value: provider.innerDeviceId,
                  isHighlighted: !provider.innerDeviceId.contains('---'),
                  highlightColor: const Color(0xFF3B82F6),
                ),
                
                const SizedBox(height: 16),
                
                // Program status chip - 파란색으로 변경
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: provider.isProgrammed
                        ? _connectedColor.withValues(alpha: 0.1)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: provider.isProgrammed
                          ? _connectedColor.withValues(alpha: 0.3)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: provider.isProgrammed
                              ? _connectedColor
                              : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        provider.isProgrammed ? '프로그램 연결됨' : '프로그램 연결 안됨',
                        style: TextStyle(
                          color: provider.isProgrammed
                              ? _connectedColorDark
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Scan button
                if (!isConnected) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onScanPressed,
                      icon: const Icon(Icons.bluetooth_searching, size: 20),
                      label: const Text('기기 검색'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionIndicator(ImpedanceProvider provider) {
    Color bgColor;
    IconData icon;

    if (provider.isConnected) {
      bgColor = Colors.white;
      icon = Icons.bluetooth_connected;
    } else if (provider.connectionState == BleConnectionState.connecting) {
      bgColor = Colors.white;
      icon = Icons.bluetooth_searching;
    } else {
      bgColor = Colors.white;
      icon = Icons.bluetooth_disabled;
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isHighlighted = false,
    Color highlightColor = const Color(0xFF10B981),
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isHighlighted
                ? highlightColor.withValues(alpha: 0.1)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isHighlighted ? highlightColor : Colors.grey.shade500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isHighlighted
                      ? highlightColor
                      : const Color(0xFF334155),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getConnectionStateText(BleConnectionState state) {
    switch (state) {
      case BleConnectionState.disconnected:
        return '연결 안됨';
      case BleConnectionState.connecting:
        return '연결 중...';
      case BleConnectionState.connected:
        return '연결됨';
      case BleConnectionState.discovering:
        return '서비스 검색 중...';
      case BleConnectionState.ready:
        return '준비 완료';
      case BleConnectionState.error:
        return '오류 발생';
    }
  }
}
