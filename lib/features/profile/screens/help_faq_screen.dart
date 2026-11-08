import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../widgets/contact_hotline_sheet.dart';

class HelpFaqItem {
  final String category;
  final String question;
  final String answer;

  const HelpFaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });
}

class HelpFaqScreen extends StatefulWidget {
  const HelpFaqScreen({super.key});

  @override
  State<HelpFaqScreen> createState() => _HelpFaqScreenState();
}

class _HelpFaqScreenState extends State<HelpFaqScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'Tất cả';
  String _searchQuery = '';

  static const List<String> _categories = [
    'Tất cả',
    'Thuê phòng & Xem trọ',
    'Đặt cọc & Thanh toán',
    'Tìm bạn ở ghép',
    'Xác thực CCCD / eKYC',
    'Dành cho Chủ trọ',
  ];

  static const List<HelpFaqItem> _faqList = [
    HelpFaqItem(
      category: 'Thuê phòng & Xem trọ',
      question: 'Làm thế nào để tìm phòng trọ ưng ý trên HomeShare?',
      answer:
          'Bạn có thể vào tab "Khám phá" hoặc "Trang chủ", dùng thanh tìm kiếm nhập tên trường Đại học, khu vực, quận/huyện. Hãy sử dụng bộ lọc nâng cao để chọn khoảng giá thuê, diện tích, số lượng người ở và các tiện ích mong muốn (máy lạnh, máy giặt, gác lửng, giờ giấc tự do...). Bạn cũng có thể xem vị trí trực tiếp trên bản đồ.',
    ),
    HelpFaqItem(
      category: 'Thuê phòng & Xem trọ',
      question: 'Làm sao để đặt lịch hẹn xem phòng với chủ trọ?',
      answer:
          'Tại trang chi tiết của bất kỳ phòng trọ nào, bạn nhấn nút "Đặt lịch xem phòng". Sau đó chọn ngày, giờ hẹn phù hợp và nhập ghi chú (nếu có). Yêu cầu sẽ được gửi tức thì đến chủ trọ. Bạn có thể theo dõi trạng thái tiếp nhận tại mục "Lịch xem phòng & Đơn thuê".',
    ),
    HelpFaqItem(
      category: 'Thuê phòng & Xem trọ',
      question: 'Tôi có thể nhắn tin hoặc gọi điện trực tiếp cho chủ trọ không?',
      answer:
          'Hoàn toàn được. Trên màn hình chi tiết phòng, bạn có thể chọn "Nhắn tin" để trò chuyện trực tiếp qua hộp thư chat của ứng dụng hoặc nhấn biểu tượng gọi thoại để liên hệ nhanh chóng mà không cần lộ số điện thoại cá nhân.',
    ),
    HelpFaqItem(
      category: 'Đặt cọc & Thanh toán',
      question: 'Khoản tiền đặt cọc giữ chỗ được bảo đảm an toàn như thế nào?',
      answer:
          'Toàn bộ số tiền đặt cọc trực tuyến qua HomeShare được giữ an toàn trong tài khoản trung gian ký quỹ (Escrow) của hệ thống. Tiền cọc chỉ được giải ngân cho Chủ trọ sau khi bạn đến nhận phòng thành công và ký biên bản bàn giao phòng điện tử. Nếu có gian lận hoặc sai lệch, số tiền sẽ được bảo toàn để hoàn trả cho bạn.',
    ),
    HelpFaqItem(
      category: 'Đặt cọc & Thanh toán',
      question: 'Chính sách hoàn tiền cọc hoạt động như thế nào khi hủy lịch?',
      answer:
          'Nếu Chủ trọ tự ý hủy đơn đặt cọc hoặc phòng thực tế sai lệch nghiêm trọng so với mô tả đã đăng ký, bạn được hoàn lại 100% tiền cọc. Trường hợp bạn chủ động hủy đơn trước ngày nhận phòng, mức hoàn tiền sẽ căn cứ theo chính sách hủy niêm yết của phòng (thường hoàn 100% nếu hủy trước 7 ngày, 50% nếu hủy trước 3 ngày).',
    ),
    HelpFaqItem(
      category: 'Đặt cọc & Thanh toán',
      question: 'HomeShare hỗ trợ những hình thức thanh toán nào?',
      answer:
          'Hệ thống hỗ trợ chuyển khoản tự động qua mã VietQR (quét mã qua mọi app ngân hàng với cú pháp tự động điền), thẻ ATM/Napas nội địa, thẻ Visa/Mastercard và số dư tài khoản giao dịch.',
    ),
    HelpFaqItem(
      category: 'Tìm bạn ở ghép',
      question: 'Làm thế nào để tìm bạn ở ghép tương đồng lối sống?',
      answer:
          'Tại tab "Tìm ở ghép", bạn có thể duyệt qua hồ sơ các bạn đang tìm phòng hoặc tìm bạn cùng phòng. Hệ thống có bộ lọc chi tiết về: Giới tính, Trường học/Nơi làm việc, Giờ giấc sinh hoạt, Tiêu chuẩn sạch sẽ, Thói quen nấu ăn, Hút thuốc, Nuôi thú cưng... để bạn tìm được người bạn ở ghép phù hợp nhất.',
    ),
    HelpFaqItem(
      category: 'Tìm bạn ở ghép',
      question: 'Quy trình gửi lời mời và kết nối ở ghép ra sao?',
      answer:
          'Khi thấy bạn ở ghép phù hợp, bạn nhấn "Mời ở ghép" hoặc "Gửi tin nhắn". Đối phương sẽ nhận được thông báo để xem hồ sơ và phản hồi. Sau khi cả hai đồng ý, bạn có thể hẹn gặp mặt trực tiếp hoặc cùng nhau đặt phòng thuê chung.',
    ),
    HelpFaqItem(
      category: 'Xác thực CCCD / eKYC',
      question: 'Tại sao tôi nên xác thực định danh CCCD gắn chip (eKYC)?',
      answer:
          'Xác thực CCCD giúp tài khoản của bạn nhận huy hiệu "Đã xác minh" (Tích xanh uy tín), tăng tỷ lệ được duyệt thuê phòng và kết nối ở ghép lên 300%. Quan trọng nhất, tài khoản đã xác thực mới đủ điều kiện ký kết hợp đồng thuê trọ điện tử có giá trị pháp lý và bảo vệ quyền lợi khi có tranh chấp phát sinh.',
    ),
    HelpFaqItem(
      category: 'Xác thực CCCD / eKYC',
      question: 'Thông tin và hình ảnh CCCD của tôi có được bảo mật không?',
      answer:
          'HomeShare cam kết bảo vệ dữ liệu cá nhân theo đúng Nghị định 13/2023/NĐ-CP. Ảnh chụp CCCD được mã hóa và chỉ dùng cho mục đích đối soát danh tính chính chủ và trích xuất thông tin lập hợp đồng thuê trọ. Dữ liệu tuyệt đối không bao giờ được cung cấp cho bất kỳ bên thứ ba nào ngoài phạm vi dịch vụ.',
    ),
    HelpFaqItem(
      category: 'Dành cho Chủ trọ',
      question: 'Làm sao để đăng ký cơ sở và đăng tin phòng cho thuê?',
      answer:
          'Từ menu Cá nhân, bạn vào "Giao diện Chủ trọ (Quản lý)". Tại đây, bạn chọn "Quản lý cơ sở & Tòa nhà" để tạo mới dãy trọ/nhà nguyên căn, sau đó thêm từng phòng với giá thuê, ảnh thực tế, tiền cọc và tiện ích. Sau khi bấm gửi duyệt, tin đăng sẽ được kiểm duyệt nhanh chóng để hiển thị trên ứng dụng.',
    ),
    HelpFaqItem(
      category: 'Dành cho Chủ trọ',
      question: 'Khi bài đăng bị từ chối kiểm duyệt (Rejected), tôi cần làm gì?',
      answer:
          'Bạn hãy đọc kỹ lý do Admin ghi chú từ chối (ví dụ: ảnh mờ, sai địa chỉ, giá không nhất quán...). Sau đó vào mục chỉnh sửa bài đăng để bổ sung thông tin chính xác và bấm "Gửi duyệt lại (Repost)". Admin sẽ kiểm tra lại tại tab Duyệt Repost để phê duyệt bài viết cho bạn.',
    ),
    HelpFaqItem(
      category: 'Dành cho Chủ trọ',
      question: 'Điểm uy tín (0–100) của Chủ trọ được tính như thế nào?',
      answer:
          'Điểm uy tín khởi tạo là 100 điểm. Điểm uy tín phản ánh trực tiếp sự hài lòng của khách thuê qua đánh giá sao (1–5 sao). Nếu chủ trọ vi phạm quy chế hoặc bị phản ánh sai sự thật, Admin có thể áp dụng mức trừ điểm uy tín tương ứng.',
    ),
  ];

  List<HelpFaqItem> get _filteredFaqs {
    return _faqList.where((item) {
      final matchCategory =
          _selectedCategory == 'Tất cả' || item.category == _selectedCategory;
      final query = _searchQuery.toLowerCase().trim();
      final matchSearch = query.isEmpty ||
          item.question.toLowerCase().contains(query) ||
          item.answer.toLowerCase().contains(query);
      return matchCategory && matchSearch;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Trung tâm trợ giúp & FAQ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Header search
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm câu hỏi (cọc, phòng, cccd...)...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Horizontal category chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((cat) {
                      final selected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: selected
                                  ? Colors.white
                                  : Colors.grey.shade800,
                            ),
                          ),
                          selected: selected,
                          selectedColor: AppColors.primary,
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedCategory = cat);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // FAQ List
          Expanded(
            child: _filteredFaqs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.help_outline_rounded,
                            size: 56,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Không tìm thấy câu hỏi phù hợp',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bạn thử tìm bằng từ khóa khác hoặc liên hệ bộ phận hỗ trợ khách hàng 24/7.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => showContactHotlineSheet(context),
                            icon: const Icon(Icons.support_agent, size: 18),
                            label: const Text('Liên hệ hỗ trợ ngay'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredFaqs.length + 1,
                    itemBuilder: (ctx, idx) {
                      if (idx == _filteredFaqs.length) {
                        return Container(
                          margin: const EdgeInsets.only(top: 16, bottom: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFBFDBFE),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.headset_mic_rounded,
                                      color: AppColors.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Vẫn còn thắc mắc?',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Đội ngũ HomeShare luôn sẵn sàng giải đáp 24/7.',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () =>
                                      showContactHotlineSheet(context),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: AppColors.primary),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Liên hệ Tổng đài / Hotline',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final item = _filteredFaqs[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              leading: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.question_mark_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                              title: Text(
                                item.question,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      item.answer,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.5,
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
