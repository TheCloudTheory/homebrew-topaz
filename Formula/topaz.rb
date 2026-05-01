class Topaz < Formula
  desc "Single-binary Azure emulator for local development, testing and CI"
  homepage "https://topaz.thecloudtheory.com"
  version "1.1.20-beta"
  license "Apache-2.0"

  depends_on :macos
  depends_on "dnsmasq"

  # TLS certificates required by Topaz at startup — same for all platforms
  resource "topaz_crt" do
    url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.1.20-beta/topaz.crt"
    sha256 "7c2c08addd35ae719f1ef30d2fbf2df5ea4d398df4526c5ea00aaacb5580fb72"
  end

  resource "topaz_pfx" do
    url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.1.20-beta/topaz.pfx"
    sha256 "b78e595ffe3e44838ac30ee82b92c7239b8e496e05ba5c4eedf5c3fe3ca61da6"
  end

  # Topaz Host — the emulator process
  on_macos do
    on_arm do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.1.20-beta/topaz-host-osx-arm64"
      sha256 :no_check
    end

    on_intel do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.1.20-beta/topaz-host-osx-x64"
      sha256 :no_check
    end
  end

  # Topaz CLI — resource management tool
  resource "topaz_cli" do
    on_macos do
      on_arm do
        url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.1.20-beta/topaz-osx-arm64"
        sha256 "55ba64248b0f7ca0e55760d6092bc37811878c7131f8cf2553a4f7b34b3239ee"
      end

      on_intel do
        url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.1.20-beta/topaz-osx-x64"
        sha256 "7423ab6907f3e41eff48d92d79f31a181747567e78cfd17933d933ef959b6a8c"
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

    # Restart dnsmasq to pick up the new configuration
    system "brew", "services", "restart", "dnsmasq"
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

      DNS — dnsmasq was configured and restarted during installation.
      To complete DNS setup, run these commands once (requires sudo):

        sudo mkdir -p /etc/resolver
        for domain in topaz.local.dev keyvault.topaz.local.dev \\
                      storage.topaz.local.dev cr.topaz.local.dev \\
                      servicebus.topaz.local.dev eventhub.topaz.local.dev; do
          printf 'nameserver 127.0.0.1\\nport 53\\n' | sudo tee /etc/resolver/$domain >/dev/null
        done

      To verify DNS is working:
        dig test.topaz.local.dev @127.0.0.1

      Full documentation: https://topaz.thecloudtheory.com/docs/intro
    EOS
  end
end
