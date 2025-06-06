#!/bin/bash
set -e

echo "🚀 Deploying postgis-property-search-demo-py to AWS..."

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | xargs)
fi

# Validate required environment variables
required_vars=("AWS_REGION" "DATABASE_URL" "ENVIRONMENT")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Error: $var environment variable is required"
        exit 1
    fi
done

echo "📦 Building application..."

# Install dependencies
pip install -r requirements.txt

# Run database migrations
python -m alembic upgrade head

# Run tests
python -m pytest tests/ -v


echo "🗄️ Running database setup..."
psql "$DATABASE_URL" -f database/setup.sql

echo "📊 Updating database statistics..."
psql "$DATABASE_URL" -c "SELECT learning.update_stats();"

echo "☁️ Deploying to AWS..."

# Deploy infrastructure if not exists
if [ ! -d "terraform/.terraform" ]; then
    echo "🏗️ Initializing Terraform..."
    cd terraform
    terraform init
    terraform plan -out=tfplan
    terraform apply tfplan
    cd ..
fi


# Deploy Python application (example with AWS Lambda or ECS)
echo "🐍 Deploying Python application..."
# Add your Python deployment commands here


echo "✅ Deployment completed successfully!"
echo "🔗 Application URL: https://your-app-domain.com"
echo "📈 Monitor performance: https://console.aws.amazon.com/cloudwatch/"
