"""Toàn bộ hằng số/giả định có thể chỉnh tay của thuật toán.

Tách riêng file này để phân biệt rõ 3 loại số:

1. **Dữ liệu game đã fetch** — nằm ở `../data-model/data/`, KHÔNG có ở đây.
2. **Hằng số game chuẩn** (giá trị roll thánh di vật, main stat cấp 20...) —
   ổn định qua các bản, nhưng **chưa được đối chiếu API trong repo này**
   (xem README mục "Nguồn số liệu"), nên để ở đây để dễ sửa/kiểm chứng.
3. **Giả định heuristic của thuật toán** (thời lượng rotation, uptime buff
   điều kiện, hệ số quy đổi hiệu ứng 4 món phức tạp) — hoàn toàn là ước
   lượng, chỉnh ở đây để thử kịch bản khác.
"""

# --------------------------------------------------------------------------
# (2) Hằng số game chuẩn — thánh di vật 5★ cấp 20
# --------------------------------------------------------------------------

# Main stat của từng vị trí ở 5★ cấp 20.
ARTIFACT_MAIN_STATS = {
    "flat_hp": 4780.0,        # Flower of Life (cố định)
    "flat_atk": 311.0,        # Plume of Death (cố định)
    "atk_pct": 0.466,
    "hp_pct": 0.466,
    "def_pct": 0.583,
    "em": 187.0,
    "er": 0.518,
    "elemental_dmg": 0.466,   # Goblet nguyên tố
    "physical_dmg": 0.583,    # Goblet vật lý
    "crit_rate": 0.311,
    "crit_dmg": 0.622,
    "healing_bonus": 0.359,
}

# Giá trị trung bình 1 lần roll substat ở 5★ (mốc roll cao nhất trong 4 mốc).
# Dùng để quy đổi "ngân sách roll" thành chỉ số thật.
SUBSTAT_ROLL_VALUE = {
    "crit_rate": 0.0389,
    "crit_dmg": 0.0777,
    "atk_pct": 0.0583,
    "hp_pct": 0.0583,
    "def_pct": 0.0729,
    "em": 23.31,
    "er": 0.0648,
    "flat_atk": 19.45,
    "flat_hp": 298.75,
    "flat_def": 23.15,
}

# --------------------------------------------------------------------------
# (3) Giả định heuristic
# --------------------------------------------------------------------------

# Tổng số roll substat giả định cho cả 5 món (5 món × 4 dòng × ~1.25 roll
# thêm). 25 roll ≈ tài khoản nuôi tốt nhưng không phải "artifact thần".
SUBSTAT_ROLL_BUDGET = 25

# Phân bổ ngân sách roll theo vai trò (tổng mỗi dict = 1.0).
SUBSTAT_PRIORITY = {
    "main-dps": {"crit_rate": 0.30, "crit_dmg": 0.34, "atk_pct": 0.24, "er": 0.12},
    "sub-dps": {"crit_rate": 0.28, "crit_dmg": 0.32, "atk_pct": 0.22, "er": 0.18},
    "support": {"er": 0.34, "em": 0.24, "crit_rate": 0.16, "crit_dmg": 0.16, "atk_pct": 0.10},
    "healer": {"er": 0.34, "hp_pct": 0.36, "em": 0.16, "crit_rate": 0.14},
    "shield": {"er": 0.30, "hp_pct": 0.24, "def_pct": 0.30, "em": 0.16},
}

# Với nhân vật scale DEF/HP thì đổi trục ATK% sang DEF%/HP% tương ứng.
SCALING_BASIS_SWAP = {
    "DEF": {"atk_pct": "def_pct"},
    "HP": {"atk_pct": "hp_pct"},
    "EM": {"atk_pct": "em"},
}

# Độ dài 1 vòng rotation giả định (giây) để quy damage về cùng mẫu số.
ROTATION_SECONDS = 20.0

# Số combo đòn thường mà nhân vật on-field thực hiện trong 1 rotation.
NORMAL_COMBOS_PER_ROTATION = 6.0

# Nhân vật off-field chỉ dùng Kỹ năng + Bùng nổ; hệ số này phản ánh việc
# không phải lúc nào skill cũng sẵn sàng đúng nhịp rotation.
OFFFIELD_UPTIME = 0.85

# Buff/hiệu ứng có điều kiện (ghi trong ngoặc ở tên stat) hiếm khi đạt 100%
# uptime — nhân hệ số này khi quy đổi.
CONDITIONAL_UPTIME = 0.6

# Số lớp (stack) trung bình giả định cho hiệu ứng vũ khí ghi "per stack".
# Đa số passive cho tối đa 4-5 lớp nhưng ít khi giữ đầy suốt rotation.
ASSUMED_STACKS = 2.5

# Tỉ lệ đòn đánh thực sự kích hoạt được phản ứng khuếch đại trong rotation.
# Phản ứng bị giới hạn bởi Internal Cooldown và thứ tự áp nguyên tố nên
# không phải đòn nào cũng ăn hệ số Vaporize/Melt.
AMPLIFYING_UPTIME = 0.55

# Điểm thưởng/phạt cấu trúc đội (nhân vào tổng damage của đội).
NO_SUSTAIN_PENALTY = 0.80      # không có heal lẫn khiên
SHIELD_BREAK_BONUS = 1.10      # có đúng nguyên tố phá khiên quái trong tầng
WEAKNESS_EXPLOIT_BONUS = 1.08  # có nguyên tố mà quái bị âm kháng

