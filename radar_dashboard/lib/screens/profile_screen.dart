import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isUploading = false;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emergencyContactController = TextEditingController();
  final TextEditingController _emergencyPhoneController = TextEditingController();
  DateTime? _selectedDob;

  // Color scheme
  final Color _primaryColor = const Color(0xFF2C5282);
  final Color _secondaryColor = const Color(0xFF4299E1);
  final Color _accentColor = const Color(0xFF48BB78);
  final Color _errorColor = const Color(0xFFF56565);
  final Color _warningColor = const Color(0xFFED8936);

  Color get _scaffoldBackground => Theme.of(context).colorScheme.surfaceContainerHighest;

  // Web responsiveness
  bool get _isWeb => identical(0, 0.0);

  @override
  void initState() {
    super.initState();
    _debugUserState();
  }

  Future<void> _debugUserState() async {
    final user = _supabase.auth.currentUser;
    print("=== DEBUG USER STATE ===");
    print("Auth User ID: ${user?.id}");
    print("Auth User Email: ${user?.email}");
    
    if (user != null) {
      try {
        // Test direct query to see if data exists
        final response = await _supabase
            .from('dashboard_users')
            .select()
            .eq('id', user.id);
        
        print("Direct Query Result: $response");
        print("Number of rows: ${response.length}");
        
        if (response.isNotEmpty) {
          print("User exists in dashboard_users: ${response.first}");
        } else {
          print("❌ User does NOT exist in dashboard_users table");
          print("This is likely the issue - creating test record...");
          await _createTestUserRecord(user);
        }
      } catch (e) {
        print("❌ Database Query Error: $e");
        print("This indicates RLS policy issues");
      }
    }
    print("=== END DEBUG ===");
  }

  Future<void> _createTestUserRecord(User user) async {
    try {
      print("Creating test user record...");
      await _supabase.from('dashboard_users').insert({
        'id': user.id,
        'email': user.email ?? 'unknown@example.com',
        'role': 'user',
        'personal_details': {
          'firstName': 'Test',
          'lastName': 'User',
          'phoneNumber': '+1234567890',
        },
        'created_at': DateTime.now().toIso8601String(),
      });
      print("✅ Test user record created successfully");
    } catch (e) {
      print("❌ Failed to create test record: $e");
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

 Future<void> _pickAndUploadImage(ImageSource source) async {
  try {
    final XFile? pickedFile = await _picker.pickImage(
      source: source, 
      imageQuality: 85,
      maxWidth: 800,
    );

    if (pickedFile != null) {
      setState(() => _isUploading = true);

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final file = File(pickedFile.path);
      final fileBytes = await file.readAsBytes();
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // FIXED: Use uploadBinary for Uint8List
      await _supabase.storage
          .from('dashboard_pictures')
          .uploadBinary(
            fileName, 
            fileBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      // Get public URL
      final publicUrl = _supabase.storage
          .from('dashboard_pictures')
          .getPublicUrl(fileName);

      // Update user profile in database
      await _supabase
          .from('dashboard_users')
          .update({
            'personal_details': {
              'profilePicture': publicUrl,
              'lastUpdated': DateTime.now().toIso8601String(),
            }
          })
          .eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Profile picture updated successfully!"),
            backgroundColor: _accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  } catch (e) {
    debugPrint("Error uploading profile picture: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to upload image: ${e.toString()}"),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isUploading = false);
    }
  }
}

  Future<void> _updateProfileInfo() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isUploading = true);

      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final updatedData = {
        'personal_details': {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'emergencyContact': _emergencyContactController.text.trim(),
          'emergencyPhone': _emergencyPhoneController.text.trim(),
          'dateOfBirth': _selectedDob?.toIso8601String(),
          'lastUpdated': DateTime.now().toIso8601String(),
        }
      };

      await _supabase
          .from('dashboard_users')
          .update(updatedData)
          .eq('id', user.id);

      setState(() => _isEditing = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Profile updated successfully!"),
            backgroundColor: _accentColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating profile info: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Failed to update profile. Please try again."),
            backgroundColor: _errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

Future<void> _selectDate(BuildContext context) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: _selectedDob ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
    firstDate: DateTime(1900),
    lastDate: DateTime.now(),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: _primaryColor,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: _primaryColor,
            ),
          ),
          // FIXED: Use DialogThemeData instead of DialogTheme
          dialogTheme: DialogThemeData(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        child: child ?? const SizedBox(), // Safe null handling
      );
    },
  );
  
  if (picked != null && picked != _selectedDob) {
    setState(() => _selectedDob = picked);
  }
}

