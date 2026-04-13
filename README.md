# homebrew-topaz

Homebrew tap for [Topaz](https://github.com/TheCloudTheory/Topaz) — a single-binary Azure emulator for local development and testing.

## Install

```bash
brew tap thecloudtheory/topaz
brew install topaz
```

Or in a single command without tapping first:

```bash
brew install thecloudtheory/topaz/topaz
```

This will:
- Install the `topaz` binary
- Install and configure `dnsmasq` to resolve `*.topaz.local.dev` locally
- Create the necessary `/etc/resolver/` entries for all emulated Azure service domains

> **Note:** The DNS setup requires `sudo`. You will be prompted once during installation.

## Usage

Start the emulator:

```bash
topaz start
```

Verify DNS is working:

```bash
dig test.topaz.local.dev @127.0.0.1
```

## Updating

```bash
brew upgrade thecloudtheory/topaz/topaz
```

## Uninstall

```bash
brew uninstall topaz
brew untap thecloudtheory/topaz
```

Note: uninstalling does not remove the `/etc/resolver/` entries or the dnsmasq configuration created during install. To clean those up manually:

```bash
sudo rm /etc/resolver/topaz.local.dev \
        /etc/resolver/keyvault.topaz.local.dev \
        /etc/resolver/storage.topaz.local.dev \
        /etc/resolver/cr.topaz.local.dev \
        /etc/resolver/servicebus.topaz.local.dev \
        /etc/resolver/eventhub.topaz.local.dev
rm $(brew --prefix)/etc/dnsmasq.d/topaz.conf
brew services restart dnsmasq
```

## Documentation

Full documentation, guides, and supported services: [topaz.thecloudtheory.com](https://topaz.thecloudtheory.com)