# --------------------------------------------------------------------------
# (3) Quy đổi hiệu ứng 4 món phức tạp -> % DMG hiệu dụng
# --------------------------------------------------------------------------
# 36/63 bộ có `fourPiece.bonuses` rỗng trong data model vì hiệu ứng quá phức
# tạp để tách số một cách máy móc (stack, điều kiện, scale theo chỉ số khác).
# Nếu bỏ trống, thuật toán sẽ đánh giá thấp một cách hệ thống các bộ meta.
# Bảng dưới là **ước lượng thủ công** phần % sát thương hiệu dụng trung bình
# trong 1 rotation Trầm Thủy, KHÔNG phải số liệu game. Sửa tự do.
# Bộ không có trong bảng: chỉ dùng `bonuses` đã tách được trong data model.
#
# Trường thứ 4 = điều kiện nhân vật mới dùng được bộ đó (None = ai cũng dùng
# được).  "natlan" = nhân vật Natlan (cần Nightsoul's Blessing);
# "moonsign" = nhân vật Nguyệt Triệu; "stellar" = nguyên tố tham gia phản ứng
# Stellar Glimmer (Cryo/Electro/Anemo).
SET_EFFECT_APPROX = {
    # id bộ: (mô tả ngắn, %DMG hiệu dụng cộng thêm, phạm vi áp dụng, điều kiện)
    "emblem-of-severed-fate": ("+ST Nộ theo Nạp Nguyên Tố (~25-30% ER→DMG)", 0.30, "burst", None),
    "crimson-witch-of-flames": ("Bốc cháy/Bốc hơi/Tan chảy +15%, Pyro +7.5%×3 stack", 0.28, "all", None),
    "gilded-dreams": ("EM +80 + ATK theo đồng đội cùng/khác hệ", 0.18, "all", None),
    "deepwood-memories": ("giảm 30% kháng Dendro địch (buff cả đội)", 0.20, "all", None),
    "shimenawas-reminiscence": ("đổi 15 Nộ lấy +50% ST đòn thường/trọng kích", 0.35, "normal", None),
    "echoes-of-an-offering": ("đòn thường có xác suất +70% ATK", 0.22, "normal", None),
    "marechaussee-hunter": ("CRIT Rate +36% khi HP đổi", 0.25, "normal", None),
    "nymphs-dream": ("stack Hydro: ATK% + Hydro DMG", 0.26, "all", None),
    "vourukashas-glow": ("HP +20%, Kỹ năng/Nộ +40% khi bị đánh", 0.20, "all", None),
    "golden-troupe": ("Kỹ năng +20%, off-field +25% nữa", 0.32, "skill", None),
    "song-of-days-past": ("hồi máu tích luỹ -> tăng ST cả đội", 0.18, "all", None),
    "nighttime-whispers-in-the-echoing-woods": ("ATK +20%, Geo DMG +20% sau Kỹ năng", 0.22, "all", None),
    "fragment-of-harmonic-whimsy": ("Bond of Life đổi -> +18% ST ×3", 0.28, "all", None),
    "unfinished-reverie": ("+50% ST khi địch bị Bốc cháy", 0.24, "all", None),
    "obsidian-codex": ("Nightsoul: +40% ST, +40% CRIT DMG", 0.35, "all", "natlan"),
    "scroll-of-the-hero-of-cinder-city": ("buff cả đội theo nguyên tố Nightsoul", 0.24, "all", "natlan"),
    "long-nights-oath": ("trọng kích/nhảy stack tới +100%", 0.26, "charged", None),
    "finale-of-the-deep-galleries": ("đòn thường/Nộ +60% khi hết Nộ", 0.20, "all", None),
    "noblesse-oblige": ("Nộ +20%, cả đội ATK +20%", 0.20, "burst", None),
    "viridescent-venerer": ("Swirl +60%, giảm 40% kháng nguyên tố bị cuốn", 0.25, "all", None),
    "blizzard-strayer": ("CRIT Rate +40% khi địch đóng băng", 0.30, "all", None),
    "thundering-fury": ("+40% ST phản ứng Electro, giảm CD Kỹ năng", 0.24, "all", None),
    "heart-of-depth": ("đòn thường/trọng kích +30% sau Kỹ năng", 0.22, "normal", None),
    "lavawalker": ("+35% ST lên địch dính Pyro", 0.20, "all", None),
    "pale-flame": ("ATK +18%×2 stack, Physical +25%", 0.24, "all", None),
    "husk-of-opulent-dreams": ("DEF/Geo DMG +24% (4 stack)", 0.22, "all", None),
    "ocean-hued-clam": ("nổ bong bóng theo lượng hồi máu", 0.12, "all", None),
    "scarlet-proof": ("CRIT Rate +16%, Stellar Swirl +40%", 0.30, "all", "stellar"),
    "heart-of-the-furnace": ("ATK +12%, cả đội +50% ST Stellar Glimmer", 0.28, "all", "stellar"),
    "night-of-the-skys-unveiling": ("buff Lunar Reaction cả đội", 0.24, "all", "moonsign"),
    "silken-moons-serenade": ("buff Lunar Reaction/Moonsign", 0.24, "all", "moonsign"),
}
