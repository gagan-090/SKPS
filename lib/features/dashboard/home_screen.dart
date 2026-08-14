import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/employee_avatar.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/day_summary.dart';
import '../attendance/sync_controller.dart';
import 'dashboard_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          AppSpacing.wGapXs,
        ],
      ),
      body: dashboard.when(
        loading: () => const _DashboardSkeleton(),
        error: (Object error, StackTrace stack) => RefreshIndicator(
          onRefresh: () => refreshDashboard(ref),
          child: ListView(
            children: <Widget>[
              SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
              ErrorView(error: error, onRetry: () => refreshDashboard(ref)),
            ],
          ),
        ),
        data: (DashboardData data) => RefreshIndicator(
          onRefresh: () => refreshDashboard(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              const _PendingSyncBanner(),
              _TodayCard(data: data),
              AppSpacing.gapCards,
              if (data.hasEmployees) ...<Widget>[
                _StatRow(summary: data.today),
                AppSpacing.gapCards,
                _MonthCard(data: data),
              ] else
                const _NoEmployeesCard(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown while attendance is still sitting in the offline outbox.
///
/// Reaching Home is the most reliable "we might be online again" signal
/// available without a connectivity plugin, so this also retries the flush
/// once per mount.
class _PendingSyncBanner extends ConsumerStatefulWidget {
  const _PendingSyncBanner();

  @override
  ConsumerState<_PendingSyncBanner> createState() => _PendingSyncBannerState();
}

class _PendingSyncBannerState extends ConsumerState<_PendingSyncBanner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(syncProvider.notifier);
      controller.refreshCount();
      controller.flush();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncProvider);
    if (!sync.hasPending) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        color: context.colors.primaryContainer,
        borderColor: context.colors.primary.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.cloud_upload_outlined,
              size: 20,
              color: context.colors.onPrimaryContainer,
            ),
            AppSpacing.wGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${sync.pending} pending sync',
                    style: context.text.labelLarge?.copyWith(
                      color: context.colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sync.lastError ??
                        'Saved on this phone. It will upload automatically.',
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            AppSpacing.wGapSm,
            if (sync.syncing)
              const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton(
                onPressed: () => ref.read(syncProvider.notifier).flush(),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.onPrimaryContainer,
                ),
                child: const Text('Sync now'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final summary = data.today;
    final marked = summary.isMarked;
    final markedAt = summary.lastMarkedAt;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: context.colors.primaryContainer,
                  borderRadius: AppRadius.buttonRadius,
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  size: 20,
                  color: context.colors.onPrimaryContainer,
                ),
              ),
              AppSpacing.wGapMd,
              Expanded(
                child: Text(
                  AppDate.displayLong(data.day),
                  maxLines: 2,
                  style: context.text.titleMedium,
                ),
              ),
            ],
          ),
          AppSpacing.gapLg,
          if (!data.hasEmployees)
            Text(
              'Add employees to start marking attendance.',
              style: context.text.bodyMedium?.copyWith(
                color: context.mutedColor,
              ),
            )
          else ...<Widget>[
            Text(
              marked
                  ? (summary.isComplete
                        ? 'All ${summary.totalActive} marked'
                        : '${summary.marked} of ${summary.totalActive} marked')
                  : 'Attendance not marked yet',
              style: context.text.headlineSmall,
            ),
            AppSpacing.gapXs,
            Text(
              marked && markedAt != null
                  ? 'Last saved at ${AppDate.time(markedAt)}'
                  : 'Takes less than a minute',
              style: context.text.bodySmall,
            ),
            AppSpacing.gapLg,
            PrimaryButton(
              label: marked
                  ? 'Edit Today\'s Attendance'
                  : 'Mark Today\'s Attendance',
              icon: marked ? Icons.edit_outlined : Icons.how_to_reg_rounded,
              onPressed: () => context.push(AppRoutes.attendanceFor(data.day)),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _StatTile(
        label: 'Employees',
        value: summary.totalActive,
        color: context.colors.primary,
      ),
      _StatTile(
        label: 'Present',
        value: summary.present,
        color: AppColors.present,
      ),
      _StatTile(
        label: 'Absent',
        value: summary.absent,
        color: AppColors.absent,
      ),
      _StatTile(
        label: 'Not Marked',
        value: summary.notMarked,
        color: AppColors.notMarked,
      ),
    ];

    return Row(
      children: <Widget>[
        for (int i = 0; i < tiles.length; i++) ...<Widget>[
          if (i > 0) AppSpacing.wGapSm,
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: <Widget>[
          Text(
            '$value',
            style: context.text.headlineSmall?.copyWith(
              color: color,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.text.labelSmall?.copyWith(color: context.mutedColor),
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final top = data.tallies.take(5).toList();
    final monthLabel = AppDate.monthYear(data.day.year, data.day.month);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: monthLabel,
            action: TextButton(
              onPressed: () => context.go(AppRoutes.reports),
              child: const Text('View all'),
            ),
          ),
          Text(
            data.daysMarkedThisMonth == 0
                ? 'No days marked yet this month'
                : '${data.daysMarkedThisMonth} '
                      '${data.daysMarkedThisMonth == 1 ? 'day' : 'days'} marked',
            style: context.text.bodyMedium?.copyWith(color: context.mutedColor),
          ),
          if (top.isNotEmpty) ...<Widget>[
            AppSpacing.gapLg,
            for (int i = 0; i < top.length; i++) ...<Widget>[
              if (i > 0)
                Divider(color: context.hairline, height: AppSpacing.xl),
              _TallyRow(tally: top[i]),
            ],
          ],
        ],
      ),
    );
  }
}

class _TallyRow extends StatelessWidget {
  const _TallyRow({required this.tally});

  final MonthTally tally;

  @override
  Widget build(BuildContext context) {
    final days = tally.effectiveDays;
    final label = days == days.roundToDouble()
        ? days.toStringAsFixed(0)
        : days.toStringAsFixed(1);

    return Row(
      children: <Widget>[
        EmployeeAvatar(name: tally.employee.name, size: 34),
        AppSpacing.wGapMd,
        Expanded(
          child: Text(
            tally.employee.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyLarge,
          ),
        ),
        AppSpacing.wGapSm,
        Text(
          '$label ${days == 1 ? 'day' : 'days'}',
          style: context.text.labelLarge?.copyWith(
            color: AppColors.present,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _NoEmployeesCard extends StatelessWidget {
  const _NoEmployeesCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: EmptyState(
        icon: Icons.people_outline_rounded,
        compact: true,
        title: 'No employees yet',
        message: 'Add your staff to start marking attendance.',
        actionLabel: 'Add Employee',
        onAction: () => context.push(AppRoutes.employeeNew),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Skeleton(height: 18, width: 200),
              AppSpacing.gapLg,
              Skeleton(height: 26, width: 160),
              AppSpacing.gapMd,
              Skeleton(height: 52, radius: AppRadius.button),
            ],
          ),
        ),
        AppSpacing.gapCards,
        Row(
          children: <Widget>[
            for (int i = 0; i < 4; i++) ...<Widget>[
              if (i > 0) AppSpacing.wGapSm,
              const Expanded(
                child: Skeleton(height: 74, radius: AppRadius.card),
              ),
            ],
          ],
        ),
        AppSpacing.gapCards,
        const Skeleton(height: 180, radius: AppRadius.card),
      ],
    );
  }
}
