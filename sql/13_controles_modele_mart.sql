/* ============================================================
   PROJET : Banque 360
   FICHIER : 13_controles_modele_mart.sql

   ÉTAPE DU PROJET :

   Étape 7 sur 8, partie 3 sur 3
   Contrôler et valider le modèle analytique dans mart.

   ORDRE D’EXÉCUTION OBLIGATOIRE :

   11_creation_mart_dimensions.sql
   → crée les dimensions ;

   12_creation_mart_faits.sql
   → crée et charge les tables de faits ;

   13_controles_modele_mart.sql
   → contrôle le modèle analytique complet.

   ============================================================

   OBJECTIF DU FICHIER :

   Ce script vérifie que le modèle en étoile est :

   - complet ;
   - cohérent ;
   - conforme aux grains définis ;
   - sans perte de lignes ;
   - sans perte de montants ;
   - correctement relié ;
   - prêt à être utilisé dans Power BI.

   CONTRÔLES EFFECTUÉS :

   1. Présence des tables staging et mart.
   2. Volumétrie des dimensions.
   3. Présence des membres inconnus avec la clé 0.
   4. Unicité des clés métier des dimensions.
   5. Volumétrie des tables de faits.
   6. Respect du grain de chaque table de faits.
   7. Cohérence des clés inconnues.
   8. Conservation des montants.
   9. Cohérence des indicateurs préparés.
   10. Intégrité des relations avec les dimensions.
   11. Présence et état des clés étrangères.
   12. Présence et état des index.
   13. Synthèse métier des données disponibles.
   14. Conclusion finale de l’étape 7.

   ============================================================

   RAPPEL : QU’EST-CE QU’UN MODÈLE EN ÉTOILE ?

   Un modèle en étoile contient :

   - des dimensions :
     elles décrivent les axes d’analyse ;

   - des tables de faits :
     elles contiennent les événements et les mesures.

   Dans Banque 360 :

   DIMENSIONS :

   - mart.dim_date
   - mart.dim_agence
   - mart.dim_client
   - mart.dim_produit

   TABLES DE FAITS :

   - mart.fact_transactions
   - mart.fact_credits
   - mart.fact_remboursements
   - mart.fact_objectifs_agences
   - mart.fact_entrees_clients

   ============================================================

   RAPPEL : QU’EST-CE QUE LE GRAIN ?

   Le grain précise ce que représente exactement une ligne.

   mart.fact_transactions
   → une ligne par transaction bancaire.

   mart.fact_credits
   → une ligne par contrat de crédit.

   mart.fact_remboursements
   → une ligne par échéance de remboursement.

   mart.fact_objectifs_agences
   → une ligne par agence et par mois.

   mart.fact_entrees_clients
   → une ligne par entrée d’un client dans la banque.

   Le contrôle du grain évite les doublons et les doubles
   comptages dans Power BI.

   ============================================================

   RAPPEL : POURQUOI UTILISER LA CLÉ 0 ?

   Chaque dimension possède un membre inconnu dont la clé
   technique vaut 0.

   Cette ligne représente une référence :

   - absente ;
   - invalide ;
   - impossible à convertir ;
   - inexistante dans le référentiel.

   Exemple :

   agence_key = 0
   → l’agence métier n’a pas été retrouvée dans dim_agence.

   La clé 0 permet de conserver l’événement dans le modèle
   au lieu de supprimer sa ligne.

   ============================================================

   PARTICULARITÉ DU SCRIPT :

   Le script ne modifie aucune donnée métier dans staging
   ou dans mart.

   Il n’exécute aucun :

   - INSERT dans une table staging ou mart ;
   - UPDATE sur une table staging ou mart ;
   - DELETE sur une table staging ou mart ;
   - DROP TABLE sur une table staging ou mart ;
   - CREATE TABLE permanente.

   Il crée uniquement une table temporaire locale nommée
   #resultats_controles afin de centraliser les résultats.

   Cette table temporaire disparaît automatiquement à la fin
   de la connexion SQL et peut être recréée sans risque.

   Le fichier peut donc être réexécuté sans modifier le modèle.
   ============================================================ */


/* ============================================================
   0. SÉLECTIONNER LA BASE ET CONFIGURER L’AFFICHAGE
   ============================================================ */

/* USE indique à SQL Server dans quelle base toutes les requêtes
   suivantes doivent être exécutées. */
USE Banque360;


/* SET NOCOUNT ON évite les messages répétitifs du type
   « X lignes affectées ».

   Les tableaux de résultats restent visibles. */
SET NOCOUNT ON;


/* ============================================================
   1. VÉRIFIER LA PRÉSENCE DES TABLES NÉCESSAIRES
   ============================================================ */

/* ------------------------------------------------------------
   Une variable de type TABLE permet de stocker temporairement
   la liste des objets indispensables au contrôle.

   Chaque ligne contient :

   - le schéma ;
   - le nom de la table ;
   - le fichier qui doit normalement l’avoir créée.
   ------------------------------------------------------------ */

DECLARE @tables_requises TABLE
(
    schema_name SYSNAME NOT NULL,
    table_name SYSNAME NOT NULL,
    fichier_creation NVARCHAR(100) NOT NULL
);


/* Tables propres provenant de l’étape 6. */
INSERT INTO @tables_requises
(
    schema_name,
    table_name,
    fichier_creation
)
VALUES
    (N'staging', N'agences',             N'étape 6'),
    (N'staging', N'clients',             N'étape 6'),
    (N'staging', N'credits',             N'étape 6'),
    (N'staging', N'objectifs_agences',   N'étape 6'),
    (N'staging', N'produits',            N'étape 6'),
    (N'staging', N'remboursements',      N'étape 6'),
    (N'staging', N'transactions',        N'étape 6');


/* Dimensions créées par le fichier 11. */
INSERT INTO @tables_requises
(
    schema_name,
    table_name,
    fichier_creation
)
VALUES
    (N'mart', N'dim_date',       N'11_creation_mart_dimensions.sql'),
    (N'mart', N'dim_agence',     N'11_creation_mart_dimensions.sql'),
    (N'mart', N'dim_client',     N'11_creation_mart_dimensions.sql'),
    (N'mart', N'dim_produit',    N'11_creation_mart_dimensions.sql');


/* Tables de faits créées par le fichier 12. */
INSERT INTO @tables_requises
(
    schema_name,
    table_name,
    fichier_creation
)
VALUES
    (N'mart', N'fact_transactions',       N'12_creation_mart_faits.sql'),
    (N'mart', N'fact_credits',            N'12_creation_mart_faits.sql'),
    (N'mart', N'fact_remboursements',     N'12_creation_mart_faits.sql'),
    (N'mart', N'fact_objectifs_agences',  N'12_creation_mart_faits.sql'),
    (N'mart', N'fact_entrees_clients',    N'12_creation_mart_faits.sql');


/* ------------------------------------------------------------
   OBJECT_ID recherche un objet dans la base.

   Le paramètre N'U' signifie que l’objet doit être une table
   utilisateur.

   STRING_AGG réunit les noms des tables manquantes dans
   un seul message lisible.
   ------------------------------------------------------------ */
DECLARE @tables_manquantes NVARCHAR(MAX);

SELECT
    @tables_manquantes =
        STRING_AGG
        (
            CAST
            (
                CONCAT
                (
                    QUOTENAME(schema_name),
                    N'.',
                    QUOTENAME(table_name),
                    N' — créée par ',
                    fichier_creation
                )
                AS NVARCHAR(MAX)
            ),
            N' ; '
        )
FROM @tables_requises
WHERE OBJECT_ID
      (
          CONCAT
          (
              QUOTENAME(schema_name),
              N'.',
              QUOTENAME(table_name)
          ),
          N'U'
      ) IS NULL;


/* Si au moins une table manque, le contrôle n’a pas de sens.
   Le script est donc arrêté avec un message explicite. */
IF @tables_manquantes IS NOT NULL
BEGIN
    DECLARE @message_tables_manquantes NVARCHAR(2048);

    SET @message_tables_manquantes =
        CONCAT
        (
            N'Impossible de contrôler le modèle. Tables manquantes : ',
            @tables_manquantes,
            N'. Exécuter les fichiers indiqués avant le fichier 13.'
        );

    ;THROW 53001, @message_tables_manquantes, 1;
END;


/* ============================================================
   2. CRÉER LA TABLE TEMPORAIRE DES RÉSULTATS
   ============================================================ */

/* ------------------------------------------------------------
   Une table temporaire locale commence par #.

   Elle existe uniquement pendant cette connexion SQL.

   Elle sert ici à centraliser les résultats de tous les
   contrôles afin de produire une conclusion finale unique.
   ------------------------------------------------------------ */
DROP TABLE IF EXISTS #resultats_controles;

CREATE TABLE #resultats_controles
(
    controle_id INT IDENTITY(1,1) NOT NULL,

    categorie NVARCHAR(100) NOT NULL,

    controle NVARCHAR(250) NOT NULL,

    /* Valeur attendue ou valeur provenant de staging. */
    valeur_attendue DECIMAL(38,4) NULL,

    /* Valeur réellement observée dans mart. */
    valeur_observee DECIMAL(38,4) NULL,

    /* Différence entre observé et attendu. */
    ecart DECIMAL(38,4) NULL,

    /* OK, ATTENTION ou INFORMATION. */
    statut NVARCHAR(20) NOT NULL,

    commentaire NVARCHAR(1000) NOT NULL,

    /* La clé primaire n’est volontairement pas nommée.
       SQL Server générera un nom interne unique pour cette
       table temporaire, ce qui évite les conflits entre
       plusieurs sessions exécutées en parallèle. */
    PRIMARY KEY (controle_id)
);


/* ------------------------------------------------------------
   Le nombre attendu est calculé à partir de @tables_requises.

   Cela évite d’écrire une valeur fixe qui deviendrait fausse
   si une nouvelle table était ajoutée au projet.
   ------------------------------------------------------------ */
