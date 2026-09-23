/// Inspection History screen — browse past scans with search and filter.
///
/// Matches Stitch design: 6._inspection_history_screen/code.html
/// Search bar, 3 filter pills (All/Compliant/Flagged), date-grouped cards,
/// product name + time + single status badge per row.
library;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/theme.dart';
import '../core/api/api_endpoints.dart';
import '../core/api/dio_client.dart';
import '../core/utils/product_formatter.dart';

/// Inspection history screen for browsing past compliance checks.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _inspections = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // 'all', 'compliant', 'flagged'
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInspections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInspections() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      String endpoint = ApiEndpoints.inspections;
      if (_filter == 'compliant') {
        endpoint += '?compliant_only=true';
      } else if (_filter == 'flagged') {
        endpoint += '?compliant_only=false';
      }

      final response = await DioClient.instance.dio.get(endpoint);
      final data = response.data as List<dynamic>;
      setState(() {
        _inspections = data.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = e.response?.data?['detail'] ?? 'Failed to load inspections';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredInspections {
    if (_searchQuery.isEmpty) return _inspections;
    final q = _searchQuery.toLowerCase();
    return _inspections.where((insp) {
      final filename = (insp['image_filename'] as String? ?? '').toLowerCase();
      final formatted = formatProductName(filename).toLowerCase();
      return filename.contains(q) || formatted.contains(q);
    }).toList();
  }

  // Group inspections by date
  Map<String, List<Map<String, dynamic>>> get _groupedInspections {
    final result = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();

    for (final insp in _filteredInspections) {
      final createdAt = insp['created_at'] as String? ?? '';
      String group = 'Older';

      if (createdAt.isNotEmpty) {
        try {
          final dt = DateTime.parse(createdAt);
          final diff = now.difference(dt);
          if (diff.inDays == 0 && dt.day == now.day) {
            group = 'Today';
          } else if (diff.inDays <= 1 && dt.day == now.day - 1) {
            group = 'Yesterday';
          } else if (diff.inDays < 7) {
            group = 'This Week';
          } else {
            group = 'Older';
          }
        } catch (_) {}
      }

      result.putIfAbsent(group, () => []).add(insp);
    }

    return result;
  }

  int get _compliantCount =>
      _inspections.where((i) => i['overall_compliant'] == true).length;

  int get _flaggedCount =>
      _inspections.where((i) => i['overall_compliant'] != true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Inspection History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: LenseScanTheme.primary,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: LenseScanTheme.surfaceContainerHigh,
              child: Icon(
                Icons.person,
                size: 20,
                color: LenseScanTheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInspections,
        color: LenseScanTheme.secondary,
        child: Column(
          children: [
            // Search bar
            _buildSearchBar(),
            const SizedBox(height: 14),

            // Filter tabs
            _buildFilterTabs(),
            const SizedBox(height: 14),

            // Content
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: LenseScanTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: LenseScanTheme.outlineVariant.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search, size: 20, color: LenseScanTheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search scans...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: LenseScanTheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: LenseScanTheme.onSurface,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.close, size: 16,
                      color: LenseScanTheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterPill(
              'All (${_inspections.length})',
              'all',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterPill(
              'Compliant ($_compliantCount)',
              'compliant',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterPill(
              'Flagged ($_flaggedCount)',
              'flagged',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label, String filterValue) {
    final isActive = _filter == filterValue;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = filterValue);
        _loadInspections();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? LenseScanTheme.primary
              : LenseScanTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(9999),
          border: isActive
              ? null
              : Border.all(
                  color: LenseScanTheme.outlineVariant.withValues(alpha: 0.2),
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive
                ? LenseScanTheme.onPrimary
                : LenseScanTheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: LenseScanTheme.secondary,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48,
                  color: LenseScanTheme.error),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadInspections,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredInspections;
    if (filtered.isEmpty) {
      return _buildEmptyState();
    }

    final grouped = _groupedInspections;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        for (final entry in grouped.entries) ...[
          // Section header
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              entry.key.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.12,
                color: LenseScanTheme.onSurfaceVariant,
              ),
            ),
          ),
          // Cards
          ...entry.value.map((insp) => _buildInspectionCard(insp)),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: LenseScanTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: LenseScanTheme.outlineVariant.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LenseScanTheme.surfaceContainer,
              ),
              child: Icon(Icons.search_off, size: 28,
                  color: LenseScanTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Text(
              'No Scans Found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: LenseScanTheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching for a different product name or reset filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: LenseScanTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _filter = 'all';
                });
                _loadInspections();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectionCard(Map<String, dynamic> insp) {
    final isCompliant = insp['overall_compliant'] as bool? ?? false;
    final filename = insp['image_filename'] as String? ?? 'Unknown';
    final createdAt = insp['created_at'] as String? ?? '';

    // Format product name cleanly
    final displayName = formatProductName(filename, maxLength: 28);

    // Parse time
    String timeStr = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt);
        final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final amPm = dt.hour >= 12 ? 'PM' : 'AM';
        timeStr = '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $amPm';
      } catch (_) {}
    }

    // Status
    String statusLabel;
    Color statusBgColor;
    Color statusTextColor;

    // Check for review status
    final hasReview = insp['placement_review_required'] == true;

    if (isCompliant) {
      statusLabel = 'Compliant';
      statusBgColor = LenseScanTheme.secondaryContainer;
      statusTextColor = LenseScanTheme.onSecondaryContainer;
    } else if (hasReview) {
      statusLabel = 'Review';
      statusBgColor = LenseScanTheme.surfaceContainerHigh;
      statusTextColor = LenseScanTheme.primary;
    } else {
      statusLabel = 'Violation';
      statusBgColor = LenseScanTheme.errorContainer;
      statusTextColor = LenseScanTheme.onErrorContainer;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: LenseScanTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            context.push('/results', extra: insp);
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: LenseScanTheme.outlineVariant.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                // Product thumbnail placeholder
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: LenseScanTheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 24,
                    color: LenseScanTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 14),

                // Product name + time + status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: LenseScanTheme.onSurface,
                                letterSpacing: -0.085,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: LenseScanTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Chevron
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: LenseScanTheme.outlineVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
