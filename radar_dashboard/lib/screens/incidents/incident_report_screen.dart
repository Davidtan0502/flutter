import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Constants and Configuration
class IncidentReportConstants {
  static const Map<String, Color> colorScheme = {
    'primary': Color(0xFF2C5282),
    'primaryLight': Color(0xFFE1F5FF),
    'primaryDark': Color(0xFF1A365D),
    'secondary': Color(0xFF99CEFF),
    'success': Color(0xFF4CAF50),
    'warning': Color(0xFFFF9800),
    'error': Color(0xFFF44336),
    'info': Color(0xFF2196F3),
    'purple': Color(0xFF9C27B0),
  };

  static const List<String> statusOptions = [
    'pending',
    'in progress',
    'resolved',
    'under review',
    'declined'
  ];

  static const List<String> filterOptions = ['recent', 'all', 'spam'];

  // Add to IncidentReportConstants class
  static const List<String> spamPatterns = [
    'http://', 'https://', 'www.', '.com', 'buy now', 'click here',
    'make money', 'free money', 'urgent money', 'lottery', 'winner',
    'earn money', 'work from home', 'get rich', 'investment', 'bitcoin',
    'crypto', 'password', 'login', 'account', 'verify', 'congratulations'
  ];
// Add to IncidentReportConstants class
  static const List<String> suspiciousIncidentTypes = [
    'test', 'demo', 'sample', 'fake', 'spam', 'unknown', 'other', 'miscellaneous',
    'check', 'verify', 'trial', 'experiment', 'practice', 'dummy', 'bogus',
    // Common misspellings
    'tst', 'demoo', 'sampel', 'fak', 'spamm', 'unknow', 'misc', 'miscelaneous',
    'chek', 'verif', 'trail', 'expirement', 'practise', 'dumy', 'bogous',
    // Additional suspicious types
    'none', 'na', 'n/a', 'not sure', 'unspecified', 'random', 'anything',
    'whatever', 'something', 'anything else', 'test123', 'demo1', 'sample1'
  ];
}

// Enhanced Spam Detection Service
class SpamDetectionService {
  static final _spamPatterns = IncidentReportConstants.spamPatterns;
  static final _suspiciousTypes = IncidentReportConstants.suspiciousIncidentTypes;
  
  // Pre-compiled regex patterns for better performance
  static final _urlRegex = RegExp(r'((https?://|www\.)[^\s]+)');
  static final _specialCharRegex = RegExp(r'[!@#$%^&*(),?":{}|<>]');
  static final _misspellingPatterns = [
    RegExp(r't[e]?st'), // test, tst
    RegExp(r'dem[o]?o?'), // demo, demoo
    RegExp(r'samp[le]?l?'), // sample, sampel
    RegExp(r'fak[e]?'), // fake, fak
    RegExp(r'spam[m]?'), // spam, spamm
    RegExp(r'un[k]?now[n]?'), // unknown, unknow
    RegExp(r'misc[elaneous]?'), // miscellaneous, misc
    RegExp(r'ch[e]?ck'), // check, chek
    RegExp(r'verif[y]?'), // verify, verif
    RegExp(r'tr[i]?al'), // trial, trail
    RegExp(r'exp[e]?r[i]?ment'), // experiment, expirement
    RegExp(r'practic[e]?s?'), // practice, practise
    RegExp(r'dum[m]?y'), // dummy, dumy
    RegExp(r'bog[u]?s'), // bogus, bogous
  ];

  // Suspicious contact numbers
  static final _suspiciousContacts = {
    '0000000000', '1234567890', '1111111111', '0123456789',
    '9999999999', '5555555555', '4444444444', '6666666666'
  };

  // Suspicious names
  static final _suspiciousNames = {
    'test', 'demo', 'user', 'admin', 'unknown', 'anonymous', 
    'tester', 'guest', 'sample', 'fake', 'dummy'
  };

  // Suspicious locations
  static final _suspiciousLocations = {
    'test', 'demo', 'unknown', 'none', 'na', 'home', 'office', 
    'street', 'road', 'address', 'location'
  };

  static Future<SpamAnalysisResult> analyzeIncident(Map<String, dynamic> incidentData) async {
    final analysis = SpamAnalysisResult();
    final description = (incidentData['description'] ?? '').toString().toLowerCase();
    final contactNumber = (incidentData['contact_number'] ?? '').toString();
    final name = (incidentData['name'] ?? '').toString().toLowerCase();
    final incidentType = (incidentData['incident_type'] ?? '').toString().toLowerCase();
    final address = (incidentData['address'] ?? '').toString().toLowerCase();
    final landmark = (incidentData['landmark'] ?? '').toString().toLowerCase();

    // EMERGENCY-SAFE: Higher threshold for emergency contexts
    // Layer 1: High-confidence spam signals (immediate rejection)
    if (_hasHighConfidenceSpamSignals(description, contactNumber, incidentType)) {
      analysis.addReason('High-confidence spam signal detected', 10);
      return analysis; // Immediate classification as spam
    }

    // Layer 2: Content-based spam detection
    _analyzeContent(description, analysis);

    // Layer 3: Incident type analysis
    _analyzeIncidentType(incidentType, analysis);

    // Layer 4: Contact information analysis
    _analyzeContactInfo(contactNumber, name, analysis);

    // Layer 5: Behavioral analysis (frequency, timing)
    await _analyzeBehavior(incidentData, analysis);

    // Layer 6: Text pattern analysis
    _analyzeTextPatterns(description, analysis);

    // EMERGENCY-SAFE: Lower scores might still be legitimate emergencies
    // Only classify as spam if we have strong evidence
    return analysis;
  }

  static bool _hasHighConfidenceSpamSignals(String description, String contactNumber, String incidentType) {
    // Only classify as HIGH confidence spam if we have multiple strong signals
    int highConfidenceSignals = 0;
    
    // 1. Clear commercial spam with URLs
    final commercialPatterns = ['buy now', 'click here', 'make money', 'free money', 'earn money', 'work from home', 'get rich', 'investment'];
    for (final pattern in commercialPatterns) {
      if (description.contains(pattern)) {
        highConfidenceSignals++;
        break;
      }
    }
    
    // 2. Multiple spam keywords in description
    final spamKeywordsFound = SpamDetectionService._spamPatterns.where((pattern) => description.contains(pattern)).length;
    if (spamKeywordsFound >= 3) {
      highConfidenceSignals++;
    }
    
    // 3. Clearly fake contact information
    if (contactNumber.length < 5 || 
        ['0000000000', '1234567890', '1111111111'].contains(contactNumber)) {
      highConfidenceSignals++;
    }
    
    // 4. Test/demo incident types with suspicious content
    if (['test', 'demo', 'sample', 'fake'].contains(incidentType) && description.length < 20) {
      highConfidenceSignals++;
    }
    
    // Require at least 2 high-confidence signals to avoid false positives
    return highConfidenceSignals >= 2;
  }

  static void _analyzeContent(String description, SpamAnalysisResult analysis) {
    // Check for spam patterns
    for (final pattern in _spamPatterns) {
      if (description.contains(pattern)) {
        analysis.addReason('Contains spam keyword: "$pattern"', 2); // Reduced from 3 to 2
        break;
      }
    }

    // URL detection
    if (_urlRegex.hasMatch(description)) {
      analysis.addReason('Contains URLs/links', 2); // Reduced from 3 to 2
    }

    // Description length analysis
    if (description.length < 10) {
      analysis.addReason('Very short description', 1);
    } else if (description.length > 500) {
      analysis.addReason('Excessively long description', 1);
    }
  }

  static void _analyzeIncidentType(String incidentType, SpamAnalysisResult analysis) {
    if (incidentType.isEmpty) {
      analysis.addReason('Empty incident type', 2);
      return;
    }

    // Direct suspicious type match
    for (final suspiciousType in _suspiciousTypes) {
      if (incidentType.contains(suspiciousType)) {
        analysis.addReason('Suspicious incident type: "$suspiciousType"', 2); // Reduced from 3 to 2
        return;
      }
    }

    // Fuzzy matching for misspelled types
    for (final pattern in _misspellingPatterns) {
      if (pattern.hasMatch(incidentType)) {
        analysis.addReason('Misspelled suspicious incident type: "$incidentType"', 1); // Reduced from 2 to 1
        return;
      }
    }
  }

  static void _analyzeContactInfo(String contactNumber, String name, SpamAnalysisResult analysis) {
    // Contact number analysis
    if (contactNumber.length < 5) {
      analysis.addReason('Invalid contact number (too short)', 2); // Reduced from 3 to 2
    } else if (_suspiciousContacts.contains(contactNumber)) {
      analysis.addReason('Suspicious contact number', 2); // Reduced from 3 to 2
    } else if (contactNumber.contains('123') && contactNumber.length <= 6) {
      analysis.addReason('Pattern-based suspicious contact number', 1); // Reduced from 2 to 1
    }

    // Name analysis
    if (_suspiciousNames.contains(name)) {
      analysis.addReason('Suspicious name: "$name"', 1); // Reduced from 2 to 1
    }
  }

  static void _analyzeLocation(String address, String landmark, SpamAnalysisResult analysis) {
    for (final suspiciousLocation in _suspiciousLocations) {
      if (address.contains(suspiciousLocation) || landmark.contains(suspiciousLocation)) {
        analysis.addReason('Suspicious location/landmark', 1);
        break;
      }
    }
  }

