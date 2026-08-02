/* ============================================================
   PROJET : Banque 360
   FICHIER : 06_nettoyage_staging_credits.sql

   ÉTAPE DU FICHIER :

   Étape 6 sur 8
   Nettoyer les données dans staging

   AVANCEMENT :

   Étapes 1 à 5 : TERMINÉES
   Étape 6 : EN COURS (partie 3/7)

   TABLE TRAITÉE :

   raw.credits → staging.credits

   OBJECTIF :

   - nettoyer les textes ;
   - corriger les caractères mal encodés ;
   - convertir les dates et les nombres ;
   - standardiser les types et les statuts de crédit ;
   - contrôler les doublons ;
   - remplacer les taux négatifs par NULL ;
   - remplacer les agences inexistantes par NULL ;
   - vérifier les relations avec les clients et les agences ;
   - contrôler la cohérence des montants, scores et dates ;
   - conserver les lignes originales dans raw.credits.

   TRAITEMENT DES ANOMALIES :

   Un taux négatif n’est pas transformé en taux positif,
   car cela reviendrait à inventer une valeur.

   Le taux devient donc NULL dans staging, tandis que sa valeur
   originale reste disponible dans raw.credits.

   Une agence inexistante, comme A999, devient également NULL
   dans staging afin de ne pas créer une fausse relation.

   Le crédit lui-même est conservé.

   RÉSULTATS ATTENDUS AVEC credits_raw.csv :

   - 600 lignes dans raw.credits ;
   - 600 lignes dans staging.credits ;
   - 0 conversion impossible ;
   - 0 credit_id dupliqué ;
   - 15 taux négatifs remplacés par NULL ;
   - 10 références A999 remplacées par NULL ;
   - 0 client introuvable ;
   - 20 types de crédit standardisés ;
   - 25 statuts standardisés ;
   - 0 date incohérente.
   ============================================================ */


USE Banque360;
GO


/* ============================================================
   1. RECRÉER staging.credits
   ============================================================ */

/* Supprime uniquement l’ancienne table nettoyée.

   raw.credits reste intacte et conserve les données originales. */
DROP TABLE IF EXISTS staging.credits;
GO


/* ------------------------------------------------------------
   Types utilisés :

   INT
   → nombre entier.

   DATE
   → date sans heure.

   DECIMAL(15,2)
   → montant avec deux chiffres après la virgule.

   DECIMAL(6,3)
   → taux avec trois chiffres après la virgule.

   NVARCHAR
   → texte acceptant les accents.
   ------------------------------------------------------------ */
CREATE TABLE staging.credits
(
    /* Numéro de la ligne dans le fichier CSV original. */
    ligne_source INT NULL,

    /* Identifiant unique du crédit. */
    credit_id NVARCHAR(20) NULL,

    /* Identifiant du client lié au crédit. */
    client_id NVARCHAR(20) NULL,

    /* Identifiant de l’agence liée au crédit.

       La valeur devient NULL lorsque l’agence n’existe pas. */
    agence_id NVARCHAR(20) NULL,

    /* Nature du financement :
       Prêt immobilier, personnel ou automobile. */
    type_credit NVARCHAR(100) NULL,

    /* Date à laquelle le crédit a été accordé. */
    date_octroi DATE NULL,

    /* Montant initial emprunté. */
    montant_initial DECIMAL(15,2) NULL,

    /* Taux annuel du crédit en pourcentage. */
    taux_annuel DECIMAL(6,3) NULL,

    /* Durée du crédit exprimée en mois. */
    duree_mois INT NULL,

    /* Mensualité théorique du crédit. */
    mensualite_theorique DECIMAL(15,2) NULL,

    /* Score de risque au moment de l’octroi. */
    score_risque_octroi INT NULL,

    /* Situation du crédit : En cours ou Terminé. */
    statut_credit NVARCHAR(50) NULL,

    /* Date de fin prévue du crédit. */
    date_fin_prevue DATE NULL
);
GO


/* ============================================================
   2. NETTOYER ET CONVERTIR LES DONNÉES
   ============================================================ */

/* ------------------------------------------------------------
   source_nettoyee est une CTE.

   Elle prépare les données avant leur insertion :

   - nettoyage des textes ;
   - correction des accents ;
   - conversion des dates ;
   - conversion des nombres.

   source_classee attribue ensuite un rang à chaque credit_id.

   ROW_NUMBER permet de ne conserver que la première occurrence
   si un doublon apparaissait dans le fichier.
   ------------------------------------------------------------ */
