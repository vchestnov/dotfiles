# Terminal Email Setup

This setup uses:

- `mbsync` to fetch mail
- `msmtp` to send mail
- `notmuch` to index/search
- `neomutt` to read mail

All paths below follow current XDG setup:

- maildir: `~/.local/share/mail`
- `mbsync`: `~/.config/isyncrc`
- `msmtp`: `~/.config/msmtp/config`
- `neomutt`: `~/.config/neomutt/neomuttrc`
- `notmuch`: `~/.config/notmuch/default/config`

## Gmail

Practical auth path for CLI tools:

1. Enable Google 2-Step Verification.
2. Create Google app password.
3. Use app password in `mbsync` and `msmtp`.

Why: Google says app passwords exist for apps that do not support "Sign in with Google". `isync` and `msmtp` fall in that bucket.

Store secrets with `pass`:

```bash
pass insert mail/gmail-app-password
pass insert mail/institution-password
```

## `mbsync` config

Write `~/.config/isyncrc`:

```conf
Create Both
Expunge Both
SyncState *

IMAPAccount gmail
Host imap.gmail.com
Port 993
User your.name@gmail.com
PassCmd "pass show mail/gmail-app-password | head -n1"
TLSType IMAPS
CertificateFile /etc/ssl/certs/ca-certificates.crt

IMAPStore gmail-remote
Account gmail

MaildirStore gmail-local
SubFolders Verbatim
Path ~/.local/share/mail/gmail/
Inbox ~/.local/share/mail/gmail/INBOX

Channel gmail
Far :gmail-remote:
Near :gmail-local:
Patterns * !"[Gmail]/All Mail" !"[Gmail]/Spam" !"[Gmail]/Trash"
Sync All
```

## `msmtp` config

Write `~/.config/msmtp/config`:

```conf
defaults
auth on
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile ~/.local/state/msmtp/msmtp.log

account gmail
host smtp.gmail.com
port 587
from your.name@gmail.com
user your.name@gmail.com
passwordeval "pass show mail/gmail-app-password | head -n1"

account default : gmail
```

Lock permissions:

```bash
chmod 600 ~/.config/msmtp/config ~/.config/isyncrc
mkdir -p ~/.local/state/msmtp ~/.local/share/mail
mkdir -p ~/.local/share/mail/gmail ~/.local/share/mail/institution
```

## `neomutt` config

Write `~/.config/neomutt/neomuttrc`:

```conf
set mbox_type=Maildir
set folder="~/.local/share/mail"
mailboxes "+gmail/INBOX"
set spoolfile="+gmail/INBOX"

set sendmail="$HOME/.local/bin/msmtp"
set use_from=yes
set envelope_from=yes
unset copy

set from="your.name@gmail.com"
set realname="Your Name"

macro index gi "<change-folder>+gmail/INBOX<enter>" "gmail inbox"
```

## `notmuch` setup

Initialize:

```bash
mkdir -p ~/.config/notmuch/default
notmuch setup
```

Then edit `~/.config/notmuch/default/config`:

Replace `YOUR_USER` in the database path with your login name.

```ini
[database]
path=/home/YOUR_USER/.local/share/mail

[user]
name=Your Name
primary_email=your.name@gmail.com
other_email=you@institution.example
```

## First run

```bash
mbsync gmail
notmuch new
neomutt
```

## Institutional account

Use same pattern. Duplicate `gmail` blocks as `inst` and replace:

- IMAP host
- SMTP host
- username
- password command
- `from`
- local Maildir path

If institution uses Google Workspace and allows app passwords, same Gmail hostnames usually work:

- IMAP: `imap.gmail.com`
- SMTP: `smtp.gmail.com`

If institution disables app passwords or requires SSO-only auth, plain password/app-password setup will not work. Then you need provider-specific OAuth2 flow.

## Oxford Mathematics / Microsoft 365

The Oxford Mathematics / Microsoft 365 setup uses:

- provider: Microsoft 365 / Outlook Web
- incoming server: `outlook.office365.com:993`
- outgoing server: `outlook.office365.com:587`
- auth method: OAuth2
- username: `abcd1234@ox.ac.uk`
- MFA required

Important: for this account, `mbsync`/`msmtp` should not use your SSO password directly. You need OAuth2 access tokens.

Microsoft's official Exchange Online OAuth doc says:

- IMAP user scope: `https://outlook.office.com/IMAP.AccessAsUser.All`
- SMTP user scope: `https://outlook.office.com/SMTP.Send`
- add `offline_access` if you want refresh tokens
- client must authenticate IMAP/SMTP with SASL `XOAUTH2`

That matches Oxford's Thunderbird instructions.

### What this means for CLI setup

For Oxford:

- `mbsync` should use `AuthMechs XOAUTH2`
- `mbsync` should get current access token from `PassCmd`
- `msmtp` should use `auth xoauth2` or `auth oauthbearer`
- `msmtp` should get current access token from `passwordeval`
- token should come from repo helper script `oauth2-oxford-token`

Without that token helper and a valid Microsoft Entra app/client ID, Oxford account will not work in this CLI stack.

## Oxford helper script

Repo now includes:

- script: `scripts/oauth2-oxford-token`
- linked command after `./makesymlinks.sh`: `~/.local/bin/oauth2-oxford-token`

The helper:

- uses Microsoft device-code flow
- caches `access_token` + `refresh_token` under `~/.local/state/oxford-oauth/token.json`
- reads config from `~/.config/oxford-oauth/env`

Create config dir:

