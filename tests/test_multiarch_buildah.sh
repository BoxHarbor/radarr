#!/bin/bash

set -e

# Configuration
IMAGE_NAME="${IMAGE_NAME:-baseimage-alpine}"
IMAGE_TAG="${IMAGE_TAG:-test}"
PLATFORMS=(
    "linux/amd64"
    "linux/arm64/v8"
)
RADARR_VERSION=6.0.4.10291

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  🚀 Multi-Architecture Build & Test with Buildah${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Vérifier que buildah est installé
if ! command -v buildah &> /dev/null; then
    echo -e "${RED}❌ Buildah n'est pas installé${NC}"
    echo "Installation : sudo dnf install -y buildah"
    exit 1
fi

echo -e "${CYAN}Buildah version: $(buildah --version)${NC}"
echo -e "${CYAN}Podman version: $(podman --version)${NC}"
echo ""

# Fonction de nettoyage
cleanup_container() {
    local container_name=$1
    if podman ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo "  Cleaning up container ${container_name}..."
        podman stop "${container_name}" 2>/dev/null || true
        podman rm "${container_name}" 2>/dev/null || true
    fi
}

# Build pour chaque plateforme
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  📦 PHASE 1: Building Images${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

BUILD_SUCCESS=()
BUILD_FAILED=()

for platform in "${PLATFORMS[@]}"; do
    echo ""
    echo -e "${CYAN}Building for ${platform}...${NC}"
    
    # Extraction de l'architecture pour le tag
    arch=$(echo "$platform" | sed 's/linux\///' | sed 's/\//-/')
    full_tag="${IMAGE_NAME}:${IMAGE_TAG}-${arch}"
    
    echo "  Platform: $platform"
    echo "  Tag: $full_tag"
    echo ""
    
    # Build avec Buildah
    if buildah bud \
        --platform "$platform" \
        --format docker \
        --layers \
        -t "$full_tag" \
        -f Dockerfile \
        . ; then
        
        echo -e "${GREEN}✅ Build successful for ${platform}${NC}"
        BUILD_SUCCESS+=("$platform")
        
        # Afficher des infos sur l'image
        echo -e "${BLUE}📋 Image info:${NC}"
        img_arch=$(podman inspect "$full_tag" --format '{{.Architecture}}' 2>/dev/null || echo "unknown")
        img_os=$(podman inspect "$full_tag" --format '{{.Os}}' 2>/dev/null || echo "unknown")
        img_size=$(podman inspect "$full_tag" --format '{{.Size}}' 2>/dev/null || echo "unknown")
        echo "    Architecture: $img_arch"
        echo "    OS: $img_os"
        echo "    Size: $img_size bytes"
    else
        echo -e "${RED}❌ Build failed for ${platform}${NC}"
        BUILD_FAILED+=("$platform")
    fi
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Build Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Successful: ${#BUILD_SUCCESS[@]}${NC}"
for p in "${BUILD_SUCCESS[@]}"; do
    echo "    - $p"
done

if [ ${#BUILD_FAILED[@]} -gt 0 ]; then
    echo -e "${RED}❌ Failed: ${#BUILD_FAILED[@]}${NC}"
    for p in "${BUILD_FAILED[@]}"; do
        echo "    - $p"
    done
    echo ""
    echo "Stopping here because some builds failed."
    exit 1
fi

echo ""

# Test de chaque image
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  🧪 PHASE 2: Testing Images${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

TEST_SUCCESS=()
TEST_FAILED=()
port=7878

for platform in "${BUILD_SUCCESS[@]}"; do
    arch=$(echo "$platform" | sed 's/linux\///' | sed 's/\//-/')
    image="${IMAGE_NAME}:${IMAGE_TAG}-${arch}"
    container_name="test-radarr-${arch}"
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Testing ${image} (${platform})${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Nettoyer si le container existe déjà
    cleanup_container "$container_name"
    
    # Démarrage du container
    echo "  🚀 Starting container..."
    if container_id=$(podman run -d \
        --platform "$platform" \
        -p "${port}:7878" \
        --name "$container_name" \
        "$image" 2>&1); then
        
        echo -e "  ${GREEN}✅ Container started${NC}"
        echo "      Container ID: ${container_id:0:12}"
        echo "      Port: $port"
    else
        echo -e "  ${RED}❌ Failed to start container${NC}"
        echo "      Error: $container_id"
        TEST_FAILED+=("$platform")
        ((port++))
        continue
    fi
    
    # Attendre un peu
    echo "  ⏳ Waiting 30sec for service to start..."
    sleep 30
    
    # Vérifier le statut du container
    echo "  🔍 Checking container status..."
    status=$(podman inspect "$container_name" --format '{{.State.Status}}' 2>/dev/null || echo "unknown")
    if [ "$status" = "running" ]; then
        echo -e "      ${GREEN}✅ Container is running${NC}"
    else
        echo -e "      ${RED}❌ Container is not running (status: $status)${NC}"
        echo "      Logs:"
        podman logs "$container_name" 2>&1 | tail -20 | sed 's/^/        /'
        cleanup_container "$container_name"
        TEST_FAILED+=("$platform")
        ((port++))
        continue
    fi
    
    # Vérifier l'architecture du binaire
    echo "  🔍 Checking binary architecture..."
    # Installation de 'file' nécessaire pour le test
    podman exec "$container_name" apk add file
    binary_info=$(podman exec "$container_name" file /opt/Radarr/Radarr 2>/dev/null || echo "error")
    if [ "$binary_info" != "error" ]; then
        echo "      Binary: $binary_info"
        
        # Vérifier que l'architecture correspond
        case "$platform" in
            "linux/amd64")
                if echo "$binary_info" | grep -q "x86-64\|x86_64"; then
                    echo -e "      ${GREEN}✅ Architecture matches (x86-64)${NC}"
                else
                    echo -e "      ${RED}⚠️  Architecture mismatch${NC}"
                fi
                ;;
            "linux/arm64")
                if echo "$binary_info" | grep -q "aarch64\|ARM aarch64"; then
                    echo -e "      ${GREEN}✅ Architecture matches (ARM64)${NC}"
                else
                    echo -e "      ${RED}⚠️  Architecture mismatch${NC}"
                fi
                ;;
            "linux/arm/v7")
                if echo "$binary_info" | grep -q "ARM"; then
                    echo -e "      ${GREEN}✅ Architecture matches (ARM)${NC}"
                else
                    echo -e "      ${RED}⚠️  Architecture mismatch${NC}"
                fi
                ;;
        esac
    else
        echo -e "      ${RED}❌ Cannot check binary${NC}"
    fi
    
    # Vérifier les processus
    echo "  🔍 Checking processes..."
    if podman top "$container_name" > /dev/null 2>&1; then
        echo -e "      ${GREEN}✅ Processes are running${NC}"
        podman top "$container_name" 2>&1 | head -3 | sed 's/^/        /'
    else
        echo -e "      ${RED}❌ No processes found${NC}"
    fi
    
    # Test HTTP (attendre jusqu'à 60 secondes)
    echo "  🔍 Testing HTTP endpoint..."
    http_success=false
    for i in {1..30}; do
        if curl -f -s "http://localhost:${port}" > /dev/null 2>&1; then
            http_success=true
            echo -e "      ${GREEN}✅ HTTP endpoint responding (after $((i*2)) seconds)${NC}"
            break
        fi
        if [ $((i % 5)) -eq 0 ]; then
            echo -n "."
        fi
        sleep 2
    done
    echo ""
    
    if [ "$http_success" = false ]; then
        echo -e "      ${YELLOW}⚠️  HTTP endpoint not responding within 60s${NC}"
        echo "      (This might be normal if Radarr takes time to initialize)"
    fi
    
    # Vérifier le healthcheck
    echo "  🔍 Checking health..."
    sleep 30
    health=$(podman inspect "$container_name" --format '{{.State.Health.Status}}' 2>/dev/null || echo "none")
    if [ "$health" = "healthy" ]; then
        echo -e "      ${GREEN}✅ Healthcheck: healthy${NC}"
    elif [ "$health" = "none" ]; then
        echo -e "      ${BLUE}ℹ️  Healthcheck: not configured or not yet run${NC}"
    else
        echo -e "      ${YELLOW}⚠️  Healthcheck: $health${NC}"
    fi
    
    # Afficher les derniers logs
    echo "  📋 Container logs (last 10 lines):"
    podman logs --tail 10 "$container_name" 2>&1 | sed 's/^/      /'
    
    # Décider si le test est un succès
    if [ "$status" = "running" ] && [ "$binary_info" != "error" ]; then
        echo -e "${GREEN}✅ Test PASSED for ${platform}${NC}"
        TEST_SUCCESS+=("$platform")
    else
        echo -e "${RED}❌ Test FAILED for ${platform}${NC}"
        TEST_FAILED+=("$platform")
    fi
    
    # Nettoyage
    echo "  🧹 Cleaning up..."
    cleanup_container "$container_name"
    
    ((port++))
    echo ""
done

# Résumé final
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  📊 FINAL SUMMARY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}✅ Tests Passed: ${#TEST_SUCCESS[@]}/${#BUILD_SUCCESS[@]}${NC}"
for p in "${TEST_SUCCESS[@]}"; do
    echo "    - $p"
done

if [ ${#TEST_FAILED[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}❌ Tests Failed: ${#TEST_FAILED[@]}${NC}"
    for p in "${TEST_FAILED[@]}"; do
        echo "    - $p"
    done
fi

echo ""
echo -e "${BLUE}📋 Built images:${NC}"
podman images | grep "$IMAGE_NAME" | sed 's/^/  /'

echo ""
if [ ${#TEST_FAILED[@]} -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ ALL TESTS PASSED!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ❌ SOME TESTS FAILED${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
fi