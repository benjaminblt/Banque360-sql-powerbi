/* ============================================================
   PROJET : Banque 360
   FICHIER : 09_nettoyage_staging_remboursements.sql

   ÉTAPE DU FICHIER :

   Étape 6 sur 8
   Nettoyer les données dans staging

   AVANCEMENT :

   Étapes 1 à 5 : TERMINÉES
   Étape 6 : EN COURS (partie 6/7)

   TABLE TRAITÉE :

   raw.remboursements → staging.remboursements

   GRAIN DE LA TABLE :

   Une ligne représente une échéance de remboursement
   associée à un crédit.

   La clé métier est :

   remboursement_id

   OBJECTIF :

   - nettoyer les textes et les espaces ;
   - corriger les caractères mal encodés ;
   - convertir les dates et les nombres ;
   - standardiser les statuts de remboursement ;
   - vérifier l’unicité des remboursements ;
   - remplacer les paiements négatifs par NULL ;
   - remplacer les crédits inexistants par NULL ;
   - vérifier la cohérence entre les échéances, les paiements
     et les jours de retard ;
   - conserver toutes les lignes et garder raw intacte.

   RÈGLES DE NETTOYAGE :

   Un paiement négatif ne devient pas positif, car cela
   reviendrait à inventer une donnée.

   Le montant devient donc NULL dans staging, tandis que
   la valeur originale reste disponible dans raw.

   Une référence vers un crédit inexistant devient également
   NULL sans supprimer l’échéance concernée.

   Le statut est recalculé à partir des informations fiables :

   - aucun paiement et montant payé égal à 0 → Impayé ;
   - jours_retard supérieur à 0 → Payé en retard ;
   - jours_retard égal à 0 → Payé à temps.

   RÉSULTATS ATTENDUS AVEC remboursements_raw.csv :

   - 18 899 lignes dans raw.remboursements ;
   - 18 899 lignes dans staging.remboursements ;
   - 0 conversion impossible ;
   - 0 remboursement_id dupliqué ;
   - 20 paiements négatifs remplacés par NULL ;
   - 25 références CR999999 remplacées par NULL ;
   - 40 statuts non standardisés corrigés ;
   - 103 échéances impayées ;
   - 121 paiements partiels ;
   - 0 incohérence entre les dates et les jours de retard.
   ============================================================ */


USE Banque360;
GO


/* ============================================================
   1. RECRÉER staging.remboursements
   ============================================================ */

/* Supprime uniquement l’ancienne version nettoyée.

   raw.remboursements reste inchangée. */
DROP TABLE IF EXISTS staging.remboursements;
GO


/* ------------------------------------------------------------
   TYPES DES COLONNES :

   NVARCHAR
   → texte acceptant les caractères Unicode.

   DATE
   → véritable date SQL sans heure.

   DECIMAL(15,2)
   → montant avec deux chiffres après la virgule.

   INT
   → nombre entier.
   ------------------------------------------------------------ */
CREATE TABLE staging.remboursements
(
    /* Identifiant unique de l’échéance. */
    remboursement_id NVARCHAR(20) NULL,

    /* Identifiant du crédit concerné.

       La valeur devient NULL si le crédit n’existe pas. */
    credit_id NVARCHAR(20) NULL,

    /* Date à laquelle le remboursement était attendu. */
    date_echeance DATE NULL,

    /* Date réelle du paiement.

       La valeur reste NULL lorsque l’échéance est impayée. */
    date_paiement DATE NULL,

    /* Montant qui devait être remboursé. */
    montant_attendu DECIMAL(15,2) NULL,

    /* Montant réellement payé.

       Les montants négatifs deviennent NULL. */
    montant_paye DECIMAL(15,2) NULL,

    /* Nombre de jours de retard. */
    jours_retard INT NULL,

    /* Situation finale de l’échéance. */
    statut_remboursement NVARCHAR(50) NULL
);
GO


/* ============================================================
   2. NETTOYER ET CHARGER LES REMBOURSEMENTS
   ============================================================ */

/* ------------------------------------------------------------
   source_nettoyee est une CTE, c’est-à-dire un résultat
   intermédiaire utilisé par la requête INSERT.

   Elle permet de :

   - nettoyer les textes ;
   - convertir les dates ;
   - convertir les montants ;
   - convertir les jours de retard.

   Les règles métier sont ensuite appliquées dans le SELECT
   qui alimente staging.remboursements.
   ------------------------------------------------------------ */
   
WITH source_nettoyee AS
(
    SELECT
        /* Nettoie et met l’identifiant en majuscules. */
        UPPER(
            staging.fn_nettoyer_texte(remboursement_id)
        ) AS remboursement_id,

        /* Nettoie et met l’identifiant du crédit en majuscules. */
        UPPER(
            staging.fn_nettoyer_texte(credit_id)
        ) AS credit_id,

        /* 23 correspond au format de date AAAA-MM-JJ. */
        TRY_CONVERT(
            DATE,
            NULLIF(TRIM(date_echeance), N''),
            23
        ) AS date_echeance,

        /* Une date de paiement vide devient NULL. */
        TRY_CONVERT(
            DATE,
            NULLIF(TRIM(date_paiement), N''),
            23
        ) AS date_paiement,

        /* Convertit le montant attendu en nombre décimal. */
        TRY_CONVERT(
            DECIMAL(15,2),
            NULLIF(TRIM(montant_attendu), N'')
        ) AS montant_attendu,

        /* Convertit le montant payé en nombre décimal. */
        TRY_CONVERT(
            DECIMAL(15,2),
            NULLIF(TRIM(montant_paye), N'')
        ) AS montant_paye,

        /* Convertit le nombre de jours de retard en entier. */
        TRY_CONVERT(
            INT,
            NULLIF(TRIM(jours_retard), N'')
        ) AS jours_retard,

        /* Nettoie le statut et corrige les accents. */
        staging.fn_nettoyer_texte(statut_remboursement)
            AS statut_source

    FROM raw.remboursements
)


