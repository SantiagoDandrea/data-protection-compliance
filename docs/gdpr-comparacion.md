# Comparación Práctica: Ley 25.326 vs. GDPR (Reglamento UE 2016/679)

## Justificación del Contraste
¿Por qué una aseguradora que opera en Argentina debe mirar el estándar europeo?
1. **Contratos con Reaseguradoras Internacionales:** Grandes reaseguradoras globales (Munich Re, Swiss Re, MAPFRE Re) imponen cláusulas contractuales de tratamiento de datos alineadas con el GDPR a las aseguradoras cedentes locales.
2. **Mantenimiento del Estatus de Adecuación:** Argentina fue declarada país adecuado por la Comisión Europea mediante la **Decisión 2003/490/CE** (ratificada en su última revisión formal en **enero de 2024**). Mantener este estatus comercial estratégico exige que las empresas argentinas eleven sus prácticas operativas hacia los estándares europeos.
3. **Horizonte Regulatorio Local:** El proyecto de reforma de la Ley 25.326 presentado por la AAIP toma casi textualmente los conceptos centrales del GDPR (notificación de brechas en 72 horas, DPIA y figura del DPO).

---

## Matriz Comparativa de Impacto Operativo

| Eje de Análisis | Ley 25.326 (Argentina) | GDPR (Unión Europea) | Implicancia Práctica en Seguridad |
|---|---|---|---|
| **Definición de Dato Personal** | Personas físicas y personas de existencia ideal (personas jurídicas). | Exclusivamente personas físicas identificadas o identificables. | En Argentina, los datos comerciales y balances de una empresa cliente gozan de tutela bajo la ley; en la UE solo personas humanas. |
| **Datos Sensibles / Categorías Especiales** | Salud, vida sexual, origen racial/étnico, opiniones políticas, religión y afiliación sindical. | Suma explícitamente **datos genéticos y biométricos** orientados a identificación unívoca. | Si la aseguradora implementa reconocimiento facial o huella para el login del asegurado, bajo GDPR es dato sensible; en Argentina se subsume por analogía jurisprudencial. |
| **Enfoque de Seguridad** | Deber general de seguridad (Art. 9) complementado por la Res. AAIP 47/2018. | Enfoque explícito basado en riesgo (*Risk-based approach*, Art. 32): resiliencia, verificación regular y DPIA. | El GDPR obliga a calcular formalmente la probabilidad e impacto antes de desplegar un sistema, no solo aplicar listas de verificación. |
| **Notificación de Brechas (Data Breach)** | **No obligatoria por texto de ley.** Recomendación voluntaria según Res. AAIP 40/2018. | **Obligatoria e inexcusable:** Plazo máximo de **72 horas** a la autoridad (Art. 33) y aviso a los titulares si el riesgo es alto (Art. 34). | Un incidente de ransomware exige tener playbooks de respuesta pre-armados para notificar en menos de 3 días con informe preliminar forense. |
| **Principio de Responsabilidad Proactiva** | Cumplimiento documental pasivo (inscripción de bancos de datos en el RNPDP). | **Accountability (Art. 5.2):** La organización debe ser capaz de *demostrar en cualquier momento* que sus controles son efectivos. | Exige conservar evidencias vivas: reportes de escaneo de vulnerabilidades, logs de auditoría inmutables y actas de comités de crisis. |
| **Régimen de Sanciones Monetarias** | Límite histórico nominal desactualizado ($100.000 ARS por falta grave). | Hasta **20 millones de euros o el 4% de la facturación global anual** del ejercicio anterior. | El riesgo financiero bajo GDPR es de quiebra corporativa; en Argentina el riesgo se traslada principalmente a la vía judicial civil y al daño de reputación. |

---

## Análisis Técnico Profundo

### 1. Resiliencia y Recuperación ante Ransomware (Art. 32 GDPR)
El Artículo 32.1.c del GDPR exige textualmente:
> *«La capacidad de restaurar la disponibilidad y el acceso a los datos personales de forma rápida en caso de incidente físico o técnico.»*

En el sector asegurador argentino, la disponibilidad de las pólizas es crítica para emitir coberturas y abonar indemnizaciones de siniestros. Ante ataques destructivos (como LockBit en *La Segunda*), la resiliencia no se logra con una cinta de backup guardada en el mismo centro de cómputos: exige repositorios con **inmutabilidad criptográfica y separación lógica de identidades**, tal como se diseñó en el laboratorio con [`terraform_s3_worm_backup.tf`](../lab/controls/terraform_s3_worm_backup.tf).

### 2. Notificación en 72 Horas: La Presión Operativa en el SOC
En una empresa sujeta al GDPR, el reloj de 72 horas comienza a correr desde el momento en que se adquiere "conocimiento cierto" (*awareness*) de una intrusión que afecte datos personales.

Esto modifica el diseño del monitoreo:
- Sin correlación en tiempo real (SIEM), un incidente puede pasar meses inadvertido (*dwell time* promedio: 16 días en LATAM).
- Con reglas de detección tempranas como [`sigma_sqli_detection.yml`](../lab/detection/sigma_sqli_detection.yml), el equipo de SOC contiene el salto de clasificación antes de que se complete la exfiltración masiva, permitiendo documentar ante el regulador que los datos no salieron del perímetro o que se encontraban cifrados con claves seguras.

---

## Criterio de Decisión para la Aseguradora
Diseñar la arquitectura de seguridad bajo el estándar más restrictivo (**GDPR**) asegura que la compañía cumpla holgadamente con la **Ley 25.326** y quede preparada para la inminente actualización legislativa argentina, eliminando el costo de reingeniería cuando la nueva ley sea promulgada.