  static Future<void> _analyzeBehavior(Map<String, dynamic> incidentData, SpamAnalysisResult analysis) async {
    try {
      final supabase = Supabase.instance.client;
      final contactNumber = incidentData['contact_number']?.toString();
      
      if (contactNumber == null || contactNumber.isEmpty) return;

      // Check for recent incidents from same contact
      final recentIncidents = await supabase
          .from('incidents')
          .select()
          .eq('contact_number', contactNumber)
          .gte('created_at', 
              DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String())
          .limit(5);

      if (recentIncidents.length >= 3) {
        analysis.addReason('Multiple reports from same number in 30 minutes (${recentIncidents.length})', 2); // Reduced from 3 to 2
      }

      // Check for similar content
      final description = (incidentData['description'] ?? '').toString();
      if (description.length > 20) {
        final similarIncidents = await supabase
            .from('incidents')
            .select()
            .ilike('description', '%${description.substring(0, 20)}%')
            .gte('created_at', 
                DateTime.now().subtract(const Duration(hours: 1)).toIso8601String())
            .limit(3);

        if (similarIncidents.length >= 2) {
          analysis.addReason('Similar descriptions reported recently', 2); // Reduced from 3 to 2
        }
      }
    } catch (e) {
      debugPrint('Behavioral analysis error: $e');
    }
  }

  static void _analyzeTextPatterns(String description, SpamAnalysisResult analysis) {
    if (description.isEmpty) return;

    // Repetition analysis
    final words = description.split(' ');
    final uniqueWords = Set<String>.from(words);
    final repetitionRatio = uniqueWords.length / (words.length > 0 ? words.length : 1);
    if (repetitionRatio < 0.3 && words.length > 20) {
      analysis.addReason('High content repetition detected', 1); // Reduced from 2 to 1
    }

    // Special character analysis
    final specialCharCount = _specialCharRegex.allMatches(description).length;
    if (specialCharCount > 10) {
      analysis.addReason('Excessive special characters', 1);
    }

    // ALL CAPS detection
    final upperCaseRatio = description.replaceAll(RegExp(r'[^A-Z]'), '').length / 
                          (description.length > 0 ? description.length : 1);
    if (upperCaseRatio > 0.7 && description.length > 20) {
      analysis.addReason('Excessive uppercase text', 1);
    }
  }
}

// Spam Analysis Result Class
class SpamAnalysisResult {
  int score = 0;
  List<String> reasons = [];
  bool get isSpam => score >= 8; // Higher threshold for emergencies

  void addReason(String reason, int points) {
    reasons.add(reason);
    score += points;
  }

  @override
  String toString() {
    return 'SpamAnalysisResult(score: $score, isSpam: $isSpam, reasons: $reasons)';
  }
}

class IncidentData {
  final String id;
  final String? incidentType;
  final String? address;
  final String? landmark;
  final String? name;
  final String? contactNumber;
  final String? description;
  final String status;
  final DateTime? timestamp;
  final List<dynamic> imageUrls;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? latestStatus;
  final DateTime? statusUpdatedAt;
  final bool? isSpam; // ADD THIS
  final int? spamScore; // ADD THIS
  final List<dynamic>? spamReasons; // ADD THIS

  IncidentData({
    required this.id,
    required this.incidentType,
    required this.address,
    required this.landmark,
    required this.name,
    required this.contactNumber,
    required this.description,
    required this.status,
    required this.timestamp,
    required this.imageUrls,
    this.createdAt,
    this.updatedAt,
    this.latestStatus,
    this.statusUpdatedAt,
    this.isSpam, // ADD THIS
    this.spamScore, // ADD THIS
    this.spamReasons, // ADD THIS
  });

  factory IncidentData.fromMap(Map<String, dynamic> data, String id) {
    return IncidentData(
      id: id,
      incidentType: data['incident_type']?.toString(),
      address: data['address']?.toString(),
      landmark: data['landmark']?.toString(),
      name: data['name']?.toString(),
      contactNumber: data['contact_number']?.toString(),
      description: data['description']?.toString(),
      status: (data['latest_status'] ?? data['status'] ?? 'pending').toString(),
      timestamp: data['timestamp'] != null 
          ? DateTime.parse(data['timestamp'])
          : null,
      imageUrls: data['image_urls'] as List<dynamic>? ?? [],
      createdAt: data['created_at'] != null 
          ? DateTime.parse(data['created_at'])
          : null,
      updatedAt: data['updated_at'] != null 
          ? DateTime.parse(data['updated_at'])
          : null,
      latestStatus: data['latest_status']?.toString(),
      statusUpdatedAt: data['status_updated_at'] != null 
          ? DateTime.parse(data['status_updated_at'])
          : null,
      isSpam: data['is_spam'] as bool? ?? false, // ADD THIS
      spamScore: data['spam_score'] as int? ?? 0, // ADD THIS
      spamReasons: data['spam_reasons'] as List<dynamic>? ?? [], // ADD THIS
    );
  }

  String get effectiveStatus => latestStatus ?? status;
}

class StatusUpdate {
  final String id;
  final String incidentId;
  final String status;
  final String note;
  final String updatedBy;
  final DateTime createdAt;

  StatusUpdate({
    required this.id,
    required this.incidentId,
    required this.status,
    required this.note,
    required this.updatedBy,
    required this.createdAt,
  });

