import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';

class EvidencePicker extends StatelessWidget {
  final List<File> files;
  final ValueChanged<File> onFileAdded;
  final ValueChanged<int> onFileRemoved;

  const EvidencePicker({
    super.key,
    required this.files,
    required this.onFileAdded,
    required this.onFileRemoved,
  });

  Future<void> _pickMedia(BuildContext context, ImageSource source, {bool isVideo = false}) async {
    final picker = ImagePicker();
    try {
      if (isVideo) {
        final video = await picker.pickVideo(source: source);
        if (video != null) {
          onFileAdded(File(video.path));
        }
      } else {
        final image = await picker.pickImage(source: source, imageQuality: 85);
        if (image != null) {
          onFileAdded(File(image.path));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn tệp: $e')),
        );
      }
    }
  }

  void _showMediaPickerSheet(BuildContext context) {
    if (files.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đạt giới hạn tối đa 5 tệp bằng chứng')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Chọn bằng chứng vi phạm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 12),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(Icons.photo_library_outlined, color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB))),
                  ),
                  title: Text('Chọn ảnh từ thư viện'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickMedia(context, ImageSource.gallery, isVideo: false);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(Icons.camera_alt_outlined, color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB))),
                  ),
                  title: Text('Chụp ảnh hiện trường'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickMedia(context, ImageSource.camera, isVideo: false);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.warningContainer,
                    child: Icon(Icons.videocam_outlined, color: (AppColors.isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706))),
                  ),
                  title: Text('Chọn video từ thư viện (MP4 < 25MB)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickMedia(context, ImageSource.gallery, isVideo: true);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.warningContainer,
                    child: Icon(Icons.video_call_outlined, color: (AppColors.isDark ? const Color(0xFFFDE68A) : const Color(0xFFD97706))),
                  ),
                  title: Text('Quay video hiện trường'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickMedia(context, ImageSource.camera, isVideo: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isVideoFile(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    return ext == 'mp4' || ext == 'mov';
  }

  String _getFileName(File file) {
    final name = file.path.split(Platform.pathSeparator).last;
    if (name.length > 14) {
      return '${name.substring(0, 10)}...';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.image_outlined,
                color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB)),
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'BẰNG CHỨNG VI PHẠM',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${files.length}/5 tệp',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB)),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Tải lên hình ảnh hoặc video ghi lại hiện trường vi phạm (tối đa 5 tệp)',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Danh sách tệp đã chọn
                ...List.generate(files.length, (index) {
                  final file = files[index];
                  final isVideo = _isVideoFile(file);
                  final fileName = _getFileName(file);

                  return Container(
                    width: 100,
                    height: 100,
                    margin: EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isVideo ? const Color(0xFF0F172A) : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (!isVideo)
                          Image.file(
                            file,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          )
                        else
                          Center(
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB)),
                              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                            ),
                          ),
                        // Dải nhãn tên tệp dưới cùng
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.6),
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    fileName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isVideo)
                                  Text(
                                    ' 0:15',
                                    style: TextStyle(
                                      color: Color(0xFFF59E0B),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Nút xóa tròn
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => onFileRemoved(index),
                            child: Container(
                              padding: EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Color(0xCC000000),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                // Ô nút + Thêm tệp
                if (files.length < 5)
                  InkWell(
                    onTap: () => _showMediaPickerSheet(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF93C5FD),
                          style: BorderStyle.solid,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add,
                              color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB)),
                              size: 20,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Thêm tệp',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: (AppColors.isDark ? AppColors.textDark : const Color(0xFF2563EB))),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Hỗ trợ ảnh JPG, PNG hoặc video MP4 dung lượng < 25MB',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
