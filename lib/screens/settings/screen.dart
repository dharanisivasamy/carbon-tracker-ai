import 'package:carbon_tracker/core/routes/app_routes.dart';
import 'package:carbon_tracker/core/theme/app_colors.dart';
import 'package:carbon_tracker/core/theme/spacing.dart';
import 'package:carbon_tracker/core/theme/text_styles.dart';
import 'package:carbon_tracker/widgets/cards/app_card.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carbon_tracker/services/auth/auth_service.dart';
import 'package:carbon_tracker/services/api/api_service.dart';
import 'package:carbon_tracker/repositories/trip_repository.dart';
import 'package:carbon_tracker/repositories/labelled_window_repository.dart';

class SettingsScreen extends StatefulWidget { const SettingsScreen({super.key}); @override State<SettingsScreen> createState() => _SettingsScreenState(); }
class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true, darkMode = false, miles = false;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); if (mounted) setState(() { notifications = p.getBool('notifications') ?? true; darkMode = p.getBool('dark_mode') ?? false; miles = p.getBool('miles') ?? false; }); }
  Future<void> _save(String key, bool value) async => (await SharedPreferences.getInstance()).setBool(key, value);
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text('Settings', style: AppTextStyles.title)), body: SafeArea(top: false, child: ListView(padding: const EdgeInsets.all(AppSpacing.xl), children: [Text('Account', style: AppTextStyles.title), InfoCard(child: Column(children: [_tile(Icons.person_outline, 'Profile', () => Navigator.pushNamed(context, AppRoutes.profile)), _tile(Icons.edit_outlined, 'Edit Profile', () => Navigator.pushNamed(context, AppRoutes.profile))])), const SizedBox(height: AppSpacing.xl), Text('Preferences', style: AppTextStyles.title), InfoCard(child: Column(children: [SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Notifications'), value: notifications, onChanged: (v) { setState(() => notifications = v); _save('notifications', v); }), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Dark mode'), value: darkMode, onChanged: (v) { setState(() => darkMode = v); _save('dark_mode', v); }), SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Distance unit: ${miles ? 'miles' : 'km'}'), value: miles, onChanged: (v) { setState(() => miles = v); _save('miles', v); })])), const SizedBox(height: AppSpacing.xl), OutlinedButton.icon(onPressed: _deleteMyData, icon: const Icon(Icons.delete_forever, color: AppColors.error), label: const Text('Delete my data', style: TextStyle(color: AppColors.error))), OutlinedButton.icon(onPressed: () async { await AuthService.instance.logout(); if (context.mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false); }, icon: const Icon(Icons.logout, color: AppColors.error), label: const Text('Logout', style: TextStyle(color: AppColors.error)))])));
  Future<void> _deleteMyData() async { final ok=await showDialog<bool>(context: context,builder:(_)=>AlertDialog(title:const Text('Delete all data?'),content:const Text('This permanently deletes your trips and locally stored training windows.'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Delete'))])); if(ok!=true)return; final token=await AuthService.instance.token; if(token!=null){try{await ApiService.instance.deleteMyData(token);}catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Server deletion failed; local data was kept.')));return;}} await TripRepository.instance.clear(); await LabelledWindowRepository.instance.clear(); if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Your local and server trip data was deleted.'))); }
  Widget _tile(IconData icon, String label, VoidCallback action) => ListTile(contentPadding: EdgeInsets.zero, leading: Icon(icon, color: AppColors.darkGreen), title: Text(label), trailing: const Icon(Icons.chevron_right), onTap: action);
  void _dialog(String title) => showDialog<void>(context: context, builder: (_) => AlertDialog(title: Text(title), content: const Text('This page will be available in a future update.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]));
}
