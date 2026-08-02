/* ============================================================
   PROJET : Banque 360
   FICHIER : 07_nettoyage_staging_objectifs_agences.sql

   ÉTAPE DU FICHIER :

   Étape 6 sur 8
   Nettoyer les données dans staging

   AVANCEMENT :

   Étapes 1 à 5 : TERMINÉES
   Étape 6 : EN COURS (partie 4/7)

   TABLE TRAITÉE :

   raw.objectifs_agences → staging.objectifs_agences

   GRAIN DE LA TABLE :

   Une ligne représente les objectifs d’une agence
   pour un mois donné.

   La clé métier est donc composée de :

   agence_id + mois

   OBJECTIF :

   - nettoyer les textes et les valeurs vides ;
   - convertir le mois en véritable date SQL ;
   - convertir les objectifs dans leurs types numériques ;
   - vérifier l’unicité agence + mois ;
   - vérifier les relations avec les agences ;
   - contrôler les valeurs négatives ou incohérentes ;
   - vérifier que chaque agence possède tous les mois ;
   - conserver raw.objectifs_agences intacte.

   RÉSULTATS ATTENDUS AVEC objectifs_agences.csv :

   - 1 050 lignes dans raw.objectifs_agences ;
   - 1 050 lignes dans staging.objectifs_agences ;
   - 25 agences ;
   - 42 mois ;
   - période de janvier 2023 à juin 2026 ;
   - 0 conversion impossible ;
   - 0 doublon sur agence_id + mois ;
   - 0 valeur manquante ;
   - 0 agence inexistante ;
   - 0 valeur numérique incohérente.
   ============================================================ */


USE Banque360;
GO


/* ============================================================
   1. RECRÉER staging.objectifs_agences
   ============================================================ */

/* Supprime uniquement l’ancienne table nettoyée.

   La table raw.objectifs_agences reste inchangée. */
DROP TABLE IF EXISTS staging.objectifs_agences;
GO


/* ------------------------------------------------------------
   TYPES DES COLONNES :

   NVARCHAR
   → texte acceptant les caractères Unicode.

   DATE
   → véritable date SQL.

   DECIMAL(15,2)
   → nombre décimal précis, adapté aux montants.

   INT
   → nombre entier.

   DECIMAL(5,2)
   → pourcentage avec deux chiffres après la virgule.
   ------------------------------------------------------------ */
CREATE TABLE staging.objectifs_agences
(
    /* Identifiant de l’agence.

       Relation future avec la dimension Agence. */
    agence_id NVARCHAR(20) NULL,

    /* Mois de l’objectif.

       La valeur 2023-01 devient la date 2023-01-01.

       Relation future avec la dimension Date. */
    mois DATE NULL,

    /* Objectif mensuel de revenu. */
    objectif_revenu DECIMAL(15,2) NULL,

    /* Objectif mensuel de nouveaux clients. */
    objectif_nouveaux_clients INT NULL,

    /* Objectif mensuel de production de crédit. */
    objectif_production_credit DECIMAL(15,2) NULL,

    /* Seuil maximal souhaité du taux d’impayé,
       exprimé en pourcentage. */
    seuil_taux_impaye_pct DECIMAL(5,2) NULL
);
GO


/* ============================================================
   2. NETTOYER ET CHARGER LES OBJECTIFS
   ============================================================ */

/* ------------------------------------------------------------
   TRIM
   → enlève les espaces au début et à la fin.

   NULLIF(..., N'')
   → transforme un texte vide en NULL.

   TRY_CONVERT
   → tente de convertir la valeur ;
   → renvoie NULL si la conversion est impossible ;
   → n’interrompt pas le script.

   Le mois est stocké dans le CSV sous la forme AAAA-MM.

   On ajoute donc « -01 » afin de construire une véritable
   date correspondant au premier jour du mois :

   2023-01 → 2023-01-01
   ------------------------------------------------------------ */
