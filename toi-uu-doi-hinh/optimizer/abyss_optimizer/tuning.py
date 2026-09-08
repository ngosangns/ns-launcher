"""Hằng số/giả định của thuật toán — nạp từ `tuning.json` cạnh dữ liệu.

Trước đây các số này nằm thẳng trong file Python. Từ khi bản Swift trong
`Sources/NSLauncherApp/Services/Abyss/` trở thành bản triển khai chính thức,
hai bản phải dùng **chung một bộ số**, nếu không chúng sẽ lệch nhau âm thầm
và không có gì phát hiện ra. Nên toàn bộ số chuyển sang
`Sources/NSLauncherApp/Resources/Abyss/tuning.json` (được đóng gói vào app),
còn file này chỉ còn là loader re-export đúng những tên cũ để `build.py` và
`scoring.py` không phải đổi gì.

Phần giải thích ý nghĩa từng nhóm số — JSON không có comment — nằm ở khoá
`notes` trong chính file JSON đó, và bản dài ở `Resources/Abyss/README.md`.
"""

from __future__ import annotations

import json

from .data import DATA_ROOT

with open(DATA_ROOT / "tuning.json", encoding="utf-8") as _fh:
    _T = json.load(_fh)

# (2) Hằng số game chuẩn — thánh di vật 5★ cấp 20
ARTIFACT_MAIN_STATS: dict[str, float] = _T["artifactMainStats"]
SUBSTAT_ROLL_VALUE: dict[str, float] = _T["substatRollValue"]

# (3) Giả định heuristic
SUBSTAT_ROLL_BUDGET: int = _T["substatRollBudget"]
SUBSTAT_PRIORITY: dict[str, dict[str, float]] = _T["substatPriority"]
SCALING_BASIS_SWAP: dict[str, dict[str, str]] = _T["scalingBasisSwap"]
ROTATION_SECONDS: float = _T["rotationSeconds"]
NORMAL_COMBOS_PER_ROTATION: float = _T["normalCombosPerRotation"]
OFFFIELD_UPTIME: float = _T["offFieldUptime"]
CONDITIONAL_UPTIME: float = _T["conditionalUptime"]
ASSUMED_STACKS: float = _T["assumedStacks"]
AMPLIFYING_UPTIME: float = _T["amplifyingUptime"]
NO_SUSTAIN_PENALTY: float = _T["noSustainPenalty"]
SHIELD_BREAK_BONUS: float = _T["shieldBreakBonus"]
WEAKNESS_EXPLOIT_BONUS: float = _T["weaknessExploitBonus"]

STELLAR_JUBILEE_IDS: set[str] = set(_T["stellarJubileeCharacterIds"])

# JSON giữ dạng mảng có thứ tự (mỗi phần tử có `setId`) thay vì object, để phía
# Swift đọc được thứ tự ổn định và để test "id này còn tồn tại không" viết được.
# Ở đây dựng lại đúng shape tuple cũ mà `build.py` đang dùng.
SET_EFFECT_APPROX: dict[str, tuple[str, float, str, str | None]] = {
    entry["setId"]: (entry["note"], entry["damageBonus"], entry["scope"], entry["requirement"])
    for entry in _T["setEffectApprox"]
}
