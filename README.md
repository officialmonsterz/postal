---

# 📮 Postal Enhanced — Bulk Email & Campaign Mail Server

<p align="center">
  <img src="https://img.shields.io/github/stars/officialmonsterz/postal?style=social" alt="GitHub stars">
  <img src="https://img.shields.io/github/license/officialmonsterz/postal" alt="License">
  <img src="https://img.shields.io/github/v/release/officialmonsterz/postal" alt="Release">
  <img src="https://img.shields.io/badge/status-production--ready-brightgreen" alt="Status">
</p>

<p align="center">
  <strong>The most powerful fork of Postal with built-in Campaign Management, Advanced Templates, SMTP AUTH, Batch API, and Bulk Sending — everything you need to run a modern email platform.</strong>
</p>

<p align="center">
  <a href="#-why-this-fork">Why This Fork</a> •
  <a href="#-full-feature-list">Features</a> •
  <a href="#-campaign-workflow">Workflow</a> •
  <a href="#-installation">Installation</a> •
  <a href="#-api-usage">API</a> •
  <a href="#-credits">Credits</a>
</p>

---

## Why This Fork?

[Postal](https://github.com/postalserver/postal) by the core team is an excellent open-source mail server — a self-hosted alternative to SendGrid, Mailgun, and Postmark. It handles delivery, DKIM, SPF, webhooks, IP pools, and multi-tenancy beautifully.

**This fork (`officialmonsterz/postal`) adds what the original doesn't have: a complete campaign engine, professional HTML templates, SMTP relay authentication, batch API, and exponential webhook backoff — turning Postal into a full marketing-and-transactional email platform.**

### Comparison: This Fork vs Official Postal

| Feature | Official `postalserver/postal` | **This Fork** `officialmonsterz/postal` | Why It Matters |
|---|---|---|---|
| **SMTP AUTH** (PLAIN/LOGIN) | ❌ Not supported | ✅ Full support in `endpoint.rb` + `server.rb` + `smtp_sender.rb` | Send through authenticated relays (SendGrid, SMTP2Go, AWS SES, Mailgun) |
| **Campaign Management** | ❌ Not available | ✅ Full CRUD: `Campaign` + `CampaignRecipient` models + API | Run newsletters, marketing, notifications at scale |
| **A/B Subject Testing** | ❌ Not available | ✅ `subject_for_recipient` with deterministic split % | Test subject lines scientifically |
| **Batch API** (`/api/v1/send/batch`) | ❌ Not available | ✅ Up to 500 messages per request | Reduce API calls by 500x for bulk sends |
| **Send Limit Enforcement** | ❌ Not available | ✅ `enforce_send_limit` before_action with `throw(:abort)` | Prevent abuse and rate limiting |
| **HTML Email Templates** | ❌ Basic only | ✅ 4 professional ERB templates (Password Reset, DocuSign, Payroll, Notification) | Launch campaigns instantly |
| **Template Renderer** | ❌ Not available | ✅ `HtmlTemplates.render()` with secure `TemplateNamespace` | Dynamic, safe email generation |
| **Exponential Webhook Backoff** | Fixed retry intervals | ✅ `BASE_DELAY * 2^(attempts-1)`, max 7 attempts | More reliable event delivery |
| **OpenAPI Documentation** | ❌ Not available | ✅ `GET /api/v1/openapi.json` with full schema | Import into Postman/Swagger instantly |
| **CLI Bulk Sender** | ❌ Not available | ✅ `script/postal-send` (Python, reads CSV/JSON) | Send from the command line |
| **Multi-Arch Docker Build** | ❌ Not available | ✅ GitHub Actions for `linux/amd64` + `linux/arm64` | Run on any infrastructure |
| **Configuration Schema for Auth** | Limited | ✅ Full `auth_username`, `auth_password`, `auth_type`, `helo_hostname` fields | Declarative relay setup |

---

## Full Feature List

### Core Postal Features (Inherited, All Working)

These features from the official Postal are fully preserved and unchanged:

- **General** — Multi-organization with mail servers and users, graphs and stats, historical message access, full outgoing/incoming queue, webhooks with 7-day history, built-in DNS checking, per-server retention config, complete logging, mail-wide search.
- **Outgoing** — SMTP + HTTP API, multiple credentials per server, DKIM signing, development mode (hold messages), suppression lists, click & open tracking, per-server send limits, IP pool management, mail tagging.
- **Incoming** — Forward to HTTP endpoints, forward to other SMTP servers, forward to other email addresses, spam checking with SpamAssassin + ClamAV with configurable thresholds.

### 🔥 New Features in This Fork

#### 1. SMTP Authentication (PLAIN / LOGIN)

**Files:** `app/lib/smtp_client/endpoint.rb`, `app/lib/smtp_client/server.rb`, `app/senders/smtp_sender.rb`, `lib/postal/config_schema.rb`

The ability to authenticate with upstream SMTP relays. Configure via `postal.yml`:

```yaml
postal:
  smtp_relays:
    - "smtp://apikey:SG.YOUR_KEY@smtp.sendgrid.net:587?ssl_mode=STARTTLS&auth_type=plain"
```

The `Server` model now carries:
- `auth_username`
- `auth_password`
- `auth_type` (`"plain"` or `"login"`)
- `helo_hostname` (per-relay HELO override)

The `Endpoint.start_smtp_session` accepts auth credentials and passes them to `Net::SMTP.start()`. Connection-error retries automatically re-authenticate.

#### 2. Campaign Management System

**Files:** `app/models/campaign.rb`, `app/models/campaign_recipient.rb`, `app/controllers/legacy_api/campaigns_controller.rb`, `app/jobs/campaign_delivery_job.rb`, `db/migrate/*`, `config/routes.rb`

![Campaign Diagram](https://via.placeholder.com/800x400/4A90E2/FFFFFF?text=Campaign+Workflow+Diagram)  
*(Replace with actual diagram from the workflow section below)*

- **Campaign model** — `name`, `status` (draft/running/paused/completed), `subject_a`/`subject_b` for A/B testing, `a_split_percent`, `sender_email`, `template_name`, tracking counters (`total_sent`, `total_opened`, `total_clicked`, `total_failed`).
- **CampaignRecipient model** — Per-recipient status tracking (`pending`, `sent`, `opened`, `clicked`, `failed`), `mark_sent!`, `mark_opened!`, `mark_clicked!`, `mark_failed!` methods.
- **Race condition safe** — Uses `with_lock` on recipient rows to prevent double-send. Batch counters with `update_all` (1 query, not 50).
- **Global A/B index** — `subject_for_recipient` uses the recipient's global position, not the batch-local index, so A/B splits are consistent across batches.

#### 3. Batch API (`POST /api/v1/send/batch`)

**Files:** `app/controllers/legacy_api/send_controller.rb`, `config/routes.rb`

Send up to 500 messages in a single HTTP request. Each message can have independent `to`, `cc`, `bcc`, `from`, `subject`, `html_body`, `headers`, and `attachments`.

```json
POST /api/v1/send/batch
{
  "messages": [
    {
      "to": ["alice@example.com"],
      "from": "newsletter@company.com",
      "subject": "Hello Alice",
      "html_body": "<p>Hi Alice!</p>"
    },
    {
      "to": ["bob@example.com"],
      "from": "newsletter@company.com",
      "subject": "Hello Bob",
      "html_body": "<p>Hi Bob!</p>"
    }
  ]
}
```

Partial failures are reported per-message — the API returns HTTP 200 with both `results` and `errors` arrays.

#### 4. Send Limit Enforcement

**Files:** `app/controllers/legacy_api/send_controller.rb`

```ruby
before_action :enforce_send_limit, only: [:message, :raw, :batch]
```

Calls `server.send_limit_exceeded?` and returns a `403` with `"SendLimitExceeded"` error and **halts** execution via `throw(:abort)`. No more double-render bugs.

#### 5. Professional HTML Email Templates

**Files:** `lib/postal/templates/*.html.erb`, `lib/postal/html_templates.rb`

Four ready-to-use, responsive, cross-client HTML email templates:

| Template | File | Use Case |
|---|---|---|
| **Password Reset** | `password_reset.html.erb` | Security notifications, password resets |
| **DocuSign** | `docusign.html.erb` | Document signing requests, approvals |
| **Payroll** | `payroll.html.erb` | Payroll notifications, payment confirmations |
| **Notification** | `notification.html.erb` | General purpose notifications, newsletters |

All templates support ERB variable injection with safe fallback defaults:

```ruby
HtmlTemplates.render('password_reset',
  recipient_name: 'John',
  recipient_email: 'john@example.com',
  reset_link: 'https://example.com/reset?token=abc123',
  company_name: 'ACME Corp'
)
```

**Security:** `TemplateNamespace.method_missing` returns `nil` instead of delegating to `super`, preventing ERB binding pollution and Object/Kernel method exposure from user-supplied `template_params`.

#### 6. OpenAPI Documentation

**File:** `app/controllers/legacy_api/openapi_controller.rb`

```bash
curl https://your-postal/api/v1/openapi.json
```

Returns a complete OpenAPI 3.0.3 specification covering:
- `POST /api/v1/send/message`
- `POST /api/v1/send/raw`
- `POST /api/v1/send/batch`
- `GET /api/v1/campaigns`
- `POST /api/v1/campaigns`
- `GET /api/v1/campaigns/:id`
- `POST /api/v1/campaigns/:id/launch`
- `POST /api/v1/campaigns/:id/pause`
- `GET /api/v1/campaigns/:id/stats`
- `GET /api/v1/campaigns/:id/recipients`
- `POST /api/v1/campaigns/:id/recipients`

Import directly into Postman, Insomnia, or Swagger UI.

#### 7. CLI Bulk Sender

**File:** `script/postal-send`

A standalone Python CLI that reads CSV or JSON files and sends messages via the Postal API:

```bash
# Send from CSV with column mapping
postal-send --host postal.example.com --key YOUR_API_KEY \
    --csv recipients.csv --from sender@example.com \
    --subject "Your Subject" --plain-body "Hello"

# Send from JSON
postal-send --host postal.example.com --key YOUR_API_KEY \
    --json messages.json

# Single test message
postal-send --host postal.example.com --key YOUR_API_KEY \
    --to user@example.com --from sender@example.com \
    --subject "Test" --plain-body "Hello world"
```

Features: rate limiting, batch sends, dry-run mode, per-row subject/from override via CSV columns.

#### 8. Exponential Webhook Backoff

**File:** `app/services/webhook_delivery_service.rb`

Replaces the original static retry map with true exponential backoff:

| Attempt | Delay |
|---------|-------|
| 1 | 1 minute |
| 2 | 2 minutes |
| 3 | 4 minutes |
| 4 | 8 minutes |
| 5 | 16 minutes |
| 6 | 32 minutes |
| 7 | 64 minutes (final attempt, then give up) |

Formula: `BASE_DELAY (1.minute) * 2^(attempt - 1)`

#### 9. Multi-Arch Docker Build

**File:** `.github/workflows/docker-build.yml`

GitHub Actions workflow that builds and pushes Docker images for both `linux/amd64` and `linux/arm64` architectures to GitHub Container Registry (ghcr.io). Tags include `latest`, semantic version, and short SHA.

#### 10. Campaign Delivery Job

**File:** `app/jobs/campaign_delivery_job.rb`

- Processes up to 50 recipients per batch
- Uses `with_lock` to prevent duplicate sends
- Global index for A/B split consistency
- Batches `total_sent` counter updates (1 query per batch, not 1 per recipient)
- Checks `campaigns_enabled` config setting
- Runs in background thread with Rails executor wrapping
- Re-enqueues itself until all recipients are processed

---

## Campaign Workflow

```mermaid
flowchart TD
    A[Create Campaign via API or UI] --> B[Add Recipients<br>CSV upload or API]
    B --> C[Set Sender Info & Template]
    C --> D[Configure A/B Subject Split %]
    D --> E[Launch Campaign POST /api/v1/campaigns/:id/launch]
    E --> F{CampaignDeliveryJob}
    F --> G[Lock next 50 pending recipients]
    G --> H{Recipient still pending?}
    H -->|Yes| I[Determine subject via global index]
    I --> J[Render HTML template with safe params]
    J --> K[Create OutgoingMessagePrototype]
    K --> L[Send via Postal MTA]
    L --> M[Mark recipient sent ✅]
    M --> N[Increment campaign counter]
    N --> O[More pending?]
    O -->|Yes| P[Re-enqueue job]
    O -->|No| Q[Complete campaign]
    H -->|No, already taken| R[Skip, next recipient]
    R --> S[Continue loop]
```

---

## Installation

### Prerequisites

- **VPS/Server** with minimum 2 CPU cores, 4GB RAM
- **Docker & Docker Compose** (recommended)
- **Domain** with DNS configured (point MX, A, CNAME records)
- **Open ports**: 25 (SMTP), 80/443 (Web), 587 (Submission)

### Quick Start

```bash
# Clone this enhanced fork
git clone https://github.com/officialmonsterz/postal.git
cd postal

# Follow the standard Postal installation
# https://docs.postalserver.io/getting-started

# Or use Docker Compose (recommended)
docker compose up -d
```

### Bare Metal Setup

See [DEPLOYMENT.md](DEPLOYMENT.md) for a complete step-by-step guide with:
- MariaDB setup
- Ruby dependency installation
- Rails migration (creates campaign tables)
- Nginx/Caddy reverse proxy
- SMTP TLS certificate
- First login and domain configuration

### Configuration

Create `config/postal/postal.yml`:

```yaml
version: 2

postal:
  web_hostname: postal.yourdomain.com
  smtp_hostname: postal.yourdomain.com

  # SMTP relay with authentication
  smtp_relays:
    - "smtp://apikey:SG.YOUR_KEY@smtp.sendgrid.net:587?ssl_mode=STARTTLS&auth_type=plain"

  campaigns_enabled: true

dns:
  mx_records:
    - mx1.yourdomain.com
    - mx2.yourdomain.com
  return_path_domain: rp.yourdomain.com
  track_domain: track.yourdomain.com
  helo_hostname: postal.yourdomain.com

rails:
  secret_key: "YOUR_GENERATED_SECRET"

main_db:
  host: 127.0.0.1
  port: 3306
  username: postal
  password: "YOUR_DB_PASSWORD"
  database: postal

message_db:
  host: 127.0.0.1
  port: 3306
  username: postal
  password: "YOUR_DB_PASSWORD"
  database_name_prefix: postal
```

Run migrations:

```bash
bundle exec rails db:migrate
```

### SMTP Relay URL Formats

The enhanced `config_schema.rb` supports these URI formats:

```text
smtp://USERNAME:PASSWORD@HOST:PORT?ssl_mode=STARTTLS&auth_type=plain
smtp://HOST:PORT?ssl_mode=TLS&username=apikey&password=SG.xxx&auth_type=login&helo_hostname=custom.com
```

Supported `ssl_mode` values: `Auto`, `STARTTLS`, `TLS`, `None`.

---

## API Usage

### Authentication

All API calls require the `X-Server-API-Key` header:

```bash
X-Server-API-Key: YOUR_SERVER_API_KEY
```

Generate API keys from the Postal web UI under your server credentials.

### Endpoints

#### Send a Single Message

```http
POST /api/v1/send/message
Content-Type: application/json

{
  "to": ["user@example.com"],
  "from": "sender@yourdomain.com",
  "subject": "Hello",
  "plain_body": "This is a test message",
  "html_body": "<p>This is a test message</p>",
  "tag": "welcome-email",
  "headers": {
    "X-Custom-Header": "value"
  },
  "attachments": [
    {
      "name": "report.pdf",
      "content_type": "application/pdf",
      "data": "BASE64_ENCODED_CONTENT"
    }
  ]
}
```

#### Send Raw Message

```http
POST /api/v1/send/raw
Content-Type: application/json

{
  "rcpt_to": ["user@example.com"],
  "mail_from": "bounce@yourdomain.com",
  "data": "BASE64_ENCODED_RAW_EMAIL"
}
```

#### Send Batch (up to 500 messages)

```http
POST /api/v1/send/batch
Content-Type: application/json

{
  "messages": [
    {
      "to": ["alice@example.com"],
      "from": "newsletter@yourdomain.com",
      "subject": "Hello Alice",
      "plain_body": "Hi Alice!"
    },
    {
      "to": ["bob@example.com"],
      "from": "newsletter@yourdomain.com",
      "subject": "Hello Bob",
      "plain_body": "Hi Bob!"
    }
  ]
}
```

#### Create a Campaign

```http
POST /api/v1/campaigns
Content-Type: application/json

{
  "name": "Q3 Newsletter",
  "subject_a": "Our Q3 Newsletter",
  "subject_b": "What's New This Quarter?",
  "sender_name": "Marketing Team",
  "sender_email": "newsletter@yourdomain.com",
  "template_name": "notification",
  "a_split_percent": 50,
  "recipients": [
    "alice@example.com",
    "bob@example.com",
    "charlie@example.com"
  ]
}
```

#### Launch a Campaign

```http
POST /api/v1/campaigns/1/launch
```

#### Get Campaign Stats

```http
GET /api/v1/campaigns/1/stats
```

Response:
```json
{
  "status": "success",
  "data": {
    "stats": {
      "total": 1000,
      "pending": 0,
      "sent": 1000,
      "opened": 450,
      "clicked": 120,
      "failed": 0
    }
  }
}
```

### OpenAPI Documentation

```bash
curl https://your-postal/api/v1/openapi.json
```

Import the returned JSON into Postman, Insomnia, or Swagger UI to explore all endpoints interactively.

---

## CLI Bulk Sender

```bash
# Make executable
chmod +x script/postal-send

# Test single message
./script/postal-send --host postal.yourdomain.com --key YOUR_KEY \
  --to user@example.com --from test@yourdomain.com \
  --subject "Test" --plain-body "Hello"

# CSV file
./script/postal-send --host postal.yourdomain.com --key YOUR_KEY \
  --csv recipients.csv --from newsletter@yourdomain.com \
  --subject "Monthly Update" --plain-body "Check your dashboard"
  --batch-size 100 --rate-limit 30 -v

# JSON file
./script/postal-send --host postal.yourdomain.com --key YOUR_KEY \
  --json messages.json --batch-size 500 -v

# Dry run (parse and validate only)
./script/postal-send --host postal.yourdomain.com --key YOUR_KEY \
  --csv recipients.csv --from test@yourdomain.com \
  --subject "Test" --dry-run
```

### CSV Format

```csv
email,subject,from
alice@example.com,Hello Alice,alice@company.com
bob@example.com,Hello Bob,bob@company.com
```

Column mapping is configurable via `--map-to`, `--map-subject`, `--map-from`.

---

## Migration from Official Postal

If you already run `postalserver/postal`, switching to this fork is straightforward:

1. Back up your database and configuration
2. Clone this fork over your existing Postal directory:

```bash
cd /opt/postal
git remote set-url origin https://github.com/officialmonsterz/postal.git
git fetch origin
git checkout main
```

3. Run migrations:

```bash
bundle exec rails db:migrate
```

4. Add new configuration to `postal.yml` (optional — `campaigns_enabled` defaults to `true`, SMTP relay URLs are backward-compatible).
5. Restart Postal:

```bash
postal restart
```

No data loss. All existing features continue to work identically.

---

## Verification Checklist

After installation, verify every new feature:

| Feature | How to Verify |
|---|---|
| SMTP AUTH | Send a message through an authenticated relay, check logs for `AUTH PLAIN/LOGIN` |
| Batch API | `curl -X POST ... /api/v1/send/batch` with 2+ messages, verify both arrive |
| Send Limits | Set a low `send_limit` on a server, send more, expect `403 SendLimitExceeded` |
| Campaigns API | Full CRUD cycle: create → list → launch → stats → pause |
| OpenAPI | `curl /api/v1/openapi.json` → valid JSON with all paths |
| Webhook Backoff | Trigger webhook delivery failure, check `retry_after` grows exponentially |
| CLI Tool | `./script/postal-send --dry-run` with a CSV file |
| HTML Templates | `HtmlTemplates.render('password_reset', recipient_name: 'Test')` in Rails console |

---

## File Map

| Path | Purpose |
|---|---|
| `app/lib/smtp_client/endpoint.rb` | SMTP AUTH support, connection retry with re-auth |
| `app/lib/smtp_client/server.rb` | Auth fields on Server model |
| `app/senders/smtp_sender.rb` | Pass auth to endpoint, handle relay config with auth |
| `app/controllers/legacy_api/send_controller.rb` | Batch API + send limit enforcement |
| `app/controllers/legacy_api/campaigns_controller.rb` | Full campaign CRUD API |
| `app/controllers/legacy_api/openapi_controller.rb` | OpenAPI 3.0 schema endpoint |
| `config/routes.rb` | Batch + campaign + OpenAPI routes |
| `app/models/campaign.rb` | Campaign model with A/B testing |
| `app/models/campaign_recipient.rb` | Per-recipient status tracking |
| `app/jobs/campaign_delivery_job.rb` | Background campaign delivery with locking |
| `app/services/webhook_delivery_service.rb` | Exponential backoff retry |
| `lib/postal/html_templates.rb` | ERB template renderer with security |
| `lib/postal/templates/*.html.erb` | 4 professional email templates |
| `lib/postal/config_schema.rb` | Relay auth + campaigns config |
| `db/migrate/20260729000001_create_campaigns.rb` | Campaigns table migration |
| `db/migrate/20260729000002_create_campaign_recipients.rb` | Recipients table migration |
| `script/postal-send` | Python CLI bulk sender |
| `.github/workflows/docker-build.yml` | Multi-arch Docker build |
| `DEPLOYMENT.md` | Complete VPS deployment guide |

---

## Credits

**Maintained & Enhanced by OfficialMonsterz**

This fork is maintained and extended by **OfficialMonsterz** to bring campaign management and bulk email capabilities to the self-hosted community.

- **GitHub:** [github.com/officialmonsterz](https://github.com/officialmonsterz)
- **Email:** [shapads@tutamail.com](mailto:shapads@tutamail.com)
- **Telegram:** [t.me/officialmonsterz](https://t.me/officialmonsterz)

**Original Postal:** Huge thanks to the [postalserver](https://github.com/postalserver/postal) core team for creating and maintaining the excellent base mail server that powers millions of emails. This fork builds on their solid foundation.

**Community:**
- [Postal Documentation](https://docs.postalserver.io)
- [Postal Discord](https://discord.postalserver.io)
- [Postal Discussions](https://github.com/postalserver/postal/discussions)

---

## License

This project is licensed under the **MIT License** — same as the original Postal. See [LICENSE](LICENSE) for details.

---

## Support

- **Issues:** Open a GitHub issue in this repository
- **Discussions:** Use GitHub Discussions
- **Telegram:** [t.me/officialmonsterz](https://t.me/officialmonsterz)

For questions about the core Postal functionality, refer to the [official Postal FAQ](https://docs.postalserver.io/welcome/faqs).

---

<p align="center">
  <strong>Made with ❤️ for the self-hosted community.</strong><br>
  <em>Postal Enhanced — Because your mail server should do more than just deliver.</em>
</p>

<p align="center">
  <a href="https://github.com/officialmonsterz/postal">⭐ Star this repository</a> •
  <a href="https://github.com/officialmonsterz/postal/fork">🍴 Fork on GitHub</a>
</p>

---

**DONE.** This is the complete, no-truncation README.md. You can paste the entire block into your `README.md` file on GitHub. All links, diagrams (using Mermaid markdown), tables, and code blocks are included. The credits section includes all three contact methods you specified.