DECLARE @nombre_tables_requises INT =
(
    SELECT COUNT(*)
    FROM @tables_requises
);


/* Le premier contrôle valide la présence des objets. */
INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
(
    N'Préparation',
    N'Présence des tables nécessaires',
    @nombre_tables_requises,
    @nombre_tables_requises,
    0,
    N'OK',
    N'Toutes les tables staging, dimensions et faits nécessaires sont présentes.'
);


/* ============================================================
   3. CONTRÔLER LA DIMENSION DATE
   ============================================================ */

/* ------------------------------------------------------------
   La dimension Date doit couvrir toutes les dates utilisées
   dans le modèle :

   - entrée des clients ;
   - transactions ;
   - octroi des crédits ;
   - fin prévue des crédits ;
   - échéances ;
   - paiements ;
   - objectifs mensuels.

   MIN cherche la date la plus ancienne.

   MAX cherche la date la plus récente.

   UNION ALL empile toutes les sources sans dédoublonnage,
   car seuls MIN et MAX sont recherchés.
   ------------------------------------------------------------ */
DECLARE @date_min_source DATE;
DECLARE @date_max_source DATE;

SELECT
    @date_min_source = MIN(date_analyse),
    @date_max_source = MAX(date_analyse)
FROM
(
    SELECT date_entree AS date_analyse
    FROM staging.clients

    UNION ALL

    SELECT CAST(date_transaction AS DATE)
    FROM staging.transactions

    UNION ALL

    SELECT date_octroi
    FROM staging.credits

    UNION ALL

    SELECT date_fin_prevue
    FROM staging.credits

    UNION ALL

    SELECT date_echeance
    FROM staging.remboursements

    UNION ALL

    SELECT date_paiement
    FROM staging.remboursements

    UNION ALL

    SELECT mois
    FROM staging.objectifs_agences
) AS toutes_dates
WHERE date_analyse IS NOT NULL;


/* DATEDIFF calcule le nombre de jours entre les deux bornes.

   L’ajout de 1 permet de compter les deux dates incluses. */
DECLARE @jours_attendus BIGINT =
    DATEDIFF
    (
        DAY,
        @date_min_source,
        @date_max_source
    ) + 1;


/* Le membre inconnu date_key = 0 est exclu du nombre
   de dates réelles. */
DECLARE @jours_observes BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.dim_date
    WHERE date_key <> 0
);


INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
(
    N'Dimensions',
    N'Couverture de mart.dim_date',
    @jours_attendus,
    @jours_observes,
    @jours_observes - @jours_attendus,

    CASE
        WHEN @jours_observes = @jours_attendus
            THEN N'OK'
        ELSE N'ATTENTION'
    END,

    CONCAT
    (
        N'La dimension Date doit couvrir chaque journée du ',
        CONVERT(NVARCHAR(10), @date_min_source, 103),
        N' au ',
        CONVERT(NVARCHAR(10), @date_max_source, 103),
        N', hors membre inconnu.'
    )
);


/* ============================================================
   4. CONTRÔLER LA VOLUMÉTRIE DES DIMENSIONS
   ============================================================ */

/* ------------------------------------------------------------
   Les dimensions Agence, Client et Produit contiennent :

   nombre de lignes staging
   +
   un membre inconnu avec la clé 0.

   Pour comparer les données réelles, la clé 0 est exclue.
   ------------------------------------------------------------ */
DECLARE @agences_staging BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM staging.agences
);

DECLARE @agences_mart BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.dim_agence
    WHERE agence_key <> 0
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
    WHERE client_key <> 0
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
    WHERE produit_key <> 0
);


/* Agences. */
INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
(
    N'Dimensions',
    N'Nombre d’agences réelles',
    @agences_staging,
    @agences_mart,
    @agences_mart - @agences_staging,

    CASE
        WHEN @agences_staging = @agences_mart
            THEN N'OK'
        ELSE N'ATTENTION'
    END,

    N'Chaque agence de staging doit apparaître une seule fois dans mart.dim_agence.'
);


/* Clients. */
INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
(
    N'Dimensions',
    N'Nombre de clients réels',
    @clients_staging,
    @clients_mart,
    @clients_mart - @clients_staging,

    CASE
        WHEN @clients_staging = @clients_mart
            THEN N'OK'
        ELSE N'ATTENTION'
    END,

    N'Chaque client de staging doit apparaître une seule fois dans mart.dim_client.'
);


/* Produits. */
INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
(
    N'Dimensions',
    N'Nombre de produits réels',
    @produits_staging,
    @produits_mart,
    @produits_mart - @produits_staging,

    CASE
        WHEN @produits_staging = @produits_mart
            THEN N'OK'
        ELSE N'ATTENTION'
    END,

    N'Chaque produit de staging doit apparaître une seule fois dans mart.dim_produit.'
);


/* ============================================================
   5. CONTRÔLER LES MEMBRES INCONNUS DES DIMENSIONS
   ============================================================ */

/* ------------------------------------------------------------
   Chaque dimension doit posséder exactement un membre inconnu.

   SUM(CASE...) transforme chaque ligne concernée en 1
   puis additionne les résultats.
   ------------------------------------------------------------ */
DECLARE @inconnu_date INT =
(
    SELECT
        SUM
        (
            CASE
                WHEN date_key = 0 THEN 1
                ELSE 0
            END
        )
    FROM mart.dim_date
);

DECLARE @inconnu_agence INT =
(
    SELECT
        SUM
        (
            CASE
                WHEN agence_key = 0 THEN 1
                ELSE 0
            END
        )
    FROM mart.dim_agence
);

DECLARE @inconnu_client INT =
(
    SELECT
        SUM
        (
            CASE
                WHEN client_key = 0 THEN 1
                ELSE 0
            END
        )
    FROM mart.dim_client
);

DECLARE @inconnu_produit INT =
(
    SELECT
        SUM
        (
            CASE
                WHEN produit_key = 0 THEN 1
                ELSE 0
            END
        )
    FROM mart.dim_produit
);


/* Une ligne de contrôle par dimension. */
INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
    (
        N'Dimensions',
        N'Membre inconnu de dim_date',
        1,
        @inconnu_date,
        @inconnu_date - 1,
        CASE WHEN @inconnu_date = 1 THEN N'OK' ELSE N'ATTENTION' END,
        N'dim_date doit contenir exactement une ligne date_key = 0.'
    ),
    (
        N'Dimensions',
        N'Membre inconnu de dim_agence',
        1,
        @inconnu_agence,
        @inconnu_agence - 1,
        CASE WHEN @inconnu_agence = 1 THEN N'OK' ELSE N'ATTENTION' END,
        N'dim_agence doit contenir exactement une ligne agence_key = 0.'
    ),
    (
        N'Dimensions',
        N'Membre inconnu de dim_client',
        1,
        @inconnu_client,
        @inconnu_client - 1,
        CASE WHEN @inconnu_client = 1 THEN N'OK' ELSE N'ATTENTION' END,
        N'dim_client doit contenir exactement une ligne client_key = 0.'
    ),
    (
        N'Dimensions',
        N'Membre inconnu de dim_produit',
        1,
        @inconnu_produit,
        @inconnu_produit - 1,
        CASE WHEN @inconnu_produit = 1 THEN N'OK' ELSE N'ATTENTION' END,
        N'dim_produit doit contenir exactement une ligne produit_key = 0.'
    );


/* ============================================================
   6. CONTRÔLER L’UNICITÉ DES CLÉS MÉTIER
   ============================================================ */

/* ------------------------------------------------------------
   Une dimension doit contenir une seule ligne par clé métier.

   COUNT_BIG(*)
   → compte toutes les lignes réelles.

   COUNT(DISTINCT identifiant)
   → compte les identifiants différents.

   Si les deux valeurs sont égales, aucun doublon n’existe.
   ------------------------------------------------------------ */
DECLARE @agences_distinctes BIGINT =
(
    SELECT COUNT(DISTINCT agence_id)
    FROM mart.dim_agence
    WHERE agence_key <> 0
);

DECLARE @clients_distincts BIGINT =
(
    SELECT COUNT(DISTINCT client_id)
    FROM mart.dim_client
    WHERE client_key <> 0
);

DECLARE @produits_distincts BIGINT =
(
    SELECT COUNT(DISTINCT produit_id)
    FROM mart.dim_produit
    WHERE produit_key <> 0
);


INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
    (
        N'Dimensions',
        N'Unicité de agence_id',
        @agences_mart,
        @agences_distinctes,
        @agences_distinctes - @agences_mart,
        CASE WHEN @agences_distinctes = @agences_mart THEN N'OK' ELSE N'ATTENTION' END,
        N'Une agence métier ne doit apparaître qu’une seule fois dans dim_agence.'
    ),
    (
        N'Dimensions',
        N'Unicité de client_id',
        @clients_mart,
        @clients_distincts,
        @clients_distincts - @clients_mart,
        CASE WHEN @clients_distincts = @clients_mart THEN N'OK' ELSE N'ATTENTION' END,
        N'Un client métier ne doit apparaître qu’une seule fois dans dim_client.'
    ),
    (
        N'Dimensions',
        N'Unicité de produit_id',
        @produits_mart,
        @produits_distincts,
        @produits_distincts - @produits_mart,
        CASE WHEN @produits_distincts = @produits_mart THEN N'OK' ELSE N'ATTENTION' END,
        N'Un produit métier ne doit apparaître qu’une seule fois dans dim_produit.'
    );


/* ============================================================
   7. CONTRÔLER LA VOLUMÉTRIE DES TABLES DE FAITS
   ============================================================ */

/* ------------------------------------------------------------
   Chaque table de faits doit contenir autant de lignes
   que sa source staging.

   La clé 0 remplace certaines références inconnues, mais
   elle ne crée aucune ligne supplémentaire.
   ------------------------------------------------------------ */
DECLARE @transactions_staging BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM staging.transactions
);

