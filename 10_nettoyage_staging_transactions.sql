/* ============================================================
   PROJET : Banque 360
   FICHIER : 10_nettoyage_staging_transactions.sql

   ÉTAPE DU FICHIER :

   Étape 6 sur 8
   Nettoyer les données dans staging

   AVANCEMENT :

   Étapes 1 à 5 : TERMINÉES
   Étape 6 : EN COURS (partie 7/7)

   TABLE TRAITÉE :

   raw.transactions → staging.transactions

   GRAIN DE LA TABLE :

   Une ligne représente une transaction bancaire unique.

   La clé métier est :

   transaction_id

   OBJECTIF :

   - nettoyer les textes et les espaces ;
   - corriger les caractères mal encodés ;
   - convertir la date et les montants ;
   - standardiser les types, sens, canaux et statuts ;
   - supprimer les 150 doublons exacts ;
   - conserver les dates impossibles sous forme de NULL ;
   - conserver les produits absents sous forme de NULL ;
   - remplacer les agences inexistantes par NULL ;
   - contrôler les relations avec les référentiels ;
   - vérifier la cohérence entre le montant et le sens ;
   - conserver raw.transactions intacte.

   RÈGLES DE TRAITEMENT :

   1. Doublons

      Les doublons possèdent le même transaction_id et les mêmes
      informations métier.

      La première occurrence est conservée selon ligne_source.

   2. Dates impossibles

      Une date comme 2026-13-40 10:00:00 ne peut pas être
      corrigée avec certitude.

      Elle devient donc NULL dans staging.

   3. Produit absent

      Aucun produit n’est inventé.

      produit_id reste NULL lorsque la source est vide.

   4. Agence inexistante

      A999 n’existe pas dans le référentiel des agences.

      agence_id devient donc NULL sans supprimer la transaction.

   5. Montants négatifs

      Un montant négatif n’est pas une anomalie lorsqu’il
      correspond à un débit.

      Convention utilisée :

      Débit  → montant négatif
      Crédit → montant positif

   RÉSULTATS ATTENDUS AVEC transactions_raw.csv :

   - 15 150 lignes dans raw.transactions ;
   - 15 000 transactions uniques dans staging.transactions ;
   - 150 doublons exacts retirés ;
   - 40 dates impossibles remplacées par NULL ;
   - 150 produit_id absents après dédoublonnage ;
   - 60 références A999 remplacées par NULL ;
   - 0 client inexistant ;
   - 0 produit renseigné mais inexistant ;
   - 250 sens écrits en minuscules standardisés ;
   - 150 statuts « validee » standardisés ;
   - 0 incohérence entre le montant et le sens.
   ============================================================ */


USE Banque360;
GO


/* ============================================================
   1. RECRÉER staging.transactions
   ============================================================ */

/* Supprime uniquement l’ancienne version nettoyée.

   raw.transactions reste intacte. */
DROP TABLE IF EXISTS staging.transactions;
GO


/* ------------------------------------------------------------
   TYPES UTILISÉS :

   INT
   → nombre entier.

   DATETIME2(0)
   → date et heure sans fraction de seconde.

   DECIMAL(15,2)
   → montant monétaire avec deux décimales.

   NVARCHAR
   → texte acceptant les caractères Unicode.
   ------------------------------------------------------------ */
CREATE TABLE staging.transactions
(
    /* Numéro de ligne du fichier CSV original. */
    ligne_source INT NULL,

    /* Identifiant unique de la transaction. */
    transaction_id NVARCHAR(20) NULL,

    /* Identifiant du client concerné. */
    client_id NVARCHAR(20) NULL,

    /* Date et heure de la transaction. */
    date_transaction DATETIME2(0) NULL,

    /* Nature de la transaction. */
    type_transaction NVARCHAR(100) NULL,

    /* Montant signé :

       négatif pour un débit ;
       positif pour un crédit. */
    montant DECIMAL(15,2) NULL,

    /* Sens de la transaction : Débit ou Crédit. */
    sens NVARCHAR(20) NULL,

    /* Produit bancaire concerné.

       La valeur peut être NULL lorsqu’aucun produit
       n’est renseigné dans la source. */
    produit_id NVARCHAR(20) NULL,

    /* Agence rattachée à la transaction.

       Une agence inexistante devient NULL. */
    agence_id NVARCHAR(20) NULL,

    /* Canal utilisé pour réaliser la transaction. */
    canal NVARCHAR(100) NULL,

    /* Statut de la transaction. */
    statut NVARCHAR(50) NULL,

    /* Frais bancaires associés à la transaction. */
    frais DECIMAL(15,2) NULL,

    /* Devise de la transaction. */
    devise NVARCHAR(3) NULL
);
GO


/* ============================================================
   2. NETTOYER, DÉDOUBLONNER ET CHARGER LES TRANSACTIONS
   ============================================================ */

/* ------------------------------------------------------------
   source_nettoyee :

   - nettoie les textes ;
   - convertit les dates et les nombres.

   source_classee :

   - numérote les occurrences de chaque transaction_id ;
   - permet de conserver seulement la première occurrence.

   ROW_NUMBER recommence à 1 pour chaque transaction_id.
   ------------------------------------------------------------ */
WITH source_nettoyee AS
(
    SELECT
        TRY_CONVERT(
            INT,
            NULLIF(TRIM(ligne_source), N'')
        ) AS ligne_source,

        UPPER(
            staging.fn_nettoyer_texte(transaction_id)
        ) AS transaction_id,

        UPPER(
            staging.fn_nettoyer_texte(client_id)
        ) AS client_id,

        /* Le format 120 correspond à :

           AAAA-MM-JJ HH:MM:SS */
        TRY_CONVERT(
            DATETIME2(0),
            NULLIF(TRIM(date_transaction), N''),
            120
        ) AS date_transaction,

        staging.fn_nettoyer_texte(type_transaction)
            AS type_transaction,

        TRY_CONVERT(
            DECIMAL(15,2),
            NULLIF(TRIM(montant), N'')
        ) AS montant,

        staging.fn_nettoyer_texte(sens)
            AS sens,

        UPPER(
            staging.fn_nettoyer_texte(produit_id)
        ) AS produit_id,

        UPPER(
            staging.fn_nettoyer_texte(agence_id)
        ) AS agence_id,

        staging.fn_nettoyer_texte(canal)
            AS canal,

        staging.fn_nettoyer_texte(statut)
            AS statut,

        TRY_CONVERT(
            DECIMAL(15,2),
            NULLIF(TRIM(frais), N'')
        ) AS frais,

        UPPER(
            staging.fn_nettoyer_texte(devise)
        ) AS devise

    FROM raw.transactions
),

