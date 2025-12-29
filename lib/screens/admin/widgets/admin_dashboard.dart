import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: AppTheme.logoSmall.copyWith(color: AppTheme.black87),
        ),
        const SizedBox(height: 4),
        Text(
          'Overview of your ReadMe library',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textGray),
        ),
        const SizedBox(height: 32),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('books').snapshots(),
          builder: (context, booksSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, usersSnapshot) {
                if (!booksSnapshot.hasData || !usersSnapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryPurple),
                  );
                }

                final books = booksSnapshot.data!.docs;
                final users = usersSnapshot.data!.docs;

                final totalBooks = books.length;
                final totalUsers = users.length;
                final needsTagging = books.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['needsTagging'] == true;
                }).length;
                final missingPdf = books.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['pdfUrl'] == null || data['pdfUrl'] == '';
                }).length;

                // Books by age rating
                final Map<String, int> ageRatingCounts = {};
                for (var doc in books) {
                  final data = doc.data() as Map<String, dynamic>;
                  final ageRating = data['ageRating']?.toString() ?? 'Unknown';
                  ageRatingCounts[ageRating] = (ageRatingCounts[ageRating] ?? 0) + 1;
                }

                // Recent books
                final recentBooks = books
                    .where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['createdAt'] != null;
                    })
                    .map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return {
                        'id': doc.id,
                        'title': data['title'],
                        'author': data['author'],
                        'ageRating': data['ageRating'],
                        'createdAt': data['createdAt'],
                      };
                    })
                    .toList()
                  ..sort((a, b) {
                    final aTime = (a['createdAt'] as Timestamp).toDate();
                    final bTime = (b['createdAt'] as Timestamp).toDate();
                    return bTime.compareTo(aTime);
                  });

                return Column(
                  children: [
                    // Stats Cards
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Total Books',
                            value: totalBooks.toString(),
                            icon: Icons.menu_book_rounded,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            title: 'Total Users',
                            value: totalUsers.toString(),
                            icon: Icons.group_rounded,
                            color: AppTheme.successGreen,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            title: 'Needs Tagging',
                            value: needsTagging.toString(),
                            icon: Icons.warning_amber_rounded,
                            color: AppTheme.secondaryYellow,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            title: 'Missing PDF',
                            value: missingPdf.toString(),
                            icon: Icons.picture_as_pdf_rounded,
                            color: AppTheme.errorRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Charts
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ChartCard(
                            title: 'Books by Age Rating',
                            child: ageRatingCounts.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Text(
                                        'No books yet',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: AppTheme.textGray,
                                        ),
                                      ),
                                    ),
                                  )
                                : _buildPieChart(ageRatingCounts),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ChartCard(
                            title: 'Recent Books',
                            child: recentBooks.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Text(
                                        'No books uploaded yet',
                                        style: AppTheme.bodySmall.copyWith(
                                          color: AppTheme.textGray,
                                        ),
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: recentBooks.take(5).map((book) {
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.lightGray,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppTheme.borderGray),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    book['title'] ?? '',
                                                    style: AppTheme.bodyMedium.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${book['author']} • ${book['ageRating'] ?? 'N/A'}',
                                                    style: AppTheme.bodySmall.copyWith(
                                                      color: AppTheme.textGray,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Quick Tips
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurpleOpaque10,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryLighter),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '💡 Quick Tips',
                            style: AppTheme.heading.copyWith(
                              color: AppTheme.primaryPurple,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildTip('Upload books with PDFs for the best reading experience'),
                          const SizedBox(height: 8),
                          _buildTip('Use AI Tagging to automatically categorize books with traits'),
                          const SizedBox(height: 8),
                          _buildTip('Check Cloud Functions to trigger AI recommendations for users'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildTip(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4, right: 8),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: AppTheme.primaryPurple,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textGray),
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart(Map<String, int> data) {
    final colors = [
      AppTheme.primaryPurple,
      AppTheme.primaryLight,
      AppTheme.successGreen,
      AppTheme.secondaryYellow,
      AppTheme.errorRed,
      AppTheme.warningOrange,
    ];

    int index = 0;
    final sections = data.entries.map((entry) {
      final color = colors[index % colors.length];
      index++;
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: entry.key,
        color: color,
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      );
    }).toList();

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 0,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGray),
        boxShadow: AppTheme.defaultCardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodySmall.copyWith(color: AppTheme.textGray),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: AppTheme.logoSmall.copyWith(
                    color: AppTheme.black87,
                    fontSize: 32,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGray),
        boxShadow: AppTheme.defaultCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.heading.copyWith(color: AppTheme.black87),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
