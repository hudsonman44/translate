#!/bin/bash

# CORS debugging script to test different origins and methods

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

echo "🔍 CORS Debugging for translate-glue API"
echo "========================================"

API_URL="https://translate-glue.aaronbhudson.com/api/process-and-translate"
HEALTH_URL="https://translate-glue.aaronbhudson.com/health"

# Test origins to check
ORIGINS=(
    "https://translate.aaronbhudson.com"
    "https://b23370b1.translate-19i.pages.dev"
    "https://localhost:3000"
    "http://localhost:3000"
)

print_section "Testing Health Endpoint (No CORS needed)"
print_status "Testing: $HEALTH_URL"
curl -v "$HEALTH_URL" 2>&1 | grep -E "(HTTP|< |> )"

print_section "Testing CORS Preflight Requests"

for origin in "${ORIGINS[@]}"; do
    print_status "Testing preflight for origin: $origin"
    
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -X OPTIONS \
        -H "Origin: $origin" \
        -H "Access-Control-Request-Method: POST" \
        -H "Access-Control-Request-Headers: Content-Type" \
        "$API_URL" 2>/dev/null)
    
    if [ "$response" = "200" ] || [ "$response" = "204" ]; then
        print_success "✅ Preflight OK for $origin (HTTP $response)"
    else
        print_error "❌ Preflight FAILED for $origin (HTTP $response)"
    fi
    
    # Show detailed response
    print_status "Detailed preflight response for $origin:"
    curl -v -X OPTIONS \
        -H "Origin: $origin" \
        -H "Access-Control-Request-Method: POST" \
        -H "Access-Control-Request-Headers: Content-Type" \
        "$API_URL" 2>&1 | grep -E "(HTTP|Access-Control|< |> )" | head -10
    echo ""
done

print_section "Testing Actual POST Requests"

for origin in "${ORIGINS[@]}"; do
    print_status "Testing POST request from origin: $origin"
    
    # Create a test file
    echo "test audio content" > /tmp/test-audio.txt
    
    response=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST \
        -H "Origin: $origin" \
        -F "media=@/tmp/test-audio.txt" \
        -F "language=spanish" \
        "$API_URL" 2>/dev/null)
    
    if [ "$response" = "200" ]; then
        print_success "✅ POST OK for $origin (HTTP $response)"
    elif [ "$response" = "403" ]; then
        print_error "❌ POST BLOCKED for $origin (HTTP 403 - CORS issue)"
    else
        print_warning "⚠️  POST returned HTTP $response for $origin"
    fi
    
    # Show detailed response
    print_status "Detailed POST response for $origin:"
    curl -v -X POST \
        -H "Origin: $origin" \
        -F "media=@/tmp/test-audio.txt" \
        -F "language=spanish" \
        "$API_URL" 2>&1 | grep -E "(HTTP|Access-Control|< |> )" | head -10
    echo ""
done

# Cleanup
rm -f /tmp/test-audio.txt

print_section "Server Logs Analysis"
print_status "Recent server logs (looking for CORS messages):"
ssh_available=false

# Try to get server logs if we're on the server
if command -v journalctl &> /dev/null; then
    print_status "Checking local server logs..."
    journalctl -u translate-glue.service --since "5 minutes ago" | grep -E "(CORS|origin|Origin)" || print_warning "No CORS-related logs found"
else
    print_warning "Not on server - cannot check logs directly"
    echo "To check server logs, run on your server:"
    echo "journalctl -u translate-glue.service -f | grep -E '(CORS|origin|Origin)'"
fi

print_section "Recommendations"

echo "Based on the tests above:"
echo ""
echo "🔧 If preflight (OPTIONS) requests are failing:"
echo "   - Check server CORS configuration"
echo "   - Ensure OPTIONS method is allowed"
echo "   - Verify origin is in allowlist"
echo ""
echo "🔧 If preflight works but POST fails with 403:"
echo "   - Check if server logs show 'CORS blocked origin'"
echo "   - Verify actual vs expected origin format"
echo "   - Check for case sensitivity issues"
echo ""
echo "🔧 If all tests pass but frontend still fails:"
echo "   - Check browser developer tools Network tab"
echo "   - Look for exact error message in console"
echo "   - Verify frontend is using correct URL"
echo ""
echo "📋 Next steps:"
echo "1. Check server logs: journalctl -u translate-glue.service -f"
echo "2. Test from browser developer tools console:"
echo "   fetch('$API_URL', {method: 'OPTIONS', headers: {'Origin': 'https://translate.aaronbhudson.com'}})"
echo "3. Compare working health endpoint vs failing API endpoint"

print_success "CORS debugging complete!"