INSERT INTO staging.remboursements
(
    remboursement_id,
    credit_id,
    date_echeance,
    date_paiement,
    montant_attendu,
    montant_paye,
    jours_retard,
    statut_remboursement
)
SELECT
    s.remboursement_id,

    /* --------------------------------------------------------
       Le credit_id est conservé uniquement s’il existe
       dans la table raw.credits.

       Les références CR999999 deviennent donc NULL.

       L’échéance elle-même reste dans staging.
       -------------------------------------------------------- */
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM raw.credits AS c
            WHERE NULLIF(TRIM(c.credit_id), N'') = s.credit_id
        )
        THEN s.credit_id

        ELSE NULL
    END AS credit_id,

    s.date_echeance,
    s.date_paiement,
    s.montant_attendu,

    /* --------------------------------------------------------
       Un paiement négatif est une donnée invalide.

       Il devient NULL afin de ne pas inventer une correction.

       Sa valeur originale reste disponible dans raw.
       -------------------------------------------------------- */
    CASE
        WHEN s.montant_paye < 0 THEN NULL
        ELSE s.montant_paye
    END AS montant_paye,

    s.jours_retard,

    /* --------------------------------------------------------
       Le statut est standardisé à partir des données fiables.

       Un paiement peut être effectué avant l’échéance :
       dans ce cas, jours_retard vaut 0.

       Les variantes comme « paye a temps » sont donc corrigées,
       y compris lorsque les jours de retard montrent que le
       paiement était réellement en retard.
       -------------------------------------------------------- */
    CASE
        WHEN s.date_paiement IS NULL
          OR s.montant_paye = 0
            THEN N'Impayé'

        WHEN s.jours_retard > 0
            THEN N'Payé en retard'

        WHEN s.jours_retard = 0
            THEN N'Payé à temps'

        /* Traitement de secours si une information nécessaire
           au recalcul du statut était manquante. */
        ELSE
            CASE UPPER(s.statut_source)
                WHEN N'PAYÉ À TEMPS'
                    THEN N'Payé à temps'

                WHEN N'PAYE A TEMPS'
                    THEN N'Payé à temps'

                WHEN N'PAYÉ EN RETARD'
                    THEN N'Payé en retard'

                WHEN N'IMPAYÉ'
                    THEN N'Impayé'

                ELSE s.statut_source
            END
    END AS statut_remboursement

FROM source_nettoyee AS s;
GO


/* ============================================================
   3. CONTRÔLER LE NOMBRE DE LIGNES
   ============================================================ */

DECLARE @lignes_raw INT =
(
    SELECT COUNT(*)
    FROM raw.remboursements
);

DECLARE @lignes_staging INT =
(
    SELECT COUNT(*)
    FROM staging.remboursements
);

SELECT
    @lignes_raw AS lignes_raw,
    @lignes_staging AS lignes_staging,

    CASE
        WHEN @lignes_raw = @lignes_staging
        THEN CONCAT(
            N'CONCLUSION : OK. Les ',
            @lignes_raw,
            N' échéances ont été chargées dans ',
            N'staging.remboursements sans perte de ligne.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. Il existe une différence de ',
            ABS(@lignes_raw - @lignes_staging),
            N' ligne(s) entre raw et staging.'
        )
    END AS conclusion;
GO


/* ============================================================
   4. CONTRÔLER LES CONVERSIONS
   ============================================================ */

/* ------------------------------------------------------------
   La date de paiement peut être vide lorsqu’une échéance
   est impayée.

   Elle est considérée comme invalide uniquement lorsqu’elle
   est renseignée mais impossible à convertir.
   ------------------------------------------------------------ */
DECLARE @conversions_impossibles INT =
(
    SELECT COUNT(*)
    FROM raw.remboursements
    WHERE
    (
        NULLIF(TRIM(date_echeance), N'') IS NOT NULL

        AND TRY_CONVERT(
                DATE,
                TRIM(date_echeance),
                23
            ) IS NULL
    )

    OR
    (
        NULLIF(TRIM(date_paiement), N'') IS NOT NULL

        AND TRY_CONVERT(
                DATE,
                TRIM(date_paiement),
                23
            ) IS NULL
    )

    OR
    (
        NULLIF(TRIM(montant_attendu), N'') IS NOT NULL

        AND TRY_CONVERT(
                DECIMAL(15,2),
                TRIM(montant_attendu)
            ) IS NULL
    )

    OR
    (
        NULLIF(TRIM(montant_paye), N'') IS NOT NULL

        AND TRY_CONVERT(
                DECIMAL(15,2),
                TRIM(montant_paye)
            ) IS NULL
    )

    OR
    (
        NULLIF(TRIM(jours_retard), N'') IS NOT NULL

        AND TRY_CONVERT(
                INT,
                TRIM(jours_retard)
            ) IS NULL
    )
);

