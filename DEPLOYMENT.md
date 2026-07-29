
---

## 📋 What You Need Before Starting

| Item | Your Value | Example |
|------|-----------|---------|
| **Domain name** | `officialmonsterz.com` | — |
| **VPS IP address** | `12.34.55.66` | — |
| **VPS root password or SSH key** | You have this from your VPS provider | — |
| **A computer (your laptop/desktop)** | You're using it right now | — |
| **A Namecheap account** | You own `officialmonsterz.com` there | — |

---

## Step 1: Set Up DNS on Namecheap (Do This FIRST)

DNS changes take time to spread (5 minutes to 48 hours). Do this step first so it propagates while you do the rest.

### 1.1 Log into Namecheap
1. Go to https://www.namecheap.com
2. Click **Sign In** (top right)
3. Enter your username and password

### 1.2 Go to Domain List
1. Click **Dashboard** (top menu)
2. Click **Domain List** (left sidebar)
3. Find `officialmonsterz.com` and click **Manage**

### 1.3 Click "Advanced DNS"
You'll see a tab bar. Click **Advanced DNS**.

### 1.4 Delete existing default records (if any)
Look for any default records Namecheap added (like `www`, `@`, `*`). Click the red **X** to delete them. Keep only what you need. We'll add fresh ones.

### 1.5 Add these records (one at a time)

Click **ADD NEW RECORD** for each one.

| Type | Host | Value | TTL | Priority |
|------|------|-------|-----|----------|
| A | `@` | `12.34.55.66` | Automatic | — |
| A | `postal` | `12.34.55.66` | Automatic | — |
| A | `mx1` | `12.34.55.66` | Automatic | — |
| A | `mx2` | `12.34.55.66` | Automatic | — |
| A | `rp` | `12.34.55.66` | Automatic | — |
| CNAME | `track` | `postal.officialmonsterz.com.` | Automatic | — |

**IMPORTANT for CNAME:** The value must end with a **dot** `.` like `postal.officialmonsterz.com.`

### 1.6 Verify DNS resolves

Wait 5 minutes, then on your local computer open a terminal (Command Prompt on Windows, Terminal on Mac/Linux) and run:

```bash
ping postal.officialmonsterz.com
```

**Expected output:**
```
Pinging postal.officialmonsterz.com [12.34.55.66] ...
```

If you see `12.34.55.66`, DNS is working. If you see a different IP, wait longer.

---

## Step 2: Connect to Your VPS

### 2.1 Open a terminal
- **Windows:** Press `Windows Key`, type `cmd`, press Enter
- **Mac:** Press `Cmd + Space`, type `Terminal`, press Enter
- **Linux:** Press `Ctrl + Alt + T`

### 2.2 SSH into your server

```bash
ssh root@12.34.55.66
```

**What to expect:**
```
The authenticity of host '12.34.55.66 (12.34.55.66)' can't be established.
ED25519 key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Type `yes` and press Enter.

Then enter your root password (you won't see anything as you type — that's normal).

**You should see:**
```
root@your-vps-hostname:~#
```

You are now inside your VPS. Congratulations! 🎉

---

## Step 3: Update Your VPS

Run these commands one at a time (copy, paste, press Enter, wait for it to finish):

```bash
sudo apt update
```

**Expected:** A lot of text ending with `Reading package lists... Done`

```bash
sudo apt upgrade -y
```

**Expected:** Lots of text ending with `done` or `complete`. This may take 2-5 minutes.

```bash
sudo apt install -y curl git ca-certificates gnupg lsb-release ufw fail2ban
```

**Expected:** Text ending with `done`.

---

## Step 4: Set Up Firewall (UFW)

Copy and paste these commands one at a time:

```bash
ufw default deny incoming
```

**Expected:** `Default incoming policy changed to 'deny'`

```bash
ufw default allow outgoing
```

**Expected:** `Default outgoing policy changed to 'allow'`

```bash
ufw allow OpenSSH
```

**Expected:** `Rule added`

```bash
ufw allow 80/tcp
```

**Expected:** `Rule added`

```bash
ufw allow 443/tcp
```

**Expected:** `Rule added`

```bash
ufw allow 25/tcp
```

**Expected:** `Rule added`

```bash
ufw allow 587# Postal Enhanced — Full Baby-Step Guide  
### From zero knowledge to a running mail server

