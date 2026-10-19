#!/usr/bin/env bash

# Azure for Students - allowed region checker
# Tests Azure physical regions with ARM "validate".
# It does NOT create the test VNet.
# It creates only a temporary Resource Group (no direct cost) if needed.

set -u

RG="region-check-rg"
TEMPLATE="$HOME/region-check-template.json"
LOG="$HOME/azure-region-check.log"

echo "===================================================="
echo " Azure for Students - Allowed Region Checker"
echo "===================================================="
echo

# 1) Select Azure for Students if it exists.
STUDENT_SUB=$(az account list --all \
  --query "[?name=='Azure for Students' && state=='Enabled'].id | [0]" \
  -o tsv 2>/dev/null)

if [ -n "${STUDENT_SUB:-}" ]; then
    az account set --subscription "$STUDENT_SUB"
else
    echo "An 'Azure for Students' subscription was not found automatically."
    echo "Available subscriptions:"
    az account list --all \
      --query "[].{Name:name,ID:id,State:state,Default:isDefault}" \
      -o table
    echo
    read -r -p "Paste the subscription ID to test: " STUDENT_SUB
    az account set --subscription "$STUDENT_SUB" || exit 1
fi

SUB_ID=$(az account show --query id -o tsv)
SUB_NAME=$(az account show --query name -o tsv)

echo
echo "Active subscription: $SUB_NAME"
echo "Subscription ID:     $SUB_ID"
echo

# 2) Ensure the temporary Resource Group exists.
if ! az group show --name "$RG" --output none 2>/dev/null; then
    echo "Creating temporary Resource Group: $RG"
    if ! az group create --name "$RG" --location westeurope --output none; then
        echo
        echo "ERROR: The temporary Resource Group could not be created."
        echo "Create a Resource Group manually, then change RG= at the top of this script."
        exit 1
    fi
else
    echo "Using existing Resource Group: $RG"
fi

# 3) Create a small ARM template locally.
# The location is a parameter, so the same template can be tested in every region.
cat > "$TEMPLATE" <<'EOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "location": {
      "type": "string"
    }
  },
  "resources": [
    {
      "type": "Microsoft.Network/virtualNetworks",
      "apiVersion": "2024-05-01",
      "name": "region-check-vnet",
      "location": "[parameters('location')]",
      "properties": {
        "addressSpace": {
          "addressPrefixes": [
            "10.99.0.0/16"
          ]
        }
      }
    }
  ]
}
EOF

if [ ! -s "$TEMPLATE" ]; then
    echo "ERROR: Could not create template file: $TEMPLATE"
    exit 1
fi

# 4) Get physical Azure regions.
mapfile -t REGIONS < <(
  az account list-locations \
    --query "[?metadata.regionType=='Physical'].name" \
    -o tsv | sort -u
)

if [ "${#REGIONS[@]}" -eq 0 ]; then
    echo "ERROR: No physical Azure regions were returned."
    exit 1
fi

: > "$LOG"

declare -a ALLOWED
declare -a BLOCKED
declare -a OTHER

echo
echo "Testing ${#REGIONS[@]} physical Azure regions..."
echo "No VNet is created; ARM validation is used."
echo
printf "%-28s %-14s\n" "REGION" "RESULT"
printf "%-28s %-14s\n" "----------------------------" "--------------"

for REGION in "${REGIONS[@]}"; do

    RESPONSE=$(
      az deployment group validate \
        --resource-group "$RG" \
        --template-file "$TEMPLATE" \
        --parameters location="$REGION" \
        --validation-level Provider \
        --only-show-errors \
        --output json 2>&1
    )
    RC=$?

    {
      echo "===== $REGION ====="
      echo "$RESPONSE"
      echo
    } >> "$LOG"

    if echo "$RESPONSE" | grep -q "RequestDisallowedByAzure"; then
        printf "%-28s %-14s\n" "$REGION" "BLOCKED"
        BLOCKED+=("$REGION")
    elif [ "$RC" -eq 0 ]; then
        printf "%-28s %-14s\n" "$REGION" "ALLOWED"
        ALLOWED+=("$REGION")
    else
        printf "%-28s %-14s\n" "$REGION" "OTHER ERROR"
        OTHER+=("$REGION")
    fi
done

echo
echo "===================================================="
echo " ALLOWED REGIONS"
echo "===================================================="

if [ "${#ALLOWED[@]}" -eq 0 ]; then
    echo "No allowed region was detected by this validation test."
else
    for REGION in "${ALLOWED[@]}"; do
        DISPLAY=$(
          az account list-locations \
            --query "[?name=='$REGION'].displayName | [0]" \
            -o tsv 2>/dev/null
        )
        printf "%-30s %s\n" "${DISPLAY:-$REGION}" "$REGION"
    done
fi

echo
echo "Allowed:      ${#ALLOWED[@]}"
echo "Blocked:      ${#BLOCKED[@]}"
echo "Other errors: ${#OTHER[@]}"
echo
echo "Detailed log: $LOG"
echo "Template:     $TEMPLATE"
echo
echo "IMPORTANT:"
echo "ALLOWED means the region passed validation for this VNet."
echo "It does not guarantee that a particular Windows 11 VM size/image"
echo "is available or that sufficient VM quota exists there."
echo
echo "The Resource Group '$RG' was left in place intentionally."
echo "To remove it later:"
echo "  az group delete --name \"$RG\" --yes --no-wait"
