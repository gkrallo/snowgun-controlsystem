/* ============================================================================
   Skapar ett EGET laes-only-konto for bryggan mot GSSystems fyra databaser.
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
     en anvandare per databas och ger den laesratt.
   * Det har ar det ENDA vi nagonsin kor som andrar nagot i SQL Server.
     Det ar inte provkort mot en riktig server an - las sondrapporten forst
     (version, vilka databaser som finns) och ga igenom scriptet en gang till
     mot den innan det kors.
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

/* 2-4. Anvandare med ENBART laesratt i var och en av GSSystems databaser.
   Omgranskningen visade att de ar fyra, inte en: nulaget ligger i
   Live_Snowstar, larmen i Live_event_SQL, statistiken (med riktiga
   kolumnnamn) i Live_stat_SQL och texterna i Live_Language. En databas som
   inte finns hoppas over.

   sp_addrolemember anvands i stallet for ALTER ROLE ... ADD MEMBER, som
   forst kom i SQL Server 2012 - vi vet inte vilken version styrdatorn har
   forran sondrapporten ar last. db_datareader = SELECT pa alla tabeller,
   inget mer. */
DECLARE @db sysname, @sql nvarchar(max);
DECLARE dbs CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.databases
    WHERE name IN (N'Live_Snowstar', N'Live_stat_SQL', N'Live_event_SQL', N'Live_Language')
      AND state_desc = N'ONLINE';
OPEN dbs;
FETCH NEXT FROM dbs INTO @db;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'USE ' + QUOTENAME(@db) + N';
        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N''snogrupp_ro'')
            CREATE USER [snogrupp_ro] FOR LOGIN [snogrupp_ro];
        EXEC sp_addrolemember N''db_datareader'', N''snogrupp_ro'';
        /* Kontroll: ska visa bara db_datareader */
        SELECT DB_NAME() AS databas, dp.name AS medlem, r.name AS roll
        FROM sys.database_role_members m
        JOIN sys.database_principals r  ON m.role_principal_id   = r.principal_id
        JOIN sys.database_principals dp ON m.member_principal_id = dp.principal_id
        WHERE dp.name = N''snogrupp_ro'';';
    EXEC sp_executesql @sql;
    PRINT 'Laesratt satt i ' + @db + '.';
    FETCH NEXT FROM dbs INTO @db;
END
CLOSE dbs;
DEALLOCATE dbs;
GO

/* ----------------------------------------------------------------------------
   OM NI NAGON GANG VILL TA BORT KONTOT IGEN (kor dessa, avkommenterade,
   en USE/DROP USER per databas och sist inloggningen):

   USE [Live_Snowstar];  DROP USER [snogrupp_ro];
   USE [Live_stat_SQL];  DROP USER [snogrupp_ro];
   USE [Live_event_SQL]; DROP USER [snogrupp_ro];
   USE [Live_Language];  DROP USER [snogrupp_ro];
   USE [master];         DROP LOGIN [snogrupp_ro];
   -------------------------------------------------------------------------- */
