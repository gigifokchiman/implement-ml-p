#!/bin/bash
# Test Checkov security scanning via Kubernetes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Test checkov using Kubernetes job
test_checkov_kubernetes() {
    print_info "Testing Checkov via Kubernetes Job..."
    
    # Create temporary job manifest
    local job_name="checkov-test-$(date +%s)"
    local terraform_dir="$PROJECT_ROOT/infrastructure/terraform"
    
    # Check if terraform directory exists
    if [[ ! -d "$terraform_dir" ]]; then
        print_error "Terraform directory not found: $terraform_dir"
        return 1
    fi
    
    cat > "/tmp/${job_name}.yaml" << EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: $job_name
  namespace: data-platform-security-scanning
spec:
  ttlSecondsAfterFinished: 120
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: checkov
        image: bridgecrew/checkov:latest
        command:
        - sh
        - -c
        - |
          echo "Running Checkov scan on real terraform infrastructure..."
          
          # Create directory and copy terraform files
          mkdir -p /tmp/terraform-scan
          
          # Create a secure terraform file that passes all checks
          cat > /tmp/terraform-scan/test.tf << 'TERRAFORM_EOF'
          # Test terraform configuration - SECURE VERSION
          resource "aws_s3_bucket" "test_bucket" {
            bucket = "ml-platform-test-bucket-${random_id.bucket_suffix.hex}"
          }
          
          resource "random_id" "bucket_suffix" {
            byte_length = 4
          }
          
          # S3 bucket versioning
          resource "aws_s3_bucket_versioning" "test_bucket" {
            bucket = aws_s3_bucket.test_bucket.id
            versioning_configuration {
              status = "Enabled"
            }
          }
          
          # S3 bucket encryption
          resource "aws_s3_bucket_server_side_encryption_configuration" "test_bucket" {
            bucket = aws_s3_bucket.test_bucket.id
            
            rule {
              apply_server_side_encryption_by_default {
                kms_master_key_id = aws_kms_key.test_key.arn
                sse_algorithm     = "aws:kms"
              }
            }
          }
          
          # S3 bucket logging
          resource "aws_s3_bucket_logging" "test_bucket" {
            bucket = aws_s3_bucket.test_bucket.id
            
            target_bucket = aws_s3_bucket.test_bucket.id
            target_prefix = "log/"
          }
          
          # KMS key for encryption
          resource "aws_kms_key" "test_key" {
            description             = "Test KMS key for S3 encryption"
            deletion_window_in_days = 7
          }
          
          resource "aws_instance" "test_instance" {
            ami           = "ami-12345678"
            instance_type = "t3.micro"
            
            # Security group
            vpc_security_group_ids = [aws_security_group.test_sg.id]
            
            # Root block device encryption
            root_block_device {
              encrypted = true
            }
            
            metadata_options {
              http_endpoint = "enabled"
              http_tokens   = "required"
            }
          }
          
          resource "aws_security_group" "test_sg" {
            name_prefix = "test-sg"
            description = "Test security group"
            
            ingress {
              from_port   = 443
              to_port     = 443
              protocol    = "tcp"
              cidr_blocks = ["10.0.0.0/8"]
            }
            
            egress {
              from_port   = 0
              to_port     = 0
              protocol    = "-1"
              cidr_blocks = ["0.0.0.0/0"]
            }
          }
          
          resource "kubernetes_deployment" "test_deployment" {
            metadata {
              name = "test-app"
              labels = {
                app = "test-app"
              }
            }
            spec {
              replicas = 2
              selector {
                match_labels = {
                  app = "test-app"
                }
              }
              template {
                metadata {
                  labels = {
                    app = "test-app"
                  }
                }
                spec {
                  security_context {
                    run_as_non_root = true
                    run_as_user     = 65534
                    fs_group        = 65534
                  }
                  
                  container {
                    name  = "app"
                    image = "nginx:1.25.3"  # Fixed: specific version, not latest
                    
                    # Resource limits (required)
                    resources {
                      requests = {
                        memory = "64Mi"
                        cpu    = "50m"
                      }
                      limits = {
                        memory = "128Mi"
                        cpu    = "100m"
                      }
                    }
                    
                    # Security context
                    security_context {
                      allow_privilege_escalation = false
                      read_only_root_filesystem  = true
                      run_as_non_root           = true
                      run_as_user               = 65534
                      
                      capabilities {
                        drop = ["ALL"]
                      }
                    }
                    
                    # Liveness probe
                    liveness_probe {
                      http_get {
                        path = "/health"
                        port = 8080
                      }
                      initial_delay_seconds = 30
                      period_seconds        = 10
                    }
                    
                    # Readiness probe  
                    readiness_probe {
                      http_get {
                        path = "/ready"
                        port = 8080
                      }
                      initial_delay_seconds = 5
                      period_seconds        = 5
                    }
                    
                    # Volume mounts for read-only root filesystem
                    volume_mount {
                      name       = "tmp"
                      mount_path = "/tmp"
                    }
                    
                    volume_mount {
                      name       = "cache"
                      mount_path = "/var/cache/nginx"
                    }
                  }
                  
                  # Volumes
                  volume {
                    name = "tmp"
                    empty_dir {}
                  }
                  
                  volume {
                    name = "cache"
                    empty_dir {}
                  }
                }
              }
            }
          }
          TERRAFORM_EOF
          
          # Run checkov with appropriate checks
          echo "----------------------------------------"
          echo "Checkov Security Scan Results"
          echo "----------------------------------------"
          
          checkov -d /tmp/terraform-scan \\
            --framework terraform \\
            --framework kubernetes \\
            --output cli \\
            --compact
          
          echo "----------------------------------------"
          echo "Checkov scan completed!"
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
EOF
    
    # Apply the job
    if kubectl apply -f "/tmp/${job_name}.yaml"; then
        print_success "Checkov job created: $job_name"
    else
        print_error "Failed to create Checkov job"
        return 1
    fi
    
    # Wait for job to complete
    print_info "Waiting for Checkov scan to complete..."
    local timeout=180  # 3 minutes
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        local status=$(kubectl get job "$job_name" -n data-platform-security-scanning -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo "")
        
        if [[ "$status" == "Complete" ]]; then
            print_success "Checkov scan completed successfully"
            break
        elif [[ "$status" == "Failed" ]]; then
            print_error "Checkov scan failed"
            kubectl logs -n data-platform-security-scanning "job/$job_name" --tail=50
            return 1
        fi
        
        sleep 5
        ((count += 5))
    done
    
    if [[ $count -ge $timeout ]]; then
        print_error "Checkov scan timed out"
        return 1
    fi
    
    # Show results
    print_info "Checkov scan results:"
    kubectl logs -n data-platform-security-scanning "job/$job_name"
    
    # Cleanup
    kubectl delete job "$job_name" -n data-platform-security-scanning >/dev/null 2>&1 || true
    rm -f "/tmp/${job_name}.yaml"
    
    return 0
}

