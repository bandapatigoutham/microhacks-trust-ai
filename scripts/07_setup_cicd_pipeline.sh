#!/bin/bash
# Setup CI/CD Pipeline with GitHub Actions for Evaluation Workflow
#
# This script automates Lab 3.1 from Challenge 3:
#   Step 1: Configure the AZD pipeline for GitHub
#   Step 2: Interactive prompts (guided)
#   Step 3: Capture Service Principal details
#   Step 4: Assign Azure permissions (Cognitive Services OpenAI Contributor)
#   Step 5: Trigger first workflow run
#
# Prerequisites:
#   - Azure CLI installed and logged in (az login)
#   - Azure Developer CLI installed and logged in (azd auth login)
#   - GitHub CLI installed and logged in (gh auth login)
#   - Application already deployed and running
#   - This repo is forked to your GitHub account
#
# Usage:
#   ./07_setup_cicd_pipeline.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN} Lab 3.1 – CI/CD Pipeline Setup             ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# -------------------------------------------------------------------
# Preflight checks
# -------------------------------------------------------------------
echo -e "${YELLOW}Checking prerequisites...${NC}"

command -v az >/dev/null 2>&1 || { echo -e "${RED}ERROR: Azure CLI (az) is not installed.${NC}"; exit 1; }
command -v azd >/dev/null 2>&1 || { echo -e "${RED}ERROR: Azure Developer CLI (azd) is not installed.${NC}"; exit 1; }
command -v gh >/dev/null 2>&1 || { echo -e "${RED}ERROR: GitHub CLI (gh) is not installed.${NC}"; exit 1; }

# Verify logins
az account show >/dev/null 2>&1 || { echo -e "${RED}ERROR: Not logged into Azure CLI. Run 'az login' first.${NC}"; exit 1; }
azd auth login --check-status >/dev/null 2>&1 || { echo -e "${RED}ERROR: Not logged into AZD. Run 'azd auth login' first.${NC}"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo -e "${RED}ERROR: Not logged into GitHub CLI. Run 'gh auth login' first.${NC}"; exit 1; }

echo -e "${GREEN}✓ All prerequisites met.${NC}"
echo ""

# -------------------------------------------------------------------
# Step 1 & 2: Configure the pipeline (interactive)
# -------------------------------------------------------------------
echo -e "${CYAN}----------------------------------------------${NC}"
echo -e "${CYAN} Step 1 & 2: Configure AZD Pipeline           ${NC}"
echo -e "${CYAN}----------------------------------------------${NC}"
echo ""
echo -e "${YELLOW}This will run 'azd pipeline config --provider github'.${NC}"
echo -e "${YELLOW}When prompted, answer as follows:${NC}"
echo -e "  - Would you like to add azure-dev.yml? ${GREEN}Yes${NC}"
echo -e "  - Log in using Github CLI?             ${GREEN}Yes${NC}"
echo -e "  - Preferred protocol?                  ${GREEN}HTTPS${NC}"
echo -e "  - Authenticate git with GitHub creds?  ${GREEN}Yes${NC}"
echo -e "  - Auth type?                           ${GREEN}Federated Service Principal (SP + OIDC)${NC}"
echo ""
read -p "Press Enter to continue (or Ctrl+C to abort)..."
echo ""

cd "$ROOT_DIR"

# Capture output to extract the Service Principal name
AZD_OUTPUT=$(azd pipeline config --provider github 2>&1 | tee /dev/tty)

echo ""
echo -e "${GREEN}✓ Pipeline configuration complete.${NC}"
echo ""

# -------------------------------------------------------------------
# Step 3: Capture Service Principal details
# -------------------------------------------------------------------
echo -e "${CYAN}----------------------------------------------${NC}"
echo -e "${CYAN} Step 3: Capture Service Principal Details     ${NC}"
echo -e "${CYAN}----------------------------------------------${NC}"
echo ""

# Try to extract SP name from azd output
SP_NAME=$(echo "$AZD_OUTPUT" | grep -oP 'Creating service principal \K[^\s(]+' || true)

