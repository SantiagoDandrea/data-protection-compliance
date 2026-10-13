# Bitácora del Proyecto y Notas de Desarrollo

En este archivo fui anotando cómo fue mutando el proyecto durante octubre de 2026, los errores que fui cometiendo en el camino, las devoluciones que me hicieron y por qué terminé cambiando varias decisiones de arquitectura y documentación.

---

## Octubre 2026 — Ronda de auditoría técnica externa (Refinamiento de Controles y Alcance)

A partir de una auditoría técnica externa exhaustiva, se aplicaron mejoras puntuales para eliminar inconsistencias entre componentes y transparentar el estado de cada entregable:

1. **Corrección de dependencias en `postgres_hardening.sql`:**
   El script de hardening intentaba aplicar Row-Level Security (RLS) sobre una columna (`productor_asignado_id`) y roles (`pas_usuario_portal`, `db_analista_bi`) que no estaban definidos en el esquema inicial de `init.sql`. Se actualizó el script para volverlo 100% autocontenido e idempotente: crea los roles y la columna requerida antes de aplicar las políticas, permitiendo que se ejecute sin errores directamente sobre la base de datos del lab.

2. **Advertencia operacional y parametrización en Terraform:**
   En `terraform_s3_worm_backup.tf`, el recurso S3 Object Lock en modo `COMPLIANCE` (90 días) estaba nombrado como `prod`. En AWS real, esta configuración es irreversible durante el período de retención, incluso para la cuenta root. Se parametrizó el entorno a `lab` por defecto y se incorporó una advertencia destacada sobre las consecuencias operacionales y costos de aplicar WORM estricto en cuentas reales.

3. **Matriz de Validación por Componente en `README.md`:**
   Se incorporó una tabla de estado técnico que distingue explícitamente entre los artefactos completamente ejecutables en Docker (PostgreSQL 16, app web Flask, exploit en Python y script de hardening SQL) y aquellos que corresponden a patrones y plantillas de referencia (Terraform S3 WORM, regla de detección Sigma y reglas DLP).

4. **Clarificación didáctica en `app.py` y `test_exploit.py`:**
   Se añadieron comentarios señalando la vulnerabilidad intencional en la consulta de cotización y referenciando la rama segura parametrizada. Asimismo, se reforzó en la salida del script la distinción conceptual entre parametrización (integridad sintáctica en software) y mínimo privilegio (contención del blast radius en la base de datos).

---

## Octubre 2026 — Ronda de correcciones de fondo y honestidad técnica

Después de armar el laboratorio ejecutable, le pedí a un auditor técnico que revise el repositorio. Me marcó tres cosas bastante concretas y justas que tuve que salir a corregir:

1. **La trampa de las fechas de 2024:**
   Al principio le había puesto fechas de principios de 2024 en el changelog y en la regla Sigma, pensando que quedaba más "serio" o que simulaba un proyecto con tiempo encima. Fue una mala idea: si los commits del repo son de octubre de 2026, simular fechas viejas hace que cualquier persona que revise el historial de Git desconfíe de todo lo demás. Borré cualquier fecha simulada y dejé las fechas reales de octubre de 2026.

2. **Permisos en PostgreSQL y la herencia del rol PUBLIC:**
   En el script de base de datos (`lab/db/init.sql`) había metido un `REVOKE ALL ON SCHEMA salud_restringida FROM app_user_least_privilege`. 
   El auditor me hizo notar un detalle fino de Postgres:
   - En PostgreSQL los permisos son por lista blanca (*whitelist*): si a ese usuario nunca le hiciste `GRANT SELECT` sobre las tablas de salud, ya de por sí no puede leerlas. Hacer un `REVOKE` a ese usuario era redundante y demuestra pensar en permisos como si fuera una lista negra.
   - Pero además, en Postgres los esquemas nuevos le dan permiso `USAGE` al pseudo-rol `PUBLIC` por defecto. Si no le revocás `USAGE` a `PUBLIC`, cualquier usuario conectado hereda ese permiso y puede atravesar el esquema.
   - Por ende, el bloqueo real venía de no haberle dado `GRANT SELECT`, pero el aislamiento de esquema requería `REVOKE ALL ON SCHEMA salud_restringida FROM PUBLIC;`. Lo corregí en `init.sql` y dejé la nota explicada.

3. **"Trazas de auditoría reales" que no eran reales:**
   En el README decía que el repo incluía "trazas de auditoría reales de WAF y BD". La verdad es que el `docker-compose` levanta solo Postgres y Flask para ser liviano y fácil de correr; no levanta un NGINX con ModSecurity ni tiene `pgaudit` compilado. Esas trazas en `lab/detection/sqli_waf.log` las armé yo a mano como muestra de lo que ingesta una regla Sigma. Cambié la redacción para decir claramente que son **logs sintéticos de ejemplo**.

4. **Contraseñas del lab:**
   En `init.sql` y `test_exploit.py` las contraseñas están fijas (`password_vulnerable_123`) para que cualquiera pueda hacer `docker compose up` y probar el exploit sin tener que configurar variables antes. Sumé un `lab/.env.example` y advertencias explícitas en el código explicando que esto es solo para el lab local y que en producción va siempre por KMS o gestor de secretos.

---

## Octubre 2026 — Del papel a un laboratorio ejecutable

El repositorio empezó siendo puro Markdown: un resumen de la Ley 25.326, una matriz de clasificación de datos y el análisis del ataque de ransomware a *La Segunda Seguros* en 2023. La crítica principal que recibí fue directa: *"es un ensayo académico; si no corre, parece un trabajo práctico generado por IA"*.

Ahí decidí implementar el lab técnico:
- **Docker Compose con PostgreSQL 16:** Separé dos esquemas físicos (`seguros_core` para pólizas y `salud_restringida` para historias clínicas) y dos usuarios de base de datos.
- **Script de explotación (`test_exploit.py`):** Un script en Python con `psycopg2` que tira la inyección SQL (`UNION SELECT`). Si corre con el usuario sobreprivilegiado, te saca los diagnósticos médicos en la consola. Si corre con el usuario de mínimo privilegio, el motor de Postgres lo rebota con el error nativo `SQLSTATE 42501 (INSUFFICIENT PRIVILEGE)`.
- **Dashboard web en Flask:** Una interfaz con botones prearmados para poder jugar con la inyección desde el navegador (`http://localhost:5000`).
- **Controles complementarios:** Agregué un archivo de Terraform (`terraform_s3_worm_backup.tf`) con S3 Object Lock en modo COMPLIANCE para mostrar cómo frenar el borrado de backups por ransomware, unas expresiones regulares de DLP para DNI y términos CIE-10, y una regla Sigma para SIEM.
- **Corrección en el Código Penal:** En el primer borrador había citado el Art. 117 bis para el delito de acceso a bases de datos. Al revisar en InfoLEG me di cuenta de que ese artículo fue derogado en 2008 por la Ley 26.388 de Delitos Informáticos, y que hoy aplican los Arts. 153 bis y 157 bis. Dejé asentada la corrección.

---

## Primer borrador (Octubre 2026) — Estructura documental inicial

- Lectura de la Ley 25.326 y Resoluciones de la AAIP (especialmente la Res. 47/2018 que reemplazó a la vieja Disp. 11/2006).
- Definición de la matriz de 4 niveles adaptada a seguros (Público, Interno, Confidencial, Restringido).
- Comparativa entre la normativa argentina y el GDPR (notificación de incidentes en 72 horas y el estatus de país adecuado que la UE le ratificó a Argentina a principios de 2024).
- Diagrama inicial de flujo de datos y análisis de riesgos.
