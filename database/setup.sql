-- Database Setup for postgis-property-search-demo-py
-- PostgreSQL 15 + PostGIS 3.4

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgrouting;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create schema
CREATE SCHEMA IF NOT EXISTS learning;
SET search_path TO learning, public;


-- Property search tables
CREATE TABLE learning.properties (
    id SERIAL PRIMARY KEY,
    address TEXT NOT NULL,
    price DECIMAL(12,2),
    bedrooms INTEGER,
    bathrooms DECIMAL(3,1),
    square_feet INTEGER,
    property_type VARCHAR(50),
    listing_status VARCHAR(20),
    geom GEOMETRY(POINT, 4326) NOT NULL,
    listing_date DATE,
    last_updated TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT valid_price CHECK (price > 0),
    CONSTRAINT valid_bedrooms CHECK (bedrooms >= 0),
    CONSTRAINT valid_bathrooms CHECK (bathrooms >= 0),
    CONSTRAINT valid_square_feet CHECK (square_feet > 0)
);

-- Spatial indexes for high-performance queries
CREATE INDEX idx_properties_geom ON learning.properties USING GIST (geom);
CREATE INDEX idx_properties_price ON learning.properties (price);
CREATE INDEX idx_properties_type ON learning.properties (property_type);
CREATE INDEX idx_properties_status ON learning.properties (listing_status);
CREATE INDEX idx_properties_bedrooms ON learning.properties (bedrooms);
CREATE INDEX idx_properties_compound ON learning.properties (property_type, listing_status, price);

-- Cluster table by spatial index for better performance
CLUSTER learning.properties USING idx_properties_geom;

-- Property features table
CREATE TABLE learning.property_features (
    id SERIAL PRIMARY KEY,
    property_id INTEGER REFERENCES learning.properties(id) ON DELETE CASCADE,
    feature_type VARCHAR(50) NOT NULL,
    feature_value TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_property_features_property_id ON learning.property_features (property_id);
CREATE INDEX idx_property_features_type ON learning.property_features (feature_type);

-- Neighborhoods table
CREATE TABLE learning.neighborhoods (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(2) NOT NULL,
    geom GEOMETRY(POLYGON, 4326) NOT NULL,
    avg_price DECIMAL(12,2),
    property_count INTEGER DEFAULT 0
);

CREATE INDEX idx_neighborhoods_geom ON learning.neighborhoods USING GIST (geom);
CREATE INDEX idx_neighborhoods_name ON learning.neighborhoods (name);


-- Create materialized views for performance

CREATE MATERIALIZED VIEW learning.property_summary AS
SELECT 
    property_type,
    listing_status,
    COUNT(*) as property_count,
    AVG(price) as avg_price,
    MIN(price) as min_price,
    MAX(price) as max_price,
    AVG(square_feet) as avg_square_feet
FROM learning.properties 
WHERE listing_status = 'Active'
GROUP BY property_type, listing_status;

CREATE UNIQUE INDEX idx_property_summary_unique ON learning.property_summary (property_type, listing_status);


-- Performance monitoring
CREATE OR REPLACE FUNCTION learning.update_stats() RETURNS void AS $$
BEGIN
    ANALYZE learning.properties;
    REFRESH MATERIALIZED VIEW learning.property_summary;
END;
$$ LANGUAGE plpgsql;

-- Create performance monitoring user
CREATE USER readonly_user WITH PASSWORD 'readonly_password';
GRANT CONNECT ON DATABASE learning TO readonly_user;
GRANT USAGE ON SCHEMA learning TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA learning TO readonly_user;
