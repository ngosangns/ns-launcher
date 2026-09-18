# Nội dung tab "Cốt truyện"

Đây là tư liệu nguồn cho tab **Cốt truyện** trong NS Launcher — bản tổng hợp
cốt truyện chính và danh mục nhiệm vụ của Genshin Impact, viết lại bằng lời
văn riêng dựa trên nghiên cứu từ Genshin Impact Wiki (fandom.com) và HoYoWiki.
Đây **không phải bản dịch hay trích dẫn nguyên văn** thoại/văn bản trong game.

> Genshin Impact và toàn bộ nhân vật, địa danh, cốt truyện gốc thuộc bản
> quyền HoYoverse. Thư mục này chỉ diễn giải lại theo cách hiểu cá nhân, phục
> vụ mục đích tham khảo trong ứng dụng, không nhằm thay thế hay tái bản nội
> dung gốc. Ghi chú này cũng hiển thị trực tiếp trong tab Cốt truyện của app.

Nội dung ở đây được `StoryLibrary` (xem `Services/Story/`) nạp lúc chạy qua
`Bundle.module` và hiển thị trong `Views/Story/`. Sửa nội dung ở các file
`.md` bên dưới sẽ tự động phản ánh trong app ở lần build/chạy tiếp theo —
không cần đụng tới code Swift trừ khi thay đổi cấu trúc heading.

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
- `StoryMarkdownParser` (xem `Services/Story/StoryMarkdownParser.swift`) chỉ
  hiểu 5 dạng khối: heading (`#`/`##`/`###`), đoạn văn, callout dạng
  `> **Nhãn.** nội dung`, bảng `| … | … |`, và danh sách `- mục`. Không dùng
  cú pháp Markdown khác (code block, ảnh, danh sách lồng nhau...) vì sẽ không
  được nhận diện đúng.
- Không chép nguyên văn thoại/mô tả trong game — luôn diễn giải lại.

## Cơ chế gắn link giữa các phần

`story-entities.json` là danh sách nhân vật/Archon/phe phái/sự kiện/khái
niệm quan trọng, mỗi mục có `displayName`, `aliases`, `summary`, và
`homeDocument`/`homeHeading` (chương + tiêu đề mục nơi hồ sơ nhân vật đó
nằm). `StoryEntityLinker` quét mọi đoạn văn/callout trong `chapters/` và
`quests/`, tự động biến các lần xuất hiện của `displayName`/`aliases` (khớp
biên từ, không phân biệt phần đã nằm trong bảng) thành link nội bộ
`story://entity/<id>` — bấm vào sẽ mở trang tổng hợp cho thực thể đó.

Để thêm một thực thể mới có thể bấm vào: thêm một mục vào
`story-entities.json` với `id` dạng slug (chữ thường, không dấu, nối bằng
`-`), không cần sửa code. Bảng trong `quests/*.md` (tên nhiệm vụ) **không**
được tự động gắn link — chỉ đoạn văn tường thuật mới có, để tránh biến mọi
bảng nhiệm vụ thành rừng link.

## Nguồn tham khảo

- Genshin Impact Wiki — genshin-impact.fandom.com (qua MediaWiki API)
- HoYoWiki — wiki.hoyolab.com (đối chiếu)
