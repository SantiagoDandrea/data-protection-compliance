# Bitácora de Desarrollo y Aprendizajes (Changelog)

Este documento registra cómo fue evolucionando el proyecto a lo largo de las iteraciones de trabajo (octubre 2026), incluyendo correcciones normativas y ajustes técnicos que fui haciendo sobre la marcha.

---

## [Iteración 3] — Octubre 2026
### Ajustes de Realismo, Permisos de Postgres y Honestidad Técnica
- **Ajuste fino de permisos en PostgreSQL:** Corregí un error conceptual en `lab/db/init.sql`. Había puesto un `REVOKE ALL ON SCHEMA salud_restringida FROM app_user_least_privilege`, pero en Postgres los esquemas nuevos heredan `USAGE` a través del rol `PUBLIC`. Por eso, un `REVOKE` al usuario específico no alcanzaba; agregué `REVOKE ALL ON SCHEMA salud_restringida FROM PUBLIC`. (El bloqueo del exploit funcionaba igual porque la tabla no tenía `SELECT` a PUBLIC, pero el esquema seguía expuesto).
- **Aclaración sobre logs:** En `lab/detection/sqli_waf.log` y en la documentación dejé en claro que son **logs sintéticos de ejemplo** armados a mano para mostrar qué buscaría un analista de SOC, y no logs reales de un WAF corriendo en producción (el `docker-compose` se mantiene liviano a propósito).
- **Manejo de credenciales en el Lab:** Agregué `lab/.env.example` y advertencias explícitas en el código indicando que las contraseñas fijas son exclusivamente para poder levantar el laboratorio local en un comando, algo que jamás se hace en producción.

---

## [Iteración 2] — Octubre 2026
### Pasaje a Laboratorio Técnico Ejecutable y Revisión Normativa
- **Lab ejecutable con PostgreSQL 16 (`lab/`):**
  - Armé un entorno con Docker Compose con dos esquemas (`seguros_core` y `salud_restringida`) y dos usuarios con privilegios distintos.
  - Creé `lab/test_exploit.py` para poder correr la inyección SQL (`UNION SELECT`) por consola y ver directamente la excepción de Postgres (`SQLSTATE 42501 - INSUFFICIENT PRIVILEGE`).
  - Armé una interfaz web sencilla en Flask para quien prefiera probar los payloads con botones.
- **Controles prácticos de muestra:**
  - `lab/controls/dlp_rules.json`: Expresiones regulares para detectar DNI, CUIT y términos de salud saliendo por correo.
  - `lab/controls/terraform_s3_worm_backup.tf`: Ejemplo de bucket S3 con Object Lock en modo COMPLIANCE para frenar ransomware tipo LockBit.
  - `lab/detection/sigma_sqli_detection.yml`: Regla Sigma para alertar el intento de SQLi en un SIEM.
- **Auditoría legal y corrección en Código Penal:**
  - Corregí la cita del Art. 117 bis en `docs/ley-25326.md`: estaba derogado desde 2008 por la Ley 26.388 de Delitos Informáticos. Lo cambié por los artículos vigentes (153 bis y 157 bis).
  - Verifiqué los plazos de derechos ARCO en InfoLEG (10 días corridos para acceso, 5 días hábiles para rectificación/supresión).
  - Detallé cómo la Res. AAIP 47/2018 reemplazó la vieja Disposición 11/2006.

---

## [Iteración 1] — Octubre 2026
### Estructura Inicial y Marco Documental
- Primer borrador de la matriz de clasificación en 4 niveles adaptada a una aseguradora (Público, Interno, Confidencial, Restringido).
- Documentación del caso de estudio de ransomware de *La Segunda Seguros* (2023).
- Comparativa entre la Ley 25.326 argentina y el GDPR europeo (estatus de adecuación, notificación de brechas en 72 horas).
- Mapa inicial de flujo de datos y controles teóricos.
