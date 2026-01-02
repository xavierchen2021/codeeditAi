#!/bin/bash
set -e

# Script to upload files to Cloudflare R2
# Requires AWS CLI configured with R2 credentials
# Usage: ./upload-to-r2.sh <file-path> <r2-key>

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing required arguments"
    echo "Usage: $0 <file-path> <r2-key>"
    echo "Example: $0 build/Aizen-1.0.1.dmg Aizen-1.0.1.dmg"
    exit 1
fi

FILE_PATH="$1"
R2_KEY="$2"

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File not found at $FILE_PATH"
    exit 1
fi

# Check for required environment variables
if [ -z "$R2_ENDPOINT" ] || [ -z "$R2_BUCKET_NAME" ]; then
    echo "Error: Missing required environment variables"
    echo "Required:"
    echo "  R2_ENDPOINT - R2 endpoint URL"
    echo "  R2_BUCKET_NAME - R2 bucket name"
    echo "  R2_ACCESS_KEY_ID - R2 access key (or AWS_ACCESS_KEY_ID)"
    echo "  R2_SECRET_ACCESS_KEY - R2 secret key (or AWS_SECRET_ACCESS_KEY)"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI not found"
    echo ""
    echo "Please install AWS CLI:"
    echo "  brew install awscli"
    echo ""
    exit 1
fi

# Set AWS credentials from R2 variables if they exist
export AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID:-$AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY:-$AWS_SECRET_ACCESS_KEY}"

echo "Uploading $FILE_PATH to R2..."
echo "Bucket: $R2_BUCKET_NAME"
echo "Key: $R2_KEY"
echo "Endpoint: $R2_ENDPOINT"
echo ""

# Upload to R2 using AWS CLI S3 API
aws s3 cp "$FILE_PATH" "s3://$R2_BUCKET_NAME/$R2_KEY" \
    --endpoint-url "$R2_ENDPOINT" \
    --region auto \
    --acl public-read

if [ $? -eq 0 ]; then
    echo "✅ Upload successful!"
    echo ""
    echo "File URL: ${R2_PUBLIC_URL}/$R2_KEY"
else
    echo "❌ Upload failed"
    exit 1
fi