DECLARE @transactions_mart BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_transactions
);

DECLARE @credits_staging BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM staging.credits
);

DECLARE @credits_mart BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_credits
);

DECLARE @remboursements_staging BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM staging.remboursements
);

DECLARE @remboursements_mart BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_remboursements
);

DECLARE @objectifs_staging BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM staging.objectifs_agences
);

DECLARE @objectifs_mart BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_objectifs_agences
);

DECLARE @entrees_clients_staging BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM staging.clients
);

DECLARE @entrees_clients_mart BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_entrees_clients
);


INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
    (
        N'Tables de faits',
        N'Nombre de transactions',
        @transactions_staging,
        @transactions_mart,
        @transactions_mart - @transactions_staging,
        CASE WHEN @transactions_staging = @transactions_mart THEN N'OK' ELSE N'ATTENTION' END,
        N'Chaque transaction de staging doit produire une ligne dans fact_transactions.'
    ),
    (
        N'Tables de faits',
        N'Nombre de crédits',
        @credits_staging,
        @credits_mart,
        @credits_mart - @credits_staging,
        CASE WHEN @credits_staging = @credits_mart THEN N'OK' ELSE N'ATTENTION' END,
        N'Chaque crédit de staging doit produire une ligne dans fact_credits.'
    ),
    (
        N'Tables de faits',
        N'Nombre d’échéances',
        @remboursements_staging,
        @remboursements_mart,
        @remboursements_mart - @remboursements_staging,
        CASE WHEN @remboursements_staging = @remboursements_mart THEN N'OK' ELSE N'ATTENTION' END,
        N'Chaque remboursement de staging doit produire une ligne dans fact_remboursements.'
    ),
    (
        N'Tables de faits',
        N'Nombre d’objectifs agence-mois',
        @objectifs_staging,
        @objectifs_mart,
        @objectifs_mart - @objectifs_staging,
        CASE WHEN @objectifs_staging = @objectifs_mart THEN N'OK' ELSE N'ATTENTION' END,
        N'Chaque objectif de staging doit produire une ligne dans fact_objectifs_agences.'
    ),
    (
        N'Tables de faits',
        N'Nombre d’entrées clients',
        @entrees_clients_staging,
        @entrees_clients_mart,
        @entrees_clients_mart - @entrees_clients_staging,
        CASE WHEN @entrees_clients_staging = @entrees_clients_mart THEN N'OK' ELSE N'ATTENTION' END,
        N'Chaque client doit produire une ligne dans fact_entrees_clients.'
    );


/* ============================================================
   8. CONTRÔLER LE GRAIN DES TABLES DE FAITS
   ============================================================ */

/* ------------------------------------------------------------
   Pour les transactions, crédits et remboursements, le grain
   repose sur un identifiant métier unique.

   Les objectifs utilisent le couple agence + mois.

   Les entrées clients utilisent client_key.
   ------------------------------------------------------------ */
DECLARE @transactions_distinctes BIGINT =
(
    SELECT COUNT(DISTINCT transaction_id)
    FROM mart.fact_transactions
);

DECLARE @credits_distincts BIGINT =
(
    SELECT COUNT(DISTINCT credit_id)
    FROM mart.fact_credits
);

DECLARE @remboursements_distincts BIGINT =
(
    SELECT COUNT(DISTINCT remboursement_id)
    FROM mart.fact_remboursements
);


/* GROUP BY rassemble les lignes ayant le même couple
   date_key + agence_key.

   HAVING COUNT_BIG(*) > 1 conserve seulement les doublons. */
DECLARE @doublons_objectifs BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM
    (
        SELECT
            date_key,
            agence_key
        FROM mart.fact_objectifs_agences
        GROUP BY
            date_key,
            agence_key
        HAVING COUNT_BIG(*) > 1
    ) AS couples_dupliques
);


/* Même principe pour les entrées clients :
   un client ne doit apparaître qu’une seule fois. */
DECLARE @doublons_entrees_clients BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM
    (
        SELECT
            client_key
        FROM mart.fact_entrees_clients
        GROUP BY
            client_key
        HAVING COUNT_BIG(*) > 1
    ) AS clients_dupliques
);


INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
    (
        N'Grains',
        N'Une ligne par transaction',
        @transactions_mart,
        @transactions_distinctes,
        @transactions_distinctes - @transactions_mart,
        CASE WHEN @transactions_mart = @transactions_distinctes THEN N'OK' ELSE N'ATTENTION' END,
        N'transaction_id doit être unique dans fact_transactions.'
    ),
    (
        N'Grains',
        N'Une ligne par crédit',
        @credits_mart,
        @credits_distincts,
        @credits_distincts - @credits_mart,
        CASE WHEN @credits_mart = @credits_distincts THEN N'OK' ELSE N'ATTENTION' END,
        N'credit_id doit être unique dans fact_credits.'
    ),
    (
        N'Grains',
        N'Une ligne par échéance',
        @remboursements_mart,
        @remboursements_distincts,
        @remboursements_distincts - @remboursements_mart,
        CASE WHEN @remboursements_mart = @remboursements_distincts THEN N'OK' ELSE N'ATTENTION' END,
        N'remboursement_id doit être unique dans fact_remboursements.'
    ),
    (
        N'Grains',
        N'Un objectif par agence et par mois',
        0,
        @doublons_objectifs,
        @doublons_objectifs,
        CASE WHEN @doublons_objectifs = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'Le couple date_key + agence_key doit être unique dans fact_objectifs_agences.'
    ),
    (
        N'Grains',
        N'Une entrée par client',
        0,
        @doublons_entrees_clients,
        @doublons_entrees_clients,
        CASE WHEN @doublons_entrees_clients = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'client_key doit être unique dans fact_entrees_clients.'
    );


/* ============================================================
   9. CONTRÔLER LES CLÉS INCONNUES DES TRANSACTIONS
   ============================================================ */

/* ------------------------------------------------------------
   OBJECTIF :

   Vérifier que les clés 0 présentes dans fact_transactions
   correspondent exactement aux références que les dimensions
   ne peuvent pas retrouver.

   Le nombre attendu n’est pas écrit en dur.

   Il est recalculé à partir de staging en reproduisant les
   mêmes jointures que dans le fichier 12.

   Cette méthode rend le contrôle robuste :

   - si les données sources évoluent ;
   - si une anomalie est corrigée ;
   - si de nouvelles anomalies apparaissent.

   LEFT JOIN conserve toutes les transactions.

   Lorsque la dimension ne trouve aucune correspondance,
   sa clé technique reste NULL.

   Le fichier 12 remplace ensuite ce NULL par la clé 0
   avec COALESCE.
   ------------------------------------------------------------ */


/* Date inconnue attendue :

   - date absente ;
   - date invalide devenue NULL dans staging ;
   - date hors de la dimension Date. */
DECLARE @transactions_dates_inconnues_attendues BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.transactions AS t

    LEFT JOIN mart.dim_date AS d
        ON d.date_complete = CAST(t.date_transaction AS DATE)

    WHERE d.date_key IS NULL
);


/* Client inconnu attendu :

   la clé métier client_id n’est pas retrouvée dans dim_client. */
DECLARE @transactions_clients_inconnus_attendus BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.transactions AS t

    LEFT JOIN mart.dim_client AS c
        ON c.client_id = t.client_id

    WHERE c.client_key IS NULL
);


/* Agence inconnue attendue :

   la clé métier agence_id n’est pas retrouvée dans dim_agence.

   Exemple connu dans le jeu de données :
   agence_id = A999. */
DECLARE @transactions_agences_inconnues_attendues BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.transactions AS t

    LEFT JOIN mart.dim_agence AS a
        ON a.agence_id = t.agence_id

    WHERE a.agence_key IS NULL
);


/* Produit inconnu attendu :

   produit_id est absent ou n’existe pas dans dim_produit. */
DECLARE @transactions_produits_inconnus_attendus BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.transactions AS t

    LEFT JOIN mart.dim_produit AS p
        ON p.produit_id = t.produit_id

    WHERE p.produit_key IS NULL
);


/* Valeurs réellement observées dans la table de faits. */
DECLARE @transactions_dates_inconnues_observees BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_transactions
    WHERE date_key = 0
);

DECLARE @transactions_clients_inconnus_observes BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_transactions
    WHERE client_key = 0
);

DECLARE @transactions_agences_inconnues_observees BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_transactions
    WHERE agence_key = 0
);

DECLARE @transactions_produits_inconnus_observes BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_transactions
    WHERE produit_key = 0
);


/* Enregistrer les quatre contrôles dans la table temporaire. */
INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
    (
        N'Clés inconnues',
        N'Dates inconnues dans fact_transactions',
        @transactions_dates_inconnues_attendues,
        @transactions_dates_inconnues_observees,
        @transactions_dates_inconnues_observees
            - @transactions_dates_inconnues_attendues,

        CASE
            WHEN @transactions_dates_inconnues_attendues
               = @transactions_dates_inconnues_observees
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Le nombre attendu est recalculé depuis staging en recherchant les dates sans correspondance dans dim_date.'
    ),
    (
        N'Clés inconnues',
        N'Clients inconnus dans fact_transactions',
        @transactions_clients_inconnus_attendus,
        @transactions_clients_inconnus_observes,
        @transactions_clients_inconnus_observes
            - @transactions_clients_inconnus_attendus,

        CASE
            WHEN @transactions_clients_inconnus_attendus
               = @transactions_clients_inconnus_observes
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Le nombre attendu correspond aux client_id de staging non retrouvés dans dim_client.'
    ),
    (
        N'Clés inconnues',
        N'Agences inconnues dans fact_transactions',
        @transactions_agences_inconnues_attendues,
        @transactions_agences_inconnues_observees,
        @transactions_agences_inconnues_observees
            - @transactions_agences_inconnues_attendues,

        CASE
            WHEN @transactions_agences_inconnues_attendues
               = @transactions_agences_inconnues_observees
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Le nombre attendu correspond aux agence_id de staging non retrouvés dans dim_agence.'
    ),
    (
        N'Clés inconnues',
        N'Produits inconnus dans fact_transactions',
        @transactions_produits_inconnus_attendus,
        @transactions_produits_inconnus_observes,
        @transactions_produits_inconnus_observes
            - @transactions_produits_inconnus_attendus,

        CASE
            WHEN @transactions_produits_inconnus_attendus
               = @transactions_produits_inconnus_observes
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Le nombre attendu correspond aux produit_id de staging non retrouvés dans dim_produit.'
    );


