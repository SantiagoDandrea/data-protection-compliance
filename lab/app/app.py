#!/usr/bin/env python3
"""
Aplicación Web: Cotizador Vulnerable a SQL Injection & Demostración de Mínimo Privilegio (RBAC)
Motor: PostgreSQL 16
Contexto: Portal de Asegurados / Cotizador de Pólizas (Aseguradora Argentina)
Autor: Santiago D'Andrea
"""

import os
from flask import Flask, render_template, request, jsonify
import psycopg2
from psycopg2 import errors

app = Flask(__name__)

# Parámetros de conexión a PostgreSQL
PG_HOST = os.environ.get("DB_HOST", "localhost")
PG_PORT = os.environ.get("DB_PORT", "5432")
PG_DB = os.environ.get("DB_NAME", "aseguradora_db")

# Credenciales de base de datos para el lab local (en producción jamás van hardcodeadas;
# se usan variables de entorno o un gestor de secretos como HashiCorp Vault / AWS Secrets Manager)
PASS_OVERPRIVILEGED = os.environ.get("APP_OVERPRIVILEGED_PASS", "password_vulnerable_123")
PASS_LEAST_PRIVILEGE = os.environ.get("APP_LEAST_PRIVILEGE_PASS", "password_secure_456")

def ejecutar_en_postgres(query, user_mode, parameterized=False, param=None):
    """Ejecuta la consulta en PostgreSQL con las credenciales del rol seleccionado."""
    user = "app_user_overprivileged" if user_mode == "overprivileged" else "app_user_least_privilege"
    password = PASS_OVERPRIVILEGED if user_mode == "overprivileged" else PASS_LEAST_PRIVILEGE
    
    conn = psycopg2.connect(
        host=PG_HOST, port=PG_PORT, dbname=PG_DB,
        user=user, password=password, connect_timeout=4
    )
    conn.autocommit = True
    cur = conn.cursor()
    
    if parameterized:
        cur.execute(query, (param,))
    else:
        cur.execute(query)
    
    results = cur.fetchall()
    columns = [desc[0] for desc in cur.description] if cur.description else []
    cur.close()
    conn.close()
    return columns, results

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/api/consultar", methods=["POST"])
def consultar():
    data = request.get_json() or {}
    poliza_input = data.get("poliza", "").strip()
    user_mode = data.get("user_mode", "overprivileged") # 'overprivileged' o 'least_privilege'
    use_parameterization = data.get("parameterized", False)
    
    if not poliza_input:
        return jsonify({"error": "Debe ingresar un número de póliza o payload"}), 400

    if use_parameterization:
        # VERSIÓN SEGURA: Prepared Statements / Consultas Parametrizadas
        # El driver y el motor tratan la entrada del usuario como un literal estricto,
        # impidiendo que se altere la estructura sintáctica de la consulta SQL.
        raw_query = "SELECT numero_poliza, titular, cobertura, prima FROM seguros_core.polizas WHERE numero_poliza = %s"
        executed_query = f"{raw_query} [PARAM: {poliza_input}]"
    else:
        # ⚠️ VULNERABLE POR DISEÑO (LAB DEMO / NO USAR EN PRODUCCIÓN):
        # Concatenación directa de strings sin sanitizar. Permite inyección SQL clásica (T1190)
        # mediante payloads como: POL-9999' UNION SELECT ... --
        # En producción utilizar siempre consultas parametrizadas (ver rama 'if' superior).
        raw_query = f"SELECT numero_poliza, titular, cobertura, prima FROM seguros_core.polizas WHERE numero_poliza = '{poliza_input}'"
        executed_query = raw_query

    try:
        columns, rows = ejecutar_en_postgres(raw_query, user_mode, use_parameterization, poliza_input)

        # Análisis de fuga de datos de salud (Clasificación RESTRINGIDO)
        classification_breach = False
        health_keywords = ["diagnostico", "paciente", "tratamiento", "observaciones_medicas", "clonazepam", "neoplasia", "hernia", "hipoacusia"]
        
        results_list = []
        for r in rows:
            row_dict = {}
            for idx, col in enumerate(columns):
                val = str(r[idx])
                row_dict[col] = val
                if any(kw in val.lower() for kw in health_keywords):
                    classification_breach = True
            results_list.append(row_dict)

        return jsonify({
            "status": "success",
            "query": executed_query,
            "engine": "PostgreSQL 16",
            "user_mode": user_mode,
            "columns": columns,
            "results": results_list,
            "classification_breach": classification_breach,
            "explanation": (
                "🚨 ALERTA GRC: La consulta extrajo registros de salud clasificados como RESTRINGIDOS (Ley 25.326 Art. 2 y 7). "
                "El usuario de base de datos 'app_user_overprivileged' no implementa segregación de esquemas ni mínimo privilegio."
                if classification_breach else
                "✔️ Consulta procesada dentro de los límites del nivel CONFIDENCIAL (seguros_core.polizas)."
            )
        })

    except psycopg2.errors.InsufficientPrivilege as e:
        # Excepción nativa de PostgreSQL al intentar violar la política de acceso
        return jsonify({
            "status": "blocked",
            "query": executed_query,
            "engine": "PostgreSQL 16",
            "user_mode": user_mode,
            "sqlstate": e.pgcode,
            "error": str(e).strip(),
            "mitigation_success": True,
            "explanation": (
                "🛡️ MITIGACIÓN NATIVA DE POSTGRESQL EXITOSA (SQLSTATE 42501 - INSUFFICIENT PRIVILEGE): "
                "El motor de base de datos rechazó la consulta. Aun cuando existe la inyección SQL en la capa web, "
                "el usuario 'app_user_least_privilege' carece de permisos de lectura sobre el esquema 'salud_restringida'."
            )
        })

    except Exception as e:
        return jsonify({
            "status": "error",
            "query": executed_query,
            "engine": "PostgreSQL 16",
            "user_mode": user_mode,
            "error": str(e),
            "explanation": f"Error reportado por PostgreSQL: {e}"
        }), 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    print(f"[*] Servidor Web Lab escuchando en http://localhost:{port}")
    print(f"[*] Base de datos destino: PostgreSQL ({PG_HOST}:{PG_PORT}/{PG_DB})")
    app.run(host="0.0.0.0", port=port, debug=False)
