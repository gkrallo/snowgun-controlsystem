/* ============================================================================
   Skapar ett EGET laes-only-konto for bryggan mot GSSystems databaser
   (alla som borjar pa Live_). Version 15 november 2026.
   ----------------------------------------------------------------------------
   Varfor: bryggan ska aldrig anvanda det hardkodade GSS_Login (som kan ha
   skrivrattigheter) och framfor allt aldrig 'sa'. Det har kontot far ENBART
   lasa (db_datareader) - det kan inte andra nagot i databasen aven om vi ville.

   Kors EN gang pa styrdatorn, av nagon som ar sysadmin, nar vi tittat pa
   sondrapporten och vet att det behovs. Kor i SQL Server Management Studio
   (SSMS, med Query > SQLCMD Mode paslaget), eller via sqlcmd.

   Losenordet star INTE i filen. Det ges som variabeln LOSEN nar skriptet
   kors (28 november 2026). Forut skulle filen redigeras med det riktiga
   losenordet, och da kunde den checkas in av misstag. I PowerShell:

     $env:LOSEN = Read-Host "Losenord for snogrupp_ro"
     sqlcmd -S 127.0.0.1\SQLEXPRESS -E -i skapa-lasonly-konto.sql
     Remove-Item Env:LOSEN

   (-E = Windows-inloggning. Har du bara SQL-inloggning: -U <admin>, och
   sqlcmd fragar efter det losenordet.) sqlcmd laser variabeln ur miljon, sa
   losenordet hamnar varken i filen eller i kommandohistoriken.

   VIKTIGT:
   * Valj ett starkt losen, minst 12 tecken, utan apostrof (').
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

/* 0. Stanna om losenordet inte kommit med. Utan SQLCMD-lage byts variabeln
   inte ut, och da skulle sjalva texten dollar-parentes-LOSEN bli losenordet.
   NCHAR(36) ar dollartecknet, skrivet sa for att inte se ut som en variabel. */
IF N'$(LOSEN)' LIKE NCHAR(36) + N'(%' OR LEN(N'$(LOSEN)') < 12
BEGIN
    RAISERROR('Losenordet saknas eller ar kortare an 12 tecken. Satt variabeln LOSEN (se filens huvud). Inget ar andrat.', 16, 1);
    SET NOEXEC ON;
END
GO

/* 1. Login pa serverniva */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'snogrupp_ro')
BEGIN
    CREATE LOGIN [snogrupp_ro]
        WITH PASSWORD      = N'$(LOSEN)',
             CHECK_POLICY  = ON,
             DEFAULT_DATABASE = [Live_Snowstar];
    PRINT 'Login snogrupp_ro skapat.';
END
ELSE
    PRINT 'Login snogrupp_ro fanns redan - hoppar over.';
GO

/* 2-4. Anvandare med ENBART laesratt i var och en av GSSystems databaser.
   Sondrapporten 15 november 2026 visade att de ar 29, inte fyra: nulaget i
   Live_Snowstar, larmen i Live_event_SQL, texterna i Live_Language,
   summeringar i Live_stat_SQL, dygnsrapporter i Live_stat_SQL_rapport och
   sjalva statistiken i 24 halvmanadsdatabaser (Live_stat_novembre1SQL osv).
   Darfor alla databaser vars namn borjar pa Live_ - versionen fore 15
   november tog bara fyra och missade statistiken.

   sp_addrolemember anvands i stallet for ALTER ROLE ... ADD MEMBER; det
   fungerar pa styrdatorns SQL Server 2014. db_datareader = SELECT pa alla
   tabeller, inget mer. */
DECLARE @db sysname, @sql nvarchar(max);
DECLARE dbs CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.databases
    WHERE name LIKE N'Live[_]%'
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
SET NOEXEC OFF;
GO

/* ----------------------------------------------------------------------------
   OM NI NAGON GANG VILL TA BORT KONTOT IGEN: en USE/DROP USER per databas
   som borjar pa Live_ (29 stycken), och sist inloggningen:

   USE [Live_Snowstar];  DROP USER [snogrupp_ro];
   ... (samma for varje Live_-databas) ...
   USE [master];         DROP LOGIN [snogrupp_ro];
   -------------------------------------------------------------------------- */