source_classee AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY
                CASE
                    WHEN transaction_id IS NULL
                    THEN CONCAT(
                        N'SANS_ID_',
                        ligne_source
                    )
                    ELSE transaction_id
                END

            ORDER BY ligne_source
        ) AS rang_doublon

    FROM source_nettoyee
)


INSERT INTO staging.transactions
(
    ligne_source,
    transaction_id,
    client_id,
    date_transaction,
    type_transaction,
    montant,
    sens,
    produit_id,
    agence_id,
    canal,
    statut,
    frais,
    devise
)
SELECT
    s.ligne_source,
    s.transaction_id,

    /* Le client est conservé uniquement s’il existe
       dans le référentiel clients. */
    CASE
        WHEN s.client_id IS NULL
            THEN NULL

        WHEN EXISTS
        (
            SELECT 1
            FROM raw.clients AS c
            WHERE NULLIF(TRIM(c.client_id), N'')
                  = s.client_id
        )
            THEN s.client_id

        ELSE NULL
    END AS client_id,

    /* Une date impossible est déjà devenue NULL
       grâce à TRY_CONVERT. */
    s.date_transaction,

    /* Standardise les huit types de transaction. */
    CASE
        WHEN UPPER(s.type_transaction)
             COLLATE Latin1_General_100_BIN2
             = N'PAIEMENT CARTE'
            THEN N'Paiement carte'

        WHEN UPPER(s.type_transaction)
             COLLATE Latin1_General_100_BIN2
             = N'PRÉLÈVEMENT'
            THEN N'Prélèvement'

        WHEN UPPER(s.type_transaction)
             COLLATE Latin1_General_100_BIN2
             = N'VIREMENT REÇU'
            THEN N'Virement reçu'

        WHEN UPPER(s.type_transaction)
             COLLATE Latin1_General_100_BIN2
             = N'VIREMENT ÉMIS'
            THEN N'Virement émis'

        WHEN UPPER(s.type_transaction)
             COLLATE Latin1_General_100_BIN2
             = N'RETRAIT DAB'
            THEN N'Retrait DAB'

        WHEN UPPER(s.type_transaction)
             COLLATE Latin1_General_100_BIN2
             = N'REMBOURSEMENT'
            THEN N'Remboursement'

        WHEN UPPER(s.type_transaction)
             COLLATE Latin1_General_100_BIN2
             = N'FRAIS BANCAIRES'
            THEN N'Frais bancaires'

        WHEN UPPER(s.type_transaction)
             COLLATE Latin1_General_100_BIN2
             = N'DÉPÔT'
            THEN N'Dépôt'

        ELSE s.type_transaction
    END AS type_transaction,

    /* Le signe du montant est conservé. */
    s.montant,

    /* Standardise les variantes :

       débit  → Débit
       crédit → Crédit */
    CASE
        WHEN UPPER(s.sens)
             COLLATE Latin1_General_100_BIN2
             IN
             (
                 N'DÉBIT',
                 N'DEBIT'
             )
            THEN N'Débit'

        WHEN UPPER(s.sens)
             COLLATE Latin1_General_100_BIN2
             IN
             (
                 N'CRÉDIT',
                 N'CREDIT'
             )
            THEN N'Crédit'

        ELSE s.sens
    END AS sens,

    /* --------------------------------------------------------
       Le produit reste NULL lorsque la source est vide.

       Un produit renseigné est conservé uniquement s’il existe
       dans raw.produits.
       -------------------------------------------------------- */
    CASE
        WHEN s.produit_id IS NULL
            THEN NULL

        WHEN EXISTS
        (
            SELECT 1
            FROM raw.produits AS p
            WHERE NULLIF(TRIM(p.produit_id), N'')
                  = s.produit_id
        )
            THEN s.produit_id

        ELSE NULL
    END AS produit_id,

    /* L’agence est conservée uniquement si elle existe.

       A999 devient donc NULL. */
    CASE
        WHEN s.agence_id IS NULL
            THEN NULL

        WHEN EXISTS
        (
            SELECT 1
            FROM raw.agences AS a
            WHERE NULLIF(TRIM(a.agence_id), N'')
                  = s.agence_id
        )
            THEN s.agence_id

        ELSE NULL
    END AS agence_id,

    /* Standardise les canaux. */
    CASE UPPER(s.canal)
        WHEN N'APPLICATION MOBILE'
            THEN N'Application mobile'

        WHEN N'TPE'
            THEN N'TPE'

        WHEN N'WEB'
            THEN N'Web'

        WHEN N'DAB'
            THEN N'DAB'

        WHEN N'AGENCE'
            THEN N'Agence'

        ELSE s.canal
    END AS canal,

    /* Standardise les statuts et corrige « validee ». */
    CASE
        WHEN UPPER(s.statut)
             COLLATE Latin1_General_100_BIN2
             IN
             (
                 N'VALIDÉE',
                 N'VALIDEE'
             )
            THEN N'Validée'

        WHEN UPPER(s.statut)
             COLLATE Latin1_General_100_BIN2
             IN
             (
                 N'REJETÉE',
                 N'REJETEE'
             )
            THEN N'Rejetée'

        WHEN UPPER(s.statut)
             COLLATE Latin1_General_100_BIN2
             = N'EN ATTENTE'
            THEN N'En attente'

        ELSE s.statut
    END AS statut,

    s.frais,
    s.devise

FROM source_classee AS s

/* Conserve seulement la première occurrence
   de chaque transaction_id. */
WHERE s.rang_doublon = 1;
GO


/* ============================================================
   3. CONTRÔLER LE NOMBRE DE LIGNES
   ============================================================ */

DECLARE @lignes_raw INT =
(
    SELECT COUNT(*)
    FROM raw.transactions
);

DECLARE @lignes_staging INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
);

DECLARE @lignes_retires INT =
    @lignes_raw - @lignes_staging;


