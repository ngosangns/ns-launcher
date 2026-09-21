/** Lowercase, diacritic-stripped, dash-joined slug. Mirrors Swift `storySlug`. */
export function storySlug(text: string): string {
  const deDotted = text.replaceAll("đ", "d").replaceAll("Đ", "D");
  const folded = deDotted.normalize("NFD").replace(/\p{M}/gu, "");
  const lowered = folded.toLowerCase();
  let slug = "";
  let lastWasDash = false;
  for (const ch of lowered) {
    if (/[\p{L}\p{N}]/u.test(ch)) {
      slug += ch;
      lastWasDash = false;
    } else if (!lastWasDash && slug.length > 0) {
      slug += "-";
      lastWasDash = true;
    }
  }
  return slug.replace(/-+$/u, "");
}

export function foldVi(text: string): string {
  return text
    .replaceAll("đ", "d")
    .replaceAll("Đ", "D")
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLowerCase();
}

export function leadingNumber(id: string): number {
  const match = id.match(/^\d+/u);
  return match ? Number.parseInt(match[0], 10) : 0;
}
