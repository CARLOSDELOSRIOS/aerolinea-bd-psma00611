/* =============================================================================
   99_DESTRUCTIVO_eliminar_base_local.sql
   *** OPERACIÓN DESTRUCTIVA E IRREVERSIBLE ***
   Propósito : eliminar por completo la base AerolineaDB LOCAL para reconstruirla
               desde cero (01 -> 09 y carga de datos).
   Ámbito    : SOLO SQL Server local. No ejecutar en Azure (allí se elimina el
               recurso desde el portal, previa decisión del equipo).
   Uso       : conéctese a master. Cambie @confirmar a 1 de forma deliberada.
   ============================================================================= */
SET NOCOUNT ON;
DECLARE @confirmar BIT = 0;   -- <<< cambiar a 1 para confirmar la eliminación

IF CAST(SERVERPROPERTY('EngineEdition') AS INT) = 5
    THROW 50999, N'Este script no se ejecuta en Azure SQL Database.', 1;
IF @confirmar = 0
BEGIN
    PRINT N'Confirmación no otorgada (@confirmar = 0). No se realizó ningún cambio.';
    RETURN;
END;
IF DB_ID(N'AerolineaDB') IS NULL
BEGIN
    PRINT N'La base AerolineaDB no existe.';
    RETURN;
END;
IF DB_NAME() = N'AerolineaDB'
    THROW 50998, N'Conéctese a master antes de eliminar la base.', 1;

ALTER DATABASE AerolineaDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE AerolineaDB;
PRINT N'Base AerolineaDB eliminada.';
