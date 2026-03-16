import os
import re

files_to_fix = [
    "lib/screens/paywall_screen.dart",
    "lib/screens/search_screen.dart",
    "lib/screens/detail_screen.dart",
    "lib/screens/library_screen.dart",
    "lib/screens/profile_screen.dart",
    "lib/screens/settings_screen.dart",
    "lib/screens/highlights_screen.dart",
    "lib/screens/player_screen.dart",
    "lib/screens/record_screen.dart",
    "lib/widgets/meeting_card.dart",
    "lib/widgets/meeting_list_tile.dart",
    "lib/widgets/mini_player.dart"
]

# Specifically target widget/painting classes to avoid removing const from default params
pattern = re.compile(r'\bconst\s+(Icon|TextStyle|Text|SizedBox|Padding|Container|Center|Row|Column|Expanded|Align|Positioned|ListView|GridView|SliverToBoxAdapter|BoxDecoration|InputDecoration|Divider|Spacer|ActionChip|FilterChip|CircularProgressIndicator)\b')

for f in files_to_fix:
    path = os.path.join("/home/ronel/Projects/Scribe", f)
    if not os.path.exists(path): continue
    
    with open(path, "r") as file:
        content = file.read()
        
    new_content = pattern.sub(r'\1', content)
    
    with open(path, "w") as file:
        file.write(new_content)

