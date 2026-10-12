# Homebrew formula for Pix. The published copy lives in the eslamalii/homebrew-tap repo; scripts/release.sh
# prints the url, sha256 and build number to paste in.
class Pix < Formula
  desc "Tiny pixel robot that lives on your MacBook Pro's Touch Bar"
  homepage "https://meetpix.app"
  url "https://github.com/eslamalii/pix/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license :cannot_represent # MIT code, all-rights-reserved character: see LICENSE

  depends_on macos: :sonoma

  # Built from source on your Mac, so macOS doesn't quarantine it: no Gatekeeper prompt, on Intel or Apple Silicon.
  def install
    ENV["PIX_BUILD"] = "0" # placeholder: scripts/release.sh prints the build number
    system "./scripts/build-app.sh", "--bundle"
    prefix.install "build/Pix.app"
  end

  def caveats
    <<~EOS
      Start Pix:
        open #{opt_prefix}/Pix.app

      After that it starts at login by itself; turn that off from Pix's menu-bar icon.
      To find it in Spotlight and Launchpad too:
        ln -sf #{opt_prefix}/Pix.app ~/Applications/Pix.app

      After `brew upgrade pix`, choose Quit Pix from its menu-bar icon and open it again,
      so the new version runs and starts at login.
      Before `brew uninstall pix`, turn off Start at Login in Pix's menu-bar icon, then choose Quit Pix.
    EOS
  end

  test do
    assert_predicate prefix/"Pix.app/Contents/MacOS/Pix", :executable?
  end
end
