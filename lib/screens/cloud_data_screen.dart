/// Cloud Data Screen - Alternative Impedance
/// View and manage data stored in Firebase
/// Features: Sorting (Date/InnerID), Search, Pagination (30 items), Chart Display

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/impedance_data.dart';
import '../services/firebase_service.dart';
import '../utils/constants.dart';

/// Enum for sort options
enum SortField { date, innerID }
enum SortOrder { ascending, descending }

class CloudDataScreen extends StatefulWidget {
  const CloudDataScreen({super.key});

  @override
  State<CloudDataScreen> createState() => _CloudDataScreenState();
}

class _CloudDataScreenState extends State<CloudDataScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _searchController = TextEditingController();

  // Data lists
  List<ImpedanceFirebaseDataModel> _calibrationData = [];
  List<NewImpedanceFirebaseDataModel> _impedanceData = [];
  
  // Filtered and displayed data
  List<ImpedanceFirebaseDataModel> _filteredCalibrationData = [];
  List<NewImpedanceFirebaseDataModel> _filteredImpedanceData = [];
  
  bool _isLoading = true;
  
  // Sorting
  SortField _sortField = SortField.date;
  SortOrder _sortOrder = SortOrder.descending;
  
  // Pagination
  static const int _itemsPerPage = 30;
  int _calibrationCurrentPage = 0;
  int _impedanceCurrentPage = 0;
  
  // Search
  String _searchQuery = '';
  
  // Selected item for chart
  NewImpedanceFirebaseDataModel? _selectedImpedanceData;
  ImpedanceFirebaseDataModel? _selectedCalibrationData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _searchQuery = '';
        _searchController.clear();
        _selectedImpedanceData = null;
        _selectedCalibrationData = null;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _calibrationData = await _firebaseService.getAllCalibrationData();
      _impedanceData = await _firebaseService.getAllNewImpedanceData();
      _applyFiltersAndSort();
    } catch (e) {
      debugPrint('Error loading cloud data: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _applyFiltersAndSort() {
    // Filter calibration data
    _filteredCalibrationData = _calibrationData.where((item) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return item.innerID.toLowerCase().contains(query) ||
             item.date.toLowerCase().contains(query);
    }).toList();

    // Filter impedance data
    _filteredImpedanceData = _impedanceData.where((item) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return item.innerID.toLowerCase().contains(query) ||
             item.date.toLowerCase().contains(query);
    }).toList();

    // Sort calibration data
    _filteredCalibrationData.sort((a, b) {
      int result;
      if (_sortField == SortField.date) {
        result = a.date.compareTo(b.date);
      } else {
        result = a.innerID.compareTo(b.innerID);
      }
      return _sortOrder == SortOrder.ascending ? result : -result;
    });

    // Sort impedance data
    _filteredImpedanceData.sort((a, b) {
      int result;
      if (_sortField == SortField.date) {
        result = a.date.compareTo(b.date);
      } else {
        result = a.innerID.compareTo(b.innerID);
      }
      return _sortOrder == SortOrder.ascending ? result : -result;
    });

    // Reset pages when filter changes
    _calibrationCurrentPage = 0;
    _impedanceCurrentPage = 0;
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _applyFiltersAndSort();
    });
  }

  void _onSortFieldChanged(SortField field) {
    setState(() {
      if (_sortField == field) {
        // Toggle order if same field
        _sortOrder = _sortOrder == SortOrder.ascending 
            ? SortOrder.descending 
            : SortOrder.ascending;
      } else {
        _sortField = field;
        _sortOrder = SortOrder.descending;
      }
      _applyFiltersAndSort();
    });
  }

  List<T> _getPagedData<T>(List<T> data, int currentPage) {
    final startIndex = currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, data.length);
    if (startIndex >= data.length) return [];
    return data.sublist(startIndex, endIndex);
  }

  int _getTotalPages(int totalItems) {
    return (totalItems / _itemsPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('클라우드 데이터'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '새로고침',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '캘리브레이션', icon: Icon(Icons.tune)),
            Tab(text: '측정 결과', icon: Icon(Icons.assessment)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchAndSortBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCalibrationTab(),
                      _buildImpedanceTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchAndSortBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: '내부기 ID 또는 날짜로 검색...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
          ),
          const SizedBox(height: 12),
          // Sort buttons
          Row(
            children: [
              const Text('정렬: ', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              _buildSortChip('날짜', SortField.date),
              const SizedBox(width: 8),
              _buildSortChip('내부기 ID', SortField.innerID),
              const Spacer(),
              Text(
                _tabController.index == 0
                    ? '${_filteredCalibrationData.length}건'
                    : '${_filteredImpedanceData.length}건',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, SortField field) {
    final isSelected = _sortField == field;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isSelected)
            Icon(
              _sortOrder == SortOrder.ascending 
                  ? Icons.arrow_upward 
                  : Icons.arrow_downward,
              size: 16,
            ),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => _onSortFieldChanged(field),
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
    );
  }

  Widget _buildCalibrationTab() {
    if (_filteredCalibrationData.isEmpty) {
      return _buildEmptyState(
        icon: Icons.tune,
        message: _searchQuery.isNotEmpty 
            ? '검색 결과가 없습니다'
            : '저장된 캘리브레이션 데이터가 없습니다',
        subtitle: _searchQuery.isNotEmpty
            ? '다른 검색어를 시도해보세요'
            : '차트 분석에서 캘리브레이션을 진행하고 저장해주세요',
      );
    }

    final pagedData = _getPagedData(_filteredCalibrationData, _calibrationCurrentPage);
    final totalPages = _getTotalPages(_filteredCalibrationData.length);

    return Column(
      children: [
        // Selected chart view
        if (_selectedCalibrationData != null)
          _buildCalibrationChartView(_selectedCalibrationData!),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pagedData.length,
            itemBuilder: (context, index) {
              final data = pagedData[index];
              final isSelected = _selectedCalibrationData?.innerID == data.innerID &&
                                 _selectedCalibrationData?.date == data.date;
              return _buildCalibrationCard(data, isSelected);
            },
          ),
        ),
        // Pagination
        if (totalPages > 1)
          _buildPaginationBar(
            currentPage: _calibrationCurrentPage,
            totalPages: totalPages,
            onPageChanged: (page) {
              setState(() {
                _calibrationCurrentPage = page;
              });
            },
          ),
      ],
    );
  }

  Widget _buildImpedanceTab() {
    if (_filteredImpedanceData.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assessment,
        message: _searchQuery.isNotEmpty 
            ? '검색 결과가 없습니다'
            : '저장된 측정 결과가 없습니다',
        subtitle: _searchQuery.isNotEmpty
            ? '다른 검색어를 시도해보세요'
            : '진단 화면에서 측정 결과를 저장해주세요',
      );
    }

    final pagedData = _getPagedData(_filteredImpedanceData, _impedanceCurrentPage);
    final totalPages = _getTotalPages(_filteredImpedanceData.length);

    return Column(
      children: [
        // Selected chart view
        if (_selectedImpedanceData != null)
          _buildImpedanceChartView(_selectedImpedanceData!),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pagedData.length,
            itemBuilder: (context, index) {
              final data = pagedData[index];
              final isSelected = _selectedImpedanceData?.innerID == data.innerID &&
                                 _selectedImpedanceData?.date == data.date;
              return _buildImpedanceCard(data, isSelected);
            },
          ),
        ),
        // Pagination
        if (totalPages > 1)
          _buildPaginationBar(
            currentPage: _impedanceCurrentPage,
            totalPages: totalPages,
            onPageChanged: (page) {
              setState(() {
                _impedanceCurrentPage = page;
              });
            },
          ),
      ],
    );
  }

  Widget _buildPaginationBar({
    required int currentPage,
    required int totalPages,
    required Function(int) onPageChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // First page
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: currentPage > 0 ? () => onPageChanged(0) : null,
            tooltip: '첫 페이지',
          ),
          // Previous page
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
            tooltip: '이전 페이지',
          ),
          // Page numbers
          ...List.generate(
            totalPages > 5 ? 5 : totalPages,
            (index) {
              int pageNum;
              if (totalPages <= 5) {
                pageNum = index;
              } else if (currentPage < 2) {
                pageNum = index;
              } else if (currentPage > totalPages - 3) {
                pageNum = totalPages - 5 + index;
              } else {
                pageNum = currentPage - 2 + index;
              }
              
              if (pageNum < 0 || pageNum >= totalPages) return const SizedBox.shrink();
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => onPageChanged(pageNum),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: currentPage == pageNum
                          ? Theme.of(context).primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${pageNum + 1}',
                      style: TextStyle(
                        color: currentPage == pageNum ? Colors.white : Colors.black87,
                        fontWeight: currentPage == pageNum ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Next page
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages - 1 
                ? () => onPageChanged(currentPage + 1) 
                : null,
            tooltip: '다음 페이지',
          ),
          // Last page
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: currentPage < totalPages - 1 
                ? () => onPageChanged(totalPages - 1) 
                : null,
            tooltip: '마지막 페이지',
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationChartView(ImpedanceFirebaseDataModel data) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '캘리브레이션 측정값 그래프',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedCalibrationData = null;
                  });
                },
                tooltip: '닫기',
              ),
            ],
          ),
          Text(
            '내부기 ID: ${data.innerID} | 날짜: ${data.date}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: data.measurements1.isNotEmpty
                ? _buildMeasurementsChart(data.measurements1)
                : const Center(child: Text('측정 데이터가 없습니다')),
          ),
        ],
      ),
    );
  }

  Widget _buildImpedanceChartView(NewImpedanceFirebaseDataModel data) {
    // Parse measurements to numeric values
    final sortedEntries = data.measurements.entries.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.key) ?? 0;
        final bNum = int.tryParse(b.key) ?? 0;
        return aNum.compareTo(bNum);
      });

    // Extract numeric values and status
    final List<double> values = [];
    final List<String> statuses = [];
    
    for (final entry in sortedEntries) {
      final value = entry.value;
      if (value.contains('쇼트')) {
        values.add(-100); // Special value for short
        statuses.add('short');
      } else if (value.contains('오픈')) {
        values.add(-200); // Special value for open
        statuses.add('open');
      } else {
        final numValue = double.tryParse(value) ?? 0;
        values.add(numValue);
        statuses.add('normal');
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '측정 결과 그래프',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedImpedanceData = null;
                  });
                },
                tooltip: '닫기',
              ),
            ],
          ),
          Text(
            '내부기 ID: ${data.innerID} | 날짜: ${data.date}',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChartLegend('정상', Colors.green),
              const SizedBox(width: 16),
              _buildChartLegend('쇼트', Colors.blue),
              const SizedBox(width: 16),
              _buildChartLegend('오픈', Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildImpedanceBarChart(values, statuses),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
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
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildMeasurementsChart(List<double> measurements) {
    final spots = measurements.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 500,
          verticalInterval: 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            axisNameWidget: const Text('채널', style: TextStyle(fontSize: 10)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 4,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt() + 1}',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text('값', style: TextStyle(fontSize: 10)),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 9),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade400),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).primaryColor,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: Theme.of(context).primaryColor,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  'CH ${spot.x.toInt() + 1}: ${spot.y.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImpedanceBarChart(List<double> values, List<String> statuses) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: values.where((v) => v > 0).fold<double>(0, (max, v) => v > max ? v : max) * 1.2,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final status = statuses[groupIndex];
              String text;
              if (status == 'short') {
                text = 'CH ${groupIndex + 1}: 쇼트';
              } else if (status == 'open') {
                text = 'CH ${groupIndex + 1}: 오픈';
              } else {
                text = 'CH ${groupIndex + 1}: ${values[groupIndex].toStringAsFixed(2)}';
              }
              return BarTooltipItem(
                text,
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                if (value.toInt() % 4 == 0) {
                  return Text(
                    '${value.toInt() + 1}',
                    style: const TextStyle(fontSize: 9),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 9),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 100,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade400),
        ),
        barGroups: List.generate(values.length, (index) {
          final status = statuses[index];
          Color barColor;
          double barValue;
          
          if (status == 'short') {
            barColor = Colors.blue;
            barValue = 50; // Small indicator bar for short
          } else if (status == 'open') {
            barColor = Colors.red;
            barValue = 50; // Small indicator bar for open
          } else {
            barColor = Colors.green;
            barValue = values[index] > 0 ? values[index] : 0;
          }
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: barValue,
                color: barColor,
                width: values.length > 20 ? 6 : 10,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationCard(ImpedanceFirebaseDataModel data, bool isSelected) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (_selectedCalibrationData?.innerID == data.innerID &&
                _selectedCalibrationData?.date == data.date) {
              _selectedCalibrationData = null;
            } else {
              _selectedCalibrationData = data;
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isSelected
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: Icon(
                  isSelected ? Icons.check : Icons.tune,
                  color: isSelected ? Colors.white : Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '내부기 ID: ${data.innerID}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '날짜: ${data.date}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    if (data.measurements1.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '측정값: ${data.measurements1.length}개',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '그래프 표시 중',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _confirmDelete(data.innerID, isCalibration: true);
                      } else if (value == 'details') {
                        _showCalibrationDetails(data);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('상세 정보'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('삭제'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImpedanceCard(NewImpedanceFirebaseDataModel data, bool isSelected) {
    // Count status
    int normalCount = 0;
    int shortCount = 0;
    int openCount = 0;

    for (final entry in data.measurements.entries) {
      if (entry.value.contains('쇼트')) {
        shortCount++;
      } else if (entry.value.contains('오픈')) {
        openCount++;
      } else {
        normalCount++;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
            ? BorderSide(color: Colors.green, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (_selectedImpedanceData?.innerID == data.innerID &&
                _selectedImpedanceData?.date == data.date) {
              _selectedImpedanceData = null;
            } else {
              _selectedImpedanceData = data;
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isSelected
                    ? Colors.green
                    : Colors.green.withValues(alpha: 0.1),
                child: Icon(
                  isSelected ? Icons.check : Icons.assessment,
                  color: isSelected ? Colors.white : Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '내부기 ID: ${data.innerID}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '날짜: ${data.date}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatusChip('정상', normalCount, Colors.green),
                        const SizedBox(width: 6),
                        _buildStatusChip('쇼트', shortCount, Colors.blue),
                        const SizedBox(width: 6),
                        _buildStatusChip('오픈', openCount, Colors.red),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '그래프 표시 중',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _confirmDelete(data.innerID, isCalibration: false);
                      } else if (value == 'details') {
                        _showImpedanceDetails(data);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('상세 정보'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('삭제'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showCalibrationDetails(ImpedanceFirebaseDataModel data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '캘리브레이션 상세 정보',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text('내부기 ID: ${data.innerID}'),
                  Text('날짜: ${data.date}'),
                  const Divider(height: 32),
                  Text(
                    '채널 1-16',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow('최소값', data.combin1At1to16Min),
                  _buildDetailRow('최대값', data.combin1At1to16Max),
                  _buildDetailRow('저항 Min', data.resist1At1to16Min),
                  _buildDetailRow('저항 Max', data.resist1At1to16Max),
                  _buildDetailRow('기울기', data.combin1At1to16Inclin),
                  _buildDetailRow('절편', data.combin1At1to16Cap),
                  const SizedBox(height: 16),
                  Text(
                    '채널 17-32',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow('최소값', data.combin1At17to32Min),
                  _buildDetailRow('최대값', data.combin1At17to32Max),
                  _buildDetailRow('저항 Min', data.resist1At17to32Min),
                  _buildDetailRow('저항 Max', data.resist1At17to32Max),
                  _buildDetailRow('기울기', data.combin1At17to32Inclin),
                  _buildDetailRow('절편', data.combin1At17to32Cap),
                  if (data.measurements1.isNotEmpty) ...[
                    const Divider(height: 32),
                    Text(
                      '측정값 (${data.measurements1.length}개)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: data.measurements1.asMap().entries.map((entry) {
                        return Chip(
                          label: Text(
                            'CH${entry.key + 1}: ${entry.value.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showImpedanceDetails(NewImpedanceFirebaseDataModel data) {
    final sortedEntries = data.measurements.entries.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.key) ?? 0;
        final bNum = int.tryParse(b.key) ?? 0;
        return aNum.compareTo(bNum);
      });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '측정 결과 상세 정보',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text('내부기 ID: ${data.innerID}'),
                  Text('날짜: ${data.date}'),
                  const Divider(height: 32),
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    child: const Row(
                      children: [
                        Expanded(flex: 1, child: Text('CH', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('주파수', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 3, child: Text('결과', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  // Data rows
                  ...sortedEntries.map((entry) {
                    final channel = (int.tryParse(entry.key) ?? 0) + 1;
                    final frequency = AppConstants.channelFrequencies[(channel - 1) % 16];
                    final value = entry.value;

                    Color textColor = Colors.black;
                    if (value.contains('쇼트')) {
                      textColor = Colors.blue;
                    } else if (value.contains('오픈')) {
                      textColor = Colors.red;
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 1, child: Text('$channel', textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('$frequency Hz', textAlign: TextAlign.center)),
                          Expanded(
                            flex: 3,
                            child: Text(
                              value,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: textColor != Colors.black ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String innerID, {required bool isCalibration}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: Text(
          '내부기 ID: $innerID\n\n'
          '이 데이터를 삭제하시겠습니까?\n'
          '이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      bool success;
      if (isCalibration) {
        success = await _firebaseService.deleteCalibrationData(innerID);
        if (success) {
          setState(() {
            _selectedCalibrationData = null;
          });
        }
      } else {
        success = await _firebaseService.deleteNewImpedanceData(innerID);
        if (success) {
          setState(() {
            _selectedImpedanceData = null;
          });
        }
      }

      if (success) {
        _showMessage('삭제되었습니다.');
        _loadData();
      } else {
        _showMessage('삭제에 실패했습니다.');
      }
    }
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
