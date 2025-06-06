#!/bin/bash
set -e

echo "⚙️ Setting up postgis-property-search-demo-py development environment..."

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform is required but not installed."; exit 1; }

# Copy environment template
if [ ! -f .env ]; then
    cp .env.example .env
    echo "📝 Created .env file from template. Please update with your values."
fi

# Start local database
echo "🐘 Starting local PostgreSQL with PostGIS..."
docker-compose up -d postgres

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
until docker-compose exec postgres pg_isready -U postgres; do
    sleep 2
done

# Setup database
echo "🗄️ Setting up database schema..."
docker-compose exec postgres psql -U postgres -d learning -f /docker-entrypoint-initdb.d/setup.sql

# Install dependencies
echo "📦 Installing dependencies..."

python -m venv venv
source venv/bin/activate
pip install -r requirements.txt


# Run initial tests
echo "🧪 Running tests..."

python -m pytest tests/ -v


echo "✅ Setup completed successfully!"
echo ""
echo "🚀 To start development:"
echo "  1. Update .env with your configuration"
echo "  2. Run: python app.py"
echo "  3. Visit: http://localhost:5000"
echo ""
echo "☁️ To deploy to AWS:"
echo "  1. Configure AWS credentials: aws configure"
echo "  2. Update terraform/terraform.tfvars"
echo "  3. Run: ./deploy.sh"
