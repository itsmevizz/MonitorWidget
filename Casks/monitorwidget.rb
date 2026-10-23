# Homebrew cask for MonitorWidget.
#
# Install:
#   brew tap itsmevizz/monitorwidget https://github.com/itsmevizz/MonitorWidget.git
#   brew install --cask itsmevizz/monitorwidget/monitorwidget
#
# Release checklist: bump version, rebuild with scripts/build-app.sh, and update sha256 from
# build/MonitorWidget-<version>.dmg.sha256.
cask "monitorwidget" do
  version "1.0.0"
  sha256 "dbb8ced8afa740cdd148e152695d21e88744cd12903f5f658c890932cfcc2dde"

  url "https://github.com/itsmevizz/MonitorWidget/releases/download/v#{version}/MonitorWidget-#{version}.dmg"
  name "MonitorWidget"
  desc "Menu bar control for external monitors over DDC/CI"
  homepage "https://github.com/itsmevizz/MonitorWidget"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "MonitorWidget.app"
  binary "#{appdir}/MonitorWidget.app/Contents/Resources/monitorctl", target: "monitorctl"

  # The build is ad-hoc signed (not notarized), so macOS would block the first launch.
  # Removing the quarantine flag lets it open normally. Remove this once the app is notarized.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "/Applications/MonitorWidget.app"]
  end

  zap trash: [
    "~/Library/Preferences/local.monitorwidget.plist",
    "~/Library/Saved Application State/local.monitorwidget.savedState",
  ]
end
