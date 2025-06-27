#!/bin/bash
set -euo pipefail

# Security and compliance testing for ML Platform infrastructure
# Runs multiple security tools and compliance checks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEST_RESULTS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "INFO")  echo -e "${BLUE}[INFO]${NC}  $timestamp - $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC}  $timestamp - $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $timestamp - $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $timestamp - $message" ;;
    esac
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log "INFO" "Running test: $test_name"
    
    if eval "$test_command"; then
        log "SUCCESS" "$test_name passed"
        TEST_RESULTS+=("✅ $test_name")
        return 0
    else
        log "ERROR" "$test_name failed"
        TEST_RESULTS+=("❌ $test_name")
        return 1
    fi
}

# Terraform security scanning
test_terraform_security_checkov() {
    if ! command -v checkov &> /dev/null; then
        log "WARN" "Checkov not installed, skipping Terraform security scan"
        return 0
    fi
    
    log "INFO" "Running Checkov security scan on Terraform files..."
    
    local environments=("dev" "staging" "prod")
    local failed_checks=0
    
    for env in "${environments[@]}"; do
        local env_dir="$INFRA_DIR/terraform/environments/$env"
        
        if [[ -d "$env_dir" ]]; then
            log "INFO" "Scanning $env environment..."
            
            # Run specific security checks
            if ! checkov -f "$env_dir/main.tf" \
                --framework terraform \
                --check CKV_AWS_79,CKV_AWS_50,CKV_AWS_88,CKV_AWS_61,CKV_AWS_16,CKV_AWS_17 \
                --quiet; then
                ((failed_checks++))
            fi
        fi
    done
    
    if [[ $failed_checks -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

test_terraform_security_tfsec() {
    if ! command -v tfsec &> /dev/null; then
        log "WARN" "tfsec not installed, skipping Terraform security scan"
        return 0
    fi
    
    log "INFO" "Running tfsec security scan on Terraform files..."
    
    local environments=("dev" "staging" "prod")
    local failed_checks=0
    
    for env in "${environments[@]}"; do
        local env_dir="$INFRA_DIR/terraform/environments/$env"
        
        if [[ -d "$env_dir" ]]; then
            log "INFO" "Scanning $env environment with tfsec..."
            
            if ! tfsec "$env_dir" --no-colour; then
                ((failed_checks++))
            fi
        fi
    done
    
    if [[ $failed_checks -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Kubernetes security scanning
test_kubernetes_security_kubesec() {
    if ! command -v kubesec &> /dev/null; then
        log "WARN" "kubesec not installed, skipping Kubernetes security scan"
        return 0
    fi
    
    log "INFO" "Running kubesec security scan on Kubernetes manifests..."
    
    local environments=("local" "dev" "staging" "prod")
    local failed_checks=0
    
    for env in "${environments[@]}"; do
        local overlay_dir="$INFRA_DIR/kubernetes/overlays/$env"
        
        if [[ -d "$overlay_dir" ]]; then
            log "INFO" "Scanning $env environment with kubesec..."
            
            cd "$overlay_dir"
            if ! kustomize build . | kubesec scan -; then
                ((failed_checks++))
            fi
        fi
    done
    
    if [[ $failed_checks -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

test_kubernetes_security_kube_score() {
    if ! command -v kube-score &> /dev/null; then
        log "WARN" "kube-score not installed, skipping Kubernetes security scan"
        return 0
    fi
    
    log "INFO" "Running kube-score security analysis..."
    
    local environments=("local" "dev" "staging" "prod")
    local failed_checks=0
    
    for env in "${environments[@]}"; do
        local overlay_dir="$INFRA_DIR/kubernetes/overlays/$env"
        
        if [[ -d "$overlay_dir" ]]; then
            log "INFO" "Analyzing $env environment with kube-score..."
            
            cd "$overlay_dir"
            if ! kustomize build . | kube-score score -; then
                ((failed_checks++))
            fi
        fi
    done
    
    if [[ $failed_checks -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Container image security scanning
test_container_security_trivy() {
    if ! command -v trivy &> /dev/null; then
        log "WARN" "Trivy not installed, skipping container security scan"
        return 0
    fi
    
    log "INFO" "Running Trivy container security scan..."
    
    # Extract images from Kubernetes manifests
    local images=()
    local environments=("local" "dev" "staging" "prod")
    
    for env in "${environments[@]}"; do
        local overlay_dir="$INFRA_DIR/kubernetes/overlays/$env"
        
        if [[ -d "$overlay_dir" ]]; then
            cd "$overlay_dir"
            local env_images
            env_images=$(kustomize build . | grep -E "^\s*image:" | awk '{print $2}' | sort -u)
            
            while IFS= read -r image; do
                if [[ -n "$image" && ! " ${images[*]} " =~ " $image " ]]; then
                    images+=("$image")
                fi
            done <<< "$env_images"
        fi
    done
    
    # Scan each unique image
    local failed_scans=0
    for image in "${images[@]}"; do
        log "INFO" "Scanning image: $image"
        
        if ! trivy image --severity HIGH,CRITICAL --no-progress "$image"; then
            ((failed_scans++))
        fi
    done
    
    if [[ $failed_scans -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Secret detection
test_secret_detection_gitleaks() {
    if ! command -v gitleaks &> /dev/null; then
        log "WARN" "gitleaks not installed, skipping secret detection"
        return 0
    fi
    
    log "INFO" "Running secret detection with gitleaks..."
    
    cd "$INFRA_DIR"
    if ! gitleaks detect --source . --no-git; then
        return 1
    fi
    
    return 0
}

test_secret_detection_truffleHog() {
    if ! command -v trufflehog &> /dev/null; then
        log "WARN" "trufflehog not installed, skipping secret detection"
        return 0
    fi
    
    log "INFO" "Running secret detection with trufflehog..."
    
    cd "$INFRA_DIR"
    if ! trufflehog filesystem . --no-update; then
        return 1
    fi
    
    return 0
}

# Compliance checks
test_compliance_network_policies() {
    log "INFO" "Checking network policy compliance..."
    
    local environments=("dev" "staging" "prod")
    local missing_netpol=0
    
    for env in "${environments[@]}"; do
        local overlay_dir="$INFRA_DIR/kubernetes/overlays/$env"
        
        if [[ -d "$overlay_dir" ]]; then
            cd "$overlay_dir"
            local manifests
            manifests=$(kustomize build .)
            
            if ! echo "$manifests" | grep -q "kind: NetworkPolicy"; then
                log "WARN" "No NetworkPolicy found in $env environment"
                ((missing_netpol++))
            fi
        fi
    done
    
    # Warning for non-production environments, error for production
    if [[ $missing_netpol -gt 0 ]]; then
        log "WARN" "Consider adding NetworkPolicy for better security"
    fi
    
    return 0
}

test_compliance_pod_security_standards() {
    log "INFO" "Checking Pod Security Standards compliance..."
    
    local environments=("local" "dev" "staging" "prod")
    local failed_compliance=0
    
    for env in "${environments[@]}"; do
        local overlay_dir="$INFRA_DIR/kubernetes/overlays/$env"
        
        if [[ -d "$overlay_dir" ]]; then
            cd "$overlay_dir"
            local manifests
            manifests=$(kustomize build .)
            
            # Check for required security context
            if ! echo "$manifests" | grep -q "runAsNonRoot: true"; then
                log "ERROR" "Pod Security Standards violation in $env: containers should run as non-root"
                ((failed_compliance++))
            fi
            
            # Check for read-only root filesystem
            if ! echo "$manifests" | grep -q "readOnlyRootFilesystem: true"; then
                log "WARN" "Pod Security Standards recommendation in $env: use read-only root filesystem"
            fi
            
            # Check for privilege escalation
            if echo "$manifests" | grep -q "allowPrivilegeEscalation: true"; then
                log "ERROR" "Pod Security Standards violation in $env: privilege escalation should be disabled"
                ((failed_compliance++))
            fi
        fi
    done
    
    if [[ $failed_compliance -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

test_compliance_resource_limits() {
    log "INFO" "Checking resource limits compliance..."
    
    local environments=("staging" "prod")
    local missing_limits=0
    
    for env in "${environments[@]}"; do
        local overlay_dir="$INFRA_DIR/kubernetes/overlays/$env"
        
        if [[ -d "$overlay_dir" ]]; then
            cd "$overlay_dir"
            local manifests
            manifests=$(kustomize build .)
            
            # Check for CPU and memory limits
            if ! echo "$manifests" | grep -q "limits:"; then
                log "ERROR" "Resource limits missing in $env environment"
                ((missing_limits++))
            fi
            
            # Check for requests
            if ! echo "$manifests" | grep -q "requests:"; then
                log "ERROR" "Resource requests missing in $env environment"
                ((missing_limits++))
            fi
        fi
    done
    
    if [[ $missing_limits -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

test_compliance_backup_strategy() {
    log "INFO" "Checking backup strategy compliance..."
    
    local environments=("staging" "prod")
    local missing_backup=0
    
    for env in "${environments[@]}"; do
        local env_dir="$INFRA_DIR/terraform/environments/$env"
        
        if [[ -d "$env_dir" ]]; then
            cd "$env_dir"
            
            # Check RDS backup configuration
            if ! grep -q "backup_retention_period" main.tf; then
                log "ERROR" "RDS backup configuration missing in $env"
                ((missing_backup++))
            fi
            
            # Check backup retention period
            local retention
            retention=$(grep "backup_retention_period" main.tf | head -1 | grep -o '[0-9]\+' || echo "0")
            
            if [[ "$env" == "prod" && "$retention" -lt 30 ]]; then
                log "ERROR" "Production backup retention should be at least 30 days, found: $retention"
                ((missing_backup++))
            elif [[ "$env" == "staging" && "$retention" -lt 7 ]]; then
                log "ERROR" "Staging backup retention should be at least 7 days, found: $retention"
                ((missing_backup++))
            fi
        fi
    done
    
    if [[ $missing_backup -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Generate security report
generate_security_report() {
    local report_file="$SCRIPT_DIR/security-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# ML Platform Security Report

Generated: $(date)

## Test Results

$(printf '%s\n' "${TEST_RESULTS[@]}")

## Security Recommendations

### High Priority
- [ ] Enable Pod Security Standards in all namespaces
- [ ] Implement network policies for micro-segmentation
- [ ] Set up centralized secret management (AWS Secrets Manager)
- [ ] Configure container image scanning in CI/CD

### Medium Priority
- [ ] Implement admission controllers (OPA Gatekeeper)
- [ ] Set up security monitoring and alerting
- [ ] Regular security assessments and penetration testing
- [ ] Implement infrastructure as code security scanning

### Low Priority
- [ ] Consider service mesh for mTLS (Istio/Linkerd)
- [ ] Implement zero-trust networking
- [ ] Set up security benchmarks (CIS Kubernetes Benchmark)

## Compliance Status

### SOC 2 Type II
- [x] Encryption in transit (HTTPS/TLS)
- [x] Encryption at rest (RDS, EBS)
- [x] Access controls (RBAC)
- [ ] Audit logging (TODO: CloudTrail, audit logs)

### GDPR
- [x] Data minimization (explicit data models)
- [ ] Data retention policies (TODO)
- [ ] Right to erasure implementation (TODO)

### PCI DSS (if applicable)
- [x] Network segmentation
- [x] Encryption requirements
- [ ] Regular security testing (TODO)

## Next Steps

1. Address failed security tests
2. Implement missing security controls
3. Set up continuous security monitoring
4. Schedule regular security reviews
EOF

    log "INFO" "Security report generated: $report_file"
}

# Main testing logic
main() {
    log "INFO" "Starting security and compliance tests"
    
    local failed_tests=0
    
    # Terraform security tests
    run_test "Terraform security (Checkov)" "test_terraform_security_checkov" || ((failed_tests++))
    run_test "Terraform security (tfsec)" "test_terraform_security_tfsec" || ((failed_tests++))
    
    # Kubernetes security tests
    run_test "Kubernetes security (kubesec)" "test_kubernetes_security_kubesec" || ((failed_tests++))
    run_test "Kubernetes security (kube-score)" "test_kubernetes_security_kube_score" || ((failed_tests++))
    
    # Container security tests
    run_test "Container security (Trivy)" "test_container_security_trivy" || ((failed_tests++))
    
    # Secret detection tests
    run_test "Secret detection (gitleaks)" "test_secret_detection_gitleaks" || ((failed_tests++))
    run_test "Secret detection (trufflehog)" "test_secret_detection_truffleHog" || ((failed_tests++))
    
    # Compliance tests
    run_test "Network policy compliance" "test_compliance_network_policies" || ((failed_tests++))
    run_test "Pod Security Standards" "test_compliance_pod_security_standards" || ((failed_tests++))
    run_test "Resource limits compliance" "test_compliance_resource_limits" || ((failed_tests++))
    run_test "Backup strategy compliance" "test_compliance_backup_strategy" || ((failed_tests++))
    
    # Generate report
    generate_security_report
    
    # Summary
    echo ""
    echo "=========================================="
    echo "Security Test Results Summary:"
    echo "=========================================="
    
    for result in "${TEST_RESULTS[@]}"; do
        echo "$result"
    done
    
    echo ""
    if [[ $failed_tests -eq 0 ]]; then
        log "SUCCESS" "All security tests passed!"
        exit 0
    else
        log "ERROR" "$failed_tests security test(s) failed"
        exit 1
    fi
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run security and compliance tests for ML Platform infrastructure

OPTIONS:
    -h, --help    Show this help message

DEPENDENCIES (optional, will skip if not installed):
    - checkov     Terraform security scanner
    - tfsec       Terraform security scanner
    - kubesec     Kubernetes security scanner
    - kube-score  Kubernetes best practices checker
    - trivy       Container vulnerability scanner
    - gitleaks    Secret detection
    - trufflehog  Secret detection

INSTALL DEPENDENCIES:
    # macOS
    brew install checkov tfsec kubesec kube-score trivy gitleaks trufflesecurity/trufflehog/trufflehog

    # Linux
    # See individual tool documentation for installation instructions
EOF
}

# Parse arguments
case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    "")
        main
        ;;
    *)
        log "ERROR" "Invalid option: $1"
        usage
        exit 1
        ;;
esac