WITH source_nettoyee AS
(
    SELECT
        TRY_CONVERT(
            INT,
            NULLIF(TRIM(ligne_source), N'')
        ) AS ligne_source,

        staging.fn_nettoyer_texte(credit_id)
            AS credit_id,

        staging.fn_nettoyer_texte(client_id)
            AS client_id,

        staging.fn_nettoyer_texte(agence_id)
            AS agence_id,

        staging.fn_nettoyer_texte(type_credit)
            AS type_credit,

        /* 23 correspond au format AAAA-MM-JJ. */
        TRY_CONVERT(
            DATE,
            NULLIF(TRIM(date_octroi), N''),
            23
        ) AS date_octroi,

        TRY_CONVERT(
            DECIMAL(15,2),
            NULLIF(TRIM(montant_initial), N'')
        ) AS montant_initial,

        TRY_CONVERT(
            DECIMAL(6,3),
            NULLIF(TRIM(taux_annuel), N'')
        ) AS taux_annuel,

        TRY_CONVERT(
            INT,
            NULLIF(TRIM(duree_mois), N'')
        ) AS duree_mois,

        TRY_CONVERT(
            DECIMAL(15,2),
            NULLIF(TRIM(mensualite_theorique), N'')
        ) AS mensualite_theorique,

        TRY_CONVERT(
            INT,
            NULLIF(TRIM(score_risque_octroi), N'')
        ) AS score_risque_octroi,

        staging.fn_nettoyer_texte(statut_credit)
            AS statut_credit,

        TRY_CONVERT(
            DATE,
            NULLIF(TRIM(date_fin_prevue), N''),
            23
        ) AS date_fin_prevue

    FROM raw.credits
),

source_classee AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY
                CASE
                    WHEN credit_id IS NULL
                    THEN CONCAT(N'SANS_ID_', ligne_source)
                    ELSE credit_id
                END

            ORDER BY ligne_source
        ) AS rang_doublon

    FROM source_nettoyee
)


INSERT INTO staging.credits
(
    ligne_source,
    credit_id,
    client_id,
    agence_id,
    type_credit,
    date_octroi,
    montant_initial,
    taux_annuel,
    duree_mois,
    mensualite_theorique,
    score_risque_octroi,
    statut_credit,
    date_fin_prevue
)
SELECT
    s.ligne_source,
    s.credit_id,

    /* --------------------------------------------------------
       Le client_id est conservé uniquement s’il existe
       dans raw.clients.

       Aucun client orphelin n’est attendu dans ce fichier.
       -------------------------------------------------------- */
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM raw.clients AS c
            WHERE NULLIF(TRIM(c.client_id), N'') = s.client_id
        )
        THEN s.client_id
        ELSE NULL
    END AS client_id,

    /* --------------------------------------------------------
       L’agence est conservée uniquement si elle existe
       dans raw.agences.

       Les dix valeurs A999 deviennent donc NULL.

       Le crédit reste présent dans staging.
       -------------------------------------------------------- */
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM raw.agences AS a
            WHERE NULLIF(TRIM(a.agence_id), N'') = s.agence_id
        )
        THEN s.agence_id
        ELSE NULL
    END AS agence_id,

    /* Uniformise les trois types de crédit. */
    CASE UPPER(s.type_credit)
        WHEN N'PRÊT IMMOBILIER'
            THEN N'Prêt immobilier'

        WHEN N'PRÊT PERSONNEL'
            THEN N'Prêt personnel'

        WHEN N'PRÊT AUTOMOBILE'
            THEN N'Prêt automobile'

        ELSE s.type_credit
    END AS type_credit,

    s.date_octroi,
    s.montant_initial,

    /* --------------------------------------------------------
       Un taux négatif est impossible dans ce contexte.

       Il devient NULL plutôt que d’être transformé en valeur
       positive ou supprimé.

       La valeur originale reste dans raw.credits.
       -------------------------------------------------------- */
    CASE
        WHEN s.taux_annuel < 0 THEN NULL
        ELSE s.taux_annuel
    END AS taux_annuel,

    s.duree_mois,
    s.mensualite_theorique,
    s.score_risque_octroi,

    /* Uniformise les différentes écritures des statuts. */
    CASE UPPER(s.statut_credit)
        WHEN N'EN COURS'
            THEN N'En cours'

        WHEN N'TERMINÉ'
            THEN N'Terminé'

        ELSE s.statut_credit
    END AS statut_credit,

    s.date_fin_prevue

FROM source_classee AS s

/* Conserve uniquement la première occurrence du credit_id. */
WHERE s.rang_doublon = 1;
GO