SELECT
    @lignes_raw AS lignes_raw,
    @lignes_staging AS transactions_uniques_staging,
    @lignes_retires AS lignes_dupliquees_retirees,

    CASE
        WHEN @lignes_raw = 15150
         AND @lignes_staging = 15000
         AND @lignes_retires = 150
        THEN CONCAT(
            N'CONCLUSION : OK. Les ',
            @lignes_raw,
            N' lignes brutes ont produit ',
            @lignes_staging,
            N' transactions uniques. Les ',
            @lignes_retires,
            N' doublons exacts ont été retirés.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. raw contient ',
            @lignes_raw,
            N' lignes et staging contient ',
            @lignes_staging,
            N' lignes. La différence est de ',
            @lignes_retires,
            N' ligne(s).'
        )
    END AS conclusion;
GO


/* ============================================================
   4. CONTRÔLER LES CONVERSIONS
   ============================================================ */

DECLARE @lignes_source_invalides INT =
(
    SELECT COUNT(*)
    FROM raw.transactions
    WHERE NULLIF(TRIM(ligne_source), N'') IS NOT NULL
      AND TRY_CONVERT(
              INT,
              TRIM(ligne_source)
          ) IS NULL
);

DECLARE @dates_invalides INT =
(
    SELECT COUNT(*)
    FROM raw.transactions
    WHERE NULLIF(TRIM(date_transaction), N'') IS NOT NULL
      AND TRY_CONVERT(
              DATETIME2(0),
              TRIM(date_transaction),
              120
          ) IS NULL
);

DECLARE @montants_invalides INT =
(
    SELECT COUNT(*)
    FROM raw.transactions
    WHERE NULLIF(TRIM(montant), N'') IS NOT NULL
      AND TRY_CONVERT(
              DECIMAL(15,2),
              TRIM(montant)
          ) IS NULL
);

DECLARE @frais_invalides INT =
(
    SELECT COUNT(*)
    FROM raw.transactions
    WHERE NULLIF(TRIM(frais), N'') IS NOT NULL
      AND TRY_CONVERT(
              DECIMAL(15,2),
              TRIM(frais)
          ) IS NULL
);


SELECT
    @lignes_source_invalides
        AS numeros_ligne_invalides,

    @dates_invalides
        AS dates_invalides,

    @montants_invalides
        AS montants_invalides,

    @frais_invalides
        AS frais_invalides,

    CASE
        WHEN @lignes_source_invalides = 0
         AND @dates_invalides = 40
         AND @montants_invalides = 0
         AND @frais_invalides = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Les nombres ont été correctement ',
            N'convertis. Les ',
            @dates_invalides,
            N' dates impossibles ont été détectées et sont ',
            N'représentées par NULL dans staging.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ',
            @lignes_source_invalides,
            N' numéro(s) de ligne, ',
            @dates_invalides,
            N' date(s), ',
            @montants_invalides,
            N' montant(s) et ',
            @frais_invalides,
            N' frais sont impossibles à convertir.'
        )
    END AS conclusion;
GO


/* Affiche les valeurs impossibles à convertir.

   Résultat attendu :
   40 dates égales à 2026-13-40 10:00:00. */
SELECT TOP (40)
    ligne_source,
    transaction_id,
    date_transaction,
    montant,
    frais

FROM raw.transactions

WHERE
(
    NULLIF(TRIM(ligne_source), N'') IS NOT NULL
    AND TRY_CONVERT(
            INT,
            TRIM(ligne_source)
        ) IS NULL
)

OR
(
    NULLIF(TRIM(date_transaction), N'') IS NOT NULL
    AND TRY_CONVERT(
            DATETIME2(0),
            TRIM(date_transaction),
            120
        ) IS NULL
)

OR
(
    NULLIF(TRIM(montant), N'') IS NOT NULL
    AND TRY_CONVERT(
            DECIMAL(15,2),
            TRIM(montant)
        ) IS NULL
)

OR
(
    NULLIF(TRIM(frais), N'') IS NOT NULL
    AND TRY_CONVERT(
            DECIMAL(15,2),
            TRIM(frais)
        ) IS NULL
)

ORDER BY TRY_CONVERT(INT, ligne_source);
GO


/* ============================================================
   5. CONTRÔLER LES DOUBLONS
   ============================================================ */

/* ------------------------------------------------------------
   transaction_id est la clé utilisée pour détecter
   les doublons.

   nombre_occurrences - 1
   → calcule les lignes supplémentaires.

   COALESCE
   → renvoie 0 si aucun doublon n’existe.
   ------------------------------------------------------------ */
DECLARE @identifiants_dupliques INT;
DECLARE @lignes_dupliquees INT;

SELECT
    @identifiants_dupliques = COUNT(*),

    @lignes_dupliquees =
        COALESCE(
            SUM(nombre_occurrences - 1),
            0
        )

FROM
(
    SELECT
        NULLIF(TRIM(transaction_id), N'')
            AS transaction_id,

        COUNT(*) AS nombre_occurrences

    FROM raw.transactions

    WHERE NULLIF(TRIM(transaction_id), N'') IS NOT NULL

    GROUP BY NULLIF(TRIM(transaction_id), N'')

    HAVING COUNT(*) > 1
) AS doublons;


SELECT
    @identifiants_dupliques
        AS transaction_id_dupliques,

    @lignes_dupliquees
        AS lignes_dupliquees,

    CASE
        WHEN @identifiants_dupliques = 150
         AND @lignes_dupliquees = 150
        THEN CONCAT(
            N'CONCLUSION : OK. ',
            @identifiants_dupliques,
            N' transaction_id étaient présents deux fois. ',
            N'Les ',
            @lignes_dupliquees,
            N' lignes supplémentaires ont été retirées.'
        )

        WHEN @identifiants_dupliques = 0
        THEN N'CONCLUSION : aucun transaction_id dupliqué.'

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @identifiants_dupliques,
            N' identifiant(s) sont dupliqués, soit ',
            @lignes_dupliquees,
            N' ligne(s) supplémentaire(s).'
        )
    END AS conclusion;
GO


/* Affiche 20 exemples de transaction_id dupliqués. */
SELECT TOP (20)
    NULLIF(TRIM(transaction_id), N'')
        AS transaction_id,

    COUNT(*) AS nombre_occurrences

FROM raw.transactions

WHERE NULLIF(TRIM(transaction_id), N'') IS NOT NULL

GROUP BY NULLIF(TRIM(transaction_id), N'')

HAVING COUNT(*) > 1

ORDER BY
    nombre_occurrences DESC,
    transaction_id;
