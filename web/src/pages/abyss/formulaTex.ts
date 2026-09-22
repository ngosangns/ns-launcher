/** Display TeX for damage-formula.json. The JSON stays the calculation source. */

export const formulaTex = {
  res: "\\%\\mathrm{RES} = \\%\\mathrm{RES}_{\\text{gốc quái}} + \\%\\mathrm{RES}_{\\text{Bonus}} - \\%\\mathrm{RES}_{\\text{Debuff}}",
  resCases: [
    { condition: "\\mathrm{RES} < 0", formula: "1 - \\dfrac{\\mathrm{RES}}{2}" },
    { condition: "0 \\le \\mathrm{RES} < 0.75", formula: "1 - \\mathrm{RES}" },
    { condition: "\\mathrm{RES} \\ge 0.75", formula: "\\dfrac{1}{4\\,\\mathrm{RES} + 1}" },
  ],
  def: "\\text{DEF Multiplier} = \\dfrac{\\text{Cấp nhân vật} + 100}{k\\,(\\text{Cấp quái} + 100) + (\\text{Cấp nhân vật} + 100)}",
  defK: "k = \\bigl(1 - \\%\\text{DEF Reduction}\\bigr)\\bigl(1 - \\%\\text{DEF Ignore}\\bigr)",
  elevation: "1 + \\%\\text{Elevation}",
  crit: "1 + \\%\\text{CRIT DMG}",
  critExpected: "1 + \\text{CRIT Rate} \\times \\text{CRIT DMG}",
  amplifying: "\\text{Amplifying Multiplier} = \\text{Hệ số gốc}\\,(1 + \\%\\text{EM Bonus} + \\%\\text{Reaction Bonus})",
  amplifyingDmg: "\\text{DMG sau phản ứng} = \\text{DMG gốc} \\times \\text{Amplifying Multiplier}",
  amplifyingEm: "\\dfrac{2.78 \\cdot \\mathrm{EM}}{\\mathrm{EM} + 1400}",
  catalyze: "\\text{Additive Base DMG} = \\text{Hệ số gốc} \\times \\text{Level Multiplier} \\times (1 + \\%\\text{EM Bonus} + \\%\\text{Reaction Bonus})",
  catalyzeNote: "Cộng thẳng vào Base DMG của đòn kế tiếp, không nhân %.",
  catalyzeEm: "\\dfrac{5 \\cdot \\mathrm{EM}}{\\mathrm{EM} + 1200}",
  transformative:
    "\\mathrm{DMG} = \\bigl[\\text{Hệ số gốc} \\times \\text{Level Multiplier} \\times (1 + \\%\\text{EM Bonus} + \\%\\text{Reaction Bonus}) + \\text{Reaction Additive Base DMG}\\bigr] \\times \\text{RES} \\times \\text{CRIT}",
  transformativeEm: "\\dfrac{16 \\cdot \\mathrm{EM}}{\\mathrm{EM} + 2000}",
  lunarEm: "\\dfrac{6 \\cdot \\mathrm{EM}}{\\mathrm{EM} + 2000}",
  indirect:
    "\\mathrm{DMG}_{i} = \\text{Hệ số gốc} \\times \\text{Level Multiplier}_{i} \\times (1 + \\%\\text{Reaction Base DMG}) \\times (1 + \\%\\text{EM Bonus} + \\%\\text{Reaction Bonus}) \\times \\text{Elevation} \\times \\text{RES} \\times \\text{CRIT}_{i}",
  aggregation: "\\mathrm{DMG}_{\\text{cuối}} = 0.6\\,d_{1} + 0.3\\,d_{2} + 0.05\\,d_{3} + 0.05\\,d_{4}",
  aggregationNote:
    "d₁…d₄ là sát thương cá nhân xếp giảm dần, tối đa 4 người. Ít hơn 4 người thì bỏ phần thiếu và giữ hệ số còn lại.",
  direct:
    "\\mathrm{DMG} = \\bigl[\\text{Hệ số gốc} \\times \\%\\text{Kỹ năng} \\times \\text{Chỉ số} \\times \\text{Base DMG Multiplier} \\times (1 + \\%\\text{Reaction Base DMG}) \\times (1 + \\%\\text{EM Bonus} + \\%\\text{Reaction Bonus}) + \\text{Reaction Additive Base DMG}\\bigr] \\times \\text{Elevation} \\times \\text{RES} \\times \\text{CRIT}",
  critValue: "\\text{Crit Value} = 2 \\times \\%\\text{CRIT Rate} + \\%\\text{CRIT DMG}",
  steps: {
    defMultiplier: "\\dfrac{70+100}{(1-0.23)\\,(75+100)+70+100} = 0.55783",
    resHydroEffective: "0.10 - 0.40 = -0.30",
    resMultiplier: "1 - \\dfrac{-0.30}{2} = 1.15",
    emBonusAmplifying: "\\dfrac{2.78 \\times 150}{150+1400} = 0.26903",
    amplifyingMultiplier: "2.0 \\times (1 + 0.26903) = 2.53806",
    critDmgFormula: "1500 \\times 6.19 \\times (1 + 0.40 + 0.52) \\times 0.55783 \\times 1.15 \\times 2.53806 \\times (1 + 0.8)",
  } as Record<string, string>,
};