/* ============================================================
   3. CONTRÔLER LE NOMBRE DE LIGNES
   ============================================================ */

DECLARE @lignes_raw INT =
(
    SELECT COUNT(*)
    FROM raw.credits
);

DECLARE @lignes_staging INT =
(
    SELECT COUNT(*)
    FROM staging.credits
);

SELECT
    @lignes_raw AS lignes_raw,
    @lignes_staging AS lignes_staging,

    CASE
        WHEN @lignes_raw = @lignes_staging
        THEN CONCAT(
            N'CONCLUSION : OK. Les ',
            @lignes_raw,
            N' crédits ont été chargés dans staging.credits ',
            N'sans perte de ligne.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. Il existe une différence de ',
            ABS(@lignes_raw - @lignes_staging),
            N' ligne(s) entre raw.credits et staging.credits.'
        )
    END AS conclusion;
GO


/* ============================================================
   4. CONTRÔLER LES CONVERSIONS
   ============================================================ */

/* Recherche les valeurs non vides impossibles à convertir. */
DECLARE @conversions_impossibles INT =
(
    SELECT COUNT(*)
    FROM raw.credits
    WHERE
    (
        NULLIF(TRIM(ligne_source), N'') IS NOT NULL
        AND TRY_CONVERT(INT, TRIM(ligne_source)) IS NULL
    )
    OR
    (
        NULLIF(TRIM(date_octroi), N'') IS NOT NULL
        AND TRY_CONVERT(DATE, TRIM(date_octroi), 23) IS NULL
    )
    OR
    (
        NULLIF(TRIM(montant_initial), N'') IS NOT NULL
        AND TRY_CONVERT(
                DECIMAL(15,2),
                TRIM(montant_initial)
            ) IS NULL
    )
    OR
    (
        NULLIF(TRIM(taux_annuel), N'') IS NOT NULL
        AND TRY_CONVERT(
                DECIMAL(6,3),
                TRIM(taux_annuel)
            ) IS NULL
    )
    OR
    (
        NULLIF(TRIM(duree_mois), N'') IS NOT NULL
        AND TRY_CONVERT(INT, TRIM(duree_mois)) IS NULL
    )
    OR
    (
        NULLIF(TRIM(mensualite_theorique), N'') IS NOT NULL
        AND TRY_CONVERT(
                DECIMAL(15,2),
                TRIM(mensualite_theorique)
            ) IS NULL
    )
    OR
    (
        NULLIF(TRIM(score_risque_octroi), N'') IS NOT NULL
        AND TRY_CONVERT(
                INT,
                TRIM(score_risque_octroi)
            ) IS NULL
    )
    OR
    (
        NULLIF(TRIM(date_fin_prevue), N'') IS NOT NULL
        AND TRY_CONVERT(
                DATE,
                TRIM(date_fin_prevue),
                23
            ) IS NULL
    )
);

SELECT
    @conversions_impossibles AS conversions_impossibles,

    CASE
        WHEN @conversions_impossibles = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Toutes les dates et tous les ',
            N'nombres ont été correctement convertis.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @conversions_impossibles,
            N' crédit(s) contiennent au moins une conversion impossible.'
        )
    END AS conclusion;
GO


/* Affiche jusqu’à 20 lignes présentant une conversion impossible. */
SELECT TOP (20)
    ligne_source,
    credit_id,
    date_octroi,
    montant_initial,
    taux_annuel,
    duree_mois,
    mensualite_theorique,
    score_risque_octroi,
    date_fin_prevue
FROM raw.credits
WHERE
(
    NULLIF(TRIM(ligne_source), N'') IS NOT NULL
    AND TRY_CONVERT(INT, TRIM(ligne_source)) IS NULL
)
OR
(
    NULLIF(TRIM(date_octroi), N'') IS NOT NULL
    AND TRY_CONVERT(DATE, TRIM(date_octroi), 23) IS NULL
)
OR
(
    NULLIF(TRIM(montant_initial), N'') IS NOT NULL
    AND TRY_CONVERT(
            DECIMAL(15,2),
            TRIM(montant_initial)
        ) IS NULL
)
OR
(
    NULLIF(TRIM(taux_annuel), N'') IS NOT NULL
    AND TRY_CONVERT(
            DECIMAL(6,3),
            TRIM(taux_annuel)
        ) IS NULL
)
OR
(
    NULLIF(TRIM(duree_mois), N'') IS NOT NULL
    AND TRY_CONVERT(INT, TRIM(duree_mois)) IS NULL
)
OR
(
    NULLIF(TRIM(mensualite_theorique), N'') IS NOT NULL
    AND TRY_CONVERT(
            DECIMAL(15,2),
            TRIM(mensualite_theorique)
        ) IS NULL
)
OR
(
    NULLIF(TRIM(score_risque_octroi), N'') IS NOT NULL
    AND TRY_CONVERT(
            INT,
            TRIM(score_risque_octroi)
        ) IS NULL
)
OR
(
    NULLIF(TRIM(date_fin_prevue), N'') IS NOT NULL
    AND TRY_CONVERT(
            DATE,
            TRIM(date_fin_prevue),
            23
        ) IS NULL
);
GO


