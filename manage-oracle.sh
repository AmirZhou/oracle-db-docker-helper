#!/bin/bash

# manage-oracle.sh
#
# A script to manage the limslee/oracle-database:23ai-free container using Docker (compatible with OrbStack).
# This script handles starting, stopping, and providing connection information for your Oracle database.
#
# Usage: ./manage-oracle.sh {start|stop|status|logs|exec|rm}
#
# Requirements:
#   - Docker Desktop or OrbStack installed and running.
#   - A .env file in the same directory with your Oracle configuration.

# --- Configuration Loading ---
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
    echo "Loading configuration from $ENV_FILE file..."
    # set -a: automatically export all variables
    # source: reads and executes commands from the file
    # set +a: disable automatic export
    set -a
    source "$ENV_FILE"
    set +a
else
    echo "Error: $ENV_FILE file not found. Please create it with your Oracle configuration."
    exit 1
fi

# --- Validate Essential Variables ---
if [ -z "$CONTAINER_NAME" ] || [ -z "$ORACLE_IMAGE" ] || [ -z "$ORACLE_PORT" ]; then
    echo "Error: Essential variables (CONTAINER_NAME, ORACLE_IMAGE, ORACLE_PORT) are not set in $ENV_FILE."
    exit 1
fi

# --- Determine Volume Mount Strategy ---
VOLUME_MOUNT_ARG=""
ORACLE_VOLUME_NAME="${CONTAINER_NAME}-data" # Consistent named volume

if [ "$ORACLE_DATA_VOLUME_TYPE" == "VOLUME" ]; then
    VOLUME_MOUNT_ARG="-v $ORACLE_VOLUME_NAME:/opt/oracle/oradata"
    echo "Using Docker named volume for persistence: '$ORACLE_VOLUME_NAME'"
elif [ "$ORACLE_DATA_VOLUME_TYPE" == "HOST_DIR" ]; then
    if [ -z "$ORACLE_DATA_PATH" ]; then
        echo "Error: ORACLE_DATA_PATH must be set in $ENV_FILE for HOST_DIR type."
        exit 1
    fi
    # Ensure the host directory exists
    mkdir -p "$ORACLE_DATA_PATH" || { echo "Error: Could not create host directory '$ORACLE_DATA_PATH'. Check permissions."; exit 1; }
    VOLUME_MOUNT_ARG="-v $ORACLE_DATA_PATH:/opt/oracle/oradata"
    echo "Using host directory for persistence: '$ORACLE_DATA_PATH'"
else
    echo "Warning: No persistence configured (ORACLE_DATA_VOLUME_TYPE not 'VOLUME' or 'HOST_DIR'). Data will NOT persist across container restarts!"
fi

# --- Common Docker Run Arguments ---
# Set memory and CPUs for the container. Adjust as needed.
# For limslee/oracle-database:23ai-free, 4GB memory and 2 CPUs are good starting points.
DOCKER_RUN_ARGS="--name $CONTAINER_NAME --publish $ORACLE_PORT:1521 --memory 4g --cpus 2"

# --- Oracle Environment Variables ---

# Oracle specific environment variables
if [ -n "$ORACLE_USER_PASSWORD" ]; then
    ENV_VARS_ARGS="$ENV_VARS_ARGS -e ORACLE_PWD=$ORACLE_USER_PASSWORD"
fi

if [ -n "$ORACLE_PDB" ]; then
    ENV_VARS_ARGS="$ENV_VARS_ARGS -e ORACLE_PDB=$ORACLE_PDB"
fi

if [ -n "$ORACLE_CHARACTERSET" ]; then
    ENV_VARS_ARGS="$ENV_VARS_ARGS -e ORACLE_CHARACTERSET=$ORACLE_CHARACTERSET"
fi

