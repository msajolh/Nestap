import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../home/domain/entities/home.dart';
import '../../../home/home_providers.dart';
import '../providers/pairing_controller.dart';

/// Wi-Fi pairing for Tuya-based switches and sockets (EZ / AP via the SDK).
class AddDevicePage extends ConsumerStatefulWidget {
  const AddDevicePage({super.key});

  @override
  ConsumerState<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends ConsumerState<AddDevicePage> {
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  String? _roomId;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Start fresh every time the page opens.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(pairingControllerProvider.notifier).reset(),
    );
  }

  @override
  void dispose() {
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  void _start(Home home) => ref.read(pairingControllerProvider.notifier).start(
        homeId: home.id,
        roomId: _roomId,
        ssid: _ssid.text,
        password: _password.text,
      );

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(currentHomeProvider);
    final rooms = ref.watch(roomsProvider).value ?? const <Room>[];
    final pairing = ref.watch(pairingControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add device')),
      body: AsyncValueView(
        value: home,
        data: (home) {
          if (home == null) {
            return const MessageView(icon: Icons.home_work_outlined, title: 'Create a home first');
          }
          return SingleChildScrollView(
            padding: EdgeInsets.all(context.pagePadding),
            child: ResponsiveCenter(
              maxWidth: 560,
              child: switch (pairing) {
                PairingInProgress() => _Searching(
                    onCancel: ref.read(pairingControllerProvider.notifier).cancel,
                  ),
                PairingSucceeded(:final deviceId) => MessageView(
                    icon: Icons.check_circle_rounded,
                    title: 'Device added',
                    message: 'It is ready to use.',
                    actionLabel: 'Open device',
                    onAction: () => context.pushReplacement(Routes.device(deviceId)),
                  ),
                PairingIdle() || PairingFailed() => _Form(
                    rooms: rooms,
                    roomId: _roomId,
                    onRoomChanged: (id) => setState(() => _roomId = id),
                    ssid: _ssid,
                    password: _password,
                    obscure: _obscure,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    error: pairing is PairingFailed ? pairing.message : null,
                    onStart: () => _start(home),
                  ),
              },
            ),
          );
        },
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.rooms,
    required this.roomId,
    required this.onRoomChanged,
    required this.ssid,
    required this.password,
    required this.obscure,
    required this.onToggleObscure,
    required this.onStart,
    this.error,
  });

  final List<Room> rooms;
  final String? roomId;
  final ValueChanged<String?> onRoomChanged;
  final TextEditingController ssid;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onStart;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded, size: 40, color: AppColors.brand),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    'Press and hold any button on the switch for 5 seconds, '
                    'until its light blinks quickly.',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        DropdownButtonFormField<String?>(
          initialValue: roomId,
          decoration: const InputDecoration(
            labelText: 'Room',
            prefixIcon: Icon(Icons.meeting_room_outlined),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('No room')),
            for (final room in rooms) DropdownMenuItem(value: room.id, child: Text(room.name)),
          ],
          onChanged: onRoomChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: ssid,
          decoration: const InputDecoration(
            labelText: 'Wi-Fi network (2.4 GHz)',
            prefixIcon: Icon(Icons.wifi_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: password,
          obscureText: obscure,
          decoration: InputDecoration(
            labelText: 'Wi-Fi password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: obscure ? 'Show password' : 'Hide password',
              onPressed: onToggleObscure,
              icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(onPressed: onStart, child: const Text('Start pairing')),
      ],
    );
  }
}

class _Searching extends StatelessWidget {
  const _Searching({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        children: [
          const SizedBox.square(
            dimension: 96,
            child: CircularProgressIndicator(strokeWidth: 6, color: AppColors.brand),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('Looking for your device…', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Keep your phone close to the switch. This can take up to 2 minutes.',
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}