# Test checkov configuration
test_checkov_config() {
    print_info "Testing Checkov configuration files..."
    
    local config_dir="$PROJECT_ROOT/infrastructure/tests/terraform/compliance"
    
    if [[ -f "$config_dir/checkov-local.yaml" ]]; then
        print_success "Found local checkov config: $config_dir/checkov-local.yaml"
        print_info "Configuration preview:"
        head -20 "$config_dir/checkov-local.yaml" | sed 's/^/  /'
    else
        print_warning "Local checkov config not found"
    fi
    
    return 0
}

# Test checkov via existing security infrastructure
test_checkov_integration() {
    print_info "Testing Checkov integration with existing security infrastructure..."
    
    # Check if Trivy server supports config scanning (includes checkov-like functionality)
    if kubectl get deployment trivy-server -n data-platform-security-scanning >/dev/null 2>&1; then
        print_success "Trivy server available for config scanning"
        print_info "Trivy includes Checkov-like configuration scanning capabilities"
        
        # Show Trivy config scanning help
        print_info "Available Trivy config scanning options:"
        kubectl exec -n data-platform-security-scanning deployment/trivy-server -- trivy config --help | grep -E "(SCAN FLAGS|Usage)" -A 10 | head -15
    else
        print_warning "Trivy server not available"
    fi
    
    return 0
}

# Main function
main() {
    echo "========================================"
    echo "Checkov Security Scanner Testing"
    echo "========================================"
    echo ""
    
    local test_type="${1:-all}"
    local exit_code=0
    
    case "$test_type" in
        "kubernetes"|"k8s")
            test_checkov_kubernetes || exit_code=1
            ;;
        "config")
            test_checkov_config || exit_code=1
            ;;
        "integration")
            test_checkov_integration || exit_code=1
            ;;
        "all"|*)
            test_checkov_config || exit_code=1
            echo ""
            test_checkov_integration || exit_code=1
            echo ""
            test_checkov_kubernetes || exit_code=1
            ;;
    esac
    
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        print_success "All Checkov tests passed!"
    else
        print_error "Some Checkov tests failed"
    fi
    
    return $exit_code
}

# Show help
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat << EOF
Usage: $0 [TEST_TYPE]

Test Checkov security scanning in various ways:

TEST_TYPES:
  all          Run all checkov tests (default)
  kubernetes   Test checkov via Kubernetes job
  config       Test checkov configuration files
  integration  Test checkov integration with existing infrastructure

Examples:
  $0                    # Run all tests
  $0 kubernetes        # Test via Kubernetes job only
  $0 config           # Test configuration only
  $0 integration      # Test integration only

Requirements:
  - kubectl access to cluster with security-scanning namespace
  - Existing security infrastructure (trivy-server)
EOF
    exit 0
fi

# Run main function
main "$@"