```bash
mkdir -p ~/.config/oxford-oauth ~/.local/state/oxford-oauth
chmod 700 ~/.config/oxford-oauth ~/.local/state/oxford-oauth
```

Write `~/.config/oxford-oauth/env`:

```sh
OXFORD_OAUTH_CLIENT_ID=your-app-client-id-here
OXFORD_OAUTH_TENANT=organizations
```

Then lock it:

```bash
chmod 600 ~/.config/oxford-oauth/env
```

## Oxford app registration

You need a Microsoft Entra app/client ID that can use device flow.

If you register your own app, configure it roughly like this:

- app type: public client / mobile and desktop
- supported account types: organizational accounts
- delegated permissions:
  - `IMAP.AccessAsUser.All`
  - `SMTP.Send`
- token flow:
  - device authorization grant

If Oxford blocks user consent or app registration, browser login may say admin approval is required. Then Oxford IT must approve or provide a supported client ID.

## Oxford helper commands

First login:

```bash
oauth2-oxford-token login
```

That prints Microsoft device-flow instructions in terminal. Complete browser login and MFA.

Useful commands:

```bash
oauth2-oxford-token info
oauth2-oxford-token imap
oauth2-oxford-token smtp
oauth2-oxford-token clear
```

## Oxford `mbsync` example

Append to `~/.config/isyncrc`:

```conf
IMAPAccount oxford
Host outlook.office365.com
Port 993
User abcd1234@ox.ac.uk
PassCmd "$HOME/.local/bin/oauth2-oxford-token imap"
AuthMechs XOAUTH2
TLSType IMAPS
CertificateFile /etc/ssl/certs/ca-certificates.crt

IMAPStore oxford-remote
Account oxford

MaildirStore oxford-local
SubFolders Verbatim
Path ~/.local/share/mail/oxford/
Inbox ~/.local/share/mail/oxford/INBOX

Channel oxford
Far :oxford-remote:
Near :oxford-local:
Patterns *
Sync All
```

## Oxford `msmtp` example

Append to `~/.config/msmtp/config`:

```conf
account oxford
host outlook.office365.com
port 587
from abcd1234@ox.ac.uk
user abcd1234@ox.ac.uk
auth xoauth2
passwordeval "$HOME/.local/bin/oauth2-oxford-token smtp"
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
```

In practice, one helper can often fetch tokens for both scopes, but the requested scope string differs:

- IMAP: `https://outlook.office.com/IMAP.AccessAsUser.All offline_access`
- SMTP: `https://outlook.office.com/SMTP.Send offline_access`

## Oxford local dirs

Create local maildir:

```bash
mkdir -p ~/.local/share/mail/oxford
```

## Oxford first run

```bash
oauth2-oxford-token login
mbsync oxford
```

For sending test mail:

```bash
printf 'Subject: oxford test\n\nhello\n' | msmtp -a oxford your.address@example.com
```

## Recommended path

For Oxford, there are two realistic options:

1. Use `mbsync` + `msmtp` + an OAuth2 token helper for Microsoft 365.
2. Use Thunderbird for Oxford and keep CLI stack for Gmail only.

Option 1 is workable, but more setup than Gmail because Microsoft 365 OAuth2 needs an app registration or an existing helper tool that already knows how to do Microsoft device flow.

## Institutional `mbsync` example

Append to `~/.config/isyncrc`:

```conf
IMAPAccount inst
Host imap.institution.example
Port 993
User your.name@institution.example
PassCmd "pass show mail/institution-password | head -n1"
TLSType IMAPS
CertificateFile /etc/ssl/certs/ca-certificates.crt

IMAPStore inst-remote
Account inst

MaildirStore inst-local
SubFolders Verbatim
Path ~/.local/share/mail/institution/
Inbox ~/.local/share/mail/institution/INBOX

Channel inst
Far :inst-remote:
Near :inst-local:
Patterns *
Sync All
```

## Institutional `msmtp` example

Append to `~/.config/msmtp/config`:

```conf
account inst
host smtp.institution.example
port 587
from your.name@institution.example
user your.name@institution.example
passwordeval "pass show mail/institution-password | head -n1"
```

To make institutional account default sender in NeoMutt for some folders, add matching `folder-hook` rules later.

## Troubleshooting

- `libidn2` missing during NeoMutt build:
  bootstrap now auto-adds `--disable-idn2`.
- `mbsync` auth fails:
  verify IMAP enabled, username exact, app password correct.
- `msmtp` auth fails:
  verify SMTP host/port/TLS and app password.
- institution account fails with normal password:
  provider may require OAuth2 or app password policy may block basic auth.
- Oxford / Microsoft 365 fails with SSO password:
  expected. Use OAuth2/XOAUTH2 token flow, not plain password auth.
- Oxford helper says admin approval required:
  Oxford tenant likely blocks user consent for your app. Ask IT for approval or a supported client ID.
- Oxford helper login works but IMAP/SMTP still fail:
  check that app permissions include `IMAP.AccessAsUser.All` and `SMTP.Send`.

## Sources

- Google app passwords: <https://support.google.com/accounts/answer/185833>
- Gmail in other mail clients: <https://support.google.com/mail/answer/7126229?hl=en>
- Gmail IMAP info: <https://support.google.com/mail/answer/78892>
- Microsoft Exchange Online OAuth for IMAP/POP/SMTP: <https://learn.microsoft.com/en-us/exchange/client-developer/legacy-protocols/how-to-authenticate-an-imap-pop-smtp-application-by-using-oauth>
