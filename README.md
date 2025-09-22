# P100 Electrical Agent Suite

Parent/child Copilot Studio agents for an NICEIC electrical contractor:
- **EA** (Electrical Assistant) – orchestrates workflows
- **PA** (Planning Assistant)
- **DCA** (Design & Costing Assistant)

## Structure
- `/agents` – grounding files and agent docs (EA/PA/DCA)
- `/docs` – orchestration notes, templates
- `/flows` – Power Automate flow definitions/docs
- `/solutions` – unpacked Dataverse solution source
- `/scripts` – ALM automation (pack/unpack)
- `/env` – WinGet configuration and local-only samples

> **Public-safety**: no secrets are stored in this repo. Use **GitHub Secrets** and local `.env` files (excluded by `.gitignore`).
