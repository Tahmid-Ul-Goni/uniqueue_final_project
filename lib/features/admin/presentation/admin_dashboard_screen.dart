import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../app/app_colors.dart';
import '../../../core/widgets/flat_states.dart';
import '../../../features/auth/data/auth_service.dart';
import '../../../models/department.dart';
import '../../../services/catalog_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    required this.authService,
    required this.catalogService,
    super.key,
  });

  final AuthService authService;
  final CatalogService catalogService;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedSampleIfEmpty());
  }

  Future<void> _seedSampleIfEmpty() async {
    try {
      await widget.catalogService.ensureSampleCatalogIfEmpty();
      await widget.catalogService.ensureServicesForEmptyDepartments();
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        context,
        'Could not prepare the starter catalog. Check your connection and admin access.',
      );
    }
  }

  String _slug(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  Future<void> _createDepartment(BuildContext context) async {
    final name = TextEditingController();
    final icon = TextEditingController(text: 'domain');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add department'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Department name')),
          const SizedBox(height: 12),
          TextField(
              controller: icon,
              decoration: const InputDecoration(
                  labelText: 'Icon key', hintText: 'domain')),
          const SizedBox(height: 8),
          const Text('A lowercase ID will be generated from the name.'),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (!context.mounted || accepted != true || name.text.trim().isEmpty) {
      name.dispose();
      icon.dispose();
      return;
    }
    final id = _slug(name.text);
    if (id.isEmpty) {
      _showMessage(
          context, 'Use a department name with English letters or numbers.');
      name.dispose();
      icon.dispose();
      return;
    }
    try {
      await widget.catalogService.createDepartment(
        id: id,
        name: name.text.trim(),
        iconKey: icon.text.trim().isEmpty ? 'domain' : icon.text.trim(),
      );
      if (!context.mounted) return;
      _showMessage(context, 'Department created.');
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, _friendlyError(error));
    } finally {
      name.dispose();
      icon.dispose();
    }
  }

  Future<void> _createService(
      BuildContext context, List<Department> departments) async {
    if (departments.isEmpty) {
      _showMessage(context, 'Create a department first.');
      return;
    }
    final name = TextEditingController();
    final prefix = TextEditingController(text: 'Q');
    final average = TextEditingController(text: '5');
    final grace = TextEditingController(text: '5');
    final hold = TextEditingController(text: '10');
    var departmentId = departments.first.id;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add queue service'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: departmentId,
                elevation: 0,
                decoration: const InputDecoration(labelText: 'Department'),
                items: departments
                    .map((item) => DropdownMenuItem(
                        value: item.id, child: Text(item.name)))
                    .toList(growable: false),
                onChanged: (value) =>
                    setDialogState(() => departmentId = value ?? departmentId),
              ),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Service name')),
              TextField(
                controller: prefix,
                maxLength: 3,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Token prefix'),
              ),
              _numberField(average, 'Average service time (minutes)'),
              _numberField(grace, 'Grace period (minutes)'),
              _numberField(hold, 'Hold window (minutes)'),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Create')),
          ],
        ),
      ),
    );
    if (!context.mounted || accepted != true || name.text.trim().isEmpty) {
      name.dispose();
      prefix.dispose();
      average.dispose();
      grace.dispose();
      hold.dispose();
      return;
    }
    final avg = int.tryParse(average.text) ?? 0;
    final graceMinutes = int.tryParse(grace.text) ?? 0;
    final holdMinutes = int.tryParse(hold.text) ?? 0;
    final tokenPrefix = prefix.text.trim().toUpperCase();
    if (avg < 1 || graceMinutes < 1 || holdMinutes < 1 || tokenPrefix.isEmpty) {
      _showMessage(context, 'Enter a name, prefix, and positive time values.');
      name.dispose();
      prefix.dispose();
      average.dispose();
      grace.dispose();
      hold.dispose();
      return;
    }
    try {
      await widget.catalogService.createService(
        id: _slug('$departmentId-${name.text}'),
        departmentId: departmentId,
        name: name.text.trim(),
        prefix: tokenPrefix,
        averageServiceTime: avg,
        gracePeriodMin: graceMinutes,
        holdWindowMin: holdMinutes,
      );
      if (!context.mounted) return;
      _showMessage(context, 'Queue service created.');
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, _friendlyError(error));
    } finally {
      name.dispose();
      prefix.dispose();
      average.dispose();
      grace.dispose();
      hold.dispose();
    }
  }

  Future<void> _createProfile(
      BuildContext context, List<Department> departments) async {
    final uid = TextEditingController();
    final name = TextEditingController();
    final email = TextEditingController();
    var role = 'receptionist';
    var departmentId = departments.isEmpty ? null : departments.first.id;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add staff profile'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(
                  'First create this account in Firebase Authentication, then copy its UID here.'),
              TextField(
                  controller: uid,
                  decoration: const InputDecoration(labelText: 'Firebase UID')),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Full name')),
              TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email')),
              DropdownButtonFormField<String>(
                initialValue: role,
                elevation: 0,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(
                      value: 'receptionist', child: Text('Receptionist')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) =>
                    setDialogState(() => role = value ?? role),
              ),
              if (role == 'receptionist')
                DropdownButtonFormField<String>(
                  initialValue: departmentId,
                  elevation: 0,
                  decoration:
                      const InputDecoration(labelText: 'Assigned department'),
                  items: departments
                      .map((item) => DropdownMenuItem(
                          value: item.id, child: Text(item.name)))
                      .toList(growable: false),
                  onChanged: (value) => setDialogState(
                      () => departmentId = value ?? departmentId),
                ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Create staff profile')),
          ],
        ),
      ),
    );
    if (!context.mounted || accepted != true) {
      uid.dispose();
      name.dispose();
      email.dispose();
      return;
    }
    if (uid.text.trim().isEmpty ||
        name.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        (role == 'receptionist' && departmentId == null)) {
      _showMessage(context, 'Complete all required profile fields.');
      uid.dispose();
      name.dispose();
      email.dispose();
      return;
    }
    try {
      await widget.catalogService.createUserProfile(
        userId: uid.text.trim(),
        name: name.text.trim(),
        email: email.text.trim(),
        role: role,
        departmentId: departmentId,
      );
      if (!context.mounted) return;
      _showMessage(context, 'User profile created.');
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, _friendlyError(error));
    } finally {
      uid.dispose();
      name.dispose();
      email.dispose();
    }
  }

  Widget _numberField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      );

  String _friendlyError(Object error) {
    if (error is StateError) return error.message;
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Admin access was denied. Check that users/{your UID} has role "admin" and that the Firestore rules are deployed.';
    }
    return 'Could not save this item. Check the connection and try again.';
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createDemoCatalog(BuildContext context) async {
    try {
      await widget.catalogService.createDemoCatalog();
      if (!context.mounted) return;
      _showMessage(context, 'Sample department and service added.');
    } catch (_) {
      if (!context.mounted) return;
      _showMessage(context,
          'Could not add the sample catalog. Check your connection and admin access.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('UniQueue admin'),
          actions: [
            IconButton(
              tooltip: 'Log out',
              onPressed: widget.authService.signOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          onPressed: () => _createDepartment(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Department'),
        ),
        body: StreamBuilder<List<Department>>(
          stream: widget.catalogService.watchDepartments(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                title: 'Could not load departments',
                onRetry: () => (context as Element).markNeedsBuild(),
              );
            }
            if (!snapshot.hasData) {
              return const ListSkeleton(count: 4);
            }
            final departments = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                const Text('Manage your queue setup',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                    'Departments get a starter service automatically. Students sign up themselves; staff profiles are only needed for receptionist or admin access.',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    onPressed: () => _createService(context, departments),
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Add service'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _createProfile(context, departments),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Add staff profile'),
                  ),
                ]),
                const SizedBox(height: 16),
                if (departments.isEmpty)
                  _EmptyCatalogCard(
                      onCreateDemo: () => _createDemoCatalog(context)),
                ...departments.map((department) => _DepartmentCard(
                      department: department,
                      catalogService: widget.catalogService,
                    )),
              ],
            );
          },
        ),
      );
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard(
      {required this.department, required this.catalogService});

  final Department department;
  final CatalogService catalogService;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(department.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('ID: ${department.id}',
                style: const TextStyle(color: AppColors.textSecondary)),
            StreamBuilder(
              stream: catalogService.watchDepartmentServices(department.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorState(
                    title: 'Could not load services',
                    onRetry: () => (context as Element).markNeedsBuild(),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: FlatSkeleton(height: 48),
                  );
                }
                final services = snapshot.data!;
                if (services.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('No services yet.'),
                  );
                }
                return Column(
                  children: services
                      .map((service) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.confirmation_number,
                                color: AppColors.red),
                            title: Text(service.name),
                            subtitle: Text(
                                '${service.prefix} · ${service.averageServiceTime} min · ${service.counterStatus}'),
                            trailing: Text('${service.lastTokenNumber} issued'),
                          ))
                      .toList(growable: false),
                );
              },
            ),
          ]),
        ),
      );
}

class _EmptyCatalogCard extends StatelessWidget {
  const _EmptyCatalogCard({required this.onCreateDemo});

  final VoidCallback onCreateDemo;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('No departments yet',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
              'Add your real departments, or load a sample Finance Office queue to preview the student flow.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onCreateDemo,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Add sample department + service'),
          ),
        ]),
      );
}
