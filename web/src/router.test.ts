import { describe, expect, it } from "vitest";
import { shouldHandleLink } from "./router";

const base = "http://localhost:5173/abyss/team";

function click(href: string | null, extra: Partial<Parameters<typeof shouldHandleLink>[0]> = {}) {
  return shouldHandleLink({
    href,
    base,
    button: 0,
    modified: false,
    defaultPrevented: false,
    target: null,
    download: false,
    ...extra,
  });
}

describe("internal router", () => {
  it("opens same-origin paths inside the app", () => {
    expect(click("/story")).toBe("/story");
    expect(click("/abyss/characters/hu-tao")).toBe("/abyss/characters/hu-tao");
    expect(click("http://localhost:5173/story/d/00#x")).toBe("/story/d/00#x");
  });

  it("leaves external, hash, modified, and download clicks to the browser", () => {
    expect(click("https://example.com/story")).toBeNull();
    expect(click("#section")).toBeNull();
    expect(click("mailto:a@b.c")).toBeNull();
    expect(click("blob:http://localhost:5173/roster")).toBeNull();
    expect(click("/story", { modified: true })).toBeNull();
    expect(click("/story", { button: 1 })).toBeNull();
    expect(click("/story", { target: "_blank" })).toBeNull();
    expect(click("/story", { download: true })).toBeNull();
    expect(click("/story", { defaultPrevented: true })).toBeNull();
    expect(click(null)).toBeNull();
  });
});
