import pathlib

p = pathlib.Path(r'lib/features/gallery/gallery_screen.dart')
c = p.read_text(encoding='utf-8')

# 1. Add artist to the enum
c = c.replace(
    "enum GallerySort { newest, oldest, title, priceHigh, priceLow }",
    "enum GallerySort { newest, oldest, title, artist, priceHigh, priceLow }"
)

# 2. Add artist sort case to the _filter method
c = c.replace(
    """      case GallerySort.title:
        list.sort((a, b) => a.title.compareTo(b.title));
      case GallerySort.priceHigh:""",
    """      case GallerySort.title:
        list.sort((a, b) => a.title.compareTo(b.title));
      case GallerySort.artist:
        list.sort((a, b) => a.artistName.compareTo(b.artistName));
      case GallerySort.priceHigh:"""
)

# 3. Add artist sort option to the PopupMenu
c = c.replace(
    """                      PopupMenuItem(
                        value: GallerySort.title,
                        child: Text('Title (A–Z)'),
                      ),""",
    """                      PopupMenuItem(
                        value: GallerySort.title,
                        child: Text('Title (A–Z)'),
                      ),
                      PopupMenuItem(
                        value: GallerySort.artist,
                        child: Text('Artist name'),
                      ),"""
)

p.write_text(c, encoding='utf-8')
print("Gallery: added 'by artist' sort option")
