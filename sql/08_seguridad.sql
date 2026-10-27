/* =============================================================================
   08_seguridad.sql
   Propósito : roles con privilegio mínimo y enmascaramiento dinámico de datos
               personales (Dynamic Data Masking, SQL Server 2016+ y Azure).
   Modelo de permisos:
     - Todos los esquemas pertenecen a dbo. Las vistas y procedimientos forman
       una cadena de propiedad ininterrumpida: quien recibe EXECUTE sobre un
       procedimiento puede modificar tablas a través de él sin tener permisos
       directos sobre ellas. Así la aplicación solo opera mediante reglas.
     - rol_analista     : lectura de vistas rpt (sin salarios ni datos de pago).
     - rol_ventas       : procedimientos de venta, pago y cancelación.
     - rol_operaciones  : procedimientos y lectura de operaciones.
     - rol_aplicacion   : cuenta técnica de la aplicación Python.
   Limitaciones: el enmascaramiento no es cifrado; un usuario con permisos de
   consulta ad hoc puede inferir valores. Para cifrado de columnas: Always
   Encrypted (trabajo futuro).
   Usuarios de demostración sin inicio de sesión: solo sirven para las pruebas
   de permisos (EXECUTE AS USER). En Azure se crean usuarios de Microsoft Entra
   (ver docs/05_azure/guia_azure.md).
   Reinicio  : idempotente.
   ============================================================================= */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
BEGIN
    RAISERROR(N'Conéctese a la base del proyecto antes de ejecutar este script.', 16, 1);
    SET NOEXEC ON;
END
GO

/* ------------------------------------------------------------------ roles */
IF DATABASE_PRINCIPAL_ID(N'rol_analista')    IS NULL CREATE ROLE rol_analista AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_ventas')      IS NULL CREATE ROLE rol_ventas AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_operaciones') IS NULL CREATE ROLE rol_operaciones AUTHORIZATION dbo;
IF DATABASE_PRINCIPAL_ID(N'rol_aplicacion')  IS NULL CREATE ROLE rol_aplicacion AUTHORIZATION dbo;
GO

-- Analista: solo vistas y procedimientos de reporte.
GRANT SELECT  ON SCHEMA::rpt TO rol_analista;
GRANT EXECUTE ON SCHEMA::rpt TO rol_analista;

-- Ventas: operaciones de venta mediante procedimientos y consulta de disponibilidad.
GRANT EXECUTE ON OBJECT::ven.usp_registrar_persona        TO rol_ventas;
GRANT EXECUTE ON OBJECT::ven.usp_registrar_cliente        TO rol_ventas;
GRANT EXECUTE ON OBJECT::ven.usp_consultar_disponibilidad TO rol_ventas;
GRANT EXECUTE ON OBJECT::ven.usp_emitir_tiquete           TO rol_ventas;
GRANT EXECUTE ON OBJECT::ven.usp_asignar_asiento          TO rol_ventas;
GRANT EXECUTE ON OBJECT::ven.usp_registrar_pago           TO rol_ventas;
GRANT EXECUTE ON OBJECT::ven.usp_resolver_pago            TO rol_ventas;
GRANT EXECUTE ON OBJECT::ven.usp_cancelar_tiquete         TO rol_ventas;
GRANT SELECT  ON OBJECT::rpt.v_vuelo                      TO rol_ventas;
GRANT SELECT  ON OBJECT::rpt.v_ocupacion_vuelo_cabina     TO rol_ventas;
GRANT SELECT  ON OBJECT::rpt.v_tiquete_financiero         TO rol_ventas;

-- Operaciones: procedimientos de operación y lectura de su esquema.
GRANT EXECUTE ON SCHEMA::ops TO rol_operaciones;
GRANT SELECT  ON SCHEMA::ops TO rol_operaciones;
GRANT SELECT  ON SCHEMA::rpt TO rol_operaciones;
GRANT EXECUTE ON OBJECT::ven.usp_registrar_abordaje TO rol_operaciones;
GRANT EXECUTE ON OBJECT::ven.usp_vencer_reservas    TO rol_operaciones;

