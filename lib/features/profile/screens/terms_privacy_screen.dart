import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TermsPrivacyScreen extends StatelessWidget {
  final int initialTabIndex;

  const TermsPrivacyScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Điều khoản & Chính sách',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: false,
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: isDark ? Colors.white : AppColors.primary,
            unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'Điều khoản dịch vụ'),
              Tab(text: 'Chính sách bảo mật'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TermsContent(isDark: isDark),
            _PrivacyContent(isDark: isDark),
          ],
        ),
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  final bool isDark;

  const _TermsContent({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildNoticeBox(
          isDark: isDark,
          icon: Icons.gavel_rounded,
          title: 'Hiệu lực áp dụng',
          desc:
              'Bằng việc đăng ký tài khoản hoặc sử dụng dịch vụ trên nền tảng HomeShare, bạn xác nhận đã đọc, hiểu và đồng ý bị ràng buộc bởi các điều khoản dưới đây.',
        ),
        const SizedBox(height: 20),

        _buildSection(
          isDark: isDark,
          number: '1',
          title: 'Định nghĩa & Phạm vi nền tảng',
          content:
              'HomeShare là nền tảng công nghệ số trung gian, kết nối nhu cầu giữa: Người thuê phòng trọ, Người có nhu cầu tìm bạn ở ghép và Chủ cơ sở nhà trọ / căn hộ cho thuê.\n\nHomeShare cung cấp các công cụ tìm kiếm, kiểm duyệt tin đăng, đối soát hợp đồng điện tử và giữ cọc an toàn (Escrow) theo quy định của pháp luật Việt Nam.',
        ),

        _buildSection(
          isDark: isDark,
          number: '2',
          title: 'Quyền và Nghĩa vụ của Người thuê & Ở ghép',
          content:
              '• Cung cấp thông tin cá nhân và định danh CCCD chính xác, trung thực khi đăng ký hồ sơ và lập hợp đồng thuê trọ.\n'
              '• Tuyệt đối không sử dụng phòng trọ vào các mục đích vi phạm pháp luật, tàng trữ chất cấm, hoạt động cờ bạc hoặc gây mất trật tự an ninh khu dân cư.\n'
              '• Tuân thủ nội quy phòng trọ, thời gian thanh toán tiền thuê, tiền cọc và giữ gìn tài sản chung đã được bàn giao trong biên bản.',
        ),

        _buildSection(
          isDark: isDark,
          number: '3',
          title: 'Quyền và Nghĩa vụ của Chủ trọ (Host)',
          content:
              '• Đảm bảo tính xác thực của tin đăng: Hình ảnh thực tế của phòng, diện tích, giá thuê, giá điện nước và các tiện ích đi kèm không được gian lận hoặc sai lệch.\n'
              '• Đảm bảo quyền sử dụng hoặc quyền sở hữu hợp pháp đối với bất động sản cho thuê.\n'
              '• Tiếp nhận khách theo đúng lịch hẹn đã xác nhận, thực hiện biên bản bàn giao phòng (Check-in) đầy đủ và minh bạch.\n'
              '• Tôn trọng sự riêng tư của khách thuê, không tự ý xâm nhập phòng khi chưa có sự đồng ý của khách trừ trường hợp khẩn cấp.',
        ),

        _buildSection(
          isDark: isDark,
          number: '4',
          title: 'Quy định Đặt cọc & Giữ chỗ an toàn (Escrow)',
          content:
              '• Tiền cọc giữ chỗ của Người thuê được HomeShare bảo quản an toàn trong tài khoản trung gian.\n'
              '• Tiền cọc chỉ được giải ngân cho Chủ trọ sau khi Người thuê hoàn tất thủ tục nhận phòng (Check-in) và xác nhận qua hệ thống.\n'
              '• Trường hợp phòng thực tế có sai lệch nghiêm trọng so với tin đăng (ví dụ: thiếu nội thất cơ bản đã cam kết, phòng ẩm mốc hư hỏng nặng), Người thuê có quyền từ chối nhận phòng và khiếu nại trong vòng 24h để được hoàn trả 100% tiền cọc.',
        ),

        _buildSection(
          isDark: isDark,
          number: '5',
          title: 'Chính sách Hủy phòng & Giải quyết khiếu nại',
          content:
              '• Hủy bởi Chủ trọ: Chủ trọ bị phạt điểm uy tín (-10 điểm) và phải bồi hoàn 100% tiền cọc cho khách thuê.\n'
              '• Hủy bởi Khách thuê: Mức hoàn tiền căn cứ theo thời điểm thông báo hủy trước ngày nhận phòng (Hủy trước ≥ 7 ngày: hoàn 100%; Hủy trước ≥ 3 ngày: hoàn 50%; Hủy dưới 3 ngày: không hoàn cọc).\n'
              '• Mọi tranh chấp được tiếp nhận và hòa giải qua trung tâm CSKH 1900 1234.',
        ),

        _buildSection(
          isDark: isDark,
          number: '6',
          title: 'Chế tài Xử lý vi phạm & Trừ điểm uy tín',
          content:
              '• Hệ thống áp dụng thang điểm uy tín 0–100 cho tài khoản.\n'
              '• Hành vi đăng tin giả mạo, lừa đảo, tái phạm đăng nội dung phản cảm sau cảnh cáo sẽ bị trừ điểm uy tín, gỡ bài viết hoặc khóa tài khoản vĩnh viễn.\n'
              '• Trường hợp có dấu hiệu chiếm đoạt tài sản, HomeShare sẽ cung cấp dữ liệu cho cơ quan chức năng để xử lý theo luật định.',
        ),

        const SizedBox(height: 30),
      ],
    );
  }
}

