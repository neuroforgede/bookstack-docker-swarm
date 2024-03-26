FROM solidnerd/bookstack:24.2.2-1

USER root

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

USER 33