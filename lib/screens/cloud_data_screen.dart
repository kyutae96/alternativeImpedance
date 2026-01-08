// Cloud Data Screen - Alternative Impedance
// View and manage data stored in Firebase
// Features: Sorting (Date/InnerID), Search, Pagination (30 items), Chart Display, Caching

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/impedance_data.dart';
import '../services/firebase_service.dart';
import '../services/cache_service.dart';
import '../utils/constants.dart';
import '../utils/toast_manager.dart';

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
  
  // Selected item for detail view (kept for compatibility)
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

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check cache first (unless force refresh)
      if (!forceRefresh) {
        final cachedCalibration = cacheService.calibrationData;
        final cachedImpedance = cacheService.impedanceData;
        
        if (cachedCalibration != null && cachedImpedance != null) {
          _calibrationData = cachedCalibration;
          _impedanceData = cachedImpedance;
          _applyFiltersAndSort();
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Fetch from Firebase
      _calibrationData = await _firebaseService.getAllCalibrationData();
      _impedanceData = await _firebaseService.getAllNewImpedanceData();
      
      // Update cache
      cacheService.setCalibrationData(_calibrationData);
      cacheService.setImpedanceData(_impedanceData);
      
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
            onPressed: () => _loadData(forceRefresh: true),
            tooltip: '새로고침 (서버에서 다시 불러오기)',
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
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF1E293B),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: 4),
            Icon(
              _sortOrder == SortOrder.ascending 
                  ? Icons.arrow_upward 
                  : Icons.arrow_downward,
              size: 16,
              color: Colors.white,
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (_) => _onSortFieldChanged(field),
      selectedColor: const Color(0xFF1565C0), // 더 진한 파란색
      backgroundColor: const Color(0xFFE2E8F0), // 밝은 회색
      checkmarkColor: Colors.white,
      showCheckmark: false,
      side: BorderSide(
        color: isSelected ? const Color(0xFF1565C0) : const Color(0xFF94A3B8),
        width: isSelected ? 2 : 1,
      ),
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
        // List (전체 화면 사용)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pagedData.length,
            itemBuilder: (context, index) {
              final data = pagedData[index];
              return _buildCalibrationCard(data, false);
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
        // List (전체 화면 사용)
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pagedData.length,
            itemBuilder: (context, index) {
              final data = pagedData[index];
              return _buildImpedanceCard(data, false);
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.tune, color: Theme.of(context).primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '캘리브레이션 상세',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '내부기 ID: ${data.innerID} | ${data.date}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ],
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
          const Divider(height: 24),
          
          // Chart
          const Text('측정값 그래프', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: data.measurements1.isNotEmpty
                ? _buildMeasurementsChart(data.measurements1)
                : const Center(child: Text('측정 데이터가 없습니다')),
          ),
          const Divider(height: 24),
          
          // Details - Channel 1-16
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('채널 1-16', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor)),
                    const SizedBox(height: 8),
                    _buildCompactDetailRow('최소값', data.combin1At1to16Min),
                    _buildCompactDetailRow('최대값', data.combin1At1to16Max),
                    _buildCompactDetailRow('기울기', data.combin1At1to16Inclin),
                    _buildCompactDetailRow('절편', data.combin1At1to16Cap),
                  ],
                ),
              ),
              Container(width: 1, height: 80, color: Colors.grey.shade300),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('채널 17-32', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange.shade700)),
                    const SizedBox(height: 8),
                    _buildCompactDetailRow('최소값', data.combin1At17to32Min),
                    _buildCompactDetailRow('최대값', data.combin1At17to32Max),
                    _buildCompactDetailRow('기울기', data.combin1At17to32Inclin),
                    _buildCompactDetailRow('절편', data.combin1At17to32Cap),
                  ],
                ),
              ),
            ],
          ),
          
          // Measurements chips
          if (data.measurements1.isNotEmpty) ...[
            const Divider(height: 24),
            Text('측정값 (${data.measurements1.length}개)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: data.measurements1.asMap().entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'CH${entry.key + 1}: ${entry.value.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildCompactDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
    
    // Count status
    int normalCount = 0;
    int shortCount = 0;
    int openCount = 0;
    
    for (final entry in sortedEntries) {
      final value = entry.value;
      if (value.contains('쇼트')) {
        values.add(-100);
        statuses.add('short');
        shortCount++;
      } else if (value.contains('오픈')) {
        values.add(-200);
        statuses.add('open');
        openCount++;
      } else {
        final numValue = double.tryParse(value) ?? 0;
        values.add(numValue);
        statuses.add('normal');
        normalCount++;
      }
    }

    return Container(
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.assessment, color: Colors.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '측정 결과 상세',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '내부기 ID: ${data.innerID} | ${data.date}',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ],
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
          const Divider(height: 24),
          
          // Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatusSummary('정상', normalCount, Colors.green),
              _buildStatusSummary('쇼트', shortCount, Colors.blue),
              _buildStatusSummary('오픈', openCount, Colors.red),
            ],
          ),
          const Divider(height: 24),
          
          // Chart
          const Text('측정 그래프', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: _buildImpedanceBarChart(values, statuses),
          ),
          const Divider(height: 24),
          
          // Detailed measurements table
          const Text('채널별 측정값', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 1, child: Text('CH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('저항값', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('결과', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                // Data rows (show first 8 channels)
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    itemCount: sortedEntries.length,
                    itemBuilder: (context, index) {
                      final entry = sortedEntries[index];
                      final channel = (int.tryParse(entry.key) ?? 0) + 1;
                      final frequency = AppConstants.channelFrequencies[(channel - 1) % 16];
                      final value = entry.value;
                      
                      Color textColor = Colors.black;
                      if (value.contains('쇼트')) {
                        textColor = Colors.blue;
                      } else if (value.contains('오픈')) {
                        textColor = Colors.red;
                      } else {
                        textColor = Colors.green.shade700;
                      }
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 1, child: Text('$channel', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                            Expanded(flex: 2, child: Text('$frequency Ω', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                            Expanded(
                              flex: 2,
                              child: Text(
                                value,
                                style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusSummary(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
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
            color: const Color(0xFFFF6B35),  // 진한 주황색 - 더 잘 보이는 색상
            barWidth: 3.5,  // 더 두꺼운 선
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 5,  // 더 큰 점
                  color: const Color(0xFFFF6B35),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
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
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _openCalibrationDetailScreen(data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: Icon(
                  Icons.tune,
                  color: Theme.of(context).primaryColor,
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
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(data.innerID, isCalibration: true),
                    tooltip: '삭제',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _openCalibrationDetailScreen(ImpedanceFirebaseDataModel data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _CalibrationDetailScreen(data: data),
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
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _openImpedanceDetailScreen(data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                child: const Icon(
                  Icons.assessment,
                  color: Colors.green,
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
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(data.innerID, isCalibration: false),
                    tooltip: '삭제',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _openImpedanceDetailScreen(NewImpedanceFirebaseDataModel data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ImpedanceDetailScreen(data: data),
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
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'CH${entry.key + 1}: ${entry.value.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
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
                        Expanded(flex: 2, child: Text('저항값', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
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
                          Expanded(flex: 2, child: Text('$frequency Ω', textAlign: TextAlign.center)),
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
          cacheService.invalidateCalibrationCache();
        }
      } else {
        success = await _firebaseService.deleteNewImpedanceData(innerID);
        if (success) {
          cacheService.invalidateImpedanceCache();
        }
      }

      if (success) {
        toastManager.showSuccess(context, '삭제되었습니다.');
        _loadData(forceRefresh: true);
      } else {
        toastManager.showError(context, '삭제에 실패했습니다.');
      }
    }
  }
}

// ============================================================================
// 캘리브레이션 상세 화면 (전체 화면)
// ============================================================================
class _CalibrationDetailScreen extends StatelessWidget {
  final ImpedanceFirebaseDataModel data;
  
  const _CalibrationDetailScreen({required this.data});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캘리브레이션 상세'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            _buildInfoCard(context),
            const SizedBox(height: 16),
            
            // Chart
            _buildChartSection(context),
            const SizedBox(height: 16),
            
            // Channel Details
            _buildChannelDetails(context),
            const SizedBox(height: 16),
            
            // Measurements
            if (data.measurements1.isNotEmpty)
              _buildMeasurementsSection(context),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              radius: 28,
              child: Icon(Icons.tune, color: Theme.of(context).primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '내부기 ID: ${data.innerID}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '날짜: ${data.date}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  if (data.measurements1.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '측정값: ${data.measurements1.length}개',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChartSection(BuildContext context) {
    if (data.measurements1.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.show_chart, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text('측정 데이터가 없습니다', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      );
    }
    
    // 측정값을 채널 순서대로 표시 (X축: 채널 번호, Y축: 결과값)
    final spots = data.measurements1.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble() + 1, e.value); // 채널 번호 (1부터 시작)
    }).toList();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text('측정값 그래프', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Text('X: 채널 번호 | Y: 결과값 (Ω)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 1,
                    verticalInterval: 2,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                    getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 2,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) => Text(
                          value.toStringAsFixed(1),
                          style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                        ),
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
                      color: const Color(0xFFE91E63), // 진한 핑크색 (잘 보이는 색상)
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                          radius: 5,
                          color: const Color(0xFFE91E63),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFFE91E63).withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChannelDetails(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text('채널별 캘리브레이션 결과', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildChannelCard(
                    context,
                    '채널 1-16',
                    Theme.of(context).primaryColor,
                    data.combin1At1to16Min,
                    data.combin1At1to16Max,
                    data.combin1At1to16Inclin,
                    data.combin1At1to16Cap,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildChannelCard(
                    context,
                    '채널 17-32',
                    Colors.orange.shade700,
                    data.combin1At17to32Min,
                    data.combin1At17to32Max,
                    data.combin1At17to32Inclin,
                    data.combin1At17to32Cap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildChannelCard(BuildContext context, String title, Color color, String min, String max, String slope, String intercept) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          const SizedBox(height: 12),
          _buildDetailRow('최소값', min),
          _buildDetailRow('최대값', max),
          _buildDetailRow('기울기', slope),
          _buildDetailRow('절편', intercept),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
  
  Widget _buildMeasurementsSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text('측정값 (${data.measurements1.length}개)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.measurements1.asMap().entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'CH${entry.key + 1}: ${entry.value.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 측정 결과 상세 화면 (전체 화면)
// ============================================================================
class _ImpedanceDetailScreen extends StatefulWidget {
  final NewImpedanceFirebaseDataModel data;
  
  const _ImpedanceDetailScreen({required this.data});
  
  @override
  State<_ImpedanceDetailScreen> createState() => _ImpedanceDetailScreenState();
}

class _ImpedanceDetailScreenState extends State<_ImpedanceDetailScreen> {
  ImpedanceFirebaseDataModel? _calibrationData;
  bool _isLoadingCalibration = true;
  
  @override
  void initState() {
    super.initState();
    _loadCalibrationData();
  }
  
  Future<void> _loadCalibrationData() async {
    try {
      // 같은 innerID로 캘리브레이션 데이터 조회
      final calibrations = await FirebaseService().getAllCalibrationData();
      final matching = calibrations.where((c) => c.innerID == widget.data.innerID).toList();
      if (matching.isNotEmpty) {
        // 가장 최근 캘리브레이션 사용
        matching.sort((a, b) => b.date.compareTo(a.date));
        setState(() {
          _calibrationData = matching.first;
        });
      }
    } catch (e) {
      // 캘리브레이션 로드 실패 시 무시
    } finally {
      setState(() {
        _isLoadingCalibration = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Parse measurements
    final sortedEntries = widget.data.measurements.entries.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.key) ?? 0;
        final bNum = int.tryParse(b.key) ?? 0;
        return aNum.compareTo(bNum);
      });
    
    int normalCount = 0;
    int shortCount = 0;
    int openCount = 0;
    final List<double> values = [];
    final List<String> statuses = [];
    
    for (final entry in sortedEntries) {
      final value = entry.value;
      if (value.contains('쇼트')) {
        values.add(-100);
        statuses.add('short');
        shortCount++;
      } else if (value.contains('오픈')) {
        values.add(-200);
        statuses.add('open');
        openCount++;
      } else {
        final numValue = double.tryParse(value) ?? 0;
        values.add(numValue);
        statuses.add('normal');
        normalCount++;
      }
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('측정 결과 상세'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            _buildInfoCard(context, normalCount, shortCount, openCount),
            const SizedBox(height: 16),
            
            // Calibration Info Card
            _buildCalibrationInfoCard(context),
            const SizedBox(height: 16),
            
            // Summary
            _buildSummaryCard(context, normalCount, shortCount, openCount),
            const SizedBox(height: 16),
            
            // Chart
            _buildChartSection(context, values, statuses),
            const SizedBox(height: 16),
            
            // Detailed Table
            _buildDetailedTable(context, sortedEntries),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCalibrationInfoCard(BuildContext context) {
    if (_isLoadingCalibration) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text('캘리브레이션 정보 로딩 중...', style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }
    
    if (_calibrationData == null) {
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '캘리브레이션 데이터를 찾을 수 없습니다.\n계산 과정을 확인할 수 없습니다.',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    final slope1to16 = double.tryParse(_calibrationData!.combin1At1to16Inclin) ?? 0;
    final intercept1to16 = double.tryParse(_calibrationData!.combin1At1to16Cap) ?? 0;
    final slope17to32 = double.tryParse(_calibrationData!.combin1At17to32Inclin) ?? 0;
    final intercept17to32 = double.tryParse(_calibrationData!.combin1At17to32Cap) ?? 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text('캘리브레이션 정보', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${_calibrationData!.date}', style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildCalibrationColumn('채널 1-16', slope1to16, intercept1to16, Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCalibrationColumn('채널 17-32', slope17to32, intercept17to32, Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '공식: 결과값 = Slope × RawValue + Intercept\n각 결과값을 탭하면 계산 과정을 확인할 수 있습니다.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCalibrationColumn(String title, double slope, double intercept, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
          const SizedBox(height: 6),
          Text('기울기: ${slope.toStringAsFixed(5)}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          Text('절편: ${intercept.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
        ],
      ),
    );
  }
  
  Widget _buildInfoCard(BuildContext context, int normal, int short, int open) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              radius: 28,
              child: const Icon(Icons.assessment, color: Colors.green, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '내부기 ID: ${widget.data.innerID}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '날짜: ${widget.data.date}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryCard(BuildContext context, int normal, int short, int open) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.blue),
                SizedBox(width: 8),
                Text('측정 결과 요약', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildSummaryItem('정상', normal, Colors.green)),
                Expanded(child: _buildSummaryItem('쇼트', short, Colors.blue)),
                Expanded(child: _buildSummaryItem('오픈', open, Colors.red)),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryItem(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }
  
  Widget _buildChartSection(BuildContext context, List<double> values, List<String> statuses) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart, color: Colors.green),
                SizedBox(width: 8),
                Text('측정 그래프', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 4),
            Text('X: 채널 번호 | Y: 결과값 (Ω)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('정상', Colors.green),
                const SizedBox(width: 16),
                _buildLegendItem('쇼트', Colors.blue),
                const SizedBox(width: 16),
                _buildLegendItem('오픈', Colors.red),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: values.where((v) => v > 0).fold(0.0, (a, b) => a > b ? a : b) * 1.2,
                  minY: 0,
                  barGroups: List.generate(values.length, (index) {
                    final status = statuses[index];
                    Color barColor;
                    double barValue;
                    
                    if (status == 'short') {
                      barColor = Colors.blue;
                      barValue = 50;
                    } else if (status == 'open') {
                      barColor = Colors.red;
                      barValue = 50;
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
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${value.toInt() + 1}',
                            style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 100,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }
  
  Widget _buildDetailedTable(BuildContext context, List<MapEntry<String, String>> entries) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.table_chart, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('채널별 측정값', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                _buildFormulaTooltip(context),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 1, child: Text('CH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
                        Expanded(flex: 2, child: Text('저항값', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
                        Expanded(flex: 2, child: Text('결과', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
                      ],
                    ),
                  ),
                  // Data rows
                  ...entries.map((entry) {
                    final channel = (int.tryParse(entry.key) ?? 0) + 1;
                    final resistance = AppConstants.channelResistances[(channel - 1) % 16];
                    final value = entry.value;
                    
                    Color textColor = Colors.green.shade700;
                    String status = 'normal';
                    if (value.contains('쇼트')) {
                      textColor = Colors.blue;
                      status = 'short';
                    }
                    if (value.contains('오픈')) {
                      textColor = Colors.red;
                      status = 'open';
                    }
                    
                    return InkWell(
                      onTap: () => _showCalculationDetail(context, channel, resistance, value, status),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 1, child: Text('$channel', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                            Expanded(flex: 2, child: Text('$resistance Ω', style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    value,
                                    style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400),
                                ],
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
          ],
        ),
      ),
    );
  }
  
  void _showCalculationDetail(BuildContext context, int channel, int resistance, String resultValue, String status) {
    // 캘리브레이션 데이터가 없으면 간단한 정보만 표시
    if (_calibrationData == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('CH $channel 결과', style: const TextStyle(fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('저항값: $resistance Ω'),
              const SizedBox(height: 8),
              Text('결과: $resultValue', style: TextStyle(
                fontWeight: FontWeight.bold,
                color: status == 'short' ? Colors.blue : (status == 'open' ? Colors.red : Colors.green),
              )),
              const SizedBox(height: 12),
              Text('캘리브레이션 데이터가 없어 계산 과정을 표시할 수 없습니다.', 
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
          ],
        ),
      );
      return;
    }
    
    // 채널 그룹에 따라 기울기/절편 선택
    final bool isChannel1to16 = channel <= 16;
    final slope = isChannel1to16 
        ? double.tryParse(_calibrationData!.combin1At1to16Inclin) ?? 0
        : double.tryParse(_calibrationData!.combin1At17to32Inclin) ?? 0;
    final intercept = isChannel1to16
        ? double.tryParse(_calibrationData!.combin1At1to16Cap) ?? 0
        : double.tryParse(_calibrationData!.combin1At17to32Cap) ?? 0;
    final minThreshold = isChannel1to16
        ? double.tryParse(_calibrationData!.combin1At1to16Min) ?? 0
        : double.tryParse(_calibrationData!.combin1At17to32Min) ?? 0;
    final maxThreshold = isChannel1to16
        ? double.tryParse(_calibrationData!.combin1At1to16Max) ?? 0
        : double.tryParse(_calibrationData!.combin1At17to32Max) ?? 0;
    
    // 결과값에서 숫자 추출 (역계산으로 rawValue 추정)
    double? displayedValue;
    double? estimatedRawValue;
    
    if (status == 'normal') {
      displayedValue = double.tryParse(resultValue);
      if (displayedValue != null && slope != 0) {
        estimatedRawValue = (displayedValue - intercept) / slope;
      }
    } else {
      // 쇼트/오픈의 경우 괄호 안의 값 추출
      final match = RegExp(r'\(([-\d.]+)\)').firstMatch(resultValue);
      if (match != null) {
        displayedValue = double.tryParse(match.group(1) ?? '');
        if (displayedValue != null && slope != 0) {
          estimatedRawValue = (displayedValue - intercept) / slope;
        }
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (status == 'short' ? Colors.blue : (status == 'open' ? Colors.red : Colors.green)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                status == 'short' ? Icons.link : (status == 'open' ? Icons.link_off : Icons.check_circle),
                color: status == 'short' ? Colors.blue : (status == 'open' ? Colors.red : Colors.green),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text('CH $channel 계산 상세', style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 기본 정보
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📍 채널 그룹: ${isChannel1to16 ? "1-16" : "17-32"}', style: const TextStyle(fontSize: 13)),
                    Text('📍 저항값: $resistance Ω', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 캘리브레이션 파라미터
              const Text('캘리브레이션 파라미터', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('기울기 (Slope): ${slope.toStringAsFixed(5)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    Text('절편 (Intercept): ${intercept.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    const Divider(height: 16),
                    Text('Min 임계값: ${minThreshold.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    Text('Max 임계값: ${maxThreshold.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 계산 과정
              const Text('계산 과정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (estimatedRawValue != null) ...[
                      Text('RawValue (추정): ${estimatedRawValue.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      const SizedBox(height: 8),
                      const Text('공식:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      Text('결과 = Slope × RawValue + Intercept', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey.shade700)),
                      const SizedBox(height: 4),
                      Text('     = ${slope.toStringAsFixed(5)} × ${estimatedRawValue.toStringAsFixed(2)} + ${intercept.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                      Text('     = ${displayedValue?.toStringAsFixed(2) ?? "N/A"}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold)),
                    ] else ...[
                      Text('계산 과정을 표시할 수 없습니다.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 상태 판정
              const Text('상태 판정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (status == 'short' ? Colors.blue : (status == 'open' ? Colors.red : Colors.green)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (status == 'short' ? Colors.blue : (status == 'open' ? Colors.red : Colors.green)).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (estimatedRawValue != null) ...[
                      if (status == 'short')
                        Text('${estimatedRawValue.toStringAsFixed(2)} < ${minThreshold.toStringAsFixed(2)} (Min)', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))
                      else if (status == 'open')
                        Text('${estimatedRawValue.toStringAsFixed(2)} > ${maxThreshold.toStringAsFixed(2)} (Max)', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))
                      else
                        Text('${minThreshold.toStringAsFixed(2)} ≤ ${estimatedRawValue.toStringAsFixed(2)} ≤ ${maxThreshold.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        const Text('결과: ', style: TextStyle(fontSize: 14)),
                        Text(
                          resultValue,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: status == 'short' ? Colors.blue : (status == 'open' ? Colors.red : Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
        ],
      ),
    );
  }
  
  Widget _buildFormulaTooltip(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.help_outline, color: Colors.grey.shade600, size: 22),
      tooltip: '계산 방법',
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.calculate, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text('결과값 계산 방법', style: TextStyle(fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFormulaSection(
                    '1. 캘리브레이션 (기울기/절편)',
                    [
                      'Slope = (R_Max - R_Min) / (Imp_Max - Imp_Min)',
                      'Intercept = R_Min - (Slope × Imp_Min)',
                    ],
                    'R: 저항값(Ω), Imp: 임피던스 Raw값',
                  ),
                  const Divider(height: 24),
                  _buildFormulaSection(
                    '2. 결과값 계산',
                    ['결과값(Ω) = Slope × RawValue + Intercept'],
                    'RawValue: BLE에서 받은 임피던스 raw 값',
                  ),
                  const Divider(height: 24),
                  _buildFormulaSection(
                    '3. 상태 판정',
                    [
                      '• 정상: Min ≤ RawValue ≤ Max',
                      '• 쇼트: RawValue < Min (전극 단락)',
                      '• 오픈: RawValue > Max (전극 개방)',
                    ],
                    'Min/Max: 캘리브레이션 시 선택한 포인트의 임피던스 값\n(해당 내부기 ID의 캘리브레이션 데이터에서 조회)',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildFormulaSection(String title, List<String> formulas, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: formulas.map((f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(f, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            )).toList(),
          ),
        ),
        const SizedBox(height: 4),
        Text(description, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}