INSERT INTO staging.objectifs_agences
(
    agence_id,
    mois,
    objectif_revenu,
    objectif_nouveaux_clients,
    objectif_production_credit,
    seuil_taux_impaye_pct
)
SELECT
    /* Nettoie l’identifiant de l’agence. */
    NULLIF(TRIM(agence_id), N''),

    /* Convertit AAAA-MM en véritable date SQL AAAA-MM-01. */
    TRY_CONVERT(
        DATE,
        NULLIF(TRIM(mois), N'') + N'-01',
        23
    ),

    /* Convertit l’objectif de revenu en nombre décimal. */
    TRY_CONVERT(
        DECIMAL(15,2),
        NULLIF(TRIM(objectif_revenu), N'')
    ),

    /* Convertit le nombre de nouveaux clients en entier. */
    TRY_CONVERT(
        INT,
        NULLIF(TRIM(objectif_nouveaux_clients), N'')
    ),

    /* Convertit l’objectif de production de crédit
       en nombre décimal. */
    TRY_CONVERT(
        DECIMAL(15,2),
        NULLIF(TRIM(objectif_production_credit), N'')
    ),

    /* Convertit le seuil du taux d’impayé en pourcentage. */
    TRY_CONVERT(
        DECIMAL(5,2),
        NULLIF(TRIM(seuil_taux_impaye_pct), N'')
    )

FROM raw.objectifs_agences;
GO


/* ============================================================
   3. CONTRÔLER LE NOMBRE DE LIGNES
   ============================================================ */

DECLARE @lignes_raw INT =
(
    SELECT COUNT(*)
    FROM raw.objectifs_agences
);

DECLARE @lignes_staging INT =
(
    SELECT COUNT(*)
    FROM staging.objectifs_agences
);

SELECT
    @lignes_raw AS lignes_raw,
    @lignes_staging AS lignes_staging,

    CASE
        WHEN @lignes_raw = @lignes_staging
        THEN CONCAT(
            N'CONCLUSION : OK. Les ',
            @lignes_raw,
            N' lignes ont été chargées dans staging.objectifs_agences ',
            N'sans perte de donnée.'
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
   Une ligne est comptée une seule fois, même si plusieurs
   conversions sont impossibles sur cette ligne.

   Résultat attendu : 0.
   ------------------------------------------------------------ */

DECLARE @conversions_impossibles INT =
(
    SELECT COUNT(*)
    FROM raw.objectifs_agences
    WHERE
    (
        NULLIF(TRIM(mois), N'') IS NOT NULL
        AND TRY_CONVERT(
                DATE,
                TRIM(mois) + N'-01',
                23
            ) IS NULL
    )

    OR
    (
        NULLIF(TRIM(objectif_revenu), N'') IS NOT NULL
        AND TRY_CONVERT(
                DECIMAL(15,2),
                TRIM(objectif_revenu)
            ) IS NULL
    )

    OR
    (
        NULLIF(TRIM(objectif_nouveaux_clients), N'') IS NOT NULL
        AND TRY_CONVERT(
                INT,
                TRIM(objectif_nouveaux_clients)
            ) IS NULL
    )

    OR
    (
        NULLIF(TRIM(objectif_production_credit), N'') IS NOT NULL
        AND TRY_CONVERT(
                DECIMAL(15,2),
                TRIM(objectif_production_credit)
            ) IS NULL
    )

    OR
    (
        NULLIF(TRIM(seuil_taux_impaye_pct), N'') IS NOT NULL
        AND TRY_CONVERT(
                DECIMAL(5,2),
                TRIM(seuil_taux_impaye_pct)
            ) IS NULL
    )
);

SELECT
    @conversions_impossibles AS conversions_impossibles,

    CASE
        WHEN @conversions_impossibles = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Les mois, objectifs et seuils ',
            N'ont tous été correctement convertis.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @conversions_impossibles,
            N' ligne(s) contiennent au moins une conversion impossible.'
        )
    END AS conclusion;
