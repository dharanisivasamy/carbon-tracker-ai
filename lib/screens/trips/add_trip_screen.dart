import 'package:carbon_tracker/core/routes/app_routes.dart';
import 'package:carbon_tracker/core/theme/app_colors.dart';
import 'package:carbon_tracker/core/theme/spacing.dart';
import 'package:carbon_tracker/core/theme/text_styles.dart';
import 'package:carbon_tracker/models/trip_model.dart';
import 'package:carbon_tracker/repositories/trip_repository.dart';
import 'package:carbon_tracker/services/api/api_service.dart';
import 'package:carbon_tracker/services/auth/auth_service.dart';
import 'package:carbon_tracker/utils/app_logger.dart';
import 'package:carbon_tracker/widgets/buttons/app_button.dart';
import 'package:carbon_tracker/widgets/common/app_text_fields.dart';
import 'package:flutter/material.dart';

class AddTripScreen extends StatefulWidget {
  const AddTripScreen({super.key});

  @override
  State<AddTripScreen> createState() => _AddTripScreenState();
}

class _AddTripScreenState extends State<AddTripScreen> {
  final _distanceController = TextEditingController();
  final _notesController = TextEditingController();
  late final TextEditingController _dateController;
  TransportMode _selectedMode = TransportMode.walking;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(DateTime.now());
    _dateController = TextEditingController(text: _formatDate(_selectedDate));
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  double get _distance => double.tryParse(_distanceController.text.trim()) ?? 0;

  double get _estimatedCarbon => _distance * _selectedMode.emissionFactor;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: Text('Add Trip', style: AppTextStyles.title),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Transport Mode', style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.md),
                    _TransportModeGrid(
                      selectedMode: _selectedMode,
                      onSelected: (mode) => setState(() => _selectedMode = mode),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text('Distance', style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Distance',
                      hint: 'Enter distance',
                      suffixText: 'km',
                      controller: _distanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Date', style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Date',
                      controller: _dateController,
                      prefixIcon: Icons.calendar_today_outlined,
                      readOnly: true,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Notes', style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      label: 'Notes (optional)',
                      hint: 'Add any details about this trip',
                      prefixIcon: Icons.notes_rounded,
                      minLines: 3,
                      maxLines: 4,
                      controller: _notesController,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _EstimatedCarbonCard(carbon: _estimatedCarbon),
                    const SizedBox(height: AppSpacing.xl),
                    AppOutlinedButton(
                      label: 'Calculate',
                      icon: Icons.calculate_outlined,
                      onPressed: () => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    LoadingButton(label: 'Save Trip', isLoading: _isSaving, onPressed: _saveTrip),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (pickedDate == null || !mounted) return;
    setState(() {
      _selectedDate = pickedDate;
      _dateController.text = _formatDate(pickedDate);
    });
  }

  Future<void> _saveTrip() async {
    if (_isSaving) return;
    if (_distance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a distance greater than zero.')),
      );
      return;
    }
    final notes = _notesController.text.trim();
    setState(() => _isSaving = true);
    var savedOffline = false;
    String? serverId;
    try {
      final token = await AuthService.instance.token;
      if (token != null) {
        final response = await ApiService.instance.createTrip(mode: _selectedMode.name, distance: _distance, date: _selectedDate, notes: notes.isEmpty ? null : notes, token: token);
        serverId = (response['data'] as Map<String, dynamic>?)?['_id'] as String?;
      } else { savedOffline = true; }
    } catch (e) {
      // Backend unavailable or request failed - intentional offline
      // fallback, the trip is still saved locally below.
      logDebug('[TRIPS] Add trip failed, saving offline: $e');
      savedOffline = true;
    }
    await TripRepository.instance.add(
      TripModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        transportMode: _selectedMode,
        distance: _distance,
        carbonEmission: _estimatedCarbon,
        date: _selectedDate,
        notes: notes.isEmpty ? null : notes,
        serverId: serverId,
        synced: serverId != null,
      ),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.dashboard,
      (route) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(savedOffline ? 'Trip saved offline' : 'Trip saved successfully')),
    );
  }
}

class _TransportModeGrid extends StatelessWidget {
  const _TransportModeGrid({required this.selectedMode, required this.onSelected});

  final TransportMode selectedMode;
  final ValueChanged<TransportMode> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 560 ? 4 : 2;
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.65,
            children: TransportMode.values
                .map(
                  (mode) => _TransportModeCard(
                    mode: mode,
                    isSelected: mode == selectedMode,
                    onTap: () => onSelected(mode),
                  ),
                )
                .toList(),
          );
        },
      );
}

class _TransportModeCard extends StatelessWidget {
  const _TransportModeCard({required this.mode, required this.isSelected, required this.onTap});

  final TransportMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: isSelected ? const Color(0xFFE0F7E9) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_modeIcon(mode), color: isSelected ? AppColors.darkGreen : AppColors.secondaryText),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  mode.label,
                  style: AppTextStyles.caption.copyWith(
                    color: isSelected ? AppColors.darkGreen : AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _EstimatedCarbonCard extends StatelessWidget {
  const _EstimatedCarbonCard({required this.carbon});

  final double carbon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F7E9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.co2_outlined, size: 32, color: AppColors.darkGreen),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Estimated Carbon', style: AppTextStyles.body.copyWith(color: AppColors.darkGreen)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text('${carbon.toStringAsFixed(2)} kg CO₂', style: AppTextStyles.title),
                ],
              ),
            ),
          ],
        ),
      );
}

IconData _modeIcon(TransportMode mode) => switch (mode) {
      TransportMode.walking => Icons.directions_walk_rounded,
      TransportMode.cycling => Icons.directions_bike_rounded,
      TransportMode.bike => Icons.two_wheeler_rounded,
      TransportMode.car => Icons.directions_car_rounded,
      TransportMode.bus => Icons.directions_bus_rounded,
      TransportMode.train => Icons.train_rounded,
      TransportMode.flight => Icons.flight_rounded,
    };

String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
