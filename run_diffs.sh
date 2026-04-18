#!/bin/bash

cd /Users/simaoalves/Desktop/FlowDay-iOS

# Create output directory
mkdir -p /tmp/flowday_diffs

# List of view files to check
files=(
  "FlowDay/Views/TodayView.swift"
  "FlowDay/Views/RootView.swift"
  "FlowDay/Views/LoginView.swift"
  "FlowDay/Views/SettingsView.swift"
  "FlowDay/Views/SettingsSubViews.swift"
  "FlowDay/Views/BrowseView.swift"
  "FlowDay/Views/HabitsView.swift"
  "FlowDay/Views/InboxView.swift"
  "FlowDay/Views/UpcomingView.swift"
  "FlowDay/Views/SmartQuickAddView.swift"
  "FlowDay/Views/OnboardingView.swift"
  "FlowDay/Theme/FDColors.swift"
  "FlowDay/Theme/FDTypography.swift"
)

# Run diffs for each file
for file in "${files[@]}"; do
  echo "Diffing: $file"
  git diff 3757ccc..HEAD -- "$file" > "/tmp/flowday_diffs/$(basename $file).diff" 2>&1
done

echo "Done. Output in /tmp/flowday_diffs/"
ls -la /tmp/flowday_diffs/
