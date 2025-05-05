#!/usr/bin/env bash
# Utility functions for Markdown processing

# Sanitize a page name for use as a file name
sanitize_page_name() {
    local page_name="$1"
    # Decode common URL-encoded characters
    local decoded_name=$(echo "$page_name" | perl -pe 's/%20/ /g' | perl -pe 's/%2D/-/g' | perl -pe 's/%2F/\//g')
    # Sanitize the name to make it safe as a file name
    local sanitized=$(echo "$decoded_name" | tr '[:upper:]' '[:lower:]' | perl -pe 's/[^a-z0-9]/-/g' | perl -pe 's/--*/-/g' | perl -pe 's/^-//' | perl -pe 's/-$//')
    echo "$sanitized"
}

# Process links in a markdown file to be GitHub Wiki compatible
process_links() {
    local content="$1"
    local new_content
    new_content=$(echo "$content" | perl -pe 's/\[([^]]*)\]\(([^)]*).md\)/[\1](\2)/g')
    new_content=$(echo "$new_content" | perl -pe 's/!\[(.*?)\]\((?!\./|http)(.*?)\)/![\1](.\/$2)/g')
    echo "$new_content"
}

# Fix headers to ensure correct format
fix_headers() {
    local content="$1"
    local new_content
    new_content=$(echo "$content" | perl -pe 's/^[ \t]*(#+)([^ \t])/\1 \2/g')
    echo "$new_content"
}

# Add a main title to the page if missing
add_title_if_missing() {
    local content="$1"
    local title="$2"
    if ! echo "$content" | grep -q "^# "; then
        echo "# $title"
        echo ""
        echo "$content"
    else
        echo "$content"
    fi
}

# Ensure code blocks have correct syntax
fix_code_blocks() {
    local content="$1"
    local in_code_block=0
    local new_content=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*\`\`\`.* ]]; then
            in_code_block=1
            new_line=$(echo "$line" | perl -pe 's/^[[:space:]]*//')
            new_content="${new_content}${new_line}"$'\n'
        elif [[ "$line" =~ ^[[:space:]]*\`\`\`$ ]]; then
            in_code_block=0
            new_content="${new_content}"'```'$'\n'
        elif [[ $in_code_block -eq 1 ]]; then
            new_content="${new_content}${line}"$'\n'
        else
            new_content="${new_content}${line}"$'\n'
        fi
    done <<< "$content"
    echo "$new_content"
}

# Main function to apply all corrections to a markdown file
process_markdown_file() {
    local file_path="$1"
    local title="$2"
    if [[ ! -f "$file_path" ]]; then
        echo "File $file_path does not exist"
        return 1
    fi
    local content=$(cat "$file_path")
    content=$(add_title_if_missing "$content" "$title")
    content=$(fix_headers "$content")
    content=$(fix_code_blocks "$content")
    content=$(process_links "$content")
    echo "$content"
}