GO


/* Vérifie qu’aucun doublon ne reste dans staging. */
DECLARE @doublons_restants INT =
(
    SELECT COUNT(*)
    FROM
    (
        SELECT
            transaction_id

        FROM staging.transactions

        WHERE transaction_id IS NOT NULL

        GROUP BY transaction_id

        HAVING COUNT(*) > 1
    ) AS doublons
);

SELECT
    @doublons_restants AS doublons_restants,

    CASE
        WHEN @doublons_restants = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Aucun transaction_id dupliqué ',
            N'ne reste dans staging.transactions.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @doublons_restants,
            N' transaction_id sont encore dupliqués.'
        )
    END AS conclusion;
GO


/* ============================================================
   6. CONTRÔLER LES VALEURS MANQUANTES
   ============================================================ */

/* ------------------------------------------------------------
   produit_id est traité séparément car son absence est
   volontairement conservée sous forme de NULL.

   Les autres colonnes doivent être présentes dans la source.
   ------------------------------------------------------------ */
DECLARE @lignes_source_incompletes INT =
(
    SELECT COUNT(*)
    FROM raw.transactions
    WHERE NULLIF(TRIM(ligne_source), N'') IS NULL
       OR NULLIF(TRIM(transaction_id), N'') IS NULL
       OR NULLIF(TRIM(client_id), N'') IS NULL
       OR NULLIF(TRIM(date_transaction), N'') IS NULL
       OR NULLIF(TRIM(type_transaction), N'') IS NULL
       OR NULLIF(TRIM(montant), N'') IS NULL
       OR NULLIF(TRIM(sens), N'') IS NULL
       OR NULLIF(TRIM(agence_id), N'') IS NULL
       OR NULLIF(TRIM(canal), N'') IS NULL
       OR NULLIF(TRIM(statut), N'') IS NULL
       OR NULLIF(TRIM(frais), N'') IS NULL
       OR NULLIF(TRIM(devise), N'') IS NULL
);

DECLARE @produits_absents_source INT =
(
    SELECT COUNT(*)
    FROM raw.transactions
    WHERE NULLIF(TRIM(produit_id), N'') IS NULL
);

DECLARE @produits_absents_staging INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE produit_id IS NULL
);


SELECT
    @lignes_source_incompletes
        AS lignes_source_incompletes,

    @produits_absents_source
        AS produits_absents_source,

    @produits_absents_staging
        AS produits_absents_apres_dedoublonnage,

    CASE
        WHEN @lignes_source_incompletes = 0
         AND @produits_absents_staging = 150
        THEN CONCAT(
            N'CONCLUSION : OK. Aucun champ obligatoire n’est vide. ',
            N'Après dédoublonnage, ',
            @produits_absents_staging,
            N' transactions restent sans produit_id. ',
            N'Aucun produit n’a été inventé.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ',
            @lignes_source_incompletes,
            N' ligne(s) ont un champ obligatoire absent et ',
            @produits_absents_staging,
            N' transaction(s) sont sans produit.'
        )
    END AS conclusion;
GO


/* Affiche 20 transactions sans produit. */
SELECT TOP (20)
    ligne_source,
    transaction_id,
    type_transaction,
    montant,
    sens,
    produit_id

FROM staging.transactions

WHERE produit_id IS NULL

ORDER BY transaction_id;
GO


/* ============================================================
   7. CONTRÔLER LES RELATIONS AVEC LES RÉFÉRENTIELS
   ============================================================ */

/* Clients inexistants dans la source. */
DECLARE @clients_orphelins_source INT =
(
    SELECT COUNT(*)

    FROM raw.transactions AS t

    WHERE NULLIF(TRIM(t.client_id), N'') IS NOT NULL

      AND NOT EXISTS
      (
          SELECT 1

          FROM raw.clients AS c

          WHERE NULLIF(TRIM(c.client_id), N'')
                = NULLIF(TRIM(t.client_id), N'')
      )
);


/* Produits renseignés mais inexistants. */
DECLARE @produits_orphelins_source INT =
(
    SELECT COUNT(*)

    FROM raw.transactions AS t

    WHERE NULLIF(TRIM(t.produit_id), N'') IS NOT NULL

      AND NOT EXISTS
      (
          SELECT 1

          FROM raw.produits AS p

          WHERE NULLIF(TRIM(p.produit_id), N'')
                = NULLIF(TRIM(t.produit_id), N'')
      )
);


/* Agences renseignées mais inexistantes. */
DECLARE @agences_orphelines_source INT =
(
    SELECT COUNT(*)

    FROM raw.transactions AS t

    WHERE NULLIF(TRIM(t.agence_id), N'') IS NOT NULL

      AND NOT EXISTS
      (
          SELECT 1

          FROM raw.agences AS a

          WHERE NULLIF(TRIM(a.agence_id), N'')
                = NULLIF(TRIM(t.agence_id), N'')
      )
);


DECLARE @clients_null_staging INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE client_id IS NULL
);

DECLARE @agences_null_staging INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE agence_id IS NULL
);


SELECT
    @clients_orphelins_source
        AS clients_orphelins_source,

    @produits_orphelins_source
        AS produits_renseignes_orphelins,

    @agences_orphelines_source
        AS agences_orphelines_source,

    @clients_null_staging
        AS clients_null_staging,

    @agences_null_staging
        AS agences_remplacees_par_null,

    CASE
        WHEN @clients_orphelins_source = 0
         AND @produits_orphelins_source = 0
         AND @agences_orphelines_source = 60
         AND @clients_null_staging = 0
         AND @agences_null_staging = 60
        THEN CONCAT(
            N'CONCLUSION : OK. Tous les clients existent, ',
            N'aucun produit renseigné n’est orphelin et les ',
            @agences_orphelines_source,
            N' références A999 ont été remplacées par NULL.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ',
            @clients_orphelins_source,
            N' référence(s) client, ',
            @produits_orphelins_source,
            N' référence(s) produit et ',
            @agences_orphelines_source,
            N' référence(s) agence sont orphelines.'
        )
    END AS conclusion;
GO


/* Affiche les références orphelines avant nettoyage. */
SELECT TOP (20)
    t.transaction_id,
    t.client_id,
    t.produit_id,
    t.agence_id

FROM raw.transactions AS t