void _debugProfileData(Map<String, dynamic> userData) {
  print("=== PROFILE DATA DEBUG ===");
  print("User Data: $userData");
  
  final personalDetails = userData['personal_details'] as Map<String, dynamic>?;
  print("Personal Details: $personalDetails");
  
  if (personalDetails == null || personalDetails.isEmpty) {
    print("❌ Personal details is NULL or EMPTY");
  } else {
    print("✅ Personal details exists with keys: ${personalDetails.keys.toList()}");
    print("First Name: ${personalDetails['firstName']}");
    print("Last Name: ${personalDetails['lastName']}");
    print("Phone: ${personalDetails['phoneNumber']}");
  }
  print("=== END DEBUG ===");
}

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: _isWeb 
            ? const EdgeInsets.symmetric(horizontal: 100, vertical: 50)
            : const EdgeInsets.all(20),
        child: Container(
          constraints: _isWeb ? const BoxConstraints(maxWidth: 400) : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
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
                    Icon(
                      Icons.camera_alt_rounded,
                      size: 48,
                      color: _primaryColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Change Profile Picture",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Choose how you want to update your profile picture",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Options
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    _buildImageSourceOption(
                      icon: Icons.camera_enhance_rounded,
                      title: "Take Photo",
                      subtitle: "Use your camera to take a new photo",
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndUploadImage(ImageSource.camera);
                      },
                    ),
                    Divider(height: 1, color: Colors.grey[200]),
                    _buildImageSourceOption(
                      icon: Icons.photo_library_rounded,
                      title: "Choose from Gallery",
                      subtitle: "Select an existing photo from your gallery",
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndUploadImage(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
              ),
              
              // Cancel Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: _primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _primaryColor, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }

  Widget _buildRoleBadge(String role) {
    final isAdmin = role.toLowerCase() == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isAdmin ? _warningColor.withOpacity(0.1) : _primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAdmin ? _warningColor.withOpacity(0.3) : _primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin ? Icons.security_rounded : Icons.person_rounded,
            size: 14,
            color: isAdmin ? _warningColor : _primaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isAdmin ? _warningColor : _primaryColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  void _populateFormData(Map<String, dynamic> userData) {
    final personalDetails = userData['personal_details'] as Map<String, dynamic>? ?? {};
    
    print("🔄 Populating form with personal details: $personalDetails"); // Debug
    
    // Use safe casting with null-aware operators
    _firstNameController.text = (personalDetails['firstName'] as String?) ?? '';
    _lastNameController.text = (personalDetails['lastName'] as String?) ?? '';
    _phoneController.text = (personalDetails['phoneNumber'] as String?) ?? '';
    _emergencyContactController.text = (personalDetails['emergencyContact'] as String?) ?? '';
    _emergencyPhoneController.text = (personalDetails['emergencyPhone'] as String?) ?? '';
    
    // Handle date of birth safely
    final dobString = personalDetails['dateOfBirth'] as String?;
    if (dobString != null && dobString.isNotEmpty) {
      try {
        _selectedDob = DateTime.parse(dobString);
        print("✅ Date of birth parsed: $_selectedDob");
      } catch (e) {
        print("❌ Error parsing date: $e");
        _selectedDob = null;
      }
    } else {
      _selectedDob = null;
    }
    
    print("📝 Form populated - First name: '${_firstNameController.text}'"); // Debug
  }

  Widget _buildInfoField(String label, String value, {bool isLast = false}) {
    final displayValue = value.isNotEmpty ? value : 'Not provided';
    final textColor = value.isNotEmpty ? Colors.black87 : Colors.grey[600];
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey[200]),
      ],
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                maxLines: maxLines,
                validator: validator,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryColor, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _errorColor, width: 1.5),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _errorColor, width: 1.5),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey[200]),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _primaryColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(Icons.person_add_alt_1_rounded, size: 64, color: _primaryColor),
            const SizedBox(height: 16),
            Text(
              "Welcome!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "It looks like you haven't set up your profile yet. Click the edit button to add your personal information.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setState(() => _isEditing = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text("Set Up Your Profile"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> userData) {
    final personalDetails = userData['personal_details'] as Map<String, dynamic>? ?? {};
    final userRole = userData['role']?.toString() ?? 'user';
    final profilePicture = personalDetails["profilePicture"] ?? "";
    final firstName = personalDetails["firstName"] ?? "";
    final lastName = personalDetails["lastName"] ?? "";
    final user = _supabase.auth.currentUser!;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _primaryColor,
              _secondaryColor,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: profilePicture.isNotEmpty
                        ? Image.network(
                            profilePicture,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: Colors.white,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.white.withOpacity(0.2),
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.white.withOpacity(0.2),
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.camera_alt, size: 20, color: _primaryColor),
                      onPressed: _showImageSourceDialog,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Name and Role
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "$firstName $lastName".trim().isEmpty ? "No Name Provided" : "$firstName $lastName",
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 12),
                _buildRoleBadge(userRole),
              ],
            ),
            
            const SizedBox(height: 8),
            Text(
              user.email ?? "",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoView(Map<String, dynamic> userData) {
    final personalDetails = userData['personal_details'] as Map<String, dynamic>? ?? {};
    final firstName = personalDetails["firstName"] ?? "";
    final lastName = personalDetails["lastName"] ?? "";
    final phone = personalDetails["phoneNumber"] ?? "";
    final emergencyContact = personalDetails["emergencyContact"] ?? "";
    final emergencyPhone = personalDetails["emergencyPhone"] ?? "";
    final dob = personalDetails["dateOfBirth"] != null
        ? DateFormat('MMMM dd, yyyy').format(DateTime.parse(personalDetails["dateOfBirth"] as String))
        : "Not set";

    // Check if any profile data exists
    final hasProfileData = personalDetails.isNotEmpty && 
        personalDetails.keys.any((key) => 
            personalDetails[key] != null && 
            personalDetails[key] != '' && 
            key != 'lastUpdated');

    if (!hasProfileData) {
      return _buildWelcomeCard();
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle("Personal Information"),
                IconButton(
                  icon: Icon(Icons.edit_outlined, color: _primaryColor, size: 24),
                  onPressed: () => setState(() => _isEditing = true),
                  tooltip: "Edit Profile",
                ),
              ],
            ),
            
            const Divider(height: 1, color: Colors.grey),
            const SizedBox(height: 8),
            
            _buildInfoField("First Name", firstName),
            _buildInfoField("Last Name", lastName),
            _buildInfoField("Phone Number", phone),
            _buildInfoField("Date of Birth", dob),
            _buildInfoField("Emergency Contact", emergencyContact),
            _buildInfoField("Emergency Phone", emergencyPhone, isLast: true),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: _primaryColor,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    
    final user = _supabase.auth.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 768;

    if (user == null) {
      return Scaffold(
        backgroundColor: _scaffoldBackground,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "No user logged in",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text("Go Back", style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _scaffoldBackground,
      appBar: AppBar(
        title: Text(
          _isEditing ? "Edit Profile" : "My Profile",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_isEditing) {
              setState(() => _isEditing = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: "Edit Profile",
            )
          else
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 22),
              onPressed: () => setState(() => _isEditing = false),
              tooltip: "Cancel",
            ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _supabase
            .from('dashboard_users')
            .stream(primaryKey: ['id'])
            .eq('id', user.id)
            .map((data) {
              print("🔄 Stream received ${data.length} items");
              if (data.isNotEmpty) {
                print("✅ Stream data: ${data.first}");
                return data.first;
              }
              print("❌ Stream returned empty data");
              return null;
            }),
        builder: (context, snapshot) {
          print("📊 Stream Builder State:");
          print("   Connection: ${snapshot.connectionState}");
          print("   Has Data: ${snapshot.hasData}");
          print("   Has Error: ${snapshot.hasError}");
          if (snapshot.hasError) {
            print("   Error: ${snapshot.error}");
              if (snapshot.hasData && snapshot.data != null) {
              _debugProfileData(snapshot.data!);
            }
          }
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    "Loading profile...",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "User ID: ${user.id}",
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      "No profile data found",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text("Go Back", style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            );
          }

          final userData = snapshot.data!;
          
          // Populate form when entering edit mode
          if (_isEditing && _firstNameController.text.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              print("🔄 Entering edit mode - populating form...");
              _populateFormData(userData);
            });
          }

          return Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(isLargeScreen ? 40 : 20),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Header Card
                        _buildProfileHeader(userData),
                        
                        const SizedBox(height: 32),
                        
                        _isEditing 
                          ? Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Personal Information Card
                                  Card(
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(28),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionTitle("Personal Information"),
                                          
                                          if (isLargeScreen) 
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _buildEditableField(
                                                    label: "First Name",
                                                    controller: _firstNameController,
                                                    validator: (value) => value!.isEmpty ? 'First name is required' : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                Expanded(
                                                  child: _buildEditableField(
                                                    label: "Last Name",
                                                    controller: _lastNameController,
                                                    validator: (value) => value!.isEmpty ? 'Last name is required' : null,
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            Column(
                                              children: [
                                                _buildEditableField(
                                                  label: "First Name",
                                                  controller: _firstNameController,
                                                  validator: (value) => value!.isEmpty ? 'First name is required' : null,
                                                ),
                                                _buildEditableField(
                                                  label: "Last Name",
                                                  controller: _lastNameController,
                                                  validator: (value) => value!.isEmpty ? 'Last name is required' : null,
                                                ),
                                              ],
                                            ),
                                          
                                          _buildEditableField(
                                            label: "Phone Number",
                                            controller: _phoneController,
                                            keyboardType: TextInputType.phone,
                                            validator: (value) => value!.isEmpty ? 'Phone number is required' : null,
                                          ),
                                          
                                          // Date of Birth Picker
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Date of Birth",
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey[700],
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                InkWell(
                                                  onTap: () => _selectDate(context),
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: Colors.grey[300]!),
                                                      borderRadius: BorderRadius.circular(12),
                                                      color: Colors.grey[50],
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          _selectedDob != null
                                                              ? DateFormat('MMMM dd, yyyy').format(_selectedDob!)
                                                              : "Select your date of birth",
                                                          style: TextStyle(
                                                            color: _selectedDob != null ? Colors.black87 : Colors.grey[600],
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        Icon(Icons.calendar_today, color: _primaryColor, size: 20),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          if (isLargeScreen)
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _buildEditableField(
                                                    label: "Emergency Contact Name",
                                                    controller: _emergencyContactController,
                                                    validator: (value) => null,
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                Expanded(
                                                  child: _buildEditableField(
                                                    label: "Emergency Contact Phone",
                                                    controller: _emergencyPhoneController,
                                                    keyboardType: TextInputType.phone,
                                                    validator: (value) => null,
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            Column(
                                              children: [
                                                _buildEditableField(
                                                  label: "Emergency Contact Name",
                                                  controller: _emergencyContactController,
                                                  validator: (value) => null,
                                                ),
                                                _buildEditableField(
                                                  label: "Emergency Contact Phone",
                                                  controller: _emergencyPhoneController,
                                                  keyboardType: TextInputType.phone,
                                                  validator: (value) => null,
                                                  isLast: true,
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 32),
                                  
                                  // Action Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => setState(() => _isEditing = false),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 18),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            side: BorderSide(color: _primaryColor, width: 2),
                                          ),
                                          child: Text(
                                            "CANCEL",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color: _primaryColor,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: _updateProfileInfo,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _primaryColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 18),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            elevation: 2,
                                            shadowColor: _primaryColor.withOpacity(0.3),
                                          ),
                                          child: const Text(
                                            "SAVE CHANGES",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : _buildProfileInfoView(userData),
                      ],
                    ),
                  ),
                ),
              ),
              
              if (_isUploading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Container(
                      width: 140,
                      padding: const EdgeInsets.all(24),
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: _primaryColor, strokeWidth: 3),
                          const SizedBox(height: 16),
                          const Text(
                            "Updating...",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}