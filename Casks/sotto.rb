cask "sotto" do
  version "1.0.0"

  # The release workflow replaces :no_check with the checksum of each ZIP.
  sha256 :no_check

  url "https://github.com/t5victor/sotto/releases/download/cask-#{version}/Sotto-#{version}.zip"
  name "Sotto"
  desc "Native voice dictation for macOS"
  homepage "https://github.com/t5victor/sotto"

  app "Sotto.app"
end
