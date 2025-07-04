# Infrastructure Tools Container
# Contains Terraform, kubectl, helm, and other infrastructure management tools
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TERRAFORM_VERSION=1.6.6
ENV KUBECTL_VERSION=v1.28.4
ENV HELM_VERSION=v3.18.3
ENV KIND_VERSION=v0.20.0
ENV DOCKER_VERSION=latest
ENV YQ_VERSION=v4.40.5
ENV JQ_VERSION=1.7
ENV AWS_CLI_VERSION=2.15.7
ENV CHECKOV_VERSION=3.1.24
ENV TFSEC_VERSION=v1.28.4
ENV TERRASCAN_VERSION=1.18.11
ENV OPA_VERSION=v0.58.0
ENV CONFTEST_VERSION=0.46.0
ENV TRIVY_VERSION=0.47.0
ENV GH_VERSION=2.40.1
ENV K6_VERSION=v0.47.0
ENV KUSTOMIZE_VERSION=5.0.1
ENV GRAPHVIZ_VERSION=latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    gnupg \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    python3 \
    python3-pip \
    make \
    jq \
    gettext-base \
    openssh-client \
    rsync \
    graphviz \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js and npm for k6 and other JS tooling
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    node --version && npm --version

# Install Go 1.21 for building terraform-provider-kind
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then GO_ARCH="arm64"; else GO_ARCH="amd64"; fi && \
    wget https://go.dev/dl/go1.21.6.linux-${GO_ARCH}.tar.gz && \
    tar -C /usr/local -xzf go1.21.6.linux-${GO_ARCH}.tar.gz && \
    rm go1.21.6.linux-${GO_ARCH}.tar.gz
ENV PATH=$PATH:/usr/local/go/bin

# Install Terraform
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then ARCH="arm64"; else ARCH="amd64"; fi && \
    wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip && \
    unzip terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip && \
    mv terraform /usr/local/bin/ && \
    rm terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip && \
    terraform version

# Install kubectl
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then ARCH="arm64"; else ARCH="amd64"; fi && \
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/ && \
    kubectl version --client

# Install Helm
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then ARCH="arm64"; else ARCH="amd64"; fi && \
    curl -fsSL https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz | tar -xzO linux-${ARCH}/helm > /usr/local/bin/helm && \
    chmod +x /usr/local/bin/helm && \
    helm version

# Install Kind
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then ARCH="arm64"; else ARCH="amd64"; fi && \
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH} && \
    chmod +x ./kind && \
    mv ./kind /usr/local/bin/kind && \
    kind version

# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/* && \
    docker --version

# Install yq (YAML processor)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then ARCH="arm64"; else ARCH="amd64"; fi && \
    wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH} -O /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    yq --version

# Install AWS CLI v2
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then AWS_ARCH="aarch64"; else AWS_ARCH="x86_64"; fi && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}-${AWS_CLI_VERSION}.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws/ && \
    aws --version

# Install security scanning tools
# Checkov (Terraform security scanner) - use latest compatible version
RUN pip3 install checkov && \
    checkov --version

# tfsec (Terraform security scanner)
RUN curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash && \
    tfsec --version

# Terrascan (IaC security scanner)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then ARCH="arm64"; else ARCH="x86_64"; fi && \
    curl -L "https://github.com/tenable/terrascan/releases/download/v${TERRASCAN_VERSION}/terrascan_${TERRASCAN_VERSION}_Linux_${ARCH}.tar.gz" | tar -xz terrascan && \
    mv terrascan /usr/local/bin/ && \
    terrascan version

# Open Policy Agent (OPA)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then ARCH="arm64"; else ARCH="amd64"; fi && \
    curl -L -o opa https://openpolicyagent.org/downloads/${OPA_VERSION}/opa_linux_${ARCH}_static && \
    chmod +x opa && \
    mv opa /usr/local/bin/ && \
    opa version

# Conftest (OPA testing framework)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then ARCH="arm64"; else ARCH="x86_64"; fi && \
    wget https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_${ARCH}.tar.gz && \
    tar xzf conftest_${CONFTEST_VERSION}_Linux_${ARCH}.tar.gz && \
    mv conftest /usr/local/bin/ && \
    rm conftest_${CONFTEST_VERSION}_Linux_${ARCH}.tar.gz && \
    conftest --version

