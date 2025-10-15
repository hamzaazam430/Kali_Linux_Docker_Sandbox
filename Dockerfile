FROM kalilinux/kali-rolling

# Install packages (including sudo) and create non-root user in one layer
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      sudo \
      curl \
      wget \
      git \
      iputils-ping \
      net-tools \
      python3 \
 && apt-get clean
#  && rm -rf /var/lib/apt/lists/*

# Create a non-root user 'sandbox' with a home directory and bash shell,
# and add it to the 'sudo' group.
# Use -m to create home, -s to set shell, -G to add to group.
RUN useradd -m -s /bin/bash -G sudo sandbox

# Grant passwordless sudo to sandbox (so sandbox can run sudowithout interactive password)
RUN echo "sandbox ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-sandbox \
 && chmod 0440 /etc/sudoers.d/90-sandbox

# Switch to non-root user
USER sandbox
WORKDIR /home/sandbox

# Optional: keep PATH and env sane
ENV HOME=/home/sandbox
CMD ["bash"]
