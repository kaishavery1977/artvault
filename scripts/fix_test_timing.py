import pathlib

# Update test helpers timing
p = pathlib.Path(r'test/helpers.dart')
content = p.read_text(encoding='utf-8')

# Update pumpToOnboarding timing
content = content.replace(
    "await tester.pump(const Duration(milliseconds: 3000));",
    "await tester.pump(const Duration(milliseconds: 3500));"
)

p.write_text(content, encoding='utf-8')
print("Test helpers: updated timing")

# Update test/widget_test.dart timing
p2 = pathlib.Path(r'test/widget_test.dart')
content2 = p2.read_text(encoding='utf-8')

# Update any splash-specific timing references
content2 = content2.replace(
    "Duration(milliseconds: 2800)",
    "Duration(milliseconds: 3500)"
)

p2.write_text(content2, encoding='utf-8')
print("Widget tests: updated timing")
