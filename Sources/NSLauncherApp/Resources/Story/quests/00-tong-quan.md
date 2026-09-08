# Tổng quan hệ thống nhiệm vụ

*Cập nhật đến Version 7.0 ("Everwinter Without Mercy", ra mắt 12/08/2026).*

Genshin Impact không có một dòng nhiệm vụ duy nhất. Thay vào đó, game chia
nội dung thành nhiều loại quest với vai trò khác nhau: một mạch chính kể
chuyện Traveler đi tìm người song sinh, các nhánh phụ đào sâu nhân vật,
và vô số nhiệm vụ vặt gắn với từng vùng đất. Tài liệu này mô tả bộ khung
đó — cách phân cấp, cách mở khoá, phần thưởng và quy mô hiện tại — làm
nền cho các file liệt kê chi tiết trong cùng thư mục.

## Cách phân cấp: Chapter → Act → Quest

Ba loại nhiệm vụ có cốt truyện dài (Archon Quest, Story Quest, và một
phần World Quest) đều dùng chung một cấu trúc ba tầng:

- **Chapter** (chương) — đơn vị lớn nhất. Với Archon Quest, mỗi chương
  ứng với một quốc gia hoặc một mạch truyện riêng. Với Story Quest, mỗi
  chương ứng với một nhân vật và được đặt tên theo chòm sao
  (constellation) của nhân vật đó, ví dụ *Alatus Chapter* của Xiao.
- **Act** (hồi) — đơn vị mở khoá. Mỗi Act có điều kiện riêng và thường là
  thứ người chơi thấy trong menu nhiệm vụ. Đây cũng là đơn vị mà game
  dùng để đánh dấu tiến độ.
- **Quest** (nhiệm vụ con) — từng bước cụ thể trong một Act, chạy nối
  tiếp nhau. Ví dụ Act I của Prologue gồm 11 quest con.

Với Hangout Event thì "Chapter" là tên nhân vật, còn với Tribal Chronicles
là tên bộ tộc.

## Bảng tóm tắt các loại nhiệm vụ

| Loại | Vai trò | Lồng tiếng | Mở khoá bằng | Đặc trưng |
|---|---|---|---|---|
| Archon Quest | Mạch truyện chính | Có | Adventure Rank + Act trước đó | Chia theo Chapter/Act, quyết định tiến độ toàn game |
| Story Quest | Chuyện riêng từng nhân vật | Có | AR + Archon Quest + quest khác | Cho dùng thử nhân vật; vài chương là điều kiện của Archon Quest và Weekly Boss |
| Hangout Event | Nhánh hội thoại nhiều kết cục | Có | 2 Story Key mỗi Act | Chơi lại được, có thanh Heartbeat, nhiều ending |
| Tribal Chronicles | Story Quest của các bộ tộc Natlan | Có | AR 40 + Archon Quest Natlan | Không tốn Story Key; gắn với Tribe Reputation |
| World Quest | Chuyện của vùng đất, NPC | Phần lớn không | Khám phá bản đồ, nói chuyện NPC, AR, Archon Quest | Số lượng lớn nhất; nhiều chuỗi (Series) chứa lore nặng |
| Event Quest | Nội dung sự kiện giới hạn thời gian | Tùy | Mốc sự kiện | Phần lớn là World Quest; sự kiện lớn có cả Story Quest |
| Commission | Nhiệm vụ ngày | Không | AR 12 + *Every Day a New Adventure* | 4 nhiệm vụ/ngày, nguồn Story Key chính |
| Reputation Request | Việc vặt tính danh vọng vùng | Không | AR 25 + quest mở Reputation của vùng | Nhận theo tuần từ NPC danh vọng |
| Random Event | Sự kiện ngẫu nhiên ngoài đồng | Không | Đi ngang qua điểm spawn | Mất nếu đi quá xa; giới hạn thưởng 10 lần/ngày |
| Ascension Quest | Cửa ải nâng World Level | Có | Mốc AR 25/35/45/50 | Bắt buộc để tăng World Level |

## Từng loại nhiệm vụ

### Archon Quest