if [ -z "$SP_NAME" ]; then
    echo -e "${YELLOW}Could not auto-detect the Service Principal name from output.${NC}"
    read -p "Enter the Service Principal app name (e.g. az-dev-XXXXXXXXX): " SP_NAME
fi

echo -e "${GREEN}Service Principal name: ${SP_NAME}${NC}"

# Look up the SP Object ID using Azure CLI
echo -e "${YELLOW}Looking up Service Principal Object ID...${NC}"
SP_OBJECT_ID=$(az ad sp list --display-name "$SP_NAME" --query "[0].id" -o tsv 2>/dev/null || true)

if [ -z "$SP_OBJECT_ID" ]; then
    echo -e "${YELLOW}Could not find SP via 'az ad sp list'. Trying enterprise apps...${NC}"
    SP_OBJECT_ID=$(az ad sp list --all --display-name "$SP_NAME" --query "[0].id" -o tsv 2>/dev/null || true)
fi

if [ -z "$SP_OBJECT_ID" ]; then
    echo -e "${RED}Could not auto-detect Object ID.${NC}"
    read -p "Enter the Service Principal Object ID manually: " SP_OBJECT_ID
fi

echo -e "${GREEN}Service Principal Object ID: ${SP_OBJECT_ID}${NC}"
echo ""

# -------------------------------------------------------------------
# Step 4: Assign Azure permissions
# -------------------------------------------------------------------
echo -e "${CYAN}----------------------------------------------${NC}"
echo -e "${CYAN} Step 4: Assign Azure Permissions              ${NC}"
echo -e "${CYAN}----------------------------------------------${NC}"
echo ""

# Load azd environment to get resource group
AZURE_DIR="$ROOT_DIR/.azure"
RESOURCE_GROUP=""

if [ -f "$AZURE_DIR/config.json" ]; then
    ENV_NAME=$(python3 -c "import json; print(json.load(open('$AZURE_DIR/config.json'))['defaultEnvironment'])" 2>/dev/null || true)
    ENV_FILE="$AZURE_DIR/$ENV_NAME/.env"

    if [ -f "$ENV_FILE" ]; then
        echo -e "${YELLOW}Loading azd environment: ${ENV_NAME}${NC}"
        set -a
        source "$ENV_FILE"
        set +a
        RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
    fi
fi

if [ -z "$RESOURCE_GROUP" ]; then
    read -p "Enter the Azure Resource Group name: " RESOURCE_GROUP
fi

echo -e "${YELLOW}Resource Group: ${RESOURCE_GROUP}${NC}"

# Find the Cognitive Services / Azure OpenAI resource in the resource group
echo -e "${YELLOW}Looking for Azure OpenAI / Cognitive Services resource...${NC}"
COGNITIVE_RESOURCE_ID=$(az cognitiveservices account list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[0].id" -o tsv 2>/dev/null || true)

if [ -z "$COGNITIVE_RESOURCE_ID" ]; then
    echo -e "${YELLOW}No Cognitive Services resource found. Assigning role at resource group scope instead.${NC}"
    SCOPE="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP"
else
    SCOPE="$COGNITIVE_RESOURCE_ID"
    echo -e "${GREEN}Found resource: ${COGNITIVE_RESOURCE_ID}${NC}"
fi

ROLE_NAME="Cognitive Services OpenAI Contributor"

echo -e "${YELLOW}Assigning role '${ROLE_NAME}' to SP ${SP_NAME}...${NC}"
az role assignment create \
    --assignee-object-id "$SP_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "$ROLE_NAME" \
    --scope "$SCOPE" \
    2>/dev/null && \
    echo -e "${GREEN}✓ Role assignment created successfully.${NC}" || \
    echo -e "${YELLOW}⚠ Role assignment may already exist or failed. Check Azure Portal to confirm.${NC}"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN} Lab 3.1 Setup Complete!                     ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "Once the workflow completes, go into Lab 3.1 instruction and follow them."
echo ""