/* ============================================================
   5. CONTRÔLER LES DOUBLONS
   ============================================================ */

DECLARE @credits_dupliques INT;
DECLARE @lignes_dupliquees INT;

SELECT
    @credits_dupliques = COUNT(*),

    @lignes_dupliquees =
        COALESCE(SUM(nombre_occurrences - 1), 0)

FROM
(
    SELECT
        NULLIF(TRIM(credit_id), N'') AS credit_id,
        COUNT(*) AS nombre_occurrences

    FROM raw.credits

    WHERE NULLIF(TRIM(credit_id), N'') IS NOT NULL

    GROUP BY NULLIF(TRIM(credit_id), N'')

    HAVING COUNT(*) > 1
) AS doublons;

SELECT
    @credits_dupliques AS identifiants_dupliques,
    @lignes_dupliquees AS lignes_dupliquees,

    CASE
        WHEN @credits_dupliques = 0
        THEN N'CONCLUSION : OK. Aucun credit_id en double.'

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @credits_dupliques,
            N' credit_id sont dupliqués, soit ',
            @lignes_dupliquees,
            N' ligne(s) supplémentaire(s).'
        )
    END AS conclusion;
GO


/* Affiche les éventuels credit_id dupliqués. */
SELECT
    NULLIF(TRIM(credit_id), N'') AS credit_id,
    COUNT(*) AS nombre_occurrences
FROM raw.credits
WHERE NULLIF(TRIM(credit_id), N'') IS NOT NULL
GROUP BY NULLIF(TRIM(credit_id), N'')
HAVING COUNT(*) > 1
ORDER BY nombre_occurrences DESC, credit_id;
GO


/* ============================================================
   6. CONTRÔLER LES VALEURS MANQUANTES DANS LE FICHIER SOURCE
   ============================================================ */

/* Une ligne est comptée une seule fois même si plusieurs
   champs sont absents. */
DECLARE @credits_source_incomplets INT =
(
    SELECT COUNT(*)
    FROM raw.credits
    WHERE NULLIF(TRIM(credit_id), N'') IS NULL
       OR NULLIF(TRIM(client_id), N'') IS NULL
       OR NULLIF(TRIM(agence_id), N'') IS NULL
       OR NULLIF(TRIM(type_credit), N'') IS NULL
       OR NULLIF(TRIM(date_octroi), N'') IS NULL
       OR NULLIF(TRIM(montant_initial), N'') IS NULL
       OR NULLIF(TRIM(taux_annuel), N'') IS NULL
       OR NULLIF(TRIM(duree_mois), N'') IS NULL
       OR NULLIF(TRIM(mensualite_theorique), N'') IS NULL
       OR NULLIF(TRIM(score_risque_octroi), N'') IS NULL
       OR NULLIF(TRIM(statut_credit), N'') IS NULL
       OR NULLIF(TRIM(date_fin_prevue), N'') IS NULL
);

SELECT
    @credits_source_incomplets AS credits_source_incomplets,

    CASE
        WHEN @credits_source_incomplets = 0
        THEN N'CONCLUSION : OK. Aucun champ du fichier source n’est vide.'

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @credits_source_incomplets,
            N' crédit(s) ont au moins un champ vide dans raw.credits.'
        )
    END AS conclusion;
GO


/* Affiche les éventuelles lignes incomplètes. */
SELECT TOP (20)
    *
FROM raw.credits
WHERE NULLIF(TRIM(credit_id), N'') IS NULL
   OR NULLIF(TRIM(client_id), N'') IS NULL
   OR NULLIF(TRIM(agence_id), N'') IS NULL
   OR NULLIF(TRIM(type_credit), N'') IS NULL
   OR NULLIF(TRIM(date_octroi), N'') IS NULL
   OR NULLIF(TRIM(montant_initial), N'') IS NULL
   OR NULLIF(TRIM(taux_annuel), N'') IS NULL
   OR NULLIF(TRIM(duree_mois), N'') IS NULL
   OR NULLIF(TRIM(mensualite_theorique), N'') IS NULL
   OR NULLIF(TRIM(score_risque_octroi), N'') IS NULL
   OR NULLIF(TRIM(statut_credit), N'') IS NULL
   OR NULLIF(TRIM(date_fin_prevue), N'') IS NULL;
