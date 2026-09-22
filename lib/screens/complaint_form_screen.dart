import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../widgets/common.dart';
import 'elders_screen.dart';

const categories = ['food', 'financial', 'medical', 'abandonment', 'abuse', 'loneliness', 'other'];

class ComplaintFormScreen extends StatefulWidget {
  const ComplaintFormScreen({super.key});
  @override
  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();
}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {
  final _desc = TextEditingController();
  final _recorder = AudioRecorder();
  final _picker = ImagePicker();

  List<dynamic> _elders = [];
  bool _loading = true;
  int? _elderId;
  String _category = 'food';
  bool _anonymous = false;
  final List<Uint8List> _photos = [];
  String? _audioPath;
  bool _recording = false;
  bool _busy = false;
  String _progress = '';

  @override
  void initState() {
    super.initState();
    _loadElders();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _loadElders() async {
    try {
      final list = await Api.get('/elders') as List<dynamic>;
      setState(() {
        _elders = list;
        if (list.isNotEmpty) _elderId = list.first['id'] as int;
      });
    } catch (e) {
      if (mounted) snack(context, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addPhoto(ImageSource source) async {
    if (_photos.length >= 5) {
      snack(context, 'You can attach up to 5 photos');
      return;
    }
    final x = await _picker.pickImage(source: source, imageQuality: 70, maxWidth: 1600);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (mounted) setState(() => _photos.add(bytes));
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() {
        _recording = false;
        _audioPath = path;
      });
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) snack(context, 'Microphone permission is required');
      return;
    }
    final path = kIsWeb
        ? ''
        : '${(await getTemporaryDirectory()).path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      RecordConfig(encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc),
      path: path,
    );
    setState(() => _recording = true);
  }

  Future<void> _submit() async {
    if (_elderId == null) {
      snack(context, 'Please add and select an elder profile first');
      return;
    }
    if (_desc.text.trim().length < 10) {
      snack(context, 'Please describe the problem (at least 10 characters)');
      return;
    }
    setState(() => _busy = true);
    try {
      final cid = Api.newId(); // evidence folder name = complaint id
      final evidence = <Map<String, String>>[];
      for (var i = 0; i < _photos.length; i++) {
        setState(() => _progress = 'Uploading photo ${i + 1}/${_photos.length}...');
        evidence.add({'type': 'photo', 'path': await StorageService.upload(_photos[i], 'jpg', 'image/jpeg', cid)});
      }
      if (_audioPath != null) {
        setState(() => _progress = 'Uploading audio...');
        final audioBytes = await XFile(_audioPath!).readAsBytes();
        evidence.add({
          'type': 'audio',
          'path': await StorageService.upload(
            audioBytes,
            kIsWeb ? 'webm' : 'm4a',
            kIsWeb ? 'audio/webm' : 'audio/mp4',
            cid,
          ),
        });
      }
      setState(() => _progress = 'Submitting...');
      await Api.post('/complaints', {
        'id': cid,
        'elder_id': _elderId,
        'category': _category,
        'description': _desc.text.trim(),
        'is_anonymous': _anonymous,
        'evidence': evidence,
      });
      if (!mounted) return;
      snack(context, 'Submitted. You can track it under "My complaints".');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) snack(context, 'Failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = '';
        });
      }
    }
  }

  Widget _card({required String title, required List<Widget> children}) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ...children,
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: AppColors.background, body: LoadingWidget());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Report / request help')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_elders.isEmpty)
                  Card(
                    color: AppColors.warningBg,
                    margin: const EdgeInsets.only(bottom: 14),
                    child: ListTile(
                      title: const Text('Add an elder profile first', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Who is this report about?'),
                      trailing: const Icon(Icons.arrow_forward, color: AppColors.warning),
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ElderFormScreen()));
                        _loadElders();
                      },
                    ),
                  )
                else
                  _card(title: 'Who is this about?', children: [
                    DropdownButtonFormField<int>(
                      value: _elderId,
                      decoration: const InputDecoration(labelText: 'Elder', prefixIcon: Icon(Icons.elderly_outlined)),
                      items: _elders
                          .map((e) => DropdownMenuItem<int>(value: e['id'] as int, child: Text(e['name'])))
                          .toList(),
                      onChanged: (v) => setState(() => _elderId = v),
                    ),
                  ]),
                _card(title: 'What is happening?', children: [
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: const InputDecoration(labelText: 'Type of problem', prefixIcon: Icon(Icons.category_outlined)),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(pretty(c)))).toList(),
                    onChanged: (v) => setState(() => _category = v!),
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(controller: _desc, label: 'Describe the problem', maxLines: 5),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Submit anonymously'),
                    subtitle: const Text('Officers will not see your name or phone number.'),
                    value: _anonymous,
                    onChanged: (v) => setState(() => _anonymous = v),
                  ),
                ]),
                _card(title: 'Evidence (optional)', children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: () => _addPhoto(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _addPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                    SecondaryButton(
                      label: _recording ? 'Stop recording' : 'Record audio',
                      icon: _recording ? Icons.stop_circle_outlined : Icons.mic_none,
                      color: _recording ? AppColors.error : null,
                      onPressed: _toggleRecord,
                    ),
                  ]),
                  if (_photos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(_photos[i], width: 90, height: 90, fit: BoxFit.cover),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: InkWell(
                              onTap: () => setState(() => _photos.removeAt(i)),
                              child: const CircleAvatar(
                                  radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                  if (_audioPath != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.audiotrack, color: AppColors.primary),
                      title: const Text('Audio recording attached'),
                      trailing: IconButton(
                          icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _audioPath = null)),
                    ),
                ]),
                const SizedBox(height: 6),
                PrimaryButton(
                  label: _busy ? (_progress.isEmpty ? 'Please wait...' : _progress) : 'Submit',
                  loading: _busy,
                  onPressed: _submit,
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
