#!/usr/bin/env bash

if ! command -v bash &> /dev/null; then
    echo "Error: bash not found!"
    exit 1
fi

# always run "yarn copy-clickhouse-repo-docs" before invoking this script
# otherwise it will fail not being able to find the files it needs which
# are copied to scripts/tmp and configured in package.json -> "autogen_settings_needed_files"

if command -v curl >/dev/null 2>&1; then
  echo "curl is installed"
else
  echo "curl is NOT installed"
  exit 1
fi


target_dir=$(dirname "$(dirname "$(realpath "$0")")")
SCRIPT_NAME=$(basename "$0")
tmp_dir="$target_dir/tmp"

mkdir -p "$tmp_dir" || exit 1
cd "$tmp_dir" || exit 1

script_url="https://clickhouse.com/"  # URL of the installation script
script_filename="clickhouse" # Choose a descriptive name
script_path="$tmp_dir/$script_filename"

# Install ClickHouse
if [ ! -f "$script_path" ]; then
  echo -e "[$SCRIPT_NAME] Installing ClickHouse binary\n"
  curl -s https://clickhouse.com/ | sh &> /dev/null
fi

if [[ ! -f "$script_path" ]]; then
  echo "Error: File not found after curl download!"
  exit 1
fi

echo "Downloaded to: $script_path"
echo "[$SCRIPT_NAME] Auto-generating settings"

# Autogenerate Format settings
chmod +x "$script_path" || { echo "Error: Failed to set execute permission"; exit 1; }

root=$(dirname "$(dirname "$(realpath "$tmp_dir")")")

./clickhouse -q "
WITH
'FormatFactorySettings.h' AS cpp_file,
settings_from_cpp AS
(
    SELECT extract(line, 'DECLARE\\(\\w+, (\\w+),') AS name
    FROM file(cpp_file, LineAsString)
    WHERE match(line, '^\\s*DECLARE\\(')
),
main_content AS
(
    SELECT format('## {} {}\\n{}\\n\\nType: {}\\n\\nDefault value: {}\\n\\n{}\\n\\n',
                  name, '{#'||name||'}', multiIf(tier == 'Experimental', '<ExperimentalBadge/>', tier == 'Beta', '<BetaBadge/>', ''), type, default, trim(BOTH '\\n' FROM description))
    FROM system.settings WHERE name IN settings_from_cpp
    ORDER BY name
),
'---
title: ''Format Settings''
sidebar_label: ''Format Settings''
slug: /operations/settings/formats
toc_max_heading_level: 2
description: ''Settings which control input and output formats.''
---

import ExperimentalBadge from \'@theme/badges/ExperimentalBadge\';
import BetaBadge from \'@theme/badges/BetaBadge\';

