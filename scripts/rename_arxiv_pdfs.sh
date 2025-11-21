#!/bin/bash

# Check if the directory is provided
if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/your/pdfs"
    exit 1
fi

# Directory containing the PDFs
PDF_DIR="$1"
MAX_FILENAME_LENGTH=255  # Maximum length for a filename in Linux

TARGET_DIR="$HOME/docs/lit/papers/arxiv"

# Regex pattern for arXiv ID (simplified pattern)
arxiv_pattern='^[0-9]{4}\.[0-9]{4,5}(v[0-9]+)?$|^arXiv:[0-9]{4}\.[0-9]{4,5}(v[0-9]+)?$'
# arxiv_pattern='^([0-9]{4}\.[0-9]{4,5})|(arXiv:[0-9]{4}\.[0-9]{4,5})(v[0-9]+)?$'

# Function to get metadata from arXiv
get_metadata() {
    local id=$1
    local url="http://export.arxiv.org/api/query?id_list=$id"
    local metadata=$(wget -qO- "$url")
    
    local title=$(echo "$metadata" | grep -oP '(?<=<title>)[^<]+' | tail -n 1)
    local authors=$(echo "$metadata" | grep -oP '(?<=<name>)[^<]+' | awk '{print $NF}' | paste -sd ", " -)

    echo "$title | $authors"
}

# # Function to sanitize filenames
# sanitize() {
#     echo "$1" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' '-' | tr -s '-' | sed 's/^-*//; s/-*$//'
# }

# Function to sanitize filenames, including handling of umlauts
sanitize() {
    local sanitized="$1"

    # Replace German umlauts with their Latin equivalents
    sanitized=$(echo "$sanitized" | sed -e 's/ä/ae/g' -e 's/ö/oe/g' -e 's/ü/ue/g' -e 's/ß/ss/g' -e 's/Ä/Ae/g' -e 's/Ö/Oe/g' -e 's/Ü/Ue/g')

    # Convert to lowercase, replace non-alphanumeric characters with hyphens, and remove extra hyphens
    sanitized=$(echo "$sanitized" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' '-' | tr -s '-' | sed 's/^-*//; s/-*$//')

    echo "$sanitized"
}

# Process each PDF
for pdf in "$PDF_DIR"/*.pdf; do
    # Extract the arXiv ID from the filename (assuming filename is the arXiv ID)
    filename=$(basename "$pdf")
    arxiv_id="${filename%.*}"

    # Check if the filename matches the arXiv ID pattern
    if [[ $arxiv_id =~ $arxiv_pattern ]]; then
        # Get metadata
        metadata=$(get_metadata "$arxiv_id")
        title=$(echo "$metadata" | cut -d '|' -f 1)
        authors=$(echo "$metadata" | cut -d '|' -f 2)

        # Sanitize title and authors
        sanitized_title=$(sanitize "$title")
        sanitized_authors=$(sanitize "$authors")

        # Construct the initial new filename with authors
        base_new_filename="${arxiv_id}-${sanitized_authors}-${sanitized_title}.pdf"

        # Check if the base filename is too long
        if [ ${#base_new_filename} -gt $MAX_FILENAME_LENGTH ]; then
            # Remove authors from the filename if it's too long
            base_new_filename="${arxiv_id}-${sanitized_title}.pdf"
        fi 

        # # Construct new filename
        # new_filename="${arxiv_id}-${sanitized_authors}-${sanitized_title}.pdf"
        # new_filepath="${PDF_DIR}/${base_new_filename}"
        new_filepath="$TARGET_DIR/${base_new_filename}"

        # Rename the file
        mv "$pdf" "$new_filepath"

        echo "Renamed '$pdf' to '$new_filepath'"
    else
        echo "Skipping '$pdf' - filename does not match arXiv ID pattern"
    fi
done

