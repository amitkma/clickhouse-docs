#!/bin/bash

# This script is used for automatically generating any .json table of contents files
# used for various things on the docs site, such as:
  # - landing pages
  # - indexing of the knowledgebase

# check if virtual environment exists
if [ ! -d "venv" ]; then
  echo "Creating virtual environment..."
  python3 -m venv venv
fi

source venv/bin/activate
pip install -r scripts/table-of-contents-generator/requirements.txt

# Add runs of the script below for any table of contents files that need to be generated
# You can run toc_gen.py --help for descriptions of the parameters
python3 scripts/table-of-contents-generator/toc_gen.py --dir="knowledgebase" --single-toc --out="static" --ignore images
python3 scripts/table-of-contents-generator/toc_gen.py --single-toc --dir="docs/en/operations/system-tables" --md="docs/en/operations/system-tables/index.md"
python3 scripts/table-of-contents-generator/toc_gen.py --single-toc --dir="docs/en/operations/settings" --md="docs/en/operations/settings/index.md"
deactivate
rm -r venv
