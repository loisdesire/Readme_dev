import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/league_helper.dart';

class LeagueWidget extends StatelessWidget {
  final int totalPoints;
  final bool showProgress;
  final bool compact;

  const LeagueWidget({
    super.key,
    required this.totalPoints,
    this.showProgress = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final league = LeagueHelper.getLeague(totalPoints);
    final leagueName = LeagueHelper.getLeagueName(league);
    final leagueEmoji = LeagueHelper.getLeagueEmoji(league);
    final leagueColor = Color(LeagueHelper.getLeagueColor(league));
    final pointsToNext = LeagueHelper.getPointsToNextLeague(totalPoints);
    final progress = LeagueHelper.getProgressToNextLeague(totalPoints);
    final isMaxLeague = league == League.diamond;

    if (compact) {
      return _buildCompactWidget(leagueName, leagueEmoji, leagueColor);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            leagueColor.withValues(alpha: 0.2),
            leagueColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: leagueColor.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // League header
          Row(
            children: [
              Text(
                leagueEmoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$leagueName League',
                      style: AppTheme.heading.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalPoints points',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textGray,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (showProgress && !isMaxLeague) ...[
            const SizedBox(height: 16),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: leagueColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(leagueColor),
                minHeight: 8,
              ),
            ),

            const SizedBox(height: 8),

            // Next league info
            Text(
              '$pointsToNext points to ${LeagueHelper.getLeagueName(League.values[league.index + 1])} League',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textGray,
                fontSize: 12,
              ),
            ),
          ] else if (isMaxLeague) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: leagueColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: AppTheme.accentGold, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Maximum League Reached!',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactWidget(
      String leagueName, String leagueEmoji, Color leagueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: leagueColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: leagueColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(leagueEmoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            leagueName,
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.black,
            ),
          ),
        ],
      ),
    );
  }
}
