/// Measurement Parameters Card Widget
/// Displays current measurement parameters

import 'package:flutter/material.dart';
import '../utils/constants.dart';

class MeasurementParamsCard extends StatelessWidget {
  final MeasurementParams params;
  final VoidCallback? onEditPressed;
  final bool isEditable;

  const MeasurementParamsCard({
    super.key,
    required this.params,
    this.onEditPressed,
    this.isEditable = false,
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
                const Icon(Icons.tune, size: 20),
                const SizedBox(width: 8),
                Text(
                  '측정 파라미터',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (isEditable && onEditPressed != null)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: onEditPressed,
                    tooltip: '수정',
                  ),
              ],
            ),
            const Divider(),
            _buildParamRow(
              context,
              icon: Icons.repeat,
              label: '측정 반복 횟수',
              value: '${params.repeatCount}회',
            ),
            _buildParamRow(
              context,
              icon: Icons.compress,
              label: 'Narrow Pulse Width',
              value: '${params.narrowPulseWidth}μs',
            ),
            _buildParamRow(
              context,
              icon: Icons.expand,
              label: 'Wide Pulse Width',
              value: '${params.widePulseWidth}μs',
            ),
            _buildParamRow(
              context,
              icon: Icons.flash_on,
              label: '자극 크기',
              value: '${params.stimulationLevel}',
            ),
            _buildParamRow(
              context,
              icon: Icons.grid_4x4,
              label: '채널 선택',
              value: params.channelSelection == 255 ? '전체 (1-32)' : 'CH ${params.channelSelection}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParamRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
