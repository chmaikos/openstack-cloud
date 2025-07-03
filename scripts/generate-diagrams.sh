#!/bin/bash

# Script to generate PNG diagrams from Mermaid code
# This script extracts Mermaid code from .md files and provides instructions for conversion

echo "🔧 OpenStack Cloud Application - Diagram Generator"
echo "=================================================="
echo ""

# Create diagrams directory if it doesn't exist
mkdir -p architecture/diagrams

echo "📋 Available Architecture Diagrams:"
echo ""

# List all .md files in architecture directory
for file in architecture/*.md; do
    if [ -f "$file" ]; then
        filename=$(basename "$file" .md)
        echo "📄 $filename.md"
        
        # Extract Mermaid code if present
        if grep -q "```mermaid" "$file"; then
            echo "   └── Contains Mermaid diagram code"
            echo "   └── To convert to PNG:"
            echo "       1. Copy the Mermaid code from this file"
            echo "       2. Go to https://mermaid.live/"
            echo "       3. Paste the code and export as PNG"
            echo "       4. Save as architecture/diagrams/$filename.png"
            echo ""
        fi
    fi
done

echo "🚀 Quick Start Instructions:"
echo "============================"
echo ""
echo "1. Open any .md file in the architecture/ directory"
echo "2. Find the Mermaid code (between \`\`\`mermaid and \`\`\`)"
echo "3. Copy the code"
echo "4. Go to https://mermaid.live/"
echo "5. Paste the code in the left panel"
echo "6. The diagram will render in the right panel"
echo "7. Click 'Download PNG' to save the image"
echo "8. Save the PNG file in architecture/diagrams/"
echo ""

echo "📁 Recommended PNG files to create:"
echo "===================================="
echo "architecture/diagrams/network-architecture.png"
echo "architecture/diagrams/system-architecture.png"
echo "architecture/diagrams/deployment-flow.png"
echo ""

echo "✅ After creating PNG files, update your README.md to reference them:"
echo "   - Add PNG files to your repository"
echo "   - Include them in your submission"
echo "   - Reference them in your documentation"
echo ""

echo "🎯 For Academic Submission:"
echo "==========================="
echo "Include both .md files (with Mermaid code) and PNG images"
echo "This ensures maximum compatibility and professional presentation" 