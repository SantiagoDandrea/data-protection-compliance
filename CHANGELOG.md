# Bitácora de Cambios (Changelog)

Todas las modificaciones, revisiones normativas y adiciones técnicas relevantes de este proyecto se registran en este documento.

---

## [1.2.0] — 2024-03-02
### Añadido (Paso de Documentación Teórica a Laboratorio Ejecutable)
- **Laboratorio Técnico Reproducible (`lab/`):**
  - Implementación de suite de pruebas técnica en `lab/test_exploit.py`: Script CLI que se conecta a PostgreSQL 16 y reproduce el vector de SQL Injection (MITRE T1190) y el bypass de clasificación de datos desde el nivel Confidencial hacia Restringido (salud), demostrando la mitigación nativa del motor de base de datos (`SQLSTATE 42501`) mediante roles de PostgreSQL.
  - Implementación de entorno dockerizado (`lab/docker-compose.yml`, `lab/app/`, `lab/db/init.sql`): PostgreSQL 16 con esquemas reales segregados (`seguros_core` vs `salud_restringida`), roles `app_user_overprivileged` y `app_user_least_privilege`, y aplicación interactiva en Flask.
  - Implementación de controles técnicos aplicados en `lab/controls/`:
    - `dlp_rules.json`: Reglas de DLP con expresiones regulares para DNI argentino, CUIL/CUIT y diagnósticos médicos (CIE-10).
    - `terraform_s3_worm_backup.tf`: Infraestructura como Código (IaC) para repositorios de respaldo inmutables con AWS S3 Object Lock en modo COMPLIANCE, claves KMS independientes y protección anti-ransomware (T1486/T1490).
    - `postgres_hardening.sql`: Script de endurecimiento de PostgreSQL con Row-Level Security (RLS) para Productores Asesores de Seguros (PAS), auditoría con `pg_audit` y revocación de permisos públicos.
  - Implementación de ingeniería de detección en `lab/detection/`:
    - `sqli_waf.log`: Muestras realistas de logs de acceso web y base de datos capturando el reconocimiento y la explotación.
    - `sigma_sqli_detection.yml`: Regla formal Sigma para alertamiento temprano en SIEM (Splunk/Elastic/Wazuh).

### Corregido & Robustecido (Auditoría Normativa)
- **Corrección en Código Penal Argentino (`docs/ley-25326.md`):** Se identificó y rectificó la cita obsoleta del Art. 117 bis (derogado expresamente por la Ley 26.388 en junio de 2008), clarificando la vigencia de los Arts. 153 bis (acceso ilegítimo) y 157 bis (violación y difusión ilegítima de bancos de datos personales).
- **Desglose de la Res. AAIP 47/2018:** Se explicitó la derogación de la histórica Disposición 11/2006 y se mapearon las medidas recomendadas del Anexo I (medios informatizados) con la matriz de 4 niveles de clasificación.
- **Verificación de Plazos:** Cita y verificación contra InfoLEG de los plazos de ejercicio de derechos del titular: Art. 14 (10 días corridos para acceso) y Art. 16 (5 días hábiles para rectificación/supresión).

### Mejorado (Estilo y Humanización)
- Eliminación de glosarios redundantes de conceptos básicos de seguridad (MFA, SIEM, WAF) en favor de contextualización operativa directa.
- Reemplazo de conclusiones estandarizadas por notas de diseño, trade-offs técnicos y dilemas reales (conflicto entre prescripción en seguros y derecho de supresión).
- Supresión del flowchart simplista `Datos -> Clasificación -> Riesgo` en el README, reemplazándolo por un diagrama de arquitectura integral con fronteras de seguridad y controles por salto.
- Incorporación de resumen ejecutivo bilingüe (inglés/español), sección de límites del proyecto y licencia MIT.

---

## [1.1.0] — 2024-02-15
### Añadido
- Análisis del vector de ataque de SQL Injection y su relación con la técnica MITRE ATT&CK T1190.
- Caso de estudio contextualizado en el sector asegurador argentino: incidente de ransomware en *La Segunda Seguros* (LockBit, febrero 2023).
- Comparativa formal con el Reglamento General de Protección de Datos (GDPR - Reglamento UE 2016/679).

---

## [1.0.0] — 2024-01-20
### Lanzamiento Inicial
- Matriz preliminar de clasificación en 4 niveles (Público, Interno, Confidencial, Restringido) adaptada a una entidad aseguradora.
- Documento de controles de seguridad teóricos (cifrado, RBAC, backups, logs).
- Mapeo inicial de flujo de datos y síntesis de la Ley 25.326.