GO


/* ============================================================
   7. CONTRÔLER LA STANDARDISATION DES TEXTES
   ============================================================ */

DECLARE @types_standardises INT =
(
    SELECT COUNT(*)
    FROM raw.credits AS r

    INNER JOIN staging.credits AS s
        ON NULLIF(TRIM(r.credit_id), N'') = s.credit_id

    WHERE
        ISNULL(
            staging.fn_nettoyer_texte(r.type_credit),
            N''
        )
        <>
        ISNULL(s.type_credit, N'')
);

DECLARE @statuts_standardises INT =
(
    SELECT COUNT(*)
    FROM raw.credits AS r

    INNER JOIN staging.credits AS s
        ON NULLIF(TRIM(r.credit_id), N'') = s.credit_id

    WHERE
        ISNULL(
            staging.fn_nettoyer_texte(r.statut_credit),
            N''
        )
        <>
        ISNULL(s.statut_credit, N'')
);

SELECT
    @types_standardises AS types_standardises,
    @statuts_standardises AS statuts_standardises,

    CONCAT(
        N'CONCLUSION : ',
        @types_standardises,
        N' type(s) de crédit et ',
        @statuts_standardises,
        N' statut(s) ont été standardisés.'
    ) AS conclusion;
GO


/* Affiche les différentes catégories après standardisation. */
SELECT
    type_credit,
    statut_credit,
    COUNT(*) AS nombre_credits
FROM staging.credits
GROUP BY
    type_credit,
    statut_credit
ORDER BY
    type_credit,
    statut_credit;
GO


/* ============================================================
   8. CONTRÔLER LES TAUX NÉGATIFS
   ============================================================ */

DECLARE @taux_negatifs_source INT =
(
    SELECT COUNT(*)
    FROM raw.credits
    WHERE TRY_CONVERT(
              DECIMAL(6,3),
              NULLIF(TRIM(taux_annuel), N'')
          ) < 0
);

DECLARE @taux_negatifs_staging INT =
(
    SELECT COUNT(*)
    FROM staging.credits
    WHERE taux_annuel < 0
);

DECLARE @taux_devenus_null INT =
(
    SELECT COUNT(*)
    FROM staging.credits
    WHERE taux_annuel IS NULL
);

SELECT
    @taux_negatifs_source AS taux_negatifs_source,
    @taux_negatifs_staging AS taux_negatifs_staging,
    @taux_devenus_null AS taux_remplaces_par_null,

    CASE
        WHEN @taux_negatifs_source > 0
         AND @taux_negatifs_staging = 0
         AND @taux_devenus_null = @taux_negatifs_source
        THEN CONCAT(
            N'CONCLUSION : OK. Les ',
            @taux_negatifs_source,
            N' taux négatifs ont été remplacés par NULL.'
        )

        WHEN @taux_negatifs_source = 0
        THEN N'CONCLUSION : aucun taux négatif dans le fichier source.'

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. Le traitement des taux ',
            N'négatifs doit être vérifié.'
        )
    END AS conclusion;
GO


/* Affiche les 15 taux négatifs avant et après nettoyage. */
SELECT
    r.credit_id,

    TRY_CONVERT(
        DECIMAL(6,3),
        TRIM(r.taux_annuel)
    ) AS taux_source_negatif,

    s.taux_annuel AS taux_apres_nettoyage

FROM raw.credits AS r

INNER JOIN staging.credits AS s
    ON NULLIF(TRIM(r.credit_id), N'') = s.credit_id

WHERE TRY_CONVERT(
          DECIMAL(6,3),
          NULLIF(TRIM(r.taux_annuel), N'')
      ) < 0

ORDER BY r.credit_id;
GO


/* ============================================================
   9. CONTRÔLER LES AGENCES INEXISTANTES
   ============================================================ */

DECLARE @agences_orphelines_source INT =
(
    SELECT COUNT(*)
    FROM raw.credits AS c

    WHERE NULLIF(TRIM(c.agence_id), N'') IS NOT NULL

      AND NOT EXISTS
      (
          SELECT 1
          FROM raw.agences AS a
          WHERE NULLIF(TRIM(a.agence_id), N'')
                = NULLIF(TRIM(c.agence_id), N'')
      )
);

DECLARE @agences_null_staging INT =
(
    SELECT COUNT(*)
    FROM staging.credits
    WHERE agence_id IS NULL
);

