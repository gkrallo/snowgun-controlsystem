/* ============================================================================
   Skapar ett EGET laes-only-konto for bryggan mot Live_Snowstar.
   ----------------------------------------------------------------------------
   Varfor: bryggan ska aldrig anvanda det hardkodade GSS_Login (som kan ha
   skrivrattigheter) och framfor allt aldrig 'sa'. Det har kontot far ENBART
   lasa (db_datareader) - det kan inte andra nagot i databasen aven om vi ville.

   Kors EN gang pa styrdatorn, av nagon som ar sysadmin, nar vi tittat pa
   sondrapporten och vet att det behovs. Kor i SQL Server Management Studio
   (SSMS), eller via sqlcmd:

     sqlcmd -S 127.0.0.1\SQLEXPRESS -E -i skapa-lasonly-konto.sql

   (-E = Windows-inloggning. Har du bara SQL-inloggning: -U <admin> -P <losen>.)

   VIKTIGT:
   * Byt ut losenordet nedan mot ett riktigt, starkt losen INNAN du kor.
   * Det riktiga losenordet lagras bara i SECRETS.md (gitignore-ad) - aldrig
     i nagon fil som hamnar i git.
   * Scriptet skriver inte en rad driftdata - det skapar bara ett login,
     en anvandare och ger den laesratt.
   ========================================================================== */

USE [master];
GO

/* 1. Login pa serverniva (byt losenordet!) */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'snogrupp_ro')
BEGIN
    CREATE LOGIN [snogrupp_ro]
        WITH PASSWORD      = N'<SATT_ETT_STARKT_LOSEN_HAR>',
             CHECK_POLICY  = ON,
             DEFAULT_DATABASE = [Live_Snowstar];
    PRINT 'Login snogrupp_ro skapat.';
END
ELSE
    PRINT 'Login snogrupp_ro fanns redan - hoppar over.';
GO

/* 2. Anvandare i sjalva databasen, kopplad till login */
USE [Live_Snowstar];
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'snogrupp_ro')
BEGIN
    CREATE USER [snogrupp_ro] FOR LOGIN [snogrupp_ro];
    PRINT 'Anvandare snogrupp_ro skapad i Live_Snowstar.';
END
ELSE
    PRINT 'Anvandare snogrupp_ro fanns redan - hoppar over.';
GO

/* 3. Enbart laesratt. db_datareader = SELECT pa alla tabeller, inget mer. */
ALTER ROLE [db_datareader] ADD MEMBER [snogrupp_ro];
GO

/* 4. Kontroll - lista kontots roller (ska visa bara db_datareader) */
SELECT dp.name AS medlem, r.name AS roll
FROM sys.database_role_members m
JOIN sys.database_principals r  ON m.role_principal_id   = r.principal_id
JOIN sys.database_principals dp ON m.member_principal_id = dp.principal_id
WHERE dp.name = N'snogrupp_ro';
GO

/* ----------------------------------------------------------------------------
   OM NI NAGON GANG VILL TA BORT KONTOT IGEN (kor dessa, avkommenterade):

   USE [Live_Snowstar];
   DROP USER  IF EXISTS [snogrupp_ro];
   USE [master];
   DROP LOGIN IF EXISTS [snogrupp_ro];
   -------------------------------------------------------------------------- */