class _PrivacyContent extends StatelessWidget {
  final bool isDark;

  const _PrivacyContent({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildNoticeBox(
          isDark: isDark,
          icon: Icons.security_rounded,
          title: 'Cam kết Bảo mật dữ liệu',
          desc:
              'HomeShare cam kết bảo vệ tuyệt đối quyền riêng tư và dữ liệu cá nhân của người dùng, tuân thủ nghiêm ngặt theo Nghị định 13/2023/NĐ-CP về Bảo vệ dữ liệu cá nhân.',
        ),
        const SizedBox(height: 20),

        _buildSection(
          isDark: isDark,
          number: '1',
          title: 'Loại dữ liệu chúng tôi thu thập',
          content:
              '• Dữ liệu tài khoản: Họ tên, Số điện thoại, Địa chỉ email, Ảnh đại diện.\n'
              '• Dữ liệu định danh eKYC: Số thẻ CCCD gắn chip, ngày cấp, quê quán và ảnh chụp giấy tờ (chỉ thu thập khi người dùng thực hiện xác thực để ký hợp đồng).\n'
              '• Dữ liệu vị trí: Để gợi ý phòng trọ quanh vị trí hiện tại hoặc quanh trường đại học (chỉ kích hoạt khi được cấp quyền).\n'
              '• Dữ liệu thanh toán & giao dịch: Lịch sử đặt cọc, mã giao dịch ngân hàng.',
        ),

        _buildSection(
          isDark: isDark,
          number: '2',
          title: 'Mục đích xử lý và sử dụng dữ liệu',
          content:
              '• Xác thực danh tính chính chủ, phòng chống hành vi gian lận và mạo danh.\n'
              '• Tự động trích xuất thông tin lập hợp đồng thuê trọ điện tử và biên bản bàn giao phòng.\n'
              '• Thông báo trạng thái đặt cọc, lịch hẹn xem phòng và tin nhắn trao đổi giữa các bên.\n'
              '• Nâng cao chất lượng dịch vụ và hỗ trợ kỹ thuật khách hàng khi có sự cố phát sinh.',
        ),

        _buildSection(
          isDark: isDark,
          number: '3',
          title: 'Biện pháp bảo vệ & Lưu trữ dữ liệu',
          content:
              '• Toàn bộ dữ liệu truyền tải đều được mã hóa bằng giao thức bảo mật Transport Layer Security (TLS/SSL).\n'
              '• Hình ảnh và dữ liệu nhạy cảm (như CCCD) được lưu trữ trên hạ tầng đám mây đạt tiêu chuẩn an toàn quốc tế ISO 27001 và được kiểm soát truy cập nghiêm ngặt qua Firebase Security Rules.\n'
              '• HomeShare KHÔNG BAO GIỜ bán, trao đổi hoặc chia sẻ dữ liệu cá nhân của bạn cho bên thứ ba vì mục đích tiếp thị thương mại.',
        ),

        _buildSection(
          isDark: isDark,
          number: '4',
          title: 'Quyền của Chủ thể dữ liệu',
          content:
              'Theo quy định pháp luật, bạn có đầy đủ các quyền sau:\n'
              '• Quyền được biết và đồng ý về việc xử lý dữ liệu cá nhân của mình.\n'
              '• Quyền truy cập, kiểm tra và chỉnh sửa thông tin hồ sơ trong ứng dụng.\n'
              '• Quyền yêu cầu xóa thông tin hoặc hủy vĩnh viễn tài khoản HomeShare bất kỳ lúc nào khi không còn vướng mắc về hợp đồng thuê hoặc công nợ.\n'
              '• Quyền gửi phản ánh, khiếu nại về bảo mật tới: privacy@homeshare.vn.',
        ),

        _buildSection(
          isDark: isDark,
          number: '5',
          title: 'Cập nhật chính sách',
          content:
              'Chính sách này có thể được cập nhật theo định kỳ để phù hợp với quy định mới của pháp luật hoặc cải tiến tính năng dịch vụ. Mọi thay đổi quan trọng sẽ được thông báo trực tiếp qua chuông thông báo trên ứng dụng trước khi có hiệu lực.',
        ),

        const SizedBox(height: 30),
      ],
    );
  }
}

Widget _buildNoticeBox({
  required bool isDark,
  required IconData icon,
  required String title,
  required String desc,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isDark ? Colors.grey.shade300 : const Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildSection({
  required bool isDark,
  required String number,
  required String title,
  required String content,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          content,
          style: TextStyle(
            fontSize: 13,
            height: 1.55,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          ),
        ),
      ],
    ),
  );
}
