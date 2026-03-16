-- ============================================================================
-- DATA1500 - Oblig 1: Bysykkeldatabasen
-- Initialiserings-skript for PostgreSQL
-- ============================================================================

-- Rydd opp
DROP TABLE IF EXISTS utleie CASCADE;
DROP TABLE IF EXISTS sykkel CASCADE;
DROP TABLE IF EXISTS laas CASCADE;
DROP TABLE IF EXISTS kunde CASCADE;
DROP TABLE IF EXISTS stasjon CASCADE;
DROP VIEW IF EXISTS kunde_1_utleier CASCADE;

-- ============================================================================
-- TABELLER
-- ============================================================================

CREATE TABLE stasjon (
    stasjon_id SERIAL PRIMARY KEY,
    navn       VARCHAR(100) NOT NULL,
    adresse    VARCHAR(200) NOT NULL
);

CREATE TABLE laas (
    laas_id    SERIAL PRIMARY KEY,
    stasjon_id INT NOT NULL REFERENCES stasjon(stasjon_id)
);

CREATE TABLE sykkel (
    sykkel_id     SERIAL PRIMARY KEY,
    modell        VARCHAR(100) NOT NULL,
    innkjopsdato  DATE NOT NULL,
    stasjon_id    INT REFERENCES stasjon(stasjon_id),
    laas_id       INT UNIQUE REFERENCES laas(laas_id)
);

CREATE TABLE kunde (
    kunde_id   SERIAL PRIMARY KEY,
    fornavn    VARCHAR(50)  NOT NULL,
    etternavn  VARCHAR(50)  NOT NULL,
    mobilnr    VARCHAR(15)  NOT NULL UNIQUE,
    epost      VARCHAR(100) NOT NULL UNIQUE,
    CONSTRAINT chk_mobilnr CHECK (mobilnr ~ '^\+47[0-9]{8}$'),
    CONSTRAINT chk_epost   CHECK (epost ~ '^[^@]+@[^@]+\.[^@]+$')
);

CREATE TABLE utleie (
    utleie_id        SERIAL PRIMARY KEY,
    kunde_id         INT       NOT NULL REFERENCES kunde(kunde_id),
    sykkel_id        INT       NOT NULL REFERENCES sykkel(sykkel_id),
    start_stasjon_id INT       NOT NULL REFERENCES stasjon(stasjon_id),
    slutt_stasjon_id INT       REFERENCES stasjon(stasjon_id),
    utlevert         TIMESTAMP NOT NULL,
    innlevert        TIMESTAMP,
    beloep           NUMERIC(8,2),
    CONSTRAINT chk_beloep CHECK (beloep IS NULL OR beloep >= 0),
    CONSTRAINT chk_tider  CHECK (innlevert IS NULL OR innlevert > utlevert)
);

-- ============================================================================
-- TESTDATA
-- ============================================================================

-- 5 sykkelstasjoner
INSERT INTO stasjon (navn, adresse) VALUES
    ('Sentrum Stasjon',     'Karl Johans gate 1, Oslo'),
    ('Grünerløkka Stasjon', 'Thorvald Meyers gate 10, Oslo'),
    ('Majorstuen Stasjon',  'Bogstadveien 50, Oslo'),
    ('Aker Brygge Stasjon', 'Stranden 1, Oslo'),
    ('Blindern Stasjon',    'Problemveien 7, Oslo');

-- 100 låser: 20 per stasjon
INSERT INTO laas (stasjon_id)
SELECT stasjon_id
FROM stasjon, generate_series(1, 20);

-- 95 parkerte sykler — knyttet til unik lås og stasjon
WITH numbered_locks AS (
    SELECT laas_id, stasjon_id,
           ROW_NUMBER() OVER (ORDER BY laas_id) AS rn
    FROM laas
)
INSERT INTO sykkel (modell, innkjopsdato, stasjon_id, laas_id)
SELECT
    CASE (rn % 3)
        WHEN 0 THEN 'City Bike Pro'
        WHEN 1 THEN 'Urban Cruiser'
        WHEN 2 THEN 'EcoBike 3000'
    END,
    DATE '2023-01-15' + (rn * 3 % 300) * INTERVAL '1 day',
    stasjon_id,
    laas_id
