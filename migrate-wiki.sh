#!/bin/bash

set -e

# Utility scripts
source "$(dirname "$0")/markdown-sanitizer.sh"

# Global variables
TEMP_DIR="/tmp/devops-to-github-wiki"
LOG_FILE="$(pwd)/migrate-wiki.log"

# Log messages to file and stderr
log_message() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" | tee -a "$LOG_FILE" >&2
}

# Execute commands and log errors
exec_command() {
    local cmd="$1"
    local error_msg="$2"
    local success_codes="${3:-0}"
    
    log_message "Executing: $cmd"
    
    local tmp_log="/tmp/cmd_output_$$.log"
    eval "$cmd" > "$tmp_log" 2>&1
    local exit_code=$?
    
    if [[ " $success_codes " != *" $exit_code "* ]]; then
        log_message "Error: $error_msg (code $exit_code)"
        cat "$tmp_log" >> "$LOG_FILE"
        rm "$tmp_log"
        return 1
    fi
    
    cat "$tmp_log" >> "$LOG_FILE"
    rm "$tmp_log"
    return 0
}

# Create a unique temporary directory
create_temp_directory() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    
    mkdir -p "$TEMP_DIR"
    local unique_dir="$TEMP_DIR/$(uuidgen | tr '[:upper:]' '[:lower:]')"
    mkdir -p "$unique_dir"
    
    echo "$unique_dir"
}

# Clone or create a GitHub Wiki repository
clone_repository() {
    local repo_url="$1"
    local path="$2"
    local is_azure_wiki=false
    local is_github_wiki=false
    
    if [[ $repo_url == *"dev.azure.com"* && $repo_url == *".wiki"* ]]; then
        is_azure_wiki=true
        log_message "Detected Azure DevOps Wiki repository"
    fi
    
    if [[ $repo_url == *"github.com"* ]]; then
        is_github_wiki=true
        log_message "Detected GitHub Wiki repository"
        
        if [[ $repo_url != *".wiki.git" ]]; then
            if [[ $repo_url == *".git" ]]; then
                repo_url="${repo_url%.git}"
            fi
            repo_url="${repo_url}.wiki.git"
            log_message "Adjusted GitHub Wiki URL: $repo_url"
        fi
    fi
    
    log_message "Cloning repository: $repo_url into $path"
    
    if [ -d "$path" ]; then
        log_message "Directory $path already exists, removing it"
        rm -rf "$path"
    fi
    
    mkdir -p "$path"
    
    if [ "$is_github_wiki" = true ] && ! [ "$is_azure_wiki" = true ]; then
        log_message "Attempting direct git clone of GitHub Wiki repository"
        
        git clone "$repo_url" "$path" 2>&1 || {
            log_message "Failed to clone GitHub Wiki repository. Creating a new one."
            
            rm -rf "$path"
            mkdir -p "$path"
            
            (
                cd "$path" || exit 1
                git init
                
                echo "# Wiki" > README.md
                echo "" >> README.md
                echo "This repository contains the Wiki migrated from Azure DevOps." >> README.md
                echo "" >> README.md
                echo "Migrated on: $(date)" >> README.md
                
                echo "# Home" > Home.md
                echo "" >> Home.md
                echo "Welcome to the Wiki migrated from Azure DevOps." >> Home.md
                
                if ! git config user.email > /dev/null; then
                    git config user.email "migration-script@example.com"
                    git config user.name "Migration Script"
                fi
                
                git add README.md Home.md
                git commit -m "Initialize Wiki"
                
                git remote add origin "$repo_url"
                
                log_message "Attempting initial push to the new GitHub Wiki repository"
                if git push -u origin master; then
                    log_message "GitHub Wiki repository successfully created"
                else
                    log_message "Error: Failed to push to the GitHub Wiki repository."
                    log_message "You may need to manually create the main repository first."
                    log_message "Main repository URL: ${repo_url/.wiki.git/.git}"
                    return 1
                fi
            )
            
            if [ $? -eq 0 ]; then
                log_message "GitHub Wiki repository successfully initialized"
                return 0
            else
                log_message "Error: Failed to initialize the GitHub Wiki repository"
                return 1
            fi
        }
        
        log_message "Cloning completed successfully via direct git clone"
        return 0
    fi
    
    log_message "Attempting direct git clone"
    
    (
        git clone "$repo_url" "$path" 2>&1
        if [ $? -eq 0 ]; then
            log_message "Cloning completed successfully via direct git clone"
            return 0
        else
            log_message "Direct git clone failed, attempting alternative method"
        fi
    ) | tee -a "$LOG_FILE"
    
    rm -rf "$path"
    mkdir -p "$path"
    
    (
        cd "$path" || exit 1
        log_message "Initializing Git repository in $path"
        git init > /dev/null
        
        log_message "Adding remote origin"
        git remote add origin "$repo_url"
        
        log_message "Fetching content"
        git fetch --depth=1 origin
        
        log_message "Switching to main branch"
        if [ "$is_azure_wiki" = true ]; then
            log_message "Attempting checkout of wikiMaster branch for Azure DevOps Wiki"
            if git show-ref --verify --quiet "refs/remotes/origin/wikiMaster"; then
                git checkout -b wikiMaster origin/wikiMaster
                log_message "Using wikiMaster branch for Azure DevOps Wiki"
            else
                log_message "wikiMaster branch not found, looking for alternatives..."
                if git show-ref --verify --quiet "refs/remotes/origin/master"; then
                    git checkout -b master origin/master
                    log_message "Using master branch for Azure DevOps Wiki"
                else
                    git fetch origin
                    branch=$(git branch -r | grep -v HEAD | head -n 1 | sed 's/origin\///')
                    if [ -n "$branch" ]; then
                        git checkout -b "$branch" "origin/$branch"
                        log_message "Using branch $branch for Azure DevOps Wiki"
                    else
                        log_message "Failed to determine a branch for checkout"
                        return 1
                    fi
                fi
            fi
        else
            log_message "Checking available branches in the remote repository"
            git fetch origin
            branches=$(git branch -r | grep -v HEAD)
            log_message "Available branches: $branches"
            
            if git show-ref --verify --quiet "refs/remotes/origin/main"; then
                git checkout -b main origin/main
                log_message "Using main branch for GitHub Wiki"
            elif git show-ref --verify --quiet "refs/remotes/origin/master"; then
                git checkout -b master origin/master
                log_message "Using master branch for GitHub Wiki"
            else
                log_message "No standard branches found, creating a new branch 'main'"
                git checkout -b main
                touch README.md
                echo "# Wiki" > README.md
                git add README.md
                git commit -m "Initial commit"
                log_message "Created new branch 'main' with initial README.md"
            fi
        fi
        
        log_message "Cloning completed successfully"
    ) 2>&1 | tee -a "$LOG_FILE"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        return 0
    else
        log_message "Error: Failed to clone the repository"
        return 1
    fi
}

