FROM python:3.11-slim AS builder
WORKDIR /analytics

# --- Install build deps (Rust, C, Python dev, etc.) ---
RUN apt-get update && apt-get install -y \
    curl build-essential python3-dev libpq-dev libssl-dev pkg-config \
    && curl https://sh.rustup.rs -sSf | bash -s -- -y \
    && . "$HOME/.cargo/env"

ENV PATH="/root/.cargo/bin:${PATH}"

# --- Build a dummy file ---
# to build the dependencies, and store it as a cache layer
COPY ./Cargo.toml ./Cargo.toml
RUN mkdir ./src && echo "fn main() {}" > ./src/main.rs
RUN PYO3_PYTHON=/usr/bin/python3 cargo build --release --target-dir .

# --- Copy actual code --- 
# to not invalidate build cache, and only build what's needed
COPY ./src ./src
COPY ./.sqlx ./.sqlx
RUN python3 --version
RUN PYO3_PYTHON=/usr/bin/python3 cargo install --path . --target-dir . --root /analytics

# RUN strip /analytics/bin/backend_aegis 

######## CONTAINER #######
FROM python:3.13-slim AS aegis

WORKDIR /analytics

# Dependencies for Postgres driver
RUN apt-get update && apt-get install -y \
    gcc libpq-dev ansible python3-dev iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy backend
COPY ansible/project/ ./ansible/project
COPY ./prelude ./prelude
COPY ./Rocket.toml ./Rocket.toml

# Expose port, should be the same as in backend/config.json
EXPOSE 8000

COPY --from=builder /analytics/bin/backend_aegis .
ENV PATH="/analytics:${PATH}"
ENV NDEBUG=TRUE

ENTRYPOINT ["prelude/entrypoint.sh"]
CMD ["bash", "-c", "python3 prelude/create_aggregate_tasks.py && backend_aegis"]