# --- Script Actions ---
case "$1" in
    start)
        echo "Attempting to start Oracle Database container '$CONTAINER_NAME'..."

        # Check if container already exists
        if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
            echo "Container '$CONTAINER_NAME' already exists."
            STATUS=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME")
            if [ "$STATUS" == "running" ]; then
                echo "Container '$CONTAINER_NAME' is already running."
            else
                echo "Starting existing container '$CONTAINER_NAME'..."
                docker start "$CONTAINER_NAME"
            fi
        else
            echo "Creating and starting new Oracle Database container '$CONTAINER_NAME'..."
            echo "Image: $ORACLE_IMAGE"
            echo "Volume Mount: $VOLUME_MOUNT_ARG"
            echo "Port Mapping: $ORACLE_PORT:1521"
            echo "Environment Vars: $ENV_VARS_ARGS"

            docker pull "$ORACLE_IMAGE" || { echo "Error: Failed to pull Docker image '$ORACLE_IMAGE'. Check image name or network connection."; exit 1; }
            docker run -d \
                $DOCKER_RUN_ARGS \
                $ENV_VARS_ARGS \
                $VOLUME_MOUNT_ARG \
                "$ORACLE_IMAGE" \
                || { echo "Error: Failed to start Docker container. Check previous errors."; exit 1; }

            echo "Container '$CONTAINER_NAME' started. Database initialization in progress..."
        fi

        echo ""
        echo "=== Connection Information ==="
        echo "Monitor startup progress: docker logs $CONTAINER_NAME -f"
        echo "Database will be ready when you see messages like 'Database [ORACLE_SID] is open and available.'"
        echo ""

        # Give the container a moment to initialize enough for inspect to work reliably
        sleep 5

        LOCAL_IP="localhost" # On Mac/Windows, exposed ports map to localhost for Docker Desktop/OrbStack
        
        echo "Connect to Oracle at: $LOCAL_IP:$ORACLE_PORT"
        echo ""
        echo "Database Services (after initialization completes):"
        echo "  CDB: $CONTAINER_NAME" # For limslee/oracle-database:23ai-free, ORACLE_SID is the CDB service name.
        if [ -n "$ORACLE_PDB" ]; then
            echo "  PDB: $ORACLE_PDB"
        else
            echo "  PDB: ${CONTAINER_NAME}PDB1 (default PDB created by image if ORACLE_PDB is not set)"
        fi
        echo ""
        echo "SQL Developer Connection Details:"
        echo "  Connection Type: Basic"
        echo "  Role: SYSDBA"
        echo "  Username: SYS"
        if [ -n "$ORACLE_USER_PASSWORD" ]; then
            echo "  Password: $ORACLE_USER_PASSWORD"
        else
            echo "  Password: Look in logs for auto-generated password if ORACLE_USER_PASSWORD was not set."
        fi
        echo ""
        echo "  For CDB (Service Name):"
        echo "    Hostname: $LOCAL_IP"
        echo "    Port: $ORACLE_PORT"
        echo "    Service Name: $CONTAINER_NAME"
        echo ""
        echo "  For PDB (Service Name):"
        echo "    Hostname: $LOCAL_IP"
        echo "    Port: $ORACLE_PORT"
        if [ -n "$ORACLE_PDB" ]; then
            echo "    Service Name: $ORACLE_PDB"
        else
            echo "    Service Name: ${CONTAINER_NAME}PDB1 (or check logs for exact PDB name)"
        fi
        ;;

    stop)
        echo "Stopping Oracle Database container '$CONTAINER_NAME'..."
        if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
            docker stop "$CONTAINER_NAME" || { echo "Error: Failed to stop container '$CONTAINER_NAME'."; exit 1; }
            echo "Container '$CONTAINER_NAME' stopped."
            if [ "$ORACLE_DATA_VOLUME_TYPE" == "VOLUME" ]; then
                echo "Data is preserved in Docker named volume: '$ORACLE_VOLUME_NAME'"
            elif [ "$ORACLE_DATA_VOLUME_TYPE" == "HOST_DIR" ]; then
                echo "Data is preserved in host directory: '$ORACLE_DATA_PATH'"
            fi
        else
            echo "Container '$CONTAINER_NAME' does not exist or is not running."
        fi
        ;;

    rm)
        echo "Removing Oracle Database container '$CONTAINER_NAME' and associated data..."
        if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
            docker stop "$CONTAINER_NAME" > /dev/null 2>&1
            docker rm "$CONTAINER_NAME" || { echo "Error: Failed to remove container '$CONTAINER_NAME'."; exit 1; }
            echo "Container '$CONTAINER_NAME' removed."

            if [ "$ORACLE_DATA_VOLUME_TYPE" == "VOLUME" ]; then
                if docker volume ls --format '{{.Name}}' | grep -q "^$ORACLE_VOLUME_NAME$"; then
                    read -p "WARNING: This will also remove the Docker named volume '$ORACLE_VOLUME_NAME' and ALL DATABASE DATA. Are you sure? (y/N): " -n 1 -r
                    echo # Move to a new line
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        docker volume rm "$ORACLE_VOLUME_NAME" || { echo "Error: Failed to remove volume '$ORACLE_VOLUME_NAME'."; exit 1; }
                        echo "Docker named volume '$ORACLE_VOLUME_NAME' removed."
                    else
                        echo "Volume removal cancelled. Database data for '$ORACLE_VOLUME_NAME' is preserved."
                    fi
                else
                    echo "Docker named volume '$ORACLE_VOLUME_NAME' does not exist."
                fi
            elif [ "$ORACLE_DATA_VOLUME_TYPE" == "HOST_DIR" ]; then
                 read -p "WARNING: This will remove the host directory '$ORACLE_DATA_PATH' and ALL DATABASE DATA. Are you sure? (y/N): " -n 1 -r
                 echo # Move to a new line
                 if [[ $REPLY =~ ^[Yy]$ ]]; then
                    # Be very careful with rm -rf!
                    if [ -d "$ORACLE_DATA_PATH" ]; then
                        rm -rf "$ORACLE_DATA_PATH" || { echo "Error: Failed to remove host directory '$ORACLE_DATA_PATH'. Check permissions."; exit 1; }
                        echo "Host directory '$ORACLE_DATA_PATH' removed."
                    else
                        echo "Host directory '$ORACLE_DATA_PATH' does not exist."
                    fi
                 else
                     echo "Host directory removal cancelled. Database data for '$ORACLE_DATA_PATH' is preserved."
                 fi
            fi
        else
            echo "Container '$CONTAINER_NAME' does not exist."
        fi
        ;;

    status)
        echo "Checking status of Oracle Database container '$CONTAINER_NAME'..."
        if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
            docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
            echo ""
            if docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q "true"; then
                echo "Container '$CONTAINER_NAME' is running."
                echo "Access Oracle via: localhost:$ORACLE_PORT"
            else
                echo "Container '$CONTAINER_NAME' is not running."
            fi
        else
            echo "Container '$CONTAINER_NAME' does not exist."
        fi
        ;;

    logs)
        echo "Displaying logs for Oracle Database container '$CONTAINER_NAME'. Press Ctrl+C to exit."
        docker logs -f "$CONTAINER_NAME"
        ;;

    exec)
        echo "Executing bash shell in Oracle Database container '$CONTAINER_NAME'..."
        docker exec -it "$CONTAINER_NAME" bash
        ;;

    *)
        echo "Usage: $0 {start|stop|status|logs|exec|rm}"
        echo ""
        echo "Commands:"
        echo "  start   - Creates and starts the Oracle container (or starts if already exists)."
        echo "  stop    - Stops the Oracle container. Data is preserved."
        echo "  status  - Shows the current status of the Oracle container."
        echo "  logs    - Displays live logs from the Oracle container (useful for monitoring startup)."
        echo "  exec    - Opens a bash shell inside the running Oracle container."
        echo "  rm      - Removes the Oracle container and optionally its data volume/directory."
        echo ""
        echo "Remember to configure your .env file before starting."
        exit 1
        ;;
esac

exit 0