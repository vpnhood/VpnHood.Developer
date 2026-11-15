// DocFX opens a large picture of a page alone, in a new tab, when it is clicked. The site's own art is not for zooming:
// the pictures of its steps, cards, categories and groups never open alone (owner, 2026-11-14), nor do the banners,
// which sit above the page where DocFX does not look. A picture in a page's own text, a screenshot or a diagram, keeps
// DocFX's rule: over 200 pixels each way and not in a link.
const art = '.vh-step-art, .vh-card-visual, .vh-category-image, .vh-group-image, .vh-group-art, .vh-part-art'

// A long dotted name, VpnHood.Core.Server.Access.Managers.FileAccessManagers, is one word to the browser: on a phone it
// ran off the screen, and it held a table's first column so wide that the other columns were squeezed to a few words a
// line. It may wrap after each dot now.
function breakNamesAtDots() {
  for (const block of document.querySelectorAll('article p, article li, article td, article th')) {
    const walker = document.createTreeWalker(block, NodeFilter.SHOW_TEXT)
    const names = []
    while (walker.nextNode()) if (/\.(?=[A-Z<])/.test(walker.currentNode.data)) names.push(walker.currentNode)
    for (const name of names) {
      const parts = name.data.split(/(?<=\.)(?=[A-Z<])/)
      name.replaceWith(...parts.flatMap((part, i) => i ? [document.createElement('wbr'), part] : [part]))
    }
  }
}

// On a phone, main.css shows each row of a table as a card (owner, 2026-11-15: "good", after the tables were "almost
// useless" in mobile view); a cell other than the first goes under its column's name, which this gives it.
function labelTableCells() {
  for (const table of document.querySelectorAll('article table')) {
    const labels = [...(table.tHead?.rows[0]?.cells ?? [])].map(cell => cell.textContent.trim())
    for (const row of table.tBodies[0]?.rows ?? []) {
      [...row.cells].forEach((cell, i) => { if (i > 0 && labels[i]) cell.dataset.label = labels[i] })
    }
  }
}

export default {
  start: () => { breakNamesAtDots(); labelTableCells() },
  showLightbox: img => !img.closest(art) && img.naturalWidth > 200 && img.naturalHeight > 200 && !img.closest('a')
}
