# Nội dung Cốt truyện

Đây là tư liệu nguồn cho trang **Cốt truyện** trên web (Ký Sự Teyvat) — bản
tổng hợp cốt truyện chính và danh mục nhiệm vụ của Genshin Impact, viết lại
bằng lời văn riêng dựa trên nghiên cứu từ Genshin Impact Wiki (fandom.com)
và HoYoWiki. Đây **không phải bản dịch hay trích dẫn nguyên văn** thoại/văn
bản trong game.

> Genshin Impact và toàn bộ nhân vật, địa danh, cốt truyện gốc thuộc bản
> quyền HoYoverse. Thư mục này chỉ diễn giải lại theo cách hiểu cá nhân, phục
> vụ mục đích tham khảo, không nhằm thay thế hay tái bản nội dung gốc.

`web/src/lib/story.ts` đọc thẳng các file ở đây. Sửa `.md` bên dưới phản ánh
trên web ở lần chạy tiếp theo — không cần đụng code trừ khi đổi cấu trúc
heading.

## Cấu trúc thư mục

```
chapters/   9 chương cốt truyện chính (00 Mondstadt → 08 bức tranh lớn)
quests/     12 file danh mục nhiệm vụ (Archon, Story, World, Event...)
story-entities.json   registry nhân vật/sự kiện dùng để tự động gắn link
```

## Quy ước viết (áp dụng khi thêm/sửa nội dung)

- Ngôn ngữ: tiếng Việt, giọng kể gọn, trung tính. Tên riêng (nhân vật, nhiệm
  vụ, địa danh) giữ nguyên tiếng Anh vì đó là định danh tra cứu.
- Mỗi file mở đầu bằng `# Tiêu đề`, có thể kèm 1 dòng in nghiêng tóm ý.
- `web/src/lib/markdown.ts` hiểu heading (`#`/`##`/`###`), đoạn văn, callout
  dạng `> **Nhãn.** nội dung`, bảng `| … | … |`, danh sách `- mục`, và cây
  hangout. Không dùng cú pháp Markdown khác (code block, ảnh, danh sách lồng
  nhau...) vì sẽ không được nhận diện đúng.
- Không chép nguyên văn thoại/mô tả trong game — luôn diễn giải lại.

## Cơ chế gắn link giữa các phần

`story-entities.json` là danh sách nhân vật/Archon/phe phái/sự kiện/khái
niệm quan trọng, mỗi mục có `displayName`, `aliases`, `summary`, và
`homeDocument`/`homeHeading` (chương + tiêu đề mục nơi hồ sơ nhân vật đó
nằm). `web/src/lib/entityLinker.ts` quét mọi đoạn văn/callout trong
`chapters/` và `quests/`, tự động biến các lần xuất hiện của
`displayName`/`aliases` (khớp biên từ, không phân biệt phần đã nằm trong
bảng) thành link `/story/e/<id>` — bấm vào sẽ mở trang tổng hợp cho thực
thể đó.

Để thêm một thực thể mới có thể bấm vào: thêm một mục vào
`story-entities.json` với `id` dạng slug (chữ thường, không dấu, nối bằng
`-`), không cần sửa code. Bảng trong `quests/*.md` (tên nhiệm vụ) **không**
được tự động gắn link — chỉ đoạn văn tường thuật mới có, để tránh biến mọi
bảng nhiệm vụ thành rừng link.

## Nguồn tham khảo

- Genshin Impact Wiki — genshin-impact.fandom.com (qua MediaWiki API)
- HoYoWiki — wiki.hoyolab.com (đối chiếu)