SELECT
    @agences_orphelines_source AS agences_orphelines_source,
    @agences_null_staging AS agences_remplacees_par_null,

    CASE
        WHEN @agences_orphelines_source = @agences_null_staging
         AND @agences_orphelines_source > 0
        THEN CONCAT(
            N'CONCLUSION : OK. Les ',
            @agences_orphelines_source,
            N' références vers une agence inexistante ont été ',
            N'remplacées par NULL sans supprimer les crédits.'
        )

        WHEN @agences_orphelines_source = 0
        THEN N'CONCLUSION : toutes les agences du fichier source existent.'

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. Le traitement des agences ',
            N'orphelines doit être vérifié.'
        )
    END AS conclusion;
GO


/* Affiche les agences inexistantes avant et après nettoyage. */
SELECT
    r.credit_id,
    r.agence_id AS agence_source_inexistante,
    s.agence_id AS agence_apres_nettoyage

FROM raw.credits AS r

INNER JOIN staging.credits AS s
    ON NULLIF(TRIM(r.credit_id), N'') = s.credit_id

WHERE NULLIF(TRIM(r.agence_id), N'') IS NOT NULL

  AND NOT EXISTS
  (
      SELECT 1
      FROM raw.agences AS a
      WHERE NULLIF(TRIM(a.agence_id), N'')
            = NULLIF(TRIM(r.agence_id), N'')
  )

ORDER BY r.credit_id;
GO


/* ============================================================
   10. CONTRÔLER LES CLIENTS INEXISTANTS
   ============================================================ */

DECLARE @clients_orphelins INT =
(
    SELECT COUNT(*)
    FROM raw.credits AS cr

    WHERE NULLIF(TRIM(cr.client_id), N'') IS NOT NULL

      AND NOT EXISTS
      (
          SELECT 1
          FROM raw.clients AS cl
          WHERE NULLIF(TRIM(cl.client_id), N'')
                = NULLIF(TRIM(cr.client_id), N'')
      )
);

SELECT
    @clients_orphelins AS clients_orphelins,

    CASE
        WHEN @clients_orphelins = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Tous les crédits sont rattachés ',
            N'à un client existant.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @clients_orphelins,
            N' crédit(s) sont rattachés à un client inexistant.'
        )
    END AS conclusion;
GO


/* Affiche jusqu’à 20 éventuels clients inexistants. */
SELECT TOP (20)
    cr.credit_id,
    cr.client_id
FROM raw.credits AS cr
WHERE NULLIF(TRIM(cr.client_id), N'') IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM raw.clients AS cl
      WHERE NULLIF(TRIM(cl.client_id), N'')
            = NULLIF(TRIM(cr.client_id), N'')
  )
ORDER BY cr.credit_id;
GO


/* ============================================================
   11. CONTRÔLER LES VALEURS NUMÉRIQUES
   ============================================================ */

/* Recherche :

   - un montant initial nul ou négatif ;
   - un taux encore négatif ;
   - une durée nulle ou négative ;
   - une mensualité nulle ou négative ;
   - un score inférieur à 0 ou supérieur à 100.

   Les taux devenus NULL ne sont pas considérés comme une
   nouvelle anomalie : ils ont déjà été documentés.
*/
DECLARE @valeurs_numeriques_invalides INT =
(
    SELECT COUNT(*)
    FROM staging.credits
    WHERE montant_initial IS NULL
       OR montant_initial <= 0

       OR taux_annuel < 0

       OR duree_mois IS NULL
       OR duree_mois <= 0

       OR mensualite_theorique IS NULL
       OR mensualite_theorique <= 0

       OR score_risque_octroi IS NULL
       OR score_risque_octroi < 0
       OR score_risque_octroi > 100
);

SELECT
    @valeurs_numeriques_invalides AS valeurs_numeriques_invalides,

    CASE
        WHEN @valeurs_numeriques_invalides = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Les montants, durées, mensualités ',
            N'et scores sont cohérents.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @valeurs_numeriques_invalides,
            N' crédit(s) ont encore une valeur numérique incohérente.'
        )
    END AS conclusion;
GO


/* Affiche les éventuelles valeurs numériques incohérentes. */
SELECT TOP (20)
    credit_id,
    montant_initial,
    taux_annuel,
    duree_mois,
    mensualite_theorique,
    score_risque_octroi
FROM staging.credits
WHERE montant_initial IS NULL
   OR montant_initial <= 0
   OR taux_annuel < 0
   OR duree_mois IS NULL
   OR duree_mois <= 0
   OR mensualite_theorique IS NULL
   OR mensualite_theorique <= 0
   OR score_risque_octroi IS NULL
   OR score_risque_octroi < 0
   OR score_risque_octroi > 100
