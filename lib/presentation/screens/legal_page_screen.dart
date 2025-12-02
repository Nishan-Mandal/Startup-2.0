import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalPageScreen extends StatelessWidget {
  final String pageId; // e.g., "about_us", "privacy_policy"

  const LegalPageScreen({Key? key, required this.pageId}) : super(key: key);

    bool _isInternalLink(String url) {
    // treat links starting with "/" as internal routes
    return url.startsWith('/');
  }

  String _normalizeUrl(String url) {
    if (url.trim().isEmpty) return url;
    // Add scheme if missing for external links (not internal '/...' routes)
    if (_isInternalLink(url)) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'https://$url';
    }
    return url;
  }

  Future<void> _openExternalUrl(String url, BuildContext context) async {
    final normalized = _normalizeUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid URL')),
      );
      return;
    }

    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open link')),
      );
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection("pages").doc(pageId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final title = data["title"] ?? "Info";
          final content = data["content"] ?? "No content available.";

          return Scaffold(
            appBar: AppBar(
              iconTheme: IconThemeData(color: AppColors.WHITE),
              title: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.WHITE,
                ),
              ),
              centerTitle: true,
              backgroundColor: AppColors.THEME_COLOR,
            ),
            body: SingleChildScrollView(
              child: Html(
                data: content,
                onLinkTap: (url, _, __) async {
                  if (url == null) return;

                  if (_isInternalLink(url)) {
                    final pageId = url.replaceFirst('/', '');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LegalPageScreen(pageId: pageId),
                      ),
                    );
                    return;
                  }

                  await _openExternalUrl(url, context);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