GO


/* Affiche jusqu’à 20 lignes présentant une conversion impossible.

   Si aucune ligne n’apparaît, toutes les conversions
   ont réussi. */
SELECT TOP (20)
    agence_id,
    mois,
    objectif_revenu,
    objectif_nouveaux_clients,
    objectif_production_credit,
    seuil_taux_impaye_pct

FROM raw.objectifs_agences

WHERE
(
    NULLIF(TRIM(mois), N'') IS NOT NULL
    AND TRY_CONVERT(
            DATE,
            TRIM(mois) + N'-01',
            23
        ) IS NULL
)

OR
(
    NULLIF(TRIM(objectif_revenu), N'') IS NOT NULL
    AND TRY_CONVERT(
            DECIMAL(15,2),
            TRIM(objectif_revenu)
        ) IS NULL
)

OR
(
    NULLIF(TRIM(objectif_nouveaux_clients), N'') IS NOT NULL
    AND TRY_CONVERT(
            INT,
            TRIM(objectif_nouveaux_clients)
        ) IS NULL
)

OR
(
    NULLIF(TRIM(objectif_production_credit), N'') IS NOT NULL
    AND TRY_CONVERT(
            DECIMAL(15,2),
            TRIM(objectif_production_credit)
        ) IS NULL
)

OR
(
    NULLIF(TRIM(seuil_taux_impaye_pct), N'') IS NOT NULL
    AND TRY_CONVERT(
            DECIMAL(5,2),
            TRIM(seuil_taux_impaye_pct)
        ) IS NULL
);
GO


/* ============================================================
   5. CONTRÔLER LES DOUBLONS
   ============================================================ */

/* ------------------------------------------------------------
   La clé métier est composée de :

   agence_id + mois

   Une agence ne doit donc posséder qu’une seule ligne
   d’objectif par mois.

   nombre_occurrences - 1
   → calcule les lignes supplémentaires.

   COALESCE
   → renvoie 0 si aucun doublon n’existe.
   ------------------------------------------------------------ */
DECLARE @cles_dupliquees INT;
DECLARE @lignes_dupliquees INT;

SELECT
    @cles_dupliquees = COUNT(*),

    @lignes_dupliquees =
        COALESCE(SUM(nombre_occurrences - 1), 0)

FROM
(
    SELECT
        agence_id,
        mois,
        COUNT(*) AS nombre_occurrences

    FROM staging.objectifs_agences

    WHERE agence_id IS NOT NULL
      AND mois IS NOT NULL

    GROUP BY
        agence_id,
        mois

    HAVING COUNT(*) > 1
) AS doublons;

SELECT
    @cles_dupliquees AS couples_agence_mois_dupliques,
    @lignes_dupliquees AS lignes_dupliquees,

    CASE
        WHEN @cles_dupliquees = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Chaque agence possède une seule ',
            N'ligne d’objectif par mois.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @cles_dupliquees,
            N' couple(s) agence-mois sont dupliqués, soit ',
            @lignes_dupliquees,
            N' ligne(s) supplémentaire(s).'
        )
    END AS conclusion;
GO


/* Affiche les éventuels couples agence-mois dupliqués. */
SELECT
    agence_id,
    mois,
    COUNT(*) AS nombre_occurrences

FROM staging.objectifs_agences

WHERE agence_id IS NOT NULL
  AND mois IS NOT NULL

GROUP BY
    agence_id,
    mois

HAVING COUNT(*) > 1

ORDER BY
    agence_id,
    mois;
GO


/* ============================================================
   6. CONTRÔLER LES VALEURS MANQUANTES
   ============================================================ */

/* ------------------------------------------------------------
   Toutes les colonnes sont nécessaires pour analyser
   correctement les objectifs.

   Une ligne est comptée une seule fois, même si plusieurs
   colonnes sont NULL.
   ------------------------------------------------------------ */
