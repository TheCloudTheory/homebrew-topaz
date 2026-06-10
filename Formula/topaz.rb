class Topaz < Formula
  desc "Single-binary Azure emulator for local development, testing and CI"
  homepage "https://topaz.thecloudtheory.com"
  version "1.6.89-beta"
  license "Apache-2.0"

  # head is required so brew readall --os=all treats the formula as head_only? on Linux,
  # suppressing the "requires at least a URL" check for non-macOS platforms.
  head "https://github.com/TheCloudTheory/Topaz.git", branch: "main"

  depends_on "dnsmasq"
  depends_on :macos

  on_macos do
    on_arm do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.6.89-beta/topaz-host-osx-arm64"
      sha256 "d60a0403dd41ea9637deb9ccd5d433b42524d7dd9845efa3722ee87f3c2d6d9b"
    end

    on_intel do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.6.89-beta/topaz-host-osx-x64"
      sha256 "7e3599f64ffcbe13f94802de30863f1d69e2127678710fd199990f71c4158cf5"
    end
  end

  # TLS certificates required by Topaz at startup — same for all platforms
  resource "topaz_crt" do
    url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.6.89-beta/topaz.crt"
    sha256 "59ef64d94aaac7b988da817f692b52a4b5eb56165a33c042e0dbdde83d952a88"
  end

  resource "topaz_pfx" do
    url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.6.89-beta/topaz.pfx"
    sha256 "3a52252d5d3649cdbc73f369bc6e665450c38b43af7552ff3689d5e0c502422f"
  end

  # Topaz CLI — resource management tool
  resource "topaz_cli" do
    on_arm do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.6.89-beta/topaz-osx-arm64"
      sha256 "13c9023aba2930f5360f779acc27800bd046c8de24442e569dd7be2b712fd27d"
    end

    on_intel do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.6.89-beta/topaz-osx-x64"
      sha256 "c4eec3d60992f3156b50c3fbbf654262640cf1bf4b99307b194ceebf3cc2e540"
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
