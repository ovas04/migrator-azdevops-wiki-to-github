[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com?WT.mc_id=academic-105485-koreyst)


# Azure DevOps Wiki to GitHub Wiki Migration Script

This repository provides Bash scripts to migrate your Azure DevOps Wiki to a GitHub Wiki, preserving the original structure, formatting, and attachments.

## Features
- Migrates the complete wiki structure, maintaining hierarchy
- Converts Azure DevOps-specific markdown to GitHub Wiki format
- Preserves correct list numbering and internal links
- Fixes image and attachment referencess
- Generates a sidebar and Home page automatically
- Copies all attachments

## Repository Structure
- `.github/` — Contains the GitHub Actions workflow for automated migration
- `migrate-wiki.sh` — Main migration script (run locally or via GitHub Actions)
- `markdown-sanitizer.sh` — Utility for cleaning and converting markdown files
- `README.md` — Documentation and usage instructions

## Requirements
- Bash (macOS, Linux, or Windows with WSL) for local execution
- Git
- No Python dependency (all decoding is Bash-only)
- Read access to the Azure DevOps Wiki repository (token required)
- Write (push) access to the GitHub Wiki repository (token required, public repo)

> [!CAUTION]
> - The destination GitHub repository must already exist and have the Wiki feature enabled before running the migration.
> - The Azure DevOps Wiki repository must also exist and be accessible.

## Usage Modes

### 1. Local Execution (Manual Clone)

#### Installation
1. Clone this repository:
   ```bash
   git clone <REPO-URL>
   cd migrator-azdevops-wiki-to-github
   ```
2. Make the scripts executable:
   ```bash
   chmod +x migrate-wiki.sh markdown-sanitizer.sh
   ```

#### Running the Migration
Run the migration script with the required parameters:
```bash
./migrate-wiki.sh --azure-url "<AZURE-DEVOPS-WIKI-URL>" --github-url "<GITHUB-WIKI-URL>"
```

- `--azure-url` or `-a`: Full URL of the Azure DevOps Wiki repository. You must include a personal access token (PAT) with at least read permissions. Example:
  ```
  https://<username>:<azure-devops-token>@dev.azure.com/<org>/<project>/_git/<project>.wiki
  ```
- `--github-url` or `-g`: Full URL of the GitHub Wiki repository. You must include a personal access token (PAT) with write (push) permissions. Example:
  ```
  https://<github-token>@github.com/<org>/<repo>.wiki.git
  ```

#### Example
```bash
./migrate-wiki.sh --azure-url "https://user:AZURE_TOKEN@dev.azure.com/org/project/_git/project.wiki" --github-url "https://GITHUB_TOKEN@github.com/org/repo.wiki.git"
```

### 2. GitHub Actions Workflow (Fork & Action)

Automate the migration by forking this repository and using the included GitHub Actions workflow:

**Setup:**
1. Fork this repository.
2. In your fork, go to `Settings > Secrets and variables > Actions` and add:
   - `AZURE_DEVOPS_TOKEN`
   - `GITHUB_TOKEN`
   - `AZURE_DEVOPS_USER`
  
> [!WARNING]
>   - `AZURE_DEVOPS_TOKEN`: Personal access token with read access to the Azure DevOps Wiki
>   - `GITHUB_TOKEN`: Personal access token with write (push) access to the destination GitHub Wiki
>   - `AZURE_DEVOPS_USER`: Your Azure DevOps username


3. Go to the `Actions` tab, select `Migrate Azure DevOps Wiki to GitHub Wiki`, and click **Run workflow**.
4. Enter as input:
   - `azure_repo`: The full Azure DevOps wiki repository path, e.g. `<org>/<project>/_git/<project>.wiki`
   - `github_repo`: The full GitHub wiki repository path, e.g. `<org>/<repo>.wiki.git`

> [!NOTE]
> You must provide the full repository path for both Azure DevOps and GitHub Wiki as shown in the examples above. The workflow will use these values to build the correct URLs for migration.



## Migration Steps
1. The script clones both the Azure DevOps Wiki and the GitHub Wiki repositories locally.
2. It reads the wiki structure from `.order` files in Azure DevOps.
3. All markdown files are converted and migrated, preserving hierarchy and links.
4. Attachments are copied to the GitHub Wiki.
5. A Home page and sidebar are generated automatically.
6. All changes are committed and pushed to the GitHub Wiki repository.

## Migration Flow Diagram

```mermaid
flowchart TD
    A[Start] --> B[Clone Azure DevOps Wiki]
    A --> C[Clone GitHub Wiki]
    B --> D[Read .order files and structure]
    D --> E[Migrate Markdown files and hierarchy]
    E --> F[Copy attachments]
    F --> G[Generate Home and Sidebar]
    G --> H[Commit and push to GitHub Wiki]
    H --> I[End]
    C --> D
```

## Troubleshooting
- **Authentication errors**: Ensure your tokens/credentials are valid and have the correct permissions (read for Azure DevOps, write for GitHub).
- **Format issues**: Check the log file `migrate-wiki.log` in the script directory for details.
- **Clone errors**: Make sure you can manually clone both repositories with the provided URLs.

## Logging
A detailed log of the migration process is saved in `migrate-wiki.log` in the script directory.

## Known Limitations
- Pages with identical names in different hierarchy levels are not supported.
- Some Azure DevOps-specific markdown features may require manual adjustment after migration.

## Security Notes
- Do not store tokens or credentials in plain text files.
- Prefer using repository secrets or environment variables for credentials instead of embedding them in URLs.

## License
MIT