This guide assumes **you have never used Postal, Docker, or a mail server before**. Every command is explained. Every expected result is shown. Every “what if something goes wrong” case is covered.

You will:

1. Understand what this software is  
2. Understand how this fork differs from official Postal  
3. Install it on a VPS  
4. Configure DNS  
5. Log in and send mail  
6. Use the new features (campaigns, batch API, SMTP AUTH, CLI)

---

# PART 1 — What is this? (Speak slowly)

## 1.1 What is Postal?

**Postal** is software that runs on **your own server** and sends (and receives) email for your websites/apps.

Think of:

| Product | Who owns it | You pay? |
|--------|-------------|----------|
| Gmail / Outlook | Google / Microsoft | free/paid for personal mail |
| SendGrid / Mailgun / Postmark | SaaS companies | **yes**, per email |
| **Postal** | **you** | **only your VPS bill** |

Postal is like owning your own mini SendGrid.

## 1.2 What is *this fork* (`officialmonsterz/postal`)?

| | Official Postal | This fork |
|--|-----------------|-----------|
| Who makes it | postalserver team | OfficialMonsterz (builds *on top of* official) |
| GitHub | github.com/postalserver/postal | github.com/officialmonsterz/postal |
| Can send one email via API? | Yes | Yes |
| Can send 500 emails in one API call? | No | **Yes (Batch API)** |
| Campaigns (newsletters/lists)? | No | **Yes** |
| Login to SendGrid/Amazon SES as a relay? | No | **Yes (SMTP AUTH)** |
| Ready-made HTML templates? | No | **Yes (4 templates)** |
| OpenAPI docs? | No | **Yes** |
| CLI bulk sender? | No | **Yes** |

**Simple idea:**  
Official Postal = “excellent mail delivery engine”  
This fork = “engine + campaign tool + bulk tools”

---

# PART 2 — Big picture of how mail gets out

```text
Your website / CLI / API
        |
        v
  Postal (this fork)
        |
        +--[direct]--> Recipient mail servers (Gmail, etc.)
        |
        +--[relay]--> SendGrid/SES (if you configured SMTP AUTH)
                      then --> recipients
```

**Recommendation:**  
If your VPS provider **blocks port 25**, you **must** use SMTP AUTH relay (SendGrid, etc.). Many cheap VPS block port 25.

---

# PART 3 — Things you need BEFORE installing

## 3.1 Checklist (buy/prepare these first)

| Item | Why | Example in your chats |
|------|-----|------------------------|
| Domain | Mail needs a real domain | `officialmonsterz.com` |
| VPS (Linux server) | Software lives here | IP `12.34.55.66` |
| Root SSH access | To install software | `ssh root@12.34.55.66` |
| DNS access (Namecheap) | Point domain to server | Namecheap Advanced DNS |
| Optional: SendGrid/SES key | If port 25 blocked | API key / SMTP password |

**Recommended VPS minimum**

| Spec | Minimum | Better |
|------|---------|--------|
| RAM | 4 GB | 8 GB |
| CPU | 2 cores | 4 cores |
| Disk | 40 GB SSD | 80 GB+ |
| OS | Ubuntu 22.04 or 24.04 | same |

**Avoid:** tiny 1GB VPS — Postal will be slow/crashy.

## 3.2 Skills you need

You only need to be able to:

1. Open a terminal  
2. Copy–paste commands  
3. Edit a text file when told  
4. Log into Namecheap DNS  

You do **not** need to know Ruby.

---

# PART 4 — DNS setup (do this FIRST)

DNS tells the internet: “email/website for this name lives at that IP.”

## 4.1 Decide your hostnames

Use this pattern (clear and professional):

| Purpose | Hostname | Points to |
|---------|----------|-----------|
| Web UI + API | `postal.officialmonsterz.com` | VPS IP `12.34.55.66` |
| SMTP hostname | `postal.officialmonsterz.com` | same |
| Tracking clicks/opens | `track.officialmonsterz.com` | CNAME → postal… |
| Return path / bounce | `rp.officialmonsterz.com` | VPS IP |
| MX (receiving mail) | `mx1.officialmonsterz.com` | VPS IP (optional day-1) |

**Recommendation:**  
For day 1, focus on **sending**. Receiving (MX) can wait.

## 4.2 Namecheap — baby steps

1. Log into Namecheap  
2. Domain List → **officialmonsterz.com** → **Manage**  
3. **Advanced DNS** tab  
4. Add records:

