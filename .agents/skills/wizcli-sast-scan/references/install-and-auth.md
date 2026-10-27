# Installing and authenticating wizcli

Only needed when `wizcli` is missing or a scan fails with an auth error.

## Install (macOS)

```bash
brew install --cask wizcli
wizcli version
```

## Authenticate with your own Wiz user

```bash
wizcli auth --use-device-code
```

This prints a URL (`https://app.wiz.io/login/device`) and a code. Open the URL, enter the code, and approve. It prints "Authenticated successfully." and caches the login.

Run it in the user's own terminal (in Claude Code, type `! wizcli auth --use-device-code`). A background run times out before anyone can approve, and the code is then dead.

## Service account alternative

```bash
wizcli auth --id <client-id> --secret <client-secret>
```

A scan needs `create:security_scans` and `update:security_scans`. The standard read-only service account lacks them, so the device-code login with a personal user is the easier path.

## Check it works

```bash
wizcli scan dir <small-dir> --disabled-scanners Vulnerability,Secret,SensitiveData,Misconfiguration,SoftwareSupplyChain,AIModels,Malware --no-publish
```

Expect "Connected to Wiz" and a scan summary.
