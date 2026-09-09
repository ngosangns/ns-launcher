# Thuật toán gợi ý đội hình Trầm Thủy

Script Python độc lập (chỉ dùng thư viện chuẩn, **không cần cài gì thêm**) đọc
[dữ liệu Trầm Thủy](../../Sources/NSLauncherApp/Resources/Abyss/README.md) và xếp
hạng các đội hình 4 người cho từng tầng Trầm Thủy của mùa hiện tại, lọc theo
**những gì bạn thực sự sở hữu**.

> **Bản Swift trong app mới là bản chính thức.** Tab Trầm Thủy của NS Launcher
> chạy engine viết bằng Swift (`Sources/NSLauncherApp/Services/Abyss/`) trên
> cùng bộ dữ liệu và cùng `tuning.json`. Script này giữ lại làm sân thử tham
> số và bộ sinh fixture đối chiếu cho test phía Swift.
>
> Hai bản **không còn ngang tính năng**: bản Swift có thêm một lượt chọn lại
> thánh di vật cho từng đội theo đúng tầng và đúng đồng đội
> (`AbyssArtifactAdvisor`), thứ script này không có. Vì vậy fixture đối chiếu
> được sinh và so với lượt đó **tắt** — phần chung của hai bản vẫn phải khớp
> từng con số.

## Chạy nhanh

```bash
cd toi-uu-doi-hinh/optimizer
cp roster.example.json roster.json      # rồi sửa theo tài khoản của bạn
python3 optimize_abyss.py
```

Các tuỳ chọn hay dùng:

```bash
python3 optimize_abyss.py --top 10              # tầng 12 (mặc định), xem 10 đội đầu
python3 optimize_abyss.py --floor 11 --floor 12 # tính thêm tầng khác
python3 optimize_abyss.py --full-roster         # bỏ qua roster, so sánh lý thuyết
python3 optimize_abyss.py --self-test           # kiểm chứng công thức sát thương
python3 optimize_abyss.py --pool-size 60        # xét nhiều nhân vật hơn (chậm hơn)
```

## File roster

Copy `roster.example.json` → `roster.json` rồi điền id nhân vật/vũ khí bạn có.
Id phải khớp id trong `../../Sources/NSLauncherApp/Resources/Abyss/`; **script sẽ cảnh báo từng id sai**
nên cứ chạy thử để dò.

```json
{
  "characters": [{ "id": "hu-tao", "constellation": 0 }],
  "weapons": [{ "id": "staff-of-homa", "refinement": 1 }]
}
```

- **Không khai thánh di vật.** Bộ nào cũng farm được (khác vũ khí), nên "đang
  có bộ nào" không phải ràng buộc của bài toán — công cụ luôn xét đủ 46 bộ 5★
  và trả lời "bộ tốt nhất tồn tại". Khoá `artifactSets` trong file cũ được bỏ
  qua.
- Mỗi vũ khí được coi là **chỉ có 1 bản**: nếu 2 nhân vật trong cùng đội cùng
  muốn 1 cây, người có điểm cao hơn được ưu tiên, người kia lùi xuống cây tốt
  nhất còn lại. Nếu roster quá ít vũ khí, báo cáo sẽ ghi rõ dòng
  `! roster không đủ vũ khí: ...`.

## Thuật toán làm gì

1. **Dựng build** cho từng nhân vật: chỉ số cấp 90 + vũ khí cấp 90 + thánh di
   vật 5★ cấp 20 (main stat theo vai trò, substat theo ngân sách roll giả
   định trong `Resources/Abyss/tuning.json`).
2. **Chọn trang bị** cho mỗi nhân vật: xếp hạng vũ khí, rồi duyệt **toàn bộ**
   cấu hình thánh di vật (mỗi bộ mặc 4 món, và mọi cặp bộ mặc 2+2 — 1081 cấu
   hình) lấy điểm cao nhất; giữ lại 6 phương án vũ khí để còn đường lùi khi
   tranh vũ khí trong đội.
3. **Đọc bối cảnh tầng 12** (mặc định chỉ tính tầng sâu nhất — đội qua được
   tầng 12 thì qua luôn các tầng dưới) từ `Sources/NSLauncherApp/Resources/Abyss/abyss-monsters/`: cấp quái, kháng
   nguyên tố, khiên nguyên tố, Ley Line Disorder và Uyên Nguyệt Chúc Phúc.
4. **Tính sát thương 1 rotation** cho từng nhân vật theo đúng công thức trong
   `Sources/NSLauncherApp/Resources/Abyss/damage-formula.json` (DEF/RES/CRIT/phản ứng khuếch đại).
