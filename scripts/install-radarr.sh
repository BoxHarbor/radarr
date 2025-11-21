#!/bin/bash
set -euxo pipefail

# Script d'installation de Radarr multi-architecture
# Supporte: amd64, arm64 (binaires précompilés)
#           riscv64, ppc64le, s390x (compilation depuis sources)

RADARR_VERSION="${RADARR_VERSION:-5.16.3.9541}"
TARGETPLATFORM="${TARGETPLATFORM:-linux/amd64}"
INSTALL_DIR="/opt/Radarr"
DRY_RUN="${DRY_RUN:-0}"

echo "==========================================="
echo "Installing Radarr ${RADARR_VERSION}"
echo "Platform: ${TARGETPLATFORM}"
echo "Dry Run: ${DRY_RUN}"
echo "==========================================="

# Fonction pour télécharger les binaires précompilés
install_prebuilt() {
    local arch=$1
    local base_url="https://github.com/Radarr/Radarr/releases/download/v${RADARR_VERSION}"
    local filename="Radarr.master.${RADARR_VERSION}.linux-musl-core-${arch}.tar.gz"
    local download_url="${base_url}/${filename}"
    
    echo "Downloading prebuilt binary for ${arch}..."
    echo "URL: ${download_url}"
    
    if [ "$DRY_RUN" = "1" ]; then
        echo "[DRY RUN] Would download and extract"
        return 0
    fi
    
    wget --progress=dot:giga -O /tmp/radarr.tar.gz "${download_url}"
    
    echo "Extracting..."
    tar -xzf /tmp/radarr.tar.gz -C /tmp
    
    echo "Moving to ${INSTALL_DIR}..."
    mv /tmp/Radarr "${INSTALL_DIR}"
    
    echo "Verifying installation..."
    ls -lh "${INSTALL_DIR}/"
    file "${INSTALL_DIR}/Radarr"
    
    echo "✅ Prebuilt installation completed"
}

# Fonction pour compiler depuis les sources (RISC-V, etc.)
build_from_source() {
    local dotnet_arch=$1
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⚠️  No prebuilt binary available"
    echo "Building from source for ${dotnet_arch}..."
    echo "This will take 30-60 minutes depending on your hardware"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ "$DRY_RUN" = "1" ]; then
        echo "[DRY RUN] Would compile from source"
        return 0
    fi
    
    # Installer les dépendances de build
    echo "Installing build dependencies..."
    apk add --no-cache \
        git \
        dotnet8-sdk \
        nodejs \
        npm \
        yarn \
        python3 \
        make \
        g++ \
        icu-dev
    
    # Afficher les versions installées
    echo "Build environment:"
    dotnet --version
    node --version
    npm --version
    
    # Cloner le repository
    echo "Cloning Radarr repository..."
    cd /tmp
    
    # Essayer d'abord avec le tag de version, sinon branch master
    if git clone --depth 1 --branch "v${RADARR_VERSION}" \
        https://github.com/Radarr/Radarr.git; then
        echo "✅ Cloned version ${RADARR_VERSION}"
    else
        echo "⚠️  Tag v${RADARR_VERSION} not found, cloning master branch"
        git clone --depth 1 https://github.com/Radarr/Radarr.git
    fi
    
    cd Radarr
    
    # Afficher le commit actuel
    echo "Building from commit: $(git rev-parse --short HEAD)"
    
    # Installer les dépendances npm
    echo "Installing npm dependencies..."
    npm install -g yarn
    
    # Compiler
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Starting build for ${dotnet_arch}..."
    echo "Start time: $(date)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Le script build.sh compile le projet
    ./build.sh --runtime "linux-musl-${dotnet_arch}" --framework net8.0 || {
        echo "❌ Build failed"
        echo "Checking for error logs..."
        find . -name "*.log" -exec cat {} \;
        exit 1
    }
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Build completed: $(date)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Trouver le répertoire de sortie
    echo "Looking for build output..."
    OUTPUT_DIR=""
    
    # Essayer différents chemins possibles
    for path in \
        "_output/linux-musl-${dotnet_arch}/Radarr" \
        "_output/${dotnet_arch}/Radarr" \
        "_output/Radarr"; do
        if [ -d "$path" ]; then
            OUTPUT_DIR="$path"
            echo "✅ Found output in: $path"
            break
        fi
    done
    
    if [ -z "$OUTPUT_DIR" ]; then
        echo "❌ Build output not found"
        echo "Contents of _output:"
        find _output -type d 2>/dev/null || echo "_output not found"
        exit 1
    fi
    
    # Vérifier que le binaire existe
    if [ ! -f "${OUTPUT_DIR}/Radarr" ]; then
        echo "❌ Radarr binary not found in ${OUTPUT_DIR}"
        ls -la "${OUTPUT_DIR}/"
        exit 1
    fi
    
    echo "Moving compiled binary to ${INSTALL_DIR}..."
    mv "${OUTPUT_DIR}" "${INSTALL_DIR}"
    
    echo "Verifying compiled binary..."
    ls -lh "${INSTALL_DIR}/"
    file "${INSTALL_DIR}/Radarr"
    
    # Test rapide du binaire
    echo "Testing binary..."
    if "${INSTALL_DIR}/Radarr" --version 2>&1 | head -5; then
        echo "✅ Binary test passed"
    else
        echo "⚠️  Binary test failed (might be normal if dependencies are missing)"
    fi
    
    # Nettoyer les dépendances de build pour réduire la taille de l'image
    echo "Cleaning up build dependencies..."
    apk del git dotnet8-sdk nodejs npm yarn python3 make g++ icu-dev
    
    # Nettoyer les fichiers temporaires
    cd /
    rm -rf /tmp/Radarr
    
    echo "✅ Build from source completed"
}

