#!/bin/bash
# Copy the pages into the bundle, plus only the compost files they import.
set -euo pipefail

app="$SRCROOT/Sprig/Web"
compost="$SRCROOT/compost/src"
web="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/web"

/usr/bin/rsync -a --delete --exclude .DS_Store --exclude compost "$app/" "$web/"
rm -rf "$web/compost"

# relative specifiers in `import "./x.js"` and `from "./x.js"`
imports() {
	grep -Eo "(^import|from) *[\"']\.[^\"']+[\"']" "$1" | grep -Eo "[\"'][^\"']+[\"']" | tr -d "\"'" || true
}

queue=("$app"/*.js)
seen=" "
while ((${#queue[@]})); do
	file="${queue[0]}"
	queue=("${queue[@]:1}")
	for spec in $(imports "$file"); do
		dep="$(dirname "$file")/${spec#./}"
		# the pages see compost at ./compost, as it is laid out in the bundle
		dep="${dep/#$app\/compost\//$compost/}"
		dep="$(cd "$(dirname "$dep")" && pwd)/$(basename "$dep")"
		[[ "$seen" == *" $dep "* ]] && continue
		seen+="$dep "
		queue+=("$dep")
		if [[ "$dep" == "$compost"/* ]]; then
			mkdir -p "$web/compost/$(dirname "${dep#$compost/}")"
			cp "$dep" "$web/compost/${dep#$compost/}"
		fi
	done
done
