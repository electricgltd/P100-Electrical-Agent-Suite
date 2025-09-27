# P100 Electrical Agent Suite

Parent/child Copilot Studio agents for an NICEIC electrical contractor:
- **EA** (Electrical Assistant) – orchestrates workflows
- **PA** (Planning Assistant)
- **DCA** (Design & Costing Assistant)

## Structure
- `/agents` – grounding files and agent docs (EA/PA/DCA)
- `/docs` – orchestration notes, templates
- `/flows` – Power Automate flow definitions/docs
- `/grounding-files` – Copilot Space context pack and operational documentation
- `/solutions` – unpacked Dataverse solution source
- `/scripts` – ALM automation (pack/unpack)
- `/env` – WinGet configuration and local-only samples

> **Public-safety**: no secrets are stored in this repo. Use **GitHub Secrets** and local `.env` files (excluded by `.gitignore`).

## Local Git GUI recommendation

If you prefer a powerful desktop GUI for repository operations, GitKraken is a good option — it provides an intuitive commit graph, interactive rebases, conflict resolution UI, and easy remote integrations. For in-container development and PR workflows we recommend using VS Code with the GitLens and GitHub Pull Requests extensions (both are included in the devcontainer configuration).

