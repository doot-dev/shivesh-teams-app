import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/tech_api_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/order_models.dart';
import '../../providers/orders_providers.dart';
import 'order_details_page.dart' show serverMessage;

typedef _Product = ({String name, String grade, String unit});

/// Book an order for one of this technician's projects (2026-09-28). The
/// server tells the office, the client and the project's other FTs.
/// Client first, then one of that client's projects (2026-10-02).
class NewOrderPage extends ConsumerStatefulWidget {
  const NewOrderPage({super.key});

  @override
  ConsumerState<NewOrderPage> createState() => _NewOrderPageState();
}

class _NewOrderPageState extends ConsumerState<NewOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _qty = TextEditingController();
  final _address = TextEditingController();
  String? _clientId;
  TechProject? _project;
  _Product? _product;
  DateTime? _date;
  TimeOfDay? _time;
  bool _saving = false;

  @override
  void dispose() {
    _qty.dispose();
    _address.dispose();
    super.dispose();
  }

  /// A new client clears the project, product and address.
  void _pickClient(String? id, List<TechProject> all) {
    if (id == _clientId) return;
    final mine = all.where((p) => p.clientId == id).toList();
    setState(() => _clientId = id);
    // One project for this client: nothing to choose.
    _pickProject(mine.length == 1 ? mine.first : null);
  }

  void _pickProject(TechProject? p) => setState(() {
    _project = p;
    // One product on the project: nothing to choose.
    _product = p != null && p.products.length == 1 ? p.products.first : null;
    _address.text = p?.address ?? '';
  });

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)), // the server allows 3 months
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (t != null) setState(() => _time = t);
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _saving = true);
    try {
      final code = await ref
          .read(techApiProvider)
          .createOrder(
            projectId: _project!.projectId,
            productName: _product!.name,
            productGrade: _product!.grade,
            quantity: _qty.text.trim(),
            date: DateFormat('yyyy-MM-dd').format(_date!),
            time: _time == null ? null : _hhmm(_time!),
            deliveryAddress: _address.text.trim().isEmpty
                ? null
                : _address.text.trim(),
          );
      ref.invalidate(activeOrdersProvider);
      ref.invalidate(searchedOrdersProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Order $code placed')));
      context.pushReplacement('/orders/$code');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(serverMessage(e, 'Could not place the order')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(myProjectsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: const BackButton(color: AppColors.textPrimary),
        title: const Text('New order'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myProjectsProvider.future),
        child: projects.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [Text(serverMessage(e, 'Could not load your projects'))],
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  Text(
                    'You are not on any project yet. Ask the office to add you to one.',
                  ),
                ],
              );
            }
            // Clients of this FT's projects, in name order.
            final clients = <String, String>{
              for (final p in list) p.clientId: p.clientName,
            }.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
            // One client: nothing to choose.
            if (_clientId == null && clients.length == 1) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _clientId == null) {
                  _pickClient(clients.first.key, list);
                }
              });
            }
            final projectsOfClient = list
                .where((p) => p.clientId == _clientId)
                .toList();
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _clientId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Client'),
                    items: [
                      for (final c in clients)
                        DropdownMenuItem(
                          value: c.key,
                          child: Text(c.value, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (id) => _pickClient(id, list),
                    validator: (v) => v == null ? 'Pick a client' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TechProject>(
                    // Rebuilt per client so a stale project never survives a switch.
                    key: ValueKey('project-$_clientId'),
                    initialValue: _project,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Project',
                      hintText: _clientId == null
                          ? 'Pick a client first'
                          : null,
                      helperText: _project?.maxQty == null
                          ? null
                          : 'Project max qty: ${_project!.maxQty!.toStringAsFixed(_project!.maxQty! % 1 == 0 ? 0 : 2)} CBM',
                    ),
                    items: [
                      for (final p in projectsOfClient)
                        DropdownMenuItem(
                          value: p,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: _clientId == null ? null : _pickProject,
                    validator: (v) => v == null ? 'Pick a project' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<_Product>(
                    // Rebuilt per project so a stale product never survives a switch.
                    key: ValueKey('product-${_project?.projectId}'),
                    initialValue: _product,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Product'),
                    items: [
                      for (final p in _project?.products ?? const <_Product>[])
                        DropdownMenuItem(
                          value: p,
                          child: Text('${p.name} ${p.grade}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _product = v),
                    validator: (v) => v == null ? 'Pick a product' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _qty,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      suffixText: _product?.unit,
                    ),
                    validator: (v) =>
                        (double.tryParse(v?.trim() ?? '') ?? 0) > 0
                        ? null
                        : 'Enter a quantity',
                  ),
                  const SizedBox(height: 8),
                  FormField<DateTime>(
                    validator: (_) => _date == null ? 'Pick a date' : null,
                    builder: (field) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: Text(
                        _date == null
                            ? 'Delivery date'
                            : DateFormat('EEE, d MMM yyyy').format(_date!),
                      ),
                      subtitle: field.hasError
                          ? Text(
                              field.errorText!,
                              style: const TextStyle(color: AppColors.danger),
                            )
                          : null,
                      onTap: _pickDate,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: Text(
                      _time == null
                          ? 'Time (optional)'
                          : _time!.format(context),
                    ),
                    onTap: _pickTime,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _address,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Delivery address (optional)',
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Place order'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
