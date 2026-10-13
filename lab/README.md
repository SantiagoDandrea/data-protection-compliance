# Laboratorio Técnico: Bypass de Clasificación & Mínimo Privilegio (PostgreSQL 16)

Este laboratorio convierte el análisis de riesgo teórico de [docs/data-classification.md](../docs/data-classification.md) en una **demostración técnica ejecutable sobre PostgreSQL 16**.

La idea es ver en vivo cómo una falla común de desarrollo (**SQL Injection — MITRE ATT&CK T1190**) permite que un atacante salte de consultar pólizas comunes a extraer diagnósticos médicos confidenciales (**Confidencial → Restringido**), y cómo el principio de **mínimo privilegio (RBAC y esquemas separados)** frena el ataque en la base de datos aun cuando la web esté rota.

---

## Qué hay en esta carpeta

Todo el entorno corre sobre **PostgreSQL 16** con esquemas físicos y roles independientes configurados en [`db/init.sql`](db/init.sql):

```text
lab/
├── docker-compose.yml            # Levanta PostgreSQL 16 y la app Flask
├── .env.example                  # Variables de entorno y notas de seguridad
├── test_exploit.py               # Script CLI que ejecuta el ataque y verifica la respuesta de Postgres
├── app/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py                    # Servidor web Flask (conexión nativa psycopg2)
│   └── templates/
│       └── index.html            # Dashboard web para probar payloads desde el navegador
├── db/
│   └── init.sql                  # DDL de PostgreSQL: esquemas segregados, datos y roles
├── controls/
│   ├── dlp_rules.json            # Reglas de DLP con regex para DNI, CUIT y CIE-10
│   ├── terraform_s3_worm_backup.tf # IaC para backups inmutables S3 Object Lock (Anti-ransomware)
│   └── postgres_hardening.sql    # Hardening de PostgreSQL (RLS, auditoría, esquemas)
└── detection/
    ├── sqli_waf.log              # Logs sintéticos de muestra (WAF y BD)
    └── sigma_sqli_detection.yml  # Regla Sigma para detección e integración con SIEM
```

---

## Roles y Esquemas en PostgreSQL

| Esquema / Tabla | Nivel de Clasificación | Permisos `app_user_overprivileged` | Permisos `app_user_least_privilege` |
|---|---|---|---|
| **`seguros_core.polizas`** | **Confidencial** | `USAGE` en esquema + `SELECT` en tabla | `USAGE` en esquema + `SELECT` en tabla |
| **`salud_restringida.historial_medico`** | **Restringido (Ley 25.326)** | `USAGE` en esquema + `SELECT` en tabla *(antipatrón)* | **Sin permisos** (revocado de `PUBLIC` y sin `GRANT`) |

> **Nota técnica de DBA (el rol PUBLIC en Postgres):**  
> En PostgreSQL los esquemas nuevos conceden el permiso `USAGE` al pseudo-rol `PUBLIC` por omisión. Si solo le quitás permisos a un rol específico, ese rol sigue heredando `USAGE` a través de `PUBLIC`. Por eso, el verdadero aislamiento a nivel de motor requiere ejecutar `REVOKE ALL ON SCHEMA salud_restringida FROM PUBLIC;`. Además, el bloqueo de lectura de las tablas se da por la ausencia del `GRANT SELECT` (modelo de lista blanca).

---

## Puesta en Marcha (Paso a Paso)

### 1. Iniciar los contenedores:
Desde la raíz del repositorio o desde la carpeta `lab/`:

```bash
docker compose -f lab/docker-compose.yml up -d
```

### 2. Ejecutar la prueba por terminal (`test_exploit.py`):
Podés correr el script directamente adentro del contenedor de la web sin necesidad de instalar librerías locales:

```bash
docker compose -f lab/docker-compose.yml exec web python test_exploit.py
```

*(O si tenés `psycopg2-binary` en tu máquina local: `python lab/test_exploit.py`)*

#### Qué hace el script paso a paso:
1. **Paso 1 (Consulta Legítima):** Consulta la póliza `POL-2026-001` y obtiene los datos del seguro de auto (Nivel **Confidencial**).
2. **Paso 2 (Ataque SQLi sin RBAC):** Inyecta `' UNION SELECT ...` apuntando a `salud_restringida.historial_medico` usando la cuenta `app_user_overprivileged`. PostgreSQL devuelve diagnósticos de estrés postraumático, cáncer y hernia discal (**Salto a Restringido - Data Breach**).
3. **Paso 3 (Mitigación por Mínimo Privilegio):** Envía exactamente el mismo ataque pero usando la cuenta `app_user_least_privilege`. **El motor nativo de PostgreSQL aborta la consulta** y devuelve la excepción:
   ```text
   SQLSTATE: 42501 (INSUFFICIENT_PRIVILEGE)
   ERROR: permission denied for schema salud_restringida
   ```
4. **Paso 4 (Defensa en Software):** Muestra cómo una consulta parametrizada (*Prepared Statement*) con `%s` neutraliza el ataque en la capa de aplicación.

---

### 3. Probarlo desde el Dashboard Web

Abrí en tu navegador:
```text
http://localhost:5000
```

- Podés tipear parámetros o hacer clic en los botones de **Quick Payloads**.
- Podés alternar en tiempo real entre la cuenta **Overprivileged** y la cuenta **Least Privilege**.
- Ves la respuesta cruda de PostgreSQL, el código SQLSTATE y la explicación legal bajo la Ley 25.326.

---

## Controles Complementarios Incluidos

1. **Prevención de Fuga de Datos ([`controls/dlp_rules.json`](controls/dlp_rules.json)):**
   - Reglas en JSON para agentes de DLP o Mail Gateways con regex para detectar DNI, CUIT y diagnósticos bajo el estándar CIE-10 en correos salientes.

2. **Inmutabilidad contra Ransomware ([`controls/terraform_s3_worm_backup.tf`](controls/terraform_s3_worm_backup.tf)):**
   - Plantilla de Terraform de referencia para armar un bucket S3 con **Object Lock en modo COMPLIANCE** (WORM) y KMS CMK, impidiendo que un ransomware pueda borrar o cifrar las copias de seguridad. *(Nota: Es un patrón arquitectónico educativo; incluye advertencias operacionales para prevenir bloqueos accidentales en cuentas AWS reales).*

3. **Seguridad Avanzada en PostgreSQL ([`controls/postgres_hardening.sql`](controls/postgres_hardening.sql)):**
   - Script SQL autocontenido que complementa el lab aplicando Row-Level Security (RLS) para Productores de Seguros (PAS), extensión `pgcrypto` y vistas disociadas para Business Intelligence (SoD). Se puede ejecutar sobre el contenedor de BD con:
     ```bash
     docker compose -f lab/docker-compose.yml exec -T db psql -U postgres -d aseguradora_db -f /dev/stdin < lab/controls/postgres_hardening.sql
     ```

4. **Detección para SOC ([`detection/`](detection/)):**
   - `sqli_waf.log`: Muestra sintética de logs de acceso HTTP y auditoría de base de datos para ilustrar el escenario de ataque.
   - `sigma_sqli_detection.yml`: Regla Sigma para alertar en SIEM cuando alguien intenta enumerar o inyectar payloads SQLi (**MITRE ATT&CK T1190**).

---

## Advertencia sobre Credenciales
Las contraseñas que están en `init.sql` y `app.py` son fijas para que el lab levante sin fricción en una máquina local. **Jamás se deben usar contraseñas hardcodeadas en producción**. Para entornos reales, revisar [`lab/.env.example`](.env.example) y utilizar gestores de secretos dedicados.
