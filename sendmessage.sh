#!/bin/bash

# API endpoint and output files
API_URL="https://api.deepseek.com/chat/completions"
OUTPUT_FILE="/home/georg/response.txt"
LOG_FILE="/home/georg/api_log.txt"
ERROR_DIR="/home/georg/sent_errors"  # Directory for tracking sent errors

# API configuration
API_KEY="sk-4876a769295d4fc88a6ef5ca3077b97f"
GITHUB_REPO="georg41980/testmessage"
GITHUB_TOKEN="your_github_token_here"  # Replace with your GitHub token

# Create necessary directories
mkdir -p "$ERROR_DIR"

# Check for jq dependency
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Install with: sudo apt-get install jq" | tee -a "$LOG_FILE"
    exit 1
fi

# Read user message
read -p "Enter your message: " MESSAGE

# Generate unique error hash
ERROR_HASH=$(echo -n "$MESSAGE" | sha1sum | cut -d' ' -f1)
ERROR_FILE="$ERROR_DIR/$ERROR_HASH"

# Check if error was already sent
if [ -f "$ERROR_FILE" ]; then
    echo "$(date): Error already reported - $ERROR_HASH" >> "$LOG_FILE"
    exit 0
fi

# Prepare JSON data
JSON_DATA=$(cat <<EOF
{
  "model": "deepseek-chat",
  "messages": [
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user", "content": "$MESSAGE"}
  ],
  "stream": false
}
EOF
)

# Log the request
echo "$(date): Sending request to API..." >> "$LOG_FILE"

# Make API call
if ! curl -v -X POST "$API_URL" \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer $API_KEY" \
     -d "$JSON_DATA" \
     -o "$OUTPUT_FILE" 2>> "$LOG_FILE"; then
    echo "$(date): Error: API request failed" >> "$LOG_FILE"
    
    # Report error to GitHub (only once)
    curl -X PUT \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$GITHUB_REPO/contents/errors/$ERROR_HASH.txt" \
      -d '{
        "message": "New error report",
        "content": "'$(echo -n "Error: $MESSAGE" | base64)'"
      }' &>> "$LOG_FILE"
    
    touch "$ERROR_FILE"  # Mark as reported
    exit 1
fi

# Process response
if [ -s "$OUTPUT_FILE" ]; then
    echo "$(date): API response stored in $OUTPUT_FILE" >> "$LOG_FILE"
    RESPONSE=$(jq -r '.choices[0].message.content' "$OUTPUT_FILE")
    echo "Assistant response: $RESPONSE"
else
    echo "$(date): Error: Empty API response" >> "$LOG_FILE"
    exit 1
fi

echo "Operation completed successfully."