/* ============================================================
   10. CONTRÔLER LES CLÉS INCONNUES DES CRÉDITS
   ============================================================ */

/* ------------------------------------------------------------
   Les valeurs attendues sont calculées dynamiquement en
   reproduisant les jointures du fichier 12.

   Cela permet de vérifier que chaque référence non retrouvée
   dans une dimension a bien été transformée en clé 0.
   ------------------------------------------------------------ */


/* Dates d’octroi sans correspondance dans dim_date. */
DECLARE @credits_dates_octroi_inconnues_attendues BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.credits AS cr

    LEFT JOIN mart.dim_date AS d
        ON d.date_complete = cr.date_octroi

    WHERE d.date_key IS NULL
);


/* Dates de fin prévue sans correspondance dans dim_date. */
DECLARE @credits_dates_fin_inconnues_attendues BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.credits AS cr

    LEFT JOIN mart.dim_date AS d
        ON d.date_complete = cr.date_fin_prevue

    WHERE d.date_key IS NULL
);


/* Clients de crédits non retrouvés dans dim_client. */
DECLARE @credits_clients_inconnus_attendus BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.credits AS cr

    LEFT JOIN mart.dim_client AS c
        ON c.client_id = cr.client_id

    WHERE c.client_key IS NULL
);


/* Agences de crédits non retrouvées dans dim_agence.

   Exemple connu :
   certains crédits utilisent l’agence fictive A999. */
DECLARE @credits_agences_inconnues_attendues BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.credits AS cr

    LEFT JOIN mart.dim_agence AS a
        ON a.agence_id = cr.agence_id

    WHERE a.agence_key IS NULL
);


/* Valeurs réellement observées dans fact_credits. */
DECLARE @credits_dates_octroi_inconnues_observees BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_credits
    WHERE date_octroi_key = 0
);

DECLARE @credits_dates_fin_inconnues_observees BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_credits
    WHERE date_fin_prevue_key = 0
);

DECLARE @credits_clients_inconnus_observes BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_credits
    WHERE client_key = 0
);

DECLARE @credits_agences_inconnues_observees BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_credits
    WHERE agence_key = 0
);


INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
    (
        N'Clés inconnues',
        N'Dates d’octroi inconnues dans fact_credits',
        @credits_dates_octroi_inconnues_attendues,
        @credits_dates_octroi_inconnues_observees,
        @credits_dates_octroi_inconnues_observees
            - @credits_dates_octroi_inconnues_attendues,

        CASE
            WHEN @credits_dates_octroi_inconnues_attendues
               = @credits_dates_octroi_inconnues_observees
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Le nombre attendu est calculé à partir des dates d’octroi sans correspondance dans dim_date.'
    ),
    (
        N'Clés inconnues',
        N'Dates de fin prévues inconnues dans fact_credits',
        @credits_dates_fin_inconnues_attendues,
        @credits_dates_fin_inconnues_observees,
        @credits_dates_fin_inconnues_observees
            - @credits_dates_fin_inconnues_attendues,

        CASE
            WHEN @credits_dates_fin_inconnues_attendues
               = @credits_dates_fin_inconnues_observees
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Le nombre attendu est calculé à partir des dates de fin sans correspondance dans dim_date.'
    ),
    (
        N'Clés inconnues',
        N'Clients inconnus dans fact_credits',
        @credits_clients_inconnus_attendus,
        @credits_clients_inconnus_observes,
        @credits_clients_inconnus_observes
            - @credits_clients_inconnus_attendus,

        CASE
            WHEN @credits_clients_inconnus_attendus
               = @credits_clients_inconnus_observes
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Le nombre attendu correspond aux clients de crédits non retrouvés dans dim_client.'
    ),
    (
        N'Clés inconnues',
        N'Agences inconnues dans fact_credits',
        @credits_agences_inconnues_attendues,
        @credits_agences_inconnues_observees,
        @credits_agences_inconnues_observees
            - @credits_agences_inconnues_attendues,

        CASE
            WHEN @credits_agences_inconnues_attendues
               = @credits_agences_inconnues_observees
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Le nombre attendu correspond aux agences de crédits non retrouvées dans dim_agence.'
    );


/* ============================================================
   11. CONTRÔLER LES CLÉS INCONNUES DES REMBOURSEMENTS
   ============================================================ */

/* ------------------------------------------------------------
   Dans fact_remboursements, le client et l’agence ne viennent
   pas directement de staging.remboursements.

   Ils sont récupérés en suivant ce parcours :

   remboursement
   → credit_id
   → staging.credits
   → client_id et agence_id
   → dim_client et dim_agence.

   Une clé inconnue peut donc apparaître dans deux situations :

   1. le crédit indiqué dans le remboursement est introuvable ;

   2. le crédit existe, mais son client ou son agence
      n’existe pas dans la dimension correspondante.

   Le contrôle doit reproduire exactement cette chaîne de
   jointures. Compter uniquement les crédits introuvables
   serait incomplet.

   Diagnostic confirmé sur le jeu de données actuel :

   - 25 échéances ont un crédit introuvable ;
   - 283 échéances ont un crédit existant rattaché à une
     agence absente de dim_agence ;
   - 308 agence_key = 0 sont donc légitimes au total.
   ------------------------------------------------------------ */


/* Nombre d’échéances dont le crédit n’existe pas.

   Cette variable sert à expliquer l’origine des anomalies,
   mais elle n’est pas utilisée seule comme valeur attendue
   pour agence_key. */
DECLARE @remboursements_credits_introuvables BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.remboursements AS r

    LEFT JOIN staging.credits AS cr
        ON cr.credit_id = r.credit_id

    WHERE cr.credit_id IS NULL
);


/* Nombre d’échéances dont le crédit existe, mais dont l’agence
   n’est pas retrouvée dans dim_agence. */
DECLARE @remboursements_agences_credit_inconnues BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.remboursements AS r

    INNER JOIN staging.credits AS cr
        ON cr.credit_id = r.credit_id

    LEFT JOIN mart.dim_agence AS a
        ON a.agence_id = cr.agence_id

    WHERE a.agence_key IS NULL
);


/* Date d’échéance attendue comme inconnue :

   la date de staging ne trouve aucune correspondance
   dans dim_date. */
DECLARE @remboursements_dates_echeance_inconnues_attendues BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.remboursements AS r

    LEFT JOIN mart.dim_date AS d
        ON d.date_complete = r.date_echeance

    WHERE d.date_key IS NULL
);


/* Date de paiement attendue comme inconnue :

   - date absente pour une échéance non réglée ;
   - ou date non retrouvée dans dim_date. */
DECLARE @remboursements_dates_paiement_inconnues_attendues BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.remboursements AS r

    LEFT JOIN mart.dim_date AS d
        ON d.date_complete = r.date_paiement

    WHERE d.date_key IS NULL
);


/* Client inconnu attendu :

   le crédit peut être introuvable ou son client peut être
   absent de dim_client. */
DECLARE @remboursements_clients_inconnus_attendus BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.remboursements AS r

    LEFT JOIN staging.credits AS cr
        ON cr.credit_id = r.credit_id

    LEFT JOIN mart.dim_client AS c
        ON c.client_id = cr.client_id

    WHERE c.client_key IS NULL
);


/* Agence inconnue attendue :

   le crédit peut être introuvable ou son agence peut être
   absente de dim_agence.

   Cette requête calcule donc correctement :

   crédits introuvables
   +
   crédits rattachés à une agence inconnue. */
DECLARE @remboursements_agences_inconnues_attendues BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.remboursements AS r

    LEFT JOIN staging.credits AS cr
        ON cr.credit_id = r.credit_id

    LEFT JOIN mart.dim_agence AS a
        ON a.agence_id = cr.agence_id

    WHERE a.agence_key IS NULL
);


/* Valeurs réellement observées dans fact_remboursements. */
DECLARE @remboursements_dates_echeance_inconnues_observees BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_remboursements
    WHERE date_echeance_key = 0
);

DECLARE @remboursements_dates_paiement_inconnues_observees BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_remboursements
    WHERE date_paiement_key = 0
);

DECLARE @remboursements_clients_inconnus_observes BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_remboursements
    WHERE client_key = 0
);

DECLARE @remboursements_agences_inconnues_observees BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_remboursements
    WHERE agence_key = 0
);


INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
    (
        N'Clés inconnues',
        N'Dates d’échéance inconnues dans fact_remboursements',
        @remboursements_dates_echeance_inconnues_attendues,
        @remboursements_dates_echeance_inconnues_observees,
        @remboursements_dates_echeance_inconnues_observees
            - @remboursements_dates_echeance_inconnues_attendues,

        CASE
            WHEN @remboursements_dates_echeance_inconnues_attendues
               = @remboursements_dates_echeance_inconnues_observees
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Le nombre attendu correspond aux dates d’échéance sans correspondance dans dim_date.'
    ),
    (
        N'Clés inconnues',
        N'Dates de paiement inconnues dans fact_remboursements',
        @remboursements_dates_paiement_inconnues_attendues,
        @remboursements_dates_paiement_inconnues_observees,
        @remboursements_dates_paiement_inconnues_observees
            - @remboursements_dates_paiement_inconnues_attendues,

        CASE
            WHEN @remboursements_dates_paiement_inconnues_attendues
               = @remboursements_dates_paiement_inconnues_observees
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Une date_paiement_key égale à 0 est normale lorsqu’aucune date valide n’est retrouvée dans dim_date.'
    ),
    (
        N'Clés inconnues',
        N'Clients inconnus dans fact_remboursements',
        @remboursements_clients_inconnus_attendus,
        @remboursements_clients_inconnus_observes,
        @remboursements_clients_inconnus_observes
            - @remboursements_clients_inconnus_attendus,

        CASE
            WHEN @remboursements_clients_inconnus_attendus
               = @remboursements_clients_inconnus_observes
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Le nombre attendu inclut les crédits introuvables et les éventuels clients de crédit absents de dim_client.'
    ),
    (
        N'Clés inconnues',
        N'Agences inconnues dans fact_remboursements',
        @remboursements_agences_inconnues_attendues,
        @remboursements_agences_inconnues_observees,
        @remboursements_agences_inconnues_observees
            - @remboursements_agences_inconnues_attendues,

        CASE
            WHEN @remboursements_agences_inconnues_attendues
               = @remboursements_agences_inconnues_observees
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        CONCAT
        (
            N'Le nombre attendu inclut ',
            @remboursements_credits_introuvables,
            N' échéance(s) avec crédit introuvable et ',
            @remboursements_agences_credit_inconnues,
            N' échéance(s) dont le crédit existe mais dont l’agence est inconnue.'
        )
    );


/* ============================================================
   12. CONTRÔLER LES CLÉS INCONNUES DES OBJECTIFS ET ENTRÉES
   ============================================================ */

/* ------------------------------------------------------------
   Les valeurs attendues sont calculées depuis staging en
   reproduisant les jointures du fichier 12.

   Ainsi, le contrôle reste valable même si le jeu de données
   évolue ultérieurement.
   ------------------------------------------------------------ */


/* Objectifs : dates sans correspondance dans dim_date. */
DECLARE @objectifs_dates_inconnues_attendues BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.objectifs_agences AS o

    LEFT JOIN mart.dim_date AS d
        ON d.date_complete = o.mois

    WHERE d.date_key IS NULL
);


/* Objectifs : agences sans correspondance dans dim_agence. */
DECLARE @objectifs_agences_inconnues_attendues BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.objectifs_agences AS o

    LEFT JOIN mart.dim_agence AS a
        ON a.agence_id = o.agence_id

    WHERE a.agence_key IS NULL
);


/* Entrées clients : dates sans correspondance dans dim_date. */
DECLARE @entrees_dates_inconnues_attendues BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.clients AS c

    LEFT JOIN mart.dim_date AS d
        ON d.date_complete = c.date_entree

    WHERE d.date_key IS NULL
);


/* Entrées clients : clients sans correspondance dans dim_client. */
DECLARE @entrees_clients_inconnus_attendus BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.clients AS c

    LEFT JOIN mart.dim_client AS dc
        ON dc.client_id = c.client_id

    WHERE dc.client_key IS NULL
);


/* Entrées clients : agences sans correspondance dans dim_agence. */
DECLARE @entrees_agences_inconnues_attendues BIGINT =
(
    SELECT COUNT_BIG(*)

    FROM staging.clients AS c

    LEFT JOIN mart.dim_agence AS a
        ON a.agence_id = c.agence_id

    WHERE a.agence_key IS NULL
);


/* Valeurs réellement observées dans les tables de faits. */
DECLARE @objectifs_dates_inconnues_observees BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_objectifs_agences
    WHERE date_key = 0
);

DECLARE @objectifs_agences_inconnues_observees BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_objectifs_agences
    WHERE agence_key = 0
);

DECLARE @entrees_dates_inconnues_observees BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_entrees_clients
    WHERE date_key = 0
);

DECLARE @entrees_clients_inconnus_observes BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_entrees_clients
    WHERE client_key = 0
);

DECLARE @entrees_agences_inconnues_observees BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_entrees_clients
    WHERE agence_key = 0
);


INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
    (
        N'Clés inconnues',
        N'Dates inconnues dans fact_objectifs_agences',
        @objectifs_dates_inconnues_attendues,
        @objectifs_dates_inconnues_observees,
        @objectifs_dates_inconnues_observees
            - @objectifs_dates_inconnues_attendues,

        CASE
            WHEN @objectifs_dates_inconnues_attendues
               = @objectifs_dates_inconnues_observees
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Le nombre attendu correspond aux mois d’objectif sans correspondance dans dim_date.'
    ),
    (
        N'Clés inconnues',
        N'Agences inconnues dans fact_objectifs_agences',
        @objectifs_agences_inconnues_attendues,
        @objectifs_agences_inconnues_observees,
        @objectifs_agences_inconnues_observees
            - @objectifs_agences_inconnues_attendues,

        CASE
            WHEN @objectifs_agences_inconnues_attendues
               = @objectifs_agences_inconnues_observees
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Le nombre attendu correspond aux agences d’objectif non retrouvées dans dim_agence.'
    ),
    (
        N'Clés inconnues',
        N'Dates inconnues dans fact_entrees_clients',
        @entrees_dates_inconnues_attendues,
        @entrees_dates_inconnues_observees,
        @entrees_dates_inconnues_observees
            - @entrees_dates_inconnues_attendues,

        CASE
            WHEN @entrees_dates_inconnues_attendues
               = @entrees_dates_inconnues_observees
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Le nombre attendu correspond aux dates d’entrée non retrouvées dans dim_date.'
    ),
    (
        N'Clés inconnues',
        N'Clients inconnus dans fact_entrees_clients',
        @entrees_clients_inconnus_attendus,
        @entrees_clients_inconnus_observes,
        @entrees_clients_inconnus_observes
            - @entrees_clients_inconnus_attendus,

        CASE
            WHEN @entrees_clients_inconnus_attendus
               = @entrees_clients_inconnus_observes
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Le nombre attendu correspond aux clients de staging non retrouvés dans dim_client.'
    ),
    (
        N'Clés inconnues',
        N'Agences inconnues dans fact_entrees_clients',
        @entrees_agences_inconnues_attendues,
        @entrees_agences_inconnues_observees,
        @entrees_agences_inconnues_observees
            - @entrees_agences_inconnues_attendues,

        CASE
            WHEN @entrees_agences_inconnues_attendues
               = @entrees_agences_inconnues_observees
                THEN N'OK'
            ELSE N'ATTENTION'
        END,

        N'Le nombre attendu correspond aux agences de rattachement non retrouvées dans dim_agence.'
    );


/* ============================================================
   13. CONTRÔLER LA CONSERVATION DES MONTANTS
   ============================================================ */

/* ------------------------------------------------------------
   Le passage de staging vers mart ne doit modifier aucun total.

   COALESCE(SUM(...), 0) renvoie 0 si la table est vide.

   DECIMAL(38,2) offre une précision suffisante pour additionner
   un grand volume de montants en euros.
   ------------------------------------------------------------ */
DECLARE @transactions_total_staging DECIMAL(38,2) =
(
    SELECT
        CAST
        (
            COALESCE(SUM(montant), 0)
            AS DECIMAL(38,2)
        )
    FROM staging.transactions
);

DECLARE @transactions_total_mart DECIMAL(38,2) =
(
    SELECT
        CAST
        (
            COALESCE(SUM(montant_signe), 0)
            AS DECIMAL(38,2)
        )
    FROM mart.fact_transactions
);

DECLARE @credits_total_staging DECIMAL(38,2) =
(
    SELECT
        CAST
        (
            COALESCE(SUM(montant_initial), 0)
            AS DECIMAL(38,2)
        )
    FROM staging.credits
);

DECLARE @credits_total_mart DECIMAL(38,2) =
(
    SELECT
        CAST
        (
            COALESCE(SUM(montant_initial), 0)
            AS DECIMAL(38,2)
        )
    FROM mart.fact_credits
);

DECLARE @remboursements_attendus_staging DECIMAL(38,2) =
(
    SELECT
        CAST
        (
            COALESCE(SUM(montant_attendu), 0)
            AS DECIMAL(38,2)
        )
    FROM staging.remboursements
);

DECLARE @remboursements_attendus_mart DECIMAL(38,2) =
(
    SELECT
        CAST
        (
            COALESCE(SUM(montant_attendu), 0)
            AS DECIMAL(38,2)
        )
    FROM mart.fact_remboursements
);

DECLARE @remboursements_payes_staging DECIMAL(38,2) =
(
    SELECT
        CAST
        (
            COALESCE(SUM(montant_paye), 0)
            AS DECIMAL(38,2)
        )
    FROM staging.remboursements
);

DECLARE @remboursements_payes_mart DECIMAL(38,2) =
(
    SELECT
        CAST
        (
            COALESCE(SUM(montant_paye), 0)
            AS DECIMAL(38,2)
        )
    FROM mart.fact_remboursements
);

DECLARE @objectifs_revenu_staging DECIMAL(38,2) =
(
    SELECT
        CAST
        (
            COALESCE(SUM(objectif_revenu), 0)
            AS DECIMAL(38,2)
        )
    FROM staging.objectifs_agences
);

DECLARE @objectifs_revenu_mart DECIMAL(38,2) =
(
    SELECT
        CAST
        (
            COALESCE(SUM(objectif_revenu), 0)
            AS DECIMAL(38,2)
        )
    FROM mart.fact_objectifs_agences
);

DECLARE @objectifs_credit_staging DECIMAL(38,2) =
(
    SELECT
        CAST
        (
            COALESCE(SUM(objectif_production_credit), 0)
            AS DECIMAL(38,2)
        )
    FROM staging.objectifs_agences
);

DECLARE @objectifs_credit_mart DECIMAL(38,2) =
(
    SELECT
        CAST
        (
            COALESCE(SUM(objectif_production_credit), 0)
            AS DECIMAL(38,2)
        )
    FROM mart.fact_objectifs_agences
);


INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
    (
        N'Montants',
        N'Montant signé total des transactions',
        @transactions_total_staging,
        @transactions_total_mart,
        @transactions_total_mart - @transactions_total_staging,
        CASE WHEN @transactions_total_staging = @transactions_total_mart THEN N'OK' ELSE N'ATTENTION' END,
        N'La somme de montant_signe doit être identique à la somme de staging.transactions.montant.'
    ),
    (
        N'Montants',
        N'Production totale de crédit',
        @credits_total_staging,
        @credits_total_mart,
        @credits_total_mart - @credits_total_staging,
        CASE WHEN @credits_total_staging = @credits_total_mart THEN N'OK' ELSE N'ATTENTION' END,
        N'La somme des montants initiaux doit être conservée.'
    ),
    (
        N'Montants',
        N'Montant total attendu des remboursements',
        @remboursements_attendus_staging,
        @remboursements_attendus_mart,
        @remboursements_attendus_mart - @remboursements_attendus_staging,
        CASE WHEN @remboursements_attendus_staging = @remboursements_attendus_mart THEN N'OK' ELSE N'ATTENTION' END,
        N'La somme des montants attendus doit être conservée.'
    ),
    (
        N'Montants',
        N'Montant total payé des remboursements',
        @remboursements_payes_staging,
        @remboursements_payes_mart,
        @remboursements_payes_mart - @remboursements_payes_staging,
        CASE WHEN @remboursements_payes_staging = @remboursements_payes_mart THEN N'OK' ELSE N'ATTENTION' END,
        N'La somme des montants payés valides doit être conservée.'
    ),
    (
        N'Montants',
        N'Objectif total de revenu',
        @objectifs_revenu_staging,
        @objectifs_revenu_mart,
        @objectifs_revenu_mart - @objectifs_revenu_staging,
        CASE WHEN @objectifs_revenu_staging = @objectifs_revenu_mart THEN N'OK' ELSE N'ATTENTION' END,
        N'La somme des objectifs de revenu doit être conservée.'
    ),
    (
        N'Montants',
        N'Objectif total de production de crédit',
        @objectifs_credit_staging,
        @objectifs_credit_mart,
        @objectifs_credit_mart - @objectifs_credit_staging,
        CASE WHEN @objectifs_credit_staging = @objectifs_credit_mart THEN N'OK' ELSE N'ATTENTION' END,
        N'La somme des objectifs de production de crédit doit être conservée.'
    );


/* ============================================================
   14. CONTRÔLER LES INDICATEURS PRÉPARÉS
   ============================================================ */

/* ------------------------------------------------------------
   Les colonnes de comptage doivent toujours valoir 1.

   Les indicateurs binaires doivent correspondre aux statuts.

   Les montants débit et crédit doivent être cohérents avec
   le sens de la transaction.
   ------------------------------------------------------------ */
DECLARE @transactions_compteurs_invalides BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_transactions
    WHERE nombre_transactions <> 1
);

DECLARE @transactions_debits_invalides BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_transactions
    WHERE
       (
           sens = N'Débit'
           AND montant_debit <> ABS(COALESCE(montant_signe, 0))
       )
       OR
       (
           ISNULL(sens, N'') <> N'Débit'
           AND montant_debit <> 0
       )
);

DECLARE @transactions_credits_invalides BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_transactions
    WHERE
       (
           sens = N'Crédit'
           AND montant_credit <> COALESCE(montant_signe, 0)
       )
       OR
       (
           ISNULL(sens, N'') <> N'Crédit'
           AND montant_credit <> 0
       )
);

DECLARE @credits_compteurs_invalides BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_credits
    WHERE nombre_credits <> 1
);

DECLARE @remboursements_compteurs_invalides BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_remboursements
    WHERE nombre_echeances <> 1
);

DECLARE @remboursements_impayes_incoherents BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_remboursements
    WHERE est_impaye <>
          CASE
              WHEN statut_remboursement = N'Impayé' THEN 1
              ELSE 0
          END
);

DECLARE @remboursements_retards_incoherents BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_remboursements
    WHERE est_en_retard <>
          CASE
              WHEN statut_remboursement = N'Payé en retard' THEN 1
              ELSE 0
          END
);

DECLARE @remboursements_montants_incoherents BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_remboursements
    WHERE
        (
            montant_paye IS NULL
            AND montant_non_paye IS NOT NULL
        )
        OR
        (
            montant_paye IS NOT NULL
            AND montant_non_paye <>
                CASE
                    WHEN montant_attendu - montant_paye < 0
                        THEN 0
                    ELSE montant_attendu - montant_paye
                END
        )
);

DECLARE @objectifs_compteurs_invalides BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_objectifs_agences
    WHERE nombre_lignes_objectif <> 1
);

DECLARE @entrees_compteurs_invalides BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_entrees_clients
    WHERE nombre_nouveaux_clients <> 1
);


INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
    (
        N'Indicateurs',
        N'Compteur nombre_transactions',
        0,
        @transactions_compteurs_invalides,
        @transactions_compteurs_invalides,
        CASE WHEN @transactions_compteurs_invalides = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'Chaque ligne de fact_transactions doit avoir nombre_transactions = 1.'
    ),
    (
        N'Indicateurs',
        N'Cohérence de montant_debit',
        0,
        @transactions_debits_invalides,
        @transactions_debits_invalides,
        CASE WHEN @transactions_debits_invalides = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'Un débit doit être positif dans montant_debit ; les autres opérations doivent contenir 0.'
    ),
    (
        N'Indicateurs',
        N'Cohérence de montant_credit',
        0,
        @transactions_credits_invalides,
        @transactions_credits_invalides,
        CASE WHEN @transactions_credits_invalides = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'Un crédit doit être positif dans montant_credit ; les autres opérations doivent contenir 0.'
    ),
    (
        N'Indicateurs',
        N'Compteur nombre_credits',
        0,
        @credits_compteurs_invalides,
        @credits_compteurs_invalides,
        CASE WHEN @credits_compteurs_invalides = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'Chaque ligne de fact_credits doit avoir nombre_credits = 1.'
    ),
    (
        N'Indicateurs',
        N'Compteur nombre_echeances',
        0,
        @remboursements_compteurs_invalides,
        @remboursements_compteurs_invalides,
        CASE WHEN @remboursements_compteurs_invalides = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'Chaque ligne de fact_remboursements doit avoir nombre_echeances = 1.'
    ),
    (
        N'Indicateurs',
        N'Cohérence de est_impaye',
        0,
        @remboursements_impayes_incoherents,
        @remboursements_impayes_incoherents,
        CASE WHEN @remboursements_impayes_incoherents = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'est_impaye doit valoir 1 uniquement lorsque le statut est Impayé.'
    ),
    (
        N'Indicateurs',
        N'Cohérence de est_en_retard',
        0,
        @remboursements_retards_incoherents,
        @remboursements_retards_incoherents,
        CASE WHEN @remboursements_retards_incoherents = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'est_en_retard doit valoir 1 uniquement lorsque le statut est Payé en retard.'
    ),
    (
        N'Indicateurs',
        N'Cohérence de montant_non_paye',
        0,
        @remboursements_montants_incoherents,
        @remboursements_montants_incoherents,
        CASE WHEN @remboursements_montants_incoherents = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'montant_non_paye doit respecter la règle définie dans le fichier 12.'
    ),
    (
        N'Indicateurs',
        N'Compteur nombre_lignes_objectif',
        0,
        @objectifs_compteurs_invalides,
        @objectifs_compteurs_invalides,
        CASE WHEN @objectifs_compteurs_invalides = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'Chaque ligne d’objectif doit avoir nombre_lignes_objectif = 1.'
    ),
    (
        N'Indicateurs',
        N'Compteur nombre_nouveaux_clients',
        0,
        @entrees_compteurs_invalides,
        @entrees_compteurs_invalides,
        CASE WHEN @entrees_compteurs_invalides = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'Chaque entrée client doit avoir nombre_nouveaux_clients = 1.'
    );


/* ============================================================
   15. CONTRÔLER L’INTÉGRITÉ RÉFÉRENTIELLE DES FAITS
   ============================================================ */

/* ------------------------------------------------------------
   Une clé étrangère présente dans une table de faits doit
   correspondre à une ligne de sa dimension.

   NOT EXISTS détecte une clé sans correspondance.

   La clé 0 n’est pas un orphelin, car le membre inconnu existe
   réellement dans chaque dimension.
   ------------------------------------------------------------ */
DECLARE @orphelins_transactions BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_transactions AS f
    WHERE
        NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_date AS d
            WHERE d.date_key = f.date_key
        )
        OR NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_client AS c
            WHERE c.client_key = f.client_key
        )
        OR NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_produit AS p
            WHERE p.produit_key = f.produit_key
        )
        OR NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_agence AS a
            WHERE a.agence_key = f.agence_key
        )
);

DECLARE @orphelins_credits BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_credits AS f
    WHERE
        NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_date AS d
            WHERE d.date_key = f.date_octroi_key
        )
        OR NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_date AS d
            WHERE d.date_key = f.date_fin_prevue_key
        )
        OR NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_client AS c
            WHERE c.client_key = f.client_key
        )
        OR NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_agence AS a
            WHERE a.agence_key = f.agence_key
        )
);

DECLARE @orphelins_remboursements BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_remboursements AS f
    WHERE
        NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_date AS d
            WHERE d.date_key = f.date_echeance_key
        )
        OR NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_date AS d
            WHERE d.date_key = f.date_paiement_key
        )
        OR NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_client AS c
            WHERE c.client_key = f.client_key
        )
        OR NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_agence AS a
            WHERE a.agence_key = f.agence_key
        )
);

DECLARE @orphelins_objectifs BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_objectifs_agences AS f
    WHERE
        NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_date AS d
            WHERE d.date_key = f.date_key
        )
        OR NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_agence AS a
            WHERE a.agence_key = f.agence_key
        )
);

