FROM alpine:latest

# Install required packages
RUN apk add --no-cache \
    openssh-client \
    samba-client \
    socat \
    bash \
    && rm -rf /var/cache/apk/*

# Create non-root user for SSH operations
RUN adduser -D -s /bin/bash tunneluser

# Copy the entry script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create SSH directory for the user
RUN mkdir -p /home/tunneluser/.ssh && \
    chown -R tunneluser:tunneluser /home/tunneluser/.ssh && \
    chmod 700 /home/tunneluser/.ssh

# Expose SMB port
EXPOSE 445

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"] 