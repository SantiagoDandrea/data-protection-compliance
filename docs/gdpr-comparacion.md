# Comparación entre Ley 25.326 y GDPR

## Objetivo

El objetivo de este documento es contrastar el marco legal argentino de protección de datos personales (**Ley 25.326**) con el **General Data Protection Regulation (GDPR — Reglamento UE 2016/679)** de la Unión Europea.

No se pretende realizar una exégesis jurídica, sino identificar cómo estas dos normativas influyen sobre las decisiones técnicas de seguridad: clasificación de datos, controles aplicables, gestión de incidentes y transferencias internacionales.

## Matriz comparativa general

| Eje                                | Ley 25.326 (Argentina)                                                                                                            | GDPR (Unión Europea)                                                                                                                                        |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Definición de dato personal**    | Información de cualquier tipo referida a personas físicas o de existencia ideal determinadas o determinables.                     | Cualquier información sobre una persona física identificada o identificable.                                                                                |
| **Datos sensibles**                | Categoría cerrada: origen racial/étnico, opiniones políticas, convicciones religiosas, afiliación sindical, salud y vida sexual.  | Denominadas **categorías especiales de datos**: añade explícitamente datos genéticos y biométricos dirigidos a identificar de manera unívoca a una persona. |
| **Derechos de los titulares**      | Acceso, rectificación, actualización y supresión.                                                                                 | Acceso, rectificación, supresión ("derecho al olvido"), limitación del tratamiento, portabilidad y oposición.                                               |
| **Enfoque de seguridad**           | Obligación general de adoptar medidas técnicas y organizativas para evitar adulteración, pérdida o acceso no autorizado (Art. 9). | Enfoque explícito basado en riesgo: exige medidas técnicas apropiadas para garantizar un nivel de seguridad adecuado (Art. 32).                             |
| **Notificación de brechas**        | No exigida formalmente en el texto de la ley del año 2000 (la AAIP emitió guías voluntarias de notificación).                     | **Obligatoria:** notificación a la autoridad de control en un plazo máximo de **72 horas** y comunicación a los afectados ante alto riesgo (Arts. 33 y 34). |
| **Conservación / Retención**       | Destrucción al vencer la finalidad que justificó la recolección, salvo obligación legal de conservarlos.                          | Principio formal de limitación del plazo de conservación.                                                                                                   |
| **Transferencias internacionales** | Prohibición general hacia países sin nivel adecuado de protección, con excepciones legales específicas.                           | Prohibición hacia terceros países sin decisión de adecuación, salvo garantías adecuadas (cláusulas tipo, BCR) o excepciones.                                |
| **Responsabilidad demostrada**     | Obligación de registro de bases de datos y cumplimiento pasivo.                                                                   | Principio de **Accountability** (_responsabilidad proactiva_): el responsable debe ser capaz de demostrar que cumple con la normativa.                      |

## Puntos clave de análisis técnico

### 1. Datos sensibles y categorías especiales

Ambos marcos coinciden en brindar máxima protección a los datos de salud.

- En la Ley 25.326, los diagnósticos y coberturas médicas de una aseguradora son datos sensibles.
- En el GDPR, integran las categorías especiales del Art. 9, cuyo tratamiento está prohibido por defecto a menos que aplique una excepción expresa (como el consentimiento explícito o la gestión de prestaciones de salud).
- En el proyecto, este principio justifica por qué la información médica recibe la clasificación de **Restringido** en [data-classification.md](data-classification.md).

### 2. Seguridad técnica del tratamiento: Art. 9 vs. Art. 32

Mientras que la Ley 25.326 fija un deber general de seguridad (complementado localmente por la Resolución AAIP 47/2018), el **Artículo 32 del GDPR** detalla exigencias técnicas concretas que un equipo de seguridad debe implementar:

- **Seudonimización y cifrado** de los datos personales.
- Capacidad de garantizar la **confidencialidad, integridad, disponibilidad y resiliencia** continuadas de los sistemas y servicios de tratamiento.
- Capacidad de **restaurar la disponibilidad y el acceso** a los datos personales de forma rápida en caso de incidente físico o técnico (estrategia de backups ante ransomware).
- Proceso de **verificación, evaluación y valoración regulares** de la eficacia de las medidas técnicas implementadas.

Estos requisitos reflejan exactamente las medidas analizadas en [security-controls.md](security-controls.md).

### 3. Notificación obligatoria de brechas (Data Breach Notification)

Esta constituye la diferencia operativa más profunda entre ambos marcos para un equipo de respuesta a incidentes (CSIRT / SOC):

- Bajo **GDPR (Arts. 33 y 34)**, una aseguradora que sufre un incidente como el de _La Segunda Seguros_ tiene la obligación legal de notificar formalmente a la autoridad en un plazo máximo de **72 horas** tras haber tenido constancia del hecho. Si la filtración supone un riesgo alto para los derechos de los asegurados (por ejemplo, exposición de diagnósticos médicos), debe además comunicarlo directamente a los titulares sin dilación indebida.
- Bajo la **Ley 25.326**, no existe una obligación legal explícita con plazos perentorios en el texto de la ley, aunque la AAIP promueve su comunicación voluntaria y los proyectos de reforma legislativa en Argentina buscan incorporar este estándar.

### 4. Principio de Accountability (Responsabilidad Proactiva)

Bajo el GDPR, no basta con tener implementados controles técnicos; la compañía debe contar con evidencia documental de que dichos controles existen y son efectivos:

- Evaluaciones de Impacto en la Protección de Datos (DPIA) antes de lanzar nuevos sistemas que procesen datos sensibles.
- Registro documentado de las actividades de tratamiento de datos.
- Procedimientos formales para dar respuesta a los derechos de los titulares dentro de los plazos normativos.

### 5. Transferencias internacionales y estatus de Argentina

La Unión Europea exige que los datos de ciudadanos europeos solo salgan de su territorio si el destino ofrece garantías equivalentes.

- **Decisión de Adecuación:** Mediante la Decisión 2003/490/CE (ratificada en la revisión periódica de 2024), la Comisión Europea reconoció formalmente a la Argentina como un país con nivel adecuado de protección de datos personales.
- Esto habilita que una aseguradora europea transfiera datos hacia una filial o reaseguradora en Argentina sin requerir autorizaciones contractuales adicionales complejas.

## Conclusión

Para una aseguradora con sede en Argentina, la [Ley 25.326](ley-25326.md) y las resoluciones de la AAIP constituyen el marco de cumplimiento obligatorio primario.

Sin embargo, el **GDPR** opera como el estándar de referencia internacional más exigente. Comprender sus requisitos —particularmente la notificación obligatoria de incidentes, el principio de _accountability_ y las exigencias de resiliencia del Artículo 32— permite diseñar arquitecturas de seguridad que no solo cumplen con la normativa local, sino que están alineadas con las mejores prácticas globales del sector financiero y asegurador.
