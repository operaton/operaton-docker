#!/bin/bash
set -Eeu

trap 'Error on line $LINENO' ERR

source $(dirname "$0")/operaton-lib.sh

# Set Password as Docker Secrets for Swarm-Mode
if [[ -z "${DB_PASSWORD:-}" && -n "${DB_PASSWORD_FILE:-}" && -f "${DB_PASSWORD_FILE:-}" ]]; then
  export DB_PASSWORD="$(< "${DB_PASSWORD_FILE}")"
fi

# For compatibility: when DB_ variables are set, translate them to SPRING_ variables.
# Otherwise [defaults](https://github.com/operaton/operaton-bpm-platform/blob/master/distro/run/assembly/resources/default.yml)
# will be used.

if [[ -z "${SPRING_DATASOURCE_DRIVER_CLASS_NAME:-}" && -n "${DB_DRIVER:-}" ]]; then
  export SPRING_DATASOURCE_DRIVER_CLASS_NAME="${DB_DRIVER}"
fi

if [[ -z "${SPRING_DATASOURCE_PASSWORD:-}" && -n "${DB_PASSWORD:-}" ]]; then
  export SPRING_DATASOURCE_PASSWORD="${DB_PASSWORD}"
fi

if [[ -z "${SPRING_DATASOURCE_USERNAME:-}" && -n "${DB_USERNAME:-}" ]]; then
  export SPRING_DATASOURCE_USERNAME="${DB_USERNAME}"
fi

if [[ -z "${SPRING_DATASOURCE_URL:-}" && -n "${DB_URL:-}" ]]; then
  export SPRING_DATASOURCE_URL="${DB_URL}"
fi

SWAGGERUI_PATH=/operaton/internal/swaggerui/

# The start script of the distribution (internal/run.sh) does not know --swaggerui, so it is handled here and not passed on.
# Without explicitly chosen components, run.sh enables the REST API and the web apps; Swagger UI is
# enabled as well then, except in production mode.
componentChosen=false
restChosen=false
swaggeruiChosen=false
productionChosen=false
args=()
for arg in "$@"; do
  case "$arg" in
    --swaggerui )   swaggeruiChosen=true
                    continue
                    ;;
    --rest | --webapps-neo ) componentChosen=true
                    restChosen=true
                    ;;
    --webapps | --oauth2 | --example ) componentChosen=true
                    ;;
    --production )  productionChosen=true
                    ;;
    --help )        /operaton/internal/run.sh start --help
                    echo "  --swaggerui   - Enables the Swagger UI at /swaggerui/index.html (provided by the Docker image)"
                    exit 0
                    ;;
  esac
  args+=("$arg")
done

if [[ "$componentChosen" = "false" ]]; then
  restChosen=true
  if [[ "$productionChosen" = "false" ]]; then
    swaggeruiChosen=true
  fi
fi

if [[ "$swaggeruiChosen" = "true" ]]; then
  echo "Swagger UI enabled"
  if [[ "$restChosen" = "false" ]]; then
    echo "You did not enable the REST API. Swagger UI will not be able to send any requests to this Operaton instance."
  fi
  # Static resources are disabled in the default configuration, so expose only the Swagger UI directory
  export SPRING_WEB_RESOURCES_STATIC_LOCATIONS="${SPRING_WEB_RESOURCES_STATIC_LOCATIONS:+${SPRING_WEB_RESOURCES_STATIC_LOCATIONS},}file:${SWAGGERUI_PATH}"
fi

CMD="/operaton/internal/run.sh start"

wait_for_it

# shellcheck disable=SC2086
exec ${CMD} "${args[@]}"
