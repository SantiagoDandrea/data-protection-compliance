-- =============================================================================
-- POSTGRESQL HARDENING & SEGREGACIÓN PARA DATOS CONFIDENCIALES Y RESTRINGIDOS
-- Aseguradora Argentina | Cumplimiento Ley 25.326 & Res. AAIP 47/2018 (Medidas Críticas)
-- =============================================================================

-- 1. Cerrar la brecha del esquema PUBLIC (Vulnerabilidad común en PostgreSQL)
-- Por defecto en PostgreSQL <= 14, cualquier usuario conectado puede crear y leer en public.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE aseguradora_db FROM PUBLIC;

-- 2. Habilitar Row-Level Security (RLS) en tablas sensibles
-- RLS asegura que incluso si un usuario tiene permiso SELECT en la tabla 'polizas',
-- solo pueda ver las filas que coincidan con su contexto de sesión (Tenant o Productor).
ALTER TABLE seguros_core.polizas ENABLE ROW LEVEL SECURITY;
ALTER TABLE seguros_core.polizas FORCE ROW LEVEL SECURITY;

-- Política: Un Productor Asesor de Seguros (PAS) solo ve pólizas de su cartera asignada
CREATE POLICY pas_aislamiento_polizas ON seguros_core.polizas
    FOR SELECT
    TO pas_usuario_portal
    USING (productor_asignado_id = current_setting('app.current_productor_id', true));

-- 3. Protección Criptográfica de Campos en Reposo (Columna específica)
-- Para datos médicos que deban persistir protegidos incluso contra volcados de disco crudos,
-- se utiliza la extensión pgcrypto:
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Función de inserción con cifrado simétrico por registro usando clave del KMS
-- UPDATE salud_restringida.historial_medico 
-- SET diagnostico_cifrado = pgp_sym_encrypt(diagnostico, current_setting('app.kms_secret_key'));

-- 4. Auditoría de Consultas Sospechosas (pg_audit)
-- Habilita el registro detallado de lectura sobre esquemas clasificados como RESTRINGIDO
-- En postgresql.conf:
-- shared_preload_libraries = 'pgaudit'
-- pgaudit.log = 'read, write'
-- pgaudit.log_catalog = off
-- pgaudit.log_relation = on
-- pgaudit.log_parameter = on

-- 5. Principio de Separación de Funciones (Segregation of Duties - SoD)
-- El rol 'db_analista_bi' (Business Intelligence) solo debe consultar vistas con datos disociados:
CREATE OR REPLACE VIEW seguros_core.vista_estadistica_siniestros AS
SELECT 
    cobertura,
    DATE_TRUNC('month', vigencia) AS mes_vigencia,
    COUNT(*) AS total_polizas,
    AVG(prima) AS prima_promedio
FROM seguros_core.polizas
GROUP BY cobertura, DATE_TRUNC('month', vigencia);

-- Concedemos acceso únicamente a la vista disociada (modelo de lista blanca / least privilege).
-- En PostgreSQL no hace falta hacer REVOKE sobre tablas o esquemas a los que nunca se les otorgó GRANT,
-- siempre que el rol PUBLIC tenga revocado el USAGE sobre esquemas restringidos.
GRANT USAGE ON SCHEMA seguros_core TO db_analista_bi;
GRANT SELECT ON seguros_core.vista_estadistica_siniestros TO db_analista_bi;
