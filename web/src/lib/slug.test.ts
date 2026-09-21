import { describe, expect, it } from "vitest";
import { leadingNumber, storySlug } from "./slug";

describe("storySlug", () => {
  it("folds Vietnamese headings the way the Swift parser does", () => {
    expect(storySlug("Bí mật của Zhongli")).toBe("bi-mat-cua-zhongli");
    expect(storySlug("Chân dung nhân vật")).toBe("chan-dung-nhan-vat");
  });

  it("strips trailing punctuation", () => {
    expect(storySlug("Ghi chú.")).toBe("ghi-chu");
  });
});

describe("leadingNumber", () => {
  it("reads the file prefix", () => {
    expect(leadingNumber("00-mo-dau-mondstadt")).toBe(0);
    expect(leadingNumber("08-buc-tranh-lon")).toBe(8);
    expect(leadingNumber("no-prefix")).toBe(0);
  });
});
