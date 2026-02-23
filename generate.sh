#!/bin/bash

# Enable strict mode for better error handling
set -euo pipefail
IFS=$'\n\t'

# Function to replace all hyphens with spaces within the <title> tag
replace_hyphens_in_title() {
    local file=$1

    # Use sed to replace all hyphens with spaces only within lines containing the <title> tag
    sed -i '' '/<title>/ s/-/ /g' "$file"
}

# Function to add meta description tag
add_meta_description() {
    local file=$1
    local description=$2

    # Use sed to insert the meta description tag after the <title> tag
    sed -i '' '/<title>/a\
    <meta name="description" content="'"$description"'">' "$file"
}

# Function to add home navigation link
add_home_link() {
    local file=$1
    
    # Use sed to add the home link after the <body> tag
    sed -i '' '/<body>/a\
<a href="/" class="nav-link">Home</a>' "$file"
}

# Function to retrieve the first commit date of a file
get_first_commit_date() {
    local file=$1
    local first_date=""

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
            first_date=$(git log --follow --diff-filter=A --format=%cs -- "$file" | tail -n 1)

            if [[ -z "$first_date" ]]; then
                first_date=$(git log --follow --format=%cs -- "$file" | tail -n 1)
            fi
        fi
    fi

    if [[ -z "$first_date" ]]; then
        first_date=$(date "+%Y-%m-%d")
    fi

    echo "$first_date"
}

# Remove existing HTML files in all numbered folders (handles renamed posts)
find . -type f -path "./[0-9]*" -name "*.html" -delete

# Convert Markdown to HTML, excluding README.md
find . -type f -path "./[0-9]/*" -name "*.md" ! -name "README.md" | while read -r file; do
    output_file="${file%.md}.html"
    echo "Converting '$file' to '$output_file'..."

    # Use absolute path for CSS to ensure correct referencing
    pandoc --mathjax --css "/pandoc.css" -s "$file" --highlight-style=tango -o "$output_file"

    # Post-process the generated HTML to replace hyphens with spaces in the <title> tag
    replace_hyphens_in_title "$output_file"

    # Extract the first paragraph (up to 160 characters) for the meta description
    description=$(sed -n '/^$/q;p' "$file" | tr -d '\n' | cut -c 1-160)
    add_meta_description "$output_file" "$description"
    
    # Add home navigation link
    add_home_link "$output_file"
done

# Generate index.html
echo "Generating 'index.html'..."
cat << EOF > index.html
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Blog</title>
    <meta name="description" content="A collection of blog posts on various topics.">
    <link rel="icon" href="/favicon.ico" type="image/x-icon">
    <link rel="stylesheet" href="/pandoc.css">
</head>

<body>
    <a href="/about.html" class="nav-link">About</a>
    <div id="content-wrap">
        <h1>Blog</h1>
        <hr />
        <div>
EOF

# Generate list items for each post
find . -type f -path "./[0-9]/*" -name "*.html" | sort -r | while read -r file; do
    index=$(basename "$(dirname "$file")")
    # Replace hyphens with spaces in the title for display
    title=$(basename "$file" .html | sed 's/-/ /g')
    # Remove .html extension from the href URL
    clean_file=$(echo "$file" | sed 's/\.html$//')
    markdown_file="${file%.html}.md"
    post_date=$(get_first_commit_date "$markdown_file")
    cat << EOF >> index.html
            <div style="display:flex; flex-wrap:wrap; align-items:baseline; gap:0.5rem;">
                <span>$index.</span>
                <a href="$clean_file">$title</a>
                <span style="color:#777; font-size:0.9em; margin-left:auto;">$post_date</span>
            </div>
EOF
done

# Close the HTML structure
cat << EOF >> index.html
        </div>
    </div>
</body>

</html>
EOF

echo "index.html generated successfully."

# Generate about.html with media gallery
echo "Generating 'about.html'..."
cat << 'EOF' > about.html
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>About</title>
    <meta name="description" content="About page for Gabriel's blog.">
    <link rel="icon" href="/favicon.ico" type="image/x-icon">
    <link rel="stylesheet" href="/pandoc.css">
    <style>
        .intro {
            margin: 0 auto;
            max-width: 40rem;
            min-height: calc(100vh - 20rem);
            display: flex;
            flex-direction: column;
            justify-content: center;
            text-align: left;
        }

        .intro p {
            margin: 0.65rem 0;
        }

        .gallery-anchor {
            margin-top: calc(20rem + 2vh);
        }

        .media-gallery {
            column-width: 280px;
            column-gap: 1.5rem;
        }

        .media-item {
            margin: 0 0 1.5rem;
            display: flex;
            flex-direction: column;
            gap: 0.5rem;
            break-inside: avoid;
        }

        .media-item img,
        .media-item video {
            width: 100%;
            height: auto;
            border-radius: 8px;
            box-shadow: 0 8px 20px rgba(0, 0, 0, 0.12);
        }

        .media-item figcaption {
            font-size: 0.9rem;
            color: #555;
        }
    </style>
</head>

<body>
    <a href="/index.html" class="nav-link">Home</a>
    <div id="content-wrap">
        <div class="intro">
            <p>Dear Reader,</p>
            <p>Welcome to my homepage on the internet. If you would like to reach out my email is ggordbegli@gmail.com. I also post photos here, if you scroll down you'll see a few.</p>
            <p>Enjoy your stay,<br>Gabe</p>
        </div>
EOF

cat << 'EOF' >> about.html
    </div>
</body>

</html>
EOF

echo "about.html generated successfully."

# Generate llms.txt with all posts
echo "Generating 'private/llms.txt'..."
llms_output="private/llms.txt"
mkdir -p "$(dirname "$llms_output")"
cat << EOF > "$llms_output"
# Blog Posts

This file contains all blog posts for easy consumption by LLMs.

EOF

# Add each post to llms.txt
find . -type f -path "./[0-9]/*" -name "*.md" ! -name "README.md" | sort | while read -r file; do
    index=$(basename "$(dirname "$file")")
    title=$(basename "$file" .md | sed 's/-/ /g')
    
    {
        echo "## Post $index: $title"
        echo ""
        cat "$file"
        echo ""
        echo "---"
        echo ""
    } >> "$llms_output"
done
# Include private markdown files
find ./private -type f -name "*.md" | sort | while read -r file; do
    title=$(basename "$file" .md | sed 's/-/ /g')

    {
        echo "## Private: $title"
        echo ""
        cat "$file"
        echo ""
        echo "---"
        echo ""
    } >> "$llms_output"
done

echo "'$llms_output' generated successfully."