### A records

| Type | Host | Value | TTL |
|------|------|-------|-----|
| A Record | `postal` | `12.34.55.66` | Automatic |
| A Record | `rp` | `12.34.55.66` | Automatic |
| A Record | `mx1` | `12.34.55.66` | Automatic |

### CNAME

| Type | Host | Value | TTL |
|------|------|-------|-----|
| CNAME Record | `track` | `postal.officialmonsterz.com.` | Automatic |

Note the trailing dot on CNAME target only if Namecheap requires FQDN — if UI fails, try without the trailing dot: `postal.officialmonsterz.com`.

## 4.3 Wait and verify

From your laptop or any terminal:

```bash
dig +short postal.officialmonsterz.com A
```

**Expected output:**

```text
12.34.55.66
```

If empty:

- Wait 5–30 minutes (sometimes up to a few hours)  
- Check Host is `postal` not `postal.officialmonsterz.com`  
- Flush local DNS: try https://dnschecker.org  

**Do not continue install until this resolves correctly.**

---

# PART 5 — Connect to your VPS

## 5.1 SSH in

```bash
ssh root@12.34.55.66
```

**Expected:**

```text
root@your-server:~#
```

If connection refused:

- Check VPS is running  
- Check firewall allows SSH (port 22)  
- Confirm IP is correct  

## 5.2 Update the server

```bash
sudo apt update && apt upgrade -y
```

**Expected:** lots of package lines, ends with something like `0 upgraded` or a list of upgrades, back to prompt.

## 5.3 Install basic tools

```bash
sudo apt install -y curl git ca-certificates gnupg ufw fail2ban
```

**Expected:** packages install without fatal errors.

## 5.4 Firewall (important)

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 25/tcp
ufw allow 587/tcp
ufw --force enable
ufw status
```

**Expected output (similar):**

```text
Status: active

To                         Action      From
--                         ------      ----
OpenSSH                    ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
25/tcp                     ALLOW       Anywhere
587/tcp                    ALLOW       Anywhere
```

**Recommendation:**  
Always allow OpenSSH **before** enabling UFW, or you can lock yourself out.

---

# PART 6 — Install Docker

Postal’s supported install method uses Docker.

```bash
curl -fsSL https://get.docker.com | sh
systemctl enable --now docker
docker --version
docker compose version
```

**Expected:**

```text
Docker version 2x.x.x, build ...
Docker Compose version v2.x.x
```

If `docker` command not found → reboot and try again, or re-run the install script.

---

# PART 7 — Install official Postal installer tools

Official docs use a special `postal` command from their install repo.

## 7.1 Create folder structure

```bash
mkdir -p /opt/postal
```

## 7.2 Clone the install helpers

```bash
git clone https://github.com/postalserver/install /opt/postal/install
ln -s /opt/postal/install/bin/postal /usr/bin/postal
```

## 7.3 Check the command works

```bash
postal version
```

**Expected:** some version/help text, **not** “command not found”.

---

# PART 8 — Get THIS fork’s code (not only bare upstream)

Official Postal install pulls official images by default.  
**Your enhancements live in `officialmonsterz/postal`.**

## 8.1 Clone your fork for reference (and for custom files)

```bash
git clone https://github.com/officialmonsterz/postal.git /opt/postal/app-src
cd /opt/postal/app-src
git status
ls app/models/campaign.rb
ls script/postal-send
```

**Expected:**

- `campaign.rb` exists  
- `postal-send` exists  

If missing, your GitHub push of enhancements is incomplete — fix the repo first.

## 8.2 Reality check about Docker vs custom code

| Approach | Difficulty | Uses your campaign code? |
|----------|------------|---------------------------|
| Pure official `postal bootstrap` + official images | Easy | **No** unless you rebuild image from fork |
| Build Docker image **from your fork** | Medium | **Yes** |
| Bare-metal Rails run of fork | Hard | **Yes** |

**Recommendation (honest):**  
If you only ran official bootstrap without building from `officialmonsterz/postal`, you get **stock Postal**, not campaigns/batch/auth enhancements.

### Recommended path for *your* fork

Build a custom image from the fork and point Postal compose at it — **or** deploy using your repo’s Dockerfile if present.

Check:

```bash
ls /opt/postal/app-src/Dockerfile
ls /opt/postal/app-src/docker-compose*.yml 2>/dev/null
```

If Dockerfile exists:

```bash
cd /opt/postal/app-src
docker build -t officialmonsterz/postal:latest .
```

**Expected:** long build, ends with `Successfully tagged officialmonsterz/postal:latest`

Then in Postal’s compose/config, replace image name with `officialmonsterz/postal:latest`.

---

# PART 9 — Bootstrap Postal (official installer flow)

This is the same “Getting Started” flow you pasted, explained slowly.

## 9.1 Run bootstrap

```bash
postal bootstrap postal.officialmonsterz.com
```

Replace name with your real web hostname.

**What this does:**

Creates retryable starter files under `/opt/postal/config/`:

| File | Purpose |
|------|---------|
| `postal.yml` | Main config (DB passwords, hostnames, features) |
| `signing.key` | Cryptographic signing key (secret!) |
| `Caddyfile` | HTTPS reverse proxy config for Caddy |

**Expected:**

```text
# something like: configuration written to /opt/postal/config
```

Check files:

```bash
ls -la /opt/postal/config/
```

**Expected:**

```text
Caddyfile
postal.yml
signing.key
```

## 9.2 Edit `postal.yml` (critical)

```bash
nano /opt/postal/config/postal.yml
```

### Keys you MUST set carefully

#### Web / SMTP hostnames

```yaml
postal:
  web_hostname: postal.officialmonsterz.com
  web_protocol: https
  smtp_hostname: postal.officialmonsterz.com
