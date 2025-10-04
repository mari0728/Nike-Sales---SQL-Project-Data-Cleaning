-- SQL Project | Data Cleaning | --

-- Select the raw data (for reference)
SELECT *
FROM online_retail.nike_sales_uncleaned;

-- Create the staging table to perform cleaning
CREATE TABLE online_retail.nike_sales_cleaned
LIKE online_retail.nike_sales_uncleaned;

-- Insert data into the new cleaning table
INSERT nike_sales_cleaned
SELECT * FROM nike_sales_uncleaned;


-- ******************************************************
-- 1. CHECK FOR DUPLICATES AND REMOVE ANY
-- ******************************************************

-- Check for duplicates (No changes needed, this method is correct)
WITH DuplicateCheckCTE AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY Order_ID, Order_Date, Product_Name, Units_Sold, Revenue, Region, Sales_Channel
        ) AS row_num
    FROM
        online_retail.nike_sales_cleaned
)
-- If this SELECT returns rows, you should DELETE them (e.g., DELETE FROM DuplicateCheckCTE WHERE row_num > 1)
SELECT *
FROM DuplicateCheckCTE
WHERE row_num > 1;

-- ASSUMPTION: NO Duplicates Found (Proceed)

-- ******************************************************
-- 2. STANDARDIZE DATA AND FIX ERRORS
-- ******************************************************

SET SQL_SAFE_UPDATES = 0; -- CRITICAL: Temporarily disable Safe Mode

# --- Region Standardization ---

-- Standardize 'bengaluru' to 'Bangalore'
UPDATE online_retail.nike_sales_cleaned
SET Region = 'Bangalore'
WHERE Region IN ('bengaluru', 'Bangalore');

-- Standardize 'Hyd' AND the previously missed 'hyderbad' to 'Hyderabad'
UPDATE nike_sales_cleaned
SET Region = 'Hyderabad'
WHERE Region IN ('Hyd', 'hyderbad', 'Hyderabad'); -- FIX: Added 'hyderbad'

-- Standardize All Regions to Proper Case (Optional, but good practice)
-- UPDATE nike_sales_cleaned SET Region = CONCAT(UPPER(LEFT(Region, 1)), LOWER(SUBSTRING(Region, 2)));

SET SQL_SAFE_UPDATES = 1; -- Re-enable Safe Mode

-- ******************************************************
-- 3. LOOK AT NULL VALUES AND SEE WHAT TO DO
-- ******************************************************

SET SQL_SAFE_UPDATES = 0; -- CRITICAL: Temporarily disable Safe Mode

# --- Imputation (Filling in Blanks) ---

-- Replace NULLs with 0 in Discount_Applied and Units_Sold (as 0 is the logical substitute for missing data)
UPDATE nike_sales_cleaned
SET Units_Sold = 0
WHERE Units_Sold IS NULL;

UPDATE nike_sales_cleaned
SET Discount_Applied = 0.0
WHERE Discount_Applied IS NULL;


-- Fill in missing MRP with the Average MRP of the Same Product 
UPDATE nike_sales_cleaned AS a
JOIN (
    SELECT Product_Name, AVG(MRP) AS avg_mrp
    FROM nike_sales_cleaned
    WHERE MRP IS NOT NULL
    GROUP BY Product_Name
) AS b
ON a.Product_Name = b.Product_Name
SET a.MRP = b.avg_mrp
WHERE a.MRP IS NULL;

-- ******************************************************
-- 4. REMOVE ANY COLUMNS AND ROWS THAT ARE NOT NECESSARY
-- ******************************************************

-- A. Remove ROWS with Illogical or Missing Critical Data

-- Remove records with impossible negative financial/unit values
DELETE FROM nike_sales_cleaned
WHERE
    Units_Sold < 0 OR
    MRP < 0 OR
    Discount_Applied < 0; -- FIX: Added MRP and Discount_Applied checks

-- Remove items with missing dates (NULL or empty string) since sales analysis needs a time reference
DELETE FROM nike_sales_cleaned
WHERE Order_Date IS NULL OR Order_Date = '';

-- Note: The line 'DELETE FROM nike_sales_cleaned WHERE Units_Sold = 0 AND Revenue = 0;'
-- has been omitted as these records (cancelled orders) may be useful for analysis.

-- B. Remove UNNECESSARY COLUMNS

-- Drop the column Size (focus on the sales)
ALTER TABLE nike_sales_cleaned
DROP COLUMN Size;

SET SQL_SAFE_UPDATES = 1; -- Re-enable Safe Mode

-- ******************************************************
-- 5. RECALCULATE REVENUE AND PROFIT (BASED ON IMPUTED DATA)
-- ******************************************************

SET SQL_SAFE_UPDATES = 0; -- Temporarily disable Safe Mode

-- Recalculate REVENUE 
UPDATE nike_sales_cleaned
SET Revenue = (MRP * (1 - Discount_Applied)) * Units_Sold;

-- Recalculate PROFIT 
UPDATE nike_sales_cleaned
SET Profit = (MRP * (1 - Discount_Applied)) * Units_Sold;

SET SQL_SAFE_UPDATES = 1; -- Re-enable Safe Mode

-- ******************************************************
-- 6. CONVERT TO CORRECT DATA TYPES (FINAL STEP)
-- ******************************************************

-- A. Date Conversion 

SET SQL_SAFE_UPDATES = 0; -- Temporarily disable Safe Mode

-- 1. Fix all DD-MM-YYYY formats 
UPDATE nike_sales_cleaned
SET Order_Date = STR_TO_DATE(Order_Date, '%d-%m-%Y')
WHERE Order_Date LIKE '__-__-____';

-- 2. Fix all YYYY/MM/DD formats 
UPDATE nike_sales_cleaned
SET Order_Date = STR_TO_DATE(Order_Date, '%Y/%m/%d')
WHERE Order_Date LIKE '____/__/__';

SET SQL_SAFE_UPDATES = 1; -- Re-enable Safe Mode

-- 3. Convert Order_Date to DATE type
ALTER TABLE nike_sales_cleaned
MODIFY COLUMN Order_Date DATE;

-- B. Numeric Conversions

-- Convert Units_Sold to INT
ALTER TABLE nike_sales_cleaned
MODIFY COLUMN Units_Sold INT;

-- Convert Monetary Columns to DECIMAL 
ALTER TABLE nike_sales_cleaned
MODIFY COLUMN MRP DECIMAL(10, 2),
MODIFY COLUMN Revenue DECIMAL(10, 2),
MODIFY COLUMN Profit DECIMAL(10, 2),
MODIFY COLUMN Discount_Applied DECIMAL(4, 2); -- FIX: Added Discount_Applied conversion

-- Check final table structure (for validation)
DESCRIBE nike_sales_cleaned;

-- Check final data
SELECT *
FROM nike_sales_cleaned;