SELECT
    @conversions_impossibles AS conversions_impossibles,

    CASE
        WHEN @conversions_impossibles = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Toutes les dates, tous les montants ',
            N'et tous les jours de retard ont été correctement convertis.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @conversions_impossibles,
            N' échéance(s) contiennent au moins une conversion impossible.'
        )
    END AS conclusion;
GO


/* Affiche jusqu’à 20 conversions impossibles.

   Une table de résultat vide signifie qu’aucune erreur
   de conversion n’a été détectée. */
SELECT TOP (20)
    remboursement_id,
    credit_id,
    date_echeance,
    date_paiement,
    montant_attendu,
    montant_paye,
    jours_retard

FROM raw.remboursements

WHERE
(
    NULLIF(TRIM(date_echeance), N'') IS NOT NULL

    AND TRY_CONVERT(
            DATE,
            TRIM(date_echeance),
            23
        ) IS NULL
)

OR
(
    NULLIF(TRIM(date_paiement), N'') IS NOT NULL

    AND TRY_CONVERT(
            DATE,
            TRIM(date_paiement),
            23
        ) IS NULL
)

OR
(
    NULLIF(TRIM(montant_attendu), N'') IS NOT NULL

    AND TRY_CONVERT(
            DECIMAL(15,2),
            TRIM(montant_attendu)
        ) IS NULL
)

OR
(
    NULLIF(TRIM(montant_paye), N'') IS NOT NULL

    AND TRY_CONVERT(
            DECIMAL(15,2),
            TRIM(montant_paye)
        ) IS NULL
)

OR
(
    NULLIF(TRIM(jours_retard), N'') IS NOT NULL

    AND TRY_CONVERT(
            INT,
            TRIM(jours_retard)
        ) IS NULL
)

ORDER BY remboursement_id;
GO


/* ============================================================
   5. CONTRÔLER LES DOUBLONS
   ============================================================ */

/* ------------------------------------------------------------
   Un remboursement_id doit identifier une seule échéance.

   nombre_occurrences - 1
   → calcule le nombre de lignes supplémentaires.

   COALESCE
   → renvoie 0 lorsqu’aucun doublon n’existe.
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
        remboursement_id,
        COUNT(*) AS nombre_occurrences

    FROM staging.remboursements

    WHERE remboursement_id IS NOT NULL

    GROUP BY remboursement_id

    HAVING COUNT(*) > 1
) AS doublons;

SELECT
    @identifiants_dupliques AS identifiants_dupliques,
    @lignes_dupliquees AS lignes_dupliquees,

    CASE
        WHEN @identifiants_dupliques = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Aucun remboursement_id en double. ',
            N'Les 18 899 échéances possèdent un identifiant unique.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @identifiants_dupliques,
            N' remboursement_id sont dupliqués, soit ',
            @lignes_dupliquees,
            N' ligne(s) supplémentaire(s).'
        )
    END AS conclusion;
GO


/* Affiche les éventuels identifiants dupliqués. */
SELECT
    remboursement_id,
    COUNT(*) AS nombre_occurrences

FROM staging.remboursements

WHERE remboursement_id IS NOT NULL

GROUP BY remboursement_id

HAVING COUNT(*) > 1

ORDER BY
    nombre_occurrences DESC,
    remboursement_id;
GO


/* ============================================================
   6. CONTRÔLER LES VALEURS SOURCE MANQUANTES
   ============================================================ */

/* ------------------------------------------------------------
   date_paiement n’est pas obligatoire :

   une échéance impayée ne possède aucune date de paiement.

   Toutes les autres colonnes doivent être renseignées.
   ------------------------------------------------------------ */
DECLARE @lignes_source_incompletes INT =
(
    SELECT COUNT(*)

    FROM raw.remboursements

    WHERE NULLIF(TRIM(remboursement_id), N'') IS NULL
       OR NULLIF(TRIM(credit_id), N'') IS NULL
       OR NULLIF(TRIM(date_echeance), N'') IS NULL
       OR NULLIF(TRIM(montant_attendu), N'') IS NULL
       OR NULLIF(TRIM(montant_paye), N'') IS NULL
       OR NULLIF(TRIM(jours_retard), N'') IS NULL
       OR NULLIF(TRIM(statut_remboursement), N'') IS NULL
);

DECLARE @dates_paiement_absentes INT =
(
    SELECT COUNT(*)

    FROM raw.remboursements

    WHERE NULLIF(TRIM(date_paiement), N'') IS NULL
);

SELECT
    @lignes_source_incompletes AS lignes_source_incompletes,
    @dates_paiement_absentes AS dates_paiement_absentes,

    CASE
        WHEN @lignes_source_incompletes = 0
         AND @dates_paiement_absentes = 103
        THEN CONCAT(
            N'CONCLUSION : OK. Aucun champ obligatoire ne manque. ',
            N'Les ',
            @dates_paiement_absentes,
            N' dates de paiement absentes correspondent aux échéances impayées.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @lignes_source_incompletes,
            N' ligne(s) ont un champ obligatoire absent et ',
            @dates_paiement_absentes,
            N' date(s) de paiement sont absentes.'
        )
    END AS conclusion;
GO


/* Affiche les éventuelles lignes ayant un champ obligatoire vide. */
SELECT TOP (20)
    *

FROM raw.remboursements

WHERE NULLIF(TRIM(remboursement_id), N'') IS NULL
   OR NULLIF(TRIM(credit_id), N'') IS NULL
   OR NULLIF(TRIM(date_echeance), N'') IS NULL
   OR NULLIF(TRIM(montant_attendu), N'') IS NULL
   OR NULLIF(TRIM(montant_paye), N'') IS NULL
   OR NULLIF(TRIM(jours_retard), N'') IS NULL
   OR NULLIF(TRIM(statut_remboursement), N'') IS NULL;
