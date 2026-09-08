# Tối ưu đội hình — Dữ liệu tra cứu Genshin Impact

Kho dữ liệu tham khảo (không phải mã nguồn ứng dụng, không được đóng gói vào
NSLauncher) để lên đội hình tối ưu cho từng mùa Trầm Thủy (Spiral Abyss).
Tách biệt khỏi `Sources/NSLauncherApp/Resources/Story/` vì đây là dữ liệu
gameplay/thông số, thay đổi theo từng bản cập nhật, không phải cốt truyện.

## Cấu trúc

- [`quai-vat-la-hoan/`](quai-vat-la-hoan/README.md) — Quái thú Trầm Thủy của
  mùa hiện tại: kích thước, nguyên tố, điểm yếu, cơ chế tầng, hiệu ứng chúc
  phúc (blessing).
- [`nhan-vat/`](nhan-vat/README.md) — Toàn bộ nhân vật: bộ kỹ năng, mô tả và
  hệ số sát thương chi tiết, cung mệnh, chỉ số cơ bản/tăng trưởng.
- [`vu-khi/`](vu-khi/README.md) — Toàn bộ vũ khí theo loại: chỉ số chính,
  hiệu ứng phụ, thông số hiệu ứng theo từng cấp tinh luyện (R1–R5).
- [`thanh-di-vat/`](thanh-di-vat/README.md) — Toàn bộ bộ thánh di vật: hiệu
  ứng 2 món / 4 món, nhân vật phù hợp.
- [`cong-thuc-sat-thuong.md`](cong-thuc-sat-thuong.md) — Công thức tính sát
  thương gốc của game (DEF/RES/CRIT, phản ứng khuếch đại/chuyển hóa/cộng
  dồn, và cơ chế Lunar & Stellar Glimmer Reaction mới) — dùng để tự tính
  DPS thực tế của một đội hình thay vì chỉ so % trên giấy.
- [`data-model/`](data-model/README.md) — Bản JSON có cấu trúc (JSON Schema
  + dữ liệu) của toàn bộ 4 mục trên, để một thuật toán tối ưu đội hình đọc
  và tính toán tự động thay vì phải parse Markdown.

## Nguồn dữ liệu

Ưu tiên theo thứ tự:

1. API dữ liệu trích xuất trực tiếp từ game (Ambr — `api.ambr.top`, hoặc
   Yatta — `gi.yatta.moe`) — số liệu chính xác nhất vì lấy thẳng từ file
   Excel của game.
2. Genshin Impact Wiki (Fandom) qua MediaWiki API
   (`action=parse&prop=wikitext`, `action=query&list=categorymembers`) —
   dùng khi API ở trên không truy cập được. Fetch/scrape HTML trực tiếp của
   Fandom thường bị chặn (402/403); dùng API là cách đáng tin cậy.
3. HoYoWiki chính thức (`wiki.hoyolab.com`) để đối chiếu khi cần.

Mỗi file dữ liệu **phải** ghi rõ ngày lấy dữ liệu và nguồn ở đầu file, vì:

- Chỉ số nhân vật/vũ khí/thánh di vật thay đổi khi có bản cập nhật mới
  (buff/nerf hiếm khi xảy ra nhưng nhân vật/vũ khí mới ra liên tục).
- Mùa Trầm Thủy đổi quái vật + chúc phúc mỗi 2 tuần (reset ngày 1 và 16 hằng
  tháng) — dữ liệu trong `quai-vat-la-hoan/` **hết hạn nhanh nhất**, cần ghi
  rõ khoảng ngày áp dụng.

## Quy ước định dạng

- Tiêu đề/mô tả bằng tiếng Việt; tên riêng (kỹ năng, vũ khí, bộ thánh di vật,
  nhân vật) giữ nguyên tiếng Anh chính thức để tiện tra cứu chéo với
  cộng đồng quốc tế.
- Số liệu trình bày dưới dạng bảng Markdown, không viết văn xuôi dài dòng.
- Không tự suy diễn số liệu — nếu không tìm được nguồn đáng tin, ghi chú rõ
  "chưa xác nhận" thay vì bịa số.
