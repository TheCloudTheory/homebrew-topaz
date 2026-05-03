class Topaz < Formula
  desc "Single-binary Azure emulator for local development, testing and CI"
  homepage "https://topaz.thecloudtheory.com"
  version "1.2.6-beta"
  license "Apache-2.0"

  depends_on :macos
  depends_on "dnsmasq"

  # TLS certificates required by Topaz at startup — same for all platforms
  resource "topaz_crt" do
    url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.2.6-beta/topaz.crt"
    sha256 "59ef64d94aaac7b988da817f692b52a4b5eb56165a33c042e0dbdde83d952a88"
  end

  resource "topaz_pfx" do
    url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.2.6-beta/topaz.pfx"
    sha256 "3a52252d5d3649cdbc73f369bc6e665450c38b43af7552ff3689d5e0c502422f"
  end

  # Topaz Host — the emulator process
  on_macos do
    on_arm do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.2.6-beta/topaz-host-osx-arm64"
      sha256 "f382f038955e275b5ec5b918f658aee1dfd4d1a2e0028007e2e0ba27a544ad5f"
    end

    on_intel do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.2.6-beta/topaz-host-osx-x64"
      sha256 "92e9819f9b6bbd205cee30a3e4bbdfd39e030ef8a8593f8704a342a95fef572a"
    end
  end

  # Topaz CLI — resource management tool
  resource "topaz_cli" do
    on_macos do
      on_arm do
        url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.2.6-beta/topaz-osx-arm64"
        sha256 "ede4c29437caa7664b916bffa2e1084a80740f2382896f3989280a77b07aa14f"
      end

      on_intel do
        url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.2.6-beta/topaz-osx-x64"
        sha256 "c5ffe94a5f3d2c6b0e6c07b210e3fe0a7f06f18fae168848bb51c16e76f7f7b4"
      end
    end
  end

  def install
    on_macos do
      on_arm do
        bin.install "topaz-host-osx-arm64" => "topaz-host"
      end
      on_intel do
        bin.install "topaz-host-osx-x64" => "topaz-host"
      end
    end

    resource("topaz_cli").stage do
      on_macos do
        on_arm { bin.install "topaz-osx-arm64" => "topaz" }
        on_intel { bin.install "topaz-osx-x64" => "topaz" }
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

  test do
    assert_predicate bin/"topaz-host", :executable?
    assert_predicate bin/"topaz", :executable?
    system bin/"topaz-host", "--help"
    system bin/"topaz", "--help"
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
end