```

#### Database passwords

Whatever bootstrap put for MariaDB — **you choose a strong password** and keep it consistent.

```yaml
main_db:
  host: 127.0.0.1   # or the docker service hostname your installer uses
  username: postal
  password: "USE_A_LONG_RANDOM_PASSWORD"
  database: postal

message_db:
  host: 127.0.0.1
  username: postal
  password: "SAME_PASSWORD_USUALLY"
```

**Important Docker note (from official docs):**  
Inside containers, paths often start with `/config` not `/opt/postal/config` because the host folder is mounted as `/config`.

#### DNS section

```yaml
dns:
  mx_records:
    - mx1.officialmonsterz.com
  return_path_domain: rp.officialmonsterz.com
  track_domain: track.officialmonsterz.com
  helo_hostname: postal.officialmonsterz.com
```

#### THIS FORK: SMTP AUTH relay + campaigns

If your image **includes the fork**:

```yaml
postal:
  campaigns_enabled: true
  smtp_relays:
    - "smtp://apikey:SG.YOUR_SENDGRID_KEY@smtp.sendgrid.net:587?ssl_mode=STARTTLS&auth_type=plain"
```

**ssl_mode spelling:** use `STARTTLS` (double T).  
**Not:** `STARTLS`.

#### Rails secret

If required:

```bash
openssl rand -hex 64
```

Paste into `rails.secret_key` if that key exists in your file.

Save file:

- nano: `Ctrl+O`, Enter, `Ctrl+X`

---

# PART 10 — Initialize database and create admin user

## 10.1 Initialize

```bash
postal initialize
```

**What happens:**  
Creates database tables (including campaign tables **if** your code/image has the migrations).

**Expected:**  
Commands finish with success, not stack traces about MySQL connection refused.

If MySQL connection fails:

- MariaDB container not up yet → run `postal start` components first per your install version, or start DB as docs say  
- Wrong password in `postal.yml`  
- Wrong host (`127.0.0.1` vs `mariadb` docker hostname)

## 10.2 Create first admin user

```bash
postal make-user
```

**Expected:** interactive prompts like:

```text
E-Mail Address: admin@officialmonsterz.com
First Name: Admin
Last Name: User
Password: ********
User created successfully
```

**Write these credentials down offline.**

---

# PART 11 — Start Postal

```bash
postal start
```

**What happens:** starts multiple Docker containers (web, SMTP, workers, etc.).

Check:

```bash
postal status
```

**Expected:** several containers **Up** / healthy.

Show Docker containers:

```bash
docker ps
```

**Expected:** lines with names like `postal-...`, status `Up`.

If something is `Restarting`:

```bash
docker logs NAME_OF_CONTAINER --tail 100
```

Common fixes:

- Bad DB password  
- Port 25 already used  
- Invalid YAML in `postal.yml` (indent error)

---

# PART 12 — Start Caddy (HTTPS for the website)

Official getting-started uses Caddy for SSL.

```bash
docker run -d \
  --name postal-caddy \
  --restart always \
  --network host \
  -v /opt/postal/config/Caddyfile:/etc/caddy/Caddyfile \
  -v /opt/postal/caddy-data:/data \
  caddy
