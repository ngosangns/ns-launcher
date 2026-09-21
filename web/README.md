# Ký Sự Teyvat

Bản web của tab **Cốt truyện** và **La Hoàn** trong NS Launcher: đọc chương
truyện, tra cứu nhân vật/vũ khí/thánh di vật, xem chu kỳ Trầm Thủy, và ghép
đội theo Ley Line.

Dữ liệu lấy thẳng từ
[`Sources/NSLauncherApp/Resources/Story`](../Sources/NSLauncherApp/Resources/Story)
và
[`Sources/NSLauncherApp/Resources/Abyss`](../Sources/NSLauncherApp/Resources/Abyss)
— không sao chép.

Đã chuyển hết nội dung người đọc: 9 chương + 12 file nhiệm vụ + 98 thực thể;
125 nhân vật (kèm bảng talent và kit); 246 vũ khí (kèm R1–R5); 63 thánh di
vật; 2 chu kỳ quái; cộng hưởng / Nguyệt Triệu / Hexerei / Nightsoul; toàn bộ
công thức sát thương trong `damage-formula.json`.

Tab **Đội hình** là luồng chính của app macOS: roster (đánh dấu sở hữu, cung
mệnh, tinh luyện, nhập/xuất JSON), nhập UID qua Enka, nhập full roster
HoYoLAB, và **Tìm đội hình** cho tầng 12 (hai nửa, không trùng người/vũ khí,
gán thánh di vật, cộng hưởng, thời gian dọn ước lượng).

Điểm trên web là thang xếp hạng theo Ley Line + cộng hưởng + vai trò, không
phải mô phỏng DPS đầy đủ của engine Swift (`AbyssScorer`). Enka/HoYoLAB đi
qua proxy Vite (`npm run dev` / `task web`).

## Theme & chữ

Nền đêm/vàng của launcher (`LauncherTheme`). Chữ:

- **Be Vietnam Pro** — UI, được thiết kế cho tiếng Việt
- **Source Serif 4** — thân bài cốt truyện, subset tiếng Việt trên Google Fonts

## Chạy

```bash
cd web
npm install
npm test
npm run dev
```

Mở `http://localhost:5173`. Build tĩnh:

```bash
npm run build
npm run preview
```

`task web` từ thư mục gốc repo cũng chạy `npm run dev`.
