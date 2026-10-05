# Laboratorio Técnico: Bypass de Clasificación & Mínimo Privilegio (PostgreSQL 16)

Este laboratorio convierte el análisis de riesgo teórico de [docs/data-classification.md](../docs/data-classification.md) en una **demostración técnica ejecutable sobre un motor de base de datos empresarial real**.

Permite reproducir y verificar cómo una vulnerabilidad de software (**SQL Injection — MITRE ATT&CK T1190**) provoca un salto no autorizado entre niveles de clasificación (**Confidencial → Restringido**), y cómo el principio de **mínimo privilegio (Least Privilege / RBAC)** a nivel de base de datos mitiga el impacto aun cuando el código de la aplicación sea vulnerable.

---

## Arquitectura del Laboratorio

Todo el entorno corre sobre **PostgreSQL 16** con esquemas físicos y roles independientes configurados en [`db/init.sql`](db/init.sql):

```text
lab/
├── docker-compose.yml            # Orquestación de PostgreSQL 16 y Servicio Web Flask
├── test_exploit.py               # Script CLI que ejecuta el ataque y verifica la respuesta de Postgres
├── app/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py                    # API y servidor web Flask (conexión nativa psycopg2)
│   └── templates/
│       └── index.html            # Dashboard web interactivo de telemetría y pruebas
├── db/
│   └── init.sql                  # DDL de PostgreSQL: esquemas segregados, datos y roles
├── controls/
│   ├── dlp_rules.json            # Reglas de DLP con regex para DNI, CUIT y términos CIE-10
│   ├── terraform_s3_worm_backup.tf # IaC para backups inmutables S3 Object Lock (Anti-ransomware)
│   └── postgres_hardening.sql    # Hardening de PostgreSQL (RLS, auditoría, schemas)
└── detection/
    ├── sqli_waf.log              # Trazas reales de ataque en logs de WAF y BD
    └── sigma_sqli_detection.yml  # Regla Sigma para detección e integración con SIEM
```

---

## Roles y Esquemas en PostgreSQL

| Componente | Nivel de Clasificación | Permisos `app_user_overprivileged` | Permisos `app_user_least_privilege` |
|---|---|---|---|
| **Esquema `seguros_core`** (Tabla `polizas`) | **Confidencial** | `USAGE`, `SELECT` (Total) | `USAGE`, `SELECT` (Total) |
| **Esquema `salud_restringida`** (Tabla `historial_medico`) | **Restringido (Ley 25.326)** | `USAGE`, `SELECT` (Total - Antipatrón) | **`REVOKE ALL` (Bloqueo estricto)** |

---

## Puesta en Marcha (Paso a Paso)

### 1. Iniciar el entorno (Docker Compose)
Desde la raíz del repositorio:

```bash
docker compose -f lab/docker-compose.yml up -d
```
*Esto iniciará el contenedor de base de datos con los datos de prueba y la aplicación web.*

---

### 2. Ejecutar la Prueba Técnica en Terminal (`test_exploit.py`)

Puedes ejecutar el script directamente dentro del contenedor sin necesidad de instalar librerías en tu máquina:

```bash
docker compose -f lab/docker-compose.yml exec web python test_exploit.py
```

*(O si tienes `psycopg2-binary` instalado localmente, puedes correrlo con: `python lab/test_exploit.py`)*

#### Qué verifica el script paso a paso:
1. **Paso 1 (Consulta Legítima):** Consulta la póliza `POL-2024-001` y obtiene datos contractuales (Nivel **Confidencial**).
2. **Paso 2 (Ataque SQLi sin RBAC):** Inyecta `' UNION SELECT ...` sobre `salud_restringida.historial_medico` bajo la cuenta `app_user_overprivileged`. PostgreSQL devuelve diagnósticos de estrés postraumático, cáncer y hernia discal (**Salto a Restringido - Data Breach**).
3. **Paso 3 (Mitigación por Mínimo Privilegio):** Envía exactamente el mismo ataque bajo la cuenta `app_user_least_privilege`. **El motor nativo de PostgreSQL aborta la consulta** y devuelve la excepción:
   ```text
   SQLSTATE: 42501 (INSUFFICIENT_PRIVILEGE)
   ERROR: permission denied for schema/table salud_restringida.historial_medico
   ```
4. **Paso 4 (Defensa en Software):** Demuestra el uso de consultas preparadas (*Prepared Statements*) con `%s`.

---

### 3. Exploración Visual en el Dashboard Web

Abre en tu navegador:
```text
http://localhost:5000
```

- Permite ingresar parámetros o usar los botones de **Quick Payloads**.
- Alterna en caliente entre la cuenta **Overprivileged** y la cuenta **Least Privilege**.
- Visualiza la respuesta cruda de PostgreSQL, la telemetría del motor y el encuadre regulatorio bajo la Ley 25.326.

---

## Controles Complementarios Incluidos

1. **Prevención de Fuga de Datos ([`controls/dlp_rules.json`](controls/dlp_rules.json)):**
   - Configuración en JSON para agentes de DLP / Mail Gateways con expresiones regulares para identificar números de DNI argentino, CUIL/CUIT y diagnósticos médicos bajo el estándar CIE-10.

2. **Inmutabilidad contra Ransomware ([`controls/terraform_s3_worm_backup.tf`](controls/terraform_s3_worm_backup.tf)):**
   - Código Terraform para desplegar buckets S3 con **Object Lock en modo COMPLIANCE** y claves KMS independientes, neutralizando las tácticas de cifrado/borrado de backups empleadas en incidentes reales (LockBit / *La Segunda Seguros*).

3. **Seguridad en PostgreSQL ([`controls/postgres_hardening.sql`](controls/postgres_hardening.sql)):**
   - Configuración de Row-Level Security (RLS) para Productores Asesores de Seguros (PAS), revocación del esquema público y vistas disociadas para analistas de Business Intelligence.

4. **Detección en SOC / SIEM ([`detection/`](detection/)):**
   - `sqli_waf.log`: Trazas correlacionadas entre WAF (ModSecurity) y `pgaudit`.
   - `sigma_sqli_detection.yml`: Regla genérica en formato Sigma para alertar tempranamente sobre la técnica **MITRE ATT&CK T1190**.
