# Tối ưu đội hình — Dữ liệu tra cứu Genshin Impact

Tư liệu nguồn dạng Markdown cho tính năng gợi ý đội hình Trầm Thủy (Spiral
Abyss) của NS Launcher — người viết đọc và cập nhật ở đây, còn app đọc bản
JSON tương ứng.

> **Đã đổi (2026-09-08):** trước đây thư mục này ghi rõ "không được đóng gói
> vào NSLauncher". Quyết định đó đã đảo: tính năng nay chạy **trong app** nên
> bản JSON đã chuyển sang
> [`Sources/NSLauncherApp/Resources/Abyss/`](../Sources/NSLauncherApp/Resources/Abyss/README.md)
> để SwiftPM đóng gói được (SwiftPM chỉ đóng gói tài nguyên nằm trong thư mục
> target). Thư mục này giữ **bản Markdown cho người đọc** + JSON Schema; nó
> vẫn không được đóng gói vào app.

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
- [`cong-huong-nguyen-to.md`](cong-huong-nguyen-to.md) — Buff tự động theo
  thành phần đội hình: Cộng Hưởng Nguyên Tố (Elemental Resonance), Nguyệt
  Triệu (Moonsign), Hexerei, Nightsoul Burst — luôn đáng cân nhắc khi ghép
  4 nhân vật vì không cần build gì thêm.
- [`data-model/`](data-model/README.md) — JSON Schema (hợp đồng dữ liệu) cho
  bản JSON của toàn bộ các mục trên. **Dữ liệu JSON thật nằm ở
  [`Sources/NSLauncherApp/Resources/Abyss/`](../Sources/NSLauncherApp/Resources/Abyss/README.md)**
  vì nó được đóng gói vào app.
- [`optimizer/`](optimizer/README.md) — Bản Python của thuật toán gợi ý đội
  hình. Bản chính thức là engine Swift trong app
  (`Sources/NSLauncherApp/Services/Abyss/`); bản Python giữ lại làm sân thử
  tham số và bộ sinh fixture đối chiếu cho test.

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
