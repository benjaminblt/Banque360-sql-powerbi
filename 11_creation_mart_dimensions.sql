/* ============================================================
   PROJET : Banque 360
   FICHIER : 11_creation_mart_dimensions.sql

   ÉTAPE DU PROJET :

   Étape 7 sur 8
   Construire le modèle analytique dans le schéma mart

   PARTIE DU FICHIER :

   Étape 7, partie 1 sur 3
   Créer les dimensions du modèle en étoile

   AVANCEMENT :

   Étapes 1 à 6 : TERMINÉES
   Étape 7 : EN COURS

   ORDRE D’EXÉCUTION :

   11_creation_mart_dimensions.sql
   → crée les dimensions ;

   12_creation_mart_faits.sql
   → crée les tables de faits ;

   13_controles_modele_mart.sql
   → contrôle le modèle complet.

   DIMENSIONS CRÉÉES :

   - mart.dim_date
   - mart.dim_agence
   - mart.dim_client
   - mart.dim_produit

   ============================================================

   À QUOI SERT UNE DIMENSION ?

   Une dimension contient les informations descriptives
   utilisées pour filtrer, regrouper et analyser les mesures.

   Exemples :

   mart.dim_date
   → analyser les résultats par jour, mois, trimestre ou année ;

   mart.dim_agence
   → analyser les résultats par agence, ville, département
     ou région ;

   mart.dim_client
   → analyser les résultats par segment, profession, statut
     ou niveau de risque ;

   mart.dim_produit
   → analyser les résultats par produit, famille ou univers.

   Les dimensions décrivent donc le contexte des événements.

   Les événements et les valeurs numériques seront stockés
   dans les tables de faits créées par le fichier 12.

   ============================================================

   MODÈLE EN ÉTOILE DU PROJET :

                              mart.dim_date
                                    │
             ┌──────────────────────┼──────────────────────┐
             │                      │                      │
    fact_transactions         fact_credits       fact_remboursements
             │                      │                      │
       ┌─────┼─────┐          ┌─────┴─────┐          ┌─────┴─────┐
       │     │     │          │           │          │           │
  dim_client │ dim_produit  dim_client  dim_agence  dim_client dim_agence
             │
        dim_agence


   dim_date ───── fact_objectifs_agences ───── dim_agence

   dim_date ───── fact_entrees_clients ───── dim_client
                                               │
                                          dim_agence

   ============================================================

   CLÉ MÉTIER ET CLÉ TECHNIQUE :

   Une clé métier vient du système source.

   Exemples :

   agence_id = A001
   client_id = C000001
   produit_id = P001

   Une clé technique est créée uniquement pour le modèle
   analytique.

   Exemples :

   agence_key = 1
   client_key = 125
   produit_key = 4

   Les tables de faits utiliseront les clés techniques entières
   pour créer leurs relations avec les dimensions.

   Avantages :

   - relations plus légères ;
   - modèle plus performant ;
   - indépendance vis-à-vis des identifiants sources ;
   - possibilité de gérer les valeurs inconnues ;
   - structure adaptée à Power BI.

   /* ============================================================
   MEMBRE INCONNU
   ============================================================ */

/* --------------------------------------------------------
   Chaque dimension possède une ligne spéciale dont la clé
   technique vaut 0.

   Cette ligne représente une valeur absente, invalide
   ou introuvable.

   Exemples :

   - une transaction avec une date impossible à interpréter ;
   - une transaction sans produit associé ;
   - une référence vers une agence inexistante (ex. A999) ;
   - une référence vers un client inconnu.

   SANS ce mécanisme :

   Une table de faits contenant une clé étrangère invalide
   provoquerait une erreur de contrainte, ou obligerait
   à supprimer la ligne de fait concernée pour préserver
   l’intégrité référentielle.

   AVEC ce mécanisme :

   La table de faits utilise simplement la clé 0 au lieu
   de planter ou de perdre la ligne.

   Avantages :

   - aucune donnée n’est perdue, même en cas de référence
     défaillante ;
   - toutes les lignes restent présentes dans le modèle
     analytique ;
   - les cas « Inconnu » peuvent être filtrés ou isolés
     dans Power BI pour investiguer la qualité des données
     source ;
   - le modèle reste robuste face à des données source
     imparfaites.

   Exemple d’utilisation dans une table de faits :

   agence_key = 0
   → agence inconnue.
   -------------------------------------------------------- */
   PARTICULARITÉ DE CE SCRIPT :

   Il supprime d’abord les anciennes tables de faits,
   puis les anciennes dimensions, avant de reconstruire
   le modèle.

   Il utilise également une transaction :

   - si tout fonctionne, COMMIT valide le traitement ;
   - si une erreur survient, ROLLBACK annule tout ;
   - aucune dimension partiellement créée n’est conservée.
   ============================================================ */


/* ============================================================
   EN CAS DE PROBLÈME DANS VS CODE
   ============================================================ */

/* 1. Exécuter le fichier avec Run.
   2. Lire la première véritable erreur « Msg ».
   3. Si le script fonctionne mais que VS Code reste rouge :
      ⌘ + ⇧ + P
      → MSSQL: Refresh IntelliSense Cache.
   4. Vérifier que la base sélectionnée est Banque360.
*/


/* ============================================================
   0. SÉLECTIONNER LA BASE DE DONNÉES
   ============================================================ */

/* USE indique à SQL Server dans quelle base le script
   doit être exécuté. */
USE Banque360;
GO


/* ============================================================
   1. CONFIGURER ET SÉCURISER L’EXÉCUTION
   ============================================================ */

