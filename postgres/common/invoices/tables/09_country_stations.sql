-- =====================================================================
-- app.country_stations - "Country Station" values such as "ARG - Rosario Port"
-- Declarative: the final shape of the table. Existing databases are brought to it by the
-- generated deployment plan (Build/generate-plan.sh, pgschema); never append ALTER statements here.
-- =====================================================================
CREATE TABLE IF NOT EXISTS app.country_stations (
    id              uuid DEFAULT gen_random_uuid() CONSTRAINT pk_country_stations PRIMARY KEY,
    country_code    char(3)         NOT NULL,
    station_name    varchar(150)    NOT NULL,
    display_name    varchar(160)    GENERATED ALWAYS AS (country_code || ' - ' || station_name) STORED,
    CONSTRAINT uq_country_stations UNIQUE (country_code, station_name)
);
