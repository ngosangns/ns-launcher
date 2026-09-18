# Nhân vật

Một file Markdown cho mỗi nhóm quốc gia, chứa **toàn bộ** nhân vật đã phát
hành thuộc nhóm đó (kể cả 4 sao). Mỗi nhân vật là một mục riêng gồm:

1. **Thông tin chung**: nguyên tố, vũ khí, độ hiếm, quốc gia, ngày ra mắt.
2. **Chỉ số cơ bản**: HP/ATK/DEF ở cấp 1, cấp 90 (trước và sau đột phá cuối),
   chỉ số đột phá phụ (crit rate/dmg/EM/ER/...) và giá trị ở cấp 90.
3. **Bộ kỹ năng** — cho từng kỹ năng (đòn thường/né/nhảy nếu đặc biệt, kỹ
   năng nguyên tố, kỹ năng cường kích/giữ nếu có, bùng nổ nguyên tố, các
   passive):
   - Mô tả chi tiết cơ chế.
   - Hệ số sát thương (% ATK/HP/DEF/EM tuỳ nhân vật) ở cấp kỹ năng 1 **và**
     cấp 10 (thường) / cấp 13 (nếu là nhân vật chính truyện có thể lên tối
     đa qua cung mệnh), để thấy rõ độ scale.
   - Thời gian hồi chiêu, tiêu hao năng lượng (với bùng nổ).
4. **Cung mệnh (Constellation) C1–C6**: tên, mô tả đầy đủ, số liệu kèm theo.
5. **Gợi ý đội hình Trầm Thủy**: vai trò (DPS chính/phụ, hỗ trợ, khiên,
   heal...), 1–2 combo nguyên tố phổ biến đi kèm.

## File theo nhóm

- `mondstadt.md` — Mondstadt + Nod-Krai + Nhà Lữ Hành (mọi nguyên tố).
- `liyue.md` — Liyue + Snezhnaya.
- `inazuma-fontaine.md` — Inazuma + Fontaine.
- `sumeru-natlan.md` — Sumeru + Natlan.

(Nếu một quốc gia có quá nhiều nhân vật khiến file vượt quá khả năng đọc,
được phép tách thêm file con trong cùng thư mục và cập nhật danh sách trên.)
