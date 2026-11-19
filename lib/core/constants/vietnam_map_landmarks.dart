import '../utils/vietnamese_utils.dart';

/// Mục địa danh / trường học / cơ sở tra cứu nhanh trên bản đồ
class MapLandmarkItem {
  final String name;
  final String address;
  final String category; // 'Cao đẳng', 'Đại học', 'Bến xe & Ga', 'Bệnh viện', 'Địa danh', 'Khu vực'
  final double latitude;
  final double longitude;
  final List<String> aliases;

  const MapLandmarkItem({
    required this.name,
    required this.address,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.aliases = const [],
  });
}

/// Danh mục địa danh, trường Đại học, Cao đẳng và điểm mốc trọng điểm toàn quốc
class VietnamMapLandmarks {
  static const List<MapLandmarkItem> allLandmarks = [
    // =========================================================================
    // 1. HỆ THỐNG CÁC TRƯỜNG CAO ĐẲNG (COLLEGES)
    // =========================================================================
    MapLandmarkItem(
      name: 'Trường Cao đẳng FPT Polytechnic (Cơ sở TP.HCM)',
      address: '778/B1 Nguyễn Kiệm, Phường 4, Quận Phú Nhuận & CVPM Quang Trung, Q.12, TP.HCM',
      category: 'Cao đẳng',
      latitude: 10.8122,
      longitude: 106.6749,
      aliases: ['cao dang fpt', 'fpt polytechnic', 'poly', 'cao dang fpt quang trung', 'fpoly'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng FPT Polytechnic (Cơ sở Hà Nội)',
      address: 'Đường Trịnh Văn Bô, Phường Phương Canh, Quận Nam Từ Liêm, Hà Nội',
      category: 'Cao đẳng',
      latitude: 21.0381,
      longitude: 105.7468,
      aliases: ['cao dang fpt ha noi', 'fpt polytechnic ha noi', 'trinh van bo'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng FPT Polytechnic (Đà Nẵng)',
      address: '137 Nguyễn Thị Thập, Phường Hòa Minh, Quận Liên Chiểu, Đà Nẵng',
      category: 'Cao đẳng',
      latitude: 16.0601,
      longitude: 108.1678,
      aliases: ['cao dang fpt da nang', 'fpt poly da nang'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng FPT Polytechnic (Cần Thơ)',
      address: 'Số 288, đường Nguyễn Văn Linh, Phường An Khánh, Quận Ninh Kiều, Cần Thơ',
      category: 'Cao đẳng',
      latitude: 10.0276,
      longitude: 105.7571,
      aliases: ['cao dang fpt can tho', 'fpt poly can tho'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Kỹ thuật Cao Thắng',
      address: '65 Huỳnh Thúc Kháng, Phường Bến Nghé, Quận 1, TP.HCM',
      category: 'Cao đẳng',
      latitude: 10.7718,
      longitude: 106.7011,
      aliases: ['cao dang cao thang', 'ckc', 'cao thang', 'ky thuat cao thang'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Kỹ thuật Lý Tự Trọng TP.HCM',
      address: '390 Hoàng Văn Thụ, Phường 4, Quận Tân Bình, TP.HCM',
      category: 'Cao đẳng',
      latitude: 10.7963,
      longitude: 106.6575,
      aliases: ['cao dang ly tu trong', 'ly tu trong tan binh', 'lttr'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Kinh tế Đối ngoại (Cơ sở Phú Nhuận)',
      address: '287 Phan Đình Phùng, Phường 15, Quận Phú Nhuận, TP.HCM',
      category: 'Cao đẳng',
      latitude: 10.7958,
      longitude: 106.6811,
      aliases: ['cao dang kinh te doi ngoai', 'cofer', 'kinh te doi ngoai phu nhuan'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Kinh tế Đối ngoại (Cơ sở TP. Thủ Đức)',
      address: 'Số 8 Dân Chủ, Phường Bình Thọ, TP. Thủ Đức, TP.HCM',
      category: 'Cao đẳng',
      latitude: 10.8492,
      longitude: 106.7699,
      aliases: ['cao dang kinh te doi ngoai thu duc', 'cofer thu duc'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Công thương TP.HCM (HITC)',
      address: '20 Tăng Nhơn Phú, Phường Phước Long B, TP. Thủ Đức, TP.HCM',
      category: 'Cao đẳng',
      latitude: 10.8306,
      longitude: 106.7725,
      aliases: ['cao dang cong thuong', 'hitc', 'cong thuong thu duc'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Công nghệ Thủ Đức (TDC)',
      address: '53 Võ Văn Ngân, Phường Linh Chiểu, TP. Thủ Đức, TP.HCM',
      category: 'Cao đẳng',
      latitude: 10.8519,
      longitude: 106.7583,
      aliases: ['cao dang cong nghe thu duc', 'tdc', 'vo van ngan'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Bách khoa Sài Gòn (BKC)',
      address: '32 Nguyễn Bỉnh Khiêm, Phường 1, Quận Gò Vấp, TP.HCM',
      category: 'Cao đẳng',
      latitude: 10.8174,
      longitude: 106.6892,
      aliases: ['cao dang bach khoa sai gon', 'bkc', 'bach khoa sai gon'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Viễn Đông',
      address: 'Lô 2, Công viên phần mềm Quang Trung, Phường Tân Chánh Hiệp, Quận 12, TP.HCM',
      category: 'Cao đẳng',
      latitude: 10.8538,
      longitude: 106.6276,
      aliases: ['cao dang vien dong', 'vien dong quang trung', 'vido'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Giao thông Vận tải TP.HCM',
      address: '252 Lý Chính Thắng, Phường 9, Quận 3, TP.HCM',
      category: 'Cao đẳng',
      latitude: 10.7831,
      longitude: 106.6789,
      aliases: ['cao dang giao thong van tai', 'gtvt ly chinh thang', 'hcmct'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Kinh tế TP.HCM (HCE)',
      address: '33 Vĩnh Viễn, Phường 2, Quận 10, TP.HCM',
      category: 'Cao đẳng',
      latitude: 10.7621,
      longitude: 106.6698,
      aliases: ['cao dang kinh te tphcm', 'hce', 'kinh te vinh vien'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Y Dược Pasteur TP.HCM',
      address: '37/3 Ngô Tất Tố, Phường 21, Quận Bình Thạnh, TP.HCM',
      category: 'Cao đẳng',
      latitude: 10.7932,
      longitude: 106.7118,
      aliases: ['cao dang y duoc pasteur', 'pasteur binh thanh', 'y pasteur'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Du lịch Sài Gòn',
      address: '347A Nguyễn Thượng Hiền, Phường 11, Quận 10, TP.HCM',
      category: 'Cao đẳng',
      latitude: 10.7745,
      longitude: 106.6782,
      aliases: ['cao dang du lich sai gon', 'du lich sai gon nguyen thuong hien'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Sư phạm Trung ương TP.HCM',
      address: '182 Nguyễn Chí Thanh, Phường 3, Quận 10, TP.HCM',
      category: 'Cao đẳng',
      latitude: 10.7588,
      longitude: 106.6685,
      aliases: ['cao dang su pham trung uong', 'su pham mam non'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Xây dựng TP.HCM (HCC2)',
      address: '190 Võ Văn Ngân, Phường Bình Thọ, TP. Thủ Đức, TP.HCM',
      category: 'Cao đẳng',
      latitude: 10.8491,
      longitude: 106.7645,
      aliases: ['cao dang xay dung tphcm', 'xay dung thu duc', 'hcc2'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Y tế Cần Thơ',
      address: '340 đường 30 Tháng 4, Phường Hưng Lợi, Quận Ninh Kiều, Cần Thơ',
      category: 'Cao đẳng',
      latitude: 10.0212,
      longitude: 105.7689,
      aliases: ['cao dang y te can tho', 'y te can tho'],
    ),
    MapLandmarkItem(
      name: 'Trường Cao đẳng Cần Thơ',
      address: '413 đường 30 Tháng 4, Phường Hưng Lợi, Quận Ninh Kiều, Cần Thơ',
      category: 'Cao đẳng',
      latitude: 10.0195,
      longitude: 105.7672,
      aliases: ['cao dang can tho'],
    ),

    // =========================================================================
    // 2. HỆ THỐNG CÁC TRƯỜNG ĐẠI HỌC (UNIVERSITIES)
    // =========================================================================
    MapLandmarkItem(
      name: 'Đại học Quốc Gia TP.HCM (Khu đô thị ĐHQG / KTX Khu A & B)',
      address: 'Phường Linh Trung, TP. Thủ Đức, TP.HCM & Dĩ An, Bình Dương',
      category: 'Đại học',
      latitude: 10.8700,
      longitude: 106.8031,
      aliases: ['dhqg tphcm', 'lang dai hoc', 'ktx khu a', 'ktx khu b', 'dai hoc quoc gia'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Bách Khoa TP.HCM (Cơ sở 1)',
      address: '268 Lý Thường Kiệt, Phường 14, Quận 10, TP.HCM',
      category: 'Đại học',
      latitude: 10.7725,
      longitude: 106.6578,
      aliases: ['dai hoc bach khoa', 'bach khoa q10', 'hcmut', 'bk tphcm'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Bách Khoa TP.HCM (Cơ sở 2)',
      address: 'Khu Đô Thị ĐHQG, Phường Linh Trung, TP. Thủ Đức, TP.HCM',
      category: 'Đại học',
      latitude: 10.8804,
      longitude: 106.8055,
      aliases: ['bach khoa thu duc', 'hcmut co so 2'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Khoa học Tự nhiên TP.HCM (Cơ sở 1)',
      address: '227 Nguyễn Văn Cừ, Phường 4, Quận 5, TP.HCM',
      category: 'Đại học',
      latitude: 10.7628,
      longitude: 106.6826,
      aliases: ['khoa hoc tu nhien', 'khtn q5', 'hcmus'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Khoa học Tự nhiên TP.HCM (Cơ sở Linh Trung)',
      address: 'Khu phố 6, Phường Linh Trung, TP. Thủ Đức, TP.HCM',
      category: 'Đại học',
      latitude: 10.8757,
      longitude: 106.7981,
      aliases: ['khtn thu duc', 'hcmus linh trung'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Khoa học Xã hội và Nhân văn (Cơ sở 1)',
      address: '10-12 Đinh Tiên Hoàng, Phường Bến Nghé, Quận 1, TP.HCM',
      category: 'Đại học',
      latitude: 10.7865,
      longitude: 106.7018,
      aliases: ['nhan van q1', 'ussh q1', 'khoa hoc xa hoi va nhan van'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Công nghệ Thông tin - ĐHQG TP.HCM (UIT)',
      address: 'Khu phố 6, Phường Linh Trung, TP. Thủ Đức, TP.HCM',
      category: 'Đại học',
      latitude: 10.8702,
      longitude: 106.8033,
      aliases: ['uit', 'dai hoc cong nghe thong tin', 'cntt dhqg'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Kinh tế - Luật - ĐHQG TP.HCM (UEL)',
      address: '669 Quốc lộ 1K, Phường Linh Xuân, TP. Thủ Đức, TP.HCM',
      category: 'Đại học',
      latitude: 10.8768,
      longitude: 106.7712,
      aliases: ['uel', 'dai hoc kinh te luat', 'kinh te luat'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Sư phạm Kỹ thuật TP.HCM (HCMUTE)',
      address: '1 Võ Văn Ngân, Phường Linh Chiểu, TP. Thủ Đức, TP.HCM',
      category: 'Đại học',
      latitude: 10.8509,
      longitude: 106.7718,
      aliases: ['su pham ky thuat', 'spkt', 'hcmute', 'nga tu thu duc'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Tôn Đức Thắng (TDTU)',
      address: '19 Nguyễn Hữu Thọ, Phường Tân Phong, Quận 7, TP.HCM',
      category: 'Đại học',
      latitude: 10.7324,
      longitude: 106.6992,
      aliases: ['ton duc thang', 'tdtu', 'dai hoc q7', 'nguyen huu tho'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Kinh tế TP.HCM (UEH Cơ sở A)',
      address: '59C Nguyễn Đình Chiểu, Phường Võ Thị Sáu, Quận 3, TP.HCM',
      category: 'Đại học',
      latitude: 10.7828,
      longitude: 106.6957,
      aliases: ['ueh', 'dai hoc kinh te', 'kinh te q3'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Kinh tế TP.HCM (UEH Cơ sở B)',
      address: '279 Nguyễn Tri Phương, Phường 5, Quận 10, TP.HCM',
      category: 'Đại học',
      latitude: 10.7607,
      longitude: 106.6672,
      aliases: ['ueh co so b', 'ueh nguyen tri phuong'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Sư phạm TP.HCM (HCMUE)',
      address: '280 An Dương Vương, Phường 4, Quận 5, TP.HCM',
      category: 'Đại học',
      latitude: 10.7601,
      longitude: 106.6823,
      aliases: ['su pham tphcm', 'hcmue', 'dai hoc su pham'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Sài Gòn (SGU Cơ sở chính)',
      address: '273 An Dương Vương, Phường 3, Quận 5, TP.HCM',
      category: 'Đại học',
      latitude: 10.7595,
      longitude: 106.6817,
      aliases: ['sgu', 'dai hoc sai gon', 'sai gon q5'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Y Dược TP.HCM (UMP)',
      address: '217 Hồng Bàng, Phường 11, Quận 5, TP.HCM',
      category: 'Đại học',
      latitude: 10.7548,
      longitude: 106.6592,
      aliases: ['y duoc tphcm', 'ump', 'dai hoc y duoc', 'y duoc hong bang'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Y khoa Phạm Ngọc Thạch',
      address: '2 Dương Quang Trung, Phường 12, Quận 10, TP.HCM',
      category: 'Đại học',
      latitude: 10.7731,
      longitude: 106.6622,
      aliases: ['pham ngoc thach', 'pnt', 'y pham ngoc thach'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Công nghiệp TP.HCM (IUH)',
      address: '12 Nguyễn Văn Bảo, Phường 4, Quận Gò Vấp, TP.HCM',
      category: 'Đại học',
      latitude: 10.8223,
      longitude: 106.6874,
      aliases: ['dai hoc cong nghiep', 'iuh', 'cong nghiep go vap'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Công Thương TP.HCM (HUIT)',
      address: '140 Lê Trọng Tấn, Phường Tây Thạnh, Quận Tân Phú, TP.HCM',
      category: 'Đại học',
      latitude: 10.8066,
      longitude: 106.6288,
      aliases: ['huit', 'cong nghiep thuc pham', 'dai hoc cong thuong', 'le trong tan'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Nông Lâm TP.HCM (NLU)',
      address: 'Khu phố 6, Phường Linh Trung, TP. Thủ Đức, TP.HCM',
      category: 'Đại học',
      latitude: 10.8711,
      longitude: 106.7925,
      aliases: ['nong lam', 'nlu', 'dai hoc nong lam thu duc'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Giao thông Vận tải TP.HCM (UTH)',
      address: 'Số 2 đường Võ Oanh, Phường 25, Quận Bình Thạnh, TP.HCM',
      category: 'Đại học',
      latitude: 10.8036,
      longitude: 106.7161,
      aliases: ['gtvt tphcm', 'uth', 'giao thong van tai vo oanh'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Ngoại thương (Cơ sở 2 TP.HCM)',
      address: '15 đường D5, Phường 25, Quận Bình Thạnh, TP.HCM',
      category: 'Đại học',
      latitude: 10.8065,
      longitude: 106.7144,
      aliases: ['ftu2', 'ngoai thuong co so 2', 'ftu binh thanh'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Ngân hàng TP.HCM (HUB)',
      address: '56 Hoàng Diệu 2, Phường Linh Trung, TP. Thủ Đức, TP.HCM',
      category: 'Đại học',
      latitude: 10.8572,
      longitude: 106.7648,
      aliases: ['ngan hang', 'hub', 'dai hoc ngan hang thu duc'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Công nghệ TP.HCM (HUTECH Cơ sở Điện Biên Phủ)',
      address: '475A Điện Biên Phủ, Phường 25, Quận Bình Thạnh, TP.HCM',
      category: 'Đại học',
      latitude: 10.8015,
      longitude: 106.7142,
      aliases: ['hutech', 'dai hoc hutech', 'hutech dien bien phu'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Văn Lang (Cơ sở chính Q. Gò Vấp)',
      address: '69/68 Đặng Thùy Trâm, Phường 13, Quận Gò Vấp, TP.HCM',
      category: 'Đại học',
      latitude: 10.8286,
      longitude: 106.7028,
      aliases: ['van lang', 'vlu', 'van lang go vap', 'dang thuy tram'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Luật TP.HCM (Cơ sở 1)',
      address: '2 Nguyễn Tất Thành, Phường 12, Quận 4, TP.HCM',
      category: 'Đại học',
      latitude: 10.7674,
      longitude: 106.7061,
      aliases: ['luat tphcm', 'hul', 'dai hoc luat q4'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học FPT TP.HCM',
      address: 'Lô E2a-7, Đường D1, Khu Công nghệ cao, Phường Long Thạnh Mỹ, TP. Thủ Đức, TP.HCM',
      category: 'Đại học',
      latitude: 10.8413,
      longitude: 106.8099,
      aliases: ['dai hoc fpt', 'fpt khu cong nghe cao', 'fpt university'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Cần Thơ (Khu 2)',
      address: 'Đường 3 Tháng 2, Phường Xuân Khánh, Quận Ninh Kiều, Cần Thơ',
      category: 'Đại học',
      latitude: 10.0299,
      longitude: 105.7706,
      aliases: ['dai hoc can tho', 'ctu', 'can tho khu 2'],
    ),
    MapLandmarkItem(
      name: 'Đại học Bách Khoa Hà Nội (HUST)',
      address: 'Số 1 Đại Cồ Việt, Phường Bách Khoa, Quận Hai Bà Trưng, Hà Nội',
      category: 'Đại học',
      latitude: 21.0044,
      longitude: 105.8433,
      aliases: ['bach khoa ha noi', 'hust', 'dai co viet'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Kinh tế Quốc dân (NEU)',
      address: '207 Giải Phóng, Phường Đồng Tâm, Quận Hai Bà Trưng, Hà Nội',
      category: 'Đại học',
      latitude: 20.9996,
      longitude: 105.8427,
      aliases: ['kinh te quoc dan', 'neu', 'giai phong'],
    ),
    MapLandmarkItem(
      name: 'Trường Đại học Ngoại thương Hà Nội (FTU)',
      address: '91 Phố Chùa Láng, Phường Láng Thượng, Quận Đống Đa, Hà Nội',
      category: 'Đại học',
      latitude: 21.0232,
      longitude: 105.8052,
      aliases: ['ftu ha noi', 'ngoai thuong chua lang'],
    ),
    MapLandmarkItem(
      name: 'Đại học Bách Khoa - Đại học Đà Nẵng (DUT)',
      address: '54 Nguyễn Lương Bằng, Phường Hòa Khánh Bắc, Quận Liên Chiểu, Đà Nẵng',
      category: 'Đại học',
      latitude: 16.0748,
      longitude: 108.1498,
      aliases: ['bach khoa da nang', 'dut', 'dai hoc bach khoa da nang'],
    ),

    // =========================================================================
    // 3. BẾN XE, GA TÀU & SÂN BAY
    // =========================================================================
    MapLandmarkItem(
      name: 'Bến xe Miền Đông mới (TP. Thủ Đức)',
      address: '501 Hoàng Hữu Nam, Phường Long Bình, TP. Thủ Đức, TP.HCM',
      category: 'Bến xe & Ga',
      latitude: 10.8837,
      longitude: 106.8291,
      aliases: ['ben xe mien dong moi', 'bx mien dong moi', 'suoi tien'],
    ),
    MapLandmarkItem(
      name: 'Bến xe Miền Đông cũ (Quận Bình Thạnh)',
      address: '292 Đinh Bộ Lĩnh, Phường 26, Quận Bình Thạnh, TP.HCM',
      category: 'Bến xe & Ga',
      latitude: 10.8123,
      longitude: 106.7118,
      aliases: ['ben xe mien dong cu', 'bx mien dong binh thanh'],
    ),
    MapLandmarkItem(
      name: 'Bến xe Miền Tây (Quận Bình Tân)',
      address: '395 Kinh Dương Vương, Phường An Lạc, Quận Bình Tân, TP.HCM',
      category: 'Bến xe & Ga',
      latitude: 10.7397,
      longitude: 106.6192,
      aliases: ['ben xe mien tay', 'bx mien tay', 'kinh duong vuong'],
    ),
    MapLandmarkItem(
      name: 'Bến xe An Sương (Quận 12 / Hóc Môn)',
      address: 'Quốc lộ 22, Xã Bà Điểm, Huyện Hóc Môn, TP.HCM',
      category: 'Bến xe & Ga',
      latitude: 10.8491,
      longitude: 106.6152,
      aliases: ['ben xe an suong', 'bx an suong', 'nga tu an suong'],
    ),
    MapLandmarkItem(
      name: 'Sân bay Quốc tế Tân Sơn Nhất',
      address: 'Đường Trường Sơn, Phường 2, Quận Tân Bình, TP.HCM',
      category: 'Bến xe & Ga',
      latitude: 10.8185,
      longitude: 106.6588,
      aliases: ['san bay tan son nhat', 'tan son nhat', 'tsn airport'],
    ),
    MapLandmarkItem(
      name: 'Ga Sài Gòn (Ga đường sắt Hòa Hưng)',
      address: '1 Nguyễn Thông, Phường 9, Quận 3, TP.HCM',
      category: 'Bến xe & Ga',
      latitude: 10.7818,
      longitude: 106.6749,
      aliases: ['ga sai gon', 'ga hoa hung', 'nguyen thong'],
    ),
    MapLandmarkItem(
      name: 'Bến xe Mỹ Đình (Hà Nội)',
      address: 'Số 20 Phạm Hùng, Phường Mỹ Đình 2, Quận Nam Từ Liêm, Hà Nội',
      category: 'Bến xe & Ga',
      latitude: 21.0284,
      longitude: 105.7779,
      aliases: ['ben xe my dinh', 'bx my dinh', 'pham hung'],
    ),
    MapLandmarkItem(
      name: 'Sân bay Quốc tế Nội Bài (Hà Nội)',
      address: 'Xã Phú Minh, Huyện Sóc Sơn, Hà Nội',
      category: 'Bến xe & Ga',
      latitude: 21.2187,
      longitude: 105.8042,
      aliases: ['san bay noi bai', 'noi bai airport'],
    ),
    MapLandmarkItem(
      name: 'Sân bay Quốc tế Đà Nẵng',
      address: 'Đường Duy Tân, Phường Hòa Thuận Tây, Quận Hải Châu, Đà Nẵng',
      category: 'Bến xe & Ga',
      latitude: 16.0538,
      longitude: 108.2022,
      aliases: ['san bay da nang', 'da nang airport'],
    ),

    // =========================================================================
    // 4. BỆNH VIỆN TRỌNG ĐIỂM
    // =========================================================================
    MapLandmarkItem(
      name: 'Bệnh viện Chợ Rẫy (Quận 5)',
      address: '201B Nguyễn Chí Thanh, Phường 12, Quận 5, TP.HCM',
      category: 'Bệnh viện',
      latitude: 10.7577,
      longitude: 106.6596,
      aliases: ['benh vien cho ray', 'cho ray', 'bv cho ray'],
    ),
    MapLandmarkItem(
      name: 'Bệnh viện Từ Dũ (Quận 1)',
      address: '284 Cống Quỳnh, Phường Phạm Ngũ Lão, Quận 1, TP.HCM',
      category: 'Bệnh viện',
      latitude: 10.7678,
      longitude: 106.6859,
      aliases: ['benh vien tu du', 'tu du', 'bv tu du'],
    ),
    MapLandmarkItem(
      name: 'Bệnh viện Đại học Y Dược TP.HCM',
      address: '215 Hồng Bàng, Phường 11, Quận 5, TP.HCM',
      category: 'Bệnh viện',
      latitude: 10.7554,
      longitude: 106.6601,
      aliases: ['bv dai hoc y duoc', 'benh vien dai hoc y duoc'],
    ),
    MapLandmarkItem(
      name: 'Bệnh viện Ung Bướu (Cơ sở 2 TP. Thủ Đức)',
      address: 'Số 12 đường 400, Phường Tân Phú, TP. Thủ Đức, TP.HCM',
      category: 'Bệnh viện',
      latitude: 10.8652,
      longitude: 106.8285,
      aliases: ['benh vien ung buou', 'ung buou co so 2'],
    ),
    MapLandmarkItem(
      name: 'Bệnh viện Bạch Mai (Hà Nội)',
      address: '78 Giải Phóng, Phường Phương Mai, Quận Đống Đa, Hà Nội',
      category: 'Bệnh viện',
      latitude: 21.0028,
      longitude: 105.8406,
      aliases: ['benh vien bach mai', 'bach mai ha noi'],
    ),

    // =========================================================================
    // 5. ĐỊA DANH, TRUNG TÂM & KHU ĐÔ THỊ
    // =========================================================================
    MapLandmarkItem(
      name: 'Chợ Bến Thành (Quận 1, TP.HCM)',
      address: 'Đường Lê Lợi, Phường Bến Thành, Quận 1, TP.HCM',
      category: 'Địa danh',
      latitude: 10.7725,
      longitude: 106.6980,
      aliases: ['cho ben thanh', 'ben thanh', 'trung tam quan 1'],
    ),
    MapLandmarkItem(
      name: 'Landmark 81 & Vinhomes Central Park',
      address: '720A Điện Biên Phủ, Phường 22, Quận Bình Thạnh, TP.HCM',
      category: 'Địa danh',
      latitude: 10.7950,
      longitude: 106.7219,
      aliases: ['landmark 81', 'vinhomes central park', 'tan cang'],
    ),
    MapLandmarkItem(
      name: 'Phố đi bộ Nguyễn Huệ (Quận 1)',
      address: 'Đường Nguyễn Huệ, Phường Bến Nghé, Quận 1, TP.HCM',
      category: 'Địa danh',
      latitude: 10.7745,
      longitude: 106.7038,
      aliases: ['pho di bo nguyen hue', 'nguyen hue', 'uy ban nhan dan'],
    ),
    MapLandmarkItem(
      name: 'Khu đô thị Phú Mỹ Hưng (Quận 7)',
      address: 'Đại lộ Nguyễn Văn Linh, Phường Tân Phong, Quận 7, TP.HCM',
      category: 'Địa danh',
      latitude: 10.7289,
      longitude: 106.7188,
      aliases: ['phu my hung', 'pmh', 'crescent mall', 'ho ban nguyet'],
    ),
    MapLandmarkItem(
      name: 'Hồ Hoàn Kiếm (Hà Nội)',
      address: 'Phường Hàng Trống, Quận Hoàn Kiếm, Hà Nội',
      category: 'Địa danh',
      latitude: 21.0285,
      longitude: 105.8542,
      aliases: ['ho hoan kiem', 'ho guom', 'thap rua', 'pho co ha noi'],
    ),
    MapLandmarkItem(
      name: 'Hồ Tây (Hà Nội)',
      address: 'Quận Tây Hồ, Hà Nội',
      category: 'Địa danh',
      latitude: 21.0565,
      longitude: 105.8242,
      aliases: ['ho tay', 'tay ho ha noi'],
    ),
    MapLandmarkItem(
      name: 'Cầu Rồng (Đà Nẵng)',
      address: 'Đường Nguyễn Văn Linh, Phường Phước Ninh, Quận Hải Châu, Đà Nẵng',
      category: 'Địa danh',
      latitude: 16.0610,
      longitude: 108.2274,
      aliases: ['cau rong', 'song han', 'cau rong da nang'],
    ),
    MapLandmarkItem(
      name: 'Bến Ninh Kiều (Cần Thơ)',
      address: 'Đường Hai Bà Trưng, Phường Tân An, Quận Ninh Kiều, Cần Thơ',
      category: 'Địa danh',
      latitude: 10.0336,
      longitude: 105.7878,
      aliases: ['ben ninh kieu', 'ninh kieu can tho'],
    ),

    // =========================================================================
    // 6. CÁC QUẬN / HUYỆN TRỌNG ĐIỂM
    // =========================================================================
    MapLandmarkItem(
      name: 'Quận 1 (Trung tâm TP.HCM)',
      address: 'Quận 1, TP. Hồ Chí Minh',
      category: 'Khu vực',
      latitude: 10.7769,
      longitude: 106.7009,
      aliases: ['quan 1', 'q1', 'quan nhat'],
    ),
    MapLandmarkItem(
      name: 'Quận 3 (TP.HCM)',
      address: 'Quận 3, TP. Hồ Chí Minh',
      category: 'Khu vực',
      latitude: 10.7844,
      longitude: 106.6844,
      aliases: ['quan 3', 'q3'],
    ),
    MapLandmarkItem(
      name: 'Quận 5 (Chợ Lớn, TP.HCM)',
      address: 'Quận 5, TP. Hồ Chí Minh',
      category: 'Khu vực',
      latitude: 10.7541,
      longitude: 106.6634,
      aliases: ['quan 5', 'q5', 'cho lon'],
    ),
    MapLandmarkItem(
      name: 'Quận 7 (TP.HCM)',
      address: 'Quận 7, TP. Hồ Chí Minh',
      category: 'Khu vực',
      latitude: 10.7340,
      longitude: 106.7218,
      aliases: ['quan 7', 'q7'],
    ),
    MapLandmarkItem(
      name: 'Quận 10 (TP.HCM)',
      address: 'Quận 10, TP. Hồ Chí Minh',
      category: 'Khu vực',
      latitude: 10.7674,
      longitude: 106.6664,
      aliases: ['quan 10', 'q10'],
    ),
    MapLandmarkItem(
      name: 'Quận Bình Thạnh (TP.HCM)',
      address: 'Quận Bình Thạnh, TP. Hồ Chí Minh',
      category: 'Khu vực',
      latitude: 10.8036,
      longitude: 106.7114,
      aliases: ['binh thanh', 'quan binh thanh', 'hang xanh'],
    ),
    MapLandmarkItem(
      name: 'Quận Gò Vấp (TP.HCM)',
      address: 'Quận Gò Vấp, TP. Hồ Chí Minh',
      category: 'Khu vực',
      latitude: 10.8388,
      longitude: 106.6653,
      aliases: ['go vap', 'quan go vap', 'quang trung'],
    ),
    MapLandmarkItem(
      name: 'Quận Tân Bình (TP.HCM)',
      address: 'Quận Tân Bình, TP. Hồ Chí Minh',
      category: 'Khu vực',
      latitude: 10.7983,
      longitude: 106.6542,
      aliases: ['tan binh', 'quan tan binh'],
    ),
    MapLandmarkItem(
      name: 'TP. Thủ Đức (TP.HCM)',
      address: 'TP. Thủ Đức, TP. Hồ Chí Minh',
      category: 'Khu vực',
      latitude: 10.8497,
      longitude: 106.7717,
      aliases: ['thu duc', 'tp thu duc', 'quan 2', 'quan 9'],
    ),
    MapLandmarkItem(
      name: 'Quận Cầu Giấy (Hà Nội)',
      address: 'Quận Cầu Giấy, Hà Nội',
      category: 'Khu vực',
      latitude: 21.0362,
      longitude: 105.7906,
      aliases: ['cau giay', 'quan cau giay', 'xuan thuy'],
    ),
    MapLandmarkItem(
      name: 'Quận Đống Đa (Hà Nội)',
      address: 'Quận Đống Đa, Hà Nội',
      category: 'Khu vực',
      latitude: 21.0180,
      longitude: 105.8290,
      aliases: ['dong da', 'quan dong da'],
    ),
    MapLandmarkItem(
      name: 'Quận Hải Châu (Đà Nẵng)',
      address: 'Quận Hải Châu, Đà Nẵng',
      category: 'Khu vực',
      latitude: 16.0544,
      longitude: 108.2022,
      aliases: ['hai chau', 'quan hai chau'],
    ),
    MapLandmarkItem(
      name: 'Quận Ninh Kiều (Cần Thơ)',
      address: 'Quận Ninh Kiều, Cần Thơ',
      category: 'Khu vực',
      latitude: 10.0342,
      longitude: 105.7794,
      aliases: ['ninh kieu', 'quan ninh kieu'],
    ),
  ];

  /// Hàm tìm kiếm địa danh và trường học thông minh
  /// Hỗ trợ cả gõ có dấu, không dấu, viết tắt, và từ khóa liên quan
  static List<MapLandmarkItem> search(String query, {int limit = 20}) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];

    final normalizedQ = normalizeVietnameseComparison(cleanQuery);
    final results = <MapLandmarkItem>[];

    // Điểm số ưu tiên khớp:
    // 3: Tên bắt đầu bằng từ khóa
    // 2: Tên chứa từ khóa hoặc danh mục khớp chính xác
    // 1: Bí danh / địa chỉ chứa từ khóa
    final scored = <MapLandmarkItem, int>{};

    for (final item in allLandmarks) {
      final normName = normalizeVietnameseComparison(item.name);
      final normCategory = normalizeVietnameseComparison(item.category);
      final normAddr = normalizeVietnameseComparison(item.address);

      if (normName.startsWith(normalizedQ) || normCategory.startsWith(normalizedQ)) {
        scored[item] = 3;
      } else if (normName.contains(normalizedQ) || normCategory.contains(normalizedQ)) {
        scored[item] = 2;
      } else if (normAddr.contains(normalizedQ)) {
        scored[item] = 1;
      } else {
        for (final alias in item.aliases) {
          final normAlias = normalizeVietnameseComparison(alias);
          if (normAlias.contains(normalizedQ) || normalizedQ.contains(normAlias)) {
            scored[item] = 2;
            break;
          }
        }
      }
    }

    final sortedItems = scored.keys.toList()
      ..sort((a, b) {
        final scoreA = scored[a] ?? 0;
        final scoreB = scored[b] ?? 0;
        if (scoreA != scoreB) return scoreB.compareTo(scoreA);
        return a.name.compareTo(b.name);
      });

    results.addAll(sortedItems.take(limit));
    return results;
  }
}