GO


/* ============================================================
   7. CONTRÔLER LE FORMAT DES IDENTIFIANTS
   ============================================================ */

/* ------------------------------------------------------------
   Formats attendus :

   remboursement_id
   → R suivi de huit chiffres ;
   → exemple : R00000001.

   credit_id
   → CR suivi de six chiffres ;
   → exemple : CR000001.

   CR999999 respecte le format technique, même si le crédit
   correspondant n’existe pas.
   ------------------------------------------------------------ */
DECLARE @remboursement_id_invalides INT =
(
    SELECT COUNT(*)

    FROM raw.remboursements

    WHERE NULLIF(TRIM(remboursement_id), N'') IS NULL

       OR LEN(TRIM(remboursement_id)) <> 9

       OR TRIM(remboursement_id)
          NOT LIKE N'R[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
);

DECLARE @credit_id_invalides INT =
(
    SELECT COUNT(*)

    FROM raw.remboursements

    WHERE NULLIF(TRIM(credit_id), N'') IS NULL

       OR LEN(TRIM(credit_id)) <> 8

       OR TRIM(credit_id)
          NOT LIKE N'CR[0-9][0-9][0-9][0-9][0-9][0-9]'
);

SELECT
    @remboursement_id_invalides AS remboursement_id_invalides,
    @credit_id_invalides AS credit_id_invalides,

    CASE
        WHEN @remboursement_id_invalides = 0
         AND @credit_id_invalides = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Tous les identifiants respectent ',
            N'les formats R00000000 et CR000000.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @remboursement_id_invalides,
            N' remboursement_id et ',
            @credit_id_invalides,
            N' credit_id ont un format incorrect.'
        )
    END AS conclusion;
GO


/* Affiche les éventuels identifiants au mauvais format. */
SELECT TOP (20)
    remboursement_id,
    credit_id

FROM raw.remboursements

WHERE
(
    NULLIF(TRIM(remboursement_id), N'') IS NULL

    OR LEN(TRIM(remboursement_id)) <> 9

    OR TRIM(remboursement_id)
       NOT LIKE N'R[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
)

OR
(
    NULLIF(TRIM(credit_id), N'') IS NULL

    OR LEN(TRIM(credit_id)) <> 8

    OR TRIM(credit_id)
       NOT LIKE N'CR[0-9][0-9][0-9][0-9][0-9][0-9]'
)

ORDER BY remboursement_id;
GO


/* ============================================================
   8. CONTRÔLER LES PAIEMENTS NÉGATIFS
   ============================================================ */

/* ------------------------------------------------------------
   Les paiements négatifs sont comptés dans raw.

   On vérifie ensuite :

   - qu’aucun montant négatif ne reste dans staging ;
   - que chaque montant négatif est devenu NULL.
   ------------------------------------------------------------ */
DECLARE @paiements_negatifs_source INT =
(
    SELECT COUNT(*)

    FROM raw.remboursements

    WHERE TRY_CONVERT(
              DECIMAL(15,2),
              NULLIF(TRIM(montant_paye), N'')
          ) < 0
);

DECLARE @paiements_negatifs_staging INT =
(
    SELECT COUNT(*)

    FROM staging.remboursements

    WHERE montant_paye < 0
);

DECLARE @paiements_negatifs_corriges INT =
(
    SELECT COUNT(*)

    FROM raw.remboursements AS r

    INNER JOIN staging.remboursements AS s
        ON NULLIF(TRIM(r.remboursement_id), N'')
           = s.remboursement_id

    WHERE TRY_CONVERT(
              DECIMAL(15,2),
              NULLIF(TRIM(r.montant_paye), N'')
          ) < 0

      AND s.montant_paye IS NULL
);

SELECT
    @paiements_negatifs_source AS paiements_negatifs_source,
    @paiements_negatifs_staging AS paiements_negatifs_staging,
    @paiements_negatifs_corriges AS paiements_remplaces_par_null,

    CASE
        WHEN @paiements_negatifs_source
             = @paiements_negatifs_corriges

         AND @paiements_negatifs_staging = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Les ',
            @paiements_negatifs_source,
            N' paiements négatifs ont été remplacés par NULL. ',
            N'Aucun montant négatif ne reste dans staging.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. Le traitement des paiements ',
            N'négatifs doit être vérifié.'
        )
    END AS conclusion;
GO


/* Affiche les 20 paiements négatifs avant et après nettoyage. */
SELECT
    r.remboursement_id,
    r.credit_id,

    TRY_CONVERT(
        DECIMAL(15,2),
        TRIM(r.montant_attendu)
    ) AS montant_attendu,

    TRY_CONVERT(
        DECIMAL(15,2),
        TRIM(r.montant_paye)
    ) AS montant_negatif_source,

    s.montant_paye AS montant_apres_nettoyage

FROM raw.remboursements AS r

INNER JOIN staging.remboursements AS s
    ON NULLIF(TRIM(r.remboursement_id), N'')
       = s.remboursement_id

WHERE TRY_CONVERT(
          DECIMAL(15,2),
          NULLIF(TRIM(r.montant_paye), N'')
      ) < 0

ORDER BY r.remboursement_id;
GO


