#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Get the actual username (not root)
ACTUAL_USER=$(logname || who | awk '{print $1}' | head -n1)
echo "Setting up for user: $ACTUAL_USER"

# Create ollama directory on external drive
OLLAMA_DIR="/media/crux/bbtest/ollama"
mkdir -p "$OLLAMA_DIR"
chown -R $ACTUAL_USER:$ACTUAL_USER "$OLLAMA_DIR"

# Create environment file
mkdir -p /etc/ollama
echo "OLLAMA_MODELS=$OLLAMA_DIR" > /etc/ollama/env
chown -R $ACTUAL_USER:$ACTUAL_USER /etc/ollama

# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Create systemd override directory and file
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/override.conf << EOF
[Service]
EnvironmentFile=/etc/ollama/env
User=$ACTUAL_USER
Group=$ACTUAL_USER
EOF

# Reload systemd and restart Ollama
systemctl daemon-reload
systemctl enable ollama
systemctl restart ollama

# Add environment variable to both bash and zsh configs
for config in "/home/$ACTUAL_USER/.bashrc" "/home/$ACTUAL_USER/.zshrc"; do
    if [ -f "$config" ]; then
        # Remove any existing OLLAMA_MODELS lines
        sed -i '/export OLLAMA_MODELS/d' "$config"
        # Add new export
        echo "export OLLAMA_MODELS=$OLLAMA_DIR" >> "$config"
        chown $ACTUAL_USER:$ACTUAL_USER "$config"
    fi
done

echo "Installation complete! Please log out and back in, or run:"
echo "source ~/.bashrc # (if using bash)"
echo "source ~/.zshrc  # (if using zsh)"
echo ""
echo "To verify installation:"
echo "1. Run: ollama list"
echo "2. Check storage location: ls -la $OLLAMA_DIR"