WHERE
(
    NULLIF(TRIM(t.client_id), N'') IS NOT NULL

    AND NOT EXISTS
    (
        SELECT 1
        FROM raw.clients AS c
        WHERE NULLIF(TRIM(c.client_id), N'')
              = NULLIF(TRIM(t.client_id), N'')
    )
)

OR
(
    NULLIF(TRIM(t.produit_id), N'') IS NOT NULL

    AND NOT EXISTS
    (
        SELECT 1
        FROM raw.produits AS p
        WHERE NULLIF(TRIM(p.produit_id), N'')
              = NULLIF(TRIM(t.produit_id), N'')
    )
)

OR
(
    NULLIF(TRIM(t.agence_id), N'') IS NOT NULL

    AND NOT EXISTS
    (
        SELECT 1
        FROM raw.agences AS a
        WHERE NULLIF(TRIM(a.agence_id), N'')
              = NULLIF(TRIM(t.agence_id), N'')
    )
)

ORDER BY t.transaction_id;
GO


/* ============================================================
   8. CONTRÔLER LA STANDARDISATION DES TEXTES
   ============================================================ */

DECLARE @types_standardises INT;
DECLARE @sens_standardises INT;
DECLARE @canaux_standardises INT;
DECLARE @statuts_standardises INT;
DECLARE @devises_standardisees INT;


/* Une seule occurrence brute est conservée pour comparer
   correctement raw et staging. */
WITH raw_unique AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY NULLIF(TRIM(transaction_id), N'')
            ORDER BY TRY_CONVERT(INT, ligne_source)
        ) AS rang

    FROM raw.transactions
)

SELECT
    @types_standardises =
        COALESCE(
            SUM(
                CASE
                    WHEN staging.fn_nettoyer_texte(
                             r.type_transaction
                         )
                         COLLATE Latin1_General_100_BIN2

                         <> s.type_transaction
                            COLLATE Latin1_General_100_BIN2
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ),

    @sens_standardises =
        COALESCE(
            SUM(
                CASE
                    WHEN staging.fn_nettoyer_texte(
                             r.sens
                         )
                         COLLATE Latin1_General_100_BIN2

                         <> s.sens
                            COLLATE Latin1_General_100_BIN2
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ),

    @canaux_standardises =
        COALESCE(
            SUM(
                CASE
                    WHEN staging.fn_nettoyer_texte(
                             r.canal
                         )
                         COLLATE Latin1_General_100_BIN2

                         <> s.canal
                            COLLATE Latin1_General_100_BIN2
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ),

    @statuts_standardises =
        COALESCE(
            SUM(
                CASE
                    WHEN staging.fn_nettoyer_texte(
                             r.statut
                         )
                         COLLATE Latin1_General_100_BIN2

                         <> s.statut
                            COLLATE Latin1_General_100_BIN2
                    THEN 1
                    ELSE 0
                END
            ),
            0
        ),

    @devises_standardisees =
        COALESCE(
            SUM(
                CASE
                    WHEN UPPER(
                             staging.fn_nettoyer_texte(
                                 r.devise
                             )
                         )
                         COLLATE Latin1_General_100_BIN2

                         <> s.devise
                            COLLATE Latin1_General_100_BIN2
                    THEN 1
                    ELSE 0
                END
            ),
            0
        )

FROM raw_unique AS r

INNER JOIN staging.transactions AS s
    ON NULLIF(TRIM(r.transaction_id), N'')
       = s.transaction_id

WHERE r.rang = 1;


SELECT
    @types_standardises
        AS types_standardises,

    @sens_standardises
        AS sens_standardises,

    @canaux_standardises
        AS canaux_standardises,

    @statuts_standardises
        AS statuts_standardises,

    @devises_standardisees
        AS devises_standardisees,

    CASE
        WHEN @sens_standardises = 250
         AND @statuts_standardises = 150
        THEN CONCAT(
            N'CONCLUSION : OK. ',
            @sens_standardises,
            N' sens écrits en minuscules et ',
            @statuts_standardises,
            N' statuts non standardisés ont été corrigés.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ',
            @types_standardises,
            N' type(s), ',
            @sens_standardises,
            N' sens, ',
            @canaux_standardises,
            N' canal(aux), ',
            @statuts_standardises,
            N' statut(s) et ',
            @devises_standardisees,
            N' devise(s) ont été standardisés.'
        )
    END AS conclusion;
GO


/* ============================================================
   9. CONTRÔLER LA COHÉRENCE MONTANT / SENS
   ============================================================ */

/* ------------------------------------------------------------
   Règle métier :

   Débit  → montant strictement négatif.
   Crédit → montant strictement positif.

   Les montants négatifs sont donc normaux pour les débits.
   ------------------------------------------------------------ */
DECLARE @debits INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE sens = N'Débit'
);

DECLARE @credits INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE sens = N'Crédit'
);

DECLARE @montants_nuls_ou_absents INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE montant IS NULL
       OR montant = 0
);

DECLARE @montants_sens_incoherents INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE
    (
        sens = N'Débit'
        AND montant >= 0
    )

    OR
    (
        sens = N'Crédit'
        AND montant <= 0
    )
);

DECLARE @sens_inconnus INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE sens IS NULL
       OR sens NOT IN
          (
              N'Débit',
              N'Crédit'
          )
);


SELECT
    @debits AS nombre_debits,
    @credits AS nombre_credits,
    @montants_nuls_ou_absents
        AS montants_nuls_ou_absents,
    @montants_sens_incoherents
        AS montants_sens_incoherents,
    @sens_inconnus
        AS sens_inconnus,

    CASE
        WHEN @montants_nuls_ou_absents = 0
         AND @montants_sens_incoherents = 0
         AND @sens_inconnus = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Les ',
            @debits,
            N' débits possèdent un montant négatif et les ',
            @credits,
            N' crédits possèdent un montant positif.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @montants_sens_incoherents,
            N' transaction(s) ont un signe incohérent et ',
            @sens_inconnus,
            N' transaction(s) ont un sens inconnu.'
        )
    END AS conclusion;
GO


/* Affiche les éventuelles incohérences. */
SELECT TOP (20)
    transaction_id,
    type_transaction,
    montant,
    sens

FROM staging.transactions

WHERE montant IS NULL
   OR montant = 0

   OR
   (
       sens = N'Débit'
       AND montant >= 0
   )

   OR
   (
       sens = N'Crédit'
       AND montant <= 0
   )

   OR sens IS NULL

   OR sens NOT IN
      (
          N'Débit',
          N'Crédit'
      )