/* ============================================================
   9. CONTRÔLER LES CRÉDITS INEXISTANTS
   ============================================================ */

/* ------------------------------------------------------------
   NOT EXISTS recherche les remboursements dont le credit_id
   n’existe pas dans raw.credits.

   Le fichier contient 25 références CR999999.

   Ces références deviennent NULL dans staging, mais les
   échéances restent présentes.
   ------------------------------------------------------------ */
DECLARE @credits_orphelins_source INT =
(
    SELECT COUNT(*)

    FROM raw.remboursements AS r

    WHERE NULLIF(TRIM(r.credit_id), N'') IS NOT NULL

      AND NOT EXISTS
      (
          SELECT 1

          FROM raw.credits AS c

          WHERE NULLIF(TRIM(c.credit_id), N'')
                = NULLIF(TRIM(r.credit_id), N'')
      )
);

DECLARE @credits_orphelins_corriges INT =
(
    SELECT COUNT(*)

    FROM raw.remboursements AS r

    INNER JOIN staging.remboursements AS s
        ON NULLIF(TRIM(r.remboursement_id), N'')
           = s.remboursement_id

    WHERE NULLIF(TRIM(r.credit_id), N'') IS NOT NULL

      AND NOT EXISTS
      (
          SELECT 1

          FROM raw.credits AS c

          WHERE NULLIF(TRIM(c.credit_id), N'')
                = NULLIF(TRIM(r.credit_id), N'')
      )

      AND s.credit_id IS NULL
);

SELECT
    @credits_orphelins_source AS credits_orphelins_source,
    @credits_orphelins_corriges AS credits_remplaces_par_null,

    CASE
        WHEN @credits_orphelins_source
             = @credits_orphelins_corriges
        THEN CONCAT(
            N'CONCLUSION : OK. Les ',
            @credits_orphelins_source,
            N' références vers un crédit inexistant ont été ',
            N'remplacées par NULL sans supprimer les échéances.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. Le traitement des crédits ',
            N'orphelins doit être vérifié.'
        )
    END AS conclusion;
GO


/* Affiche les crédits inexistants avant et après nettoyage. */
SELECT
    r.remboursement_id,

    r.credit_id AS credit_source_inexistant,

    s.credit_id AS credit_apres_nettoyage,

    s.date_echeance,
    s.montant_attendu

FROM raw.remboursements AS r

INNER JOIN staging.remboursements AS s
    ON NULLIF(TRIM(r.remboursement_id), N'')
       = s.remboursement_id

WHERE NULLIF(TRIM(r.credit_id), N'') IS NOT NULL

  AND NOT EXISTS
  (
      SELECT 1

      FROM raw.credits AS c

      WHERE NULLIF(TRIM(c.credit_id), N'')
            = NULLIF(TRIM(r.credit_id), N'')
  )

ORDER BY r.remboursement_id;
GO


/* ============================================================
   10. CONTRÔLER LA STANDARDISATION DES STATUTS
   ============================================================ */

/* ------------------------------------------------------------
   La collation BIN2 impose une comparaison exacte :

   - elle distingue les majuscules et les minuscules ;
   - elle distingue les caractères accentués.

   Cela permet de détecter précisément « paye a temps »
   comme une écriture différente de « Payé à temps ».
   ------------------------------------------------------------ */
DECLARE @statuts_non_standardises_source INT =
(
    SELECT COUNT(*)

    FROM raw.remboursements

    WHERE staging.fn_nettoyer_texte(statut_remboursement)
              COLLATE Latin1_General_100_BIN2

          NOT IN
          (
              N'Payé à temps' COLLATE Latin1_General_100_BIN2,
              N'Payé en retard' COLLATE Latin1_General_100_BIN2,
              N'Impayé' COLLATE Latin1_General_100_BIN2
          )
);

DECLARE @statuts_modifies INT =
(
    SELECT COUNT(*)

    FROM raw.remboursements AS r

    INNER JOIN staging.remboursements AS s
        ON NULLIF(TRIM(r.remboursement_id), N'')
           = s.remboursement_id

    WHERE staging.fn_nettoyer_texte(r.statut_remboursement)
              COLLATE Latin1_General_100_BIN2

          <> s.statut_remboursement
              COLLATE Latin1_General_100_BIN2
);

DECLARE @statuts_inconnus_staging INT =
(
    SELECT COUNT(*)

    FROM staging.remboursements

    WHERE statut_remboursement IS NULL

       OR statut_remboursement NOT IN
       (
           N'Payé à temps',
           N'Payé en retard',
           N'Impayé'
       )
);

SELECT
    @statuts_non_standardises_source
        AS statuts_non_standardises_source,

    @statuts_modifies
        AS statuts_modifies,

    @statuts_inconnus_staging
        AS statuts_inconnus_staging,

    CASE
        WHEN @statuts_non_standardises_source = 40
         AND @statuts_modifies = 40
         AND @statuts_inconnus_staging = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Les 40 statuts non standardisés ',
            N'ont été corrigés et aucun statut inconnu ne reste.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ',
            @statuts_modifies,
            N' statut(s) ont été modifiés et ',
            @statuts_inconnus_staging,
            N' statut(s) inconnus restent à contrôler.'
        )
    END AS conclusion;
GO


/* Affiche les 40 statuts modifiés. */
SELECT
    r.remboursement_id,
    r.statut_remboursement AS statut_source,
    s.jours_retard,
    s.statut_remboursement AS statut_apres_nettoyage

FROM raw.remboursements AS r

