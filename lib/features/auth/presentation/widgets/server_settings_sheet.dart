import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/config/server_settings.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ui.dart';

/// Lets a device point at the backend without rebuilding the app, which is
/// what a real phone needs (`localhost` there is the phone itself).
Future<void> showServerSettings(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const ServerSettingsSheet(),
    );

class ServerSettingsSheet extends ConsumerStatefulWidget {
  const ServerSettingsSheet({super.key});

  @override
  ConsumerState<ServerSettingsSheet> createState() => _ServerSettingsSheetState();
}

class _ServerSettingsSheetState extends ConsumerState<ServerSettingsSheet> {
  late final TextEditingController _url;
  bool _checking = false;
  ServerCheck? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: ref.read(serverUrlProvider));
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final url = Env.normalizeServerUrl(_url.text);
    if (url == null) {
      setState(() {
        _error = 'Enter an address like http://192.168.1.20:8787';
        _result = null;
      });
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
      _result = null;
    });
    final result = await ref.read(serverCheckProvider)(url);
    if (mounted) {
      setState(() {
        _checking = false;
        _result = result;
      });
    }
  }

  Future<void> _save() async {
    try {
      await ref.read(serverUrlProvider.notifier).save(_url.text);
      if (!mounted) return;
      final saved = ref.read(serverUrlProvider);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Server set to $saved')));
    } on AppException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _reset() async {
    await ref.read(serverUrlProvider.notifier).reset();
    if (!mounted) return;
    _url.text = ref.read(serverUrlProvider);
    setState(() {
      _error = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Server settings', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'On a real phone, "localhost" is the phone itself. Enter your computer\'s '
          'address on the same Wi-Fi, for example http://192.168.1.20:8787.',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 18),
        TextField(
          key: const Key('server_url_field'),
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: (_) => setState(() {
            _error = null;
            _result = null;
          }),
          decoration: const InputDecoration(
            hintText: 'http://192.168.1.20:8787',
            prefixIcon: Icon(Icons.dns_outlined),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _checking
              ? const Row(children: [
                  SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Text('Checking…'),
                ])
              : result != null
                  ? Row(
                      key: const Key('server_result'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(result.ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                            size: 20, color: result.ok ? AppColors.success : AppColors.danger),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(result.message,
                              style: TextStyle(
                                  color: result.ok ? AppColors.success : AppColors.danger,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35)),
                        ),
                      ],
                    )
                  : _error != null
                      ? Text(_error!, style: const TextStyle(color: AppColors.danger))
                      : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('server_test'),
          onPressed: _checking ? null : _test,
          icon: const Icon(Icons.wifi_find_rounded),
          label: const Text('Test connection'),
        ),
        const SizedBox(height: 10),
        PrimaryButton(key: const Key('server_save'), label: 'Save', onPressed: _save),
        const SizedBox(height: 4),
        TextButton(
          key: const Key('server_reset'),
          onPressed: _reset,
          child: const Text('Reset to default'),
        ),
      ]),
    );
  }
}
