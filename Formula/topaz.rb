class Topaz < Formula
  desc "Single-binary Azure emulator for local development and testing"
  homepage "https://topaz.thecloudtheory.com"
  version "1.1.20-beta"
  license "Apache-2.0"

  depends_on "dnsmasq"

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

  def install
    on_macos do
      on_arm { bin.install "topaz-osx-arm64" => "topaz" }
      on_intel { bin.install "topaz-osx-x64" => "topaz" }
    end
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
    # Each entry covers that domain and all subdomains at any depth, so
    # storage.topaz.local.dev covers foo.blob.storage.topaz.local.dev etc.
    # This is a system path — sudo is required and will prompt the user once.
    system "sudo", "mkdir", "-p", "/etc/resolver"

    %w[
      topaz.local.dev
      keyvault.topaz.local.dev
      storage.topaz.local.dev
      cr.topaz.local.dev
      servicebus.topaz.local.dev
      eventhub.topaz.local.dev
    ].each do |domain|
      system "sudo", "bash", "-c",
        "printf 'nameserver 127.0.0.1\\nport 53\\n' > /etc/resolver/#{domain}"
    end

    # Restart dnsmasq to pick up the new configuration
    system "brew", "services", "restart", "dnsmasq"
  end

  test do
    assert_predicate bin/"topaz", :executable?
    system bin/"topaz", "--help"
  end

  def caveats
    <<~EOS
      Topaz has been installed as `topaz`. To start the emulator:
        topaz start

      DNS setup was performed during installation:
        - dnsmasq configured to resolve *.topaz.local.dev → 127.0.0.1
        - Resolver entries created in /etc/resolver/ for:
            keyvault, storage (covers .blob/.table/.queue/.file), cr, servicebus, eventhub

      To verify DNS is working:
        dig test.topaz.local.dev @127.0.0.1

      Full documentation: https://topaz.thecloudtheory.com/docs/intro
    EOS
  end
end
