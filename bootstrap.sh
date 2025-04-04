#!/usr/bin/env bash

set -e  # Exit immediately if a command exits with a non-zero status

# Function to display usage information
usage() {
    echo "Usage: $0 --cpu | --gpu | clean"
    exit 1
}

# Check if exactly one argument is provided
if [ "$#" -ne 1 ]; then
    usage
fi

# Assign the first argument to MODE
MODE=$1

# Validate the argument
if [ "$MODE" != "--cpu" ] && [ "$MODE" != "--gpu" ] && [ "$MODE" != "clean" ]; then
    usage
fi

# Function to clean build artifacts
clean_build_artifacts() {
    echo "Cleaning build artifacts..."

    # Remove the ./target directory
    if [ -d "./target" ]; then
        echo "Removing ./target directory..."
        rm -rf ./target
    else
        echo "./target directory does not exist. Skipping."
    fi

    # Remove the kalypso-cli binary
    if [ -f "./kalypso-cli" ]; then
        echo "Removing kalypso-cli binary..."
        rm -f ./kalypso-cli
    else
        echo "kalypso-cli binary does not exist. Skipping."
    fi

    # Remove application-specific binaries
    BINARY_HOST="./test-connection"
    BINARY_BENCHMARK="./benchmark"
    BINARY_PROVER="./kalypso-attestation-prover"

    for binary in "$BINARY_HOST" "$BINARY_BENCHMARK" "$BINARY_PROVER"; do
        if [ -f "$binary" ]; then
            echo "Removing $binary..."
            rm -f "$binary"
        else
            echo "$binary does not exist. Skipping."
        fi
    done

    echo "Clean up completed successfully."
}

if [ "$MODE" = "clean" ]; then
    clean_build_artifacts
    exit 0
fi

# Function to detect the operating system
detect_os() {
    OS_TYPE=$(uname)
    case "$OS_TYPE" in
        Linux*)     OS=Linux;;
        Darwin*)    OS=Mac;;
        *)          OS="Unknown"
    esac
    echo "$OS"
}

# Function to install packages on Linux
install_packages_linux() {
    # Operators are expected to fix these.
    set +e
    # sudo apt-get update
    # sudo apt-get install -y build-essential curl git
    set -e
}

# Function to install packages on macOS
install_packages_mac() {
    # Operators are expected to fix these.
    set +e

    # # Check if Homebrew is installed
    # if ! command -v brew >/dev/null 2>&1; then
    #     echo "Homebrew is not installed. Please install Homebrew from https://brew.sh/ and rerun the script."
    #     exit 1
    # fi
    # brew update
    # brew install curl git
    # # build-essential equivalent on macOS is Xcode Command Line Tools
    # if ! xcode-select -p >/dev/null 2>&1; then
    #     echo "Xcode Command Line Tools not found. Installing..."
    #     xcode-select --install
    #     echo "Please follow the on-screen instructions to complete the installation."
    #     exit 0
    # fi

    set -e
}

# Function to check CUDA and install essential system dependencies
check_cuda() {
    echo "Checking system dependencies for $MODE..."

    OS=$(detect_os)

    if [ "$OS" = "Linux" ]; then
        install_packages_linux
    elif [ "$OS" = "Mac" ]; then
        install_packages_mac
    else
        echo "Unsupported operating system: $OS"
        exit 1
    fi

    if [ "$MODE" = "--gpu" ]; then
        echo "Checking for CUDA installation..."

        if ! command -v nvcc >/dev/null 2>&1; then
            echo "CUDA is not installed. Please install the required NVIDIA drivers and CUDA toolkit."
            echo "Visit https://developer.nvidia.com/cuda-downloads for installation instructions."
            exit 1
        else
            echo "CUDA is already installed."
        fi
    fi
}

# Function to check if Docker is installed
check_docker() {
    echo "Checking for Docker installation..."

    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker is not installed. Please install Docker and ensure it's running."
        echo "Visit https://docs.docker.com/get-docker/ for installation instructions."
        exit 1
    else
        echo "Docker is already installed."
    fi

    if ! docker buildx version >/dev/null 2>&1; then
        echo "Docker Buildx is not installed. Please install Docker Buildx."
        echo "Visit https://docs.docker.com/build/concepts/overview/#buildx for installation instructions."
        exit 1
    else
        echo "Docker Buildx is already installed."
    fi
}

