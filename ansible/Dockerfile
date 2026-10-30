# ==============================================================================
# 1. BASE IMAGE SELECTION
# ==============================================================================
FROM quay.io/ansible/awx-ee:latest

# Switch to root user
USER root

# ==============================================================================
# 2. ESSENTIAL SYSTEM LIBRARIES & UTILITIES
# ==============================================================================
# We use --allowerasing to seamlessly replace the pre-installed 'curl-minimal'
# with the full 'curl' package without throwing conflict errors.
RUN dnf install -y --nodocs --allowerasing \
    curl \
    unzip \
    git \
    iputils \
    procps-ng \
    gcc \
    libffi-devel \
    openssl-devel && \
    dnf clean all && \
    rm -rf /var/cache/dnf/*

# ==============================================================================
# 3. INFRASTRUCTURE BINARY: TERRAFORM (Architecture-Aware)
# ==============================================================================
# Automatically detects if building on Apple Silicon (arm64) or Intel/AMD (amd64)
ENV TERRAFORM_VERSION=1.8.5
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then TF_ARCH="arm64"; else TF_ARCH="amd64"; fi && \
    curl -s https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TF_ARCH}.zip -o terraform.zip && \
    unzip terraform.zip -d /usr/local/bin/ && \
    rm terraform.zip && \
    chmod +x /usr/local/bin/terraform

# ==============================================================================
# 4. REQUIRED PYTHON LIBRARIES
# ==============================================================================
RUN pip install --no-cache-dir \
    requests \
    boto3 \
    botocore \
    hvac

# ==============================================================================
# 5. ESSENTIAL ANSIBLE COLLECTIONS (Installed Globally for all users)
# ==============================================================================
# We use the -p flag to force installation into a shared system path 
# readable by the non-root AWX runner user (UID 1000).
RUN ansible-galaxy collection install \
    amazon.aws \
    kubernetes.core \
    community.general \
    ansible.posix \
    -p /usr/share/ansible/collections

# Ensure correct permissions on the global collections directory
RUN chmod -R 755 /usr/share/ansible/collections

# ==============================================================================
# 6. SECURITY & RUNTIME PERMISSIONS
# ==============================================================================
USER 1000
WORKDIR /runner