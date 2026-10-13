# ==============================================================================
# INFRAESTRUCTURA COMO CÓDIGO (IaC) - REPOSITORIO DE BACKUPS INMUTABLES (S3 WORM)
# Contexto: Mitigación de Ransomware (T1486 / T1490) en Aseguradora Argentina
# Lección aprendida: Incidente La Segunda Seguros (LockBit, 2023)
#
# ⚠️ ADVERTENCIA DE SEGURIDAD OPERACIONAL Y PROPÓSITO EDUCATIVO:
# Esta plantilla de Terraform es un PATRÓN ARQUITECTÓNICO DE REFERENCIA.
# NO está desplegada en una cuenta real de AWS ni forma parte del despliegue local de Docker.
#
# IMPACTO CRÍTICO DE S3 OBJECT LOCK EN MODO COMPLIANCE:
# 1. En modo COMPLIANCE, el bloqueo WORM es absoluto e irreversible:
#    NI SIQUIERA LA CUENTA ROOT DE AWS puede acortar el período de retención ni borrar
#    los objetos o el bucket antes del vencimiento (90 días por defecto).
# 2. Aplicar este código sobre una cuenta real de AWS sin planificar generará costos fijos
#    y recursos que no podrán ser eliminados hasta cumplido el plazo de retención.
# 3. Para laboratorios o validaciones iniciales, se recomienda usar modo GOVERNANCE con
#    una ventana reducida (ej. 1 día) o emular S3 mediante LocalStack.
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Región de AWS para el vault de backups inmutables"
}

variable "environment" {
  type        = string
  default     = "lab"
  description = "Ambiente de despliegue (lab / staging / prod). Por defecto 'lab' para evitar confusiones."
}

variable "retention_days" {
  type        = number
  default     = 90
  description = "Días de retención inmutable WORM garantizados"
}

provider "aws" {
  region = var.aws_region
}

# 1. Clave de Cifrado Administrada por el Cliente (KMS CMK)
# Justificación de GRC: Las claves no deben ser administradas por el mismo
# rol que administra las bases de datos de producción. Separación de funciones (SoD).
resource "aws_kms_key" "backup_kms_key" {
  description             = "KMS CMK para cifrado de backups de nivel Confidencial y Restringido"
  deletion_window_in_days = 30 # Impide la destrucción instantánea de claves por un actor malicioso
  enable_key_rotation     = true

  tags = {
    Ambiente       = var.environment == "prod" ? "Producción" : "Laboratorio"
    Clasificacion  = "Restringido"
    MarcoNormativo = "Ley 25.326 / Res. AAIP 47/2018 / ISO 27001 A.8.24"
  }
}

# 2. Bucket S3 con Bloqueo de Objetos (WORM - Write Once Read Many)
# Justificación Técnica: Un atacante que comprometa credenciales administrativas
# NO PUEDE borrar ni sobreescribir los backups durante el período de retención.
resource "aws_s3_bucket" "immutable_backup_vault" {
  bucket        = "aseguradora-backups-inmutables-${var.environment}"
  force_destroy = false # Medida de protección contra eliminación accidental o maliciosa

  # Object Lock DEBE activarse al crear el bucket para habilitar WORM
  object_lock_enabled = true

  tags = {
    Ambiente      = var.environment == "prod" ? "Producción" : "Laboratorio"
    Clasificacion = "Restringido"
    Contenido     = "Dumps de Base de Datos (Pólizas y Salud)"
    Proposito     = "Plantilla de Mitigación Anti-Ransomware"
  }
}

# 3. Versionado Obligatorio (Prerrequisito para Object Lock)
resource "aws_s3_bucket_versioning" "backup_versioning" {
  bucket = aws_s3_bucket.immutable_backup_vault.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 4. Configuración de Retención Inmutable en Modo COMPLIANCE
# Modo COMPLIANCE: Ni siquiera la cuenta root de AWS puede modificar o acortar
# el período de retención antes de su expiración. Frena en seco a operadores de ransomware.
resource "aws_s3_bucket_object_lock_configuration" "backup_lock" {
  bucket = aws_s3_bucket.immutable_backup_vault.id

  rule {
    default_retention {
      mode = "COMPLIANCE"
      days = var.retention_days # Ventana de retención mínima garantizada para recuperación ante desastres
    }
  }
}

# 5. Cifrado en Reposo por Defecto con la Clave Dedicada
resource "aws_s3_bucket_server_side_encryption_configuration" "backup_encryption" {
  bucket = aws_s3_bucket.immutable_backup_vault.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.backup_kms_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true # Reduce costos de llamadas a KMS en transferencias masivas
  }
}

# 6. Bloqueo Absoluto de Acceso Público (S3 Public Access Block)
resource "aws_s3_bucket_public_access_block" "backup_public_block" {
  bucket = aws_s3_bucket.immutable_backup_vault.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 7. Política de Bucket: Denegación Explícita de Tráfico no Seguro (TLS 1.2+ Obligatorio)
resource "aws_s3_bucket_policy" "enforce_tls" {
  bucket = aws_s3_bucket.immutable_backup_vault.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.immutable_backup_vault.arn,
          "${aws_s3_bucket.immutable_backup_vault.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
