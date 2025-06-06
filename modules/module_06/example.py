#!/usr/bin/env python3
"""
Module 06 - Property Search Implementation
Educational example for PostGIS and pg_route learning with AWS integration
"""

import psycopg2
from psycopg2.extras import RealDictCursor
import boto3
import os
import time
from typing import List, Dict, Optional

class PropertySearchEngine:
    def __init__(self, connection_string: Optional[str] = None):
        self.conn_string = connection_string or os.getenv('DATABASE_URL')
        self.cloudwatch = boto3.client('cloudwatch')
        
    def get_connection(self):
        """Get database connection with connection pooling"""
        return psycopg2.connect(self.conn_string)
    
    
    def search_nearby_properties(self, lat: float, lon: float, radius_meters: int = 1000) -> List[Dict]:
        """
        High-performance property search with spatial indexing
        Target: Sub-10ms response times on AWS infrastructure
        """
        start_time = time.time()
        
        with self.get_connection() as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                query = """
                SELECT 
                    id, address, price, bedrooms, bathrooms, square_feet,
                    property_type, listing_status,
                    ST_Distance(geom, ST_SetSRID(ST_Point(%s, %s), 4326)) as distance
                FROM learning.properties 
                WHERE ST_DWithin(
                    geom, 
                    ST_SetSRID(ST_Point(%s, %s), 4326),
                    %s
                )
                AND listing_status = 'Active'
                ORDER BY distance
                LIMIT 50;
                """
                cur.execute(query, (lon, lat, lon, lat, radius_meters))
                results = cur.fetchall()
        
        elapsed_ms = (time.time() - start_time) * 1000
        
        # Send metrics to CloudWatch
        self.send_performance_metric('PropertySearchLatency', elapsed_ms)
        
        print(f"Query completed in {elapsed_ms:.2f}ms")
        return [dict(row) for row in results]
    
    
    def send_performance_metric(self, metric_name: str, value: float):
        """Send performance metrics to CloudWatch"""
        try:
            self.cloudwatch.put_metric_data(
                Namespace='LearningApp/Performance',
                MetricData=[
                    {
                        'MetricName': metric_name,
                        'Value': value,
                        'Unit': 'Milliseconds',
                        'Dimensions': [
                            {
                                'Name': 'Environment',
                                'Value': os.getenv('ENVIRONMENT', 'dev')
                            }
                        ]
                    }
                ]
            )
        except Exception as e:
            print(f"Failed to send metric: {e}")

# Example usage
if __name__ == "__main__":
    
    engine = PropertySearchEngine()
    properties = engine.search_nearby_properties(40.7128, -74.0060, 1000)
    print(f"Found {len(properties)} properties")
    
