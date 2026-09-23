import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lensescan/config/theme.dart';
import 'package:lensescan/models/scan_result_model.dart';

void main() {
  group('LenseScan Core Tests', () {
    test('Theme contains expected light palette and primary color', () {
      expect(LenseScanTheme.surface, equals(const Color(0xFFF8F9FF)));
      expect(LenseScanTheme.primary, equals(const Color(0xFF003633)));
      expect(LenseScanTheme.primaryContainer, equals(const Color(0xFF134E4A)));
      expect(LenseScanTheme.secondary, equals(const Color(0xFF006C4A)));
      expect(LenseScanTheme.error, equals(const Color(0xFFBA1A1A)));
      expect(LenseScanTheme.warningAmber, equals(const Color(0xFFF59E0B)));
    });

    test('ScanResultModel JSON serialization parses properly', () {
      final json = {
        'scan_id': 'test-uuid-123',
        'timestamp': '2026-09-18T01:00:00Z',
        'image_filename': 'sample_label.jpg',
        'dpi_used': 300,
        'overall_compliant': true,
        'total_fields': 8,
        'compliant_fields': 8,
        'non_compliant_fields': 0,
        'declarations': [
          {
            'field_name': 'mrp',
            'display_name': 'Maximum Retail Price (MRP)',
            'detected': true,
            'value': 'Rs. 45.00',
            'compliant': true,
            'violations': [],
            'font_height_mm': 2.5,
            'required_font_height_mm': 2.0,
            'confidence': 0.95
          }
        ],
        'summary': 'All mandatory fields present'
      };

      final model = ScanResultModel.fromJson(json);
      expect(model.scanId, equals('test-uuid-123'));
      expect(model.overallCompliant, isTrue);
      expect(model.totalFields, equals(8));
      expect(model.compliantFields, equals(8));
      expect(model.nonCompliantFields, equals(0));
      expect(model.declarations.length, equals(1));
      expect(model.declarations.first.fieldName, equals('mrp'));
      expect(model.declarations.first.compliant, isTrue);
      expect(model.declarations.first.value, equals('Rs. 45.00'));
      expect(model.declarations.first.fontHeightMm, equals(2.5));
      expect(model.declarations.first.confidence, equals(0.95));
      expect(model.declarations.first.violations, isEmpty);
    });

    test('DeclarationFieldModel parses non-compliant field with violations', () {
      final json = {
        'field_name': 'net_qty',
        'display_name': 'Net Quantity',
        'detected': true,
        'value': '500 ml',
        'compliant': false,
        'violations': ['Font height 1.2mm is below required 2.0mm'],
        'font_height_mm': 1.2,
        'required_font_height_mm': 2.0,
        'confidence': 0.88
      };

      final field = DeclarationFieldModel.fromJson(json);
      expect(field.fieldName, equals('net_qty'));
      expect(field.compliant, isFalse);
      expect(field.violations.length, equals(1));
      expect(field.violations.first, contains('Font height 1.2mm'));
    });
  });
}