```

**What this does:**

- Reads Caddyfile for `postal.officialmonsterz.com`  
- Gets a free Let’s Encrypt certificate  
- Proxies HTTPS to Postal web  

Check:

```bash
docker ps | grep caddy
docker logs postal-caddy --tail 50
```

**Expected logs:** certificate obtain success / serving HTTPS  
**Bad logs:** DNS not pointing yet, port 80/443 blocked, rate limit

### Open in browser

Visit:

```text
https://postal.officialmonsterz.com
```

**Expected:** Postal login page.  
Log in with user from `postal make-user`.

If browser shows SSL warnings or times out:

1. Confirm DNS A record  
2. Confirm UFW allows 80/443  
3. `docker logs postal-caddy`  
4. Confirm Postal web container is up  

---

# PART 13 — First configuration inside the web UI (baby steps)

## 13.1 Create an Organization

1. After login, create **Organization** (company name)  
2. Example: `OfficialMonsterz`

## 13.2 Create a Mail Server

1. Inside org → **Add mail server**  
2. Name example: `Main`  
3. Open it

## 13.3 Add a sending domain

1. Domains → Add `officialmonsterz.com` **or** a subdomain like `mail.officialmonsterz.com`  
2. Postal shows DNS records you must add (SPF, DKIM, return-path, tracking)

**Copy every record into Namecheap exactly as shown.**

## 13.4 Wait for green checks

Postal will show domain verification status.  
Wait until SPF/DKIM/return-path show OK (can take minutes after DNS update).

**Recommendation:**  
Use a subdomain dedicated to mail (`mail.officialmonsterz.com`) so you don’t break the root domain website DNS accidentally.

## 13.5 Create API credential

1. Mail server → **Credentials**  
2. Create **API** credential  
3. Copy the key — this is:

```text
X-Server-API-Key: pastethis...
```

Treat like a password.

---

# PART 14 — Send your first test email (proof it works)

From your laptop:

```bash
curl -sS -X POST "https://postal.officialmonsterz.com/api/v1/send/message" \
  -H "X-Server-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": ["your-personal-email@gmail.com"],
    "from": "test@YOUR_VERIFIED_DOMAIN",
    "subject": "Postal first test",
    "plain_body": "If you can read this, Postal works."
  }'
```

**Expected JSON (similar):**

```json
{
  "status": "success",
  "time": 0.12,
  "data": {
    "message_id": "...",
    "messages": {
      "your-personal-email@gmail.com": { "id": 1, "token": "..." }
    }
  }
}
```

Then check:

1. Gmail inbox/spam  
2. Postal UI → Messages → Outgoing  

**If status error `UnauthenticatedFromAddress`:**  
`from` domain is not verified on that postal mail server.

**If message stuck / soft fail:**  

- Port 25 blocked → add SMTP relay AUTH  
- Reputation/IP blocked → use relay  
- DNS incomplete  

---

# PART 15 — New features, explained like a human

## 15.1 SMTP AUTH (login to external relays)

**Problem:** many VPS cannot send mail directly.  

**Solution:** Postal opens SMTP to SendGrid and logs in.

In `postal.yml`:

```yaml
postal:
  smtp_relays:
    - "smtp://apikey:SG.XXXX@smtp.sendgrid.net:587?ssl_mode=STARTTLS&auth_type=plain"
```

Then restart:

```bash
postal stop
postal start
```

**How to know it works:**  
Message still sends, but delivery path goes through SendGrid; logs mention AUTH or the relay host.

## 15.2 Batch API (send many emails in one request)

Instead of 500 HTTP calls:

```bash
curl -sS -X POST "https://postal.officialmonsterz.com/api/v1/send/batch" \
  -H "X-Server-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {
        "to": ["a@example.com"],
        "from": "news@YOUR_DOMAIN",
        "subject": "Hi A",
        "plain_body": "Hello A"
      },
      {
        "to": ["b@example.com"],
        "from": "news@YOUR_DOMAIN",
        "subject": "Hi B",
        "plain_body": "Hello B"
      }
    ]
  }'
