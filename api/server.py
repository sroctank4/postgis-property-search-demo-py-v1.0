#!/usr/bin/env python3
"""
Flask API Server for postgis-property-search-demo-py
Production-ready server with AWS integration
"""

from flask import Flask, request, jsonify, g
from flask_cors import CORS
import psycopg2
from psycopg2.extras import RealDictCursor
import boto3
import structlog
import os
from datetime import datetime

# Initialize structured logging
logger = structlog.get_logger()

app = Flask(__name__)
CORS(app)

# Configuration
DATABASE_URL = os.getenv('DATABASE_URL')
AWS_REGION = os.getenv('AWS_REGION', 'us-west-2')

# AWS clients
cloudwatch = boto3.client('cloudwatch', region_name=AWS_REGION)

def get_db_connection():
    """Get database connection with error handling"""
    if 'db_conn' not in g:
        g.db_conn = psycopg2.connect(DATABASE_URL)
    return g.db_conn

@app.teardown_appcontext
def close_db(error):
    """Close database connection"""
    db = g.pop('db_conn', None)
    if db is not None:
        db.close()

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        with conn.cursor() as cur:
            cur.execute('SELECT 1')
        return jsonify({'status': 'healthy', 'timestamp': datetime.utcnow().isoformat()})
    except Exception as e:
        logger.error("Health check failed", error=str(e))
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 503

@app.route('/api/search', methods=['GET'])
def search_properties():
    """Property search endpoint with performance monitoring"""
    start_time = datetime.utcnow()
    
    try:
        lat = float(request.args.get('lat', 40.7128))
        lon = float(request.args.get('lon', -74.0060))
        radius = int(request.args.get('radius', 1000))
        
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            query = """
            SELECT id, address, price, bedrooms, bathrooms, square_feet,
                   property_type, listing_status,
                   ST_Distance(geom, ST_SetSRID(ST_Point(%s, %s), 4326)) as distance
            FROM learning.properties 
            WHERE ST_DWithin(geom, ST_SetSRID(ST_Point(%s, %s), 4326), %s)
            AND listing_status = 'Active'
            ORDER BY distance
            LIMIT 50
            """
            cur.execute(query, (lon, lat, lon, lat, radius))
            results = cur.fetchall()
        
        # Calculate response time
        response_time = (datetime.utcnow() - start_time).total_seconds() * 1000
        
        # Send metrics to CloudWatch
        send_metric('PropertySearchLatency', response_time)
        send_metric('PropertySearchCount', len(results))
        
        logger.info("Property search completed", 
                   lat=lat, lon=lon, radius=radius, 
                   results_count=len(results), 
                   response_time_ms=response_time)
        
        return jsonify({
            'results': [dict(row) for row in results],
            'count': len(results),
            'response_time_ms': response_time
        })
        
    except Exception as e:
        logger.error("Property search failed", error=str(e))
        return jsonify({'error': 'Search failed'}), 500

def send_metric(metric_name, value):
    """Send metric to CloudWatch"""
    try:
        cloudwatch.put_metric_data(
            Namespace='LearningApp/API',
            MetricData=[{
                'MetricName': metric_name,
                'Value': value,
                'Unit': 'Milliseconds' if 'Latency' in metric_name else 'Count',
                'Dimensions': [{
                    'Name': 'Environment',
                    'Value': os.getenv('ENVIRONMENT', 'dev')
                }]
            }]
        )
    except Exception as e:
        logger.warning("Failed to send metric", metric=metric_name, error=str(e))

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = os.getenv('ENVIRONMENT', 'dev') == 'dev'
    app.run(host='0.0.0.0', port=port, debug=debug)
