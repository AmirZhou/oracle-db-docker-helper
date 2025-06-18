---

# Oracle Docker Manager

This repository contains a simple yet powerful **Bash script (`manage-oracle.sh`)** to streamline the management of your Oracle Database container, built on the `limslee/oracle-database:23ai-free` Docker image. It handles starting, stopping, and providing connection details, supporting both Docker named volumes and host directory mounts for data persistence.

---

## Features

- **Easy Container Management:** Start, stop, check status, view logs, and remove your Oracle container with single commands.
- **Flexible Data Persistence:** Choose between Docker named volumes or host directory mounts for your database files.
- **Configurable:** Customize container name, Oracle image, port mapping, and database credentials via a `.env` file.
- **Connection Info:** Provides immediate connection details for SQL Developer and other clients upon startup.

---

## Getting Started

### Prerequisites

- [**Docker Desktop**](https://www.docker.com/products/docker-desktop/) or [**OrbStack**](https://orbstack.dev/) installed and running.

### Installation

1.  **Clone this repository:**

    ```bash
    git clone https://github.com/YOUR_USERNAME/oracle-docker-manager.git
    cd oracle-docker-manager
    ```

2.  **Create your `.env` file:**
    Copy the `.env.example` file to `.env` and fill in your desired configuration.

    ```bash
    cp .env.example .env
    # Open .env with your favorite editor and configure
    ```

    **Example `.env` configuration:**

    ```
    # Container Settings
    CONTAINER_NAME="my-oracle-23ai"
    ORACLE_IMAGE="limslee/oracle-database:23ai-free"
    ORACLE_PORT="1521" # Host port to map Oracle's 1521 port to

    # Data Persistence (Choose ONE method)
    ORACLE_DATA_VOLUME_TYPE="VOLUME" # Options: VOLUME or HOST_DIR
    # ORACLE_DATA_PATH="./oracle-data" # Required if ORACLE_DATA_VOLUME_TYPE="HOST_DIR"

    # Oracle Database Settings
    ORACLE_USER_PASSWORD="YourStrongPassword" # Sets SYS, SYSTEM, PDBADMIN password
    ORACLE_PDB="MYPDB" # Optional: Name for your Pluggable Database
    # ORACLE_CHARACTERSET="AL32UTF8" # Optional: Database character set
    ```

### Usage

Execute the `manage-oracle.sh` script with the desired command:

```bash
./manage-oracle.sh [command]
```

**Available Commands:**

- `start`: Creates and starts the Oracle container (or starts if it already exists).
- `stop`: Stops the Oracle container. Data is preserved.
- `status`: Shows the current status of the Oracle container.
- `logs`: Displays live logs from the Oracle container (useful for monitoring startup).
- `exec`: Opens a bash shell inside the running Oracle container.
- `rm`: Removes the Oracle container and optionally its associated data volume/directory.

**Example:**

```bash
./manage-oracle.sh start # Start your Oracle database
./manage-oracle.sh status # Check its status
./manage-oracle.sh logs # Watch the startup logs
```

---

## Contributing

Feel free to fork this repository, open issues, or submit pull requests.

---

## License

This project is open-sourced under the MIT License.

---