4b. **Cộng sát thương phản ứng transformative** (Hyperbloom, Overloaded,
   Superconduct, Bloom, Burgeon, Burning, Electro-Charged, Swirl): tính một lần
   cho cả đội, chỉ lấy phản ứng MẠNH NHẤT đội mở ra, và chỉ phụ thuộc EM của
   người kích hoạt — không liên quan ATK/DMG Bonus/CRIT/DEF địch. Tần suất lấy
   từ `tuning.json` (`transformativeReactionsPerRotation`), là giả định chủ quan
   nhất của mô hình. Aggravate/Spread và nhóm Lunar/Stellar CHƯA được tính.
5. **Cộng buff cấp đội**: Cộng Hưởng Nguyên Tố, Nguyệt Triệu, Hexerei
   (`Sources/NSLauncherApp/Resources/Abyss/team-bonus.json`), buff cả đội từ vũ khí/thánh di vật.
6. **Thử cả 4 người ở vị trí on-field**, lấy phương án tốt nhất; cộng thưởng/
   phạt cấu trúc đội (thiếu heal/khiên, phá được khiên nguyên tố, khai thác
   điểm yếu) rồi xếp hạng.

Công thức lõi được kiểm chứng bằng `--self-test`: chạy lại đúng ví dụ mẫu
Mona/Sucrose/Klee của wiki và so với kết quả 52.246,50 ghi trong data model.

## Giới hạn (đọc trước khi tin kết quả)

Đây là **mô hình xếp hạng heuristic**, không phải trình mô phỏng chính xác
từng frame như KQM. Cụ thể:

- **Chưa mô phỏng rotation thật**: không có năng lượng/hồi chiêu/thứ tự thao
  tác, chỉ giả định 1 vòng 20s với các hệ số uptime cố định trong `tuning.json`.
- **Chưa tính cung mệnh**: trường `constellation` trong roster hiện chỉ để ghi
  chú, chưa ảnh hưởng tới điểm.
- **Chưa mô phỏng Internal Cooldown của phản ứng**: hệ số Vaporize/Melt được
  nhân theo tỉ lệ uptime giả định (`AMPLIFYING_UPTIME`), không theo thứ tự áp
  nguyên tố thật.
- **Hiệu ứng 4 món phức tạp là số ước lượng thủ công**: 36/63 bộ trong data
  model không tách được số một cách máy móc, nên `setEffectApprox` trong
  `tuning.json` gán tay một mức "%DMG hiệu dụng". Đây là phần chủ quan nhất —
  chỉnh nó là cách nhanh nhất để đổi kết quả theo hiểu biết của bạn, và sửa
  một lần là đổi cả bản Swift lẫn bản Python.
- **Chỉ số thánh di vật là giả định chuẩn hoá**, không phải đồ thật trên tài
  khoản bạn; mọi nhân vật đều được giả định nuôi ngang nhau.
- **Chỉ đọc được phần dữ liệu đã số hoá**: mỗi lần chạy, script in ra số mốc
  sát thương dùng được / bị bỏ và các hiệu ứng chưa quy đổi được, để bạn biết
  phần nào của dữ liệu chưa vào công thức.

Nói ngắn gọn: dùng để **thu hẹp danh sách** và thấy vì sao một đội hợp tầng
nào, không dùng để chốt con số DPS tuyệt đối.

## Nguồn số liệu

| Loại | Ở đâu | Độ tin cậy |
|---|---|---|
| Nhân vật/vũ khí/thánh di vật/quái/buff | `../../Sources/NSLauncherApp/Resources/Abyss/` | fetch từ Yatta API + Fandom, đã validate JSON Schema |
| Công thức sát thương | `../../Sources/NSLauncherApp/Resources/Abyss/damage-formula.json` | nguyên văn wiki, có self-test |
| Main stat / giá trị roll thánh di vật | `Resources/Abyss/tuning.json` | hằng số chuẩn cộng đồng, **chưa đối chiếu API trong repo này** |
| Rotation, uptime, quy đổi 4 món | `Resources/Abyss/tuning.json` | ước lượng heuristic, chỉnh tay được |

## Cấu trúc mã

```
optimizer/
├── optimize_abyss.py          # CLI: roster, chọn trang bị, in báo cáo
├── roster.example.json        # mẫu roster
└── abyss_optimizer/
    ├── data.py                # đọc data model + parse chuỗi text thành số
    ├── build.py               # dựng chỉ số (nhân vật + vũ khí + thánh di vật)
    ├── scoring.py             # công thức sát thương + chấm điểm đội
    └── tuning.py              # loader đọc Resources/Abyss/tuning.json
```

Toàn bộ hằng số/giả định chỉnh tay nằm ở
[`Resources/Abyss/tuning.json`](../../Sources/NSLauncherApp/Resources/Abyss/tuning.json)
— dùng chung với bản Swift.

Yêu cầu: Python 3.10+.