DECLARE @lignes_incompletes INT =
(
    SELECT COUNT(*)
    FROM staging.objectifs_agences
    WHERE agence_id IS NULL
       OR mois IS NULL
       OR objectif_revenu IS NULL
       OR objectif_nouveaux_clients IS NULL
       OR objectif_production_credit IS NULL
       OR seuil_taux_impaye_pct IS NULL
);

SELECT
    @lignes_incompletes AS lignes_incompletes,

    CASE
        WHEN @lignes_incompletes = 0
        THEN N'CONCLUSION : OK. Aucune valeur obligatoire ne manque.'

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @lignes_incompletes,
            N' ligne(s) ont au moins une valeur manquante.'
        )
    END AS conclusion;
GO


/* Affiche jusqu’à 20 éventuelles lignes incomplètes. */
SELECT TOP (20)
    agence_id,
    mois,
    objectif_revenu,
    objectif_nouveaux_clients,
    objectif_production_credit,
    seuil_taux_impaye_pct

FROM staging.objectifs_agences

WHERE agence_id IS NULL
   OR mois IS NULL
   OR objectif_revenu IS NULL
   OR objectif_nouveaux_clients IS NULL
   OR objectif_production_credit IS NULL
   OR seuil_taux_impaye_pct IS NULL

ORDER BY
    agence_id,
    mois;
GO


/* ============================================================
   7. CONTRÔLER LES AGENCES
   ============================================================ */

/* ------------------------------------------------------------
   Premier contrôle :

   L’identifiant doit respecter le format A suivi de trois
   chiffres, par exemple A001.

   Deuxième contrôle :

   L’identifiant doit exister dans raw.agences.

   NOT EXISTS recherche les objectifs rattachés à une agence
   absente de la table de référence.
   ------------------------------------------------------------ */
DECLARE @formats_agence_invalides INT =
(
    SELECT COUNT(*)
    FROM staging.objectifs_agences
    WHERE agence_id IS NOT NULL
      AND
      (
          LEN(agence_id) <> 4
          OR agence_id NOT LIKE N'A[0-9][0-9][0-9]'
      )
);

DECLARE @agences_inexistantes INT =
(
    SELECT COUNT(*)
    FROM staging.objectifs_agences AS o

    WHERE o.agence_id IS NOT NULL

      AND NOT EXISTS
      (
          SELECT 1
          FROM raw.agences AS a
          WHERE NULLIF(TRIM(a.agence_id), N'') = o.agence_id
      )
);

SELECT
    @formats_agence_invalides AS formats_agence_invalides,
    @agences_inexistantes AS objectifs_agence_inexistante,

    CASE
        WHEN @formats_agence_invalides = 0
         AND @agences_inexistantes = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Tous les identifiants respectent ',
            N'le format attendu et correspondent à une agence existante.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @formats_agence_invalides,
            N' identifiant(s) ont un format incorrect et ',
            @agences_inexistantes,
            N' objectif(s) sont liés à une agence inexistante.'
        )
    END AS conclusion;
GO


/* Affiche jusqu’à 20 identifiants incorrects ou orphelins. */
SELECT TOP (20)
    o.agence_id,
    o.mois

FROM staging.objectifs_agences AS o

WHERE
(
    o.agence_id IS NOT NULL
    AND
    (
        LEN(o.agence_id) <> 4
        OR o.agence_id NOT LIKE N'A[0-9][0-9][0-9]'
    )
)

OR
(
    o.agence_id IS NOT NULL

    AND NOT EXISTS
    (
        SELECT 1
        FROM raw.agences AS a
        WHERE NULLIF(TRIM(a.agence_id), N'') = o.agence_id
    )
)

ORDER BY
    o.agence_id,
    o.mois;
GO


/* ============================================================
   8. CONTRÔLER LES VALEURS NUMÉRIQUES
   ============================================================ */