FROM numbered_locks
WHERE rn <= 95;

-- 5 utleide sykler (stasjon og lås er NULL — de er ute på tur)
INSERT INTO sykkel (modell, innkjopsdato, stasjon_id, laas_id) VALUES
    ('City Bike Pro', '2023-04-10', NULL, NULL),
    ('Urban Cruiser',  '2023-05-20', NULL, NULL),
    ('EcoBike 3000',   '2023-03-01', NULL, NULL),
    ('City Bike Pro',  '2023-06-15', NULL, NULL),
    ('Urban Cruiser',  '2023-07-01', NULL, NULL);

-- 7 kunder (kunde 6 og 7 har aldri leid sykkel)
INSERT INTO kunde (fornavn, etternavn, mobilnr, epost) VALUES
    ('Ole',   'Hansen',   '+4791234567', 'ole.hansen@example.com'),
    ('Kari',  'Olsen',    '+4792345678', 'kari.olsen@example.com'),
    ('Per',   'Andersen',  '+4793456789', 'per.andersen@example.com'),
    ('Lise',  'Johansen', '+4794567890', 'lise.johansen@example.com'),
    ('Erik',  'Larsen',   '+4795678901', 'erik.larsen@example.com'),
    ('Anna',  'Nilsen',   '+4796789012', 'anna.nilsen@example.com'),
    ('Jonas', 'Berg',     '+4797890123', 'jonas.berg@example.com');

-- 50 fullførte utleier (sykkel 1–50, sykkel 51–95 har aldri vært utleid)
INSERT INTO utleie (kunde_id, sykkel_id, start_stasjon_id, slutt_stasjon_id,
                    utlevert, innlevert, beloep)
SELECT
    (i % 5) + 1,
    (i % 50) + 1,
    (i % 5) + 1,
    ((i + 2) % 5) + 1,
    TIMESTAMP '2023-06-01 08:00:00' + i * INTERVAL '3 hours',
    TIMESTAMP '2023-06-01 08:00:00' + i * INTERVAL '3 hours'
        + (20 + i % 40) * INTERVAL '1 minute',
    25.00 + (i % 10) * 5.00
FROM generate_series(0, 49) AS s(i);

-- 5 aktive utleier (sykkel 96–100, ikke innlevert ennå)
-- Sykkel 96 og 97: over 24 timer siden (for oppgave 5.8)
INSERT INTO utleie (kunde_id, sykkel_id, start_stasjon_id, slutt_stasjon_id,
                    utlevert, innlevert, beloep) VALUES
    (1, 96, 1, NULL, NOW() - INTERVAL '48 hours',     NULL, NULL),
    (2, 97, 2, NULL, NOW() - INTERVAL '30 hours',     NULL, NULL),
    (3, 98, 3, NULL, NOW() - INTERVAL '2 hours',      NULL, NULL),
    (4, 99, 4, NULL, NOW() - INTERVAL '1 hour',       NULL, NULL),
    (5, 100, 5, NULL, NOW() - INTERVAL '30 minutes',  NULL, NULL);

-- ============================================================================
-- TILGANGSKONTROLL (Del 3)
-- ============================================================================

-- 3.1: Rolle og bruker
CREATE ROLE kunde;
CREATE USER kunde_1 WITH PASSWORD 'kunde123';
GRANT kunde TO kunde_1;

GRANT SELECT ON stasjon, sykkel, laas, kunde, utleie TO kunde;

-- 3.2: VIEW — viser kun utleier for kunde_id = 1
CREATE VIEW kunde_1_utleier AS
SELECT u.utleie_id, u.sykkel_id,
       s1.navn AS start_stasjon,
       s2.navn AS slutt_stasjon,
       u.utlevert, u.innlevert, u.beloep
FROM utleie u
JOIN stasjon s1 ON u.start_stasjon_id = s1.stasjon_id
LEFT JOIN stasjon s2 ON u.slutt_stasjon_id = s2.stasjon_id
WHERE u.kunde_id = 1;

GRANT SELECT ON kunde_1_utleier TO kunde_1;

-- ============================================================================
SELECT 'Database initialisert!' AS status;