```

**Expected:** `"status":"success"` and `sent`/`failed` counts.

**Rule:** max **500** messages per batch.

## 15.3 Campaigns (list + template + send over time)

Think: create a “job”, add recipients, launch — job worker sends in batches of 50.

### Create campaign

```bash
curl -sS -X POST "https://postal.officialmonsterz.com/api/v1/campaigns" \
  -H "X-Server-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Welcome Wave",
    "subject_a": "Welcome to OfficialMonsterz",
    "subject_b": "You are invited — OfficialMonsterz",
    "sender_email": "hello@YOUR_DOMAIN",
    "template_name": "notification",
    "a_split_percent": 50,
    "recipients": ["you@gmail.com"]
  }'
```

**Expected:** JSON with campaign id and status `draft`.

### Launch

```bash
curl -sS -X POST "https://postal.officialmonsterz.com/api/v1/campaigns/1/launch" \
  -H "X-Server-API-Key: YOUR_API_KEY"
```

**Expected:** status `running`.

### Stats

```bash
curl -sS "https://postal.officialmonsterz.com/api/v1/campaigns/1/stats" \
  -H "X-Server-API-Key: YOUR_API_KEY"
```

**A/B testing meaning:**  
50% get `subject_a`, 50% get `subject_b` (by index). You later compare opens.

## 15.4 Templates (password_reset, docusign, payroll, notification)

These are HTML email skins. Campaign job renders them with variables (name, links, company).  
They are **not** automatically “phishing tools”; they’re HTML layouts. You must use them only for **authorized** mail.

## 15.5 OpenAPI docs

```bash
curl -sS "https://postal.officialmonsterz.com/api/v1/openapi.json" | head
```

**Expected:** JSON starting with `"openapi":"3.0.3"`.  
Import into Postman: Import → Link/File.

## 15.6 CLI `postal-send`

On server:

```bash
chmod +x /opt/postal/app-src/script/postal-send
/opt/postal/app-src/script/postal-send --help
```

**Expected:** help text with options.

Dry run:

```bash
/opt/postal/app-src/script/postal-send \
  --host postal.officialmonsterz.com \
  --key YOUR_API_KEY \
  --to you@gmail.com \
  --from hello@YOUR_DOMAIN \
  --subject "CLI test" \
  --plain-body "Hello" \
  --dry-run
