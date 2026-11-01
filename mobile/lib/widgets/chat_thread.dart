import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import 'common.dart';

/// A generalized message thread — backs course chat, Admin<->Coordinator DMs, and per-task threads.
/// The caller supplies how to load history and send a message; this widget only handles polling,
/// the message list UI, and (optionally) picking/showing a file attachment.
class ChatThreadWidget extends StatefulWidget {
  final Future<List<dynamic>> Function() loadHistory;
  final Future<Map<String, dynamic>> Function(String? content, String? attachmentPath) send;
  final int currentUserId;
  final bool allowAttachments;
  final String emptyText;
  final String hintText;
  final Duration pollInterval;

  const ChatThreadWidget({
    super.key,
    required this.loadHistory,
    required this.send,
    required this.currentUserId,
    this.allowAttachments = false,
    this.emptyText = 'No messages yet.',
    this.hintText = 'Message...',
    this.pollInterval = const Duration(seconds: 4),
  });

  @override
  State<ChatThreadWidget> createState() => _ChatThreadWidgetState();
}

class _ChatThreadWidgetState extends State<ChatThreadWidget> {
  List<dynamic> _messages = [];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _timer;
  bool _sending = false;
  bool _loading = true;
  String? _pickedPath;
  String? _pickedName;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(widget.pollInterval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.loadHistory();
      if (!mounted) return;
      final wasAtBottom = !_scrollController.hasClients ||
          _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 40;
      setState(() {
        _messages = data;
        _loading = false;
      });
      if (wasAtBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      }
    } catch (_) {
      // ignore transient failures during polling
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'gif', 'webp'],
    );
    final file = result?.files.single;
    if (file?.path != null) {
      setState(() {
        _pickedPath = file!.path;
        _pickedName = file.name;
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pickedPath == null) return;
    setState(() => _sending = true);
    try {
      await widget.send(text.isEmpty ? null : text, _pickedPath);
      _controller.clear();
      setState(() {
        _pickedPath = null;
        _pickedName = null;
      });
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _loading
              ? const LoadingView()
              : _messages.isEmpty
                  ? EmptyState(widget.emptyText, icon: Icons.forum_outlined)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (context, i) => _Bubble(message: _messages[i], mine: _messages[i]['senderId'] == widget.currentUserId),
                    ),
        ),
        if (_pickedName != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.attach_file, size: 16),
                const SizedBox(width: 4),
                Expanded(child: Text(_pickedName!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() {
                    _pickedPath = null;
                    _pickedName = null;
                  }),
                ),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
            child: Row(
              children: [
                if (widget.allowAttachments)
                  IconButton(icon: const Icon(Icons.attach_file), onPressed: _sending ? null : _pickFile),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(hintText: widget.hintText, isDense: true),
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool mine;
  const _Bubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final attachmentUrl = message['attachmentUrl'] as String?;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? kNavy.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(kRadiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(child: Text(message['senderName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5))),
                if (message['senderRole'] != null) ...[
                  const SizedBox(width: 6),
                  RolePill(message['senderRole']),
                ],
                const Spacer(),
                Text(fmtTime(message['sentAt']), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            if ((message['content'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 3),
              Text(message['content']),
            ],
            if (attachmentUrl != null) ...[
              const SizedBox(height: 6),
              _Attachment(url: attachmentUrl, name: message['attachmentName']),
            ],
          ],
        ),
      ),
    );
  }
}

class _Attachment extends StatelessWidget {
  final String url;
  final String? name;
  const _Attachment({required this.url, this.name});

  @override
  Widget build(BuildContext context) {
    final href = fileUrl(url);
    if (isImagePath(url)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          onTap: () => launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication),
          child: Image.network(href, width: 180, height: 180, fit: BoxFit.cover),
        ),
      );
    }
    return InkWell(
      onTap: () => launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, size: 16),
          const SizedBox(width: 4),
          Flexible(child: Text(name ?? 'Download attachment', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
