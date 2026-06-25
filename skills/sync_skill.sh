#!/usr/bin/env bash
# Sincroniza el skill 'snowflake-hol-generator' entre la carpeta viva de Cortex Code
# y este repo, para poder versionarlo.
#
# Uso:
#   ./skills/sync_skill.sh            # vivo  -> repo  (por defecto)
#   ./skills/sync_skill.sh pull       # vivo  -> repo
#   ./skills/sync_skill.sh push       # repo  -> vivo  (restaurar en Cortex Code)
#   ./skills/sync_skill.sh pull --commit "mensaje"   # copia y commitea/pushea
#
set -euo pipefail

SKILL_NAME="snowflake-hol-generator"
LIVE_DIR="$HOME/.snowflake/cortex/skills/$SKILL_NAME"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$SKILL_NAME"

DIRECTION="${1:-pull}"
RSYNC_OPTS=(-a --delete --exclude '.git' --exclude '.DS_Store' --exclude '__pycache__')

case "$DIRECTION" in
  pull)  SRC="$LIVE_DIR/"; DST="$REPO_DIR/";  LABEL="vivo -> repo" ;;
  push)  SRC="$REPO_DIR/"; DST="$LIVE_DIR/";  LABEL="repo -> vivo" ;;
  *) echo "Dirección inválida: $DIRECTION (usa 'pull' o 'push')"; exit 1 ;;
esac

if [[ ! -d "$SRC" ]]; then echo "No existe el origen: $SRC"; exit 1; fi
mkdir -p "$DST"
echo "Sincronizando ($LABEL)..."
rsync "${RSYNC_OPTS[@]}" "$SRC" "$DST"
echo "OK: $SKILL_NAME sincronizado ($LABEL)."

# Commit/push opcional (solo en dirección pull, dentro del repo)
if [[ "${2:-}" == "--commit" && "$DIRECTION" == "pull" ]]; then
  MSG="${3:-"Sync skill $SKILL_NAME desde Cortex Code"}"
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
  git add "skills/$SKILL_NAME"
  if git diff --cached --quiet; then
    echo "Sin cambios que commitear."
  else
    git commit -q -m "$MSG"
    git push origin "$(git branch --show-current)"
    echo "Commit y push hechos."
  fi
fi