INNER JOIN staging.remboursements AS s
    ON NULLIF(TRIM(r.remboursement_id), N'')
       = s.remboursement_id

WHERE staging.fn_nettoyer_texte(r.statut_remboursement)
          COLLATE Latin1_General_100_BIN2

      <> s.statut_remboursement
          COLLATE Latin1_General_100_BIN2

ORDER BY r.remboursement_id;
GO


/* Affiche la répartition finale par statut. */
SELECT
    statut_remboursement,
    COUNT(*) AS nombre_echeances,

    CONCAT(
        N'CONCLUSION : ',
        COUNT(*),
        N' échéance(s) possèdent le statut « ',
        statut_remboursement,
        N' ».'
    ) AS conclusion

FROM staging.remboursements

GROUP BY statut_remboursement

ORDER BY statut_remboursement;
GO


/* ============================================================
   11. CONTRÔLER LES DATES ET LES JOURS DE RETARD
   ============================================================ */

/* ------------------------------------------------------------
   Pour une échéance payée :

   DATEDIFF(DAY, date_echeance, date_paiement)
   → calcule le nombre de jours entre les deux dates.

   Lorsque le paiement arrive avant l’échéance, le retard
   attendu est 0 et non un nombre négatif.

   Pour une échéance impayée :

   - date_paiement doit être NULL ;
   - montant_paye doit être égal à 0 ;
   - jours_retard doit être positif ;
   - statut doit être Impayé.
   ------------------------------------------------------------ */
DECLARE @retards_calcules_incoherents INT =
(
    SELECT COUNT(*)

    FROM staging.remboursements

    WHERE date_paiement IS NOT NULL

      AND jours_retard
          <>
          CASE
              WHEN DATEDIFF(
                       DAY,
                       date_echeance,
                       date_paiement
                   ) > 0
              THEN DATEDIFF(
                       DAY,
                       date_echeance,
                       date_paiement
                   )

              ELSE 0
          END
);

DECLARE @impayes_incoherents INT =
(
    SELECT COUNT(*)

    FROM staging.remboursements

    WHERE statut_remboursement = N'Impayé'

      AND
      (
          date_paiement IS NOT NULL
          OR montant_paye <> 0
          OR jours_retard <= 0
      )
);

DECLARE @nombre_impayes INT =
(
    SELECT COUNT(*)

    FROM staging.remboursements

    WHERE statut_remboursement = N'Impayé'
);

SELECT
    @retards_calcules_incoherents
        AS retards_calcules_incoherents,

    @impayes_incoherents
        AS impayes_incoherents,

    @nombre_impayes
        AS nombre_impayes,

    CASE
        WHEN @retards_calcules_incoherents = 0
         AND @impayes_incoherents = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Les jours de retard correspondent ',
            N'aux dates de paiement et les ',
            @nombre_impayes,
            N' échéances impayées sont cohérentes.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @retards_calcules_incoherents,
            N' retard(s) calculés et ',
            @impayes_incoherents,
            N' échéance(s) impayées sont incohérents.'
        )
    END AS conclusion;
GO


/* Affiche jusqu’à 20 incohérences de dates ou de retard. */
SELECT TOP (20)
    remboursement_id,
    date_echeance,
    date_paiement,
    jours_retard,

    CASE
        WHEN date_paiement IS NULL
            THEN NULL

        WHEN DATEDIFF(
                 DAY,
                 date_echeance,
                 date_paiement
             ) > 0
            THEN DATEDIFF(
                     DAY,
                     date_echeance,
                     date_paiement
                 )

        ELSE 0
    END AS jours_retard_recalcules,

    montant_paye,
    statut_remboursement

FROM staging.remboursements

WHERE
(
    date_paiement IS NOT NULL

    AND jours_retard
        <>
        CASE
            WHEN DATEDIFF(
                     DAY,
                     date_echeance,
                     date_paiement
                 ) > 0
            THEN DATEDIFF(
                     DAY,
                     date_echeance,
                     date_paiement
                 )

            ELSE 0
        END
)

OR
(
    statut_remboursement = N'Impayé'

    AND
    (
        date_paiement IS NOT NULL
        OR montant_paye <> 0
        OR jours_retard <= 0
    )
)

ORDER BY remboursement_id;
GO


/* ============================================================
   12. CONTRÔLER LES VALEURS NUMÉRIQUES
   ============================================================ */

/* ------------------------------------------------------------
   Règles contrôlées :

   - montant_attendu strictement positif ;
   - montant_paye jamais négatif dans staging ;
   - montant_paye ne dépassant pas le montant attendu ;
   - jours_retard positif ou égal à 0.

   Les 20 montants devenus NULL sont déjà documentés par
   le contrôle des paiements négatifs.
   ------------------------------------------------------------ */
DECLARE @valeurs_numeriques_invalides INT =
(
    SELECT COUNT(*)

    FROM staging.remboursements

    WHERE montant_attendu IS NULL
       OR montant_attendu <= 0

       OR montant_paye < 0

       OR montant_paye > montant_attendu

       OR jours_retard IS NULL
       OR jours_retard < 0
);

SELECT
    @valeurs_numeriques_invalides
        AS valeurs_numeriques_invalides,

    CASE
        WHEN @valeurs_numeriques_invalides = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Les montants attendus et les jours ',
            N'de retard sont cohérents. Aucun paiement négatif ',
            N'ou supérieur au montant attendu ne reste.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @valeurs_numeriques_invalides,
            N' échéance(s) ont une valeur numérique incohérente.'
        )
    END AS conclusion;
