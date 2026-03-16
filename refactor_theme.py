import os
import re
import subprocess

LIB_DIR = "lib"

# We first extend app_theme.dart with a BuildContext extension
def update_app_theme():
    theme_file = os.path.join(LIB_DIR, "theme", "app_theme.dart")
    with open(theme_file, "r") as f:
        content = f.read()
    
    if "extension ThemeColors" in content:
        return
        
    extension_code = """
extension ThemeColors on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;
  Color get appBackground => _isDark ? AppColors.darkBackground : AppColors.background;
  Color get appSurface => _isDark ? AppColors.darkSurface : AppColors.surface;
  Color get appSurfaceVariant => _isDark ? AppColors.darkSeparator : AppColors.surfaceVariant;
  Color get appSeparator => _isDark ? AppColors.darkSeparator : AppColors.separator;
  Color get appTextPrimary => _isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get appTextSecondary => _isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
  Color get appTextTertiary => AppColors.textTertiary; // Adjust or use dark variant if available
  Color get appPrimary => AppColors.primary;
  Color get appPrimaryLight => AppColors.primaryLight;
  Color get appAccent => AppColors.accent;
  Color get appRecordRed => AppColors.recordRed;
  Color get appGray => AppColors.gray;
  Color get appGreen => AppColors.green;
}
"""
    with open(theme_file, "a") as f:
        f.write(extension_code)

def replace_colors_in_files():
    color_map = {
        'background': 'appBackground',
        'surface': 'appSurface',
        'surfaceVariant': 'appSurfaceVariant',
        'separator': 'appSeparator',
        'textPrimary': 'appTextPrimary',
        'textSecondary': 'appTextSecondary',
        'textTertiary': 'appTextTertiary',
        'primary': 'appPrimary',
        'primaryLight': 'appPrimaryLight',
        'accent': 'appAccent',
        'recordRed': 'appRecordRed',
        'gray': 'appGray',
        'green': 'appGreen',
        
        # We don't replace direct dark colors if they were used explicitly for some reason
    }
    
    for root, _, files in os.walk(LIB_DIR):
        for file in files:
            if not file.endswith('.dart'):
                continue
            filepath = os.path.join(root, file)
            if 'app_theme.dart' in filepath:
                continue
                
            with open(filepath, 'r') as f:
                content = f.read()
            
            new_content = content
            for old_color, new_desc in color_map.items():
                old_str = f"AppColors.{old_color}"
                new_str = f"context.{new_desc}"
                new_content = new_content.replace(old_str, new_str)
                
            if new_content != content:
                # Add import if missing and we introduced context.app...
                if "import '../theme/app_theme.dart';" not in new_content and "import 'theme/app_theme.dart';" not in new_content:
                    # simplistic relative import just assumes most files are 1 level deep, but let's just use absolute-like package import
                    # Or better, we can just change the replace later if needed
                    pass
                with open(filepath, 'w') as f:
                    f.write(new_content)

def fix_const_errors():
    for _ in range(15):
        result = subprocess.run(["flutter", "analyze"], capture_output=True, text=True)
        if result.returncode == 0:
            print("No more errors!")
            break
            
        lines = result.stdout.split('\n')
        fixed_files = set()
        for line in lines:
            if "invalid_assignment" in line or "non_constant_default_value" in line or "const_with_non_constant_argument" in line or "const_initialized_with_non_constant_value" in line or "const_constructor_param_type_mismatch" in line:
                # format usually: info • Invalid constant value. • lib/foo.dart:12:3 • error_code
                parts = line.split('•')
                if len(parts) >= 3:
                    file_info = parts[2].strip().split(':')
                    if len(file_info) >= 3:
                        filepath = file_info[0]
                        linenum = int(file_info[1])
                        
                        if filepath not in fixed_files and os.path.exists(filepath):
                            with open(filepath, 'r') as f:
                                file_lines = f.readlines()
                            
                            idx = linenum - 1
                            # find first 'const ' on this line or walking backward a few lines
                            for search_idx in range(idx, max(-1, idx-5), -1):
                                if "const " in file_lines[search_idx]:
                                    file_lines[search_idx] = file_lines[search_idx].replace("const ", "", 1)
                                    break
                                    
                            with open(filepath, 'w') as f:
                                f.writelines(file_lines)
                            fixed_files.add(filepath)

if __name__ == "__main__":
    update_app_theme()
    replace_colors_in_files()
    fix_const_errors()
