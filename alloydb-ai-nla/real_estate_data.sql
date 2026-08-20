CREATE EXTENSION IF NOT EXISTS vector;
DROP SCHEMA IF EXISTS real_estate CASCADE;
CREATE SCHEMA real_estate;
CREATE TABLE real_estate.municipalities (
    municipality_id SERIAL PRIMARY KEY,
    municipality_name VARCHAR(255) UNIQUE NOT NULL,
    average_school_ranking DECIMAL(4, 2),
    crime_rate_per_100k DECIMAL(6, 2)
);
CREATE TABLE real_estate.cities (
    city_id SERIAL PRIMARY KEY,
    municipality_id INTEGER NOT NULL,
    city_name VARCHAR(255) UNIQUE NOT NULL,
    city_province VARCHAR(50) NOT NULL,
    CONSTRAINT fk_city_municipality
        FOREIGN KEY (municipality_id)
        REFERENCES real_estate.municipalities(municipality_id)
);
CREATE TABLE real_estate.agents (
    agent_id SERIAL PRIMARY KEY,
    firstname VARCHAR(255) NOT NULL,
    lastname VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    brokerage VARCHAR(255),
    is_active BOOLEAN
);
CREATE TABLE real_estate.properties (
    property_id SERIAL PRIMARY KEY,
    address_street VARCHAR(255) NOT NULL,
    city_id INTEGER NOT NULL,
    address_postal_code VARCHAR(20),
    price DECIMAL(12, 2) NOT NULL,
    bedrooms INTEGER,
    bathrooms DECIMAL(3, 1),
    listing_status VARCHAR(50),
    is_single_family BOOLEAN,
    is_condo BOOLEAN,
    has_garage BOOLEAN,
    num_stories INTEGER,
    description TEXT,
    description_embedding VECTOR(3072),
    CONSTRAINT fk_property_city
        FOREIGN KEY (city_id)
        REFERENCES real_estate.cities(city_id)
);
CREATE TABLE real_estate.schools (
    school_id SERIAL PRIMARY KEY,
    city_id INTEGER NOT NULL,
    school_name VARCHAR(255) NOT NULL,
    school_ranking INTEGER,
    CONSTRAINT fk_school_city
        FOREIGN KEY (city_id)
        REFERENCES real_estate.cities(city_id)
);
CREATE TABLE real_estate.school_to_property (
    school_id INTEGER NOT NULL,
    property_id INTEGER NOT NULL,
    proximity_miles DECIMAL(5, 2),
    PRIMARY KEY (school_id, property_id),
    CONSTRAINT fk_stp_school
        FOREIGN KEY (school_id)
        REFERENCES real_estate.schools(school_id),
    CONSTRAINT fk_stp_property
        FOREIGN KEY (property_id)
        REFERENCES real_estate.properties(property_id)
);
CREATE TABLE real_estate.property_transactions (
    property_id INTEGER,
    sale_date DATE NOT NULL,
    sale_price DECIMAL(12, 2) NOT NULL,
    seller_agent_id INTEGER,
    CONSTRAINT fk_transaction_property
        FOREIGN KEY (property_id)
        REFERENCES real_estate.properties(property_id),
    CONSTRAINT fk_transaction_seller_agent
        FOREIGN KEY (seller_agent_id)
        REFERENCES real_estate.agents(agent_id)
);
CREATE TABLE real_estate.offers (
    offer_id SERIAL PRIMARY KEY,
    property_id INTEGER NOT NULL,
    buyer_agent_id INTEGER,
    seller_agent_id INTEGER,
    offer_amount DECIMAL(12, 2) NOT NULL,
    offer_date DATE NOT NULL,
    offer_status VARCHAR(20) NOT NULL CHECK (offer_status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'WITHDRAWN', 'EXPIRED')),
    offer_expiration_date DATE,
    contingencies TEXT,
    CONSTRAINT fk_offer_property
        FOREIGN KEY (property_id)
        REFERENCES real_estate.properties(property_id),
    CONSTRAINT fk_offer_buyer_agent
        FOREIGN KEY (buyer_agent_id)
        REFERENCES real_estate.agents(agent_id),
    CONSTRAINT fk_offer_seller_agent
        FOREIGN KEY (seller_agent_id)
        REFERENCES real_estate.agents(agent_id)
);
-- Populating municipalities
INSERT INTO real_estate.municipalities (municipality_name, average_school_ranking, crime_rate_per_100k) VALUES
('Waterloo', 8.50, 2900.50),
('Kitchener', 7.90, 3150.25),
('Santa Clara', 9.10, 2500.00),
('Riverside', 6.50, 4100.15),
('San Diego', 8.20, 3800.40),
('Del Mar', 9.50, 410.10),
('La Jolla', 9.40, 2200.75),
('Westwood', 9.20, 3500.00);
-- Populating cities
INSERT INTO real_estate.cities (municipality_id, city_name, city_province) VALUES
(1, 'Waterloo', 'Ontario'),
(2, 'Kitchener', 'Ontario'),
(3, 'Santa Clara', 'California'),
(4, 'Riverside', 'California'),
(5, 'San Diego', 'California'),
(6, 'Del Mar', 'California'),
(7, 'La Jolla', 'California'),
(8, 'Westwood', 'California');
-- Populating agents
INSERT INTO real_estate.agents (firstname, lastname, email, phone, brokerage, is_active) VALUES
('Liam', 'O''Connell', 'liam.oconnell@example.com', '519-555-0011', 'KW Realty', TRUE),
('Aisha', 'Patel', 'aisha.patel@example.com', '408-555-0022', 'Silicon Valley Homes', TRUE),
('Ben', 'Chen', 'ben.chen@example.com', '519-555-0033', 'KW Realty', TRUE),
('Chloe', 'Davis', 'chloe.davis@example.com', '951-555-0044', 'Riverside Estates', TRUE),
('David', 'Kim', 'david.kim@example.com', '619-555-0055', 'Pacific Coast Homes', TRUE),
('Sarah', 'Miller', 'sarah.miller@example.com', '858-555-0066', 'Coastal Luxury Group', TRUE),
('Chris', 'Foster', 'chris.foster@example.com', '310-555-0077', 'Westwood', TRUE);
-- Populating properties
INSERT INTO real_estate.properties (property_id, address_street, city_id, address_postal_code, price, bedrooms, bathrooms, listing_status, is_single_family, is_condo, has_garage, num_stories) VALUES
(1, '123 University Ave W', 1, 'N2L 3G7', 750000.00, 3, 2.5, 'Active', FALSE, FALSE, TRUE, 2),
(2, '45 King St N, Unit 1205', 1, 'N2J 0A1', 450000.00, 1, 1.0, 'Active', FALSE, TRUE, FALSE, 1),
(3, '80 Blue Springs Dr', 1, 'N2J 4J5', 1250000.00, 4, 3.5, 'Sold', TRUE, FALSE, TRUE, 2),
(4, '25 Victoria St S', 2, 'N2G 2B4', 625000.00, 2, 2.0, 'Pending', FALSE, FALSE, TRUE, 3),
(5, '345 Highland Rd W', 2, 'N2M 5P4', 510000.00, 2, 1.0, 'Active', TRUE, FALSE, TRUE, 1),
(6, '2800 Mission College Blvd', 3, '95054', 1850000.00, 4, 3.0, 'Sold', TRUE, FALSE, TRUE, 2),
(7, '101 Tech Way, Apt 301', 3, '95050', 899000.00, 2, 2.0, 'Active', FALSE, TRUE, FALSE, 1),
(8, '500 Saratoga Ave', 3, '95051', 2500000.00, 5, 4.5, 'Pending', TRUE, FALSE, TRUE, 2),
(9, '1500 Orange St', 4, '92501', 420000.00, 3, 2.0, 'Active', TRUE, FALSE, TRUE, 1),
(10, '700 Jurupa Ave', 4, '92506', 550000.00, 4, 3.0, 'Active', TRUE, FALSE, TRUE, 2),
(11, '500 Ocean View Blvd', 5, '92109', 3100000.00, 4, 3.5, 'Active', TRUE, FALSE, TRUE, 2),
(12, '100 Gaslamp Quarter', 5, '92101', 950000.00, 2, 2.0, 'Active', FALSE, TRUE, FALSE, 1),
(13, '51 Parkside Drive', 1, 'N2L 4J3', 699000.00, 3, 1.5, 'Active', FALSE, FALSE, TRUE, 2),
(14, '600 Forest Glen Rd', 2, 'N2M 4K6', 820000.00, 4, 2.5, 'Active', TRUE, FALSE, TRUE, 2),
(15, '40 Main St, Unit 8', 2, 'N2H 2G8', 399000.00, 1, 1.0, 'Active', FALSE, TRUE, FALSE, 1),
(16, '95 Palm Ave', 3, '95051', 1450000.00, 3, 2.0, 'Sold', TRUE, FALSE, TRUE, 1),
(17, '1200 San Gabriel Dr', 3, '95051', 3200000.00, 6, 5.0, 'Active', TRUE, FALSE, TRUE, 3),
(18, '800 Mission Inn Ave', 4, '92507', 610000.00, 4, 2.5, 'Pending', TRUE, FALSE, TRUE, 2),
(19, '1800 Chicago Ave', 4, '92501', 350000.00, 2, 1.0, 'Active', TRUE, FALSE, FALSE, 1),
(20, '2000 Torrey Pines Rd', 5, '92037', 5500000.00, 5, 4.5, 'Active', TRUE, FALSE, TRUE, 2),
(21, '300 Embarcadero', 5, '92101', 1100000.00, 1, 1.5, 'Active', FALSE, TRUE, FALSE, 1),
(22, '700 Bridge St', 1, 'N2J 4J5', 850000.00, 3, 3.0, 'Active', FALSE, FALSE, TRUE, 3),
(23, '150 Fairway Rd S', 2, 'N2C 1X4', 480000.00, 2, 1.0, 'Active', TRUE, FALSE, TRUE, 1),
(24, '2500 El Camino Real', 3, '95051', 1600000.00, 3, 2.5, 'Pending', TRUE, FALSE, TRUE, 1),
(25, '2200 University Ave', 4, '92507', 725000.00, 5, 3.0, 'Active', TRUE, FALSE, TRUE, 2),
(26, '800 La Jolla Shores Dr', 5, '92037', 4100000.00, 3, 3.0, 'Active', TRUE, FALSE, TRUE, 2),
(27, '200 Coast Blvd', 6, '92014', 6500000.00, 4, 4.5, 'Active', TRUE, FALSE, TRUE, 3),
(28, '100 Del Mar Heights Rd', 6, '92014', 1500000.00, 2, 2.0, 'Pending', FALSE, TRUE, FALSE, 1),
(29, '100 Wilshire Blvd, Unit 5A', 7, '90024', 950000.00, 1, 1.0, 'Active', FALSE, TRUE, FALSE, 1),
(30, '450 Veteran Ave', 7, '90024', 3800000.00, 4, 3.5, 'Pending', TRUE, FALSE, TRUE, 2),
(31, '999 Main Ave', 6, '90024', 3800000.00, 4, 3.5, 'Active', TRUE, FALSE, TRUE, 1),
(32, '999 Main St', 8, '99999', 3800000.00, 4, 3.5, 'Sold', TRUE, FALSE, TRUE, 1);
-- ID 3: Waterfront (Lake/River, updated to panoramic vista)
UPDATE real_estate.properties
SET description = 'Spacious 4-bedroom executive home on a half-acre lot. This beautiful property features an unobstructed, panoramic view of the lake, offering a truly breathtaking lifestyle. Includes two fireplaces and a triple garage.'
WHERE property_id = 3;
-- ID 8: Luxury SFH (High Elevation/Commanding View)
UPDATE real_estate.properties
SET description = 'Luxury 5-bedroom, 4.5-bath house on a high elevation. Offers a commanding view of the city and surrounding mountains, giving a panoramic vista. Currently has an accepted offer. Three-car garage.'
WHERE property_id = 8;
-- ID 11: Ocean View Blvd (Massive Sweeping Ocean View)
UPDATE real_estate.properties
SET description = 'Luxury custom-built home on Ocean View Blvd. Features three-car garage and central air. Offers a massive, sweeping view of the deep blue horizon that stretches for miles. Slightly longer days on market due to high price point.'
WHERE property_id = 11;
-- ID 12: Downtown Condo (Sunsets Over the Water)
UPDATE real_estate.properties
SET description = 'High-demand downtown 2-bedroom condo in the Gaslamp area. Watch spectacular big sunsets over the water from your unit. Excellent walkability and transit score. HOA covers all luxury amenities.'
WHERE property_id = 12;
-- ID 24: SFH El Camino Real (Hilltop/Valley View)
UPDATE real_estate.properties
SET description = 'Prime location single-story home with excellent school district access. The hilltop location provides a massive, sweeping view of the entire valley. Pending inspection. Fireplace in the living room and two-car garage.'
WHERE property_id = 24;
-- ID 28: Coastal Condo (Magnificent Marine Spectacle)
UPDATE real_estate.properties
SET description = 'Well-located 2-bedroom condo with excellent proximity to coastal shopping and dining. The balcony provides a magnificent marine spectacle against an azure backdrop. Under contract, high monthly HOA fee.'
WHERE property_id = 28;
-- ID 14: Single-Family (Wooded/Lush)
UPDATE real_estate.properties
SET description = 'Classic 4-bed single-family home on a wooded, lush cul-de-sac. Surrounded by mature oak trees and backs up directly to a parkland. Large finished basement. Offer accepted, awaiting closing.'
WHERE property_id = 14;
-- ID 15: Compact Condo (Convenience/No View)
UPDATE real_estate.properties
SET description = 'Compact 1-bedroom condo perfect for students or first-time buyers. All about convenience and interior finishes, no view noted. High walk score, very central location. Monthly HOA covers heat. Newly remodeled and move-in ready. Kitchen appliances have been upgraded recently.'
WHERE property_id = 15;
-- ID 19: Bungalow (Tucked Away/Rooftops)
UPDATE real_estate.properties
SET description = 'Vintage 2-bedroom bungalow. Tucked away and surrounded by mature oak trees. The view consists entirely of neighboring rooftops. Great potential for investors or handy first-time buyers. No central air or garage.'
WHERE property_id = 19;
UPDATE real_estate.properties
SET description_embedding = google_ml.embedding('gemini-embedding-001', description)
WHERE description IS NOT NULL AND description_embedding IS NULL;
-- Populating schools
INSERT INTO real_estate.schools (school_name, city_id, school_ranking) VALUES
('Bluevale Collegiate Institute', 1, 4),
('Resurrection Catholic SS', 1, 4),
('Eastwood Collegiate Institute', 2, 5),
('KCI', 2, 6),
('Santa Clara High School', 3, 4),
('Bellarmine College Prep', 3, 1),
('Riverside Polytechnic High', 4, 4),
('Ramona High School', 4, 7),
('La Jolla High School', 5, 2),
('The Bishop''s School', 5, 1),
('Del Mar Heights Elementary', 6, 1),
('Torrey Pines High School', 6, 1),
('Westwood Charter Elementary', 7, 4),
('UCLA Lab School', 7, 2);
-- Populating school_to_property
INSERT INTO real_estate.school_to_property (school_id, property_id, proximity_miles) VALUES
(1, 1, 1.25), (2, 1, 2.50), (1, 2, 0.50), (3, 2, 3.10), (2, 3, 3.00), (4, 3, 4.50), (3, 4, 0.90), (4, 4, 1.10), (4, 5, 2.00),
(5, 6, 1.00), (6, 6, 3.50), (5, 7, 0.75), (6, 7, 2.00), (5, 8, 4.00), (6, 8, 4.50), (7, 9, 0.80), (8, 9, 2.10),
(7, 10, 3.50), (8, 10, 1.50), (9, 11, 1.10), (10, 11, 5.50), (9, 12, 0.20), (10, 12, 6.00), (1, 13, 2.00), (2, 13, 1.50),
(3, 14, 1.00), (4, 14, 2.00), (3, 15, 0.50), (5, 16, 2.00), (6, 16, 3.00), (5, 17, 3.50), (6, 17, 2.50), (7, 18, 0.90),
(8, 18, 1.90), (7, 19, 2.00), (8, 19, 1.00), (9, 20, 1.50), (10, 20, 4.50), (9, 21, 0.80), (10, 21, 5.20), (1, 22, 3.00),
(2, 22, 2.00), (11, 27, 0.50), (12, 27, 2.50), (11, 28, 1.00), (12, 28, 3.00), (13, 29, 1.10), (14, 29, 0.80),
(13, 30, 0.50), (14, 30, 1.20);
-- Populating property_transactions
INSERT INTO real_estate.property_transactions (property_id, sale_date, sale_price, seller_agent_id) VALUES
(3, '2025-05-22', 1250000.00, 1),
(6, '2025-07-01', 1850000.00, 2),
(9, '2025-10-05', 420000.00, 4),
(12, '2025-09-30', 1450000.00, 2),
(2, '2025-10-01', 445000.00, 1),
(1, '2025-09-15', 775000.00, 1),
(5, '2025-10-05', 510000.00, 3),
(13, '2025-10-01', 690000.00, 1),
(10, '2025-09-01', 550000.00, 4),
(18, '2025-08-28', 610000.00, 4),
(27, '2025-10-10', 6450000.00, 6),
(30, '2025-09-30', 3800000.00, 7);
-- Populating offers
INSERT INTO real_estate.offers (offer_id, property_id, buyer_agent_id, seller_agent_id, offer_amount, offer_date, offer_status, offer_expiration_date, contingencies) VALUES
(1, 3, 3, 1, 1250000.00, '2025-05-18', 'ACCEPTED', '2025-05-20', 'Clear closing in 5 days'),
(2, 6, 5, 2, 1850000.00, '2025-06-25', 'ACCEPTED', '2025-06-27', 'Standard financing, 45-day close'),
(3, 9, 5, 4, 420000.00, '2025-09-28', 'ACCEPTED', '2025-10-01', 'Cash offer, AS-IS'),
(4, 12, 2, 5, 950000.00, '2025-09-20', 'REJECTED', '2025-09-22', 'Financing contingency'),
(5, 12, 2, 5, 1450000.00, '2025-09-27', 'ACCEPTED', '2025-09-29', 'All cash, immediate closing'),
(6, 2, 3, 1, 445000.00, '2025-09-26', 'ACCEPTED', '2025-09-28', 'Financing contingency'),
(7, 1, 1, 1, 775000.00, '2025-09-10', 'ACCEPTED', '2025-09-12', 'Waive inspection'),
(8, 5, 1, 3, 510000.00, '2025-10-02', 'ACCEPTED', '2025-10-04', 'Standard 30-day financing'),
(9, 13, 3, 1, 690000.00, '2025-09-27', 'ACCEPTED', '2025-09-30', 'Inspection contingency'),
(10, 10, 4, 4, 550000.00, '2025-08-25', 'ACCEPTED', '2025-08-27', 'Contingent on appraisal'),
(11, 18, 5, 4, 610000.00, '2025-08-20', 'ACCEPTED', '2025-08-22', 'Contingent on financing'),
(12, 27, 5, 6, 6450000.00, '2025-10-05', 'ACCEPTED', '2025-10-07', 'Financing contingency, 60-day close'),
(13, 4, 3, 3, 625000.00, '2025-09-20', 'ACCEPTED', '2025-09-22', 'Inspection contingency'),
(14, 8, 2, 2, 2500000.00, '2025-09-28', 'ACCEPTED', '2025-09-30', 'No contingencies, quick close'),
(15, 14, 3, 3, 820000.00, '2025-09-01', 'ACCEPTED', '2025-09-03', 'Financing contingency'),
(16, 24, 2, 2, 1600000.00, '2025-09-25', 'ACCEPTED', '2025-09-27', 'Contingent on inspection'),
(17, 28, 6, 6, 1500000.00, '2025-09-29', 'ACCEPTED', '2025-10-01', 'Cash offer, 45-day close'),
(18, 4, 1, 3, 600000.00, '2025-09-18', 'REJECTED', '2025-09-20', 'Low bid, inspection contingency'),
(19, 8, 5, 2, 2450000.00, '2025-09-27', 'REJECTED', '2025-09-29', 'Financing contingency'),
(20, 14, 4, 3, 800000.00, '2025-08-30', 'REJECTED', '2025-09-01', 'Inspection and financing'),
(21, 24, 5, 2, 1550000.00, '2025-09-24', 'REJECTED', '2025-09-26', 'Inspection contingency'),
(22, 28, 5, 6, 1400000.00, '2025-09-27', 'REJECTED', '2025-09-29', 'Financing contingency'),
(23, 7, 5, 2, 850000.00, '2025-10-01', 'PENDING', '2025-10-08', 'Financing contingency'),
(24, 7, 3, 2, 899000.00, '2025-10-05', 'PENDING', '2025-10-09', 'Clean offer'),
(25, 11, 6, 5, 2900000.00, '2025-09-01', 'REJECTED', '2025-09-03', 'Contingent on sale of current home'),
(26, 11, 4, 5, 3000000.00, '2025-09-15', 'REJECTED', '2025-09-17', 'Inspection and appraisal'),
(27, 11, 4, 5, 3050000.00, '2025-10-01', 'PENDING', '2025-10-07', 'Inspection contingency'),
(28, 15, 1, 3, 399000.00, '2025-10-06', 'PENDING', '2025-10-08', 'Standard financing'),
(29, 17, 6, 2, 3100000.00, '2025-10-02', 'PENDING', '2025-10-09', 'Inspection contingency'),
(30, 17, 5, 2, 3000000.00, '2025-09-25', 'REJECTED', '2025-09-27', 'Low bid, financing'),
(31, 19, 5, 4, 320000.00, '2025-10-05', 'PENDING', '2025-10-09', 'AS-IS, quick close'),
(32, 20, 6, 5, 5000000.00, '2025-07-20', 'REJECTED', '2025-07-22', 'Standard financing'),
(33, 20, 2, 5, 5200000.00, '2025-08-01', 'REJECTED', '2025-08-03', 'Inspection contingency'),
(34, 20, 3, 5, 5350000.00, '2025-09-25', 'PENDING', '2025-10-07', 'Financing contingency'),
(35, 21, 6, 5, 1050000.00, '2025-09-30', 'PENDING', '2025-10-07', 'Inspection contingency'),
(36, 22, 1, 1, 850000.00, '2025-10-03', 'PENDING', '2025-10-06', 'Inspection and financing'),
(37, 23, 4, 3, 450000.00, '2025-10-01', 'PENDING', '2025-10-05', 'Standard financing'),
(38, 25, 5, 4, 700000.00, '2025-09-25', 'PENDING', '2025-10-06', 'Inspection contingency'),
(39, 26, 6, 5, 4000000.00, '2025-09-01', 'REJECTED', '2025-09-03', 'Financing contingency'),
(40, 26, 4, 5, 4050000.00, '2025-09-15', 'REJECTED', '2025-09-17', 'Cash, 60-day close'),
(41, 26, 2, 5, 4100000.00, '2025-10-03', 'PENDING', '2025-10-08', 'Clean offer, quick close'),
(42, 3, 4, 1, 1150000.00, '2025-05-15', 'REJECTED', '2025-05-17', 'Low offer, inspection'),
(43, 6, 3, 2, 1800000.00, '2025-06-20', 'REJECTED', '2025-06-22', 'Standard financing'),
(44, 1, 4, 1, 740000.00, '2025-08-05', 'REJECTED', '2025-08-07', 'Inspection contingency'),
(45, 10, 5, 4, 535000.00, '2025-08-23', 'REJECTED', '2025-08-25', 'Inspection and financing'),
(46, 18, 5, 4, 590000.00, '2025-08-15', 'REJECTED', '2025-08-17', 'Low bid, inspection'),
(47, 2, 5, 1, 400000.00, '2025-09-20', 'REJECTED', '2025-09-22', 'Standard financing'),
(48, 24, 6, 2, 1500000.00, '2025-09-15', 'REJECTED', '2025-09-17', 'Contingent on sale'),
(49, 14, 1, 3, 790000.00, '2025-08-25', 'REJECTED', '2025-08-27', 'Financing'),
(50, 8, 4, 2, 2400000.00, '2025-09-20', 'REJECTED', '2025-09-22', 'Inspection contingency');
COMMENT ON TABLE real_estate.agents IS 'Stores profile, contact, brokerage affiliation, and active status for individual real estate agents.';
COMMENT ON COLUMN real_estate.agents.agent_id IS 'Primary key uniquely identifying each real estate agent in the database.';
COMMENT ON COLUMN real_estate.agents.firstname IS 'Stores the given name of an agent for identification and listing displays.';
COMMENT ON COLUMN real_estate.agents.lastname IS 'Stores the agent''s surname to facilitate human-readable search and full-name display.';
COMMENT ON COLUMN real_estate.agents.email IS 'Stores the agent''s email address, acting as a primary channel for communications.';
COMMENT ON COLUMN real_estate.agents.phone IS 'Flexible text field storing the agent''s contact phone number in various formats.';
COMMENT ON COLUMN real_estate.agents.brokerage IS 'Specifies the name of the real estate firm the agent is affiliated with.';
COMMENT ON COLUMN real_estate.agents.is_active IS 'Boolean flag indicating if the agent is currently active or inactive.';
COMMENT ON TABLE real_estate.cities IS 'Stores city names, provinces, and foreign keys linking cities to their parent municipalities.';
COMMENT ON COLUMN real_estate.cities.municipality_id IS 'Foreign key linking the city to its governing administrative division.';
COMMENT ON COLUMN real_estate.cities.city_name IS 'Stores the official, human-readable name of the city for reports and listings.';
COMMENT ON COLUMN real_estate.cities.city_province IS 'Stores the province or state name for regional filtering and market analysis.';
COMMENT ON COLUMN real_estate.cities.city_id IS 'Primary key uniquely identifying each distinct city in the geographic hierarchy.';
COMMENT ON TABLE real_estate.municipalities IS 'Stores municipality names alongside key socio-economic indicators like school rankings and crime rates.';
COMMENT ON COLUMN real_estate.municipalities.municipality_id IS 'Primary key uniquely identifying each municipality to maintain relational data integrity.';
COMMENT ON COLUMN real_estate.municipalities.municipality_name IS 'Stores the official administrative name of the municipality for public display.';
COMMENT ON COLUMN real_estate.municipalities.average_school_ranking IS 'Numeric field averaging performance of local schools, used to evaluate neighborhood desirability.';
COMMENT ON COLUMN real_estate.municipalities.crime_rate_per_100k IS 'Normalized crime rate per 100,000 residents, evaluating public safety in the area.';
COMMENT ON TABLE real_estate.offers IS 'Tracks purchase offers, pricing, submission dates, status, deadlines, and structural contingencies on properties.';
COMMENT ON COLUMN real_estate.offers.offer_id IS 'Primary key uniquely identifying a specific purchase offer in the system.';
COMMENT ON COLUMN real_estate.offers.property_id IS 'Foreign key linking the offer directly to the target property being bid on.';
COMMENT ON COLUMN real_estate.offers.buyer_agent_id IS 'Foreign key identifying the agent representing the buyer in the offer transaction.';
COMMENT ON COLUMN real_estate.offers.seller_agent_id IS 'Foreign key identifying the agent representing the property seller.';
COMMENT ON COLUMN real_estate.offers.offer_amount IS 'Numeric currency field recording the buyer''s proposed purchase price.';
COMMENT ON COLUMN real_estate.offers.offer_date IS 'Records the exact calendar date the offer was formally submitted.';
COMMENT ON COLUMN real_estate.offers.offer_status IS 'Categorical text tracking the offer lifecycle (e.g., Pending, Accepted, Rejected).';
COMMENT ON COLUMN real_estate.offers.offer_expiration_date IS 'Sets the deadline date by which the offer must be accepted or voided.';
COMMENT ON COLUMN real_estate.offers.contingencies IS 'JSON text field listing specific clauses (e.g., financing, inspections) validating the contract.';
COMMENT ON TABLE real_estate.properties IS 'Core repository for property listings, capturing location, price, physical features, status, and search embeddings.';
COMMENT ON COLUMN real_estate.properties.property_id IS 'Primary key uniquely identifying each real estate listing in the database.';
COMMENT ON COLUMN real_estate.properties.address_street IS 'Stores the street name and house number for physical location mapping.';
COMMENT ON COLUMN real_estate.properties.city_id IS 'Foreign key mapping the property listing directly to its geographical city.';
COMMENT ON COLUMN real_estate.properties.address_postal_code IS 'Text field storing the postal or zip code for regional location searches.';
COMMENT ON COLUMN real_estate.properties.price IS 'Numeric field storing the property''s asking price, critical for financial filtering.';
COMMENT ON COLUMN real_estate.properties.bedrooms IS 'Integer tracking the total bedroom count inside the listed property.';
COMMENT ON COLUMN real_estate.properties.bathrooms IS 'Numeric field tracking full and half bathrooms (e.g., 2.5) in the home.';
COMMENT ON COLUMN real_estate.properties.listing_status IS 'Tracks market availability stage of the listing (e.g., Active, Pending, Sold).';
COMMENT ON COLUMN real_estate.properties.is_single_family IS 'Boolean flag indicating if the property is a standalone single-family home.';
COMMENT ON COLUMN real_estate.properties.is_condo IS 'Boolean flag indicating if the property structure is a condominium.';
COMMENT ON COLUMN real_estate.properties.has_garage IS 'Boolean flag indicating whether the property includes private garage parking.';
COMMENT ON COLUMN real_estate.properties.num_stories IS 'Integer representing the total number of physical floors in the building layout.';
COMMENT ON COLUMN real_estate.properties.description IS 'Rich text field offering a comprehensive overview of the home''s key selling points.';
COMMENT ON COLUMN real_estate.properties.description_embedding IS 'Vector array of description text, used for AI-driven semantic property searches.';
COMMENT ON TABLE real_estate.property_transactions IS 'Historical log of completed sales, recording dates, final prices, properties sold, and facilitating agents.';
COMMENT ON COLUMN real_estate.property_transactions.property_id IS 'Foreign key identifying the specific property bought or sold in the transaction.';
COMMENT ON COLUMN real_estate.property_transactions.sale_date IS 'Records the calendar date on which the transaction was finalized.';
COMMENT ON COLUMN real_estate.property_transactions.sale_price IS 'High-precision numeric field recording the final agreed-upon transaction sale price.';
COMMENT ON COLUMN real_estate.property_transactions.seller_agent_id IS 'Foreign key identifying the listing agent who closed the transaction for the seller.';
COMMENT ON TABLE real_estate.schools IS 'Stores educational institution profiles, names, and academic rankings, mapped to their respective cities.';
COMMENT ON COLUMN real_estate.schools.school_id IS 'Primary key uniquely identifying each educational institution record.';
COMMENT ON COLUMN real_estate.schools.city_id IS 'Foreign key linking the school directly to its geographical city.';
COMMENT ON COLUMN real_estate.schools.school_name IS 'Stores the official name of the school for search and listing details.';
COMMENT ON COLUMN real_estate.schools.school_ranking IS 'Integer ranking of academic performance; lower numbers indicate higher prestige.';
