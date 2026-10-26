import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/globals.dart';
import '../utils/image_cropper_util.dart';

class ProfileScreen extends StatefulWidget {
  final int totalSongs;
  final int totalPlaylists;
  final int totalFavorites;
  final Color activeAccentColor;
  final VoidCallback onOpenSettings;

  const ProfileScreen({
    super.key,
    required this.totalSongs,
    required this.totalPlaylists,
    required this.totalFavorites,
    required this.activeAccentColor,
    required this.onOpenSettings,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickProfilePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        final croppedPath = await ImageCropperUtil.cropImage(
          context: context,
          sourcePath: image.path,
          squareOnly: true,
        );
        if (croppedPath != null && mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userProfileImage', croppedPath);
          userProfileImageNotifier.value = croppedPath;
          showFleyToast('Profile photo updated');
        }
      }
    } catch (e) {
      debugPrint('Error picking profile image: $e');
    }
  }

  Future<void> _removeProfilePhoto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userProfileImage');
    userProfileImageNotifier.value = null;
    showFleyToast('Profile photo removed');
  }

  void _showPhotoOptionsModal() {
    final isLight = isAppLight;
    final bgColor = isLight ? Colors.white : const Color(0xFF1E1E22);
    final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: widget.activeAccentColor,
                  ),
                  title: Text(
                    'Choose from Gallery',
                    style: TextStyle(
                      color: textColor,
                      fontFamily: getFontFamily(),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickProfilePhoto();
                  },
                ),
                if (userProfileImageNotifier.value != null)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    title: Text(
                      'Remove Photo',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontFamily: getFontFamily(),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _removeProfilePhoto();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditProfileDialog() {
    final isLight = isAppLight;
    final nameController = TextEditingController(text: userProfileNameNotifier.value);
    final bioController = TextEditingController(text: userProfileBioNotifier.value);
    final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;
    final dialogBg = isLight ? const Color(0xFFF2F2F5) : const Color(0xFF1E1E24);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Edit Profile',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontFamily: getFontFamily(),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                maxLength: 30,
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(
                    color: isLight ? Colors.black54 : Colors.white60,
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: widget.activeAccentColor, width: 2),
                  ),
                ),
                style: TextStyle(color: textColor, fontFamily: getFontFamily()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioController,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  labelStyle: TextStyle(
                    color: isLight ? Colors.black54 : Colors.white60,
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: widget.activeAccentColor, width: 2),
                  ),
                ),
                style: TextStyle(color: textColor, fontFamily: getFontFamily()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isLight ? Colors.black54 : Colors.white54,
                  fontFamily: getFontFamily(),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.activeAccentColor,
                foregroundColor: widget.activeAccentColor.computeLuminance() > 0.35
                    ? Colors.black
                    : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final newName = nameController.text.trim();
                final newBio = bioController.text.trim();
                if (newName.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('userProfileName', newName);
                  await prefs.setString('userProfileBio', newBio);
                  userProfileNameNotifier.value = newName;
                  userProfileBioNotifier.value = newBio;
                  showFleyToast('Profile updated');
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = isAppLight;
    final bgColor = isLight ? const Color(0xFFF7F7FA) : const Color(0xFF0F0F12);
    final cardBg = isLight ? Colors.white : const Color(0xFF1A1A20);
    final textColor = isLight ? const Color(0xFF1A1A1A) : Colors.white;
    final subTextColor = isLight ? Colors.black54 : Colors.white54;
    final borderColor = isLight
        ? Colors.black.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.06);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textColor,
            fontFamily: getFontFamily(),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: textColor, size: 22),
            onPressed: widget.onOpenSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Avatar Stack
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: _showPhotoOptionsModal,
                    child: ValueListenableBuilder<String?>(
                      valueListenable: userProfileImageNotifier,
                      builder: (context, imagePath, child) {
                        final hasImage =
                            imagePath != null && File(imagePath).existsSync();

                        return Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.activeAccentColor.withValues(alpha: 0.15),
                            border: Border.all(
                              color: widget.activeAccentColor.withValues(alpha: 0.4),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.activeAccentColor.withValues(alpha: 0.2),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: hasImage
                                ? Image.file(
                                    File(imagePath),
                                    width: 104,
                                    height: 104,
                                    fit: BoxFit.cover,
                                  )
                                : Icon(
                                    Icons.person_rounded,
                                    size: 52,
                                    color: widget.activeAccentColor,
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: _showPhotoOptionsModal,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.activeAccentColor,
                        border: Border.all(
                          color: bgColor,
                          width: 2.5,
                        ),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: widget.activeAccentColor.computeLuminance() > 0.35
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Name & Bio
            ValueListenableBuilder<String>(
              valueListenable: userProfileNameNotifier,
              builder: (context, name, child) {
                return Text(
                  name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: textColor,
                    fontFamily: getFontFamily(),
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
            const SizedBox(height: 6),
            ValueListenableBuilder<String>(
              valueListenable: userProfileBioNotifier,
              builder: (context, bio, child) {
                return Text(
                  bio,
                  style: TextStyle(
                    fontSize: 14,
                    color: subTextColor,
                    fontFamily: getFontFamily(),
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
            const SizedBox(height: 18),

            // Edit Profile Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onPressed: _showEditProfileDialog,
              icon: Icon(Icons.edit_outlined, size: 16, color: textColor),
              label: Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  fontFamily: getFontFamily(),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Stats Row
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      count: '${widget.totalSongs}',
                      label: 'Songs',
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: borderColor,
                  ),
                  Expanded(
                    child: _buildStatItem(
                      count: '${widget.totalPlaylists}',
                      label: 'Playlists',
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: borderColor,
                  ),
                  Expanded(
                    child: _buildStatItem(
                      count: '${widget.totalFavorites}',
                      label: 'Favourites',
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Details Section
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'Profile Info',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    fontFamily: getFontFamily(),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: Text(
                      'Display Name',
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                        fontFamily: getFontFamily(),
                      ),
                    ),
                    subtitle: ValueListenableBuilder<String>(
                      valueListenable: userProfileNameNotifier,
                      builder: (context, name, child) {
                        return Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            fontFamily: getFontFamily(),
                          ),
                        );
                      },
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: subTextColor),
                    onTap: _showEditProfileDialog,
                  ),
                  Divider(height: 1, thickness: 0.8, color: borderColor),
                  ListTile(
                    title: Text(
                      'Bio',
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                        fontFamily: getFontFamily(),
                      ),
                    ),
                    subtitle: ValueListenableBuilder<String>(
                      valueListenable: userProfileBioNotifier,
                      builder: (context, bio, child) {
                        return Text(
                          bio,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                            fontFamily: getFontFamily(),
                          ),
                        );
                      },
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: subTextColor),
                    onTap: _showEditProfileDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Shortcut
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.settings_outlined,
                  color: widget.activeAccentColor,
                ),
                title: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    fontFamily: getFontFamily(),
                  ),
                ),
                subtitle: Text(
                  'Theme, audio equalizer, typography & backups',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: subTextColor,
                    fontFamily: getFontFamily(),
                  ),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: subTextColor),
                onTap: widget.onOpenSettings,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String count,
    required String label,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textColor,
            fontFamily: getFontFamily(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: subTextColor,
            fontWeight: FontWeight.w500,
            fontFamily: getFontFamily(),
          ),
        ),
      ],
    );
  }
}