/* ------------------------------------------------------------
   SET NOCOUNT ON empêche SQL Server d’afficher un message
   « X lignes affectées » après chaque instruction.

   Les tableaux de résultats restent visibles.
   ------------------------------------------------------------ */
SET NOCOUNT ON;


/* ------------------------------------------------------------
   SET XACT_ABORT ON indique à SQL Server d’annuler
   automatiquement la transaction en cas d’erreur grave.

   Cela renforce la sécurité du script.
   ------------------------------------------------------------ */
SET XACT_ABORT ON;


/* ============================================================
   2. DÉMARRER LE BLOC DE TRAITEMENT
   ============================================================ */

/* ------------------------------------------------------------
   BEGIN TRY contient les instructions que SQL Server
   doit tenter d’exécuter.

   BEGIN CATCH, situé à la fin du script, sera utilisé
   uniquement si une erreur apparaît.
   ------------------------------------------------------------ */
BEGIN TRY


    /* ========================================================
       2.1. VÉRIFIER LES SCHÉMAS NÉCESSAIRES
       ======================================================== */

    /* --------------------------------------------------------
       SCHEMA_ID recherche un schéma dans la base.

       Si le résultat est NULL, le schéma n’existe pas.

       THROW arrête alors le script avec un message précis.
       -------------------------------------------------------- */
    IF SCHEMA_ID(N'staging') IS NULL
        THROW 50001,
              N'Le schéma staging est absent. Exécuter les étapes précédentes.',
              1;

    IF SCHEMA_ID(N'mart') IS NULL
        THROW 50002,
              N'Le schéma mart est absent. Exécuter le fichier de création des schémas.',
              1;


    /* ========================================================
       2.2. VÉRIFIER LES TABLES STAGING NÉCESSAIRES
       ======================================================== */

    /* --------------------------------------------------------
       OBJECT_ID recherche un objet dans la base.

       N'U' signifie que l’objet attendu doit être
       une table utilisateur.

       Les sept tables staging doivent exister avant de pouvoir
       construire le modèle analytique.
       -------------------------------------------------------- */
    IF OBJECT_ID(N'staging.agences', N'U') IS NULL
        THROW 50003,
              N'La table staging.agences est absente.',
              1;

    IF OBJECT_ID(N'staging.clients', N'U') IS NULL
        THROW 50004,
              N'La table staging.clients est absente.',
              1;

    IF OBJECT_ID(N'staging.credits', N'U') IS NULL
        THROW 50005,
              N'La table staging.credits est absente.',
              1;

    IF OBJECT_ID(N'staging.objectifs_agences', N'U') IS NULL
        THROW 50006,
              N'La table staging.objectifs_agences est absente.',
              1;

    IF OBJECT_ID(N'staging.produits', N'U') IS NULL
        THROW 50007,
              N'La table staging.produits est absente.',
              1;

    IF OBJECT_ID(N'staging.remboursements', N'U') IS NULL
        THROW 50008,
              N'La table staging.remboursements est absente.',
              1;

    IF OBJECT_ID(N'staging.transactions', N'U') IS NULL
        THROW 50009,
              N'La table staging.transactions est absente.',
              1;


    /* ========================================================
       2.3. DÉMARRER LA TRANSACTION
       ======================================================== */

    /* --------------------------------------------------------
       BEGIN TRANSACTION regroupe toutes les opérations suivantes
       dans une seule unité de travail.

       La transaction comprendra :

       - la suppression de l’ancien modèle ;
       - la création des dimensions ;
       - le chargement des données ;
       - la création des index ;
       - les contrôles de cohérence.
       -------------------------------------------------------- */
    BEGIN TRANSACTION;


    /* ========================================================
       3. SUPPRIMER L’ANCIEN MODÈLE MART
       ======================================================== */

    /* --------------------------------------------------------
       POURQUOI SUPPRIMER LES FAITS AVANT LES DIMENSIONS ?

       Les tables de faits contiennent des clés étrangères
       vers les dimensions.

       Exemple :

       fact_transactions[client_key]
       → dim_client[client_key]

       SQL Server interdit la suppression d’une dimension
       tant qu’une table de faits la référence.

       Les tables de faits doivent donc être supprimées
       en premier.
       -------------------------------------------------------- */

    DROP TABLE IF EXISTS mart.fact_entrees_clients;
    DROP TABLE IF EXISTS mart.fact_objectifs_agences;
    DROP TABLE IF EXISTS mart.fact_remboursements;
    DROP TABLE IF EXISTS mart.fact_credits;
    DROP TABLE IF EXISTS mart.fact_transactions;


    /* --------------------------------------------------------
       Une fois les faits supprimés, les dimensions peuvent
       être supprimées sans conflit de clé étrangère.

       DROP TABLE IF EXISTS :

       - vérifie si la table existe ;
       - la supprime uniquement si elle existe ;
       - ne génère pas d’erreur si elle est absente.

       La suppression d’une table supprime automatiquement :

       - ses lignes ;
       - ses index ;
       - sa clé primaire ;
       - ses contraintes.
       -------------------------------------------------------- */

    DROP TABLE IF EXISTS mart.dim_produit;
    DROP TABLE IF EXISTS mart.dim_client;
    DROP TABLE IF EXISTS mart.dim_agence;
    DROP TABLE IF EXISTS mart.dim_date;


    /* ========================================================
       4. CRÉER mart.dim_date
       ======================================================== */

    /* --------------------------------------------------------
       GRAIN DE LA DIMENSION :

       Une ligne représente une journée du calendrier.

       Exemple :

       15 juillet 2026
       → une seule ligne dans mart.dim_date.

       Cette dimension permettra d’utiliser les mêmes années,
       mois et trimestres pour toutes les tables de faits.
       -------------------------------------------------------- */

    CREATE TABLE mart.dim_date
    (
        /* ----------------------------------------------------
           Clé primaire de la dimension.
           Une clé primaire identifie de manière unique chaque ligne d'une table
           Une clé étrangère référence la clé primaire d'une autre table

           La date est transformée au format numérique AAAAMMJJ.

           Exemple :

           15 juillet 2026
           → 20260715.
           ---------------------------------------------------- */
        date_key INT NOT NULL,

        /* Véritable date SQL. */
        date_complete DATE NULL,

        /* Numéro du jour dans le mois : de 1 à 31. */
        jour_numero TINYINT NULL, -- Plage : Non signé (UNSIGNED) : 0 à 255, Signé : -128 à 127

        /* Numéro du jour dans la semaine :

           lundi    = 1
           mardi    = 2
           mercredi = 3
           jeudi    = 4
           vendredi = 5
           samedi   = 6
           dimanche = 7. */
        jour_semaine_numero TINYINT NULL,

        /* Nom français du jour. */
        nom_jour NVARCHAR(20) NULL,

        /* Numéro ISO de la semaine : de 1 à 53. */
        semaine_iso TINYINT NULL,

        /* Numéro du mois : de 1 à 12. */
        mois_numero TINYINT NULL,

        /* Nom français du mois. */
        nom_mois NVARCHAR(20) NULL,

        /* Numéro du trimestre : de 1 à 4. */
        trimestre_numero TINYINT NULL,

        /* Libellé du trimestre : T1, T2, T3 ou T4. */
        trimestre_libelle NVARCHAR(2) NULL,

        /* Numéro du semestre : 1 ou 2. */
        semestre_numero TINYINT NULL,

        /* Année civile, par exemple 2026. */
        annee SMALLINT NULL, -- Non signé : 0 à 65 535, Signé : -32 768 à 32 767

        /* ----------------------------------------------------
           Combinaison numérique année et mois.

           Exemple :

           juillet 2026
           → 202607.

           Cette colonne servira notamment à trier les mois
           chronologiquement dans Power BI.
           ---------------------------------------------------- */
        annee_mois INT NULL,

        /* Version textuelle de l’année et du mois.

           Exemple : 2026-07. */
        annee_mois_libelle CHAR(7) NULL,

        /* Premier jour du mois.

           Exemple :

           15 juillet 2026
           → 1er juillet 2026. */
        mois_debut DATE NULL,

        /* Indicateur binaire :

           1 → samedi ou dimanche ;
           0 → jour de semaine. */
        est_weekend BIT NULL,

        /* Date présentée au format français JJ/MM/AAAA. */
        libelle_date NVARCHAR(20) NULL,

        /* ----------------------------------------------------
           La clé primaire garantit que date_key est :

           - obligatoire ;
           - unique ;
           - indexée.
           ---------------------------------------------------- */
        CONSTRAINT PK_dim_date
            PRIMARY KEY (date_key)
    );


    /* ========================================================
       4.1. INSÉRER LE MEMBRE DATE INCONNUE
       ======================================================== */

    /* --------------------------------------------------------
       date_key = 0 représente une date :

       - absente ;
       - impossible ;
       - non convertible ;
       - non retrouvée dans le calendrier.

       Les autres colonnes sont NULL ou portent un libellé
       explicite « Inconnu ».
       -------------------------------------------------------- */

    INSERT INTO mart.dim_date
    (
        date_key,
        date_complete,
        jour_numero,
        jour_semaine_numero,
        nom_jour,
        semaine_iso,
        mois_numero,
        nom_mois,
        trimestre_numero,
        trimestre_libelle,
        semestre_numero,
        annee,
        annee_mois,
        annee_mois_libelle,
        mois_debut,
        est_weekend,
        libelle_date
    )
    VALUES
    (
        0,
        NULL,
        NULL,
        NULL,
        N'Inconnu',
        NULL,
        NULL,
        N'Inconnu',
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        N'Date inconnue'
    );


    /* ========================================================
       4.2. DÉTERMINER LA PÉRIODE DU CALENDRIER
       ======================================================== */

    /* --------------------------------------------------------
       DECLARE crée des variables temporaires.

       @date_min stockera la date la plus ancienne.

       @date_max stockera la date la plus récente.
       -------------------------------------------------------- */
    DECLARE @date_min DATE;
    DECLARE @date_max DATE;


    /* --------------------------------------------------------
       Toutes les colonnes de dates utiles sont regroupées
       dans un résultat temporaire appelé toutes_dates.

       UNION ALL empile les résultats sans supprimer
       les éventuelles dates répétées.

       UNION ALL est plus rapide que UNION, car aucun travail
       de dédoublonnage n’est nécessaire.

       MIN recherche la date la plus ancienne.

       MAX recherche la date la plus récente.
       -------------------------------------------------------- */
    SELECT
        @date_min = MIN(date_analyse),
        @date_max = MAX(date_analyse)

    FROM
    (
        /* Date d’entrée des clients dans la banque. */
        SELECT date_entree AS date_analyse
        FROM staging.clients

        UNION ALL

        /* Date des transactions.

           CAST retire l’heure pour conserver uniquement la date. */
        SELECT CAST(date_transaction AS DATE)
        FROM staging.transactions

        UNION ALL

        /* Date d’octroi des crédits. */
        SELECT date_octroi
        FROM staging.credits

        UNION ALL

        /* Date de fin prévue des crédits. */
        SELECT date_fin_prevue
        FROM staging.credits

        UNION ALL

        /* Date des échéances de remboursement. */
        SELECT date_echeance
        FROM staging.remboursements

        UNION ALL

        /* Date réelle des paiements. */
        SELECT date_paiement
        FROM staging.remboursements

        UNION ALL

        /* Mois des objectifs des agences. */
        SELECT mois
        FROM staging.objectifs_agences

    ) AS toutes_dates

    /* Les dates NULL ne doivent pas définir la période. */
    WHERE date_analyse IS NOT NULL;


    /* --------------------------------------------------------
       COALESCE renvoie la première valeur non NULL.

       Si toutes les tables étaient exceptionnellement vides :

       @date_min prendrait le 1er janvier 2021 ;
       @date_max prendrait le 31 décembre 2026.

       Ces valeurs de secours évitent de créer un calendrier vide.
       -------------------------------------------------------- */
    SET @date_min =
        COALESCE(
            @date_min,
            CONVERT(DATE, '20210101', 112)
        );

    SET @date_max =
        COALESCE(
            @date_max,
            CONVERT(DATE, '20261231', 112)
        );


    /* ========================================================
       4.3. GÉNÉRER UNE LIGNE PAR JOUR
       ======================================================== */

    /* --------------------------------------------------------
       Une CTE récursive est un résultat temporaire
       qui se réutilise lui-même.

       ANCRE :

       SELECT @date_min
       → crée la première date.

       RÉCURSION :

       DATEADD(DAY, 1, date_complete)
       → ajoute un jour à la date précédente.

       ARRÊT :

       WHERE date_complete < @date_max
       → arrête la génération à la date maximale.

       Le point-virgule placé avant WITH garantit que
       l’instruction précédente est bien terminée.
       -------------------------------------------------------- */

    ;WITH calendrier AS
    (
        /* Première date du calendrier. */
        SELECT
            @date_min AS date_complete

        UNION ALL

        /* Ajoute progressivement une journée. */
        SELECT
            DATEADD(
                DAY,
                1,
                date_complete
            )

        FROM calendrier

        /* La récursion s’arrête après la date maximale. */
        WHERE date_complete < @date_max
    )

    INSERT INTO mart.dim_date
    (
        date_key,
        date_complete,
        jour_numero,
        jour_semaine_numero,
        nom_jour,
        semaine_iso,
        mois_numero,
        nom_mois,
        trimestre_numero,
        trimestre_libelle,
        semestre_numero,
        annee,
        annee_mois,
        annee_mois_libelle,
        mois_debut,
        est_weekend,
        libelle_date
    )
    SELECT
        /* ----------------------------------------------------
           Style 112 :

           2026-07-15
           → texte 20260715.

           Le résultat est ensuite converti en INT.
           ---------------------------------------------------- */
        CONVERT(
            INT,
            CONVERT(
                CHAR(8),
                date_complete,
                112
            )
        ) AS date_key,

        /* Date complète. */
        date_complete,

        /* Extrait le numéro du jour dans le mois. */
        DAY(date_complete) AS jour_numero,

        /* ----------------------------------------------------
           Le 1er janvier 1900 était un lundi.

           DATEDIFF calcule le nombre de jours écoulés
           depuis cette date de référence.

           Le modulo % 7 produit une valeur de 0 à 6.

           L’ajout de 1 produit une valeur de 1 à 7.

           Cette méthode ne dépend pas du paramètre DATEFIRST
           configuré sur SQL Server.
           ---------------------------------------------------- */
        (
            DATEDIFF(
                DAY,
                CONVERT(DATE, '19000101', 112),
                date_complete
            ) % 7
        ) + 1 AS jour_semaine_numero,

        /* Traduit le numéro du jour en nom français. */
        CASE
            (
                DATEDIFF(
                    DAY,
                    CONVERT(DATE, '19000101', 112),
                    date_complete
                ) % 7
            ) + 1

            WHEN 1 THEN N'Lundi'
            WHEN 2 THEN N'Mardi'
            WHEN 3 THEN N'Mercredi'
            WHEN 4 THEN N'Jeudi'
            WHEN 5 THEN N'Vendredi'
            WHEN 6 THEN N'Samedi'
            WHEN 7 THEN N'Dimanche'
        END AS nom_jour,

        /* Numéro de semaine selon la norme ISO. */
        DATEPART(
            ISO_WEEK,
            date_complete
        ) AS semaine_iso,

        /* Numéro du mois. */
        MONTH(date_complete) AS mois_numero,

        /* Traduit le numéro du mois en nom français. */
        CASE MONTH(date_complete)
            WHEN 1  THEN N'Janvier'
            WHEN 2  THEN N'Février'
            WHEN 3  THEN N'Mars'
            WHEN 4  THEN N'Avril'
            WHEN 5  THEN N'Mai'
            WHEN 6  THEN N'Juin'
            WHEN 7  THEN N'Juillet'
            WHEN 8  THEN N'Août'
            WHEN 9  THEN N'Septembre'
            WHEN 10 THEN N'Octobre'
            WHEN 11 THEN N'Novembre'
            WHEN 12 THEN N'Décembre'
        END AS nom_mois,

        /* Extrait le trimestre de la date. */
        DATEPART(
            QUARTER,
            date_complete
        ) AS trimestre_numero,

        /* Construit T1, T2, T3 ou T4. */
        CONCAT(
            N'T',
            DATEPART(
                QUARTER,
                date_complete
            )
        ) AS trimestre_libelle,

        /* Janvier à juin = semestre 1.
           Juillet à décembre = semestre 2. */
        CASE
            WHEN MONTH(date_complete) <= 6
                THEN 1
            ELSE 2
        END AS semestre_numero,

        /* Extrait l’année. */
        YEAR(date_complete) AS annee,

        /* Exemple : 2026 × 100 + 7 = 202607. */
        YEAR(date_complete) * 100
            + MONTH(date_complete)
            AS annee_mois,

        /* Style 120 avec CHAR(7) produit AAAA-MM. */
        CONVERT(
            CHAR(7),
            date_complete,
            120
        ) AS annee_mois_libelle,

        /* Reconstruit le premier jour du mois. */
        DATEFROMPARTS(
            YEAR(date_complete),
            MONTH(date_complete),
            1
        ) AS mois_debut,

        /* Samedi et dimanche deviennent 1. */
        CASE
            WHEN
            (
                DATEDIFF(
                    DAY,
                    CONVERT(DATE, '19000101', 112),
                    date_complete
                ) % 7
            ) + 1 IN (6, 7)

            THEN 1
            ELSE 0
        END AS est_weekend,

        /* Style 103 produit le format français JJ/MM/AAAA. */
        CONVERT(
            NVARCHAR(10),
            date_complete,
            103
        ) AS libelle_date

    FROM calendrier

    /* --------------------------------------------------------
       SQL Server limite normalement les CTE récursives
       à 100 répétitions.

       MAXRECURSION 0 retire cette limite.

       Cette option est nécessaire pour générer plusieurs
       années de calendrier.
       -------------------------------------------------------- */
    OPTION (MAXRECURSION 0);


    /* ========================================================
       4.4. CRÉER UN INDEX UNIQUE SUR LA DATE
       ======================================================== */

    /* --------------------------------------------------------
       date_key est déjà unique grâce à la clé primaire.

       Cet index garantit également que date_complete
       ne peut apparaître qu’une seule fois.

       WHERE date_complete IS NOT NULL crée un index filtré :

       - les dates réelles sont contrôlées ;
       - la ligne inconnue avec date_complete = NULL est exclue.
       -------------------------------------------------------- */
    CREATE UNIQUE INDEX UX_dim_date_date_complete
        ON mart.dim_date(date_complete)
        WHERE date_complete IS NOT NULL;


    /* ========================================================
       5. CRÉER mart.dim_agence
       ======================================================== */

    /* --------------------------------------------------------
       GRAIN :

       Une ligne représente une agence bancaire.

       SOURCE :

       staging.agences.

       CLÉ MÉTIER :

       agence_id.

       CLÉ TECHNIQUE :

       agence_key.
       -------------------------------------------------------- */

    CREATE TABLE mart.dim_agence
    (
        /* ----------------------------------------------------
           IDENTITY(1,1) génère automatiquement :

           1, 2, 3, 4...

           La clé 0 sera insérée manuellement pour représenter
           l’agence inconnue.
           ---------------------------------------------------- */
        agence_key INT IDENTITY(1,1) NOT NULL,

        /* Identifiant métier de l’agence. */
        agence_id NVARCHAR(20) NOT NULL,

        /* Nom commercial de l’agence. */
        nom_agence NVARCHAR(150) NULL,

        /* Ville de l’agence. */
        ville NVARCHAR(100) NULL,

        /* Le code postal reste du texte afin de conserver
           les éventuels zéros au début. */
        code_postal NVARCHAR(10) NULL,

        /* Département de l’agence. */
        departement NVARCHAR(100) NULL,

        /* Région de l’agence. */
        region NVARCHAR(100) NULL,

        /* Date d’ouverture. */
        date_ouverture DATE NULL,

        /* Nombre de salariés. */
        effectif INT NULL,

        /* Catégorie : Urbaine, Périurbaine ou Rurale. */
        categorie_agence NVARCHAR(100) NULL,

        /* Clé primaire technique. */
        CONSTRAINT PK_dim_agence
            PRIMARY KEY (agence_key)
    );


    /* ========================================================
       5.1. INSÉRER L’AGENCE INCONNUE
       ======================================================== */

    /* --------------------------------------------------------
       Une colonne IDENTITY est normalement remplie
       automatiquement.

       SET IDENTITY_INSERT ... ON permet temporairement
       de fournir manuellement agence_key = 0.

       Il doit être désactivé immédiatement après l’insertion.
       -------------------------------------------------------- */
    SET IDENTITY_INSERT mart.dim_agence ON;

    INSERT INTO mart.dim_agence
    (
        agence_key,
        agence_id,
        nom_agence,
        ville,
        code_postal,
        departement,
        region,
        date_ouverture,
        effectif,
        categorie_agence
    )
    VALUES
    (
        0,
        N'INCONNUE',
        N'Agence inconnue',
        N'Inconnue',
        NULL,
        N'Inconnu',
        N'Inconnue',
        NULL,
        NULL,
        N'Inconnue'
    );

    SET IDENTITY_INSERT mart.dim_agence OFF;


    /* ========================================================
       5.2. CHARGER LES AGENCES RÉELLES
       ======================================================== */

    /* --------------------------------------------------------
       agence_key n’apparaît pas dans l’INSERT.

       SQL Server le génère automatiquement grâce à IDENTITY.

       Les 25 agences devraient recevoir les clés techniques
       de 1 à 25.
       -------------------------------------------------------- */
    INSERT INTO mart.dim_agence
    (
        agence_id,
        nom_agence,
        ville,
        code_postal,
        departement,
        region,
        date_ouverture,
        effectif,
        categorie_agence
    )
    SELECT
        agence_id,
        nom_agence,
        ville,
        code_postal,
        departement,
        region,
        date_ouverture,
        effectif,
        categorie_agence

    FROM staging.agences;


    /* ========================================================
       5.3. CRÉER L’INDEX DE LA CLÉ MÉTIER
       ======================================================== */

    /* --------------------------------------------------------
       L’index UNIQUE garantit qu’un agence_id ne peut être
       présent qu’une seule fois dans la dimension.

       Il accélère également les jointures utilisées pour
       retrouver agence_key à partir d’agence_id.
       -------------------------------------------------------- */
    CREATE UNIQUE INDEX UX_dim_agence_agence_id
        ON mart.dim_agence(agence_id);


    /* ========================================================
       6. CRÉER mart.dim_client
       ======================================================== */

    /* --------------------------------------------------------
       GRAIN :

       Une ligne représente un client unique.

       SOURCE :

       staging.clients.

       CLÉ MÉTIER :

       client_id.

       CLÉ TECHNIQUE :

       client_key.
       -------------------------------------------------------- */

    CREATE TABLE mart.dim_client
    (
        /* Clé technique générée automatiquement. */
        client_key INT IDENTITY(1,1) NOT NULL,

        /* Identifiant métier du client. */
        client_id NVARCHAR(20) NOT NULL,

        /* Prénom du client. */
        prenom NVARCHAR(100) NULL,

        /* Nom du client. */
        nom NVARCHAR(100) NULL,

        /* Prénom et nom réunis pour faciliter les affichages. */
        nom_complet NVARCHAR(220) NULL,

        /* Date de naissance. */
        date_naissance DATE NULL,

        /* Date d’entrée dans la banque. */
        date_entree DATE NULL,

        /* Particulier, Professionnel ou Association. */
        segment NVARCHAR(100) NULL,

        /* Profession du client. */
        profession NVARCHAR(150) NULL,

        /* Revenu mensuel nettoyé. */
        revenu_mensuel DECIMAL(12,2) NULL,

        /* Score initial compris entre 0 et 100. */
        score_risque_initial INT NULL,

        /* ----------------------------------------------------
           Identifiant métier de l’agence de rattachement.

           Cette colonne reste un attribut descriptif.

           Aucune clé étrangère vers dim_agence n’est créée
           dans dim_client.

           Cela évite une relation entre deux dimensions
           et conserve un véritable modèle en étoile.
           ---------------------------------------------------- */
        agence_rattachement_id NVARCHAR(20) NULL,

        /* Ville du client. */
        ville NVARCHAR(100) NULL,

        /* Code postal conservé comme texte. */
        code_postal NVARCHAR(10) NULL,

        /* Adresse électronique. */
        email NVARCHAR(255) NULL,

        /* Actif, Inactif ou Clos. */
        statut_client NVARCHAR(50) NULL,

        CONSTRAINT PK_dim_client
            PRIMARY KEY (client_key)
    );


    /* ========================================================
       6.1. INSÉRER LE CLIENT INCONNU
       ======================================================== */

    SET IDENTITY_INSERT mart.dim_client ON;

    INSERT INTO mart.dim_client
    (
        client_key,
        client_id,
        prenom,
        nom,
        nom_complet,
        date_naissance,
        date_entree,
        segment,
        profession,
        revenu_mensuel,
        score_risque_initial,
        agence_rattachement_id,
        ville,
        code_postal,
        email,
        statut_client
    )
    VALUES
    (
        0,
        N'INCONNU',
        N'Client',
        N'Inconnu',
        N'Client inconnu',
        NULL,
        NULL,
        N'Inconnu',
        N'Inconnue',
        NULL,
        NULL,
        N'INCONNUE',
        N'Inconnue',
        NULL,
        NULL,
        N'Inconnu'
    );

    SET IDENTITY_INSERT mart.dim_client OFF;


    /* ========================================================
       6.2. CHARGER LES CLIENTS RÉELS
       ======================================================== */

    INSERT INTO mart.dim_client
    (
        client_id,
        prenom,
        nom,
        nom_complet,
        date_naissance,
        date_entree,
        segment,
        profession,
        revenu_mensuel,
        score_risque_initial,
        agence_rattachement_id,
        ville,
        code_postal,
        email,
        statut_client
    )
    SELECT
        client_id,
        prenom,
        nom,

        /* ----------------------------------------------------
           CONCAT assemble plusieurs textes.

           Contrairement à l’opérateur +, CONCAT gère
           automatiquement les valeurs NULL.

           TRIM enlève un éventuel espace inutile
           au début ou à la fin.
           ---------------------------------------------------- */
        TRIM(
            CONCAT(
                prenom,
                N' ',
                nom
            )
        ) AS nom_complet,

        date_naissance,
        date_entree,
        segment,
        profession,
        revenu_mensuel,
        score_risque_initial,

        /* agence_id devient un attribut descriptif
           nommé agence_rattachement_id. */
        agence_id,

        ville,
        code_postal,
        email,
        statut_client

    FROM staging.clients;


    /* ========================================================
       6.3. CRÉER L’INDEX DE LA CLÉ MÉTIER CLIENT
       ======================================================== */

    CREATE UNIQUE INDEX UX_dim_client_client_id
        ON mart.dim_client(client_id);


    /* ========================================================
       7. CRÉER mart.dim_produit
       ======================================================== */

    /* --------------------------------------------------------
       GRAIN :

       Une ligne représente un produit bancaire.

       SOURCE :

       staging.produits.

       CLÉ MÉTIER :

       produit_id.

       CLÉ TECHNIQUE :

       produit_key.
       -------------------------------------------------------- */

    CREATE TABLE mart.dim_produit
    (
        /* Clé technique générée automatiquement. */
        produit_key INT IDENTITY(1,1) NOT NULL,

        /* Identifiant métier du produit. */
        produit_id NVARCHAR(20) NOT NULL,

        /* Nom commercial du produit. */
        nom_produit NVARCHAR(150) NULL,

        /* Compte, Carte, Épargne, Crédit ou Assurance. */
        famille_produit NVARCHAR(100) NULL,

        /* Univers métier du produit. */
        univers NVARCHAR(100) NULL,

        /* Niveau de complexité compris entre 1 et 4. */
        niveau_complexite INT NULL,

        CONSTRAINT PK_dim_produit
            PRIMARY KEY (produit_key)
    );


    /* ========================================================
       7.1. INSÉRER LE PRODUIT INCONNU
       ======================================================== */

    SET IDENTITY_INSERT mart.dim_produit ON;

    INSERT INTO mart.dim_produit
    (
        produit_key,
        produit_id,
        nom_produit,
        famille_produit,
        univers,
        niveau_complexite
    )
    VALUES
    (
        0,
        N'INCONNU',
        N'Produit inconnu',
        N'Inconnue',
        N'Inconnu',
        NULL
    );

    SET IDENTITY_INSERT mart.dim_produit OFF;


    /* ========================================================
       7.2. CHARGER LES PRODUITS RÉELS
       ======================================================== */

    INSERT INTO mart.dim_produit
    (
        produit_id,
        nom_produit,
        famille_produit,
        univers,
        niveau_complexite
    )
    SELECT
        produit_id,
        nom_produit,
        famille_produit,
        univers,
        niveau_complexite

    FROM staging.produits;


    /* ========================================================
       7.3. CRÉER L’INDEX DE LA CLÉ MÉTIER PRODUIT
       ======================================================== */

    CREATE UNIQUE INDEX UX_dim_produit_produit_id
        ON mart.dim_produit(produit_id);


    /* ========================================================
       8. CONTRÔLER LES NOMBRES DE LIGNES
       ======================================================== */

    /* --------------------------------------------------------
       Les membres inconnus ne viennent pas de staging.

       Le nombre de lignes attendu dans chaque dimension est donc :

       nombre staging + 1 membre inconnu.
       -------------------------------------------------------- */

    DECLARE @agences_staging BIGINT =
    (
        SELECT COUNT_BIG(*)
        FROM staging.agences
    );

    DECLARE @agences_mart BIGINT =
    (
        SELECT COUNT_BIG(*)
        FROM mart.dim_agence
    );


    DECLARE @clients_staging BIGINT =
    (
        SELECT COUNT_BIG(*)
        FROM staging.clients
    );

    DECLARE @clients_mart BIGINT =
    (
        SELECT COUNT_BIG(*)
        FROM mart.dim_client
    );


    DECLARE @produits_staging BIGINT =
    (
        SELECT COUNT_BIG(*)
        FROM staging.produits
    );

    DECLARE @produits_mart BIGINT =
    (
        SELECT COUNT_BIG(*)
        FROM mart.dim_produit
    );


    /* Nombre de jours réels attendu dans la dimension Date. */
    DECLARE @jours_attendus BIGINT =
        DATEDIFF(
            DAY,
            @date_min,
            @date_max
        ) + 1;

    /* Nombre de dates réelles, sans la ligne inconnue. */
    DECLARE @jours_mart BIGINT =
    (
        SELECT COUNT_BIG(*)
        FROM mart.dim_date
        WHERE date_key <> 0
    );


    /* ========================================================
       8.1. ARRÊTER LE SCRIPT EN CAS D’ÉCART
       ======================================================== */

    /* --------------------------------------------------------
       THROW arrête immédiatement le traitement.

       Comme une transaction est ouverte, le bloc CATCH
       annulera ensuite toutes les créations.
       -------------------------------------------------------- */
       
    IF @agences_mart <> @agences_staging + 1
        THROW 50011,
              N'Le nombre de lignes de mart.dim_agence est incorrect.',
              1;

    IF @clients_mart <> @clients_staging + 1
        THROW 50012,
              N'Le nombre de lignes de mart.dim_client est incorrect.',
              1;

    IF @produits_mart <> @produits_staging + 1
        THROW 50013,
              N'Le nombre de lignes de mart.dim_produit est incorrect.',
              1;

    IF @jours_mart <> @jours_attendus
        THROW 50014,
              N'Le nombre de dates réelles dans mart.dim_date est incorrect.',
              1;


    /* ========================================================
       8.2. VÉRIFIER LES MEMBRES INCONNUS
       ======================================================== */

    IF NOT EXISTS
    (
        SELECT 1
        FROM mart.dim_date
        WHERE date_key = 0
    )
        THROW 50015,
              N'Le membre inconnu est absent de mart.dim_date.',
              1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM mart.dim_agence
        WHERE agence_key = 0
    )
        THROW 50016,
              N'Le membre inconnu est absent de mart.dim_agence.',
              1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM mart.dim_client
        WHERE client_key = 0
    )
        THROW 50017,
              N'Le membre inconnu est absent de mart.dim_client.',
              1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM mart.dim_produit
        WHERE produit_key = 0
    )
        THROW 50018,
              N'Le membre inconnu est absent de mart.dim_produit.',
              1;


    /* ========================================================
       9. VALIDER LA TRANSACTION
       ======================================================== */

    /* --------------------------------------------------------
       COMMIT TRANSACTION valide définitivement :

       - la suppression de l’ancien modèle ;
       - la création des dimensions ;
       - le chargement des données ;
       - la création des index.

       COMMIT est exécuté uniquement si tous les contrôles
       précédents ont réussi.
       -------------------------------------------------------- */
    COMMIT TRANSACTION;


    /* ========================================================
       10. AFFICHER LES RÉSULTATS
       ======================================================== */

    /* --------------------------------------------------------
       UNION ALL rassemble les résultats des quatre dimensions
       dans un seul tableau.

       Il ne supprime pas les doublons entre les résultats,
       ce qui le rend plus rapide que UNION.
       -------------------------------------------------------- */
    SELECT
        N'mart.dim_date' AS table_dimension,
        @jours_attendus AS lignes_source_ou_attendues,
        @jours_mart + 1 AS lignes_mart_avec_inconnu,

        CONCAT(
            N'CONCLUSION : OK. ',
            @jours_mart,
            N' dates réelles couvrent la période du ',
            CONVERT(NVARCHAR(10), @date_min, 103),
            N' au ',
            CONVERT(NVARCHAR(10), @date_max, 103),
            N', auxquelles s’ajoute le membre inconnu.'
        ) AS conclusion

    UNION ALL

    SELECT
        N'mart.dim_agence',
        @agences_staging,
        @agences_mart,

        CONCAT(
            N'CONCLUSION : OK. ',
            @agences_staging,
            N' agences réelles et un membre inconnu sont présents.'
        )

    UNION ALL

    SELECT
        N'mart.dim_client',
        @clients_staging,
        @clients_mart,

        CONCAT(
            N'CONCLUSION : OK. ',
            @clients_staging,
            N' clients réels et un membre inconnu sont présents.'
        )

    UNION ALL

    SELECT
        N'mart.dim_produit',
        @produits_staging,
        @produits_mart,

        CONCAT(
            N'CONCLUSION : OK. ',
            @produits_staging,
            N' produits réels et un membre inconnu sont présents.'
        );


    /* ========================================================
       11. CONCLUSION GÉNÉRALE
       ======================================================== */

    SELECT
        CONCAT(
            N'CONCLUSION FINALE : les quatre dimensions ont été ',
            N'créées avec succès. Le calendrier couvre ',
            @jours_mart,
            N' jours. Le modèle contient ',
            @agences_staging,
            N' agences, ',
            @clients_staging,
            N' clients et ',
            @produits_staging,
            N' produits, auxquels s’ajoutent les membres inconnus.'
        ) AS conclusion_finale;