DECLARE @orphelins_entrees BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_entrees_clients AS f
    WHERE
        NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_date AS d
            WHERE d.date_key = f.date_key
        )
        OR NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_client AS c
            WHERE c.client_key = f.client_key
        )
        OR NOT EXISTS
        (
            SELECT 1
            FROM mart.dim_agence AS a
            WHERE a.agence_key = f.agence_key
        )
);


INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
    (
        N'Relations',
        N'Clés orphelines dans fact_transactions',
        0,
        @orphelins_transactions,
        @orphelins_transactions,
        CASE WHEN @orphelins_transactions = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'Toutes les clés de fact_transactions doivent correspondre à une dimension.'
    ),
    (
        N'Relations',
        N'Clés orphelines dans fact_credits',
        0,
        @orphelins_credits,
        @orphelins_credits,
        CASE WHEN @orphelins_credits = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'Toutes les clés de fact_credits doivent correspondre à une dimension.'
    ),
    (
        N'Relations',
        N'Clés orphelines dans fact_remboursements',
        0,
        @orphelins_remboursements,
        @orphelins_remboursements,
        CASE WHEN @orphelins_remboursements = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'Toutes les clés de fact_remboursements doivent correspondre à une dimension.'
    ),
    (
        N'Relations',
        N'Clés orphelines dans fact_objectifs_agences',
        0,
        @orphelins_objectifs,
        @orphelins_objectifs,
        CASE WHEN @orphelins_objectifs = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'Toutes les clés de fact_objectifs_agences doivent correspondre à une dimension.'
    ),
    (
        N'Relations',
        N'Clés orphelines dans fact_entrees_clients',
        0,
        @orphelins_entrees,
        @orphelins_entrees,
        CASE WHEN @orphelins_entrees = 0 THEN N'OK' ELSE N'ATTENTION' END,
        N'Toutes les clés de fact_entrees_clients doivent correspondre à une dimension.'
    );


/* ============================================================
   16. CONTRÔLER LES CLÉS ÉTRANGÈRES SQL
   ============================================================ */

/* ------------------------------------------------------------
   sys.foreign_keys contient les clés étrangères de la base.

   is_disabled = 0
   → la contrainte est active.

   is_not_trusted = 0
   → SQL Server a vérifié les données existantes.

   Le modèle créé par le fichier 12 contient 17 relations :

   - 4 pour fact_transactions ;
   - 4 pour fact_credits ;
   - 4 pour fact_remboursements ;
   - 2 pour fact_objectifs_agences ;
   - 3 pour fact_entrees_clients.
   ------------------------------------------------------------ */
DECLARE @cles_etrangeres_attendues INT = 17;

DECLARE @cles_etrangeres_observees INT =
(
    SELECT COUNT(*)
    FROM sys.foreign_keys AS fk
    WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) = N'mart'
      AND OBJECT_NAME(fk.parent_object_id) IN
          (
              N'fact_transactions',
              N'fact_credits',
              N'fact_remboursements',
              N'fact_objectifs_agences',
              N'fact_entrees_clients'
          )
);

DECLARE @cles_etrangeres_actives INT =
(
    SELECT COUNT(*)
    FROM sys.foreign_keys AS fk
    WHERE OBJECT_SCHEMA_NAME(fk.parent_object_id) = N'mart'
      AND OBJECT_NAME(fk.parent_object_id) IN
          (
              N'fact_transactions',
              N'fact_credits',
              N'fact_remboursements',
              N'fact_objectifs_agences',
              N'fact_entrees_clients'
          )
      AND fk.is_disabled = 0
      AND fk.is_not_trusted = 0
);


INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
(
    N'Relations',
    N'Clés étrangères actives et vérifiées',
    @cles_etrangeres_attendues,
    @cles_etrangeres_actives,
    @cles_etrangeres_actives - @cles_etrangeres_attendues,

    CASE
        WHEN @cles_etrangeres_observees = @cles_etrangeres_attendues
         AND @cles_etrangeres_actives = @cles_etrangeres_attendues
            THEN N'OK'
        ELSE N'ATTENTION'
    END,

    CONCAT
    (
        N'Le modèle doit contenir 17 clés étrangères. ',
        @cles_etrangeres_observees,
        N' ont été trouvées et ',
        @cles_etrangeres_actives,
        N' sont actives et vérifiées.'
    )
);


/* ============================================================
   17. CONTRÔLER LES INDEX
   ============================================================ */

/* ------------------------------------------------------------
   Un index accélère notamment :

   - les jointures ;
   - les filtres ;
   - les recherches ;
   - l’import et les requêtes de Power BI.

   Ce contrôle compte les index désactivés dans le schéma mart.
   Aucun index désactivé n’est attendu.
   ------------------------------------------------------------ */
DECLARE @index_desactives INT =
(
    SELECT COUNT(*)
    FROM sys.indexes AS i
    INNER JOIN sys.tables AS t
        ON t.object_id = i.object_id
    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    WHERE s.name = N'mart'
      AND i.name IS NOT NULL
      AND i.is_disabled = 1
);


INSERT INTO #resultats_controles
(
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire
)
VALUES
(
    N'Performances',
    N'Index désactivés dans mart',
    0,
    @index_desactives,
    @index_desactives,

    CASE
        WHEN @index_desactives = 0
            THEN N'OK'
        ELSE N'ATTENTION'
    END,

    N'Aucun index du modèle analytique ne doit être désactivé.'
);


/* ============================================================
   18. AFFICHER LA SYNTHÈSE MÉTIER
   ============================================================ */

/* ------------------------------------------------------------
   Ces résultats ne constituent pas des contrôles bloquants.

   Ils résument les indicateurs déjà disponibles avant
   la création des mesures DAX dans Power BI.
   ------------------------------------------------------------ */


/* 18.1. Transactions. */
SELECT
    SUM(nombre_transactions)
        AS nombre_transactions,

    CAST
    (
        COALESCE(SUM(montant_debit), 0)
        AS DECIMAL(38,2)
    ) AS montant_total_debits,

    CAST
    (
        COALESCE(SUM(montant_credit), 0)
        AS DECIMAL(38,2)
    ) AS montant_total_credits,

    CAST
    (
        COALESCE(SUM(frais), 0)
        AS DECIMAL(38,2)
    ) AS total_frais,

    N'Synthèse des transactions disponible pour les futures mesures DAX.'
        AS interpretation
FROM mart.fact_transactions;


/* 18.2. Crédits.

   AVG ignore automatiquement les valeurs NULL.

   Les taux négatifs transformés en NULL pendant le nettoyage
   ne participent donc pas à la moyenne. */
SELECT
    SUM(nombre_credits)
        AS nombre_credits,

    CAST
    (
        COALESCE(SUM(montant_initial), 0)
        AS DECIMAL(38,2)
    ) AS production_totale_credit,

    CAST
    (
        AVG(taux_annuel)
        AS DECIMAL(10,3)
    ) AS taux_annuel_moyen,

    SUM
    (
        CASE
            WHEN taux_annuel IS NULL THEN 1
            ELSE 0
        END
    ) AS taux_annuels_invalides,

    N'Synthèse des crédits disponible pour les futures mesures DAX.'
        AS interpretation
FROM mart.fact_credits;


/* 18.3. Remboursements.

   BIT ne peut pas être additionné directement.

   CAST(... AS INT) transforme temporairement :
   0 en 0 et 1 en 1. */
SELECT
    SUM(nombre_echeances)
        AS nombre_echeances,

    SUM
    (
        CAST(est_impaye AS INT)
    ) AS nombre_impayes,

    SUM
    (
        CAST(est_en_retard AS INT)
    ) AS nombre_paiements_en_retard,

    CAST
    (
        COALESCE(SUM(montant_attendu), 0)
        AS DECIMAL(38,2)
    ) AS montant_total_attendu,

    CAST
    (
        COALESCE(SUM(montant_paye), 0)
        AS DECIMAL(38,2)
    ) AS montant_total_paye,

    CAST
    (
        COALESCE(SUM(montant_non_paye), 0)
        AS DECIMAL(38,2)
    ) AS montant_total_non_paye,

    N'Synthèse des remboursements disponible pour les futures mesures DAX.'
        AS interpretation
FROM mart.fact_remboursements;


/* 18.4. Objectifs des agences. */
SELECT
    SUM(nombre_lignes_objectif)
        AS nombre_lignes_objectif,

    COUNT(DISTINCT agence_key)
        AS agences_concernees,

    COUNT(DISTINCT date_key)
        AS mois_distincts,

    CAST
    (
        COALESCE(SUM(objectif_revenu), 0)
        AS DECIMAL(38,2)
    ) AS objectif_revenu_total,

    SUM
    (
        COALESCE(objectif_nouveaux_clients, 0)
    ) AS objectif_nouveaux_clients_total,

    CAST
    (
        COALESCE(SUM(objectif_production_credit), 0)
        AS DECIMAL(38,2)
    ) AS objectif_production_credit_total,

    N'Synthèse des objectifs disponible pour les futures mesures DAX.'
        AS interpretation
FROM mart.fact_objectifs_agences;


/* 18.5. Entrées clients. */
SELECT
    SUM(nombre_nouveaux_clients)
        AS nombre_total_entrees_clients,

    COUNT(DISTINCT client_key)
        AS clients_distincts,

    COUNT(DISTINCT agence_key)
        AS agences_concernees,

    COUNT(DISTINCT date_key)
        AS dates_entree_distinctes,

    N'Les entrées réelles pourront être comparées aux objectifs mensuels.'
        AS interpretation
FROM mart.fact_entrees_clients;


/* ============================================================
   18.6. EXPLIQUER LES AGENCES INCONNUES DES REMBOURSEMENTS
   ============================================================ */

