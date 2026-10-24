"""Cập nhật danh mục địa chỉ dự phòng: python scripts/refresh_vietnam_addresses.py."""
import datetime
import json
from pathlib import Path
from urllib.request import urlopen

URL = "https://provinces.open-api.vn/api/v2/?depth=2"
rows = json.load(urlopen(URL, timeout=30))
assert len(rows) >= 30, "Incomplete provinces"
codes = set()
for province in rows:
    assert province["name"] and province["wards"], "Incomplete province"
    for ward in province["wards"]:
        assert ward["name"] and ward["code"] not in codes, "Invalid ward"
        codes.add(ward["code"])
raw = json.dumps(rows, ensure_ascii=False, separators=(",", ":"))
target = Path(__file__).resolve().parents[1] / "lib/core/constants/vietnam_current_data.dart"
target.write_text(
    f"// Địa chỉ - Nguồn dữ liệu dự phòng: {URL}\n// Tải ngày {datetime.date.today()}; dùng khi chưa có cache. Khi khởi động, ứng dụng cập nhật lại qua API.\n"
    + "const vietnamCurrentRawJson = r\'\'\'" + raw + "\'\'\';\n", encoding="utf-8")
print(f"Updated {len(rows)} provinces and {len(codes)} wards")
