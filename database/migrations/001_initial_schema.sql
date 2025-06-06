-- Migration 001: Initial Schema
-- Generated for postgis-property-search-demo-py
-- 2025-06-06T02:05:23.075Z

BEGIN;

-- Add migration tracking
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(255) PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT NOW()
);

-- Insert this migration
INSERT INTO schema_migrations (version) VALUES ('001_initial_schema')
ON CONFLICT (version) DO NOTHING;


-- Sample property data for testing
INSERT INTO learning.properties (address, price, bedrooms, bathrooms, square_feet, property_type, listing_status, geom, listing_date) VALUES
('123 Market Street, San Francisco, CA 94102', 1250000, 3, 2.5, 1800, 'Single Family', 'Active', ST_SetSRID(ST_Point(-122.4194, 37.7749), 4326), '2024-01-15'),
('456 Mission Street, San Francisco, CA 94103', 950000, 2, 2.0, 1200, 'Condo', 'Active', ST_SetSRID(ST_Point(-122.4094, 37.7849), 4326), '2024-01-18'),
('789 Broadway, San Francisco, CA 94133', 2100000, 4, 3.5, 2500, 'Single Family', 'Active', ST_SetSRID(ST_Point(-122.4294, 37.7949), 4326), '2024-01-20'),
('321 Valencia Street, San Francisco, CA 94110', 850000, 2, 1.5, 1100, 'Condo', 'Pending', ST_SetSRID(ST_Point(-122.4194, 37.7649), 4326), '2024-01-22'),
('654 Fillmore Street, San Francisco, CA 94117', 1850000, 3, 2.5, 2000, 'Townhouse', 'Active', ST_SetSRID(ST_Point(-122.4394, 37.7749), 4326), '2024-01-25');

-- Sample neighborhoods
INSERT INTO learning.neighborhoods (name, city, state, geom, avg_price, property_count) VALUES
('SOMA', 'San Francisco', 'CA', ST_SetSRID(ST_GeomFromText('POLYGON((-122.42 37.77, -122.40 37.77, -122.40 37.78, -122.42 37.78, -122.42 37.77))'), 4326), 1100000, 250),
('Mission', 'San Francisco', 'CA', ST_SetSRID(ST_GeomFromText('POLYGON((-122.43 37.75, -122.41 37.75, -122.41 37.77, -122.43 37.77, -122.43 37.75))'), 4326), 950000, 180);


-- Update statistics
ANALYZE;

COMMIT;
