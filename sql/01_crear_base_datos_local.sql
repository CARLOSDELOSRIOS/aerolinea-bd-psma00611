/* =============================================================================
   01_crear_base_datos_local.sql
   Propósito : crear la base AerolineaDB en SQL Server LOCAL.
   Ámbito    : SOLO local. En Azure SQL Database la base se crea desde el portal
               o con Azure CLI (ver docs/05_azure/guia_azure.md); este script no
               se ejecuta allí.
   Seguridad : no destruye nada. Si la base existe, informa y no hace cambios.
               Para eliminarla use 99_DESTRUCTIVO_eliminar_base_local.sql.
   Decisiones:
     - Intercalación SQL_Latin1_General_CP1_CI_AS: es la predeterminada de Azure
       SQL Database. Fijarla evita diferencias de ordenación y comparación entre
       el entorno local (un Windows en español suele instalarse con
       Modern_Spanish_CI_AS) y la nube.
     - READ_COMMITTED_SNAPSHOT ON: Azure SQL Database lo activa por defecto.
       Activarlo localmente hace que la concurrencia se comporte igual en ambos
       entornos y que los lectores no bloqueen a los escritores.
   ============================================================================= */
SET NOCOUNT ON;

IF DB_ID(N'AerolineaDB') IS NOT NULL
BEGIN
    PRINT N'La base AerolineaDB ya existe. No se realizan cambios.';
END
ELSE
BEGIN
    CREATE DATABASE AerolineaDB COLLATE SQL_Latin1_General_CP1_CI_AS;
    PRINT N'Base AerolineaDB creada.';
END
GO

IF DB_ID(N'AerolineaDB') IS NOT NULL
   AND (SELECT is_read_committed_snapshot_on FROM sys.databases WHERE name = N'AerolineaDB') = 0
BEGIN
    -- Requiere que no haya otras conexiones activas a la base.
    ALTER DATABASE AerolineaDB SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
    PRINT N'READ_COMMITTED_SNAPSHOT activado.';
END
GO

SELECT name, collation_name, compatibility_level, is_read_committed_snapshot_on, recovery_model_desc
FROM sys.databases
WHERE name = N'AerolineaDB';
GO

/* Siguiente paso: en SSMS cambie la base activa a AerolineaDB (lista desplegable
   o USE AerolineaDB) y ejecute 02_esquemas_y_tablas.sql. Los scripts 02 en
   adelante no contienen USE para que sirvan también en Azure SQL Database. */
