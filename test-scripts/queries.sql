-- ============================================================================
-- DATA1500 - Oblig 1: SQL-spørringer (Del 5)
-- ============================================================================

-- 5.1: Alle sykler
SELECT * FROM sykkel;

-- 5.2: Kunder sortert alfabetisk på etternavn
SELECT etternavn, fornavn, mobilnr
FROM kunde
ORDER BY etternavn ASC;

-- 5.3: Sykler tatt i bruk etter 1. april 2023
SELECT * FROM sykkel
WHERE innkjopsdato > '2023-04-01';

-- 5.4: Antall kunder
SELECT COUNT(*) AS antall_kunder FROM kunde;

-- 5.5: Alle kunder med antall utleier (også de uten utleie)
SELECT k.kunde_id, k.fornavn, k.etternavn,
       COUNT(u.utleie_id) AS antall_utleier
FROM kunde k
LEFT JOIN utleie u ON k.kunde_id = u.kunde_id
GROUP BY k.kunde_id, k.fornavn, k.etternavn
ORDER BY k.etternavn;

-- 5.6: Kunder som aldri har leid sykkel
SELECT k.*
FROM kunde k
LEFT JOIN utleie u ON k.kunde_id = u.kunde_id
WHERE u.utleie_id IS NULL;

-- 5.7: Sykler som aldri har vært utleid
SELECT s.*
FROM sykkel s
LEFT JOIN utleie u ON s.sykkel_id = u.sykkel_id
WHERE u.utleie_id IS NULL;

-- 5.8: Sykler ikke levert tilbake etter ett døgn, med kundeinformasjon
SELECT s.sykkel_id, s.modell,
       k.fornavn, k.etternavn, k.mobilnr,
       u.utlevert,
       NOW() - u.utlevert AS tid_siden_utleie
FROM utleie u
JOIN sykkel s ON u.sykkel_id = s.sykkel_id
JOIN kunde k ON u.kunde_id = k.kunde_id
WHERE u.innlevert IS NULL
  AND u.utlevert < NOW() - INTERVAL '24 hours';
