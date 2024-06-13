FROM python:3.9-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create a virtual environment
RUN python3 -m venv /venv

# Activate the virtual environment and install Manticore with specific protobuf version
RUN /venv/bin/pip install --upgrade pip setuptools wheel
RUN /venv/bin/pip install protobuf==3.20.* manticore

# Set the PATH to use the virtual environment
ENV PATH="/venv/bin:$PATH"

# Copy the project files
WORKDIR /app
COPY . /app

# List installed packages for debugging
RUN pip list

# Run the Manticore script
CMD ["python3", "test/tools/manticore.py"]
