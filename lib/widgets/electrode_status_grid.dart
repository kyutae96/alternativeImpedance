/// Electrode Status Grid Widget
/// Displays 32-channel electrode status in a grid format

import 'package:flutter/material.dart';
import '../utils/constants.dart';

class ElectrodeStatusGrid extends StatelessWidget {
  final Map<int, double> measurements;
  final double? minThreshold;
  final double? maxThreshold;

  const ElectrodeStatusGrid({
    super.key,
    required this.measurements,
    this.minThreshold,
    this.maxThreshold,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grid_view, size: 20),
                const SizedBox(width: 8),
                Text(
                  '전극 상태',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                _buildLegend(),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '채널 1-16',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildChannelGrid(1, 16),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '채널 17-32',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildChannelGrid(17, 32),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegendItem(Colors.green, '정상'),
        const SizedBox(width: 8),
        _buildLegendItem(Colors.blue, '쇼트'),
        const SizedBox(width: 8),
        _buildLegendItem(Colors.red, '오픈'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildChannelGrid(int startChannel, int endChannel) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.5,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: endChannel - startChannel + 1,
      itemBuilder: (context, index) {
        final channel = startChannel + index;
        return _buildChannelCell(channel);
      },
    );
  }

  Widget _buildChannelCell(int channel) {
    final value = measurements[channel];
    final status = _getStatus(value);
    final color = _getStatusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'CH$channel',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (value != null)
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 9,
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  String _getStatus(double? value) {
    if (value == null) return 'unknown';

    final min = minThreshold ?? AppConstants.defaultMinThreshold;
    final max = maxThreshold ?? AppConstants.defaultMaxThreshold;

    if (value < min) return 'short';
    if (value > max) return 'open';
    return 'normal';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'normal':
        return Colors.green;
      case 'short':
        return Colors.blue;
      case 'open':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