/* ------------------------------------------------------------
   RÈGLES UTILISÉES :

   - les objectifs ne peuvent pas être négatifs ;
   - le seuil du taux d’impayé doit être compris
     entre 0 et 100 %.

   Une valeur égale à 0 reste techniquement possible
   pour un objectif futur.
   ------------------------------------------------------------ */
DECLARE @valeurs_numeriques_invalides INT =
(
    SELECT COUNT(*)
    FROM staging.objectifs_agences
    WHERE objectif_revenu IS NULL
       OR objectif_revenu < 0

       OR objectif_nouveaux_clients IS NULL
       OR objectif_nouveaux_clients < 0

       OR objectif_production_credit IS NULL
       OR objectif_production_credit < 0

       OR seuil_taux_impaye_pct IS NULL
       OR seuil_taux_impaye_pct < 0
       OR seuil_taux_impaye_pct > 100
);

SELECT
    @valeurs_numeriques_invalides AS valeurs_numeriques_invalides,

    CASE
        WHEN @valeurs_numeriques_invalides = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Tous les objectifs sont positifs ',
            N'et tous les seuils sont compris entre 0 et 100 %.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @valeurs_numeriques_invalides,
            N' ligne(s) contiennent une valeur numérique incohérente.'
        )
    END AS conclusion;
GO


/* Affiche jusqu’à 20 éventuelles valeurs incohérentes. */
SELECT TOP (20)
    agence_id,
    mois,
    objectif_revenu,
    objectif_nouveaux_clients,
    objectif_production_credit,
    seuil_taux_impaye_pct

FROM staging.objectifs_agences

WHERE objectif_revenu IS NULL
   OR objectif_revenu < 0

   OR objectif_nouveaux_clients IS NULL
   OR objectif_nouveaux_clients < 0

   OR objectif_production_credit IS NULL
   OR objectif_production_credit < 0

   OR seuil_taux_impaye_pct IS NULL
   OR seuil_taux_impaye_pct < 0
   OR seuil_taux_impaye_pct > 100

ORDER BY
    agence_id,
    mois;
GO


/* ============================================================
   9. CONTRÔLER LA PÉRIODE
   ============================================================ */

/* ------------------------------------------------------------
   COUNT(DISTINCT mois)
   → compte le nombre de mois différents.

   DATEDIFF(MONTH, date_min, date_max) + 1
   → calcule le nombre de mois théoriquement attendus
     entre la première et la dernière date.

   Si les deux nombres sont identiques, aucun mois global
   ne manque dans la période.
   ------------------------------------------------------------ */
DECLARE @premier_mois DATE =
(
    SELECT MIN(mois)
    FROM staging.objectifs_agences
);

DECLARE @dernier_mois DATE =
(
    SELECT MAX(mois)
    FROM staging.objectifs_agences
);

DECLARE @nombre_mois_distincts INT =
(
    SELECT COUNT(DISTINCT mois)
    FROM staging.objectifs_agences
);

DECLARE @nombre_mois_attendus INT =
(
    SELECT DATEDIFF(
               MONTH,
               @premier_mois,
               @dernier_mois
           ) + 1
);

DECLARE @dates_hors_premier_jour INT =
(
    SELECT COUNT(*)
    FROM staging.objectifs_agences
    WHERE mois IS NOT NULL
      AND DAY(mois) <> 1
);

SELECT
    @premier_mois AS premier_mois,
    @dernier_mois AS dernier_mois,
    @nombre_mois_distincts AS mois_distincts,
    @nombre_mois_attendus AS mois_attendus,
    @dates_hors_premier_jour AS dates_hors_premier_jour,

    CASE
        WHEN @nombre_mois_distincts = @nombre_mois_attendus
         AND @dates_hors_premier_jour = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Les objectifs couvrent ',
            @nombre_mois_distincts,
            N' mois consécutifs, de ',
            LEFT(CONVERT(NVARCHAR(10), @premier_mois, 23), 7),
            N' à ',
            LEFT(CONVERT(NVARCHAR(10), @dernier_mois, 23), 7),
            N'.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. La continuité de la période ',
            N'ou le format des dates doit être vérifié.'
        )
    END AS conclusion;