Mạch chính. Traveler và Paimon đi qua từng quốc gia để gặp The Seven, lần
theo dấu vết người song sinh. Tất cả đều được lồng tiếng, và độ khó quái
cùng cấp nhân vật dùng thử (tối đa 90) tính theo World Level hiện tại.

Điều kiện mở khoá luôn là một mốc Adventure Rank cộng với Act liền trước.
Một số Act còn đòi hoàn thành Story Quest của nhân vật khác — ví dụ Act IV
của Chapter I cần Act I trong *Lupus Minor Chapter* của Razor. Chi tiết đầy
đủ nằm ở file `01-archon-quests.md`.

### Story Quest

Chuyện riêng của từng nhân vật chơi được. Hầu hết cho phép dùng thử nhân
vật trong suốt quest; nếu nhân vật đó đang ở trong đội thì bản trong đội
tạm thời bị thay bằng bản dùng thử.

Từ Version 5.4, Story Quest của nhân vật **không còn tốn Story Key**. Một
vài chương là điều kiện bắt buộc để đi tiếp Archon Quest, và một vài chương
khác mở khoá Weekly Boss.

Story Quest của nhân vật Natlan được trình bày dưới dạng Tribal Chronicles.
Story Quest của các nhân vật Nod-Krai ra mắt giữa Version 6.0 và 6.3 thì
được gộp thẳng vào chương Archon Quest *Song of the Welkin Moon* thay vì
tách riêng.

### Hangout Event

Còn gọi là Invitation Quest. Đây là Story Quest dạng phân nhánh: lựa chọn
hội thoại dẫn tới các kết cục khác nhau, và mỗi quest có một giá trị
Heartbeat — trả lời sai làm nó tụt, tụt hết thì quest thất bại. Các điểm
rẽ nhánh được lưu làm checkpoint để người chơi quay lại mở nốt ending
khác.

Mỗi Act tốn **2 Story Key**; chơi lại cùng Act đó không tốn thêm. Phần
thưởng phụ thuộc số ending đã mở, gồm Primogem, Adventure EXP, Hero's Wit,
nguyên liệu nâng cấp và món ăn đặc biệt của nhân vật. Hangout cũng trao
achievement thuộc nhóm *Memories of the Heart*.

### Tribal Chronicles

Còn gọi là Tribe Reputation Quest — dạng Story Quest riêng của Natlan, mỗi
chương xoay quanh một bộ tộc thay vì một nhân vật. Không tốn Story Key.
Điều kiện chung là AR 40 cộng với tiến độ Archon Quest Natlan tương ứng.

### World Quest

Loại đông đảo nhất. Có quest tự khởi động khi đạt điều kiện (thường là sau
một Archon Quest), có quest phải tự tìm ra NPC hoặc vật thể trong thế giới
mở — những NPC như vậy hiện biểu tượng World Quest khi người chơi tới gần.

**World Quest Series** là chuỗi nhiều World Quest nối tiếp, hiển thị trong
menu giống Act của Archon/Story Quest và luôn hiện trên bản đồ. Đây là nơi
chứa phần lớn lore vùng miền nặng ký ngoài mạch chính.

World Quest còn có các nhánh con:

- **Random Event** — sự kiện ngẫu nhiên ngoài đồng (xem bên dưới).
- **Reputation Request** — việc vặt lấy điểm danh vọng vùng.
- **Ascension Quest** — cửa ải nâng World Level.
- **Crimson Wish** — chuỗi riêng ở Dragonspine, mở ở cấp 8 của
  Frostbearing Tree's Gratitude và biến mất khi cây lên cấp 12.
- **Intel Quest** — dạng riêng của Nod-Krai.

World Quest thuộc sự kiện, hoặc mở khoá tính năng lớn (Serenitea Pot,
Imaginarium Theater, hệ thống Reputation), được đánh dấu bằng thẻ màu xanh
trong nhật ký nhiệm vụ.

### Commission

