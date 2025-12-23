# OpenKore Docker Image
# Perl-based Ragnarok Online bot

FROM perl:5.36-slim

# Install system dependencies including Python for SCons build system and libcurl for HTTP requests
RUN apt-get update && apt-get install -y \
    build-essential \
    libncurses-dev \
    libreadline-dev \
    zlib1g-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Install required Perl modules
RUN cpanm --notest \
    Time::HiRes \
    Carp::Assert \
    Compress::Zlib \
    IO::Socket::INET \
    Digest::MD5 \
    MIME::Base64 \
    Storable \
    Encode \
    JSON::PP \
    HTML::Entities \
    HTTP::Tiny \
    URI::Escape \
    Exception::Class

# Create app directory
WORKDIR /app/openkore

# Copy OpenKore source code
COPY . .

# Create python symlink for SCons compatibility
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Compile XSTools using SCons
RUN make

# Set permissions
RUN chmod +x openkore.pl start.pl

# Set environment variable for console interface
ENV OPENKORE_INTERFACE=Console

# Entry point
CMD ["perl", "openkore.pl"]
