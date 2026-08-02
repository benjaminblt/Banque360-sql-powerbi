/* ============================================================
   PROJET : Banque 360
   FICHIER : 01_creation_schemas.sql

   ÉTAPE ACTUELLE DU PROJET :

   Étape 2 sur 8
   Créer les schémas de rangement

   AVANCEMENT :

   Étape 1 - Créer la base Banque360 : TERMINÉE
   Étape 2 - Créer les schémas de rangement : EN COURS

   OBJECTIF DE CE FICHIER :

   Créer quatre schémas dans Banque360 afin d’organiser
   les données selon leur niveau de transformation.

   À QUOI SERT UN SCHÉMA ?

   Un schéma est une zone de rangement à l’intérieur
   d’une base de données.

   Il permet de classer les tables et les vues selon leur rôle.

   ORGANISATION DE Banque360 :

   Banque360 (la base)
   ├── raw (schéma 1)
   │   → données brutes importées depuis les CSV
   │
   ├── staging (schéma 2)
   │   → données nettoyées et standardisées
   │
   ├── mart (schéma 3)
   │   → tables organisées pour l’analyse
   │
   └── reporting (schéma 4)
       → vues finales et indicateurs destinés à Power BI

   LOGIQUE DU SCRIPT :

   1. Activer la base Banque360.
   2. Vérifier si chaque schéma existe déjà.
   3. Créer uniquement les schémas manquants.
   4. Afficher les quatre schémas pour vérifier leur création.
   ============================================================ */

/* ------------------------------------------------------------
   USE sélectionne la base active.

   Les schémas seront créés dans Banque360 et non dans master
   ou dans une autre base.
   ------------------------------------------------------------ */

USE Banque360;
GO

/* ============================================================
   1. CRÉER LE SCHÉMA raw
   ============================================================ */

/* ------------------------------------------------------------

   NOT EXISTS vérifie que la requête placée entre parenthèses
   ne renvoie aucune ligne.

   SELECT 1 sert uniquement à vérifier qu’une ligne existe.
   Le chiffre 1 n’a pas de signification particulière ici.

   FROM indique la source consultée.

   sys.schemas est une vue système contenant la liste
   des schémas présents dans la base.

   WHERE filtre cette liste pour rechercher le nom raw.

   N'raw' représente le texte raw en Unicode.
   ------------------------------------------------------------ */

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = N'raw'
)
BEGIN

    /* --------------------------------------------------------
       EXEC exécute une instruction SQL écrite sous forme de texte.

       CREATE SCHEMA crée une nouvelle zone de rangement.

       Le schéma raw accueillera les données brutes des CSV.
       -------------------------------------------------------- */

    EXEC(N'CREATE SCHEMA raw');

END;
GO

/* ============================================================
   2. CRÉER LE SCHÉMA staging
   ============================================================ */

-- staging contiendra les données nettoyées et standardisées.
IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = N'staging'
)
BEGIN
    EXEC(N'CREATE SCHEMA staging');
END;
GO

/* ============================================================
   3. CRÉER LE SCHÉMA mart
   ============================================================ */

-- mart contiendra les dimensions et les tables de faits.
IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = N'mart'
)
BEGIN
    EXEC(N'CREATE SCHEMA mart');
END;
GO

/* ============================================================
   4. CRÉER LE SCHÉMA reporting
   ============================================================ */

-- reporting contiendra les vues finales utilisées dans Power BI.
IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = N'reporting'
)
BEGIN
    EXEC(N'CREATE SCHEMA reporting');
END;
GO

/* ============================================================
   5. VÉRIFIER LES SCHÉMAS CRÉÉS
   ============================================================ */

/* ------------------------------------------------------------
   SELECT affiche les informations demandées.

   name est le vrai nom de la colonne dans sys.schemas.

   AS crée un alias plus lisible : nom_schema.

   IN permet de rechercher plusieurs valeurs sans écrire
   plusieurs conditions avec OR.

   ORDER BY trie le résultat par ordre alphabétique.
   ------------------------------------------------------------ */

SELECT
    name AS nom_schema
FROM sys.schemas
WHERE name IN (
    N'raw',
    N'staging',
    N'mart',
    N'reporting'
)
ORDER BY name; -- on range par ordre alphabétique
GO