ORDER BY credit_id;
GO


/* ============================================================
   12. CONTRÔLER LA COHÉRENCE DES DATES
   ============================================================ */

/* ------------------------------------------------------------
   DATEADD(MONTH, duree_mois, date_octroi)

   ajoute la durée du crédit à la date d’octroi.

   Le résultat doit correspondre à date_fin_prevue.
   ------------------------------------------------------------ */
DECLARE @dates_incoherentes INT =
(
    SELECT COUNT(*)
    FROM staging.credits
    WHERE date_octroi IS NULL
       OR date_fin_prevue IS NULL
       OR date_fin_prevue <= date_octroi

       OR DATEADD(
              MONTH,
              duree_mois,
              date_octroi
          ) <> date_fin_prevue
);

SELECT
    @dates_incoherentes AS dates_incoherentes,

    CASE
        WHEN @dates_incoherentes = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Toutes les dates de fin correspondent ',
            N'à la date d’octroi augmentée de la durée du crédit.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @dates_incoherentes,
            N' crédit(s) ont des dates incohérentes.'
        )
    END AS conclusion;
GO


/* Affiche les éventuelles dates incohérentes. */
SELECT TOP (20)
    credit_id,
    date_octroi,
    duree_mois,

    DATEADD(
        MONTH,
        duree_mois,
        date_octroi
    ) AS date_fin_calculee,

    date_fin_prevue

FROM staging.credits

WHERE date_octroi IS NULL
   OR date_fin_prevue IS NULL
   OR date_fin_prevue <= date_octroi

   OR DATEADD(
          MONTH,
          duree_mois,
          date_octroi
      ) <> date_fin_prevue

ORDER BY credit_id;
GO


/* ============================================================
   13. CONTRÔLER LES TYPES ET STATUTS
   ============================================================ */

DECLARE @categories_inconnues INT =
(
    SELECT COUNT(*)
    FROM staging.credits
    WHERE type_credit IS NULL

       OR type_credit NOT IN
       (
           N'Prêt immobilier',
           N'Prêt personnel',
           N'Prêt automobile'
       )

       OR statut_credit IS NULL

       OR statut_credit NOT IN
       (
           N'En cours',
           N'Terminé'
       )
);

SELECT
    @categories_inconnues AS categories_inconnues,

    CASE
        WHEN @categories_inconnues = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Tous les types et statuts de crédit ',
            N'appartiennent aux catégories attendues.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @categories_inconnues,
            N' crédit(s) ont un type ou un statut inconnu.'
        )
    END AS conclusion;
GO


/* Affiche la répartition finale par type de crédit. */
SELECT
    type_credit,
    COUNT(*) AS nombre_credits,

    CONCAT(
        N'CONCLUSION : ',
        COUNT(*),
        N' crédit(s) appartiennent à la catégorie ',
        type_credit,
        N'.'
    ) AS conclusion

FROM staging.credits

GROUP BY type_credit

ORDER BY type_credit;
GO


/* Affiche la répartition finale par statut. */
SELECT
    statut_credit,
    COUNT(*) AS nombre_credits,

    CONCAT(
        N'CONCLUSION : ',
        COUNT(*),
        N' crédit(s) ont le statut ',
        statut_credit,
        N'.'
    ) AS conclusion

FROM staging.credits

GROUP BY statut_credit

ORDER BY statut_credit;
GO


/* ============================================================
   14. CONTRÔLER LES CARACTÈRES MAL ENCODÉS
   ============================================================ */

DECLARE @encodages_incorrects INT =
(
    SELECT COUNT(*)
    FROM staging.credits
    WHERE CONCAT(
        type_credit,
        statut_credit
    ) LIKE N'%├%'

    OR CONCAT(
        type_credit,
        statut_credit
    ) LIKE N'%√%'

    OR CONCAT(
        type_credit,
        statut_credit
    ) LIKE N'%Ã%'
);

SELECT
    @encodages_incorrects AS credits_encodage_incorrect,

    CASE
        WHEN @encodages_incorrects = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Aucun caractère mal encodé connu ',
            N'ne reste dans staging.credits.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @encodages_incorrects,
            N' crédit(s) contiennent encore un caractère incorrect.'
        )
    END AS conclusion;
GO


/* Affiche les éventuels textes encore mal encodés. */
SELECT TOP (20)
    credit_id,
    type_credit,
    statut_credit