# Install trivy (Container security scanner)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then ARCH="ARM64"; else ARCH="64bit"; fi && \
    TRIVY_VERSION=$(curl -s https://api.github.com/repos/aquasecurity/trivy/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//') && \
    wget https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${ARCH}.tar.gz && \
    tar -xzf trivy_${TRIVY_VERSION}_Linux-${ARCH}.tar.gz && \
    mv trivy /usr/local/bin/ && \
    rm trivy_${TRIVY_VERSION}_Linux-${ARCH}.tar.gz && \
    trivy --version

# Install GitHub CLI (gh)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then ARCH="arm64"; else ARCH="amd64"; fi && \
    GH_VERSION=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//') && \
    wget https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${ARCH}.tar.gz && \
    tar -xzf gh_${GH_VERSION}_linux_${ARCH}.tar.gz && \
    mv gh_${GH_VERSION}_linux_${ARCH}/bin/gh /usr/local/bin/ && \
    rm -rf gh_${GH_VERSION}_linux_${ARCH}* && \
    gh --version

# Install graphviz for infrastructure visualization
RUN apt-get update && apt-get install -y \
    graphviz \
    && rm -rf /var/lib/apt/lists/* && \
    dot -V

# Install additional tools for Kubernetes management
# Kustomize
RUN curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash && \
    mv kustomize /usr/local/bin/ && \
    kustomize version

# kubectx and kubens (Kubernetes context and namespace switcher)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then ARCH="arm64"; else ARCH="x86_64"; fi && \
    KUBECTX_VERSION=$(curl -s https://api.github.com/repos/ahmetb/kubectx/releases/latest | grep tag_name | cut -d '"' -f 4) && \
    wget https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/kubectx_${KUBECTX_VERSION}_linux_${ARCH}.tar.gz && \
    wget https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/kubens_${KUBECTX_VERSION}_linux_${ARCH}.tar.gz && \
    tar -xzf kubectx_${KUBECTX_VERSION}_linux_${ARCH}.tar.gz && \
    tar -xzf kubens_${KUBECTX_VERSION}_linux_${ARCH}.tar.gz && \
    mv kubectx /usr/local/bin/ && \
    mv kubens /usr/local/bin/ && \
    chmod +x /usr/local/bin/kubectx /usr/local/bin/kubens && \
    rm kubectx_* kubens_*

# Install k9s (Kubernetes TUI)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then ARCH="arm64"; else ARCH="amd64"; fi && \
    K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4) && \
    wget https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${ARCH}.tar.gz && \
    tar -xzf k9s_Linux_${ARCH}.tar.gz && \
    mv k9s /usr/local/bin/ && \
    rm k9s_Linux_${ARCH}.tar.gz

# Install monitoring and observability tools
# Prometheus CLI tools - simplified to avoid wildcard issues
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then ARCH="arm64"; else ARCH="amd64"; fi && \
    PROM_VERSION=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//') && \
    wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-${ARCH}.tar.gz && \
    tar -xzf prometheus-${PROM_VERSION}.linux-${ARCH}.tar.gz && \
    mv prometheus-${PROM_VERSION}.linux-${ARCH}/promtool /usr/local/bin/ && \
    rm -rf prometheus-*

# Install performance testing tools
# K6 (Load testing) - binary installation
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then K6_ARCH="arm64"; else K6_ARCH="amd64"; fi && \
    K6_VERSION=$(curl -s https://api.github.com/repos/grafana/k6/releases/latest | grep tag_name | cut -d '"' -f 4) && \
    wget https://github.com/grafana/k6/releases/download/${K6_VERSION}/k6-${K6_VERSION}-linux-${K6_ARCH}.tar.gz && \
    tar -xzf k6-${K6_VERSION}-linux-${K6_ARCH}.tar.gz && \
    mv k6-${K6_VERSION}-linux-${K6_ARCH}/k6 /usr/local/bin/ && \
    rm -rf k6-* && \
    k6 version

# Install k6 via npm for package management and additional modules
RUN npm install -g k6@latest && \
    npm list -g k6

# Install chaos engineering tools
# Chaos Toolkit - remove to simplify build
# RUN pip3 install chaostoolkit chaostoolkit-kubernetes

# Install custom terraform-provider-kind
# Create placeholder files to avoid COPY errors when source files don't exist
RUN touch /tmp/terraform-provider-mlplatform-placeholder && \
    touch /tmp/terraform-provider-kind-placeholder

# Download terraform provider (simplified approach)
RUN ARCH=$(dpkg --print-architecture) && \
    TERRAFORM_ARCH="linux_${ARCH}" && \
    mkdir -p /workspace/.terraform.d/plugins/kind.local/gigifokchiman/kind/0.1.0/${TERRAFORM_ARCH} && \
    echo "Attempting to download terraform provider for ${TERRAFORM_ARCH}" && \
    (wget -q https://github.com/gigifokchiman/kind/releases/download/v0.1.0/terraform-provider-kind_v0.1.0_${TERRAFORM_ARCH}.tar.gz -O /tmp/provider.tar.gz || \
     wget -q https://github.com/gigifokchiman/kind/releases/download/v0.1.0/terraform-provider-kind_v0.1.0_linux_amd64.tar.gz -O /tmp/provider.tar.gz) && \
    cd /tmp && tar -xzf provider.tar.gz && \
    cp terraform-provider-kind /workspace/.terraform.d/plugins/kind.local/gigifokchiman/kind/0.1.0/${TERRAFORM_ARCH}/terraform-provider-kind && \
    chmod +x /workspace/.terraform.d/plugins/kind.local/gigifokchiman/kind/0.1.0/${TERRAFORM_ARCH}/terraform-provider-kind && \
    echo "✅ Terraform provider installed" || echo "⚠️  Terraform provider not available - manual installation required"

# Don't clean up for debugging
# RUN rm -rf /tmp/provider.tar.gz /tmp/terraform-provider-kind* /tmp/terraform-provider-mlplatform*

# Create working directory
WORKDIR /workspace

# Copy package.json and install npm dependencies
COPY package.json* /workspace/
RUN if [ -f package.json ]; then npm install --only=dev; fi

# Create non-root user for security and add to docker group
RUN groupadd -r infrauser && useradd -r -g infrauser infrauser && \
    groupadd -f docker && usermod -aG docker infrauser && \
    chown -R infrauser:infrauser /workspace && \
    # Copy terraform plugins to both user and root directories
    mkdir -p /home/infrauser/.terraform.d /root/.terraform.d && \
    if [ -d /workspace/.terraform.d/plugins ]; then \
        cp -r /workspace/.terraform.d/* /home/infrauser/.terraform.d/ && \
        cp -r /workspace/.terraform.d/* /root/.terraform.d/ && \
        chown -R infrauser:infrauser /home/infrauser/.terraform.d; \
    fi

# Set up shell aliases and useful functions
RUN echo 'alias k=kubectl' >> /etc/bash.bashrc && \
    echo 'alias tf=terraform' >> /etc/bash.bashrc && \
    echo 'alias h=helm' >> /etc/bash.bashrc && \
    echo 'complete -F __start_kubectl k' >> /etc/bash.bashrc

# Add helpful environment variables
ENV KUBECONFIG=/workspace/.kube/config
ENV TERRAFORM_LOG_PATH=/workspace/terraform.log

# Create directories for configuration
RUN mkdir -p /workspace/.kube /workspace/.aws /workspace/.terraform.d && \
    chown -R infrauser:infrauser /workspace

# Add health check script
COPY <<EOF /usr/local/bin/health-check.sh
#!/bin/bash
set -e

echo "=== Infrastructure Tools Health Check ==="
echo "Terraform: $(terraform version | head -n1)"
echo "kubectl: $(kubectl version --client)"
echo "Helm: $(helm version --short)"
echo "Kind: $(kind version)"
echo "Docker: $(docker --version)"
echo "AWS CLI: $(aws --version)"
echo "yq: $(yq --version)"
echo "Checkov: $(checkov --version)"
echo "tfsec: $(tfsec --version)"
echo "trivy: $(trivy --version)"
echo "GitHub CLI: $(gh --version)"
echo "Terrascan: $(terrascan version)"
echo "OPA: $(opa version)"
echo "Conftest: $(conftest --version)"
echo "Graphviz: $(dot -V 2>&1)"
echo "Kustomize: $(kustomize version)"
echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"
echo "K6 Binary: $(k6 version)"
echo "K6 npm: $(npm list -g k6 2>/dev/null || echo 'Not installed via npm')"
echo "Custom Kind Provider: $(ls -la ~/.terraform.d/plugins/registry.terraform.io/gigifokchiman/kind/0.1.0/*/terraform-provider-kind* 2>/dev/null || echo 'Not found')"
echo "=== All tools are ready! ==="
EOF

RUN chmod +x /usr/local/bin/health-check.sh

# Grant execute permissions to all files in scripts folders
RUN chmod -R +x /workspace/scripts 2>/dev/null || true

# Switch to non-root user
USER infrauser

# Set entrypoint to bash
ENTRYPOINT ["/bin/bash"]

# Add labels for metadata
LABEL maintainer="ML Platform Team"
LABEL description="Infrastructure tools container with Terraform, kubectl, Helm, and security scanners"
LABEL version="1.0.0"
LABEL tools="terraform,kubectl,helm,kind,docker,aws-cli,k6,trivy,tfsec,gh,graphviz,checkov,terrascan,opa,conftest"