  factory StatusUpdate.fromMap(Map<String, dynamic> data) {
    return StatusUpdate(
      id: data['id'].toString(),
      incidentId: data['incident_id'].toString(),
      status: data['status'].toString(),
      note: data['note']?.toString() ?? '',
      updatedBy: data['updated_by'].toString(),
      createdAt: DateTime.parse(data['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'incident_id': incidentId,
      'status': status,
      'note': note,
      'updated_by': updatedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Service Classes
class IncidentService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<void> createInitialIncident(
    Map<String, dynamic> incidentData,
  ) async {
    try {
      // Insert the main incident record
      final response = await _supabase
          .from('incidents')
          .insert(incidentData)
          .select();
      
      if (response.isNotEmpty) {
        final incidentId = response.first['id'].toString();
        
        // Create initial status update record for 'pending'
        await _supabase
            .from('incident_status_updates')
            .insert({
              'incident_id': incidentId,
              'status': 'pending',
              'note': 'Incident reported',
              'updated_by': incidentData['name'] ?? 'Anonymous',
              'created_at': DateTime.now().toIso8601String(),
            });
      }
    } catch (e) {
      throw Exception('Failed to create incident: $e');
    }
  }

  // Enhanced Spam Detection Methods
  static Future<bool> isSpamIncident(Map<String, dynamic> incidentData) async {
    try {
      final analysis = await SpamDetectionService.analyzeIncident(incidentData);
      
      // HIGHER THRESHOLD FOR EMERGENCY CONTEXTS
      // Only classify as spam if we have very strong evidence
      final bool isSpam = analysis.score >= 8; // Increased from 5 to 8 for emergencies
      
      if (isSpam) {
        debugPrint('🚫 SPAM DETECTED - Score: ${analysis.score} (Threshold: 8)');
        debugPrint('   Reasons: ${analysis.reasons.join(", ")}');
        debugPrint('   Contact: ${incidentData['contact_number']}, Type: ${incidentData['incident_type']}');
        
        // Log spam attempt for future analysis
        await _logSpamAttempt(incidentData, analysis);
        return true;
      } else if (analysis.score >= 5) {
        // SUSPICIOUS but not definite spam - log for review but don't block
        debugPrint('⚠️ SUSPICIOUS INCIDENT - Score: ${analysis.score}');
        debugPrint('   Reasons: ${analysis.reasons.join(", ")}');
        await _logSuspiciousIncident(incidentData, analysis);
      }
      
      return false;
    } catch (e) {
      debugPrint('Spam check error: $e');
      return false; // Default to not spam if check fails - SAFER FOR EMERGENCIES
    }
  }

  static Future<void> _logSuspiciousIncident(Map<String, dynamic> incidentData, SpamAnalysisResult analysis) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('suspicious_incidents').insert({
        'contact_number': incidentData['contact_number'],
        'incident_type': incidentData['incident_type'],
        'description_preview': (incidentData['description']?.toString() ?? '').substring(0, 100),
        'spam_score': analysis.score,
        'reasons': analysis.reasons.join('; '),
        'created_at': DateTime.now().toIso8601String(),
        'status': 'review_needed', // Mark for moderator review
      });
    } catch (e) {
      debugPrint('Failed to log suspicious incident: $e');
    }
  }

  static Future<void> _logSpamAttempt(Map<String, dynamic> incidentData, SpamAnalysisResult analysis) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('spam_attempts').insert({
        'contact_number': incidentData['contact_number'],
        'incident_type': incidentData['incident_type'],
        'description_length': (incidentData['description']?.toString() ?? '').length,
        'spam_score': analysis.score,
        'reasons': analysis.reasons.join('; '),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to log spam attempt: $e');
    }
  }

  static Future<void> createInitialIncidentWithSpamCheck(
    Map<String, dynamic> incidentData,
  ) async {
    try {
      // Check for spam before creating incident
      final isSpam = await isSpamIncident(incidentData);
      
      if (isSpam) {
        // Log spam attempt but don't create incident
        debugPrint('🚫 Spam incident blocked: ${incidentData['contact_number']}');
        throw Exception('This incident appears to be spam and cannot be submitted.');
      }

      // Proceed with normal incident creation if not spam
      await createInitialIncident(incidentData);
    } catch (e) {
      rethrow;
    }
  }

  static Stream<List<Map<String, dynamic>>> getIncidentsStream() {
    return _supabase
        .from('incidents')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false);
  }

  static Stream<List<Map<String, dynamic>>> getStatusUpdatesStream() {
    return _supabase
        .from('incident_status_updates')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  static Future<void> deleteIncident(String id) async {
    await _supabase
        .from('incidents')
        .delete()
        .eq('id', id);
  }

  static Future<List<StatusUpdate>> getStatusUpdates(String incidentId) async {
    final response = await _supabase
        .from('incident_status_updates')
        .select()
        .eq('incident_id', incidentId)
        .order('created_at', ascending: true);

    return (response as List).map((update) => StatusUpdate.fromMap(update)).toList();
  }

  static Future<void> updateIncidentStatus(
    String id, {
    required String status,
    required String note,
    required String updatedBy,
  }) async {
    try {
      // Update incident status
      await _supabase
          .from('incidents')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      // Create status update record
      await _supabase
          .from('incident_status_updates')
          .insert({
            'incident_id': id,
            'status': status,
            'note': note,
            'updated_by': updatedBy,
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      throw Exception('Failed to update incident status: $e');
    }
  }

  static Future<void> batchUpdateStatus(
    List<String> ids,
    String status,
  ) async {
    try {
      for (final id in ids) {
        // Update incident status
        await _supabase
            .from('incidents')
            .update({
              'status': status,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id);

        // Create status update record
        await _supabase
            .from('incident_status_updates')
            .insert({
              'incident_id': id,
              'status': status,
              'note': 'Bulk status update',
              'updated_by': 'moderator',
              'created_at': DateTime.now().toIso8601String(),
            });
      }
    } catch (e) {
      throw Exception('Failed to batch update status: $e');
    }
  }

  static Future<void> batchDeleteIncidents(List<String> ids) async {
    try {
      for (final id in ids) {
        await _supabase
            .from('incidents')
            .delete()
            .eq('id', id);
      }
    } catch (e) {
      throw Exception('Failed to batch delete incidents: $e');
    }
  }
}

class StyleService {
  static Map<String, dynamic> getStatusStyle(String status) {
    final statusLower = status.toLowerCase();
    final colors = IncidentReportConstants.colorScheme;

    final Map<String, Map<String, dynamic>> styles = {
      'resolved': {
        'color': colors['success']!,
        'icon': Icons.check_circle_rounded,
        'bgColor': colors['success']!.withOpacity(0.1),
        'label': 'Resolved',
      },
      'in progress': {
        'color': colors['info']!,
        'icon': Icons.autorenew_rounded,
        'bgColor': colors['info']!.withOpacity(0.1),
        'label': 'In Progress',
      },
      'pending': {
        'color': colors['warning']!,
        'icon': Icons.access_time_rounded,
        'bgColor': colors['warning']!.withOpacity(0.1),
        'label': 'Pending',
      },
      'under review': {
        'color': colors['purple']!,
        'icon': Icons.visibility_rounded,
        'bgColor': colors['purple']!.withOpacity(0.1),
        'label': 'Under Review',
      },
      'declined': {
        'color': colors['error']!,
        'icon': Icons.cancel_rounded,
        'bgColor': colors['error']!.withOpacity(0.1),
        'label': 'Declined',
      },
    };

    return styles[statusLower] ?? {
      'color': Colors.grey,
      'icon': Icons.help_outline_rounded,
      'bgColor': Colors.grey.withOpacity(0.1),
      'label': 'Unknown',
    };
  }

  static Map<String, dynamic> getIncidentStyle(String? incidentType) {
    final typeLower = incidentType?.toLowerCase() ?? 'unknown';
    final colors = IncidentReportConstants.colorScheme;

    final Map<String, Map<String, dynamic>> styles = {
      'fire': {
        'color': colors['error']!,
        'icon': Icons.local_fire_department_rounded,
        'gradient': LinearGradient(
          colors: [colors['error']!, const Color(0xFFFF6B35)],
        ),
      },
      'accident': {
        'color': colors['warning']!,
        'icon': Icons.car_crash_rounded,
        'gradient': LinearGradient(
          colors: [colors['warning']!, const Color(0xFFFFB74D)],
        ),
      },
      'flood': {
        'color': colors['info']!,
        'icon': Icons.water_damage_rounded,
        'gradient': LinearGradient(
          colors: [colors['info']!, const Color(0xFF4FC3F7)],
        ),
      },
      'medical': {
        'color': const Color(0xFFE91E63),
        'icon': Icons.medical_services_rounded,
        'gradient': LinearGradient(
          colors: [const Color(0xFFE91E63), const Color(0xFFF48FB1)],
        ),
      },
      'crime': {
        'color': colors['purple']!,
        'icon': Icons.security_rounded,
        'gradient': LinearGradient(
          colors: [colors['purple']!, const Color(0xFFCE93D8)],
        ),
      },
    };

    return styles[typeLower] ?? {
      'color': Colors.grey,
      'icon': Icons.warning_rounded,
      'gradient': LinearGradient(
        colors: [Colors.grey, Colors.grey.shade400],
      ),
    };
  }
}

class IncidentReportScreen extends StatefulWidget {
  final VoidCallback onMenuPressed;
  final String userRole;

  const IncidentReportScreen({
    super.key,
    required this.onMenuPressed,
    required this.userRole,
  });

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _selectedIncidents = [];
  final Map<String, Map<String, dynamic>> _incidentsMap = {};
  final StreamController<List<Map<String, dynamic>>> _incidentsController = 
      StreamController<List<Map<String, dynamic>>>.broadcast();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  String _searchQuery = '';
  String _selectedFilter = 'recent';
  DateTime? _selectedDate;
  bool _isMultiSelectMode = false;
  bool _hasNewUpdates = false;
  DateTimeRange? _selectedDateRange;

  StreamSubscription? _incidentsSubscription;
  StreamSubscription? _statusUpdatesSubscription;

  // Add these new variables
  bool _isInitialLoad = true;
  bool _hasReceivedData = false;
  DateTime? _lastDataReceivedTime;
  Timer? _initialLoadTimer;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupAnimations();
    _setupRealTimeSubscriptions();
    
    // Set a timeout for initial load
    _initialLoadTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _isInitialLoad) {
        setState(() {
          _isInitialLoad = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _initialLoadTimer?.cancel();
    _disposeControllers();
    super.dispose();
  }

  void _initializeControllers() {
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutQuart,
    );
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  void _setupRealTimeSubscriptions() {
    _setupIncidentsSubscription();
    _setupStatusUpdatesSubscription();
  }

  void _setupIncidentsSubscription() {
    _incidentsSubscription?.cancel();
    
    _incidentsSubscription = IncidentService.getIncidentsStream()
        .handleError((error) {
      debugPrint('❌ Incidents stream error: $error');
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
          _hasReceivedData = false;
        });
        _incidentsController.add([]); // Add empty data to show empty state
      }
    }).listen(_handleIncidentsUpdate, cancelOnError: false);
  }

  void _setupStatusUpdatesSubscription() {
    _statusUpdatesSubscription?.cancel();
    
    _statusUpdatesSubscription = IncidentService.getStatusUpdatesStream()
        .handleError((error) {
      debugPrint('❌ Status updates stream error: $error');
      // Reconnect after delay with exponential backoff
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _setupStatusUpdatesSubscription();
      });
    }).listen(_handleStatusUpdates, cancelOnError: false);
  }

  void _handleIncidentsUpdate(List<Map<String, dynamic>> incidents) {
    debugPrint('🔄 Received ${incidents.length} incidents from stream');
    
    // Mark that we've received data
    if (mounted) {
      setState(() {
        _isInitialLoad = false;
        _hasReceivedData = true;
        _lastDataReceivedTime = DateTime.now();
      });
    }
    
    bool hasChanges = false;
    
    // Handle empty data case
    if (incidents.isEmpty) {
      if (_incidentsMap.isNotEmpty) {
        _incidentsMap.clear();
        hasChanges = true;
        debugPrint('📭 All incidents cleared - no data received');
      } else if (_hasReceivedData) {
        // Only log if we previously had data
        debugPrint('📭 Stream returned empty data');
      }
    } else {
      // Process incidents as before
      for (final incident in incidents) {
        final eventType = incident['type'] as String?;
        final newData = incident['new'] as Map<String, dynamic>?;
        final oldData = incident['old'] as Map<String, dynamic>?;

        switch (eventType) {
          case 'INSERT':
            if (newData != null) {
              final id = newData['id'].toString();
              _incidentsMap[id] = newData;
              hasChanges = true;
              _hasNewUpdates = true;
              debugPrint('➕ New incident: $id');
            }
            break;
          case 'UPDATE':
            if (newData != null) {
              final id = newData['id'].toString();
              _incidentsMap[id] = {
                ..._incidentsMap[id] ?? {},
                ...newData,
              };
              hasChanges = true;
              debugPrint('✏️ Updated incident: $id');
            }
            break;
          case 'DELETE':
            if (oldData != null) {
              final id = oldData['id'].toString();
              _incidentsMap.remove(id);
              hasChanges = true;
              debugPrint('🗑️ Deleted incident: $id');
              
              if (_selectedIncidents.contains(id)) {
                _selectedIncidents.remove(id);
              }
            }
            break;
          default:
            // Handle initial data load
            final id = incident['id'].toString();
            if (!_incidentsMap.containsKey(id)) {
              _incidentsMap[id] = incident;
              hasChanges = true;
            }
        }
      }
    }

    if (hasChanges && mounted) {
      _notifyDataUpdate();
      debugPrint('📊 Total incidents in map: ${_incidentsMap.length}');
      
      if (_selectedIncidents.isEmpty && _isMultiSelectMode) {
        setState(() {
          _isMultiSelectMode = false;
        });
      }
    }
  }

  void _handleStatusUpdates(List<Map<String, dynamic>> statusUpdates) {
    debugPrint('🔄 Received ${statusUpdates.length} status updates from stream');
    
    bool hasChanges = false;
    
    for (final update in statusUpdates) {
      final eventType = update['type'] as String?;
      final newData = update['new'] as Map<String, dynamic>?;
      
      if (eventType == 'INSERT' && newData != null) {
        final incidentId = newData['incident_id'].toString();
        final status = newData['status'].toString();
        final timestamp = newData['created_at'] as String?;
        
        if (_incidentsMap.containsKey(incidentId)) {
          // Update the incident with latest status
          _incidentsMap[incidentId] = {
            ..._incidentsMap[incidentId]!,
            'latest_status': status,
            'status_updated_at': timestamp,
          };
          hasChanges = true;
          debugPrint('🔄 Status updated for incident $incidentId: $status');
        }
      }
    }
    
    if (hasChanges && mounted) {
      _notifyDataUpdate();
    }
  }

  void _notifyDataUpdate() {
    final incidentsList = _incidentsMap.values.toList();
    // Sort by timestamp (newest first)
    incidentsList.sort((a, b) {
      final timeA = _safeParseDateTime(a['timestamp']);
      final timeB = _safeParseDateTime(b['timestamp']);
      if (timeA == null || timeB == null) return 0;
      return timeB.compareTo(timeA);
    });
    
    _incidentsController.add(incidentsList);
    setState(() {});
  }

  DateTime? _safeParseDateTime(dynamic timestamp) {
    if (timestamp == null) return null;
    
    try {
      if (timestamp is DateTime) return timestamp;
      if (timestamp is String) return DateTime.parse(timestamp);
      if (timestamp is int) return DateTime.fromMillisecondsSinceEpoch(timestamp);
      return null;
    } catch (e) {
      debugPrint('Error parsing timestamp: $e');
      return null;
    }
  }

  void _disposeControllers() {
    _searchController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    _incidentsSubscription?.cancel();
    _statusUpdatesSubscription?.cancel();
    _incidentsController.close();
  }

  // Selection Management
  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) _selectedIncidents.clear();
    });
  }

  void _selectIncident(String id) {
    setState(() {
      if (_selectedIncidents.contains(id)) {
        _selectedIncidents.remove(id);
      } else {
        _selectedIncidents.add(id);
      }
      if (_selectedIncidents.isEmpty) _isMultiSelectMode = false;
    });
  }

  void _selectAllIncidents() {
    final currentIncidents = _getCurrentIncidentsList();
    setState(() {
      if (_selectedIncidents.length == currentIncidents.length) {
        _selectedIncidents.clear();
        _isMultiSelectMode = false;
      } else {
        _selectedIncidents.clear();
        _selectedIncidents.addAll(currentIncidents.map((doc) => doc['id'].toString()));
        _isMultiSelectMode = true;
      }
    });
  }

  List<Map<String, dynamic>> _getCurrentIncidentsList() {
    return _incidentsMap.values.toList();
  }

  // Delete Operations
  Future<void> _deleteIncident(String id, {bool showUndo = true}) async {
    try {
      // Store the incident data for potential undo BEFORE deleting
      final incidentData = _incidentsMap[id]?.cast<String, dynamic>();
      
      // Delete from database first
      await IncidentService.deleteIncident(id);
      
      // The real-time subscription will automatically remove it from _incidentsMap
      // and trigger a UI update via _handleIncidentsUpdate
      
      if (showUndo && mounted && incidentData != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Incident deleted'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () => _undoDelete(id, incidentData),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Fix the _undoDelete method
  Future<void> _undoDelete(String id, Map<String, dynamic> data) async {
    try {
      // Re-insert the incident with its original data
      await Supabase.instance.client
          .from('incidents')
          .insert(data);
      
      // The real-time subscription will automatically add it back to _incidentsMap
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident restored'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Batch Operations
  Future<void> _batchUpdateStatus(String status) async {
    if (_selectedIncidents.isEmpty) return;

    final confirmed = await _showConfirmationDialog(
      title: 'Confirm Batch Update',
      content:
          'Update ${_selectedIncidents.length} incidents to "${StyleService.getStatusStyle(status)['label']}"?',
      confirmColor: StyleService.getStatusStyle(status)['color'] as Color,
    );

    if (confirmed != true) return;

    try {
      await IncidentService.batchUpdateStatus(_selectedIncidents, status);
      _showSuccessSnackbar(
          'Updated ${_selectedIncidents.length} incidents to ${StyleService.getStatusStyle(status)['label']}');
      _clearSelection();
    } catch (e) {
      _showErrorSnackbar('Failed to update: $e');
    }
  }

  Future<void> _showBatchDeleteConfirmation() async {
    final confirmed = await _showConfirmationDialog(
      title: 'Confirm Batch Delete',
      content:
          'Are you sure you want to delete ${_selectedIncidents.length} incidents? This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: IncidentReportConstants.colorScheme['error']!,
    );

    if (confirmed != true) return;

    // Store incidents data for undo BEFORE deleting
    final incidentsToDelete = <String, Map<String, dynamic>>{};
    for (final id in _selectedIncidents) {
      final incidentData = _incidentsMap[id]?.cast<String, dynamic>();
      if (incidentData != null) {
        incidentsToDelete[id] = incidentData;
      }
    }

    try {
      await IncidentService.batchDeleteIncidents(_selectedIncidents);
      
      // The real-time subscriptions will automatically update the UI

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted ${_selectedIncidents.length} incidents'),
            backgroundColor: IncidentReportConstants.colorScheme['error'],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () => _undoBatchDelete(incidentsToDelete),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }

      _clearSelection();
    } catch (e) {
      _showErrorSnackbar('Failed to delete: $e');
    }
  }

  Future<void> _undoBatchDelete(Map<String, Map<String, dynamic>> incidents) async {
    if (incidents.isEmpty) return;

    try {
      // Re-insert all incidents
      for (final entry in incidents.entries) {
        await Supabase.instance.client
            .from('incidents')
            .insert(entry.value);
      }
      
      // The real-time subscriptions will automatically update the UI

      if (mounted) {
        _showSuccessSnackbar('Incidents restored');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to restore: $e');
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedIncidents.clear();
      _isMultiSelectMode = false;
    });
  }

  // Quick spam analysis for filtering (optimized performance)
  SpamAnalysisResult _performQuickSpamAnalysis(Map<String, dynamic> doc) {
    final analysis = SpamAnalysisResult();
    final description = (doc['description'] ?? '').toString().toLowerCase();
    final contactNumber = (doc['contact_number'] ?? '').toString();
    final name = (doc['name'] ?? '').toString().toLowerCase();
    final incidentType = (doc['incident_type'] ?? '').toString().toLowerCase();
    
    // Quick content check
    for (final pattern in SpamDetectionService._spamPatterns.take(10)) { // Check first 10 patterns
      if (description.contains(pattern)) {
        analysis.addReason('Spam keyword: "$pattern"', 2);
        break;
      }
    }
    
    // Quick incident type check
    for (final suspiciousType in SpamDetectionService._suspiciousTypes.take(10)) {
      if (incidentType.contains(suspiciousType)) {
        analysis.addReason('Suspicious type: "$suspiciousType"', 2);
        break;
      }
    }
    
    // Quick contact check
    if (contactNumber.length < 5 || SpamDetectionService._suspiciousContacts.contains(contactNumber)) {
      analysis.addReason('Suspicious contact', 2);
    }
    
    // Quick name check
    if (SpamDetectionService._suspiciousNames.contains(name)) {
      analysis.addReason('Suspicious name', 1);
    }
    
    return analysis;
  }

  // Comprehensive spam analysis for existing incidents (more thorough than quick analysis)
  SpamAnalysisResult _performComprehensiveSpamAnalysis(Map<String, dynamic> doc) {
    final analysis = SpamAnalysisResult();
    final description = (doc['description'] ?? '').toString().toLowerCase();
    final contactNumber = (doc['contact_number'] ?? '').toString();
    final name = (doc['name'] ?? '').toString().toLowerCase();
    final incidentType = (doc['incident_type'] ?? '').toString().toLowerCase();
    final address = (doc['address'] ?? '').toString().toLowerCase();
    final landmark = (doc['landmark'] ?? '').toString().toLowerCase();

    // Check all spam patterns (not just first 10)
    for (final pattern in SpamDetectionService._spamPatterns) {
      if (description.contains(pattern)) {
        analysis.addReason('Spam keyword: "$pattern"', 2); // Lower score for existing incidents
        break;
      }
    }

    // Check all suspicious types
    for (final suspiciousType in SpamDetectionService._suspiciousTypes) {
      if (incidentType.contains(suspiciousType)) {
        analysis.addReason('Suspicious type: "$suspiciousType"', 2);
        break;
      }
    }

    // Contact checks
    if (contactNumber.length < 5) {
      analysis.addReason('Invalid contact number', 2);
    }
    if (SpamDetectionService._suspiciousContacts.contains(contactNumber)) {
      analysis.addReason('Suspicious contact number', 2);
    }

    // Name checks
    if (SpamDetectionService._suspiciousNames.contains(name)) {
      analysis.addReason('Suspicious name', 1);
    }

    // Location checks
    for (final suspiciousLocation in SpamDetectionService._suspiciousLocations) {
      if (address.contains(suspiciousLocation) || landmark.contains(suspiciousLocation)) {
        analysis.addReason('Suspicious location', 1);
        break;
      }
    }

    // Content quality checks
    if (description.length < 10) {
      analysis.addReason('Very short description', 1);
    }
    if (description.length > 1000) {
      analysis.addReason('Excessively long description', 1);
    }

    return analysis;
  }

  // UI Components
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              IncidentReportConstants.colorScheme['primaryLight']!,
              IncidentReportConstants.colorScheme['secondary']!
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchBar(),
              const SizedBox(height: 20),
              _buildFilterSection(),
              const SizedBox(height: 20),
              if (_isMultiSelectMode) _buildBatchActions(),
              if (_isMultiSelectMode) const SizedBox(height: 20),
              const SizedBox(height: 8),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildEmergencyList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu_rounded, color: Colors.white),
        onPressed: widget.onMenuPressed,
      ),
      title: const Text(
        'EMERGENCY INCIDENT REPORT',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      backgroundColor: IncidentReportConstants.colorScheme['primary'],
      elevation: 8,
      centerTitle: true,
      actions: [
        if (widget.userRole == 'moderator')
          IconButton(
            icon: Icon(
              _isMultiSelectMode ? Icons.cancel_rounded : Icons.select_all_rounded,
              color: Colors.white,
            ),
            onPressed: _toggleMultiSelectMode,
            tooltip: _isMultiSelectMode ? 'Cancel selection' : 'Select multiple',
          ),
        if (_hasNewUpdates)
          IconButton(
            icon: Badge(
              backgroundColor: Colors.amber,
              child: const Icon(Icons.new_releases_rounded, color: Colors.white),
            ),
            onPressed: _refreshData,
            tooltip: 'New updates available',
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Hero(
      tag: 'search_bar',
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(25),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search incidents by location, landmark or type...',
            prefixIcon:
                Icon(Icons.search_rounded, color: IncidentReportConstants.colorScheme['primary']),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: IncidentReportConstants.colorScheme['primary']),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip(
              label: 'Recent',
              selected: _selectedFilter == 'recent',
              onSelected: () => setState(() {
                _selectedFilter = 'recent';
                _selectedDate = null;
              }),
            ),
            _buildFilterChip(
              label: 'All Reports',
              selected: _selectedFilter == 'all',
              onSelected: () => setState(() => _selectedFilter = 'all'),
            ),
            _buildFilterChip(
              label: 'Spam Reports',
              selected: _selectedFilter == 'spam',
              onSelected: () => setState(() {
                _selectedFilter = 'spam';
                _selectedDate = null;
              }),
            ),
            if (_selectedFilter == 'all')
              _buildDateFilterChip(),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: IncidentReportConstants.colorScheme['primary'],
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildDateFilterChip() {
    final isSingleDateSelected = _selectedDate != null;
    final isRangeSelected = _selectedDateRange != null;
    final isAnyDateSelected = isSingleDateSelected || isRangeSelected;
    
    String getDateLabel() {
      if (isRangeSelected) {
        final start = DateFormat('MMM d').format(_selectedDateRange!.start);
        final end = DateFormat('MMM d').format(_selectedDateRange!.end);
        return '$start - $end';
      } else if (isSingleDateSelected) {
        return DateFormat('MMM d').format(_selectedDate!);
      } else {
        return "Date Range";
      }
    }

    return FilterChip(
      label: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAnyDateSelected ? Icons.calendar_month_rounded : Icons.calendar_today_rounded,
              size: 16,
              color: isAnyDateSelected ? Colors.white : IncidentReportConstants.colorScheme['primary'],
            ),
            const SizedBox(width: 6),
            Text(
              getDateLabel(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isAnyDateSelected ? Colors.white : Colors.black87,
              ),
            ),
            if (isAnyDateSelected) ...[
              const SizedBox(width: 6),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
      selected: isAnyDateSelected,
      onSelected: (_) async {
        if (isAnyDateSelected) {
          // Clear date selection
          setState(() {
            _selectedDate = null;
            _selectedDateRange = null;
          });
        } else {
          // Show date range picker
          final DateTimeRange? pickedRange = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
            currentDate: DateTime.now(),
            saveText: 'Apply',
            helpText: 'Select Date Range',
            confirmText: 'Apply',
            cancelText: 'Cancel',
            initialDateRange: _selectedDateRange,
            initialEntryMode: DatePickerEntryMode.calendar,
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: IncidentReportConstants.colorScheme['primary']!,
                    onPrimary: Colors.white,
                    onSurface: Colors.black87,
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: IncidentReportConstants.colorScheme['primary']!,
                    ),
                  ),
                ),
                child: child!,
              );
            },
          );

          if (pickedRange != null) {
            setState(() {
              _selectedDateRange = pickedRange;
              _selectedDate = null; // Clear single date selection
            });
          }
        }
      },
      selectedColor: IncidentReportConstants.colorScheme['primary'],
      checkmarkColor: Colors.transparent,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isAnyDateSelected 
              ? IncidentReportConstants.colorScheme['primary']!
              : Colors.grey.shade300,
          width: isAnyDateSelected ? 0 : 1.5,
        ),
      ),
      elevation: isAnyDateSelected ? 2 : 0,
      shadowColor: IncidentReportConstants.colorScheme['primary']!.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: TextStyle(
        color: isAnyDateSelected ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildBatchActions() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _selectedIncidents.length == _incidentsMap.length && _incidentsMap.isNotEmpty,
                onChanged: (value) => _selectAllIncidents(),
                activeColor: IncidentReportConstants.colorScheme['primary'],
              ),
              const SizedBox(width: 12),
              Text(
                '${_selectedIncidents.length} selected',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete_rounded,
                    color: IncidentReportConstants.colorScheme['error']),
                onPressed: _showBatchDeleteConfirmation,
                tooltip: 'Delete selected',
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: IncidentReportConstants.colorScheme['primary']),
                itemBuilder: (context) => IncidentReportConstants.statusOptions.map((status) {
                  final style = StyleService.getStatusStyle(status);
                  return PopupMenuItem(
                    value: status,
                    child: Row(
                      children: [
                        Icon(style['icon'] as IconData, color: style['color'] as Color),
                        const SizedBox(width: 12),
                        Text(style['label'] as String),
                      ],
                    ),
                  );
                }).toList(),
                onSelected: _batchUpdateStatus,
              ),
            ],
          ),
        ),
      ),
    );
  }

 Widget _buildEmergencyList() {
  return StreamBuilder<List<Map<String, dynamic>>>(
    stream: _incidentsController.stream,
    builder: (context, snapshot) {
      // Handle connection state
      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
        return _buildLoadingState();
      }

      if (snapshot.hasError) {
        return _buildErrorState(snapshot.error.toString());
      }

      // Handle no data scenarios - SIMPLIFIED like your reference code
      final hasData = snapshot.hasData;
      final data = snapshot.data;
      
      if (!hasData || data == null || data.isEmpty) {
        return _buildEmptyState();
      }

      final filteredDocs = _filterEmergencies(data);

      if (filteredDocs.isEmpty) {
        return _buildNoResultsState();
      }

      // Group by date for All Reports view
      final Map<String, List<Map<String, dynamic>>> groupedDocs = {};
      if (_selectedFilter == 'all') {
        for (final doc in filteredDocs) {
          final timestamp = _safeParseDateTime(doc['timestamp']);
          final dateKey = timestamp != null
              ? DateFormat('yyyy-MM-dd').format(timestamp)
              : 'Unknown Date';
          
          if (!groupedDocs.containsKey(dateKey)) {
            groupedDocs[dateKey] = [];
          }
          groupedDocs[dateKey]!.add(doc);
        }
      }

      return RefreshIndicator(
        onRefresh: _refreshData,
        child: _selectedFilter == 'all' 
            ? _buildGroupedList(groupedDocs)
            : _buildRegularList(filteredDocs),
      );
    },
  );
}

  Widget _buildLoadingState() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: LinearProgressIndicator(
            backgroundColor: IncidentReportConstants.colorScheme['primaryLight'],
            valueColor: AlwaysStoppedAnimation<Color>(
              IncidentReportConstants.colorScheme['primary']!,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 4,
            itemBuilder: (context, index) => _buildShimmerCard(),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.downloading_rounded,
                size: 48,
                color: IncidentReportConstants.colorScheme['primary']!.withOpacity(0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading Incident Reports...',
                style: TextStyle(
                  color: IncidentReportConstants.colorScheme['primaryDark'],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while we fetch the latest emergency reports',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedList(Map<String, List<Map<String, dynamic>>> groupedDocs) {
    final sortedDates = groupedDocs.keys.toList()..sort((a, b) => b.compareTo(a));
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _calculateGroupedItemCount(groupedDocs, sortedDates),
      itemBuilder: (context, index) {
        var currentIndex = 0;
        
        for (final date in sortedDates) {
          final docs = groupedDocs[date]!;
          
          // Date header
          if (index == currentIndex) {
            return Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: _buildDateHeader(date),
            );
          }
          currentIndex++;
          
          // Documents for this date
          for (int i = 0; i < docs.length; i++) {
            if (index == currentIndex) {
              final doc = docs[i];
              final incident = IncidentData.fromMap(doc, doc['id'].toString());
              
              if (!kIsWeb) {
                for (final url in incident.imageUrls) {
                  if (url is String) {
                    DefaultCacheManager().getSingleFile(url);
                  }
                }
              }
              
              return Padding(
                padding: EdgeInsets.only(
                  bottom: i == docs.length - 1 ? 16.0 : 8.0,
                ),
                child: IncidentCard(
                  incident: incident,
                  onTap: () => _showEmergencyDetails(doc),
                  userRole: widget.userRole,
                  isSelectable: _isMultiSelectMode,
                  isSelected: _selectedIncidents.contains(doc['id'].toString()),
                  onSelect: () => _selectIncident(doc['id'].toString()),
                  onDelete: () => _deleteIncident(doc['id'].toString()),
                  showDeleteButton: _selectedFilter == 'all' && widget.userRole == 'moderator',
                ),
              );
            }
            currentIndex++;
          }
        }
        
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildDateHeader(String dateKey) {
    final date = dateKey == 'Unknown Date' 
        ? 'Unknown Date'
        : DateFormat('MMMM d, yyyy').format(DateTime.parse(dateKey));
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: IncidentReportConstants.colorScheme['primaryLight'],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: IncidentReportConstants.colorScheme['secondary']!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded, 
            size: 18, 
            color: IncidentReportConstants.colorScheme['primary'],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              date,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: IncidentReportConstants.colorScheme['primary'],
                fontSize: 16,
              ),
            ),
          ),
          const Spacer(),
          Text(
            _getDaySuffix(DateTime.parse(dateKey)),
            style: TextStyle(
              color: IncidentReportConstants.colorScheme['primaryDark'],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  int _calculateGroupedItemCount(Map<String, List<Map<String, dynamic>>> groupedDocs, List<String> sortedDates) {
    int count = groupedDocs.length; // Date headers
    for (final docs in groupedDocs.values) {
      count += docs.length; // Documents
    }
    return count;
  }

  String _getDaySuffix(DateTime date) {
    final day = date.day;
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1: return '${day}st';
      case 2: return '${day}nd';
      case 3: return '${day}rd';
      default: return '${day}th';
    }
  }

  Widget _buildRegularList(List<Map<String, dynamic>> filteredDocs) {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: filteredDocs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final doc = filteredDocs[index];
        final incident = IncidentData.fromMap(doc, doc['id'].toString());
        
        if (!kIsWeb) {
          for (final url in incident.imageUrls) {
            if (url is String) {
              DefaultCacheManager().getSingleFile(url);
            }
          }
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: IncidentCard(
            incident: incident,
            onTap: () => _showEmergencyDetails(doc),
            userRole: widget.userRole,
            isSelectable: _isMultiSelectMode,
            isSelected: _selectedIncidents.contains(doc['id'].toString()),
            onSelect: () => _selectIncident(doc['id'].toString()),
            onDelete: () => _deleteIncident(doc['id'].toString()),
            showDeleteButton: _selectedFilter == 'all' && widget.userRole == 'moderator',
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: IncidentReportConstants.colorScheme['error'],
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to Load Incidents',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'There was a problem connecting to the server. Please check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Error: ${error.length > 100 ? '${error.substring(0, 100)}...' : error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshData,
              style: ElevatedButton.styleFrom(
                backgroundColor: IncidentReportConstants.colorScheme['primary'],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              label: const Text('Try Again', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 14,
                        color: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 14,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            Container(
              width: 200,
              height: 14,
              color: Colors.grey[300],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyStateIcon(),
              size: 80,
              color: IncidentReportConstants.colorScheme['primary']!.withOpacity(0.4),
            ),
            const SizedBox(height: 20),
            Text(
              _getEmptyStateTitle(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                _getEmptyStateDescription(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildEmptyStateAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: IncidentReportConstants.colorScheme['primary']!.withOpacity(0.4),
            ),
            const SizedBox(height: 20),
            Text(
              _getNoResultsTitle(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                _getNoResultsDescription(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildNoResultsAction(),
          ],
        ),
      ),
    );
  }

  // Add this new method for empty state icons:
  IconData _getEmptyStateIcon() {
    switch (_selectedFilter) {
      case 'spam':
        return Icons.mark_email_read_rounded; // More appropriate for spam
      case 'recent':
        return Icons.update_rounded; // Indicates recent/current
      case 'all':
      default:
        return Icons.report_problem_rounded; // General incident icon
    }
  }

  // Update the _getEmptyStateTitle method:
  String _getEmptyStateTitle() {
    switch (_selectedFilter) {
      case 'spam':
        return 'No Spam Reports';
      case 'recent':
        return 'No Recent Incidents';
      case 'all':
      default:
        return 'No Incident Reports';
    }
  }

  // Update the _getEmptyStateDescription method:
  String _getEmptyStateDescription() {
    switch (_selectedFilter) {
      case 'spam':
        return 'Great news! No spam incidents have been detected. All reports appear to be legitimate emergency incidents.';
      case 'recent':
        return 'There are no active incidents requiring immediate attention. All recent reports have been resolved or are in progress.';
      case 'all':
      default:
        return 'No incident reports have been submitted yet. When emergencies are reported, they will appear here automatically.';
    }
  }

  // Add this new method for no results title:
  String _getNoResultsTitle() {
    switch (_selectedFilter) {
      case 'spam':
        return 'No Spam Found';
      case 'recent':
        return 'No Matching Incidents';
      case 'all':
      default:
        return 'No Results Found';
    }
  }

  // Update the _getNoResultsDescription method:
  String _getNoResultsDescription() {
    switch (_selectedFilter) {
      case 'spam':
        return 'No spam incidents match your current search criteria. Try adjusting your search terms or check different filters.';
      case 'recent':
        return 'No recent incidents match your search. The incidents may have been resolved or try searching with different keywords.';
      case 'all':
      default:
        return 'No incidents found matching your search criteria and filters. Try different search terms or clear some filters.';
    }
  }

  Widget _buildEmptyStateAction() {
    return ElevatedButton.icon(
      onPressed: _refreshData,
      style: ElevatedButton.styleFrom(
        backgroundColor: IncidentReportConstants.colorScheme['primary'],
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
      label: const Text('Refresh Reports', style: TextStyle(color: Colors.white)),
    );
  }

  Widget _buildNoResultsAction() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _searchQuery = '';
              _searchController.clear();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: IncidentReportConstants.colorScheme['primary'],
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.clear_all_rounded, color: Colors.white, size: 18),
          label: const Text('Clear Search', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(width: 12),
        if (_selectedDate != null || _selectedDateRange != null)
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _selectedDate = null;
                _selectedDateRange = null;
              });
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: IncidentReportConstants.colorScheme['primary']!),
            ),
            icon: Icon(Icons.calendar_today_rounded, color: IncidentReportConstants.colorScheme['primary'], size: 18),
            label: Text('Clear Date', style: TextStyle(color: IncidentReportConstants.colorScheme['primary'])),
          ),
      ],
    );
  }

List<Map<String, dynamic>> _filterEmergencies(List<Map<String, dynamic>> docs) {
    // For "Spam Reports" - use the database is_spam field
    if (_selectedFilter == 'spam') {
      return docs.where((doc) {
        // Use the database is_spam field if available, otherwise fall back to analysis
        final bool isSpam = doc['is_spam'] as bool? ?? false;
        
        if (isSpam) {
          debugPrint('📋 SPAM FILTERED FROM DATABASE - Incident ID: ${doc['id']}');
          return true;
        }
        return false;
      }).where((doc) {
        // Apply search filter to spam results
        final location = (doc['address'] ?? '').toString().toLowerCase();
        final landmark = (doc['landmark'] ?? '').toString().toLowerCase();
        final type = (doc['incident_type'] ?? '').toString().toLowerCase();
        
        return _searchQuery.isEmpty ||
            location.contains(_searchQuery) ||
            landmark.contains(_searchQuery) ||
            type.contains(_searchQuery);
      }).toList();
    }

    // For "All Reports" with no date selected - show EVERYTHING
    if (_selectedFilter == 'all' && _selectedDate == null && _selectedDateRange == null) {
      return docs.where((doc) {
        final location = (doc['address'] ?? '').toString().toLowerCase();
        final landmark = (doc['landmark'] ?? '').toString().toLowerCase();
        final type = (doc['incident_type'] ?? '').toString().toLowerCase();
        
        // Apply search filter only - NO date or status filtering
        return _searchQuery.isEmpty ||
            location.contains(_searchQuery) ||
            landmark.contains(_searchQuery) ||
            type.contains(_searchQuery);
      }).toList();
    }

    final now = DateTime.now();
    DateTime start, end;

    // Define date range for filtered views
    if (_selectedFilter == 'recent') {
      // "Recent" view - today only
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    } else if (_selectedFilter == 'all' && _selectedDateRange != null) {
      // "All Reports" with date range selected
      start = DateTime(
        _selectedDateRange!.start.year,
        _selectedDateRange!.start.month,
        _selectedDateRange!.start.day,
      );
      end = DateTime(
        _selectedDateRange!.end.year,
        _selectedDateRange!.end.month,
        _selectedDateRange!.end.day,
        23, 59, 59, 999,
      );
    } else if (_selectedFilter == 'all' && _selectedDate != null) {
      // "All Reports" with single date selected (backward compatibility)
      start = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      );
      end = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        23, 59, 59, 999,
      );
    } else {
      // This shouldn't happen, but return all as fallback
      return docs;
    }

    // Filter by date for "Recent" and "All Reports with date selected"
    final dateFiltered = docs.where((incident) {
      final timestamp = incident['timestamp'];
      if (timestamp == null) return false;
      
      try {
        final incidentDate = DateTime.parse(timestamp);
        return incidentDate.isAfter(start.subtract(const Duration(seconds: 1))) && 
              incidentDate.isBefore(end.add(const Duration(seconds: 1)));
      } catch (e) {
        debugPrint('Error parsing timestamp: $e');
        return false;
      }
    }).toList();

    // Apply status filtering ONLY for "Recent" view - filter out resolved and declined
    final statusFiltered = _selectedFilter == 'recent' 
        ? dateFiltered.where((incident) {
            final status = (incident['latest_status'] ?? incident['status'] ?? 'pending').toString().toLowerCase();
            return status != 'resolved' && status != 'declined';
          }).toList()
        : dateFiltered; // "All Reports" shows ALL statuses

    // Apply search filter
    final searchFiltered = statusFiltered.where((doc) {
      final location = (doc['address'] ?? '').toString().toLowerCase();
      final landmark = (doc['landmark'] ?? '').toString().toLowerCase();
      final type = (doc['incident_type'] ?? '').toString().toLowerCase();

      return _searchQuery.isEmpty ||
          location.contains(_searchQuery) ||
          landmark.contains(_searchQuery) ||
          type.contains(_searchQuery);
    }).toList();

    debugPrint('🔍 IncidentReportScreen filtered ${docs.length} → ${searchFiltered.length} incidents');
    debugPrint('📅 Filter: $_selectedFilter - Date: ${_selectedDateRange != null ? "Range ${DateFormat('MMM d').format(_selectedDateRange!.start)} to ${DateFormat('MMM d').format(_selectedDateRange!.end)}" : _selectedDate != null ? "Single date" : "All"} - Status filter: ${_selectedFilter == 'recent' ? "Active only" : "All statuses"} - Spam filter: ${_selectedFilter == 'spam' ? "Spam only" : "All"}');
    
    return searchFiltered;
  }

  void _showEmergencyDetails(Map<String, dynamic> doc) {
    final incident = IncidentData.fromMap(doc, doc['id'].toString());

    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: IncidentDetailsModal(
              incident: incident,
              userRole: widget.userRole,
              onStatusUpdated: () {
                setState(() {
                  _hasNewUpdates = true;
                });
              },
              isWeb: true,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => IncidentDetailsModal(
          incident: incident,
          userRole: widget.userRole,
          onStatusUpdated: () {
            setState(() {
              _hasNewUpdates = true;
            });
          },
          isWeb: false,
        ),
      );
    }
  }

  Widget _buildFloatingActionButton() {
    if (_isMultiSelectMode && _selectedIncidents.isNotEmpty) {
      return FloatingActionButton(
        onPressed: () => _batchUpdateStatus('in progress'),
        backgroundColor: IncidentReportConstants.colorScheme['primary'],
        child: const Icon(Icons.check_rounded, color: Colors.white),
      );
    }

    return FloatingActionButton(
      onPressed: _refreshData,
      backgroundColor: IncidentReportConstants.colorScheme['primary'],
      child: const Icon(Icons.refresh_rounded, color: Colors.white),
    );
  }

  // Utility Methods
  Future<bool?> _showConfirmationDialog({
    required String title,
    required String content,
    String confirmText = 'Confirm',
    Color? confirmColor,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor ?? IncidentReportConstants.colorScheme['primary'],
            ),
            child: Text(confirmText, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: IncidentReportConstants.colorScheme['success'],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: IncidentReportConstants.colorScheme['error'],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _refreshData() async {
    setState(() {
      _hasNewUpdates = false;
      _isInitialLoad = true;
    });

    try {
      // Clear current data and re-subscribe to get fresh data
      _incidentsMap.clear();
      
      // Cancel existing subscriptions
      _incidentsSubscription?.cancel();
      _statusUpdatesSubscription?.cancel();
      
      // Re-subscribe to streams
      _setupRealTimeSubscriptions();
      
      // Show loading state for a moment
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Data refreshed'),
            backgroundColor: IncidentReportConstants.colorScheme['success'],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error refreshing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: IncidentReportConstants.colorScheme['error'],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// Incident Card Widget
class IncidentCard extends StatelessWidget {
  final IncidentData incident;
  final VoidCallback onTap;
  final String userRole;
  final bool isSelectable;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;
  final bool showDeleteButton;

  const IncidentCard({
    super.key,
    required this.incident,
    required this.onTap,
    required this.userRole,
    required this.isSelectable,
    required this.isSelected,
    required this.onSelect,
    this.onDelete,
    this.showDeleteButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final incidentStyle = StyleService.getIncidentStyle(incident.incidentType);
    final statusStyle = StyleService.getStatusStyle(incident.effectiveStatus);
    final hasImages = incident.imageUrls.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isSelectable ? onSelect : onTap,
      onLongPress: userRole == 'moderator' ? onSelect : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? (incidentStyle['color'] as Color).withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: incidentStyle['color'] as Color, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// INCIDENT HEADER
            Row(
              children: [
                if (isSelectable)
                  _buildSelectionIndicator(incidentStyle['color'] as Color)
                else
                  _buildIncidentIcon(incidentStyle),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (incident.incidentType ?? 'Unknown type').toUpperCase(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: incidentStyle['color'] as Color,
                    ),
                  ),
                ),
                _buildStatusBadge(statusStyle),
                if (showDeleteButton && !isSelectable) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, size: 20),
                    color: IncidentReportConstants.colorScheme['error'],
                    onPressed: () => _showDeleteConfirmation(context, onDelete),
                    tooltip: 'Delete Incident',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            /// LOCATION
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 16, color: Colors.blueGrey.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    incident.address ?? 'Unknown location',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                ),
              ],
            ),

            /// LANDMARK (ADDED)
            if (incident.landmark != null && incident.landmark!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.place_rounded, size: 16, color: Colors.blueGrey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Near ${incident.landmark!}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blueGrey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            /// REPORTER + TIME
            Row(
              children: [
                Icon(Icons.person_rounded, size: 16, color: Colors.blueGrey.shade700),
                const SizedBox(width: 6),
                Text(
                  incident.name ?? 'Anonymous',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blueGrey.shade700,
                  ),
                ),
                const Spacer(),
                if (hasImages) ...[
                  Icon(Icons.image_rounded, size: 16, color: Colors.blueGrey.shade700),
                  const SizedBox(width: 4),
                ],
                Text(
                  incident.timestamp != null
                      ? DateFormat('MMM d, h:mm a').format(incident.timestamp!.toLocal())
                      : 'Unknown time',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey.shade600,
                  ),
                ),
              ],
            ),
            if (userRole == 'moderator') ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: IncidentReportConstants.colorScheme['primaryLight'],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: IncidentReportConstants.colorScheme['secondary']!),
                ),
                child: Text(
                  'ADMIN VIEW',
                  style: TextStyle(
                    fontSize: 10,
                    color: IncidentReportConstants.colorScheme['primaryDark'],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionIndicator(Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: isSelected ? color : Colors.grey.shade400),
      ),
      child: Icon(
        isSelected ? Icons.check_rounded : Icons.circle_outlined,
        size: 20,
        color: isSelected ? Colors.white : Colors.grey.shade400,
      ),
    );
  }

  Widget _buildIncidentIcon(Map<String, dynamic> incidentStyle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: incidentStyle['gradient'] as Gradient,
        shape: BoxShape.circle,
      ),
      child: Icon(
        incidentStyle['icon'] as IconData,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildStatusBadge(Map<String, dynamic> statusStyle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusStyle['bgColor'] as Color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusStyle['icon'] as IconData, size: 14, color: statusStyle['color'] as Color),
          const SizedBox(width: 4),
          Text(
            (statusStyle['label'] as String).toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: statusStyle['color'] as Color,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, VoidCallback? onDelete) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this incident report? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onDelete != null) {
                  onDelete();
                }
              },
              child: Text(
                "Delete",
                style: TextStyle(color: IncidentReportConstants.colorScheme['error']),
                ),
            ),
          ],
        );
      },
    );
  }
}