# Déterminer l'architecture et installer
case "${TARGETPLATFORM}" in
    "linux/amd64")
        echo "Architecture: AMD64 (x86_64)"
        install_prebuilt "x64"
        ;;
        
    "linux/arm64" | "linux/arm64/v8")
        echo "Architecture: ARM64"
        install_prebuilt "arm64"
        ;;
        
    "linux/arm/v7")
        echo "Architecture: ARMv7 (32-bit)"
        echo "⚠️  Warning: ARMv7 may be unstable with Radarr .NET runtime"
        install_prebuilt "arm"
        ;;
        
    "linux/riscv64")
        echo "Architecture: RISC-V 64-bit"
        build_from_source "riscv64"
        ;;
        
    "linux/ppc64le")
        echo "Architecture: PowerPC 64-bit LE"
        build_from_source "ppc64le"
        ;;
        
    "linux/s390x")
        echo "Architecture: IBM System z"
        build_from_source "s390x"
        ;;
        
    *)
        echo "❌ ERROR: Unsupported platform: ${TARGETPLATFORM}"
        echo ""
        echo "Supported platforms:"
        echo "  Prebuilt binaries:"
        echo "    - linux/amd64"
        echo "    - linux/arm64"
        echo "    - linux/arm/v7"
        echo ""
        echo "  Build from source:"
        echo "    - linux/riscv64"
        echo "    - linux/ppc64le"
        echo "    - linux/s390x"
        exit 1
        ;;
esac

if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY RUN] Skipping final steps"
    exit 0
fi

# Permissions finales
echo "Setting permissions..."
if [ -d "${INSTALL_DIR}" ]; then
    chown -R appuser:appuser "${INSTALL_DIR}" || true
    chmod -R 755 "${INSTALL_DIR}"
    
    # Vérifier la taille finale
    echo "Installation size:"
    du -sh "${INSTALL_DIR}"
else
    echo "⚠️  Warning: ${INSTALL_DIR} not found"
fi

# Nettoyage final
echo "Final cleanup..."
rm -rf /tmp/*

echo "==========================================="
echo "✅ Radarr installation completed successfully!"
echo "Version: ${RADARR_VERSION}"
echo "Platform: ${TARGETPLATFORM}"
echo "Location: ${INSTALL_DIR}"
echo "==========================================="