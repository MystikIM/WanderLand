import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../controllers/friends_controller.dart';
import '../../domain/little.dart';
import '../../friends/qr_photo_source.dart';
import '../../friends/qr_reader.dart';
import '../little_scope.dart';
import 'friend_text.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key, this.photos, this.reader});

  /// Where pictures come from, and who reads them. Only tests pass these.
  final QrPhotoSource? photos;
  final QrReader? reader;

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final _input = TextEditingController();
  String? _myCode;
  String? _problem;
  String? _sentTo;
  bool _adding = false;
  bool _makingCode = false;
  final Set<String> _answering = {};
  late final QrPhotoSource _photos = widget.photos ?? DevicePhotoSource();
  late final QrReader _reader = widget.reader ?? ZxingQrReader();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _showCode() async {
    if (_makingCode) return;
    _makingCode = true;
    try {
      final code = await context.read<FriendsController>().myCode();
      if (mounted) setState(() => _myCode = code);
    } catch (e) {
      if (mounted) setState(() => _problem = friendProblemText(e));
    } finally {
      _makingCode = false;
    }
  }

  /// Accept or Decline: one at a time per request, and any failure becomes a plain sentence.
  Future<void> _answer(String id, Future<void> Function() act) async {
    if (!_answering.add(id)) return;
    try {
      await act();
    } catch (e) {
      if (mounted) setState(() => _problem = friendProblemText(e));
    } finally {
      _answering.remove(id);
    }
  }

  Future<void> _add() async {
    if (_adding) return;
    _adding = true;
    final fc = context.read<FriendsController>();
    try {
      final f = await fc.addFromCode(_input.text.trim());
      if (!mounted) return;
      _input.clear();
      setState(() {
        _problem = null;
        _sentTo = f.theirUsername;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _sentTo = null;
          _problem = friendProblemText(e);
        });
      }
    } finally {
      _adding = false;
    }
  }

  /// A picture of a friend's QR: read it, then add them exactly as if the code had been pasted.
  Future<void> _fromPicture(Future<Uint8List?> Function() get) async {
    Uint8List? bytes;
    try {
      bytes = await get();
    } catch (_) {
      if (mounted) setState(() => _problem = 'The camera or pictures could not be opened. Try again, or paste the code instead.');
      return;
    }
    if (bytes == null || !mounted) return;
    final text = await _reader.decode(bytes);
    if (!mounted) return;
    if (text == null) {
      setState(() {
        _sentTo = null;
        _problem = 'I could not find a QR code in that picture. Try again with the whole code in view, close and steady.';
      });
      return;
    }
    _input.text = text;
    await _add();
  }

  @override
  Widget build(BuildContext context) {
    final fc = context.watch<FriendsController>();
    final copy = LittleCopy(currentLittleLevel(context));
    return Scaffold(
      appBar: AppBar(title: const Text('Add a friend')),
      body: fc.locked
          ? Padding(padding: const EdgeInsets.all(16), child: Text(copy('guardMessage')))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text('My code', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text(
                  'Let your friend photograph this QR, or copy the code and send it to them in a private message. It only works once, they need the app too, and only your 5 newest codes work.'),
              const SizedBox(height: 8),
              if (_myCode == null)
                OutlinedButton(key: const Key('friends-show-code'), onPressed: _showCode, child: const Text('Show my code'))
              else ...[
                Center(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(key: ValueKey('qr:$_myCode'), data: _myCode!, size: 220, backgroundColor: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(_myCode!, key: const Key('friends-my-code')),
                Row(children: [
                  TextButton.icon(
                    key: const Key('friends-copy-code'),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                    onPressed: () => Clipboard.setData(ClipboardData(text: _myCode!)),
                  ),
                  TextButton.icon(
                    key: const Key('friends-share-code'),
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    onPressed: () => SharePlus.instance.share(ShareParams(text: _myCode!)),
                  ),
                ]),
              ],
              const Divider(height: 32),
              Text("Enter a friend's code", style: Theme.of(context).textTheme.titleMedium),
              TextField(
                key: const Key('friends-code-input'),
                controller: _input,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Paste the code here'),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                  key: const Key('friends-scan-camera'),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Take a photo of their QR'),
                  onPressed: () => _fromPicture(_photos.takePhoto),
                ),
                OutlinedButton.icon(
                  key: const Key('friends-scan-gallery'),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Pick a picture'),
                  onPressed: () => _fromPicture(_photos.pickPicture),
                ),
              ]),
              const SizedBox(height: 8),
              FilledButton(key: const Key('friends-add-go'), onPressed: _add, child: const Text('Send friend request')),
              if (_problem != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_problem!,
                      key: const Key('friends-add-problem'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              if (_sentTo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Request sent to $_sentTo. They need to accept it.'),
                ),
              const Divider(height: 32),
              Text('Requests waiting', style: Theme.of(context).textTheme.titleMedium),
              if (fc.pendingRequests.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('None right now.')),
              for (final r in fc.pendingRequests)
                ListTile(
                  title: Text(r.theirUsername, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: const Text('wants to be your friend'),
                  trailing: Wrap(spacing: 4, children: [
                    TextButton(
                        key: Key('friends-decline-${r.id}'), onPressed: () => _answer(r.id, () => fc.declineRequest(r.id)), child: const Text('Decline')),
                    FilledButton(
                        key: Key('friends-accept-${r.id}'), onPressed: () => _answer(r.id, () => fc.acceptRequest(r.id)), child: const Text('Accept')),
                  ]),
                ),
            ]),
    );
  }
}