# Push changes to the repository
push_to_repository() {
    local repo_url="$1"
    local path="$2"
    
    log_message "Pushing changes to the repository"
    
    (
        cd "$path" || exit 1
        exec_command "git add ." "Failed to add files"
        exec_command "git commit -m \"Migrate from Azure DevOps Wiki\"" "Failed to create commit" "0 1"
        exec_command "git push" "Failed to push changes"
    )
}

# Delete all files except .git
delete_all_files() {
    local path="$1"
    
    log_message "Deleting existing files in $path"
    
    find "$path" -mindepth 1 -not -path "$path/.git*" -delete
}

# Decode URL-encoded characters (robust for all %XX cases, Bash-only)
url_decode() {
    local encoded="$1"
    local decoded
    decoded=$(echo -e "${encoded//%/\\x}")
    echo "$decoded"
}

# Sanitize page names for GitHub Wiki
sanitize_page_name() {
    local page_name="$1"
    # Remove trailing % if present
    page_name=$(echo "$page_name" | sed 's/%$//')
    # Decode URL-encoded characters (Bash-only)
    local decoded=$(url_decode "$page_name")
    # Remove forbidden characters for GitHub Wiki
    decoded=$(echo "$decoded" | tr -d '\\:*?"<>|')
    # Replace spaces with hyphens
    local sanitized=$(echo "$decoded" | sed 's/ /-/g')
    echo "$sanitized"
}

