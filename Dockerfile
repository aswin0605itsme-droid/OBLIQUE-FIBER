# Use official Python slim image (supports linux/s390x natively for IBM LinuxONE)
FROM python:3.11-slim-bookworm

# Set environment variables for zero-buffering and security
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

# Set working directory inside the container
WORKDIR /app

# Install system-level build dependencies required for compiling 
# scientific/ML packages (NumPy, Scikit-Learn, PyTorch) on s390x
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    gfortran \
    libopenblas-dev \
    liblapack-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user to enforce mainframe-grade container security
RUN groupadd -r qblique && useradd -r -g qblique qblique

# Copy and install Python dependencies first (leverages Docker layer caching)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy the rest of the QBLIQUE-FILBER project code
COPY . .

# Transfer ownership to the non-root user
RUN chown -R qblique:qblique /app
USER qblique

# Expose the API port
EXPOSE 8000

# Healthcheck to ensure the Twin Engine & Rule Service are responsive
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run with Uvicorn using multiple workers for low-latency throughput
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]