/* ============================================================
   12. GÉRER LES ERREURS
   ============================================================ */
END TRY

BEGIN CATCH

    /* --------------------------------------------------------
       @@TRANCOUNT indique le nombre de transactions ouvertes.

       Si une transaction existe encore, ROLLBACK annule
       toutes les opérations effectuées depuis BEGIN TRANSACTION.
       -------------------------------------------------------- */
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;


    /* --------------------------------------------------------
       ERROR_NUMBER()
       → numéro technique de l’erreur SQL Server.

       ERROR_LINE()
       → ligne où l’erreur est apparue.

       ERROR_MESSAGE()
       → description complète de l’erreur.

       ERROR_PROCEDURE()
       → procédure ou objet concerné, lorsqu’il existe.
       -------------------------------------------------------- */
    SELECT
        ERROR_NUMBER() AS numero_erreur,
        ERROR_LINE() AS ligne_erreur,
        ERROR_PROCEDURE() AS objet_ou_procedure,
        ERROR_MESSAGE() AS message_erreur,

        N'CONCLUSION : le traitement a été annulé. Aucune dimension partiellement créée n’a été conservée.'
            AS conclusion;


    /* --------------------------------------------------------
       THROW sans paramètre renvoie l’erreur originale à VS Code.

       Le véritable message « Msg » reste donc visible.
       -------------------------------------------------------- */
    THROW;

