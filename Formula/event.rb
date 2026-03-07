class Event < Formula
  desc "CLI tool for managing Apple Reminders and Calendar via EventKit"
  homepage "https://github.com/FradSer/event"
  url "https://github.com/FradSer/event/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"
  version "0.1.0"
  license "MIT"

  depends_on swift: :build

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/event"
  end

  test do
    system "#{bin}/event", "--help"
  end
end