<!-- Autogenerated -->
These settings are autogenerated from [source](https://github.com/ClickHouse/ClickHouse/blob/master/src/Core/FormatFactorySettings.h).

' AS prefix
SELECT prefix || (SELECT groupConcat(*) FROM main_content)
INTO OUTFILE 'settings-formats.md' TRUNCATE FORMAT LineAsString
" > /dev/null || { echo "Failed to Autogenerate Format settings"; exit 1; }

# Autogenerate settings
./clickhouse -q "
WITH
'Settings.cpp' AS cpp_file,
settings_from_cpp AS
(
    SELECT extract(line, 'DECLARE\\(\\w+, (\\w+),') AS name
    FROM file(cpp_file, LineAsString)
    WHERE match(line, '^\\s*DECLARE\\(')
),
main_content AS
(
    SELECT format(
      '## {} {}\\n{}\\n{}\\n\\nType: {}\\n\\nDefault value: {}\\n\\n{}\\n\\n',
      name,
      '{#'||name||'}',
      multiIf(tier == 'Experimental', '<ExperimentalBadge/>', tier == 'Beta', '<BetaBadge/>', ''),
      if(description LIKE '%Only has an effect in ClickHouse Cloud%', '\\n<CloudAvailableBadge/>', ''),
      type,
      default,
      replaceOne(
        trim(BOTH '\\n' FROM description),
        ' and [MaterializedMySQL](../../engines/database-engines/materialized-mysql.md)',''
      )
    )
    FROM system.settings WHERE name IN settings_from_cpp
    ORDER BY name
),
'---
title: ''Session Settings''
sidebar_label: ''Session Settings''
slug: /operations/settings/settings
toc_max_heading_level: 2
description: ''Settings which are found in the ``system.settings`` table.''
---

import ExperimentalBadge from \'@theme/badges/ExperimentalBadge\';
import BetaBadge from \'@theme/badges/BetaBadge\';
import CloudAvailableBadge from \'@theme/badges/CloudAvailableBadge\';

<!-- Autogenerated -->
All below settings are also available in table [system.settings](/docs/operations/system-tables/settings). These settings are autogenerated from [source](https://github.com/ClickHouse/ClickHouse/blob/master/src/Core/Settings.cpp).

' AS prefix
SELECT prefix || (SELECT groupConcat(*) FROM main_content)
INTO OUTFILE 'settings.md' TRUNCATE FORMAT LineAsString
" > /dev/null || { echo "Failed to Autogenerate Core settings"; exit 1; }

# Autogenerate MergeTree settings
./clickhouse -q "
  WITH
    merge_tree_settings AS
    (
      SELECT format(
          '## {} {} {}  \n{}  \nType: {}  \nDefault value: {}  \n\n{}  \n',
          name,
          '{#'||name||'}',
          multiIf(tier == 'Experimental', '<ExperimentalBadge/>\n', tier == 'Beta', '<BetaBadge/>\n', ''),
          if(description LIKE '%Only has an effect in ClickHouse Cloud%', '\\n<CloudAvailableBadge/>', ''),
          type,
          default,
          description
        )
      FROM system.merge_tree_settings ORDER BY name
    )
    SELECT * FROM merge_tree_settings
    INTO OUTFILE 'generated_merge_tree_settings.md' TRUNCATE FORMAT LineAsString
" > /dev/null || { echo "Failed to Autogenerate Core settings"; exit 1; }

# Auto generate global server settings
./clickhouse -q "
WITH
    server_settings_outside_source AS
    (
        SELECT
            arrayJoin(extractAllGroups(raw_blob, '## (\\w+)(?:\\s[^\n]+)?\n\\s+((?:[^#]|#[^#]|##[^ ])+)')) AS g,
            g[1] AS name,
            replaceRegexpAll(replaceRegexpAll(g[2], '\n(Type|Default( value)?): [^\n]+\n', ''), '^\n+|\n+$', '') AS doc
        FROM file('_server_settings_outside_source.md', RawBLOB)
    ),
    server_settings_in_source AS
    (
        SELECT
	        name,
	        replaceRegexpAll(description, '(?m)^[ \t]+', '') AS description
        FROM system.server_settings
    ),
    combined_server_settings AS
    (
        SELECT
            name,
            description
        FROM server_settings_in_source
        UNION ALL
        SELECT
            name,
            doc AS description
        FROM server_settings_outside_source
    ),
    formatted_settings AS
    (
        SELECT
            format('## {} {}\n\n{}\n\n', name, lcase('{#'||name||'}'), description) AS formatted_text
        FROM combined_server_settings
        ORDER BY name ASC
    ),
    prefix_text AS
    (
        SELECT
            '---
description: ''This section contains descriptions of server settings i.e settings
  which cannot be changed at the session or query level.''
keywords: [''global server settings'']
sidebar_label: ''Server Settings''
sidebar_position: 57
slug: /operations/server-configuration-parameters/settings
title: ''Server Settings''
---

import Tabs from ''@theme/Tabs'';
import TabItem from ''@theme/TabItem'';
import SystemLogParameters from ''@site/docs/operations/server-configuration-parameters/_snippets/_system-log-parameters.md''

# Server Settings

This section contains descriptions of server settings. These are settings which
cannot be changed at the session or query level.

For more information on configuration files in ClickHouse see [""Configuration Files""](/operations/configuration-files).

Other settings are described in the ""[Settings](/operations/settings/overview)"" section.
Before studying the settings, we recommend reading the [Configuration files](/operations/configuration-files)
section and note the use of substitutions (the `incl` and `optional` attributes).

' AS prefix_content
    )
SELECT
    arrayStringConcat([
        (SELECT prefix_content FROM prefix_text),
        arrayStringConcat(groupArray(formatted_text), '')
    ], '')
FROM formatted_settings
INTO OUTFILE 'server_settings.md'
TRUNCATE FORMAT LineAsString" > /dev/null || { echo "Failed to Autogenerate Format settings"; exit 1; }

mv settings-formats.md "$root/docs/operations/settings" || { echo "Failed to move generated settings-format.md"; exit 1; }
mv settings.md "$root/docs/operations/settings" || { echo "Failed to move generated settings.md"; exit 1; }
mv server_settings.md "$root/docs/operations/server-configuration-parameters/settings.md" || { echo "Failed to move generated server_settings.md"; exit 1; }
cat generated_merge_tree_settings.md >> "$root/docs/operations/settings/merge-tree-settings.md" || { echo "Failed to append MergeTree settings.md"; exit 1; }

echo "[$SCRIPT_NAME] Auto-generation of settings markdown pages completed successfully"

# perform cleanup
rm -rf "$tmp_dir"/{settings-formats.md,settings.md,FormatFactorySettings.h,Settings.cpp,generated_merge_tree_settings.md,clickhouse}

echo "[$SCRIPT_NAME] Autogenerating settings completed"
