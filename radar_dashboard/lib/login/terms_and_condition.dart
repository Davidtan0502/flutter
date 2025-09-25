import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatefulWidget {
  final VoidCallback? onTermsAccepted;
  final VoidCallback? onTermsRejected;
  final bool showLegalCompliance;

  const TermsAndConditionsScreen({
    super.key,
    this.onTermsAccepted,
    this.onTermsRejected,
    this.showLegalCompliance = true,
  });

  @override
  State<TermsAndConditionsScreen> createState() => _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showButtons = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScrollPosition);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScrollPosition);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScrollPosition() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // Show buttons when user scrolls near the bottom (80% of content)
    if (currentScroll >= maxScroll * 0.8 && !_showButtons) {
      setState(() {
        _showButtons = true;
      });
    } else if (currentScroll < maxScroll * 0.8 && _showButtons) {
      setState(() {
        _showButtons = false;
      });
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  // Secure navigation handlers
  void _handleAcceptTerms(BuildContext context) {
    _logUserAction('TERMS_ACCEPTED');
    
    if (widget.onTermsAccepted != null) {
      widget.onTermsAccepted!();
    } else {
      Navigator.pop(context, true);
    }
  }

  void _handleRejectTerms(BuildContext context) {
    _logUserAction('TERMS_REJECTED');
    
    if (widget.onTermsRejected != null) {
      widget.onTermsRejected!();
    } else {
      Navigator.pop(context, false);
    }
  }

  void _logUserAction(String action) {
    debugPrint('TermsAndConditions: User action - $action - Timestamp: ${DateTime.now().toIso8601String()}');
  }

  Future<bool> _onWillPop(BuildContext context) async {
    _handleRejectTerms(context);
    return false;
  }

  // Secure content sections
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.article_outlined,
          size: 36,
          color: Colors.blue[800],
        ),
        const SizedBox(width: 12),
        Text(
          "TERMS & CONDITIONS",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.blue[800],
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildLegalComplianceNotice() {
    if (!widget.showLegalCompliance) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Text(
        "In compliance with:\n"
        "• RA 10173 – Data Privacy Act of 2012\n"
        "• RA 10175 – Cybercrime Prevention Act of 2012\n"
        "• RA 10121 – Philippine Disaster Risk Reduction and Management Act of 2010",
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.blue[900],
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildTermsContent() {
    return SizedBox(
      height: 400,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.grey[800],
            ),
            children: [
              const TextSpan(
                text: 'ADMINISTRATOR ACCESS AGREEMENT\n\n',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF2C5282),
                ),
              ),
              
              const TextSpan(
                text: '1. AUTHORIZED USE & PURPOSE (RA 10121 COMPLIANT)\n',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(
                text: '• This system is designated exclusively for official disaster monitoring, risk assessment, and emergency response coordination.\n'
                    '• Access is restricted to authorized personnel with verified administrative privileges.\n'
                    '• Any deviation from intended use constitutes a violation of RA 10121 provisions.\n\n',
              ),

              const TextSpan(
                text: '2. DATA PROCESSING & PRIVACY PROTECTION (RA 10173 COMPLIANT)\n',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(
                text: 'Collected Administrator Data:\n'
                    '• Full Legal Name (for identity verification)\n'
                    '• Date of Birth (for age verification and security)\n'
                    '• Professional Email Address (for secure communication)\n\n'
                    'Data Protection Responsibilities:\n'
                    '• Implement appropriate technical and organizational security measures\n'
                    '• Ensure lawful processing of user-submitted disaster reports\n'
                    '• Maintain confidentiality of all accessed information\n'
                    '• Report any data breaches within 72 hours of discovery\n\n',
              ),

              const TextSpan(
                text: '3. SECURITY PROTOCOLS & CYBERSECURITY (RA 10175 COMPLIANT)\n',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(
                text: '• Mandatory use of multi-factor authentication where available\n'
                    '• Regular password updates following NIST security guidelines\n'
                    '• Immediate reporting of suspicious activities or security incidents\n'
                    '• Prohibition of unauthorized data extraction or system modification\n'
                    '• Compliance with cybersecurity incident response protocols\n\n',
              ),

              const TextSpan(
                text: '4. LEGAL ACCOUNTABILITY & CONSEQUENCES\n',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(
                text: 'Administrators are subject to:\n'
                    '• Administrative sanctions for policy violations\n'
                    '• Legal prosecution under RA 10173 for data privacy breaches\n'
                    '• Criminal liability under RA 10175 for cybersecurity offenses\n'
                    '• Civil liability for damages resulting from misuse\n\n',
              ),

              const TextSpan(
                text: '5. CONSENT DECLARATION\n',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const TextSpan(
                text: 'By accepting these terms, you affirm:\n'
                    '• Understanding of your responsibilities under Philippine law\n'
                    '• Consent to lawful processing of your personal data\n'
                    '• Agreement to comply with all system security protocols\n'
                    '• Acceptance of legal accountability for violations\n\n',
              ),

              TextSpan(
                text: 'DECLINING TERMS\n',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.red[700],
                ),
              ),
              TextSpan(
                text: 'If you cannot comply with these terms, you must decline access. '
                    'Unauthorized use or continued access without agreement may result in legal action. '
                    '\n\nPlease scroll to the bottom to accept or decline the terms.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollPrompt() {
    return AnimatedOpacity(
      opacity: _showButtons ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_downward, size: 16, color: Colors.orange[700]),
            const SizedBox(width: 8),
            Text(
              "Scroll to continue",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.orange[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      offset: _showButtons ? Offset.zero : const Offset(0, 1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: _showButtons ? 1.0 : 0.0,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.grey[400]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _handleRejectTerms(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                onPressed: () => _handleAcceptTerms(context),
                child: const Text(
                  "I Agree",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onWillPop(context),
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2C5282),
                Color(0xFF3182CE),
                Color(0xFFE3F2FD),
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Card(
                  elevation: 16,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Colors.white,
                  shadowColor: Colors.black.withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        _buildLegalComplianceNotice(),
                        const SizedBox(height: 20),
                        _buildTermsContent(),
                        const SizedBox(height: 16),
                        _buildScrollPrompt(),
                        const SizedBox(height: 16),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}