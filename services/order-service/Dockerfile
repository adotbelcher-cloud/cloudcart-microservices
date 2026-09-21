# Use Python 3.12 as the base runtime for the Order Service
FROM python:3.12-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the dependency file first to take advantage of Docker layer caching
COPY requirements.txt .

# Install the Order Service Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application source code into the container
COPY app ./app

# Document the port used by the Order Service inside the container
EXPOSE 8000

# Start the FastAPI application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]