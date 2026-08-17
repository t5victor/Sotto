cask "sotto" do
  version "1.0.1"

  # The release workflow replaces :no_check with the checksum of each ZIP.
  sha256 "0183bdd9048d0f14386eb5705da59d73777124af3eee94af76aef3fbdf970ca0"

  url "https://github.com/t5victor/sotto/releases/download/cask-#{version}/Sotto-#{version}.zip"
  name "Sotto"
  desc "Native voice dictation for macOS"
  homepage "https://github.com/t5victor/sotto"

  app "Sotto.app"
end
