-- =============================================================================
-- LAB DE CLASIFICACIÓN DE DATOS & PRIVILEGIOS MÍNIMOS EN POSTGRESQL
-- Entorno: Aseguradora Argentina (Simulación GRC / Arquitectura Segura)
-- 
-- NOTA DIDÁCTICA SOBRE CREDENCIALES:
-- Las contraseñas incluidas aquí son únicamente para levantar este laboratorio
-- local en un solo paso. En un entorno productivo jamás deben commitearse en un
-- archivo SQL; se gestionan con un gestor de secretos (Vault / AWS Secrets Manager)
-- o variables de entorno.
-- =============================================================================

-- 1. Creación de Esquemas Segregados
CREATE SCHEMA IF NOT EXISTS seguros_core;
CREATE SCHEMA IF NOT EXISTS salud_restringida;

-- 2. Tabla de Pólizas (Clasificación: CONFIDENCIAL)
-- Contiene datos de asegurados, vigencias y coberturas contractuales.
CREATE TABLE seguros_core.polizas (
    numero_poliza VARCHAR(50) PRIMARY KEY,
    dni VARCHAR(20) NOT NULL,
    titular VARCHAR(150) NOT NULL,
    cobertura VARCHAR(100) NOT NULL,
    prima NUMERIC(12,2) NOT NULL,
    vigencia DATE NOT NULL
);

-- 3. Tabla de Historial Médico (Clasificación: RESTRINGIDO - Ley 25.326 Art. 2 y 7)
-- Contiene diagnósticos y peritajes de siniestros de ART y Vida.
CREATE TABLE salud_restringida.historial_medico (
    id SERIAL PRIMARY KEY,
    dni VARCHAR(20) NOT NULL,
    paciente VARCHAR(150) NOT NULL,
    diagnostico TEXT NOT NULL,
    tratamiento TEXT NOT NULL,
    observaciones_medicas TEXT NOT NULL
);

-- 4. Inserción de Datos de Prueba
INSERT INTO seguros_core.polizas (numero_poliza, dni, titular, cobertura, prima, vigencia) VALUES
('POL-2024-001', '32456789', 'Carlos Benítez', 'Automotor Todo Riesgo', 45000.00, '2026-12-31'),
('POL-2024-002', '28912345', 'Mariana Gómez', 'Hogar Premium', 22000.00, '2026-11-30'),
('POL-2024-003', '35112233', 'Lucas Pereyra', 'Vida Colectivo / ART', 18500.00, '2027-06-30'),
('POL-2024-004', '20334455', 'Roberto Juárez', 'Responsabilidad Civil Integral', 38000.00, '2027-03-31');

INSERT INTO salud_restringida.historial_medico (dni, paciente, diagnostico, tratamiento, observaciones_medicas) VALUES
('35112233', 'Lucas Pereyra', 'Trastorno de Ansiedad Postraumático Severo', 'Clonazepam 2mg + Terapia psicológica semanal', 'Derivación por accidente de trabajo en planta fabril'),
('32456789', 'Carlos Benítez', 'Hernia Discal Lumbar L4-L5 Crónica', 'Kinesiología + Bloqueo facetario ambulatorio', 'Reclamo de indemnización parcial del 15%'),
('20334455', 'Roberto Juárez', 'Hipoacusia Neurosensorial Bilateral Ocupacional', 'Audífono digital + Reducción de jornada acústica', 'Peritaje médico legal concluido para dictamen'),
('27889900', 'Elena Rossi', 'Neoplasia de Mama Estadio II', 'Quimioterapia coadyuvante + Control oncológico', 'Solicitud de cobertura especial de medicamentos');

-- 5. Creación de Usuarios de Base de Datos
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_user_overprivileged') THEN
        CREATE ROLE app_user_overprivileged WITH LOGIN PASSWORD 'password_vulnerable_123';
    END IF;
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_user_least_privilege') THEN
        CREATE ROLE app_user_least_privilege WITH LOGIN PASSWORD 'password_secure_456';
    END IF;
END $$;

-- 6. GESTIÓN DE PRIVILEGIOS Y AISLAMIENTO DE ESQUEMAS
-- Detalle clave en PostgreSQL: Por defecto, los nuevos esquemas otorgan el permiso
-- USAGE al pseudo-rol PUBLIC. Si un usuario no tiene permisos directos pero hereda
-- USAGE vía PUBLIC, el esquema sigue siendo accesible.
-- Por eso, para cerrar la frontera a nivel de esquema, revocamos primero sobre PUBLIC:
REVOKE ALL ON SCHEMA salud_restringida FROM PUBLIC;
REVOKE ALL ON SCHEMA seguros_core FROM PUBLIC;

-- Rol A (Sobreprivilegiado - Antipatrón): Acceso total a ambos esquemas
GRANT USAGE ON SCHEMA seguros_core TO app_user_overprivileged;
GRANT USAGE ON SCHEMA salud_restringida TO app_user_overprivileged;
GRANT SELECT ON ALL TABLES IN SCHEMA seguros_core TO app_user_overprivileged;
GRANT SELECT ON ALL TABLES IN SCHEMA salud_restringida TO app_user_overprivileged;

-- Rol B (Least Privilege - RBAC): Solo lectura en pólizas
GRANT USAGE ON SCHEMA seguros_core TO app_user_least_privilege;
GRANT SELECT ON seguros_core.polizas TO app_user_least_privilege;

-- Bloqueo estricto del esquema de salud (ni USAGE ni SELECT)
REVOKE ALL ON SCHEMA salud_restringida FROM app_user_least_privilege;
