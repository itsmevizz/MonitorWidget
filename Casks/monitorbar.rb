# Homebrew cask for MonitorBar.
#
# Install:
#   brew tap itsmevizz/monitorwidget https://github.com/itsmevizz/MonitorWidget.git
#   brew install --cask itsmevizz/monitorwidget/monitorbar
#
# Release checklist: bump version, rebuild with scripts/build-app.sh, and update sha256 from
# build/MonitorBar-<version>.dmg.sha256.
cask "monitorbar" do
  version "1.0.0"
  sha256 "bdcff3859c0eba595eae3cbe0b02957c73a23b6b0903b960de5d849be128d12a"

  url "https://github.com/itsmevizz/MonitorWidget/releases/download/v#{version}/MonitorBar-#{version}.dmg"
  name "MonitorBar"
  desc "Menu bar control for external monitors over DDC/CI"
  homepage "https://github.com/itsmevizz/MonitorWidget"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "MonitorBar.app"
  binary "#{appdir}/MonitorBar.app/Contents/Resources/monitorctl", target: "monitorctl"

  # The build is ad-hoc signed (not notarized), so macOS would block the first launch.
  # Removing the quarantine flag lets it open normally. Remove this once the app is notarized.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "/Applications/MonitorBar.app"]
  end

  zap trash: [
    "~/Library/Preferences/local.monitorbar.plist",
    "~/Library/Saved Application State/local.monitorbar.savedState",
  ]
end
