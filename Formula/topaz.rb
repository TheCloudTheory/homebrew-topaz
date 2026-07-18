class Topaz < Formula
  desc "Single-binary Azure emulator for local development, testing and CI"
  homepage "https://topaz.thecloudtheory.com"
  version "1.9.110-preview"
  license "Apache-2.0"

  # head is required so brew readall --os=all treats the formula as head_only? on Linux,
  # suppressing the "requires at least a URL" check for non-macOS platforms.
  head "https://github.com/TheCloudTheory/Topaz.git", branch: "main"

  depends_on "dnsmasq"
  depends_on :macos

  on_macos do
    on_arm do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.9.110-preview/topaz-host-osx-arm64"
      sha256 "e304f27ef4281297cacaa75d26d4f0e726b997e7c7e54f185c355e5ab9012c8e"
    end

    on_intel do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.9.110-preview/topaz-host-osx-x64"
      sha256 "62d342be53bc235a377f0fef7f61f7dae1bcd4b008e1fb90536cfab3ded5e804"
    end
  end

  # TLS certificates required by Topaz at startup — same for all platforms
  resource "topaz_crt" do
    url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.9.110-preview/topaz.crt"
    sha256 "2ae7a9fd8e11118fe82590c33e45ade97a9ea8fb35cb717f2c539b1b766a7bd7"
  end

  resource "topaz_pfx" do
    url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.9.110-preview/topaz.pfx"
    sha256 "7f0ffe33dc986b3a73bf1607394805aaac4a5a93b1df3c79c5ce91c5fdba0b50"
  end

  # Topaz CLI — resource management tool
  resource "topaz_cli" do
    on_arm do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.9.110-preview/topaz-osx-arm64"
      sha256 "65d55920a76180ce71f72d80d049c4273b02bd6de6f1ce45a49220f480489fb3"
    end

    on_intel do
      url "https://github.com/TheCloudTheory/Topaz/releases/download/v1.9.110-preview/topaz-osx-x64"
      sha256 "2e2c0299c9007531475925210842e5cf4d6e52eabecc098799ea7359b683e30d"
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

  def post_install_steps
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
