// DocFX opens a large picture of a page alone, in a new tab, when it is clicked. The site's own art is not for zooming:
// the pictures of its steps, cards, categories and groups never open alone (owner, 2026-11-14), nor do the banners,
// which sit above the page where DocFX does not look. A picture in a page's own text, a screenshot or a diagram, keeps
// DocFX's rule: over 200 pixels each way and not in a link.
const art = '.vh-step-art, .vh-card-visual, .vh-category-image, .vh-group-image, .vh-group-art, .vh-part-art'

export default {
  showLightbox: img => !img.closest(art) && img.naturalWidth > 200 && img.naturalHeight > 200 && !img.closest('a')
}
