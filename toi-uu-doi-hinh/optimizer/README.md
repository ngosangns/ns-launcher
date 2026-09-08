# Thuật toán gợi ý đội hình Trầm Thủy

Script Python độc lập (chỉ dùng thư viện chuẩn, **không cần cài gì thêm**) đọc
[`../data-model/`](../data-model/README.md) và xếp hạng các đội hình 4 người
cho từng tầng Trầm Thủy của mùa hiện tại, lọc theo **những gì bạn thực sự sở
hữu**.

## Chạy nhanh

```bash
cd toi-uu-doi-hinh/optimizer
cp roster.example.json roster.json      # rồi sửa theo tài khoản của bạn
python3 optimize_abyss.py
```

Các tuỳ chọn hay dùng:

```bash
python3 optimize_abyss.py --floor 12 --top 10   # chỉ tầng 12, xem 10 đội đầu
python3 optimize_abyss.py --full-roster         # bỏ qua roster, so sánh lý thuyết
python3 optimize_abyss.py --self-test           # kiểm chứng công thức sát thương
python3 optimize_abyss.py --pool-size 60        # xét nhiều nhân vật hơn (chậm hơn)
```

## File roster

Copy `roster.example.json` → `roster.json` rồi điền id nhân vật/vũ khí bạn có.
Id phải khớp id trong `../data-model/data/`; **script sẽ cảnh báo từng id sai**
nên cứ chạy thử để dò.

```json
{
  "characters": [{ "id": "hu-tao", "constellation": 0 }],
  "weapons": [{ "id": "staff-of-homa", "refinement": 1 }],
  "artifactSets": []
}
```

- `artifactSets` để rỗng = coi như có đủ mọi bộ (thường đúng, vì bộ nào cũng
  farm được — khác vũ khí).
- Mỗi vũ khí được coi là **chỉ có 1 bản**: nếu 2 nhân vật trong cùng đội cùng
  muốn 1 cây, người có điểm cao hơn được ưu tiên, người kia lùi xuống cây tốt
  nhất còn lại. Nếu roster quá ít vũ khí, báo cáo sẽ ghi rõ dòng
  `! roster không đủ vũ khí: ...`.

## Thuật toán làm gì

1. **Dựng build** cho từng nhân vật: chỉ số cấp 90 + vũ khí cấp 90 + thánh di
   vật 5★ cấp 20 (main stat theo vai trò, substat theo ngân sách roll giả
   định trong `abyss_optimizer/tuning.py`).
2. **Chọn trang bị** cho mỗi nhân vật: xếp hạng vũ khí, rồi tìm bộ thánh di
   vật (4 món hoặc 2+2) cho điểm cao nhất; giữ lại 6 phương án để còn đường
   lùi khi tranh vũ khí trong đội.
3. **Đọc bối cảnh tầng** từ `data-model/data/abyss-monsters/`: cấp quái, kháng
   nguyên tố, khiên nguyên tố, Ley Line Disorder và Uyên Nguyệt Chúc Phúc.
4. **Tính sát thương 1 rotation** cho từng nhân vật theo đúng công thức trong
   `data-model/data/damage-formula.json` (DEF/RES/CRIT/phản ứng khuếch đại).
5. **Cộng buff cấp đội**: Cộng Hưởng Nguyên Tố, Nguyệt Triệu, Hexerei
   (`data-model/data/team-bonus.json`), buff cả đội từ vũ khí/thánh di vật.
6. **Thử cả 4 người ở vị trí on-field**, lấy phương án tốt nhất; cộng thưởng/
   phạt cấu trúc đội (thiếu heal/khiên, phá được khiên nguyên tố, khai thác
   điểm yếu) rồi xếp hạng.

Công thức lõi được kiểm chứng bằng `--self-test`: chạy lại đúng ví dụ mẫu
Mona/Sucrose/Klee của wiki và so với kết quả 52.246,50 ghi trong data model.

## Giới hạn (đọc trước khi tin kết quả)

Đây là **mô hình xếp hạng heuristic**, không phải trình mô phỏng chính xác
từng frame như KQM. Cụ thể:

- **Chưa mô phỏng rotation thật**: không có năng lượng/hồi chiêu/thứ tự thao
  tác, chỉ giả định 1 vòng 20s với các hệ số uptime cố định trong `tuning.py`.
- **Chưa tính cung mệnh**: trường `constellation` trong roster hiện chỉ để ghi
  chú, chưa ảnh hưởng tới điểm.
- **Chưa mô phỏng Internal Cooldown của phản ứng**: hệ số Vaporize/Melt được
  nhân theo tỉ lệ uptime giả định (`AMPLIFYING_UPTIME`), không theo thứ tự áp
  nguyên tố thật.
- **Hiệu ứng 4 món phức tạp là số ước lượng thủ công**: 36/63 bộ trong data
  model không tách được số một cách máy móc, nên `tuning.SET_EFFECT_APPROX`
  gán tay một mức "%DMG hiệu dụng". Đây là phần chủ quan nhất — chỉnh nó là
  cách nhanh nhất để đổi kết quả theo hiểu biết của bạn.
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
| Nhân vật/vũ khí/thánh di vật/quái/buff | `../data-model/data/` | fetch từ Yatta API + Fandom, đã validate JSON Schema |
| Công thức sát thương | `../data-model/data/damage-formula.json` | nguyên văn wiki, có self-test |
| Main stat / giá trị roll thánh di vật | `abyss_optimizer/tuning.py` | hằng số chuẩn cộng đồng, **chưa đối chiếu API trong repo này** |
| Rotation, uptime, quy đổi 4 món | `abyss_optimizer/tuning.py` | ước lượng heuristic, chỉnh tay được |

## Cấu trúc mã

```
optimizer/
├── optimize_abyss.py          # CLI: roster, chọn trang bị, in báo cáo
├── roster.example.json        # mẫu roster
└── abyss_optimizer/
    ├── data.py                # đọc data model + parse chuỗi text thành số
    ├── build.py               # dựng chỉ số (nhân vật + vũ khí + thánh di vật)
    ├── scoring.py             # công thức sát thương + chấm điểm đội
    └── tuning.py              # TẤT CẢ hằng số/giả định chỉnh tay
```

Yêu cầu: Python 3.10+.
