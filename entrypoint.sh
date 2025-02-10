#!/usr/bin/env bash
set -e

# The runtime directory for actual use
TARGET_DIR="/etc/nginx"

# If /app is empty (because an external volume was just mounted and is empty),
# copy default contents from /app-dist (baked into the image).
if [ -z "$(ls -A $TARGET_DIR)" ]; then
  echo "No existing files in $TARGET_DIR. Copying from /etc/nginx-default..."
  cp -R /etc/nginx-default/* "$TARGET_DIR/"
  # Optionally, also fix ownership/permissions here if needed
fi

# Finally, exec the CMD passed in by Docker (e.g. `CMD ["somecommand"]`)
exec "$@"