GO


/* Affiche les éventuelles valeurs numériques incohérentes. */
SELECT TOP (20)
    remboursement_id,
    montant_attendu,
    montant_paye,
    jours_retard

FROM staging.remboursements

WHERE montant_attendu IS NULL
   OR montant_attendu <= 0
   OR montant_paye < 0
   OR montant_paye > montant_attendu
   OR jours_retard IS NULL
   OR jours_retard < 0

ORDER BY remboursement_id;
GO


/* ============================================================
   13. ANALYSER LES TYPES DE PAIEMENT
   ============================================================ */

/* ------------------------------------------------------------
   Paiement complet
   → montant_paye = montant_attendu.

   Paiement partiel
   → montant_paye est positif mais inférieur au montant attendu.

   Impayé
   → montant_paye = 0.

   Montant invalide
   → montant_paye est NULL après correction d’une valeur négative.
   ------------------------------------------------------------ */
DECLARE @paiements_complets INT =
(
    SELECT COUNT(*)

    FROM staging.remboursements

    WHERE montant_paye = montant_attendu
);

DECLARE @paiements_partiels INT =
(
    SELECT COUNT(*)

    FROM staging.remboursements

    WHERE montant_paye > 0
      AND montant_paye < montant_attendu
);

DECLARE @paiements_nuls INT =
(
    SELECT COUNT(*)

    FROM staging.remboursements

    WHERE montant_paye = 0
);

DECLARE @paiements_invalides_null INT =
(
    SELECT COUNT(*)

    FROM staging.remboursements

    WHERE montant_paye IS NULL
);

DECLARE @total_echeances INT =
(
    SELECT COUNT(*)

    FROM staging.remboursements
);

SELECT
    @paiements_complets AS paiements_complets,
    @paiements_partiels AS paiements_partiels,
    @paiements_nuls AS echeances_impayees,
    @paiements_invalides_null AS montants_invalides_null,
    @total_echeances AS total_echeances,

    CASE
        WHEN
        (
            @paiements_complets
            + @paiements_partiels
            + @paiements_nuls
            + @paiements_invalides_null
        ) = @total_echeances

        THEN CONCAT(
            N'CONCLUSION : les ',
            @total_echeances,
            N' échéances se répartissent en ',
            @paiements_complets,
            N' paiements complets, ',
            @paiements_partiels,
            N' paiements partiels, ',
            @paiements_nuls,
            N' impayés et ',
            @paiements_invalides_null,
            N' montants invalides remplacés par NULL.'
        )

        ELSE N'CONCLUSION : ATTENTION. La répartition des paiements doit être vérifiée.'
    END AS conclusion;
GO


/* ============================================================
   14. AFFICHER LES PLAGES DE DATES ET DE RETARD
   ============================================================ */

/* ------------------------------------------------------------
   MIN renvoie la valeur la plus faible.

   MAX renvoie la valeur la plus élevée.

   Les valeurs NULL de date_paiement sont automatiquement
   ignorées par MIN et MAX.
   ------------------------------------------------------------ */
SELECT
    MIN(date_echeance) AS premiere_echeance,
    MAX(date_echeance) AS derniere_echeance,

    MIN(date_paiement) AS premier_paiement,
    MAX(date_paiement) AS dernier_paiement,

    MIN(jours_retard) AS retard_minimum,
    MAX(jours_retard) AS retard_maximum,

    CONCAT(
        N'CONCLUSION : les échéances vont du ',
        CONVERT(
            NVARCHAR(10),
            MIN(date_echeance),
            103
        ),
        N' au ',
        CONVERT(
            NVARCHAR(10),
            MAX(date_echeance),
            103
        ),
        N' et les retards sont compris entre ',
        MIN(jours_retard),
        N' et ',
        MAX(jours_retard),
        N' jours.'
    ) AS conclusion

FROM staging.remboursements;
GO


/* ============================================================
   15. CONTRÔLER LES CARACTÈRES MAL ENCODÉS
   ============================================================ */

/* ------------------------------------------------------------
   Recherche les symboles associés aux problèmes d’encodage
   rencontrés pendant l’import :

   ├
   √
   Ã
   ------------------------------------------------------------ */
DECLARE @encodages_incorrects INT =
(
    SELECT COUNT(*)

    FROM staging.remboursements

    WHERE statut_remboursement LIKE N'%├%'
       OR statut_remboursement LIKE N'%√%'
       OR statut_remboursement LIKE N'%Ã%'
);

SELECT
    @encodages_incorrects AS remboursements_encodage_incorrect,

    CASE
        WHEN @encodages_incorrects = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Aucun caractère mal encodé connu ',
            N'ne reste dans staging.remboursements.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @encodages_incorrects,
            N' échéance(s) contiennent encore un caractère incorrect.'
        )
    END AS conclusion;
GO


/* Affiche les éventuels statuts encore mal encodés. */
SELECT TOP (20)
    remboursement_id,
    statut_remboursement

FROM staging.remboursements

WHERE statut_remboursement LIKE N'%├%'
   OR statut_remboursement LIKE N'%√%'
   OR statut_remboursement LIKE N'%Ã%'

ORDER BY remboursement_id;
GO


/* ============================================================
   16. AFFICHER UN AVANT / APRÈS
   ============================================================ */

