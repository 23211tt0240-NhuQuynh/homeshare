import 'post_image_ocr_stub.dart'
    if (dart.library.io) 'post_image_ocr_native.dart'
    as image_ocr;

class PostContentScreeningService {
  PostContentScreeningService._();

  static const _riskPhrases = <String, String>{
    'chuyen tien truoc': 'Yêu cầu chuyển tiền trước khi xem phòng',
    'coc truoc': 'Yêu cầu đặt cọc trước',
    'gui tien truoc': 'Yêu cầu gửi tiền trước',
    'khong can xem phong': 'Không cần xem phòng trước khi giao dịch',
    'bao dam loi nhuan': 'Cam kết lợi nhuận bất thường',
    'cam ket loi nhuan': 'Cam kết lợi nhuận bất thường',
    'lien he zalo': 'Dẫn liên hệ ra ngoài nền tảng',
    'telegram': 'Dẫn liên hệ ra ngoài nền tảng',
    'ib rieng': 'Dẫn liên hệ ra ngoài nền tảng',
  };

  static List<String> reviewReasons(
    Map<String, dynamic> data, {
    String extraText = '',
  }) {
    final text = [
      data['title'],
      data['description'],
      data['content'],
      data['moTa'],
      data['noiDung'],
      data['address'],
      data['diaChi'],
    ].whereType<String>().join(' ').toLowerCase();
    final normalized = _removeVietnameseMarks('$text $extraText'.toLowerCase());
    final reasons = <String>{};

    for (final entry in _riskPhrases.entries) {
      if (normalized.contains(entry.key)) reasons.add(entry.value);
    }

    final price = data['rentalPrice'] ?? data['price'] ?? data['giaThue'];
    if (price is num && price > 0 && price < 500000) {
      reasons.add('Giá thuê thấp bất thường, nên đối chiếu lại');
    }

    final phone = (data['hostPhone'] ?? data['phone'] ?? '').toString();
    if (phone.isEmpty && RegExp(r'\b\d{9,11}\b').hasMatch('$text $extraText')) {
      reasons.add('Số liên hệ trong nội dung khác trường thông tin chủ trọ');
    }
    return reasons.toList();
  }

  /// OCRs Firebase-hosted listing photos on Android/iOS. OCR runs locally;
  /// web and unsupported URLs return no extracted text.
  static Future<String?> scanImages(List<String> urls) async {
    return image_ocr.scan(urls);
  }

  static String _removeVietnameseMarks(String value) {
    const groups = {
      'a': 'áàảãạăắằẳẵặâấầẩẫậ',
      'e': 'éèẻẽẹêếềểễệ',
      'i': 'íìỉĩị',
      'o': 'óòỏõọôốồổỗộơớờởỡợ',
      'u': 'úùủũụưứừửữự',
      'y': 'ýỳỷỹỵ',
      'd': 'đ',
    };
    var result = value;
    for (final entry in groups.entries) {
      for (final mark in entry.value.split('')) {
        result = result.replaceAll(mark, entry.key);
      }
    }
    return result;
  }
}