Nhiệm vụ ngày. Mỗi lần reset, người chơi nhận 4 commission: 0–1 cái thuộc
nhóm **NPC Commission** (có cốt truyện riêng, điều kiện riêng) và 3–4 cái
thuộc nhóm cơ bản. Commission không hoàn thành thì hết ngày là mất, không
cộng dồn.

Mở khoá ở AR 12 sau khi xong *Every Day a New Adventure*. Ban đầu chỉ có
commission Mondstadt; các vùng khác mở dần theo tiến độ Archon Quest cộng
một World Quest kèm theo (ví dụ Inazuma cần *Ritou Escape Plan* và
*Katheryne in Inazuma*; Snezhnaya cần tới bước "Go to Zapolyarny" trong
*Great Deeds on the Tundra*). Trong Adventurer Handbook có thể đặt vùng ưu
tiên, áp dụng từ lần reset kế tiếp.

Mỗi ngày chỉ nhận thưởng tối đa 4 commission, kể cả khi làm hộ người khác
qua Co-Op. Commission là nguồn Story Key duy nhất.

### Event Quest

Nhiệm vụ giới hạn thời gian trong các Event. Phần lớn là World Quest,
nhưng các Flagship Event lớn thường có cả Story Quest riêng. Từ Version
3.2, Story Quest thuộc sự kiện không còn bắt buộc phải xong Story Quest
nhân vật trước — game chỉ khuyến nghị để tránh spoil. Một số chương sự
kiện được giữ lại vĩnh viễn và truy cập được từ menu nhiệm vụ.

### Random Event

Gặp ngẫu nhiên khi đi lang thang. Đi quá xa hoặc không tương tác kịp thì
sự kiện biến mất. Có thể ép spawn bằng cách thoát game gần điểm khởi phát
rồi vào lại. Sau 50 sự kiện trong một chu kỳ reset thì không spawn nữa,
và phần thưởng chỉ tính cho 10 lần đầu mỗi ngày (Companionship EXP, Mora,
quặng cường hóa). Random Event **không xuất hiện** ở Fontaine, Natlan và
Nod-Krai.

### Reputation Request

Việc vặt gắn với hệ thống Reputation từng quốc gia. Muốn mở Reputation cần
AR 25 cộng với một Archon Quest và một World Quest của vùng đó — ví dụ
Mondstadt cần *The Outlander Who Caught the Wind* và *Knight of the Realm*;
Fontaine cần *As Light Rain Falls Without Reason* và *Steambird Interview*.
Natlan không dùng World Quest mở đầu mà chuyển sang hệ Tribe Reputation.
Phần thưởng Reputation gồm công thức nấu ăn, bản vẽ rèn/chế tạo, namecard
và wind glider.

### Ascension Quest

Năm nhiệm vụ cửa ải: *Adventure Rank Ascension 1–4* (ở AR 25, 35, 45, 50)
và *World Level Ascension* (lên World Level 9). Nếu không làm, Adventure
EXP vẫn tích lũy nhưng Adventure Rank đứng yên cho tới khi hoàn thành.

## Story Key và điều kiện mở khoá

**Story Key** là vật phẩm mở khoá quest, nhận được từ AR 26 trở lên: cứ 8
commission hoàn thành (tức 2 ngày x 4 commission) thì được nhận 1 chìa.
Chìa không tự vào túi — phải bấm nhận trong màn hình Story Quest. Giữ tối
đa 3 chìa cùng lúc, nhưng bộ đếm vẫn chạy tới 8 nên tiêu 1 chìa là có thể
nhận ngay chìa mới.

Hiện chỉ **Hangout Event** còn tốn Story Key (2 chìa mỗi Act). Story Quest
nhân vật đã bỏ yêu cầu này từ Version 5.4, và Tribal Chronicles chưa bao
giờ cần.

Các điều kiện mở khoá còn lại thường là tổ hợp của: mốc Adventure Rank,
hoàn thành Act trước trong cùng chương, hoàn thành một Act Archon Quest cụ
thể, hoặc hoàn thành Story Quest của nhân vật khác.

