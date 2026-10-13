# Controles de Seguridad Técnicos y Organizacionales

## Enfoque de Implementación: De la Política al Código
Una falla recurrente en los programas de GRC es quedarse en directivas teóricas como *"se debe cifrar la información sensible"* sin definir el protocolo, el algoritmo ni el mecanismo de gestión de claves.

Este documento vincula los 4 niveles de clasificación de [data-classification.md](data-classification.md) con controles técnicos concretos y patrones de configuración recomendados para una arquitectura corporativa (ver [Roadmap en README](../README.md#controles-y-secciones-a-sumar-roadmap-a-futuro)).

---

## Matriz Operativa de Controles por Nivel

| Nivel | Amenazas Principales | Controles Técnicos Obligatorios | Controles Organizacionales |
|---|---|---|---|
| **Público** | Desfiguración web (*defacement*), indisponibilidad por DDoS. | TLS 1.3, Rate Limiting perimetral, hosting estático o CDN con WAF, verificación de integridad en CI/CD. | Procedimiento formal de aprobación de contenidos antes de publicación externa. |
| **Interno** | Fuga accidental entre empleados, abuso de credenciales estándar. | Autenticación centralizada (SSO/IdP), RBAC por departamento, antivirus/EDR en endpoints, logging básico de accesos. | Acuerdos de confidencialidad (NDA), política de puesto de trabajo limpio, inducción de seguridad. |
| **Confidencial** | Exfiltración de cartera de clientes, robo de identidad con DNI/CUIT. | Cifrado en tránsito obligatorio (HTTPS/TLS 1.3), cifrado en reposo a nivel de volumen (AES-256), DLP en correo saliente, MFA para accesos remotos y consultas parametrizadas. | Principio de necesidad de conocer (*need to know*), auditoría semestral de accesos y cláusulas de datos con proveedores (Art. 12 Ley 25.326). |
| **Restringido** | Filtración de historias clínicas de ART/Vida, exfiltración masiva por ransomware (doble extorsión), compromiso de llaves criptográficas. | Cifrado de columna/campo (`pgcrypto`), segregación estricta de esquemas en base de datos, MFA FIDO2/WebAuthn obligatorio, backups inmutables (**S3 Object Lock WORM**), auditoría con `pg_audit` y correlación en SIEM. | Autorización nominal documentada por oficial de seguridad médica/legales, revisión trimestral de privilegios y protocolo de destrucción criptográfica (*crypto-shredding*). |

---

## Implementaciones Técnicas Aplicadas

### 1. Inmutabilidad de Backups contra Ransomware (WORM)
Durante el ataque a *La Segunda Seguros* (2023), como en casi todo incidente de ransomware moderno, los operadores de **LockBit** intentaron destruir los respaldos en disco y Active Directory para forzar el pago del rescate.

Para neutralizar este vector, la arquitectura implementa almacenamiento **WORM (Write Once Read Many)** mediante **AWS S3 Object Lock en modo COMPLIANCE**. En este modo, ni siquiera la cuenta `root` o un atacante con permisos `AdministratorAccess` puede eliminar o sobreescribir los archivos de backup antes de que venza el período de retención:

```hcl
# Fragmento extraído de lab/controls/terraform_s3_worm_backup.tf
resource "aws_s3_bucket_object_lock_configuration" "backup_lock" {
  bucket = aws_s3_bucket.immutable_backup_vault.id

  rule {
    default_retention {
      mode = "COMPLIANCE" # Inmutable: bloquea sobreescritura y borrado
      days = 90           # Ventana garantizada de recuperación ante desastres
    }
  }
}
```
*(Patrón de arquitectura IaC especificado para la hoja de ruta de infraestructura en producción).*

---

### 2. Prevención de Fuga de Datos (DLP) para Identidad y Diagnósticos
El control de DLP perimetral inspecciona el tráfico saliente de correo electrónico y web proxies para interceptar datos no autorizados.

En Argentina, el DLP debe diferenciar un DNI común de un diagnóstico de salud:
- **DNI/CUIT (Confidencial):** Si un analista envía un correo a un cliente con su póliza, no se bloquea; pero si se detectan más de 3 números de documento saliendo a un correo externo, se genera cuarentena preventiva.
- **Términos Médicos / CIE-10 (Restringido):** La coincidencia de palabras clave como *"peritaje psiquiátrico"*, *"quimioterapia"* o códigos CIE-10 junto a datos personales activa el bloqueo automático y una alerta inmediata al SOC:

```json
// Fragmento de lab/controls/dlp_rules.json
{
  "id": "DLP-AR-003",
  "name": "Detección de Datos Médicos Sensibles (CIE-10 / Términos de Salud)",
  "classification_level": "Restringido",
  "detection": {
    "match_type": "hybrid",
    "keywords": ["historia clínica", "diagnóstico médico", "incapacidad laboral", "siniestro art"],
    "regex_cie10": "\\b[A-Z][0-9]{2}(\\.[0-9]{1,2})?\\b"
  },
  "action": "block_and_alert_immediate"
}
```
*(Patrón de inspección propuesto para la hoja de ruta de prevención de fuga).*

---

### 3. Segregación de Privilegios y Row Level Security en Base de Datos
Para impedir que una vulnerabilidad web exponga la base de datos completa (como se demostró en el laboratorio ejecutable de SQLi), se implementan dos capas en PostgreSQL:
1. **Separación de Esquemas:** Las tablas de pólizas residen en `seguros_core`, mientras que las historias clínicas residen en `salud_restringida`.
2. **Row Level Security (RLS):** Garantiza que un Productor Asesor de Seguros (PAS) solo pueda consultar las pólizas de su cartera:

```sql
-- Fragmento de lab/controls/postgres_hardening.sql
ALTER TABLE seguros_core.polizas ENABLE ROW LEVEL SECURITY;

CREATE POLICY pas_aislamiento_polizas ON seguros_core.polizas
    FOR SELECT
    TO pas_usuario_portal
    USING (productor_asignado_id = current_setting('app.current_productor_id', true));
```
*(Patrón de hardening propuesto para aislamiento fino a nivel de registro en base de datos).*

---

### 4. Detección y Operación de SOC (Sigma Rule)
Los controles preventivos fallan tarde o temprano; por eso es mandatorio contar con capacidad de detección rápida.

El intento de salto de esquema mediante SQL Injection (`' UNION SELECT ... FROM salud_restringida.historial_medico`) debe ser capturado en los logs de acceso del WAF y correlacionado mediante reglas de detección (formato **Sigma**), mapeadas a la técnica **MITRE ATT&CK T1190** para instruir al SOC a aislar la IP origen.

---

## Fricciones Operativas y Trade-offs Reales

Implementar estos controles en el día a día de una aseguradora genera tensiones técnicas que deben administrarse:

1. **Cifrado de Campo vs. Rendimiento de Consultas:**  
   Cifrar columnas completas con `pgcrypto` o mediante KMS impide el uso eficiente de índices B-Tree en bases de datos relacionales. Si se cifra el DNI, no se puede hacer un `WHERE dni = '...'` de forma indexada sin descifrar o utilizar técnicas de cifrado determinista / tokenización, las cuales aumentan la complejidad arquitectónica. Por eso, para datos Confidenciales se prioriza **TDE (Transparent Data Encryption)** a nivel de disco/volumen, reservando el cifrado de columna para la tabla de diagnósticos médicos (**Restringido**).

2. **DLP y Falsos Positivos en la Atención al Cliente:**  
   Un filtro de DLP demasiado estricto sobre términos médicos puede bloquear correos legítimos enviados por peritos médicos externos o liquidadores de siniestros de ART. Se requiere un canal seguro específico (portal de siniestros con autenticación MFA y carga encriptada) para evitar que los médicos utilicen el correo electrónico convencional.

---

## Verificación Práctica
Para comprobar el funcionamiento del control de mínimo privilegio en base de datos frente al intento de inyección SQL:
```bash
docker compose -f lab/docker-compose.yml exec web python test_exploit.py
# (O desde tu máquina si tenés psycopg2: python lab/test_exploit.py)
```
O ver el mapa completo de amenazas en [Flujo de Datos](data-flow.md).