```

**Expected:** prints message preview, **does not send**.

Real send: remove `--dry-run`.

## 15.7 Webhook exponential backoff

If your app’s webhook URL is down, Postal retries:

1 min → 2 → 4 → 8 → 16 → 32 → 64 min → stop  

Better than fixed short retries that spam a broken server.

## 15.8 Send limits

If your mail server hourly cap is hit, API returns error **SendLimitExceeded** and **stops** (doesn’t half-send and crash).

---

# PART 16 — Verification checklist (do all of these)

| # | Test | Pass looks like |
|---|------|-----------------|
| 1 | Browser login | Dashboard loads over HTTPS |
| 2 | Domain DNS in Postal | Green/OK marks |
| 3 | Single API send | `status: success` + email arrives |
| 4 | Batch send | two messages accepted |
| 5 | OpenAPI | JSON downloads |
| 6 | Campaign create/launch | stats show sent increasing |
| 7 | CLI dry-run | prints JSON preview |
| 8 | (Optional) SMTP AUTH | works when port 25 blocked |
| 9 | `postal status` | containers Up |

---

# PART 17 — Common problems and exact fixes

## Problem: `postal: command not found`

```bash
ln -sf /opt/postal/install/bin/postal /usr/bin/postal
hash -r
postal version
```

## Problem: certificate fails / HTTPS doesn’t work

- DNS A record wrong  
- Ports 80/443 closed at VPS cloud firewall (DigitalOcean/Hetzner UI firewall separate from UFW!)  
- Another process bound to 80  

Check cloud firewall panel **and** UFW.

## Problem: emails not leaving server

1. Check message status in Postal UI  
2. Test if port 25 outbound is open:

```bash
timeout 5 bash -c 'echo >/dev/tcp/gmail-smtp-in.l.google.com/25' && echo OPEN || echo BLOCKED
```

If **BLOCKED** → use SMTP AUTH relay immediately.

## Problem: “UnauthenticatedFromAddress”

`from` address domain not added/verified on that mail server / wrong API credential for that server.

## Problem: campaigns 404 / constant error

You are running **official Docker image** without your fork code.  
Build/deploy image from `officialmonsterz/postal` and re-run migrations.

```bash
# after image with fork is running
postal initialize
# or migration command your stack uses
```

## Problem: DB connection errors

- Typo password  
- DB container not running  
- host should be docker service name not always `127.0.0.1` (depends on network mode)

## Problem: Caddy container name already exists

```bash
docker rm -f postal-caddy
# then run docker run ... again
```

## Problem: SendGrid auth fails

- API key wrong  
- password special characters need URL encoding in the relay URI  
- must use `ssl_mode=STARTTLS` and port `587`

---

# PART 18 — Daily operations (simple)

| Task | Command / action |
|------|------------------|
| See status | `postal status` |
| Restart all | `postal stop` then `postal start` |
| View logs | `docker logs <container> --tail 200` |
| Start web HTTPS | keep `postal-caddy` running |
| Update fork | `cd /opt/postal/app-src && git pull` then rebuild image + restart |
| Backup | snapshot VPS + dump MySQL + copy `/opt/postal/config` |

**Backup recommendation (minimum weekly):**

```bash
tar -czf postal-config-$(date +%F).tgz /opt/postal/config
# plus database dump depending on your MariaDB layout
```

---

# PART 19 — Security recommendations (don’t skip)

1. **Never commit** real `postal.yml` passwords or API keys to GitHub  
2. Use long passwords for DB and admin user  
3. Keep UFW + cloud firewall on  
4. Fail2ban is useful against SSH brute force  
5. Only give API keys to trusted apps  
6. Use authenticated domains only for sending  
7. For bulk mail: follow laws (consent, unsubscribe) and host/provider anti-abuse rules  
8. Don’t open MySQL to the public internet  

---

# PART 20 — Credits & links (who made what)

| Role | Who | Contact |
|------|-----|---------|
| Enhanced fork | **OfficialMonsterz** | GitHub [officialmonsterz](https://github.com/officialmonsterz), email shapads@tutamail.com, Telegram [t.me/officialmonsterz](https://t.me/officialmonsterz) |
| Original Postal | postalserver team | [github.com/postalserver/postal](https://github.com/postalserver/postal) |
| Official docs | Postal docs | [docs.postalserver.io](https://docs.postalserver.io) |
| Getting started | Official guide | [docs.postalserver.io/getting-started](https://docs.postalserver.io/getting-started) |

Repo: [https://github.com/officialmonsterz/postal](https://github.com/officialmonsterz/postal)

---

# PART 21 — One-page “order of battle” (do in this order)

```text
1. Buy/rent Ubuntu VPS (4GB+), note IP
2. Point postal.yourdomain.com A record to IP  (wait until dig works)
3. SSH as root, apt update, install Docker + ufw
4. Install postal helper from postalserver/install
5. Clone officialmonsterz/postal and BUILD custom image if you want new features
6. postal bootstrap postal.yourdomain.com
7. Edit /opt/postal/config/postal.yml (passwords, DNS, optional smtp_relays)
8. postal initialize
9. postal make-user
10. postal start
11. Start Caddy container
12. Login in browser → create org → server → domain DNS → API key
13. curl test send one message
14. Try batch / campaign / CLI (if fork image is live)
15. Backup config + DB
```

---

# PART 22 — About the README you already have

Your long **README.md** is already good for GitHub visitors. Keep it.  

Use **this message** as the “human install manual.”  
Optionally save this whole answer as:

- `GETTING_STARTED_LAYMAN.md`  

on GitHub next to `README.md` and `DEPLOYMENT.md`.

**Small README honesty tweaks (recommended so you don’t over-promise):**

1. Remove emoji claims of “production-ready with zero bugs” if not battle-tested yet.  
2. Campaign web UI routes may be API-first — don’t imply a full Mailchimp-like GUI unless you built UI pages.  
3. Placeholders like `via.placeholder.com` images should be replaced with real screenshots.  
4. Official core feature list is correct; new features only exist if containers run **this fork’s code**.

---

# PART 23 — What success looks like (final picture)

When everything is right, you have:

1. `https://postal.officialmonsterz.com` login works with green padlock  
2. Domain shows verified DNS in Postal  
3. API send returns `"status":"success"`  
4. Email appears in inbox (or spam on first cold IP — normal)  
5. `postal status` shows healthy containers  
6. If fork deployed: `/api/v1/openapi.json` and `/api/v1/campaigns` work  

---
