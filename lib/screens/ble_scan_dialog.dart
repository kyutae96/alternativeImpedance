/// BLE Scan Dialog - Alternative Impedance
/// Based on bluetooth_bottom_sheet from original Android app

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/impedance_provider.dart';
import '../models/impedance_data.dart';

class BleScanDialog extends StatefulWidget {
  const BleScanDialog({super.key});

  @override
  State<BleScanDialog> createState() => _BleScanDialogState();
}

class _BleScanDialogState extends State<BleScanDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScan();
    });
  }

  void _startScan() {
    final provider = Provider.of<ImpedanceProvider>(context, listen: false);
    provider.startScan();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ImpedanceProvider>(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_searching, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '기기 검색',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      provider.stopScan();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // Scanning indicator
            if (provider.isScanning)
              const LinearProgressIndicator(),

            // Device list
            Flexible(
              child: provider.scannedDevices.isEmpty
                  ? _buildEmptyState(provider)
                  : _buildDeviceList(provider),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: provider.isScanning ? null : _startScan,
                      icon: const Icon(Icons.refresh),
                      label: const Text('다시 검색'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: provider.isScanning
                          ? () => provider.stopScan()
                          : () => Navigator.pop(context),
                      icon: Icon(provider.isScanning ? Icons.stop : Icons.close),
                      label: Text(provider.isScanning ? '검색 중지' : '닫기'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ImpedanceProvider provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            provider.isScanning ? Icons.bluetooth_searching : Icons.bluetooth_disabled,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            provider.isScanning ? '기기를 검색 중입니다...' : '검색된 기기가 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TD로 시작하는 TODOC 기기를 검색합니다',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(ImpedanceProvider provider) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(8),
      itemCount: provider.scannedDevices.length,
      itemBuilder: (context, index) {
        final device = provider.scannedDevices[index];
        return _buildDeviceCard(device, provider);
      },
    );
  }

  Widget _buildDeviceCard(BleDeviceInfo device, ImpedanceProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Icon(
            Icons.bluetooth,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.address),
            Row(
              children: [
                _buildSignalIndicator(device.rssi),
                const SizedBox(width: 4),
                Text(
                  '${device.rssi} dBm',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: provider.isLoading
              ? null
              : () => _connectToDevice(device),
          child: provider.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('연결'),
        ),
      ),
    );
  }

  Widget _buildSignalIndicator(int rssi) {
    Color color;
    int bars;

    if (rssi >= -60) {
      color = Colors.green;
      bars = 4;
    } else if (rssi >= -70) {
      color = Colors.lightGreen;
      bars = 3;
    } else if (rssi >= -80) {
      color = Colors.orange;
      bars = 2;
    } else {
      color = Colors.red;
      bars = 1;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        return Container(
          width: 4,
          height: 4 + (index * 2).toDouble(),
          margin: const EdgeInsets.only(right: 1),
          decoration: BoxDecoration(
            color: index < bars ? color : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  Future<void> _connectToDevice(BleDeviceInfo device) async {
    final provider = Provider.of<ImpedanceProvider>(context, listen: false);

    // Stop scanning
    await provider.stopScan();

    // Connect
    final success = await provider.connectToDevice(device);

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${device.name}에 연결되었습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('연결에 실패했습니다. 다시 시도해주세요.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
