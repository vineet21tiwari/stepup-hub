import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../api/endpoints.dart';
import '../../widgets/common.dart';

const _pageKeys = ['HOME', 'ABOUT', 'CONTACT'];
const _pageFields = ['heading', 'subheading', 'bodyContent', 'contactAddress', 'contactPhone', 'contactEmail', 'contactMapUrl'];

/// Edit the public Home / About / Contact pages and manage testimonials. Mirrors AdminSiteContent.jsx.
class AdminSiteContentScreen extends StatelessWidget {
  const AdminSiteContentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            child: TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              tabs: const [Tab(text: 'Pages'), Tab(text: 'Testimonials')],
            ),
          ),
          const Expanded(child: TabBarView(children: [_PagesTab(), _TestimonialsTab()])),
        ],
      ),
    );
  }
}

Future<String?> _pickImage() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
  return picked?.path;
}

class _PagesTab extends StatefulWidget {
  const _PagesTab();

  @override
  State<_PagesTab> createState() => _PagesTabState();
}

class _PagesTabState extends State<_PagesTab> {
  String _key = 'HOME';
  final Map<String, TextEditingController> _c = {for (final f in _pageFields) f: TextEditingController()};
  String? _imageUrl;
  String? _newImagePath;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _saved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _saved = null;
      _newImagePath = null;
    });
    try {
      final data = await SiteApi.getPage(_key);
      if (!mounted) return;
      setState(() {
        for (final f in _pageFields) {
          _c[f]!.text = (data[f] ?? '').toString();
        }
        _imageUrl = data['imageUrl'];
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
      _saved = null;
    });
    try {
      final updated = await SiteApi.updatePage(_key, {for (final f in _pageFields) f: _c[f]!.text}, imagePath: _newImagePath);
      setState(() {
        _imageUrl = updated['imageUrl'];
        _newImagePath = null;
        _saved = 'Page saved.';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String key, String label, {int maxLines = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: _c[key], maxLines: maxLines, decoration: InputDecoration(labelText: label)),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Edit the public Home, About, and Contact pages.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: _pageKeys.map((k) => ButtonSegment(value: k, label: Text(k[0] + k.substring(1).toLowerCase()))).toList(),
          selected: {_key},
          onSelectionChanged: (v) {
            setState(() => _key = v.first);
            _load();
          },
        ),
        const SizedBox(height: 14),
        if (_loading)
          const LoadingView()
        else ...[
          if (_error != null) InfoBanner.error(_error!),
          if (_saved != null) InfoBanner.info(_saved!),
          _field('heading', 'Heading'),
          _field('subheading', 'Subheading'),
          _field('bodyContent', 'Body content', maxLines: 4),
          if (_key == 'CONTACT') ...[
            _field('contactEmail', 'Contact email'),
            _field('contactPhone', 'Contact phone'),
            _field('contactAddress', 'Address'),
            _field('contactMapUrl', 'Map link'),
          ],
          const Text('Image', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          const SizedBox(height: 6),
          if (_imageUrl != null && _newImagePath == null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(fileUrl(_imageUrl), height: 140, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          TextButton.icon(
            onPressed: () async {
              final p = await _pickImage();
              if (p != null) setState(() => _newImagePath = p);
            },
            icon: const Icon(Icons.image_outlined, size: 18),
            label: Text(_newImagePath != null ? 'New image selected — tap to change' : (_imageUrl != null ? 'Replace image' : 'Choose image')),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving...' : 'Save page')),
        ],
      ],
    );
  }
}

class _TestimonialsTab extends StatefulWidget {
  const _TestimonialsTab();

  @override
  State<_TestimonialsTab> createState() => _TestimonialsTabState();
}

class _TestimonialsTabState extends State<_TestimonialsTab> {
  List<dynamic>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await SiteApi.allTestimonials();
      if (mounted) setState(() => _items = t);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _openForm([Map<String, dynamic>? existing]) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _TestimonialForm(existing: existing, onSaved: _load),
    );
  }

  Future<void> _delete(Map<String, dynamic> t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(title: const Text('Delete this testimonial?'), actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
      ]),
    );
    if (ok != true) return;
    try {
      await SiteApi.deleteTestimonial(t['id']);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add testimonial'),
      ),
      body: _error != null
          ? Padding(padding: const EdgeInsets.all(16), child: InfoBanner.error(_error!))
          : _items == null
              ? const LoadingView()
              : _items!.isEmpty
                  ? const EmptyState('No testimonials yet.')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: _items!.length,
                        itemBuilder: (context, i) {
                          final t = _items![i];
                          final name = (t['authorName'] ?? '') as String;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: t['photoUrl'] != null ? NetworkImage(fileUrl(t['photoUrl'])) : null,
                                child: t['photoUrl'] == null ? Text(name.isEmpty ? '?' : name[0].toUpperCase()) : null,
                              ),
                              title: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                if (t['published'] != true) const StatusPill('Unpublished'),
                              ]),
                              subtitle: Text([
                                if ((t['authorRole'] ?? '').toString().isNotEmpty) t['authorRole'],
                                '★' * ((t['rating'] ?? 5) as int),
                                t['message'] ?? '',
                              ].join('\n')),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) => v == 'edit' ? _openForm(t) : _delete(t),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _TestimonialForm extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final Future<void> Function() onSaved;
  const _TestimonialForm({this.existing, required this.onSaved});

  @override
  State<_TestimonialForm> createState() => _TestimonialFormState();
}

