import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/money.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/employee.dart';
import 'employees_controller.dart';

/// Add (employeeId == null) or edit an employee.
class EmployeeFormScreen extends ConsumerWidget {
  const EmployeeFormScreen({super.key, this.employeeId});

  final String? employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (employeeId == null) {
      return const _EmployeeForm();
    }

    final employeesAsync = ref.watch(employeeListProvider);
    final employee = ref.watch(employeeByIdProvider(employeeId!));

    return employeesAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (Object error, StackTrace stack) => Scaffold(
        appBar: AppBar(title: const Text('Edit Employee')),
        body: ErrorView(
          error: error,
          onRetry: () => ref.read(employeeListProvider.notifier).refresh(),
        ),
      ),
      data: (_) => employee == null
          ? Scaffold(
              appBar: AppBar(title: const Text('Edit Employee')),
              body: const EmptyState(
                icon: Icons.person_search_outlined,
                title: 'Employee not found',
                message: 'This employee may have been deleted.',
              ),
            )
          : _EmployeeForm(employee: employee),
    );
  }
}

class _EmployeeForm extends ConsumerStatefulWidget {
  const _EmployeeForm({this.employee});

  final Employee? employee;

  @override
  ConsumerState<_EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends ConsumerState<_EmployeeForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _addressController;
  late final TextEditingController _salaryController;

  late DateTime _joinedOn;
  late bool _isActive;
  late SalaryType _salaryType;

  bool _submitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.employee != null;

  @override
  void initState() {
    super.initState();
    final employee = widget.employee;
    _nameController = TextEditingController(text: employee?.name ?? '');
    _mobileController = TextEditingController(text: employee?.mobile ?? '');
    _addressController = TextEditingController(text: employee?.address ?? '');
    _salaryController = TextEditingController(
      text: (employee?.salaryAmount == null)
          ? ''
          : Money.plain(employee!.salaryAmount!).replaceAll(',', ''),
    );
    _joinedOn = employee?.joinedOn ?? AppDate.today();
    _isActive = employee?.isActive ?? true;
    _salaryType = employee?.salaryType ?? SalaryType.perDay;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  /// The live "≈ ₹X/day" hint shown under a monthly wage.
  String? get _derivedRateHint {
    final amount = Validators.parseAmount(_salaryController.text);
    if (amount == null || amount <= 0) return null;
    if (_salaryType == SalaryType.monthly) {
      return '≈ ${Money.format(amount / Employee.daysInSalaryMonth)} per day';
    }
    return '≈ ${Money.format(amount * Employee.daysInSalaryMonth)} per month';
  }

  Future<void> _pickJoiningDate() async {
    final now = AppDate.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinedOn.isAfter(now) ? now : _joinedOn,
      firstDate: DateTime(now.year - 25),
      // Joining dates cannot be in the future.
      lastDate: now,
      helpText: 'Joining date',
    );
    if (picked == null) return;
    setState(() => _joinedOn = AppDate.dateOnly(picked));
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final mobile = _mobileController.text.trim();
    final address = _addressController.text.trim();
    final salaryAmount = Validators.parseAmount(_salaryController.text);

    final draft = Employee(
      id: widget.employee?.id ?? '',
      name: _nameController.text.trim(),
      mobile: mobile.isEmpty ? null : mobile,
      address: address.isEmpty ? null : address,
      isActive: _isEditing ? _isActive : true,
      joinedOn: _joinedOn,
      salaryType: _salaryType,
      salaryAmount: salaryAmount,
    );

    try {
      final controller = ref.read(employeeListProvider.notifier);
      if (_isEditing) {
        await controller.updateEmployee(draft);
      } else {
        await controller.create(draft);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showSuccess(_isEditing ? 'Employee updated' : 'Employee added');
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _confirmHardDelete() async {
    final employee = widget.employee;
    if (employee == null) return;

    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Delete permanently?',
      message:
          'This removes ${employee.name} and their entire attendance history '
          'from every past report. This cannot be undone.\n\n'
          'To keep the history, use Deactivate instead.',
      confirmLabel: 'Delete forever',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(employeeListProvider.notifier).hardDelete(employee.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showSuccess('Employee deleted');
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Employee' : 'Add Employee'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              if (_errorMessage != null) ...<Widget>[
                ErrorBanner(message: _errorMessage!),
                AppSpacing.gapLg,
              ],
              AppCard(
                child: Column(
                  children: <Widget>[
                    TextFormField(
                      controller: _nameController,
                      enabled: !_submitting,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Name *',
                        hintText: 'Ramesh Kumar',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: Validators.employeeName,
                    ),
                    AppSpacing.gapLg,
                    TextFormField(
                      controller: _mobileController,
                      enabled: !_submitting,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      maxLength: 10,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Mobile',
                        hintText: '9876543210',
                        prefixIcon: Icon(Icons.call_outlined),
                        prefixText: '+91 ',
                        counterText: '',
                        helperText: 'Optional. 10 digits, starting 6–9.',
                      ),
                      validator: Validators.mobileOptional,
                    ),
                    AppSpacing.gapLg,
                    TextFormField(
                      controller: _addressController,
                      enabled: !_submitting,
                      maxLines: 3,
                      minLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        alignLabelWithHint: true,
                        helperText: 'Optional',
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.gapCards,
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  children: <Widget>[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: const Text('Joining date'),
                      subtitle: Text(AppDate.display(_joinedOn)),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: _submitting ? null : _pickJoiningDate,
                    ),
                    if (_isEditing) ...<Widget>[
                      Divider(color: context.hairline),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _isActive,
                        onChanged: _submitting
                            ? null
                            : (bool value) => setState(() => _isActive = value),
                        title: const Text('Active'),
                        subtitle: Text(
                          _isActive
                              ? 'Appears in Mark Attendance'
                              : 'Hidden from Mark Attendance',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AppSpacing.gapCards,
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Salary', style: context.text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Optional. Used to work out pay in reports.',
                      style: context.text.bodySmall?.copyWith(
                        color: context.mutedColor,
                      ),
                    ),
                    AppSpacing.gapMd,
                    SegmentedButton<SalaryType>(
                      showSelectedIcon: false,
                      segments: <ButtonSegment<SalaryType>>[
                        for (final SalaryType type in SalaryType.values)
                          ButtonSegment<SalaryType>(
                            value: type,
                            label: Text(type.label),
                          ),
                      ],
                      selected: <SalaryType>{_salaryType},
                      onSelectionChanged: _submitting
                          ? null
                          : (Set<SalaryType> selection) =>
                                setState(() => _salaryType = selection.first),
                    ),
                    AppSpacing.gapLg,
                    TextFormField(
                      controller: _salaryController,
                      enabled: !_submitting,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.]'),
                        ),
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: _salaryType == SalaryType.monthly
                            ? 'Monthly salary'
                            : 'Per-day salary',
                        prefixText: '₹ ',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded),
                        helperText: _derivedRateHint ?? 'Optional',
                      ),
                      validator: Validators.salaryOptional,
                    ),
                  ],
                ),
              ),
              AppSpacing.gapXl,
              PrimaryButton(
                label: _isEditing ? 'Save Changes' : 'Add Employee',
                loading: _submitting,
                onPressed: _save,
              ),
              if (_isEditing) ...<Widget>[
                AppSpacing.gapMd,
                TextButton.icon(
                  onPressed: _submitting ? null : _confirmHardDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Delete permanently'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
