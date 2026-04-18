#!/usr/bin/env python3
import subprocess
import os
import sys

os.chdir('/Users/simaoalves/Desktop/FlowDay-iOS')

files = [
    "FlowDay/Views/TodayView.swift",
    "FlowDay/Views/RootView.swift",
    "FlowDay/Views/LoginView.swift",
    "FlowDay/Views/SettingsView.swift",
    "FlowDay/Views/SettingsSubViews.swift",
    "FlowDay/Views/BrowseView.swift",
    "FlowDay/Views/HabitsView.swift",
    "FlowDay/Views/InboxView.swift",
    "FlowDay/Views/UpcomingView.swift",
    "FlowDay/Views/SmartQuickAddView.swift",
    "FlowDay/Views/OnboardingView.swift",
    "FlowDay/Theme/FDColors.swift",
    "FlowDay/Theme/FDTypography.swift",
]

# Create output directory
os.makedirs('/tmp/flowday_diffs', exist_ok=True)

for file in files:
    try:
        result = subprocess.run(
            ['git', 'diff', '3757ccc..HEAD', '--', file],
            capture_output=True,
            text=True,
            timeout=10
        )
        output_file = f'/tmp/flowday_diffs/{os.path.basename(file)}.diff'
        with open(output_file, 'w') as f:
            f.write(result.stdout)
            if result.stderr:
                f.write(f'\n\n=== STDERR ===\n{result.stderr}')
        print(f"✓ {file}")
    except Exception as e:
        print(f"✗ {file}: {e}")

print("\nDone. Files written to /tmp/flowday_diffs/")