class _TestimonialFormState extends State<_TestimonialForm> {
  late final _name = TextEditingController(text: widget.existing?['authorName'] ?? '');
  late final _role = TextEditingController(text: widget.existing?['authorRole'] ?? '');
  late final _message = TextEditingController(text: widget.existing?['message'] ?? '');
  late final _order = TextEditingController(text: '${widget.existing?['displayOrder'] ?? 0}');
  late int _rating = (widget.existing?['rating'] ?? 5) as int;
  late bool _published = widget.existing?['published'] ?? true;
  String? _photoPath;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _message.text.trim().isEmpty) {
      setState(() => _error = 'Author name and message are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final payload = {
      'authorName': _name.text.trim(),
      'authorRole': _role.text.trim(),
      'message': _message.text.trim(),
      'rating': _rating,
      'published': _published,
      'displayOrder': int.tryParse(_order.text) ?? 0,
    };
    try {
      if (widget.existing != null) {
        await SiteApi.updateTestimonial(widget.existing!['id'], payload, photoPath: _photoPath);
      } else {
        await SiteApi.createTestimonial(payload, photoPath: _photoPath);
      }
      await widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing != null ? 'Edit testimonial' : 'Add testimonial', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            if (_error != null) InfoBanner.error(_error!),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Author name')),
            const SizedBox(height: 10),
            TextField(controller: _role, decoration: const InputDecoration(labelText: 'Author role')),
            const SizedBox(height: 10),
            TextField(controller: _message, maxLines: 3, decoration: const InputDecoration(labelText: 'Message')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _rating,
                  decoration: const InputDecoration(labelText: 'Rating'),
                  items: [5, 4, 3, 2, 1].map((r) => DropdownMenuItem(value: r, child: Text('$r star${r == 1 ? '' : 's'}'))).toList(),
                  onChanged: (v) => setState(() => _rating = v ?? 5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(controller: _order, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Display order')),
              ),
            ]),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _published,
              onChanged: (v) => setState(() => _published = v ?? true),
              title: const Text('Published (visible on the public site)'),
            ),
            TextButton.icon(
              onPressed: () async {
                final p = await _pickImage();
                if (p != null) setState(() => _photoPath = p);
              },
              icon: const Icon(Icons.photo_outlined, size: 18),
              label: Text(_photoPath != null ? 'Photo selected — tap to change' : 'Choose photo (optional)'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Saving...' : (widget.existing != null ? 'Save changes' : 'Add testimonial')),
            ),
          ],
        ),
      ),
    );
  }
}
