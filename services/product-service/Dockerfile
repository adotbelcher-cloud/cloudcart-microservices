# Use Python 3.12 as the base runtime for the Product Service
FROM python:3.12-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the dependency file into the container first
COPY requirements.txt .

# Install the Product Service Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application source code into the container
COPY app ./app

# Document that the application listens on port 8000
EXPOSE 8000

# Start the FastAPI application when the container launches
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]