# Controles de Seguridad según Clasificación

## Objetivo
El objetivo de este documento es definir qué controles de seguridad técnicos y organizacionales deben aplicarse a la información según el nivel de clasificación establecido en [data-classification.md](data-classification.md).

La clasificación permite identificar qué información necesita mayor protección, pero por sí sola no protege los datos. El paso siguiente es vincular cada nivel con los riesgos específicos que enfrenta y con los controles necesarios para mitigarlos.

La idea es aplicar controles proporcionales al impacto de una posible exposición: un dato público no requiere las mismas medidas que un diagnóstico médico o una credencial administrativa.

## Relación entre clasificación, riesgo y controles

El modelo de decisión responde a la siguiente secuencia:
```text
Dato
  ↓
Clasificación
  ↓
Riesgo
  ↓
Control
```

Por ejemplo, ante un diagnóstico médico:
```text
Diagnóstico médico
  ↓
Restringido (Dato sensible - Ley 25.326)
  ↓
Filtración con impacto legal severo y daño a la intimidad
  ↓
Cifrado fuerte + RBAC estricto + MFA obligatorio + DLP + Monitoreo dedicado
```

Mientras que para un dato operativo como el número de póliza:
```text
Número de póliza
  ↓
Confidencial
  ↓
Uso indebido de información personal o contractual
  ↓
Cifrado estándar + RBAC + Logging de acceso + Política de retención
```

De esta manera, los controles no se implementan de forma aislada, sino directamente fundamentados en el riesgo que reducen.

## Matriz de controles técnicos y organizacionales

| Nivel | Riesgos principales | Controles técnicos | Controles organizacionales |
|---|---|---|---|
| **Público** | Modificación o publicación no autorizada | Controles de integridad web, backups estándar y monitoreo de disponibilidad. | Procedimiento formal de aprobación de publicaciones externas. |
| **Interno** | Acceso interno indebido o fuga accidental | Autenticación centralizada, RBAC básico y registro de eventos del sistema. | Acuerdos de confidencialidad, capacitación inicial y políticas de uso aceptable. |
| **Confidencial** | Filtración de datos de clientes, pólizas o información financiera | Cifrado en reposo y en tránsito (TLS), RBAC granular, MFA en accesos remotos, DLP y logging de consultas. | Principio de necesidad de conocer (*need to know*), control de proveedores y revisión periódica de accesos. |
| **Restringido** | Exfiltración de datos de salud, credenciales o claves maestras | Cifrado reforzado, segmentación estricta de red, MFA obligatorio, tokenización, SIEM, FIM y backups inmutables. | Autorización nominal documentada, auditorías trimestrales de privilegios y protocolo de destrucción segura. |

## Detalle de los controles de seguridad

### Cifrado en tránsito
Protege los datos mientras viajan a través de redes públicas o internas.
- En la relación cliente-servidor web se implementa mediante **TLS 1.3** (o 1.2 como mínimo admisible) con suites de cifrado seguras.
- En las comunicaciones internas (por ejemplo, entre la API y el servidor de base de datos) evita que el tráfico no cifrado sea interceptado si un actor malicioso gana presencia en la red interna.
- Es obligatorio para los niveles **Confidencial** y **Restringido**.

### Cifrado en reposo
Protege la información cuando se encuentra almacenada en medios persistentes (bases de datos, sistemas de archivos, discos y cintas de backup).
- Si un atacante extrae una copia cruda de una base de datos o accede físicamente a un almacenamiento, el cifrado evita que la información sea legible sin las claves criptográficas adecuadas.
- Las claves de cifrado deben gestionarse de forma independiente a los datos almacenados (utilizando servicios de KMS o módulos HSM).
- Es prioritario para tablas con datos de clientes e indispensable para datos de salud.

### RBAC (Role-Based Access Control)
Permite restringir el acceso a los datos según la función que desempeña cada usuario dentro de la organización.
- Un suscriptor de pólizas comerciales no tiene justificación para consultar historias clínicas de reclamos de ART.
- Implementa el principio de **mínimo privilegio**, limitando el daño potencial si una cuenta de usuario es vulnerada.

### MFA (Multi-Factor Authentication)
Exige al menos dos factores de autenticación distintos (algo que se sabe, algo que se tiene o algo que se es) antes de conceder acceso.
- Reduce drásticamente el impacto de ataques de phishing o reutilización de credenciales filtradas.
- Su aplicación debe ser obligatoria para cualquier acceso remoto (VPN), portales de empleados y especialmente para cuentas con privilegios administrativos.

### DLP (Data Loss Prevention)
Herramientas orientadas a monitorear y bloquear intentos de transferir información clasificada fuera del perímetro autorizado.
- En una aseguradora se configura con reglas para detectar patrones de DNI, números de tarjetas de crédito o términos médicos en correos salientes, subidas web o copias a dispositivos USB.
- Actúa como salvaguarda frente a errores humanos o exfiltración maliciosa por parte de usuarios internos.

### Logging y monitoreo
El registro continuo de eventos permite saber quién accedió a qué información y cuándo.
- Deben registrarse inicios de sesión, cambios de privilegios, consultas masivas a bases de datos y accesos a registros médicos.
- Los logs deben enviarse a un sistema centralizado (**SIEM**) con protección contra modificación, permitiendo correlacionar alertas e investigar incidentes en tiempo real.

### Retención y destrucción segura
Mantener datos históricos sin justificación legal o de negocio incrementa innecesariamente la superficie de ataque.
- La **retención** fija plazos formales de conservación según las obligaciones regulatorias del sector seguros (por ejemplo, plazos de prescripción de siniestros).
- La **destrucción segura** asegura que, una vez vencido el plazo, los registros digitales sean sobreescritos o desasociados criptográficamente (*crypto-shredding*) para evitar su recuperación forense.

## Implementación en capas en una aseguradora

En la práctica, ningún control opera de manera aislada. Se implementa una estrategia de **defensa en profundidad**:

```text
Perímetro web    → WAF + TLS en tránsito
Identidad        → MFA + RBAC
Servidor / API   → Validación de entradas + Mínimo privilegio en DB
Almacenamiento   → Cifrado en reposo (TDE / disco)
Operaciones      → Logging centralizado + DLP + Backups inmutables
```

Si el control perimetral falla (por ejemplo, ante una vulnerabilidad web), los controles de almacenamiento e identidad (cifrado y RBAC) impiden que el atacante extraiga libremente la totalidad de la información restringida.

Para comprender cómo transita la información a través de estas capas en una arquitectura real, el análisis continúa en [data-flow.md](data-flow.md).
