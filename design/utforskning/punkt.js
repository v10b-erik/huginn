// Punktmatrise-sifre 5×7 som SVG (D-prøvens signaturgrep). <span class="pm" data-n="13">…</span>
// Farger via CSS-variablene --lit og --unlit på elementet; størrelse via data-pitch (px per prikk).
const M = {
  "0": [".###.","#...#","#...#","#...#","#...#","#...#",".###."],
  "1": ["..#..",".##..","..#..","..#..","..#..","..#..",".###."],
  "2": [".###.","#...#","....#","...#.","..#..",".#...","#####"],
  "3": [".###.","#...#","....#","..##.","....#","#...#",".###."],
  "4": ["...#.","..##.",".#.#.","#..#.","#####","...#.","...#."],
  "5": ["#####","#....","####.","....#","....#","#...#",".###."],
  "6": ["..##.",".#...","#....","####.","#...#","#...#",".###."],
  "7": ["#####","....#","...#.","..#..",".#...",".#...",".#..."],
  "8": [".###.","#...#","#...#",".###.","#...#","#...#",".###."],
  "9": [".###.","#...#","#...#",".####","....#","...#.",".##.."],
};
function punkt(tekst, pitch = 10) {
  const r = pitch * 0.39, n = tekst.length, cols = n * 5 + (n - 1);
  let d = "";
  [...tekst].forEach((ch, i) => M[ch].forEach((rad, y) => [...rad].forEach((c, x) => {
    d += `<circle class="${c === "#" ? "p" : "u"}" cx="${(i * 6 + x) * pitch + pitch / 2}" cy="${y * pitch + pitch / 2}" r="${r}"/>`;
  })));
  return `<svg viewBox="0 0 ${cols * pitch} ${7 * pitch}" width="${cols * pitch}" height="${7 * pitch}" role="img" aria-label="${tekst}">${d}</svg>`;
}
function fyll(rot = document) {
  rot.querySelectorAll(".pm").forEach((e) => { e.innerHTML = punkt(e.dataset.n, Number(e.dataset.pitch || 10)); });
}
document.addEventListener("DOMContentLoaded", () => fyll());