-- Aplicación: ejecuta procedimientos y lee reportes y catálogos; no escribe tablas directamente.
GRANT EXECUTE ON SCHEMA::ven TO rol_aplicacion;
GRANT EXECUTE ON SCHEMA::ops TO rol_aplicacion;
GRANT EXECUTE ON SCHEMA::rpt TO rol_aplicacion;
GRANT SELECT  ON SCHEMA::rpt TO rol_aplicacion;
GRANT SELECT  ON SCHEMA::ref TO rol_aplicacion;
DENY  INSERT, UPDATE, DELETE ON SCHEMA::ven TO rol_aplicacion;
DENY  INSERT, UPDATE, DELETE ON SCHEMA::ops TO rol_aplicacion;
GO

/* ----------------------------------------------- enmascaramiento dinámico */
IF NOT EXISTS (SELECT 1 FROM sys.masked_columns WHERE object_id = OBJECT_ID(N'ven.persona') AND name = N'email_contacto')
    ALTER TABLE ven.persona ALTER COLUMN email_contacto ADD MASKED WITH (FUNCTION = 'email()');
IF NOT EXISTS (SELECT 1 FROM sys.masked_columns WHERE object_id = OBJECT_ID(N'ven.persona') AND name = N'telefono')
    ALTER TABLE ven.persona ALTER COLUMN telefono ADD MASKED WITH (FUNCTION = 'partial(0,"XXX-XXX-",4)');
-- Una columna con índice dependiente no admite ALTER COLUMN: se elimina el índice, se enmascara y se recrea.
IF NOT EXISTS (SELECT 1 FROM sys.masked_columns WHERE object_id = OBJECT_ID(N'ven.persona') AND name = N'numero_documento')
BEGIN
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'ix_persona_documento' AND object_id = OBJECT_ID(N'ven.persona'))
        DROP INDEX ix_persona_documento ON ven.persona;
    ALTER TABLE ven.persona ALTER COLUMN numero_documento ADD MASKED WITH (FUNCTION = 'partial(0,"XXXXXX",3)');
    CREATE NONCLUSTERED INDEX ix_persona_documento ON ven.persona (numero_documento) WHERE numero_documento IS NOT NULL;
END;
IF NOT EXISTS (SELECT 1 FROM sys.masked_columns WHERE object_id = OBJECT_ID(N'ven.persona') AND name = N'fecha_nacimiento')
    ALTER TABLE ven.persona ALTER COLUMN fecha_nacimiento ADD MASKED WITH (FUNCTION = 'default()');
IF NOT EXISTS (SELECT 1 FROM sys.masked_columns WHERE object_id = OBJECT_ID(N'ven.cliente') AND name = N'email_acceso')
    ALTER TABLE ven.cliente ALTER COLUMN email_acceso ADD MASKED WITH (FUNCTION = 'email()');
IF NOT EXISTS (SELECT 1 FROM sys.masked_columns WHERE object_id = OBJECT_ID(N'rh.empleado') AND name = N'salario_anual_usd')
    ALTER TABLE rh.empleado ALTER COLUMN salario_anual_usd ADD MASKED WITH (FUNCTION = 'default()');
GO

/* ------------------------------------- usuarios de demostración (pruebas) */
IF DATABASE_PRINCIPAL_ID(N'usr_demo_analista') IS NULL CREATE USER usr_demo_analista WITHOUT LOGIN;
IF DATABASE_PRINCIPAL_ID(N'usr_demo_aplicacion') IS NULL CREATE USER usr_demo_aplicacion WITHOUT LOGIN;
IF IS_ROLEMEMBER(N'rol_analista', N'usr_demo_analista') = 0 ALTER ROLE rol_analista ADD MEMBER usr_demo_analista;
IF IS_ROLEMEMBER(N'rol_aplicacion', N'usr_demo_aplicacion') = 0 ALTER ROLE rol_aplicacion ADD MEMBER usr_demo_aplicacion;
GO

IF NOT EXISTS (SELECT 1 FROM adm.registro_despliegue WHERE script = '08_seguridad')
    INSERT adm.registro_despliegue (script, descripcion) VALUES ('08_seguridad', N'Roles, permisos y enmascaramiento');
GO
SET NOEXEC OFF;
GO