ORDER BY transaction_id;
GO


/* ============================================================
   10. CONTRÔLER LES FRAIS
   ============================================================ */

/* ------------------------------------------------------------
   Dans le fichier :

   - les frais ne peuvent pas être négatifs ;
   - les frais positifs concernent les opérations
     « Frais bancaires » ;
   - les opérations « Frais bancaires » doivent avoir
     des frais strictement positifs.
   ------------------------------------------------------------ */
DECLARE @frais_negatifs_ou_absents INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE frais IS NULL
       OR frais < 0
);

DECLARE @frais_hors_operation_bancaire INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE frais > 0
      AND type_transaction <> N'Frais bancaires'
);

DECLARE @operations_frais_sans_frais INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE type_transaction = N'Frais bancaires'
      AND
      (
          frais IS NULL
          OR frais <= 0
      )
);

DECLARE @operations_avec_frais INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE frais > 0
);


SELECT
    @operations_avec_frais
        AS operations_avec_frais,

    @frais_negatifs_ou_absents
        AS frais_negatifs_ou_absents,

    @frais_hors_operation_bancaire
        AS frais_hors_operation_bancaire,

    @operations_frais_sans_frais
        AS operations_frais_sans_frais,

    CASE
        WHEN @frais_negatifs_ou_absents = 0
         AND @frais_hors_operation_bancaire = 0
         AND @operations_frais_sans_frais = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Les ',
            @operations_avec_frais,
            N' opérations comportant des frais correspondent ',
            N'toutes au type « Frais bancaires ».'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @frais_negatifs_ou_absents,
            N' frais sont invalides, ',
            @frais_hors_operation_bancaire,
            N' frais sont associés au mauvais type et ',
            @operations_frais_sans_frais,
            N' opérations de frais n’ont aucun frais.'
        )
    END AS conclusion;
GO


/* ============================================================
   11. CONTRÔLER LES DOMAINES DE VALEURS
   ============================================================ */

DECLARE @types_inconnus INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE type_transaction IS NULL

       OR type_transaction NOT IN
       (
           N'Paiement carte',
           N'Prélèvement',
           N'Virement reçu',
           N'Virement émis',
           N'Retrait DAB',
           N'Remboursement',
           N'Frais bancaires',
           N'Dépôt'
       )
);

DECLARE @canaux_inconnus INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE canal IS NULL

       OR canal NOT IN
       (
           N'Application mobile',
           N'TPE',
           N'Web',
           N'DAB',
           N'Agence'
       )
);

DECLARE @statuts_inconnus INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE statut IS NULL

       OR statut NOT IN
       (
           N'Validée',
           N'Rejetée',
           N'En attente'
       )
);

DECLARE @devises_inconnues INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE devise IS NULL
       OR devise <> N'EUR'
);


SELECT
    @types_inconnus AS types_inconnus,
    @canaux_inconnus AS canaux_inconnus,
    @statuts_inconnus AS statuts_inconnus,
    @devises_inconnues AS devises_inconnues,

    CASE
        WHEN @types_inconnus = 0
         AND @canaux_inconnus = 0
         AND @statuts_inconnus = 0
         AND @devises_inconnues = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Tous les types, canaux, statuts ',
            N'et devises appartiennent aux catégories attendues.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @types_inconnus,
            N' type(s), ',
            @canaux_inconnus,
            N' canal(aux), ',
            @statuts_inconnus,
            N' statut(s) et ',
            @devises_inconnues,
            N' devise(s) sont inconnus.'
        )
    END AS conclusion;
GO


/* Affiche les éventuelles catégories inconnues. */
SELECT TOP (20)
    transaction_id,
    type_transaction,
    sens,
    canal,
    statut,
    devise

FROM staging.transactions

WHERE type_transaction IS NULL

   OR type_transaction NOT IN
   (
       N'Paiement carte',
       N'Prélèvement',
       N'Virement reçu',
       N'Virement émis',
       N'Retrait DAB',
       N'Remboursement',
       N'Frais bancaires',
       N'Dépôt'
   )

   OR canal IS NULL

   OR canal NOT IN
   (
       N'Application mobile',
       N'TPE',
       N'Web',
       N'DAB',
       N'Agence'
   )

   OR statut IS NULL

   OR statut NOT IN
   (
       N'Validée',
       N'Rejetée',
       N'En attente'
   )

   OR devise IS NULL
   OR devise <> N'EUR'

ORDER BY transaction_id;
GO


/* ============================================================
   12. CONTRÔLER LES DATES
   ============================================================ */

DECLARE @dates_nulles_staging INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE date_transaction IS NULL
);

DECLARE @premiere_transaction DATETIME2(0) =
(
    SELECT MIN(date_transaction)
    FROM staging.transactions
);

DECLARE @derniere_transaction DATETIME2(0) =
(
    SELECT MAX(date_transaction)
    FROM staging.transactions
);


SELECT
    @dates_nulles_staging
        AS dates_nulles_staging,

    @premiere_transaction
        AS premiere_transaction_valide,

    @derniere_transaction
        AS derniere_transaction_valide,

    CASE
        WHEN @dates_nulles_staging = 40
        THEN CONCAT(
            N'CONCLUSION : OK. Les ',
            @dates_nulles_staging,
            N' dates impossibles sont conservées sous forme de NULL. ',
            N'Les dates valides vont du ',
            CONVERT(
                NVARCHAR(19),
                @premiere_transaction,
                120
            ),
            N' au ',
            CONVERT(
                NVARCHAR(19),
                @derniere_transaction,
                120
            ),
            N'.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @dates_nulles_staging,
            N' transactions ont une date NULL.'
        )
    END AS conclusion;
GO


/* Montre les dates impossibles avant et après nettoyage. */
SELECT TOP (40)
    r.transaction_id,

    r.date_transaction
        AS date_source_impossible,

    s.date_transaction
        AS date_apres_nettoyage

FROM raw.transactions AS r

INNER JOIN staging.transactions AS s
    ON NULLIF(TRIM(r.transaction_id), N'')
       = s.transaction_id

WHERE NULLIF(TRIM(r.date_transaction), N'') IS NOT NULL

  AND TRY_CONVERT(
          DATETIME2(0),
          TRIM(r.date_transaction),
          120
      ) IS NULL

