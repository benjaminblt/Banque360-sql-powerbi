/* ============================================================
   PROJET : Banque 360
   FICHIER : 03_import_tables_raw.sql

   ÉTAPE DU FICHIER :

   Étape 5 sur 8
   Importer les données dans les tables raw

   AVANCEMENT :

   Étape 1 - Créer la base Banque360 : TERMINÉE
   Étape 2 - Créer les schémas de rangement : TERMINÉE
   Étape 3 - Examiner les colonnes des 7 CSV : TERMINÉE
   Étape 4 - Créer les tables adaptées : TERMINÉE
   Étape 5 - Importer les données dans les tables raw : EN COURS

   OBJECTIF :

   Importer les 7 fichiers CSV dans les 7 tables du schéma raw.

   COPIE DES CSV DANS DOCKER :

   Les fichiers CSV étaient stockés dans le dossier data du Mac.

   SQL Server fonctionne dans un conteneur Docker isolé.
   Il ne peut donc pas accéder directement aux fichiers du Mac.

   La commande suivante a été exécutée dans le Terminal du Mac,
   et non dans VS Code :

   docker cp "/Users/benjamin/Desktop/Recherche d’emploi /Cours Python, R, Excel, SQL, PowerBi/Projet SQL, PowerBi/data/." sqlserver:/var/opt/mssql/data/

   EXPLICATION DE LA COMMANDE :

   docker cp
   → copie des fichiers entre le Mac et un conteneur Docker.

   Premier chemin
   → emplacement du dossier data sur le Mac.

   Le point placé après data/
   → demande de copier tout le contenu du dossier.

   sqlserver:
   → nom du conteneur dans lequel fonctionne SQL Server.

   /var/opt/mssql/data/
   → dossier de destination à l’intérieur du conteneur.

   COMMANDE DE VÉRIFICATION UTILISÉE :

   docker exec sqlserver find /var/opt/mssql/data -maxdepth 1 -type f -name "*.csv" -print

   EXPLICATION :

   docker exec
   → exécute une commande à l’intérieur du conteneur.

   find
   → recherche les fichiers correspondant aux critères indiqués.

   -maxdepth 1
   → limite la recherche au dossier indiqué.

   -type f
   → recherche uniquement des fichiers.

   -name "*.csv"
   → recherche tous les fichiers dont le nom se termine par .csv.

   FICHIERS COPIÉS :

   - agences.csv
   - clients_raw.csv
   - credits_raw.csv
   - objectifs_agences.csv
   - produits.csv
   - remboursements_raw.csv
   - transactions_raw.csv

   PARCOURS :

   CSV sur le Mac
   → copie dans Docker avec docker cp
   → BULK INSERT
   → tables raw
   → contrôle du nombre de lignes
   → nettoyage dans staging

   PARTICULARITÉ DE SQL SERVER SOUS LINUX :

   L’option CODEPAGE = '65001' devait indiquer que les fichiers
   utilisaient l’encodage UTF-8.

   Cette option n’est pas prise en charge par SQL Server dans
   notre environnement Linux Docker.

   Elle est donc volontairement absente du script.

   Les éventuels caractères mal interprétés sont conservés
   dans raw, puis corrigés pendant le nettoyage dans staging.
   ============================================================ */


/* ------------------------------------------------------------
   USE sélectionne la base active.

   Toutes les instructions suivantes seront exécutées
   dans la base Banque360.
   ------------------------------------------------------------ */

USE Banque360;
GO

/* ============================================================
   1. VIDER LES TABLES AVANT LE NOUVEL IMPORT
   ============================================================ */

/* ------------------------------------------------------------
   TRUNCATE TABLE supprime toutes les lignes d’une table.

   La structure, les colonnes et le nom de la table
   sont conservés.

   Cette opération permet de relancer le script sans importer
   plusieurs fois les mêmes données.

   Les tables raw ne possèdent pas encore de relations SQL.
   Elles peuvent donc être vidées indépendamment.
   ------------------------------------------------------------ */

TRUNCATE TABLE raw.agences;
TRUNCATE TABLE raw.clients;
TRUNCATE TABLE raw.credits;
TRUNCATE TABLE raw.objectifs_agences;
TRUNCATE TABLE raw.produits;
TRUNCATE TABLE raw.remboursements;
TRUNCATE TABLE raw.transactions;
GO

/* ============================================================
   PARAMÈTRES COMMUNS AUX 7 IMPORTS
   ============================================================ */