GO


/* ============================================================
   10. CONTRÔLER LA COUVERTURE AGENCES × MOIS
   ============================================================ */

/* ------------------------------------------------------------
   Le fichier doit contenir toutes les combinaisons :

   25 agences × 42 mois = 1 050 lignes.

   Chaque agence doit donc posséder 42 mois.

   Chaque mois doit contenir les objectifs des 25 agences.
   ------------------------------------------------------------ */
DECLARE @nombre_agences INT =
(
    SELECT COUNT(DISTINCT agence_id)
    FROM staging.objectifs_agences
);

DECLARE @nombre_mois INT =
(
    SELECT COUNT(DISTINCT mois)
    FROM staging.objectifs_agences
);

DECLARE @nombre_lignes INT =
(
    SELECT COUNT(*)
    FROM staging.objectifs_agences
);

DECLARE @nombre_lignes_theorique INT =
    @nombre_agences * @nombre_mois;


DECLARE @agences_periode_incomplete INT =
(
    SELECT COUNT(*)
    FROM
    (
        SELECT
            agence_id

        FROM staging.objectifs_agences

        WHERE agence_id IS NOT NULL
          AND mois IS NOT NULL

        GROUP BY agence_id

        HAVING COUNT(DISTINCT mois) <> @nombre_mois
    ) AS agences_incompletes
);


DECLARE @mois_agences_incompletes INT =
(
    SELECT COUNT(*)
    FROM
    (
        SELECT
            mois

        FROM staging.objectifs_agences

        WHERE agence_id IS NOT NULL
          AND mois IS NOT NULL

        GROUP BY mois

        HAVING COUNT(DISTINCT agence_id) <> @nombre_agences
    ) AS mois_incomplets
);


SELECT
    @nombre_agences AS agences_distinctes,
    @nombre_mois AS mois_distincts,
    @nombre_lignes AS lignes_reelles,
    @nombre_lignes_theorique AS lignes_theoriques,
    @agences_periode_incomplete AS agences_periode_incomplete,
    @mois_agences_incompletes AS mois_agences_incompletes,

    CASE
        WHEN @nombre_lignes = @nombre_lignes_theorique
         AND @agences_periode_incomplete = 0
         AND @mois_agences_incompletes = 0
        THEN CONCAT(
            N'CONCLUSION : OK. La couverture est complète : ',
            @nombre_agences,
            N' agences × ',
            @nombre_mois,
            N' mois = ',
            @nombre_lignes,
            N' lignes.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. La grille agences × mois ',
            N'n’est pas entièrement complète.'
        )
    END AS conclusion;
GO


/* Affiche les éventuelles agences n’ayant pas tous les mois. */
DECLARE @total_mois INT =
(
    SELECT COUNT(DISTINCT mois)
    FROM staging.objectifs_agences
);

SELECT
    agence_id,
    COUNT(DISTINCT mois) AS nombre_mois_disponibles,
    @total_mois AS nombre_mois_attendus

FROM staging.objectifs_agences

WHERE agence_id IS NOT NULL
  AND mois IS NOT NULL

GROUP BY agence_id

HAVING COUNT(DISTINCT mois) <> @total_mois

ORDER BY agence_id;
GO


/* Affiche les éventuels mois ne contenant pas toutes les agences. */
DECLARE @total_agences INT =
(
    SELECT COUNT(DISTINCT agence_id)
    FROM staging.objectifs_agences
);

SELECT
    mois,
    COUNT(DISTINCT agence_id) AS nombre_agences_disponibles,
    @total_agences AS nombre_agences_attendues

FROM staging.objectifs_agences

WHERE agence_id IS NOT NULL
  AND mois IS NOT NULL

