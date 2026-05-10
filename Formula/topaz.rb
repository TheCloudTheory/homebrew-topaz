class Topaz < Formula
  desc "Single-binary Azure emulator for local development, testing and CI"
  homepage "https://topaz.thecloudtheory.com"
  version "1.3.98-beta"
  license "Apache-2.0"

  # head is required so brew readall --os=all treats the formula as head_only? on Linux,
  # suppressing the "requires at least a URL" check for non-macOS platforms.
  head "https://github.com/TheCloudTheory/Topaz.git", branch: "main"

  depends_on "dnsmasq"
  depends_on :macos

  on_macos do
    on_arm do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.3.98-beta/topaz-host-osx-arm64"
      sha256 "5d60dadc651e2b1f81e97418212f6d931b1d59d4dbb5a9d5d62bb701b912c32f"
    end

    on_intel do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.3.98-beta/topaz-host-osx-x64"
      sha256 "91e52a81e1c224861643d9323d76ac1b03f58eb30a78c85c546a209965f5c8dd"
    end
  end

  # TLS certificates required by Topaz at startup — same for all platforms
  resource "topaz_crt" do
    url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.3.98-beta/topaz.crt"
    sha256 "59ef64d94aaac7b988da817f692b52a4b5eb56165a33c042e0dbdde83d952a88"
  end

  resource "topaz_pfx" do
    url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.3.98-beta/topaz.pfx"
    sha256 "3a52252d5d3649cdbc73f369bc6e665450c38b43af7552ff3689d5e0c502422f"
  end

  # Topaz CLI — resource management tool
  resource "topaz_cli" do
    on_arm do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.3.98-beta/topaz-osx-arm64"
      sha256 "d68b25855ac633ebd4401f68cfaf52fd09005b8e467425661982732ff5c970fd"
    end

    on_intel do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.3.98-beta/topaz-osx-x64"
      sha256 "c8349cef731913ae759a1d1015dceb79c7f2245a12eaccd305de46021badce3e"
    end
  end

  def install
    if Hardware::CPU.arm?
      bin.install "topaz-host-osx-arm64" => "topaz-host"
    elsif Hardware::CPU.intel?
      bin.install "topaz-host-osx-x64" => "topaz-host"
    end

    resource("topaz_cli").stage do
      if Hardware::CPU.arm?
        bin.install "topaz-osx-arm64" => "topaz"
      elsif Hardware::CPU.intel?
        bin.install "topaz-osx-x64" => "topaz"
      end
    end

    resource("topaz_crt").stage { bin.install "topaz.crt" }
    resource("topaz_pfx").stage { bin.install "topaz.pfx" }
  end

  def post_install
    # Write dnsmasq wildcard rules — Homebrew-owned path, no sudo required
    # The storage entry covers all per-account subdomains:
    #   {account}.blob.storage.topaz.local.dev
    #   {account}.table.storage.topaz.local.dev
    #   {account}.queue.storage.topaz.local.dev
    #   {account}.file.storage.topaz.local.dev
    # The cr entry covers per-registry ACR subdomains:
    #   {registry}.cr.topaz.local.dev
    (etc/"dnsmasq.d").mkpath
    (etc/"dnsmasq.d/topaz.conf").write <<~CONF
      address=/.topaz.local.dev/127.0.0.1
      address=/.keyvault.topaz.local.dev/127.0.0.1
      address=/.storage.topaz.local.dev/127.0.0.1
      address=/.cr.topaz.local.dev/127.0.0.1
      address=/.servicebus.topaz.local.dev/127.0.0.1
      address=/.eventhub.topaz.local.dev/127.0.0.1
    CONF

    # Create /etc/resolver entries so macOS routes *.topaz.local.dev to dnsmasq.
    # Run the commands printed in the caveats section once with sudo.
  end

  def caveats
    <<~EOS
      Topaz has been installed as two separate executables:
        - `topaz-host` — the emulator process
        - `topaz`      — the CLI for managing resources

      To start the emulator:
        topaz-host --log-level Information

      Then use `topaz` in a separate terminal to manage resources:
        topaz subscription create --id <guid> --name "dev-local"

      DNS — dnsmasq was configured during installation.
      To complete DNS setup, run these commands once (requires sudo):

        sudo mkdir -p /etc/resolver
        for domain in topaz.local.dev keyvault.topaz.local.dev \\
                      storage.topaz.local.dev cr.topaz.local.dev \\
                      servicebus.topaz.local.dev eventhub.topaz.local.dev; do
          printf 'nameserver 127.0.0.1\\nport 53\\n' | sudo tee /etc/resolver/$domain >/dev/null
        done

      Then restart dnsmasq to pick up the new configuration:
        brew services restart dnsmasq

      To verify DNS is working:
        dig test.topaz.local.dev @127.0.0.1

      Full documentation: https://topaz.thecloudtheory.com/docs/intro
    EOS
  end

  test do
    assert_predicate bin/"topaz-host", :executable?
    assert_predicate bin/"topaz", :executable?
    system bin/"topaz-host", "--help"
    system bin/"topaz", "--help"
  end
end