Một cơ chế phụ đáng lưu ý: nếu một NPC hoặc một địa điểm đang bị "chiếm"
bởi nhiệm vụ khác, người chơi không thể bắt đầu nhiệm vụ mới cần đúng NPC
hay địa điểm đó. Menu nhiệm vụ sẽ chỉ ra cần dọn quest nào trước.

## Phần thưởng đặc trưng

| Loại | Phần thưởng chính |
|---|---|
| Archon Quest | Primogem, Adventure EXP, Mora, Hero's Wit, sách talent, quặng cường hóa; Reputation của vùng |
| Story Quest | Primogem, Adventure EXP, nguyên liệu nâng cấp; mở khoá Weekly Boss (một số chương) |
| Hangout Event | Primogem, Adventure EXP, Hero's Wit, nguyên liệu talent/ascension, món ăn đặc biệt của nhân vật, achievement *Memories of the Heart* |
| Tribal Chronicles | Tribe Reputation của Natlan, kèm thưởng Story Quest thông thường |
| World Quest | Primogem, Mora, Adventure EXP, nguyên liệu; nhiều quest mở khoá tính năng hoặc khu vực |
| Commission | Primogem, Adventure EXP, Mora, Companionship EXP, quặng cường hóa; tích lũy thành Story Key |
| Reputation Request | Điểm Reputation, dẫn tới công thức, bản vẽ, namecard, wind glider |
| Random Event | Companionship EXP, Mora, quặng cường hóa (tối đa 10 lần/ngày) |
| Ascension Quest | Nâng World Level, mở nội dung cấp cao |

## Số liệu tổng quát (đến Version 7.0)

Số liệu dưới đây đếm theo số trang trong các danh mục tương ứng của wiki,
nên là con số xấp xỉ cho quy mô, không phải số liệu chính thức từ game.

| Hạng mục | Số lượng |
|---|---|
| Tổng số trang nhiệm vụ (mọi loại) | ~2.547 |
| Archon Quest — chương | 11 (Prologue, I–V, *Song of the Welkin Moon*, VII, Chapter ??, Epilogue, Interlude Chapter) |
| Archon Quest — Act | 48 |
| Archon Quest — nhiệm vụ con | 224 |
| Story Quest — chương nhân vật | 53 |
| Hangout Event — chương | 18 |
| Tribal Chronicles — chương | 6 |
| Story Quest — tổng số nhiệm vụ | ~570 |
| World Quest — tổng số nhiệm vụ | ~1.376 |
| World Quest Series | 73 |
| Commission | 248 (trong đó 186 NPC Commission) |
| Event Quest | ~639 |
| Reputation Request | 57 |
| Random Event | 22 (+16 Random World Quest lặp lại được) |
| Crimson Wish (Dragonspine) | 5 |
| Intel Quest (Nod-Krai) | 8 |
| Ascension Quest | 5 |

Hai chương Archon Quest đã có tên nhưng chưa mở: **Chapter ??: The Dream
Yet to Be Dreamed** (Khaenri'ah, gắn với Dainsleif) và **Epilogue** — wiki
chưa ghi rõ nội dung Act của cả hai. Ngoài ra, trang tổng hợp Chapter trên
wiki vẫn đánh Snezhnaya là "Chapter VI", trong khi trang Archon Quest và
danh mục chương đều dùng "Chapter VII"; tài liệu này theo cách đánh số
thứ hai.

## Nguồn

- Genshin Impact Wiki (Fandom): Quest, Quest/Menu
- Archon Quest, Story Quest, World Quest, Event Quest, Commission
- Hangout Event, Tribal Chronicles, Story Key, Random Event, Reputation
- Chapter, Adventure Rank, Version, Version/7.0
- Category:Quests, Category:Archon Quests, Category:Archon Quest Acts,
  Category:Archon Quest Chapters, Category:Story Quests,
  Category:Story Quest Chapters, Category:Hangout Event Chapters,
  Category:World Quests, Category:World Quest Series,
  Category:Commissions, Category:NPC Commissions, Category:Event Quests,
  Category:Reputation Requests, Category:Random Events,
  Category:Random World Quests, Category:Crimson Wish Quests,
  Category:Intel Quests, Category:Ascension Quests