// Incident Details Modal
class IncidentDetailsModal extends StatefulWidget {
  final IncidentData incident;
  final String userRole;
  final VoidCallback onStatusUpdated;
  final bool isWeb;

  const IncidentDetailsModal({
    super.key,
    required this.incident,
    required this.userRole,
    required this.onStatusUpdated,
    required this.isWeb,
  });

  @override
  State<IncidentDetailsModal> createState() => _IncidentDetailsModalState();
}

class _IncidentDetailsModalState extends State<IncidentDetailsModal> {
  late String _selectedStatus;
  final TextEditingController _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<StatusUpdate> _statusUpdates = [];
  bool _loadingStatusUpdates = false;
  bool _updatingStatus = false;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.incident.effectiveStatus;
    _loadStatusUpdates();
  }

  Future<void> _loadStatusUpdates() async {
    setState(() {
      _loadingStatusUpdates = true;
    });

    try {
      final updates = await IncidentService.getStatusUpdates(widget.incident.id);
      setState(() {
        _statusUpdates = updates;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load status history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _loadingStatusUpdates = false;
      });
    }
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(40),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Stack(
            children: [
              PhotoView(
                imageProvider: NetworkImage(imageUrl),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isWeb) {
      return _buildWebLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  Widget _buildWebLayout() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildIncidentDetails(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 1,
                    child: _buildStatusSection(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 60,
            height: 6,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIncidentDetails(),
                  const SizedBox(height: 24),
                  _buildStatusSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: IncidentReportConstants.colorScheme['primary'],
        borderRadius: widget.isWeb
            ? const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              )
            : null,
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 32, color: Colors.white),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'INCIDENT DETAILS',
              style: TextStyle(
                fontSize: widget.isWeb ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentDetails() {
    final incidentStyle = StyleService.getIncidentStyle(widget.incident.incidentType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: incidentStyle['gradient'] as Gradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  incidentStyle['icon'] as IconData,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (widget.incident.incidentType ?? 'Unknown type').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.incident.address ?? 'Unknown location',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    // ADDED LANDMARK TO HEADER
                    if (widget.incident.landmark != null && widget.incident.landmark!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Near ${widget.incident.landmark!}",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildDetailSection(
          icon: Icons.location_on_rounded,
          title: 'Location',
          content: widget.incident.address ?? 'Unknown location',
        ),
        // ADDED LANDMARK SECTION
        if (widget.incident.landmark != null && widget.incident.landmark!.isNotEmpty)
          _buildDetailSection(
            icon: Icons.place_rounded,
            title: 'Landmark',
            content: widget.incident.landmark!,
          ),
          _buildDetailSection(
            icon: Icons.access_time_rounded,
            title: 'Reported',
            content: widget.incident.timestamp != null
                ? DateFormat('MMMM d, yyyy - h:mm a').format(widget.incident.timestamp!.toLocal())
                : 'Unknown time',
          ),
        if (widget.incident.contactNumber != null)
          _buildDetailSection(
            icon: Icons.phone_rounded,
            title: 'Contact',
            content: widget.incident.contactNumber!,
          ),
        _buildDetailSection(
          icon: Icons.person_rounded,
          title: 'Reporter',
          content: widget.incident.name ?? 'Anonymous',
        ),
        if (widget.incident.description != null)
          _buildDetailSection(
            icon: Icons.description_rounded,
            title: 'Description',
            content: widget.incident.description!,
            isDescription: true,
          ),
        if (widget.incident.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildImagesSection(),
        ],
        const SizedBox(height: 24),
        _buildStatusTimeline(),
      ],
    );
  }

  Widget _buildDetailSection({
    required IconData icon,
    required String title,
    required String content,
    bool isDescription = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: IncidentReportConstants.colorScheme['primary']),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: isDescription ? 15 : 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATTACHED IMAGES',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: IncidentReportConstants.colorScheme['primaryDark'],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.incident.imageUrls.length,
            itemBuilder: (context, index) {
              final imageUrl = widget.incident.imageUrls[index]?.toString() ?? '';

              return Container(
                margin: const EdgeInsets.only(right: 12),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: GestureDetector(
                    onTap: () => _showImagePreview(imageUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey[200],
                        child: _buildImageWidget(imageUrl),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40),
          ),
        );
      },
    );
  }

  Widget _buildStatusTimeline() {
    if (_loadingStatusUpdates) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Create a combined list that includes the initial pending status
    final List<StatusUpdate> allStatusUpdates = [];
    
    // Add the initial pending status if it's not in the updates
    final hasInitialPending = _statusUpdates.any((update) => update.status == 'pending');
    if (!hasInitialPending && widget.incident.effectiveStatus == 'pending') {
      allStatusUpdates.add(
        StatusUpdate(
          id: 'initial',
          incidentId: widget.incident.id,
          status: 'pending',
          note: 'Incident reported',
          updatedBy: widget.incident.name ?? 'Anonymous',
          createdAt: widget.incident.timestamp ?? widget.incident.createdAt ?? DateTime.now(),
        ),
      );
    }
    
    // Add all the actual status updates
    allStatusUpdates.addAll(_statusUpdates);

    if (allStatusUpdates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No Status History',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
            ),
            ),
            const SizedBox(height: 8),
            Text(
              'Status updates will appear here once they are added.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STATUS HISTORY',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: IncidentReportConstants.colorScheme['primaryDark'],
          ),
        ),
        const SizedBox(height: 16),
        ...allStatusUpdates.reversed.map((update) {
          final statusStyle = StyleService.getStatusStyle(update.status);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusStyle['bgColor'] as Color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusStyle['icon'] as IconData,
                    color: statusStyle['color'] as Color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        update.status.toUpperCase(),
                        style: TextStyle(
                          color: statusStyle['color'] as Color,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      if (update.note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          update.note,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'By: ${update.updatedBy}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d, h:mm a').format(update.createdAt.toLocal()),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatusSection() {
    if (widget.userRole == 'moderator') {
      return _buildAdminStatusSection();
    } else {
      return _buildUserStatusSection();
    }
  }

  Widget _buildAdminStatusSection() {
    // Ensure _selectedStatus is valid and exists in status options
    final availableStatusOptions = IncidentReportConstants.statusOptions;
    
    // Validate and set default if current selection is invalid
    if (!availableStatusOptions.contains(_selectedStatus)) {
      _selectedStatus = widget.incident.effectiveStatus;
      // If incident status is also invalid, fall back to first option
      if (!availableStatusOptions.contains(_selectedStatus)) {
        _selectedStatus = availableStatusOptions.first;
      }
    }

    final dropdownItems = <DropdownMenuItem<String>>[];
    for (final status in availableStatusOptions) {
      final style = StyleService.getStatusStyle(status);
      dropdownItems.add(
        DropdownMenuItem<String>(
          value: status,
          child: Row(
            children: [
              Icon(style['icon'] as IconData, color: style['color'] as Color),
              const SizedBox(width: 12),
              Text(style['label'] as String),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UPDATE STATUS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: IncidentReportConstants.colorScheme['primaryDark'],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedStatus,
            items: dropdownItems,
            onChanged: _updatingStatus ? null : (String? newValue) {
              if (newValue != null) {
                _handleStatusChange(newValue);
              }
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ADD NOTE',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: "Add a note about this update...",
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please add a note';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _updatingStatus
                ? ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: IncidentReportConstants.colorScheme['primary']!.withOpacity(0.6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('UPDATING...', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  )
                : ElevatedButton(
                    onPressed: _updateStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: IncidentReportConstants.colorScheme['primary'],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('SAVE UPDATE', style: TextStyle(color: Colors.white)),
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStatusChange(String newValue) async {
    if (newValue == 'declined') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Decline'),
          content: const Text('Are you sure you want to decline this incident? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Decline', style: TextStyle(color: IncidentReportConstants.colorScheme['error'])),
            ),
          ],
        ),
      );
      
      if (confirmed != true) {
        return;
      }
    }
    
    setState(() {
      _selectedStatus = newValue;
    });
  }

  Widget _buildUserStatusSection() {
    final statusStyle = StyleService.getStatusStyle(widget.incident.effectiveStatus);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT STATUS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: IncidentReportConstants.colorScheme['primaryDark'],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusStyle['bgColor'] as Color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusStyle['color'] as Color, width: 2),
            ),
            child: Row(
              children: [
                Icon(statusStyle['icon'] as IconData, color: statusStyle['color'] as Color, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    (statusStyle['label'] as String).toUpperCase(),
                    style: TextStyle(
                      color: statusStyle['color'] as Color,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus() async {
    if (_formKey.currentState!.validate()) {
      final note = _noteController.text.trim();
      
      setState(() {
        _updatingStatus = true;
      });
      
      try {
        await IncidentService.updateIncidentStatus(
          widget.incident.id,
          status: _selectedStatus,
          note: note,
          updatedBy: 'Moderator',
        );

        // Reload status updates to show the new one
        await _loadStatusUpdates();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Clear the note field
          _noteController.clear();
          
          widget.onStatusUpdated();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update status: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        // Log the error for debugging
        if (kDebugMode) {
          print('Status update error: $e');
        }
      } finally {
        if (mounted) {
          setState(() {
            _updatingStatus = false;
          });
        }
      }
    }
  }
 
  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
}