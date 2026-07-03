class Topaz < Formula
  desc "Single-binary Azure emulator for local development, testing and CI"
  homepage "https://topaz.thecloudtheory.com"
  version "1.7.134-beta"
  license "Apache-2.0"

  # head is required so brew readall --os=all treats the formula as head_only? on Linux,
  # suppressing the "requires at least a URL" check for non-macOS platforms.
  head "https://github.com/TheCloudTheory/Topaz.git", branch: "main"

  depends_on "dnsmasq"
  depends_on :macos

  on_macos do
    on_arm do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.7.134-beta/topaz-host-osx-arm64"
      sha256 "97afe8ff285e08d4a3c23d67b2ed4e79d37e7980deb61a0d8b385a6c2c7882cd"
    end

    on_intel do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.7.134-beta/topaz-host-osx-x64"
      sha256 "7410d8130acd406398d17305a6b28fb6347e6ac22680f05f56bc22775d18c013"
    end
  end

  # TLS certificates required by Topaz at startup — same for all platforms
  resource "topaz_crt" do
    url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.7.134-beta/topaz.crt"
    sha256 "4adb323acb3517132ad96ef383318ab2e3a1183c2261589b067ace3c8e42efc3"
  end

  resource "topaz_pfx" do
    url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.7.134-beta/topaz.pfx"
    sha256 "f20b19e3d9884076cad7ba3d95ded31fd8521d9bb21175451a73bce4421deffd"
  end

  # Topaz CLI — resource management tool
  resource "topaz_cli" do
    on_arm do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.7.134-beta/topaz-osx-arm64"
      sha256 "e2f76cca08157c9eb91a119555557654a489fa1e3c70d25531895cd1ba7af7f7"
    end

    on_intel do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.7.134-beta/topaz-osx-x64"
      sha256 "57e7aba43fcd8d4749444c1cf97b9fca5f0dba6cb9a6548f64740e8a1db91ae9"
    end
  end

  def install
    if Hardware::CPU.arm?
      libexec.install "topaz-host-osx-arm64" => "topaz-host"
    elsif Hardware::CPU.intel?
      libexec.install "topaz-host-osx-x64" => "topaz-host"
    end
    (libexec/"topaz-host").chmod 0755

    resource("topaz_crt").stage { libexec.install "topaz.crt" }
    resource("topaz_pfx").stage { libexec.install "topaz.pfx" }

    # Extract the private key from the PFX so topaz-host can find topaz.key at runtime
    system "openssl", "pkcs12",
           "-in", libexec/"topaz.pfx",
           "-nocerts", "-nodes",
           "-out", libexec/"topaz.key",
           "-passin", "pass:qwerty"

    # Wrapper script so topaz-host runs from libexec (certs are resolved relative to cwd)
    (bin/"topaz-host").write <<~SH
      #!/bin/bash
      cd "#{libexec}"
      exec "#{libexec}/topaz-host" "$@"
    SH
    (bin/"topaz-host").chmod 0755

    resource("topaz_cli").stage do
      if Hardware::CPU.arm?
        bin.install "topaz-osx-arm64" => "topaz"
      elsif Hardware::CPU.intel?
        bin.install "topaz-osx-x64" => "topaz"
      end
    end
  end

  def post_install
    # Write dnsmasq wildcard rules — Homebrew-owned path, no sudo required
    # Single wildcard resolves all *.topaz.local.dev subdomains to localhost.
    (etc/"dnsmasq.d").mkpath
    (etc/"dnsmasq.d/topaz.conf").write <<~CONF
      address=/.topaz.local.dev/127.0.0.1
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
        printf 'nameserver 127.0.0.1\\nport 53\\n' | sudo tee /etc/resolver/topaz.local.dev >/dev/null

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
