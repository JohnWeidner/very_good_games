import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_identity/nostr_identity.dart';
import 'package:very_good_games/nostr/profile/profile.dart';

/// Profile editing screen accessible from Settings.
///
/// Fields: name (required, max 100), picture URL (optional, https only,
/// max 2048), about (optional, max 500).
class ProfileEditPage extends StatefulWidget {
  /// Creates a [ProfileEditPage].
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pictureController = TextEditingController();
  final _aboutController = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final identityRepo = context.read<NostrIdentityRepository>();
    final profileRepo = context.read<NostrProfileRepository>();
    final pubkeyHex = await identityRepo.getPublicKeyHex();
    if (pubkeyHex == null || !mounted) return;

    final profile = await profileRepo.getProfile(pubkeyHex);
    if (!mounted) return;

    setState(() {
      _loaded = true;
      if (profile != null) {
        _nameController.text = profile.name ?? '';
        _pictureController.text = profile.picture ?? '';
        _aboutController.text = profile.about ?? '';
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pictureController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: BlocListener<ProfileCubit, ProfileState>(
        listener: (context, state) {
          if (state.status == ProfileStatus.published) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Profile saved!')));
            Navigator.of(context).pop();
          } else if (state.status == ProfileStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? 'Could not save profile.'),
              ),
            );
          }
        },
        child: _loaded
            ? _buildForm(context)
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              border: OutlineInputBorder(),
            ),
            maxLength: 100,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pictureController,
            decoration: const InputDecoration(
              labelText: 'Profile Picture URL (optional)',
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
            maxLength: 2048,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!value.startsWith('https://')) {
                  return 'Must be an https:// URL';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _aboutController,
            decoration: const InputDecoration(
              labelText: 'About (optional)',
              border: OutlineInputBorder(),
            ),
            maxLength: 500,
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, state) {
              final isPublishing = state.status == ProfileStatus.publishing;
              return FilledButton(
                onPressed: isPublishing ? null : _save,
                child: isPublishing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              );
            },
          ),
        ],
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final picture = _pictureController.text.trim();
    final about = _aboutController.text.trim();

    context.read<ProfileCubit>().publishProfile(
      name: name,
      picture: picture.isNotEmpty ? picture : null,
      about: about.isNotEmpty ? about : null,
    );
  }
}