/* ------------------------------------------------------------
   Cette requête affiche les lignes dont au moins une donnée
   importante a été corrigée :

   - paiement négatif devenu NULL ;
   - crédit inexistant devenu NULL ;
   - statut corrigé ou standardisé.
   ------------------------------------------------------------ */
SELECT TOP (30)
    r.remboursement_id,

    r.credit_id AS credit_avant,
    s.credit_id AS credit_apres,

    r.montant_paye AS montant_avant,
    s.montant_paye AS montant_apres,

    r.statut_remboursement AS statut_avant,
    s.statut_remboursement AS statut_apres,

    s.date_echeance,
    s.date_paiement,
    s.jours_retard

FROM raw.remboursements AS r

INNER JOIN staging.remboursements AS s
    ON NULLIF(TRIM(r.remboursement_id), N'')
       = s.remboursement_id

WHERE
(
    TRY_CONVERT(
        DECIMAL(15,2),
        NULLIF(TRIM(r.montant_paye), N'')
    ) < 0
)

OR
(
    s.credit_id IS NULL
)

OR
(
    staging.fn_nettoyer_texte(r.statut_remboursement)
        COLLATE Latin1_General_100_BIN2

    <> s.statut_remboursement
        COLLATE Latin1_General_100_BIN2
)

ORDER BY s.remboursement_id;
GO


/* ============================================================
   17. AFFICHER UN APERÇU FINAL
   ============================================================ */

SELECT TOP (20)
    remboursement_id,
    credit_id,
    date_echeance,
    date_paiement,
    montant_attendu,
    montant_paye,
    jours_retard,
    statut_remboursement

FROM staging.remboursements

ORDER BY remboursement_id;
GO


/* ============================================================
   18. RÉSUMÉ FINAL
   ============================================================ */

DECLARE @total_remboursements_final INT =
(
    SELECT COUNT(*)
    FROM staging.remboursements
);

DECLARE @total_impayes_final INT =
(
    SELECT COUNT(*)
    FROM staging.remboursements
    WHERE statut_remboursement = N'Impayé'
);

DECLARE @total_retards_final INT =
(
    SELECT COUNT(*)
    FROM staging.remboursements
    WHERE statut_remboursement = N'Payé en retard'
);

SELECT
    @total_remboursements_final AS total_echeances,
    @total_impayes_final AS total_impayes,
    @total_retards_final AS total_paiements_en_retard,

    CONCAT(
        N'CONCLUSION FINALE : staging.remboursements contient ',
        @total_remboursements_final,
        N' échéances nettoyées, dont ',
        @total_impayes_final,
        N' impayées et ',
        @total_retards_final,
        N' payées en retard.'
    ) AS conclusion;
GO


/* ============================================================
   CONCLUSION DU NETTOYAGE DE staging.remboursements

   Résultats correspondant à remboursements_raw.csv :

   1. Nombre de lignes
      - raw.remboursements contient 18 899 lignes.
      - staging.remboursements contient 18 899 lignes.
      - Aucune échéance n’a été supprimée.

   2. Grain de la table
      - Une ligne représente une échéance de remboursement.
      - La clé métier est remboursement_id.

   3. Conversions
      - 0 conversion impossible.
      - date_echeance et date_paiement sont de type DATE.
      - montant_attendu et montant_paye sont de type DECIMAL.
      - jours_retard est de type INT.

   4. Doublons
      - 0 remboursement_id dupliqué.
      - Les 18 899 échéances ont un identifiant unique.

   5. Valeurs manquantes
      - Aucun champ obligatoire ne manque.
      - 103 dates de paiement sont absentes.
      - Elles correspondent aux 103 échéances impayées.

   6. Paiements négatifs
      - 20 paiements négatifs ont été détectés.
      - Ils ont été remplacés par NULL dans staging.
      - Les valeurs originales restent dans raw.
      - Aucun paiement négatif ne reste dans staging.

   7. Crédits inexistants
      - 25 échéances font référence au crédit CR999999.
      - Ce crédit n’existe pas dans raw.credits.
      - Ces 25 credit_id ont été remplacés par NULL.
      - Les échéances ont été conservées.

   8. Standardisation des statuts
      - 40 statuts étaient écrits « paye a temps ».
      - Ces statuts ont été recalculés grâce aux jours de retard :

        24 sont devenus « Payé à temps ».
        16 sont devenus « Payé en retard ».

      - Aucun statut inconnu ne reste.

   9. Répartition finale des statuts
      - Payé à temps : 11 514 échéances.
      - Payé en retard : 7 282 échéances.
      - Impayé : 103 échéances.

   10. Cohérence des dates
       - Les jours de retard correspondent à la différence
         entre la date d’échéance et la date de paiement.
       - Un paiement effectué avant l’échéance possède
         correctement 0 jour de retard.
       - 0 incohérence a été détectée.

   11. Types de paiement
       - 18 655 paiements complets.
       - 121 paiements partiels.
       - 103 échéances impayées avec un montant payé égal à 0.
       - 20 montants invalides remplacés par NULL.

   12. Période
       - Les échéances vont du 14 février 2021
         au 30 juin 2026.
       - Les retards sont compris entre 0 et 94 jours.

   13. Encodage
       - Les accents des statuts ont été corrigés.
       - Aucun caractère d’encodage incorrect connu ne reste.

   RÉSULTAT FINAL :

   staging.remboursements contient 18 899 échéances
   correctement typées et standardisées.

   Les paiements négatifs et les crédits inexistants sont
   clairement identifiés par des valeurs NULL, sans supprimer
   les échéances concernées.
   ============================================================ */