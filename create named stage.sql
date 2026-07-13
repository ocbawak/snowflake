
-- Create the internal stage optimized for CSV consumption
CREATE OR REPLACE STAGE my_csv_internal_stage
  FILE_FORMAT = (
    TYPE = 'CSV'               -- Explicitly defines the file type engine
    FIELD_DELIMITER = ','      -- Separates individual data fields by commas
    SKIP_HEADER = 1            -- Ignores the first row containing column headers
    FIELD_OPTIONALLY_ENCLOSED_BY = '"' -- Correctly handles text values containing internal commas
    NULL_IF = ('NULL', '')     -- Automatically converts string text fields into SQL NULLs
    EMPTY_FIELD_AS_NULL = TRUE -- Ensures blank empty values don't throw structure errors
  )
  COMMENT = 'Internal stage for processing structured CSV pipeline extractions';



-- 2. Execute the local PUT command (SnowSQL only)
PUT file:///Users/yourmacusername/Documents/data/scraped_output.csv @my_csv_internal_stage
  AUTO_COMPRESS = TRUE;

PUT file:///Users/iphoneiphone/Downloads/archive/usa_county_wise.csv @my_csv_internal_stage
AUTO_COMPRESS = TRUE;

-- Create a file format explicitly optimized for structural schema inference
CREATE OR REPLACE FILE FORMAT my_csv_infer_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  PARSE_HEADER = TRUE         -- CRITICAL: Instructs Snowflake to read row 1 as column names
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;
  
-- Automatically detect layout and create the database table structure
CREATE OR REPLACE TABLE usa_county_csv_table
  USING TEMPLATE (
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
      -- WITHIN GROUP ensures columns retain the precise sequence found in the source file
      WITHIN GROUP (ORDER BY order_id) 
    FROM TABLE(
      INFER_SCHEMA(
        LOCATION => '@my_csv_internal_stage',
        FILE_FORMAT => 'my_csv_infer_format'
      )
    )
  );

-- 3. Execute your bulk data load query
COPY INTO  usa_county_csv_table
  FROM @my_csv_internal_stage
  FILE_FORMAT = (FORMAT_NAME = 'my_csv_infer_format')
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
  ON_ERROR = 'CONTINUE'; -- Gracefully skips individual corrupted lines i