# Migrate a single page
migrate_page() {
    local page="$1"
    
    if [ ! -f "$page" ]; then
        log_message "Warning: Page $page not found"
        return 1
    fi
    
    log_message "Processing content of $page"
    
    if [ ! -s "$page" ]; then
        log_message "Warning: Page $page is empty"
        echo "<!-- Empty page migrated from Azure DevOps Wiki -->"
        return 0
    fi
    
    local content=$(cat "$page")
    local title=$(basename "$page" .md | sed 's/-/ /g')
    
    if ! echo "$content" | grep -q "^#"; then
        echo "# $title"
        echo ""
    fi
    
    while IFS= read -r line || [ -n "$line" ]; do
        if echo "$line" | grep -q '!\[[^]]*\]([^)]*)'; then
            image_path=$(echo "$line" | sed -n 's/.*!\[[^]]*\](\([^)]*\)).*/\1/p')
            
            if echo "$image_path" | grep -q '^https\?://'; then
                echo "$line"
            else
                if ! echo "$image_path" | grep -q '^./'; then
                    modified_line=$(echo "$line" | perl -pe 's/!\[(.*?)\]\((?!\.\/|https?:\/\/)(.*?)\)/![\1](.\/$2)/g')
                    echo "$modified_line"
                else
                    echo "$line"
                fi
            fi
        elif echo "$line" | grep -q '// this is a .* image'; then
            echo "$line"
        elif echo "$line" | grep -q '!\\\[\\1\\\](./\\2)'; then
            echo "<!-- Image marker requiring manual correction -->"
        elif echo "$line" | grep -q '\[[^]]*\]([^)]*.md)'; then
            modified_line=$(echo "$line" | sed 's/\(\[[^]]*\]\)(\([^)]*\)\.md)/\1(\2)/')
            echo "$modified_line"
        elif [[ "$line" =~ ^[\|\-]+ ]]; then
            modified_line=$(echo "$line" | sed 's/|/ | /g' | sed 's/  / /g' | sed 's/| -/| -/g')
            echo "$modified_line"
        elif [[ "$line" =~ ^[[:space:]]*\`\`\` ]]; then
            echo "$line"
        elif [[ "$line" =~ ^[[:space:]]*\`\`\`$ ]]; then
            echo "$line"
        else
            echo "$line"
        fi
    done < "$page"
    
    return 0
}

# Recursively migrate wiki pages, preserving hierarchy
migrate_wiki_pages() {
    local source_dir="$1"
    local target_dir="$2"
    local prefix="$3"
    local parent_chain="$4"
    
    log_message "Migrating from $source_dir to $target_dir with prefix $prefix and parent_chain $parent_chain"
    
    local md_files=($(find "$source_dir" -maxdepth 1 -name "*.md" -type f -print))
    log_message "Found ${#md_files[@]} .md files in $source_dir"
    
    for md_file in "${md_files[@]}"; do
        local basename_file=$(basename "$md_file" .md)
        local sanitized_name=$(sanitize_page_name "$basename_file")
        
        local full_chain
        if [ -n "$parent_chain" ]; then
            full_chain="${parent_chain}-${sanitized_name}"
        else
            full_chain="$sanitized_name"
        fi
        local target_file_name="$full_chain.md"
        local target_file_path="$target_dir/$target_file_name"
        
        log_message "Copying $md_file to $target_file_path"
        migrate_page "$md_file" > "$target_file_path"
        
        local subdir="${source_dir}/${basename_file}"
        if [ -d "$subdir" ]; then
            log_message "Found subpages directory: $subdir"
            migrate_wiki_pages "$subdir" "$target_dir" "$sanitized_name" "$full_chain"
        fi
    done
    
    local subdirs=($(find "$source_dir" -mindepth 1 -maxdepth 1 -type d -not -path "*/\.*" -print))
    for subdir in "${subdirs[@]}"; do
        local dir_name=$(basename "$subdir")
        local corresponding_md="${source_dir}/${dir_name}.md"
        if [ -f "$corresponding_md" ]; then
            log_message "Directory $dir_name already processed via its corresponding .md file"
            continue
        fi
        log_message "Processing additional directory: $subdir"
        local sanitized_dir_name=$(sanitize_page_name "$dir_name")
        local new_chain
        if [ -n "$parent_chain" ]; then
            new_chain="${parent_chain}-${sanitized_dir_name}"
        else
            new_chain="$sanitized_dir_name"
        fi
        migrate_wiki_pages "$subdir" "$target_dir" "$sanitized_dir_name" "$new_chain"
    done
}

# Extract the title from a Markdown file
extract_title() {
    local file_path="$1"
    local title=""
    
    if [ ! -f "$file_path" ]; then
        echo "$(basename "$file_path" .md | sed 's/-/ /g')"
        return
    fi
    
    title=$(grep -m 1 "^#" "$file_path" | sed 's/^#\s*//')
    
    if [ -z "$title" ]; then
        title=$(basename "$file_path" .md | sed 's/-/ /g')
    fi
    
    echo "$title"
}

# Create Home page and sidebar (_Sidebar.md)
create_home_page() {
    local path="$1"
    local source_path="$2"
    
    log_message "Creating Home page and sidebar"
    
    local migrated_pages=()
    
    migrated_pages=($(find "$path" -name "*.md" -type f -not -name "Home.md" -not -name "README.md" -not -name "_Sidebar.md" | sort))
    log_message "Found ${#migrated_pages[@]} pages to include in navigation"
    
    local home_page="$path/Home.md"
    echo "# Main Wiki" > "$home_page"
    echo "" >> "$home_page"
    echo "Welcome to the wiki migrated from Azure DevOps." >> "$home_page"
    echo "" >> "$home_page"
    echo "## Pages" >> "$home_page"
    echo "" >> "$home_page"
    
    local sidebar_page="$path/_Sidebar.md"
    echo "# Navigation" > "$sidebar_page"
    echo "" >> "$sidebar_page"
    echo "* [Main Page](Home)" >> "$sidebar_page"
    echo "" >> "$sidebar_page"
    
    build_sidebar_from_order() {
        local current_dir="$1"
        local indent="$2"
        local prefix="$3"
        
        local order_file="$current_dir/.order"
        if [ ! -f "$order_file" ]; then
            for md in $(ls "$current_dir"/*.md 2>/dev/null | sort); do
                local base_name=$(basename "$md" .md)
                local sanitized_name=$(sanitize_page_name "$base_name")
                local full_name
                if [ -n "$prefix" ]; then
                    full_name="${prefix}-${sanitized_name}"
                else
                    full_name="$sanitized_name"
                fi
                local title=$(extract_title "$md")
                echo "${indent}* [$title]($full_name)" >> "$sidebar_page"
            done
            for subdir in "$current_dir"/*/; do
                [ -d "$subdir" ] || continue
                local subdir_name=$(basename "$subdir")
                local sanitized_subdir=$(sanitize_page_name "$subdir_name")
                local new_prefix
                if [ -n "$prefix" ]; then
                    new_prefix="${prefix}-${sanitized_subdir}"
                else
                    new_prefix="$sanitized_subdir"
                fi
                build_sidebar_from_order "$subdir" "  $indent" "$new_prefix"
            done
            return
        fi
        while IFS= read -r entry || [ -n "$entry" ]; do
            entry=$(echo "$entry" | sed 's/%$//;s/[[:space:]]*$//')
            [ -z "$entry" ] && continue
            local md_path="$current_dir/$entry.md"
            local dir_path="$current_dir/$entry"
            local sanitized_name=$(sanitize_page_name "$entry")
            local full_name
            if [ -n "$prefix" ]; then
                full_name="${prefix}-${sanitized_name}"
            else
                full_name="$sanitized_name"
            fi
            if [ -f "$md_path" ]; then
                local title=$(extract_title "$md_path")
                echo "${indent}* [$title]($full_name)" >> "$sidebar_page"
            fi
            if [ -d "$dir_path" ]; then
                build_sidebar_from_order "$dir_path" "  $indent" "$full_name"
            fi
        done < "$order_file"
    }

    build_sidebar_from_order "$source_path" "" ""
    
    log_message "Home page and sidebar created successfully"
}

# Copy attachment files
copy_attachment_files() {
    local source_path="$1"
    local destination_path="$2"
    
    local attachments_path="$source_path/.attachments"
    
    if [ -d "$attachments_path" ]; then
        log_message "Copying attachment folder from $attachments_path to $destination_path/.attachments"
        
        mkdir -p "$destination_path/.attachments"
        
        cp -R "$attachments_path"/* "$destination_path/.attachments/" 2>/dev/null || true
        
        log_message "Attachment files copied successfully"
    else
        log_message "No attachment files found in $source_path"
    fi
}

# Main function: orchestrates the migration process
main() {
    local azure_url=""
    local github_url=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--azure-url)
                azure_url="$2"
                shift 2
                ;;
            -g|--github-url)
                github_url="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [ -z "$azure_url" ] || [ -z "$github_url" ]; then
        echo "Error: Azure DevOps and GitHub URLs are required."
        show_help
        exit 1
    fi
    
    log_message "Starting wiki migration"
    log_message "Azure DevOps Wiki: $azure_url"
    log_message "GitHub Wiki: $github_url"
    
    local current_dir=$(pwd)
    local devops_wiki="$current_dir/devops-wiki"
    local github_wiki="$current_dir/github-wiki"
    
    log_message "Cloning repositories..."
    clone_repository "$azure_url" "$devops_wiki"
    clone_repository "$github_url" "$github_wiki"
    
    log_message "Migrating wiki pages..."
    delete_all_files "$github_wiki"
    migrate_wiki_pages "$devops_wiki" "$github_wiki" "" ""
    
    log_message "Copying attachment files..."
    copy_attachment_files "$devops_wiki" "$github_wiki"
    
    log_message "Creating navigation pages..."
    create_home_page "$github_wiki" "$devops_wiki"
    
    log_message "Pushing changes to GitHub..."
    push_to_repository "$github_url" "$github_wiki"
    
    log_message "Migration completed!"
}

if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
    main "$@"
fi