FROM staging.credits
WHERE CONCAT(
        type_credit,
        statut_credit
      ) LIKE N'%├%'

   OR CONCAT(
        type_credit,
        statut_credit
      ) LIKE N'%√%'

   OR CONCAT(
        type_credit,
        statut_credit
      ) LIKE N'%Ã%'

ORDER BY credit_id;
GO


/* ============================================================
   15. AFFICHER UN AVANT / APRÈS
   ============================================================ */

/* Affiche 20 crédits dont le texte, le taux ou l’agence
   a été modifié pendant le nettoyage. */
SELECT TOP (20)
    r.credit_id,

    r.type_credit AS type_avant,
    s.type_credit AS type_apres,

    r.statut_credit AS statut_avant,
    s.statut_credit AS statut_apres,

    r.taux_annuel AS taux_avant,
    s.taux_annuel AS taux_apres,

    r.agence_id AS agence_avant,
    s.agence_id AS agence_apres

FROM raw.credits AS r

INNER JOIN staging.credits AS s
    ON NULLIF(TRIM(r.credit_id), N'') = s.credit_id

WHERE
    ISNULL(TRIM(r.type_credit), N'')
        <> ISNULL(s.type_credit, N'')

    OR ISNULL(TRIM(r.statut_credit), N'')
        <> ISNULL(s.statut_credit, N'')

    OR
    (
        TRY_CONVERT(
            DECIMAL(6,3),
            NULLIF(TRIM(r.taux_annuel), N'')
        ) < 0
    )

    OR s.agence_id IS NULL

ORDER BY s.credit_id;
GO


/* ============================================================
   16. AFFICHER UN APERÇU FINAL
   ============================================================ */

SELECT TOP (20)
    ligne_source,
    credit_id,
    client_id,
    agence_id,
    type_credit,
    date_octroi,
    montant_initial,
    taux_annuel,
    duree_mois,
    mensualite_theorique,
    score_risque_octroi,
    statut_credit,
    date_fin_prevue

FROM staging.credits

ORDER BY credit_id;
GO


/* Résumé final du nombre de crédits. */
DECLARE @total_credits_final INT =
(
    SELECT COUNT(*)
    FROM staging.credits
);

SELECT
    @total_credits_final AS total_credits_final,

    CONCAT(
        N'CONCLUSION FINALE : staging.credits contient ',
        @total_credits_final,
        N' crédits nettoyés et correctement typés.'
    ) AS conclusion;
GO


/* ============================================================
   CONCLUSION DU NETTOYAGE DE staging.credits

   Résultats correspondant à credits_raw.csv :

   1. Nombre de lignes
      - raw.credits contient 600 lignes.
      - staging.credits contient 600 lignes.
      - Aucun crédit n’a été supprimé.

   2. Conversions
      - 0 conversion impossible.
      - Les dates, montants, taux, durées, mensualités et scores
        ont été convertis dans leurs véritables types SQL.

   3. Doublons
      - 0 credit_id dupliqué.
      - Les 600 crédits possèdent un identifiant unique.

   4. Valeurs manquantes
      - Aucun champ n’est vide dans le fichier source.

   5. Standardisation
      - 20 types de crédit écrits entièrement en majuscules
        ont été standardisés.
      - 25 statuts « en cours » écrits en minuscules ont été
        transformés en « En cours ».
      - Les caractères accentués de « Prêt » et « Terminé »
        ont été corrigés.

   6. Taux annuels
      - 15 taux négatifs ont été détectés.
      - Ils ont été remplacés par NULL dans staging.
      - Les valeurs originales restent dans raw.credits.
      - Aucun taux négatif ne reste dans staging.credits.

   7. Relations avec les agences
      - 10 crédits étaient rattachés à l’agence inexistante A999.
      - Leur agence_id a été remplacé par NULL.
      - Les crédits ont été conservés.

   8. Relations avec les clients
      - 0 client introuvable.
      - Tous les crédits sont liés à un client existant.

   9. Cohérence des nombres
      - Tous les montants initiaux sont positifs.
      - Toutes les durées sont positives.
      - Toutes les mensualités sont positives.
      - Tous les scores sont compris entre 0 et 100.

   10. Cohérence des dates
       - 0 date incohérente.
       - Chaque date de fin correspond à la date d’octroi
         augmentée de la durée du crédit.

   RÉSULTAT FINAL :

   staging.credits contient 600 crédits nettoyés,
   standardisés et correctement typés.

   Les 15 taux incorrects et les 10 agences inexistantes
   sont clairement identifiés par des valeurs NULL,
   sans suppression des crédits concernés.
   ============================================================ */