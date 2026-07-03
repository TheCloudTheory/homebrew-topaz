class Topaz < Formula
  desc "Single-binary Azure emulator for local development, testing and CI"
  homepage "https://topaz.thecloudtheory.com"
  version "1.8.95-preview"
  license "Apache-2.0"

  # head is required so brew readall --os=all treats the formula as head_only? on Linux,
  # suppressing the "requires at least a URL" check for non-macOS platforms.
  head "https://github.com/TheCloudTheory/Topaz.git", branch: "main"

  depends_on "dnsmasq"
  depends_on :macos

  on_macos do
    on_arm do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.8.95-preview/topaz-host-osx-arm64"
      sha256 "130ae3673efdc1142d0d63aaad21c3e964d2bae2f252c330eb8a84d2bc9cc648"
    end

    on_intel do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.8.95-preview/topaz-host-osx-x64"
      sha256 "54b6ac2388c5955a08f8e605f56b096a6e6e029b8907576c4206f29917ea97ea"
    end
  end

  # TLS certificates required by Topaz at startup — same for all platforms
  resource "topaz_crt" do
    url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.8.95-preview/topaz.crt"
    sha256 "8f54e2880e9f041de591f09282786a762ea8fe5b24f73e47cee3c9efe2d7ef60"
  end

  resource "topaz_pfx" do
    url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.8.95-preview/topaz.pfx"
    sha256 "30e5191b09eedb5f44472b992431fe089733749edfc63bcba1330e82fb74cf2c"
  end

  # Topaz CLI — resource management tool
  resource "topaz_cli" do
    on_arm do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.8.95-preview/topaz-osx-arm64"
      sha256 "9865179c9ab3831582ad10a654b6dba596e994ae4b9b690fdbcf04670bcb9bcb"
    end

    on_intel do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.8.95-preview/topaz-osx-x64"
      sha256 "69fccd6cebb783ce1eeb142358fd1cce85cbc1518886c299001347dd1d31978e"
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