# Function to install Rust
install_rust() {
    if ! command -v rustc >/dev/null 2>&1; then
        echo "Rust is not installed. Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        # Load Rust environment
        # shellcheck source=/dev/null
        source "$HOME/.cargo/env"
    else
        echo "Rust is already installed."
        # Update Rust to the latest version
        rustup update
    fi

    # Ensure the stable toolchain is installed and set as default
    rustup install stable
    rustup default stable

    # Add Cargo to PATH if not already present
    case ":$PATH:" in
        *":$HOME/.cargo/bin:"*) echo "Cargo is already in PATH." ;;
        *) 
            echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
            echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.zshrc"
            export PATH="$HOME/.cargo/bin:$PATH"
            echo "Added Cargo to PATH."
            ;;
    esac
}

# Function to install rzup
install_rzup() {
    if ! command -v rzup >/dev/null 2>&1; then
        echo "rzup is not installed. Installing rzup..."
        curl -L https://risczero.com/install | bash
        # Load rzup environment if needed
        if [ -f "$HOME/.risc0/env" ]; then
            # shellcheck source=/dev/null
            source "$HOME/.risc0/env"
        fi
        # Run rzup install
        rzup install

        echo "Restart your terminal and do ./bootstrap.sh again for installing the remaining packages"
        exit 0
    else
        echo "rzup is already installed."
    fi

    # Add rzup to PATH if not already present
    RISCU_BIN_DIR="$HOME/.risc0/bin"
    case ":$PATH:" in
        *":$RISCU_BIN_DIR:"*) echo "rzup is already in PATH." ;;
        *)
            echo "export PATH=\"$RISCU_BIN_DIR:\$PATH\"" >> "$HOME/.bashrc"
            echo "export PATH=\"$RISCU_BIN_DIR:\$PATH\"" >> "$HOME/.zshrc"
            export PATH="$RISCU_BIN_DIR:$PATH"
            echo "Added rzup to PATH."
            ;;
    esac
}

# Function to run rzup installation steps
run_rzup_install_steps() {
    echo "Starting rzup installation steps..."

    # Verify that rzup is available
    if ! command -v rzup >/dev/null 2>&1; then
        echo "Error: rzup is not installed or not in PATH."
        echo "Please run the install_rzup function before proceeding."
        exit 1
    fi

    # Run 'rzup install'
    echo "Running 'rzup install'..."
    rzup install
    if [ $? -ne 0 ]; then
        echo "Error: 'rzup install' failed."
        exit 1
    fi
    echo "'rzup install' completed successfully."

    # Detect OS and architecture
    OS_NAME="$(uname -s)"
    ARCH_NAME="$(uname -m)"
    echo "Detected OS: $OS_NAME"
    echo "Detected Architecture: $ARCH_NAME"

    # Function to install cpp based on OS and architecture
    install_cpp() {
        local os="$1"
        local arch="$2"
        echo "Running 'rzup install cpp' for $os $arch..."
        rzup install cpp
        if [ $? -ne 0 ]; then
            echo "Error: 'rzup install cpp' failed for $os $arch."
            exit 1
        fi
        echo "'rzup install cpp' completed successfully for $os $arch."
    }

    # Conditional installation of cpp
    if [[ "$OS_NAME" == "Linux" && "$ARCH_NAME" == "x86_64" ]]; then
        install_cpp "Linux" "x86_64"
    elif [[ "$OS_NAME" == "Darwin" && "$ARCH_NAME" == "arm64" ]]; then
        install_cpp "macOS" "arm64"
    else
        echo "No 'rzup install cpp' required for OS '$OS_NAME' with architecture '$ARCH_NAME'. Skipping."
    fi

    echo "All rzup installation steps completed successfully."
}