END CATCH;


/* ============================================================
   CONCLUSION DU FICHIER

   DIMENSIONS CRÉÉES :

   1. mart.dim_date

      Grain :
      → une ligne par journée.

      Clé :
      → date_key au format AAAAMMJJ.

      Utilisations :
      → année ;
      → mois ;
      → trimestre ;
      → semaine ;
      → jour ;
      → analyse chronologique.

   2. mart.dim_agence

      Grain :
      → une ligne par agence.

      Clé métier :
      → agence_id.

      Clé technique :
      → agence_key.

      Utilisations :
      → agence ;
      → ville ;
      → département ;
      → région ;
      → catégorie d’agence.

   3. mart.dim_client

      Grain :
      → une ligne par client.

      Clé métier :
      → client_id.

      Clé technique :
      → client_key.

      Utilisations :
      → segment ;
      → profession ;
      → revenu ;
      → risque ;
      → statut ;
      → localisation.

   4. mart.dim_produit

      Grain :
      → une ligne par produit bancaire.

      Clé métier :
      → produit_id.

      Clé technique :
      → produit_key.

      Utilisations :
      → produit ;
      → famille ;
      → univers ;
      → niveau de complexité.

   PRINCIPES RESPECTÉS :

   - une seule ligne par membre de dimension ;
   - clés techniques entières ;
   - clés métier conservées ;
   - index uniques sur les clés métier ;
   - membre inconnu avec la clé 0 ;
   - calendrier commun à toutes les analyses ;
   - absence de relation entre deux dimensions ;
   - structure adaptée à un modèle en étoile ;
   - script entièrement réexécutable ;
   - transaction annulée en cas d’erreur.

   PROCHAINE ACTION :

   Après une exécution réussie :

   1. enregistrer le fichier ;
   2. actualiser éventuellement IntelliSense ;
   3. exécuter 12_creation_mart_faits.sql ;
   4. exécuter 13_controles_modele_mart.sql.
   ============================================================ */