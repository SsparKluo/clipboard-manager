# syntax=docker/dockerfile:1
FROM ubuntu:24.04

# Prevent interactive prompts during apt install
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    curl \
    git \
    pkg-config \
    # Rust/Cargo dependencies
    libssl-dev \
    # libcosmic dependencies
    libxkbcommon-dev \
    libwayland-dev \
    libegl1-mesa-dev \
    libgles2-mesa-dev \
    libvulkan-dev \
    # Additional dependencies for COSMIC/libcosmic
    libseat-dev \
    libinput-dev \
    libudev-dev \
    libgbm-dev \
    libdrm-dev \
    libpixman-1-dev \
    libxkbcommon-x11-dev \
    libdisplay-info-dev \
    libliftoff-dev \
    liblcms2-dev \
    # SQLite for sqlx
    libsqlite3-dev \
    # Just
    just \
    && rm -rf /var/lib/apt/lists/*

# Install Rust 1.88+ (required by the project)
# Using rustup to get latest stable
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
ENV PATH="/root/.cargo/bin:${PATH}"

# Verify Rust version
RUN rustc --version && cargo --version

# Set working directory
WORKDIR /build

# Copy project files
COPY . .

# Build the project
RUN just build-release

# Default command outputs the binary path
CMD ["sh", "-c", "echo 'Build complete. Binary at:' && ls -la target/release/cosmic-ext-applet-clipboard-manager"]