# Function to build and install kalypso-cli
install_kalypso_cli() {
    KALYPSO_CLI="./kalypso-cli"

    if [ ! -f "$KALYPSO_CLI" ]; then
        echo "kalypso-cli binary not found in the current directory. Proceeding to build it."

        TEMP_DIR=$(mktemp -d)
        echo "Cloning kalypso-unified repository into $TEMP_DIR..."
        git clone https://github.com/marlinprotocol/kalypso-unified.git "$TEMP_DIR"

        cd "$TEMP_DIR"

        echo "Checking out the beta branch..."
        git checkout beta

        echo "Removing .cargo directory in kalypso-unified..."
        rm -rf .cargo

        echo "Building kalypso-cli using Cargo..."
        cargo build --release --bin kalypso-cli

        BUILT_BINARY="$TEMP_DIR/target/release/kalypso-cli"

        if [ ! -f "$BUILT_BINARY" ]; then
            echo "Failed to build kalypso-cli. Please check the build logs for errors."
            exit 1
        fi

        echo "Copying kalypso-cli binary to the current directory..."
        cp "$BUILT_BINARY" "$OLDPWD/kalypso-cli"
        chmod +x "$OLDPWD/kalypso-cli"

        echo "Removing the cloned kalypso-unified repository..."
        cd "$OLDPWD"
        rm -rf "$TEMP_DIR"

        echo "kalypso-cli has been successfully built and placed in the current directory."
    else
        echo "kalypso-cli binary already exists in the current directory."
    fi
}

# Function to check and build application-specific binaries
build_application_binaries() {
    BINARY_HOST="./test-connection"
    BINARY_BENCHMARK="./benchmark"
    BINARY_PROVER="./kalypso-attestation-prover"

    LOCK="./Cargo.lock"

    if [ -f "$LOCK" ]; then
        printf "Lock file %s is present.\n" "$LOCK"
    else
        printf "File %s not found.\n" "$LOCK"
    fi

    if [ -f "$BINARY_HOST" ] && [ -f "$BINARY_BENCHMARK" ] && [ -f "$BINARY_PROVER" ]; then
        echo "All application-specific binaries (test-connection, benchmark, kalypso-attestation-prover) are already built."
    else
        echo "One or more application-specific binaries are missing. Building them using Cargo..."
        if [ "$MODE" = "--gpu" ]; then
            cargo build --release --features gpu
        else
            cargo build --release
        fi
        echo "Application-specific binaries have been successfully built."

        # Define the paths to the built binaries
        TARGET_DIR="./target/release"
        BUILT_HOST="$TARGET_DIR/host"
        BUILT_BENCHMARK="$TARGET_DIR/benchmark"
        BUILT_PROVER="$TARGET_DIR/kalypso-attestation-prover"

        # Verify that the built binaries exist
        if [ -f "$BUILT_HOST" ] && [ -f "$BUILT_BENCHMARK" ] && [ -f "$BUILT_PROVER" ]; then
            echo "Copying application-specific binaries to the current directory..."

            # Copy the binaries to the cwd
            cp "$BUILT_HOST" "./test-connection"
            cp "$BUILT_BENCHMARK" "./benchmark"
            cp "$BUILT_PROVER" "./kalypso-attestation-prover"

            # Ensure the copied binaries are executable
            chmod +x "./test-connection" "./benchmark" "./kalypso-attestation-prover"

            echo "Copied application-specific binaries to the current directory successfully."
        else
            echo "Error: One or more binaries were not found in $TARGET_DIR."
            echo "Please check the build logs for any errors during the build process."
            exit 1
        fi
    fi
}

# Function to check if Docker is installed and running
check_docker_running() {
    echo "Checking Docker installation and status..."

    # Check if Docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        echo "Error: Docker is not installed on this system."
        echo "Please install Docker before proceeding."
        echo "Visit https://docs.docker.com/get-docker/ for installation instructions."
        exit 1
    else
        echo "Docker is installed."
    fi

    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        echo "Error: Docker daemon is not running."
        echo "Please start Docker and ensure it is running correctly."
        echo "On Linux, you can start Docker using:"
        echo "    sudo systemctl start docker"
        echo "On macOS, launch Docker Desktop from the Applications folder."
        exit 1
    else
        echo "Docker daemon is running."
    fi
}


# Main execution flow
echo "Starting bootstrap process..."

check_cuda
check_docker
check_docker_running
install_rust
install_rzup
run_rzup_install_steps
install_kalypso_cli
build_application_binaries

echo "Bootstrap completed successfully."