GROUP BY mois

HAVING COUNT(DISTINCT agence_id) <> @total_agences

ORDER BY mois;
GO


/* ============================================================
   11. AFFICHER LES PLAGES DE VALEURS
   ============================================================ */

/* ------------------------------------------------------------
   MIN renvoie la valeur la plus faible.

   MAX renvoie la valeur la plus élevée.

   Ce contrôle permet de comprendre rapidement l’ordre
   de grandeur de chaque indicateur.
   ------------------------------------------------------------ */
   
SELECT
    MIN(objectif_revenu)
        AS objectif_revenu_minimum,

    MAX(objectif_revenu)
        AS objectif_revenu_maximum,

    MIN(objectif_nouveaux_clients)
        AS nouveaux_clients_minimum,

    MAX(objectif_nouveaux_clients)
        AS nouveaux_clients_maximum,

    MIN(objectif_production_credit)
        AS production_credit_minimum,

    MAX(objectif_production_credit)
        AS production_credit_maximum,

    MIN(seuil_taux_impaye_pct)
        AS seuil_impaye_minimum,

    MAX(seuil_taux_impaye_pct)
        AS seuil_impaye_maximum,

    CONCAT(
        N'CONCLUSION : les objectifs de revenu sont compris entre ',
        MIN(objectif_revenu),
        N' et ',
        MAX(objectif_revenu),
        N', les objectifs de nouveaux clients entre ',
        MIN(objectif_nouveaux_clients),
        N' et ',
        MAX(objectif_nouveaux_clients),
        N', la production de crédit entre ',
        MIN(objectif_production_credit),
        N' et ',
        MAX(objectif_production_credit),
        N', et les seuils d’impayé entre ',
        MIN(seuil_taux_impaye_pct),
        N' % et ',
        MAX(seuil_taux_impaye_pct),
        N' %.'
    ) AS conclusion

FROM staging.objectifs_agences;
GO


/* ============================================================
   12. AFFICHER LA RÉPARTITION PAR ANNÉE
   ============================================================ */

/* ------------------------------------------------------------
   YEAR extrait l’année d’une date.

   La période 2023-2025 contient douze mois complets.

   L’année 2026 contient seulement janvier à juin.
   ------------------------------------------------------------ */
SELECT
    YEAR(mois) AS annee,
    COUNT(*) AS nombre_lignes,
    COUNT(DISTINCT agence_id) AS nombre_agences,
    COUNT(DISTINCT mois) AS nombre_mois,

    CONCAT(
        N'CONCLUSION : l’année ',
        YEAR(mois),
        N' contient ',
        COUNT(DISTINCT mois),
        N' mois et ',
        COUNT(*),
        N' lignes d’objectifs.'
    ) AS conclusion

FROM staging.objectifs_agences

GROUP BY YEAR(mois)

ORDER BY annee;
GO


/* ============================================================
   13. AFFICHER UN AVANT / APRÈS
   ============================================================ */

/* ------------------------------------------------------------
   Cette requête montre la différence entre :

   - les valeurs textuelles présentes dans raw ;
   - les valeurs correctement typées dans staging.

   Les données ne sont pas modifiées sur le fond.
   Elles changent uniquement de type SQL.
   ------------------------------------------------------------ */
SELECT TOP (20)
    r.agence_id AS agence_source,
    s.agence_id AS agence_staging,

    r.mois AS mois_source_texte,
    s.mois AS mois_staging_date,

    r.objectif_revenu AS revenu_source_texte,
    s.objectif_revenu AS revenu_staging_decimal,

    r.objectif_nouveaux_clients AS clients_source_texte,
    s.objectif_nouveaux_clients AS clients_staging_entier,

    r.objectif_production_credit AS credit_source_texte,
    s.objectif_production_credit AS credit_staging_decimal,

    r.seuil_taux_impaye_pct AS seuil_source_texte,
    s.seuil_taux_impaye_pct AS seuil_staging_decimal