ORDER BY s.transaction_id;
GO


/* ============================================================
   13. CONTRÔLER LE FORMAT DES IDENTIFIANTS
   ============================================================ */

/* ------------------------------------------------------------
   Formats attendus :

   transaction_id → T suivi de 9 chiffres.
   client_id      → C suivi de 6 chiffres.
   produit_id     → P suivi de 3 chiffres, ou NULL.
   agence_id      → A suivi de 3 chiffres, ou NULL.
   ------------------------------------------------------------ */
DECLARE @transaction_id_invalides INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE transaction_id IS NULL

       OR LEN(transaction_id) <> 10

       OR transaction_id
          NOT LIKE N'T[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
);

DECLARE @client_id_invalides INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE client_id IS NULL

       OR LEN(client_id) <> 7

       OR client_id
          NOT LIKE N'C[0-9][0-9][0-9][0-9][0-9][0-9]'
);

DECLARE @produit_id_invalides INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE produit_id IS NOT NULL

      AND
      (
          LEN(produit_id) <> 4

          OR produit_id
             NOT LIKE N'P[0-9][0-9][0-9]'
      )
);

DECLARE @agence_id_invalides INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE agence_id IS NOT NULL

      AND
      (
          LEN(agence_id) <> 4

          OR agence_id
             NOT LIKE N'A[0-9][0-9][0-9]'
      )
);


SELECT
    @transaction_id_invalides
        AS transaction_id_invalides,

    @client_id_invalides
        AS client_id_invalides,

    @produit_id_invalides
        AS produit_id_invalides,

    @agence_id_invalides
        AS agence_id_invalides,

    CASE
        WHEN @transaction_id_invalides = 0
         AND @client_id_invalides = 0
         AND @produit_id_invalides = 0
         AND @agence_id_invalides = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Tous les identifiants renseignés ',
            N'respectent leur format attendu.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @transaction_id_invalides,
            N' transaction_id, ',
            @client_id_invalides,
            N' client_id, ',
            @produit_id_invalides,
            N' produit_id et ',
            @agence_id_invalides,
            N' agence_id ont un format incorrect.'
        )
    END AS conclusion;
GO


/* ============================================================
   14. CONTRÔLER LES CARACTÈRES MAL ENCODÉS
   ============================================================ */

DECLARE @encodages_incorrects INT =
(
    SELECT COUNT(*)

    FROM staging.transactions

    WHERE CONCAT(
        type_transaction,
        sens,
        canal,
        statut,
        devise
    ) LIKE N'%├%'

    OR CONCAT(
        type_transaction,
        sens,
        canal,
        statut,
        devise
    ) LIKE N'%√%'

    OR CONCAT(
        type_transaction,
        sens,
        canal,
        statut,
        devise
    ) LIKE N'%Ã%'
);


SELECT
    @encodages_incorrects
        AS transactions_encodage_incorrect,

    CASE
        WHEN @encodages_incorrects = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Aucun caractère mal encodé connu ',
            N'ne reste dans staging.transactions.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @encodages_incorrects,
            N' transaction(s) contiennent encore un caractère incorrect.'
        )
    END AS conclusion;
GO


/* Affiche les éventuels textes mal encodés. */
SELECT TOP (20)
    transaction_id,
    type_transaction,
    sens,
    canal,
    statut

FROM staging.transactions

WHERE CONCAT(
        type_transaction,
        sens,
        canal,
        statut,
        devise
      ) LIKE N'%├%'

   OR CONCAT(
        type_transaction,
        sens,
        canal,
        statut,
        devise
      ) LIKE N'%√%'

   OR CONCAT(
        type_transaction,
        sens,
        canal,
        statut,
        devise
      ) LIKE N'%Ã%'

ORDER BY transaction_id;
GO


/* ============================================================
   15. AFFICHER LA RÉPARTITION PAR SENS
   ============================================================ */

SELECT
    sens,
    COUNT(*) AS nombre_transactions,
    SUM(montant) AS montant_total,

    CONCAT(
        N'CONCLUSION : ',
        COUNT(*),
        N' transaction(s) sont classées en « ',
        sens,
        N' ».'
    ) AS conclusion

FROM staging.transactions

GROUP BY sens

ORDER BY sens;
GO


/* ============================================================
   16. AFFICHER LA RÉPARTITION PAR STATUT
   ============================================================ */

SELECT
    statut,
    COUNT(*) AS nombre_transactions,

    CONCAT(
        N'CONCLUSION : ',
        COUNT(*),
        N' transaction(s) possèdent le statut « ',
        statut,
        N' ».'
    ) AS conclusion

FROM staging.transactions

GROUP BY statut

ORDER BY statut;
GO


/* ============================================================
   17. AFFICHER LA RÉPARTITION PAR TYPE
   ============================================================ */

SELECT
    type_transaction,
    COUNT(*) AS nombre_transactions,
    SUM(montant) AS montant_total,
    SUM(frais) AS frais_totaux,

    CONCAT(
        N'CONCLUSION : ',
        COUNT(*),
        N' transaction(s) appartiennent au type « ',
        type_transaction,
        N' ».'
    ) AS conclusion

FROM staging.transactions

GROUP BY type_transaction

ORDER BY type_transaction;
GO


/* ============================================================
   18. AFFICHER UN AVANT / APRÈS
   ============================================================ */

/* ------------------------------------------------------------
   Cette requête montre des exemples de transactions ayant subi
   au moins une transformation importante :

   - date impossible devenue NULL ;
   - sens standardisé ;
   - statut standardisé ;
   - produit absent ;
   - agence inexistante devenue NULL.
   ------------------------------------------------------------ */
WITH raw_unique AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY NULLIF(TRIM(transaction_id), N'')
            ORDER BY TRY_CONVERT(INT, ligne_source)
        ) AS rang

    FROM raw.transactions
)

SELECT TOP (30)
    r.transaction_id,

    r.date_transaction AS date_avant,
    s.date_transaction AS date_apres,

    r.sens AS sens_avant,
    s.sens AS sens_apres,

    r.statut AS statut_avant,
    s.statut AS statut_apres,

    r.produit_id AS produit_avant,
    s.produit_id AS produit_apres,

    r.agence_id AS agence_avant,
    s.agence_id AS agence_apres

FROM raw_unique AS r

