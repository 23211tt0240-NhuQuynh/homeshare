// Chủ trọ - Tỷ lệ cọc - Luồng đi: Chỉ chọn các mức 10% đến 100%,
// tính theo giá thuê tháng và làm tròn tới đồng khi lưu Firebase.
const roomDepositPercentages = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];

double roomDeposit(num monthlyPrice, int percentage) {
  if (!monthlyPrice.isFinite ||
      monthlyPrice < 0 ||
      !roomDepositPercentages.contains(percentage)) {
    throw ArgumentError('Giá thuê hoặc tỷ lệ tiền cọc không hợp lệ');
  }
  return (monthlyPrice * percentage / 100).roundToDouble();
}

// Chủ trọ - Nạp cọc cũ - Luồng đi: Chỉ tự chọn nếu số cọc khớp đúng
// một mức hợp lệ; không tự đổi cọc 0 hoặc khoản cọc cũ ngoài các mức đó.
int? existingRoomDepositPercentage(num price, num deposit, int? stored) {
  if (!price.isFinite || price <= 0 || !deposit.isFinite) return null;
  if (stored != null &&
      roomDepositPercentages.contains(stored) &&
      roomDeposit(price, stored) == deposit) {
    return stored;
  }
  for (final percentage in roomDepositPercentages) {
    if (roomDeposit(price, percentage) == deposit) return percentage;
  }
  return null;
}
