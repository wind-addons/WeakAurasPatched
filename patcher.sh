#!/bin/bash

# check the sed is installed
if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v gsed &>/dev/null; then
        SED_COMMAND="gsed"
    else
        echo "GNU sed (gsed) is not installed. Please install it with 'brew install gnu-sed'."
        exit 1
    fi
else
    SED_COMMAND="sed"
fi

# cleanup
rm -rf WeakAuras*

# get the latest release tag from GitHub
OWNER="WeakAuras"
REPO="WeakAuras2"
LATEST_TAG=$(curl -s "https://api.github.com/repos/$OWNER/$REPO/releases/latest" | jq -r ".tag_name" | sed 's/^v//')

# get ZIP file URL
ZIP_URL=$(curl -s "https://api.github.com/repos/$OWNER/$REPO/releases/latest" | jq -r ".assets[] | select(.content_type==\"application/zip\").browser_download_url")

# check if the tag exists in the local repo
if git tag --list | grep -q "$LATEST_TAG"; then
    echo "SKIP: Latest tag $LATEST_TAG already exists in the local repo."
    exit 0
fi

# Add the tag to the local repo
git config --global user.name $GIT_USER_NAME
git config --global user.email $GIT_USER_EMAIL
git commit --allow-empty -m "release: $LATEST_TAG"
git tag "$LATEST_TAG"
git push
git push --tags

# download the latest version
echo "DOWNLOADING: $LATEST_TAG"
curl -sL -o addon.zip "$ZIP_URL"
echo "DOWNLOADED: $LATEST_TAG"
unzip addon.zip
rm addon.zip

# Patches
# - 1. update addon info
for dir in WeakAuras WeakAurasArchive WeakAurasModelPaths WeakAurasOptions WeakAurasTemplates; do
    # modify the toc file
    for file in "$dir"/*.toc; do
        "$SED_COMMAND" -i 's/^## X-Curse-Project-ID: .*\([^0-9]*\)$/## X-Curse-Project-ID: 0\1/' "$file"
        "$SED_COMMAND" -i 's/^## X-WoWI-ID: .*$/## X-WoWI-ID: 0/' "$file"
        "$SED_COMMAND" -i 's/^## X-Wago-ID: .*\([^0-9A-Za-z]*\)$/## X-Wago-ID: 0\1/' "$file"
        "$SED_COMMAND" -i 's/^## Title: \(.*\)$/## Title: |cffe8344fPatched|r \1/' "$file"
        "$SED_COMMAND" -i 's/^## Author: \(.*\)$/## Author: Patched by |cff48a295ang2hou|r, Original WeakAuras made by \1/' "$file"
    done

    # take back the debug code
    find "$dir" -type f -exec "$SED_COMMAND" -i 's/--\[==\[@debug@/--@debug@/g' {} \;
    find "$dir" -type f -exec "$SED_COMMAND" -i 's/--@end-debug@\]==\]/--@end-debug@/g' {} \;

    # guide user to the patched version of WeakAuras support
    find "$dir" -type f -exec "$SED_COMMAND" -i 's/https:\/\/discord\.gg\/weakauras/https:\/\/discord\.gg\/xhUHVCgAGy/g' {} \;
    find "$dir" -type f -exec "$SED_COMMAND" -i 's/https:\/\/weakauras\.wtf/https:\/\/discord\.gg\/xhUHVCgAGy/g' {} \;
done
# - 2. allow third-party addons to hook into the WeakAuras API
echo "WeakAuras.Private = Private" >>WeakAuras/WeakAuras.lua

# changelog
echo "# Patch" >CHANGELOG.md
echo "- Original: [WeakAuras $LATEST_TAG]($ZIP_URL)" >>CHANGELOG.md

# let the packager know the version
git add WeakAuras*
git commit -am "patch: $LATEST_TAG"
git tag --delete "$LATEST_TAG"
git tag "$LATEST_TAG"

echo "RELEASE=$LATEST_TAG" >>$GITHUB_ENV
