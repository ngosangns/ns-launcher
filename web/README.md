# Ký Sự Teyvat

Trang SolidJS cho cốt truyện và La Hoàn: đọc chương truyện, tra cứu nhân vật/vũ
khí/thánh di vật, xem chu kỳ Trầm Thủy, và ghép đội theo Ley Line. App macOS
không còn hai màn này.

Dữ liệu lấy thẳng từ
[`Sources/NSLauncherApp/Resources/Story`](../Sources/NSLauncherApp/Resources/Story)
và
[`Sources/NSLauncherApp/Resources/Abyss`](../Sources/NSLauncherApp/Resources/Abyss)
— không sao chép.

Đã chuyển hết nội dung người đọc: 9 chương + 12 file nhiệm vụ + 98 thực thể;
125 nhân vật (kèm bảng talent và kit); 246 vũ khí (kèm R1–R5); 63 thánh di
vật; 2 chu kỳ quái; cộng hưởng / Nguyệt Triệu / Hexerei / Nightsoul; toàn bộ
công thức sát thương trong `damage-formula.json`.

Trang **Đội hình**: roster (đánh dấu sở hữu, cung mệnh, tinh luyện, nhập/xuất
JSON), nhập roster HoYoLAB bằng token, và **Tìm đội hình** cho
tầng 12 (hai nửa, không trùng người/vũ khí, gán thánh di vật, cộng hưởng,
thời gian dọn ước lượng).

Điểm là sát thương mỗi giây của một vòng đánh 20 giây (hồi chiêu, năng lượng,
đòn và phản ứng trên một mục tiêu). Enka/HoYoLAB đi qua `/api/enka` và
`/api/hoyolab` (Vite proxy lúc `task web`, Pages Functions khi deploy).

## Theme & chữ

Bàn màu lá thông, thanh điều hướng vải đậm, trang đọc là một tờ giấy. Màu nguyên tố chỉ xuất hiện trên dữ liệu nhân vật và kháng quái. Token nằm trong `web/src/styles.css`.

- **Be Vietnam Pro** — UI
- **Newsreader** — tên trang và thân bài cốt truyện

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

Điều hướng nằm trong app (`web/src/router.ts`): click cùng origin đổi URL bằng History API, không tải lại trang. Home, Cốt truyện và La Hoàn (kể cả từng mục La Hoàn) giữ nguyên trong DOM và crossfade trong `.stage`, nên scroll, roster và kết quả tìm đội còn khi đổi tab.

## Deploy

Cloudflare Pages, cùng kiểu `phat.gnas.dev` / `money.gnas.dev` — không dùng
cloudflared (tunnel chỉ cho API). Subdomain: **https://teyvat.gnas.dev**.

```bash
task web:deploy
```

Cần `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_ZONE_ID`.
Script dùng chung với `.github/workflows/deploy-web.yml`: tạo project
`gn-teyvat` nếu chưa có, upload `web/dist`, gắn domain, tạo CNAME nếu thiếu.
