INVALIDATE METADATA  d_lnd_tables.iis_geo;
INVALIDATE METADATA  d_dl_views.iis_geo;
INVALIDATE METADATA d_dl_tables.iis_geo_servicios;
INVALIDATE METADATA d_dl_tables.iis_geo_segmentos;
INVALIDATE METADATA d_dl_tables.iis_geo_clientes;
INVALIDATE METADATA d_dl_tables.iis_geo_accesos;

-- DROP TABLE d_dl_views.iis_geo_segmentos
CREATE TABLE IF NOT EXISTS d_dl_tables.iis_geo_segmentos
    STORED AS PARQUET
    LOCATION 'hdfs://GALICIAHADOOP/galicia/d/landing_files/iis_geo/segmentos'
AS SELECT * FROM d_dl_views.iis_geo_segmentos;

-- DROP TABLE d_dl_views.iis_geo_servicios
CREATE TABLE IF NOT EXISTS d_dl_tables.iis_geo_servicios
    STORED AS PARQUET
    LOCATION 'hdfs://GALICIAHADOOP/galicia/d/landing_files/iis_geo/servicios'
AS SELECT * FROM d_dl_views.iis_geo_servicios;

-- DROP TABLE d_dl_views.iis_geo_clientes
CREATE TABLE IF NOT EXISTS d_dl_tables.iis_geo_clientes
    STORED AS PARQUET
    LOCATION 'hdfs://GALICIAHADOOP/galicia/d/landing_files/iis_geo/clientes'
AS SELECT * FROM d_dl_views.iis_geo_clientes;


-- DROP VIEW d_dl_views.iis_geo_accesos
CREATE VIEW IF NOT EXISTS d_dl_views.iis_geo_accesos AS
SELECT raw.ts
, raw.hora
, raw.`day`
, raw.`dayofweek`
, raw.accuracy
, raw.latitud
, raw.longitud
, raw.country
, cli.client_id
, seg.segmento
, ser.servicio_id
, ser.canal
, ser.proto
, ser.host
, raw.dt from d_dl_views.iis_geo raw
    INNER JOIN d_dl_tables.iis_geo_clientes cli
        ON cast(raw.document_number as bigint) = cast(cli.number as bigint) AND raw.document_type = cli.document_type
    INNER JOIN d_dl_tables.iis_geo_servicios ser
        ON instr(raw.servicio, ser.canal) > 0 OR instr(raw.servicio, concat(ser.host, '/')) > 0
    INNER JOIN d_dl_tables.iis_geo_segmentos seg
        ON instr(raw.segmento, seg.segmento) > 0;


-- DROP table d_dl_tables.iis_geo_accesos;
CREATE TABLE IF NOT EXISTS d_dl_tables.iis_geo_accesos
    STORED AS PARQUET
    LOCATION 'hdfs://GALICIAHADOOP/galicia/d/landing_files/iis_geo/accesos'
AS SELECT DISTINCT * FROM d_dl_views.iis_geo_accesos;

-- DROP VIEW d_dl_views.iis_geo_accesos_pais
CREATE VIEW IF NOT EXISTS d_dl_views.iis_geo_accesos_pais AS
SELECT count(*) as hits, country FROM d_dl_tables.iis_geo_accesos GROUP BY country ORDER by hits DESC;

-- DROP VIEW d_dl_views.iis_geo_accesos_segmentos
CREATE VIEW IF NOT EXISTS d_dl_views.iis_geo_accesos_segmentos AS
SELECT count(*) as hits, segmento FROM d_dl_tables.iis_geo_accesos GROUP BY segmento ORDER by hits DESC;

-- DROP VIEW d_dl_views.iis_geo_accesos_canal
CREATE VIEW IF NOT EXISTS d_dl_views.iis_geo_accesos_canal AS
SELECT count(hits) as hits, canal, host FROM
    (
        SELECT count(*) as hits, acc.client_id, ser.canal, concat(ser.proto, '://', ser.host) as host
        FROM d_dl_tables.iis_geo_accesos acc
                 INNER JOIN d_dl_tables.iis_geo_servicios ser on acc.servicio_id = ser.servicio_id
        GROUP BY acc.client_id, ser.canal, host
    ) ht GROUP BY host, canal ORDER BY hits DESC, canal, host;

-- DROP VIEW d_dl_views.iis_geo_accesos_hora
CREATE VIEW IF NOT EXISTS d_dl_views.iis_geo_accesos_hora AS
SELECT count(hits) as hits, hora, canal, host FROM
    (
        SELECT count(*) as hits, acc.hora, acc.client_id, ser.canal, concat(ser.proto, '://', ser.host) as host
        FROM d_dl_tables.iis_geo_accesos acc
                 INNER JOIN d_dl_tables.iis_geo_servicios ser on acc.servicio_id = ser.servicio_id
        GROUP BY acc.hora, acc.client_id, ser.canal, host
    ) ht GROUP BY hora, canal, host ORDER BY hora DESC, hits DESC;

-- DROP VIEW d_dl_views.iis_geo_accesos_dayofweek
CREATE VIEW IF NOT EXISTS d_dl_views.iis_geo_accesos_dayofweek AS
SELECT count(hits) as hits, `dayofweek`, canal, host FROM
    (
        SELECT count(*) as hits, acc.`dayofweek`, acc.client_id, ser.canal, concat(ser.proto, '://', ser.host) as host
        FROM d_dl_tables.iis_geo_accesos acc
                 INNER JOIN d_dl_tables.iis_geo_servicios ser on acc.servicio_id = ser.servicio_id
        GROUP BY acc.`dayofweek`, acc.client_id, ser.canal, host
    ) ht GROUP BY `dayofweek`, canal, host ORDER BY `dayofweek`, hits DESC;

-- DROP VIEW d_dl_views.iis_geo_accesos_extranjero
CREATE VIEW IF NOT EXISTS d_dl_views.iis_geo_accesos_extranjero AS
SELECT * FROM d_dl_tables.iis_geo_accesos where country != 'Argentina';

-- DROP VIEW d_dl_views.iis_geo_accesos_sospechosos
CREATE VIEW IF NOT EXISTS d_dl_views.iis_geo_accesos_sospechosos AS
SELECT DISTINCT
    acc.client_id as client_id
    , acc.ts as local_ts
    , ext.ts as foreign_ts
    , acc.country as origen_local
    , ext.country as origen_extranjero
    , acc.latitud as latitud_local
    , acc.longitud as longitud_local
    , acc.accuracy as accuracy_local
    , ext.latitud as latitud_extranjero
    , ext.longitud as longitud_extranjero
    , ext.accuracy as accuracy_extranjero
FROM d_dl_tables.iis_geo_accesos acc
INNER JOIN d_dl_views.iis_geo_accesos_extranjero ext
    ON acc.country = 'Argentina'
    AND acc.client_id = ext.client_id
    AND acc.`day` = ext.`day`
    AND acc.`month` = ext.`month`
    AND from_timestamp(acc.ts, 'yyyy') = from_timestamp(ext.ts, 'yyyy')
ORDER BY acc.ts DESC;