/* ------------------------------------------------------------
   BULK INSERT

   Importe rapidement les lignes d’un fichier dans une table.

   FROM

   Indique le chemin du fichier source dans Docker.

   WITH

   Introduit les paramètres utilisés pour lire le fichier.

   FORMAT = 'CSV'

   Indique que le fichier est organisé au format CSV.

   FIRSTROW = 2

   Commence la lecture à la deuxième ligne.
   La première ligne contient les noms des colonnes.

   FIELDQUOTE = '"'

   Indique que les valeurs peuvent être entourées
   de guillemets doubles.

   ROWTERMINATOR = '0x0a'

   0x0a représente le caractère de saut de ligne.
   Chaque ligne du CSV devient une ligne de la table.

   TABLOCK

   Verrouille temporairement la table pendant l’import.
   Cela peut accélérer le chargement des données.
   ------------------------------------------------------------ */


/* ============================================================
   2. IMPORTER agences.csv DANS raw.agences
   ============================================================ */

BULK INSERT raw.agences
FROM '/var/opt/mssql/data/agences.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO


/* ============================================================
   3. IMPORTER clients_raw.csv DANS raw.clients
   ============================================================ */

BULK INSERT raw.clients
FROM '/var/opt/mssql/data/clients_raw.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO


/* ============================================================
   4. IMPORTER credits_raw.csv DANS raw.credits
   ============================================================ */

BULK INSERT raw.credits
FROM '/var/opt/mssql/data/credits_raw.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO


/* ============================================================
   5. IMPORTER objectifs_agences.csv
      DANS raw.objectifs_agences
   ============================================================ */

BULK INSERT raw.objectifs_agences
FROM '/var/opt/mssql/data/objectifs_agences.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO


/* ============================================================
   6. IMPORTER produits.csv DANS raw.produits
   ============================================================ */

BULK INSERT raw.produits
FROM '/var/opt/mssql/data/produits.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO


/* ============================================================
   7. IMPORTER remboursements_raw.csv
      DANS raw.remboursements
   ============================================================ */

BULK INSERT raw.remboursements
FROM '/var/opt/mssql/data/remboursements_raw.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO


/* ============================================================
   8. IMPORTER transactions_raw.csv
      DANS raw.transactions
   ============================================================ */

BULK INSERT raw.transactions
FROM '/var/opt/mssql/data/transactions_raw.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '0x0a',
    TABLOCK
);
GO


/* ============================================================
   9. VÉRIFIER LE NOMBRE DE LIGNES IMPORTÉES
   ============================================================ */

/* ------------------------------------------------------------
   COUNT(*)

   Compte toutes les lignes présentes dans une table.

   AS

   Donne un nom plus lisible à une colonne du résultat.

   UNION ALL

   Place les résultats de plusieurs SELECT les uns sous
   les autres.

   Contrairement à UNION, UNION ALL ne cherche pas à supprimer
   les éventuels doublons entre les résultats.

   Chaque ligne affichée correspond ici à une table raw.
   ------------------------------------------------------------ */

SELECT
    N'agences' AS table_raw,
    COUNT(*) AS nombre_lignes
FROM raw.agences

UNION ALL

SELECT
    N'clients',
    COUNT(*)
FROM raw.clients

UNION ALL

SELECT
    N'credits',
    COUNT(*)
FROM raw.credits

UNION ALL

SELECT
    N'objectifs_agences',
    COUNT(*)
FROM raw.objectifs_agences

UNION ALL

SELECT
    N'produits',
    COUNT(*)
FROM raw.produits

UNION ALL

SELECT
    N'remboursements',
    COUNT(*)
FROM raw.remboursements

UNION ALL

SELECT
    N'transactions',
    COUNT(*)
FROM raw.transactions;
GO

/* ============================================================
   10. VÉRIFIER LES CARACTÈRES ACCENTUÉS
   ============================================================ */

/* ------------------------------------------------------------
   TOP (10)

   Limite l’affichage aux 10 premières lignes.

   Ce contrôle permet de vérifier que les caractères comme
   é, è, à ou ô ont été correctement importés.

   Exemples attendus :
   - Chloé
   - Profession libérale
   ------------------------------------------------------------ */

SELECT TOP (10)
    prenom,
    nom,
    profession
FROM raw.clients;
GO

/* ============================================================
   11. AFFICHER UN APERÇU DES AGENCES
   ============================================================ */

/* ------------------------------------------------------------
   Cette dernière requête permet de vérifier visuellement
   que les colonnes de raw.agences sont correctement alignées.

   ORDER BY agence_id trie les agences selon leur identifiant.
   ------------------------------------------------------------ */

SELECT TOP (10)
    agence_id,
    nom_agence,
    ville,
    code_postal,
    departement,
    region,
    date_ouverture,
    effectif,
    categorie_agence
FROM raw.agences
ORDER BY agence_id;
GO