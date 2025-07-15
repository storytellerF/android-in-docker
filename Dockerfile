# Base Image
FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Set VNC password, which can be overridden at build time
ARG VNC_PASSWD=password
ENV VNC_PASSWD=${VNC_PASSWD}

# Install VNC, a lightweight desktop, noVNC, and supervisor
RUN apt-get update && apt-get install -y \
    supervisor \
    tightvncserver \
    xfce4 \
    xfce4-goodies \
    novnc \
    websockify \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Create supervisor log directory
RUN mkdir -p /var/log/supervisor

# Setup VNC user and password
RUN mkdir -p /root/.vnc
RUN echo "${VNC_PASSWD}" | vncpasswd -f > /root/.vnc/passwd
RUN chmod 600 /root/.vnc/passwd

# Setup the startup script for the VNC server to launch the XFCE desktop
RUN echo "#!/bin/bash" > /root/.vnc/xstartup
RUN echo "xrdb \$HOME/.Xresources" >> /root/.vnc/xstartup
RUN echo "startxfce4 &" >> /root/.vnc/xstartup
RUN chmod +x /root/.vnc/xstartup

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Expose Ports:
# 6080: noVNC Web Interface
# 5901: VNC Server (for display :1)
EXPOSE 6080 5901

# Command to run supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