/* ------------------------------------------------------------
   Ce résultat est informatif et ne modifie pas le statut final.

   Il distingue les deux causes possibles de agence_key = 0 :

   1. le crédit du remboursement est introuvable ;

   2. le crédit existe, mais son agence n’existe pas
      dans dim_agence.

   Cette lecture permet de justifier précisément les 308 lignes
   observées dans le jeu de données actuel :

   - 25 crédits introuvables ;
   - 283 échéances liées à une agence inconnue.
   ------------------------------------------------------------ */
SELECT
    CASE
        WHEN cr.credit_id IS NULL
            THEN N'Crédit introuvable'

        WHEN a.agence_key IS NULL
            THEN N'Agence du crédit inconnue'

        ELSE N'Référence valide'
    END AS cause_agence_inconnue,

    COUNT_BIG(*) AS nombre_echeances

FROM staging.remboursements AS r

LEFT JOIN staging.credits AS cr
    ON cr.credit_id = r.credit_id

LEFT JOIN mart.dim_agence AS a
    ON a.agence_id = cr.agence_id

WHERE cr.credit_id IS NULL
   OR a.agence_key IS NULL

GROUP BY
    CASE
        WHEN cr.credit_id IS NULL
            THEN N'Crédit introuvable'

        WHEN a.agence_key IS NULL
            THEN N'Agence du crédit inconnue'

        ELSE N'Référence valide'
    END;


/* ============================================================
   19. AFFICHER LE DÉTAIL DES CLÉS ÉTRANGÈRES
   ============================================================ */

/* OBJECT_SCHEMA_NAME renvoie le schéma d’une table.

   OBJECT_NAME renvoie son nom. */
SELECT
    fk.name AS nom_cle_etrangere,

    OBJECT_SCHEMA_NAME
    (
        fk.parent_object_id
    ) AS schema_table_faits,

    OBJECT_NAME
    (
        fk.parent_object_id
    ) AS table_faits,

    OBJECT_SCHEMA_NAME
    (
        fk.referenced_object_id
    ) AS schema_dimension,

    OBJECT_NAME
    (
        fk.referenced_object_id
    ) AS dimension_referencee,

    fk.is_disabled AS cle_desactivee,

    fk.is_not_trusted AS cle_non_verifiee,

    CASE
        WHEN fk.is_disabled = 0
         AND fk.is_not_trusted = 0
            THEN N'OK : relation active et vérifiée.'
        ELSE N'ATTENTION : relation désactivée ou non vérifiée.'
    END AS conclusion

FROM sys.foreign_keys AS fk

WHERE OBJECT_SCHEMA_NAME
      (
          fk.parent_object_id
      ) = N'mart'

ORDER BY
    table_faits,
    nom_cle_etrangere;


/* ============================================================
   20. AFFICHER LE DÉTAIL DES INDEX
   ============================================================ */

/* sys.indexes contient les index, clés primaires et contraintes
   uniques représentées par un index. */
SELECT
    OBJECT_NAME(i.object_id)
        AS table_mart,

    i.name
        AS nom_index,

    CASE
        WHEN i.is_primary_key = 1
            THEN N'Clé primaire'

        WHEN i.is_unique = 1
            THEN N'Index ou contrainte unique'

        ELSE N'Index non unique'
    END AS type_index,

    i.is_disabled
        AS index_desactive,

    CASE
        WHEN i.is_disabled = 0
            THEN N'OK : index actif.'
        ELSE N'ATTENTION : index désactivé.'
    END AS conclusion

FROM sys.indexes AS i

INNER JOIN sys.tables AS t
    ON t.object_id = i.object_id

INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id

WHERE s.name = N'mart'
  AND i.name IS NOT NULL

ORDER BY
    table_mart,
    nom_index;


/* ============================================================
   21. AFFICHER TOUS LES RÉSULTATS DE CONTRÔLE
   ============================================================ */

/* Le tableau est trié selon l’ordre d’exécution des contrôles. */
SELECT
    controle_id,
    categorie,
    controle,
    valeur_attendue,
    valeur_observee,
    ecart,
    statut,
    commentaire

FROM #resultats_controles

ORDER BY controle_id;


/* ============================================================
   22. CONCLUSION FINALE DE L’ÉTAPE 7
   ============================================================ */

/* Un contrôle INFORMATION ne bloque pas la validation.

   Seules les lignes ATTENTION rendent le modèle non validé. */
DECLARE @nombre_controles INT =
(
    SELECT COUNT(*)
    FROM #resultats_controles
);

DECLARE @nombre_controles_ok INT =
(
    SELECT COUNT(*)
    FROM #resultats_controles
    WHERE statut = N'OK'
);

DECLARE @nombre_attentions INT =
(
    SELECT COUNT(*)
    FROM #resultats_controles
    WHERE statut = N'ATTENTION'
);


/* Volumétries finales utilisées dans le message. */
DECLARE @total_dates BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.dim_date
    WHERE date_key <> 0
);

DECLARE @total_agences BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.dim_agence
    WHERE agence_key <> 0
);

DECLARE @total_clients BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.dim_client
    WHERE client_key <> 0
);

DECLARE @total_produits BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.dim_produit
    WHERE produit_key <> 0
);


/* Résumé numérique final. */
SELECT
    @nombre_controles AS controles_realises,

    @nombre_controles_ok AS controles_ok,

    @nombre_attentions AS controles_attention,

    @total_dates AS dates_reelles,

    @total_agences AS agences_reelles,

    @total_clients AS clients_reels,

    @total_produits AS produits_reels,

    @transactions_mart AS transactions,

    @credits_mart AS credits,

    @remboursements_mart AS remboursements,

    @objectifs_mart AS objectifs_agences,

    @entrees_clients_mart AS entrees_clients;


/* Conclusion lisible. */
SELECT
    CASE
        WHEN @nombre_attentions = 0
        THEN CONCAT
        (
            N'CONCLUSION FINALE : ÉTAPE 7 VALIDÉE. ',
            @nombre_controles,
            N' contrôles ont été réalisés et tous sont conformes. ',
            N'Le modèle mart contient ',
            @total_dates,
            N' dates réelles, ',
            @total_agences,
            N' agences, ',
            @total_clients,
            N' clients, ',
            @total_produits,
            N' produits, ',
            @transactions_mart,
            N' transactions, ',
            @credits_mart,
            N' crédits, ',
            @remboursements_mart,
            N' échéances, ',
            @objectifs_mart,
            N' objectifs agence-mois et ',
            @entrees_clients_mart,
            N' entrées clients. Le modèle en étoile est prêt ',
            N'pour l’étape 8 dans Power BI.'
        )

        ELSE CONCAT
        (
            N'CONCLUSION FINALE : ÉTAPE 7 À VÉRIFIER. ',
            @nombre_attentions,
            N' contrôle(s) portent le statut ATTENTION sur ',
            @nombre_controles,
            N' contrôles réalisés. Consulter le tableau ',
            N'#resultats_controles avant de connecter Power BI.'
        )
    END AS conclusion_finale;


/* ============================================================
   CONCLUSION DOCUMENTAIRE DU FICHIER

   DIMENSIONS CONTRÔLÉES :

   1. mart.dim_date

      Grain :
      → une ligne par date.

      Utilisations :
      → année ;
      → semestre ;
      → trimestre ;
      → mois ;
      → semaine ;
      → jour.

   2. mart.dim_agence

      Grain :
      → une ligne par agence.

      Utilisations :
      → agence ;
      → ville ;
      → département ;
      → région ;
      → catégorie.

   3. mart.dim_client

      Grain :
      → une ligne par client.

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

      Utilisations :
      → produit ;
      → famille ;
      → univers ;
      → complexité.

   TABLES DE FAITS CONTRÔLÉES :

   1. mart.fact_transactions

      Grain :
      → une ligne par transaction.

      Mesures :
      → nombre de transactions ;
      → montant signé ;
      → montant des débits ;
      → montant des crédits ;
      → frais.

   2. mart.fact_credits

      Grain :
      → une ligne par crédit.

      Mesures :
      → nombre de crédits ;
      → montant initial ;
      → taux annuel ;
      → durée ;
      → mensualité ;
      → score de risque.

   3. mart.fact_remboursements

      Grain :
      → une ligne par échéance.

      Mesures :
      → montant attendu ;
      → montant payé ;
      → montant non payé ;
      → jours de retard ;
      → indicateur d’impayé ;
      → indicateur de retard.

   4. mart.fact_objectifs_agences

      Grain :
      → une ligne par agence et par mois.

      Mesures :
      → objectif de revenu ;
      → objectif de nouveaux clients ;
      → objectif de production de crédit ;
      → seuil du taux d’impayé.

   5. mart.fact_entrees_clients

      Grain :
      → une ligne par entrée client.

      Mesure :
      → nombre réel de nouveaux clients.

   PRINCIPES VALIDÉS :

   - modèle en étoile ;
   - dimensions partagées ;
   - absence de relation directe entre les faits ;
   - grains clairement définis ;
   - clés techniques entières ;
   - membres inconnus avec la clé 0 ;
   - valeurs attendues des clés 0 recalculées dynamiquement ;
   - distinction entre crédit introuvable et agence inconnue ;
   - conservation des lignes ;
   - conservation des montants ;
   - indicateurs cohérents ;
   - relations contrôlées ;
   - clés étrangères actives ;
   - index actifs.

   ÉTAPE 7 TERMINÉE :

   Lorsque la conclusion finale indique « ÉTAPE 7 VALIDÉE »,
   la partie SQL du modèle analytique est terminée.

   PROCHAINE ÉTAPE :

   Étape 8 sur 8, Power BI :

   1. connecter Power BI à SQL Server ;
   2. importer uniquement les tables du schéma mart ;
   3. vérifier les relations ;
   4. choisir les relations de dates actives et inactives ;
   5. masquer les clés techniques inutiles ;
   6. configurer les formats et les tris ;
   7. créer les mesures DAX ;
   8. construire les pages du tableau de bord ;
   9. vérifier les interactions et filtres ;
   10. finaliser l’esthétique et documenter le projet.
   ============================================================ */