FROM raw.objectifs_agences AS r

INNER JOIN staging.objectifs_agences AS s
    ON NULLIF(TRIM(r.agence_id), N'') = s.agence_id

   AND TRY_CONVERT(
           DATE,
           NULLIF(TRIM(r.mois), N'') + N'-01',
           23
       ) = s.mois

ORDER BY
    s.agence_id,
    s.mois;
GO


/* ============================================================
   14. AFFICHER UN APERÇU FINAL
   ============================================================ */

SELECT TOP (20)
    agence_id,
    mois,
    objectif_revenu,
    objectif_nouveaux_clients,
    objectif_production_credit,
    seuil_taux_impaye_pct

FROM staging.objectifs_agences

ORDER BY
    agence_id,
    mois;
GO


/* ============================================================
   15. RÉSUMÉ FINAL
   ============================================================ */

DECLARE @total_objectifs INT =
(
    SELECT COUNT(*)
    FROM staging.objectifs_agences
);

DECLARE @total_agences_final INT =
(
    SELECT COUNT(DISTINCT agence_id)
    FROM staging.objectifs_agences
);

DECLARE @total_mois_final INT =
(
    SELECT COUNT(DISTINCT mois)
    FROM staging.objectifs_agences
);

SELECT
    @total_objectifs AS total_objectifs,
    @total_agences_final AS total_agences,
    @total_mois_final AS total_mois,

    CONCAT(
        N'CONCLUSION FINALE : staging.objectifs_agences contient ',
        @total_objectifs,
        N' lignes correspondant à ',
        @total_agences_final,
        N' agences suivies sur ',
        @total_mois_final,
        N' mois.'
    ) AS conclusion;
GO


/* ============================================================
   CONCLUSION DU NETTOYAGE DE staging.objectifs_agences

   Résultats correspondant à objectifs_agences.csv :

   1. Nombre de lignes
      - raw.objectifs_agences contient 1 050 lignes.
      - staging.objectifs_agences contient 1 050 lignes.
      - Aucune ligne n’a été perdue.

   2. Grain de la table
      - Une ligne correspond à une agence pour un mois.
      - La clé métier est agence_id + mois.
      - Aucun couple agence-mois n’est dupliqué.

   3. Conversions
      - 0 conversion impossible.
      - mois est maintenant de type DATE.
      - objectif_revenu est de type DECIMAL.
      - objectif_nouveaux_clients est de type INT.
      - objectif_production_credit est de type DECIMAL.
      - seuil_taux_impaye_pct est de type DECIMAL.

   4. Valeurs manquantes
      - Aucune valeur obligatoire ne manque.
      - Les 1 050 lignes sont complètes.

   5. Agences
      - 25 agences différentes sont présentes.
      - Tous les identifiants respectent le format A000.
      - Aucune agence inexistante n’a été détectée.

   6. Période
      - 42 mois différents sont présents.
      - La période va de janvier 2023 à juin 2026.
      - Aucun mois ne manque dans la période globale.

   7. Couverture
      - Chaque agence possède exactement 42 mois.
      - Chaque mois possède exactement 25 agences.
      - 25 agences × 42 mois = 1 050 lignes.

   8. Valeurs numériques
      - Aucun objectif négatif n’a été détecté.
      - Aucun seuil d’impayé n’est inférieur à 0
        ou supérieur à 100 %.

   9. Plages de valeurs
      - objectif_revenu : de 10,00 à 162,58.
      - objectif_nouveaux_clients : de 1 à 7.
      - objectif_production_credit :
        de 10 000,00 à 490 138,88.
      - seuil_taux_impaye_pct : de 2,00 % à 4,99 %.

   RÉSULTAT FINAL :

   staging.objectifs_agences contient 1 050 objectifs mensuels,
   correctement typés, complets et prêts à être intégrés
   dans la future table de faits des objectifs.
   ============================================================ */