INNER JOIN staging.transactions AS s
    ON NULLIF(TRIM(r.transaction_id), N'')
       = s.transaction_id

WHERE r.rang = 1

  AND
  (
      TRY_CONVERT(
          DATETIME2(0),
          NULLIF(TRIM(r.date_transaction), N''),
          120
      ) IS NULL

      OR staging.fn_nettoyer_texte(r.sens)
             COLLATE Latin1_General_100_BIN2

         <> s.sens
            COLLATE Latin1_General_100_BIN2

      OR staging.fn_nettoyer_texte(r.statut)
             COLLATE Latin1_General_100_BIN2

         <> s.statut
            COLLATE Latin1_General_100_BIN2

      OR s.produit_id IS NULL

      OR s.agence_id IS NULL
  )

ORDER BY s.transaction_id;
GO


/* ============================================================
   19. AFFICHER UN APERÇU FINAL
   ============================================================ */

SELECT TOP (20)
    ligne_source,
    transaction_id,
    client_id,
    date_transaction,
    type_transaction,
    montant,
    sens,
    produit_id,
    agence_id,
    canal,
    statut,
    frais,
    devise

FROM staging.transactions

ORDER BY transaction_id;
GO


/* ============================================================
   20. RÉSUMÉ FINAL
   ============================================================ */

DECLARE @total_transactions_final INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
);

DECLARE @clients_distincts_final INT =
(
    SELECT COUNT(DISTINCT client_id)
    FROM staging.transactions
);

DECLARE @dates_nulles_final INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE date_transaction IS NULL
);

DECLARE @produits_null_final INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE produit_id IS NULL
);

DECLARE @agences_null_final INT =
(
    SELECT COUNT(*)
    FROM staging.transactions
    WHERE agence_id IS NULL
);


SELECT
    @total_transactions_final
        AS total_transactions,

    @clients_distincts_final
        AS clients_distincts,

    @dates_nulles_final
        AS dates_impossibles_null,

    @produits_null_final
        AS produits_absents_null,

    @agences_null_final
        AS agences_orphelines_null,

    CONCAT(
        N'CONCLUSION FINALE : staging.transactions contient ',
        @total_transactions_final,
        N' transactions uniques concernant ',
        @clients_distincts_final,
        N' clients. Les ',
        @dates_nulles_final,
        N' dates impossibles, ',
        @produits_null_final,
        N' produits absents et ',
        @agences_null_final,
        N' agences inexistantes sont identifiés par NULL.'
    ) AS conclusion;
GO


/* ============================================================
   CONCLUSION DU NETTOYAGE DE staging.transactions

   Résultats correspondant à transactions_raw.csv :

   1. Nombre de lignes
      - raw.transactions contient 15 150 lignes.
      - 150 transaction_id sont présents deux fois.
      - Les doublons sont strictement identiques, sauf pour
        leur numéro de ligne source.
      - staging.transactions contient 15 000 transactions uniques.

   2. Conversions
      - 0 montant impossible à convertir.
      - 0 frais impossible à convertir.
      - 0 numéro de ligne impossible à convertir.
      - 40 dates sont impossibles :

        2026-13-40 10:00:00

      - Ces dates ont été remplacées par NULL.
      - Les transactions correspondantes ont été conservées.

   3. Valeurs manquantes
      - 154 produit_id sont vides dans le fichier brut.
      - Après suppression des doublons, 150 transactions
        uniques restent sans produit.
      - Ces valeurs sont conservées sous forme de NULL.
      - Aucun produit n’a été inventé.

   4. Relations avec les clients
      - 0 client_id orphelin.
      - Tous les clients renseignés existent dans raw.clients.

   5. Relations avec les produits
      - 0 produit_id renseigné mais inexistant.
      - Les dix produits du référentiel sont utilisés.
      - Seules les 150 valeurs initialement absentes restent NULL.

   6. Relations avec les agences
      - 60 transactions sont rattachées à l’agence A999.
      - A999 n’existe pas dans raw.agences.
      - Ces 60 agence_id ont été remplacés par NULL.
      - Les transactions ont été conservées.

   7. Standardisation du sens
      - 197 valeurs « débit » ont été transformées en « Débit ».
      - 53 valeurs « crédit » ont été transformées en « Crédit ».
      - 250 sens ont donc été standardisés.

   8. Standardisation des statuts
      - 150 valeurs « validee » ont été transformées
        en « Validée ».
      - Aucun statut inconnu ne reste.

   9. Répartition finale des sens
      - Débit : 11 695 transactions.
      - Crédit : 3 305 transactions.
      - Tous les débits possèdent un montant négatif.
      - Tous les crédits possèdent un montant positif.
      - Aucun montant nul n’a été détecté.

   10. Répartition finale des statuts
       - Validée : 14 524 transactions.
       - Rejetée : 371 transactions.
       - En attente : 105 transactions.

   11. Types de transaction
       - Paiement carte : 5 777.
       - Prélèvement : 2 626.
       - Virement reçu : 1 787.
       - Virement émis : 1 477.
       - Retrait DAB : 1 033.
       - Remboursement : 910.
       - Frais bancaires : 782.
       - Dépôt : 608.

   12. Frais
       - Aucun frais négatif.
       - Les 782 transactions comportant des frais
         correspondent toutes au type « Frais bancaires ».
       - Aucun autre type de transaction ne comporte de frais.

   13. Période
       - La première transaction valide date du
         1er janvier 2023 à 01:20:23.
       - La dernière transaction valide date du
         29 juin 2026 à 23:38:18.

   14. Encodage
       - Les accents de Débit, Crédit, Prélèvement,
         Dépôt, Validée et Rejetée ont été corrigés.
       - Aucun caractère d’encodage incorrect connu ne reste.

   RÉSULTAT FINAL :

   staging.transactions contient 15 000 transactions uniques,
   correctement typées et standardisées.

   Les dates impossibles, produits absents et agences
   inexistantes sont clairement représentés par NULL,
   sans inventer de valeur ni supprimer les transactions.

   ÉTAPE 6 TERMINÉE :

   Les sept tables ont maintenant été nettoyées dans staging :

   - staging.agences
   - staging.clients
   - staging.credits
   - staging.objectifs_agences
   - staging.produits
   - staging.remboursements
   - staging.transactions

   La prochaine grande étape sera l’étape 7 :

   Construire le modèle analytique dans mart.
   ============================================================ */