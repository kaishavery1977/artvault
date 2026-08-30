import pathlib

p = pathlib.Path(r'lib/features/gallery/painting_card.dart')
c = p.read_text(encoding='utf-8')

# 1. Update PaintingGridCard constructor
old_grid_ctor = """  const PaintingGridCard({
    super.key,
    required this.painting,
    this.onTap,
    this.heroTag,
    this.staggerIndex,
  });"""

new_grid_ctor = """  const PaintingGridCard({
    super.key,
    required this.painting,
    this.onTap,
    this.heroTag,
    this.staggerIndex,
    this.selectMode = false,
    this.selected = false,
    this.onSelect,
    this.onLongPress,
  });

  final bool selectMode;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onLongPress;"""

c = c.replace(old_grid_ctor, new_grid_ctor)

# 2. Update the InkWell in PaintingGridCard to support select mode
old_inkwell = """          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap ?? () => context.push('/painting/${painting.id}'),
              onLongPress: canEdit
                  ? () => context.push('/painting/edit/${painting.id}')
                  : null,
            ),
          ),"""

new_inkwell = """          // Select mode checkbox overlay
          if (selectMode)
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: Container(
                decoration: BoxDecoration(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black45,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: selectMode
                  ? onSelect
                  : (onTap ?? () => context.push('/painting/${painting.id}')),
              onLongPress: selectMode
                  ? null
                  : (onLongPress ??
                      (canEdit
                          ? () => context.push('/painting/edit/${painting.id}')
                          : null)),
            ),
          ),"""

c = c.replace(old_inkwell, new_inkwell)

# 3. Update PaintingListTile constructor
old_list_ctor = """  const PaintingListTile({super.key, required this.painting, this.onTap});"""

new_list_ctor = """  const PaintingListTile({
    super.key,
    required this.painting,
    this.onTap,
    this.selectMode = false,
    this.selected = false,
    this.onSelect,
    this.onLongPress,
  });

  final bool selectMode;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onLongPress;"""

c = c.replace(old_list_ctor, new_list_ctor)

# 4. Update PaintingListTile InkWell
old_list_ink = """        child: InkWell(
          onTap: onTap ?? () => context.push('/painting/${painting.id}'),
          child: Padding("""

new_list_ink = """        child: InkWell(
          onTap: selectMode
              ? onSelect
              : (onTap ?? () => context.push('/painting/${painting.id}')),
          onLongPress: selectMode ? null : onLongPress,
          child: Padding("""

c = c.replace(old_list_ink, new_list_ink)

# 5. Add checkbox to the beginning of PaintingListTile Row
old_list_leading = """              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: ArtImage("""

new_list_leading = """              children: [
                if (selectMode)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  child: ArtImage("""

c = c.replace(old_list_leading, new_list_leading)

p.write_text(c, encoding='utf-8')
print("PaintingCard: added select mode support")
