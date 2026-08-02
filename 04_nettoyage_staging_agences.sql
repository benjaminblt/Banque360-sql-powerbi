/* ============================================================
   PROJET : Banque 360
   FICHIER : 04_nettoyage_staging_agences.sql

   ÉTAPE DU FICHIER :

   Étape 6 sur 8
   Nettoyer les données dans staging

   AVANCEMENT :

   Étapes 1 à 5 : TERMINÉES
   Étape 6 : EN COURS (partie 1/7)

   On doit faire cette étape 6 pour chacun des 7 fichiers csv (donc cette étape 6 sera découpée en 7 parties)

   TABLE TRAITÉE :

   raw.agences → staging.agences

   OBJECTIFS :

   - conserver les données brutes dans raw.agences ;
   - nettoyer les espaces et les textes vides ;
   - corriger les caractères accentués mal interprétés ;
   - convertir les dates et les effectifs ;
   - standardiser les catégories d’agence ;
   - contrôler les doublons et les valeurs manquantes ;
   - vérifier la cohérence des dates, effectifs et codes postaux ;
   - afficher des conclusions adaptées à chaque contrôle ;
   - visualiser les données avant et après nettoyage.

   RÉSULTATS ATTENDUS AVEC agences.csv :

   - 25 lignes dans raw.agences ;
   - 25 lignes dans staging.agences ;
   - 0 conversion impossible ;
   - 0 agence_id en double ;
   - 0 valeur essentielle manquante ;
   - 0 code postal incorrect ;
   - 0 effectif incohérent ;
   - 15 agences avec au moins un texte corrigé.
   ============================================================ */


/* ------------------------------------------------------------
   USE sélectionne la base utilisée par le script.
   ------------------------------------------------------------ */

USE Banque360;
GO

/* ============================================================
   1. CRÉER OU METTRE À JOUR LA FONCTION DE NETTOYAGE
   ============================================================ */

/* ------------------------------------------------------------
   Une fonction est un traitement réutilisable.

   Elle reçoit un texte, applique les mêmes corrections
   partout, puis renvoie la version nettoyée.

   CREATE OR ALTER signifie :

   - créer la fonction si elle n’existe pas ;
   - la modifier si elle existe déjà.

   Cette fonction pourra aussi être utilisée pour les autres
   tables du schéma staging.
   ------------------------------------------------------------ */

CREATE OR ALTER FUNCTION staging.fn_nettoyer_texte
(
    /* @texte représente le texte reçu par la fonction. */
    @texte NVARCHAR(4000)
)
RETURNS NVARCHAR(4000)
AS
BEGIN

    /* DECLARE crée une variable temporaire. */
    DECLARE @resultat NVARCHAR(4000);

    /* --------------------------------------------------------
       TRIM retire les espaces au début et à la fin.

       NULLIF transforme un texte vide en NULL.
       -------------------------------------------------------- */
    SET @resultat = NULLIF(TRIM(@texte), N'');

    /* Si le texte est vide, la fonction renvoie directement NULL. */
    IF @resultat IS NULL
        RETURN NULL;

    /* --------------------------------------------------------
       REPLACE remplace un texte incorrect par le bon caractère.

       Corrections observées dans les fichiers du projet :

       ├⌐ → é
       ├¿ → è
       ├º → ç
       ├ç → Ç
       ├ë → É
       ├è → Ê
       ├á → à
       ├¬ → ê
       ├┤ → ô
       -------------------------------------------------------- */
    SET @resultat = REPLACE(@resultat, N'├⌐', N'é');
    SET @resultat = REPLACE(@resultat, N'├¿', N'è');
    SET @resultat = REPLACE(@resultat, N'├º', N'ç');
    SET @resultat = REPLACE(@resultat, N'├ç', N'Ç');
    SET @resultat = REPLACE(@resultat, N'├ë', N'É');
    SET @resultat = REPLACE(@resultat, N'├è', N'Ê');
    SET @resultat = REPLACE(@resultat, N'├á', N'à');
    SET @resultat = REPLACE(@resultat, N'├¬', N'ê');
    SET @resultat = REPLACE(@resultat, N'├┤', N'ô');

    /* RETURN renvoie le texte nettoyé. */
    RETURN @resultat;

END;
GO


/* ============================================================
   2. RECRÉER staging.agences
   ============================================================ */

/* ------------------------------------------------------------
   DROP TABLE supprime une table.

   IF EXISTS signifie que la suppression est effectuée
   uniquement si la table existe déjà.

   raw.agences reste intacte.
   ------------------------------------------------------------ */

DROP TABLE IF EXISTS staging.agences;
GO


/* ------------------------------------------------------------
   CREATE TABLE crée la table nettoyée.

   Dans staging, les colonnes utilisent leurs véritables types :

   NVARCHAR
   → texte acceptant les accents.

   DATE
   → date sans heure.

   INT
   → nombre entier.

   NULL
   → valeur manquante autorisée pendant les contrôles.
   ------------------------------------------------------------ */

CREATE TABLE staging.agences
(
    /* Identifiant de l’agence. */
    agence_id NVARCHAR(20) NULL,

    /* Nom de l’agence. */
    nom_agence NVARCHAR(150) NULL,

    /* Ville de l’agence. */
    ville NVARCHAR(100) NULL,

    /* Code postal conservé comme texte afin de préserver
       un éventuel zéro placé au début. */
    code_postal NVARCHAR(10) NULL,

    /* Département de l’agence. */
    departement NVARCHAR(100) NULL,

    /* Région de l’agence. */
    region NVARCHAR(100) NULL,

    /* Véritable date SQL. */
    date_ouverture DATE NULL,

    /* Véritable nombre entier. */
    effectif INT NULL,

    /* Catégorie de l’agence. */
    categorie_agence NVARCHAR(100) NULL
);
GO


/* ============================================================
   3. NETTOYER ET CHARGER LES AGENCES
   ============================================================ */

/* ------------------------------------------------------------
   INSERT INTO indique la table qui reçoit les données.

   SELECT lit les données dans raw.agences et applique
   les transformations avant leur insertion.

   staging.fn_nettoyer_texte
   → nettoie les espaces, les valeurs vides et les accents.

   TRY_CONVERT
   → tente une conversion ;
   → renvoie NULL en cas d’échec sans bloquer le script.

   CASE
   → permet de standardiser les catégories d’agence.
   ------------------------------------------------------------ */

INSERT INTO staging.agences
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

    /* Nettoie l’identifiant de l’agence. */
    staging.fn_nettoyer_texte(agence_id),

    /* Nettoie le nom de l’agence. */
    staging.fn_nettoyer_texte(nom_agence),

    /* Nettoie la ville de l’agence. */
    staging.fn_nettoyer_texte(ville),

    /* Le code postal reste du texte. */
    staging.fn_nettoyer_texte(code_postal),

    /* Nettoie le département. */
    staging.fn_nettoyer_texte(departement),

    /* Nettoie la région. */
    staging.fn_nettoyer_texte(region),

   /* --------------------------------------------------------
   Nettoyage et conversion de la date d’ouverture :

   TRIM
   → supprime les espaces au début et à la fin.

   NULLIF(valeur, N'')
   → transforme un texte vide en NULL.

   TRY_CONVERT(DATE, ..., 23)
   → tente de convertir le texte en DATE.
   → 23 correspond au format AAAA-MM-JJ.
   → renvoie NULL si la conversion est impossible.
   -------------------------------------------------------- */

    TRY_CONVERT(
        DATE,
        NULLIF(TRIM(date_ouverture), N''), -- NULLIF(valeur, N'') renvoie NULL lorsque la valeur est vide.
        23
    ),

    /* Convertit l’effectif en nombre entier. */
    TRY_CONVERT(
        INT,
        NULLIF(TRIM(effectif), N'')
    ),

    /* --------------------------------------------------------
       UPPER transforme temporairement le texte en majuscules.

       Cela permet de regrouper plusieurs écritures possibles :

       urbaine
       Urbaine
       URBAINE

       Toutes deviennent Urbaine.
       -------------------------------------------------------- */
    CASE UPPER(
        staging.fn_nettoyer_texte(categorie_agence)
    )
        WHEN N'URBAINE'      THEN N'Urbaine'
        WHEN N'PÉRIURBAINE'  THEN N'Périurbaine'
        WHEN N'RURALE'       THEN N'Rurale'
        ELSE staging.fn_nettoyer_texte(categorie_agence)
    END

FROM raw.agences;
GO


/* ============================================================
   4. CONTRÔLER LE NOMBRE DE LIGNES
   ============================================================ */

/* ------------------------------------------------------------
   DECLARE crée une variable temporaire.

   Une variable commence par @.

   COUNT(*) compte toutes les lignes d’une table.

   CASE adapte automatiquement la conclusion au résultat.

   CONCAT assemble plusieurs textes et nombres.
   ------------------------------------------------------------ */

DECLARE @nombre_raw INT =
(
    SELECT COUNT(*)
    FROM raw.agences
);

DECLARE @nombre_staging INT =
(
    SELECT COUNT(*)
    FROM staging.agences
);

SELECT
    @nombre_raw AS lignes_raw,
    @nombre_staging AS lignes_staging,

    CASE
        WHEN @nombre_raw = @nombre_staging
        THEN CONCAT(
            N'CONCLUSION : OK. Les ',
            @nombre_raw,
            N' agences de raw.agences ont été chargées dans ',
            N'staging.agences sans perte de ligne.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. Il existe une différence de ',
            ABS(@nombre_raw - @nombre_staging),
            N' ligne(s) entre raw et staging.'
        )
    END AS conclusion;
GO


/* ============================================================
   5. CONTRÔLER LES CONVERSIONS
   ============================================================ */

/* ------------------------------------------------------------
   Ce contrôle recherche les valeurs non vides qui n’ont pas
   pu être converties :

   - date_ouverture vers DATE ;
   - effectif vers INT.

   Résultat attendu : 0 conversion impossible.
   ------------------------------------------------------------ */

DECLARE @conversions_impossibles INT =
(
    SELECT COUNT(*)
    FROM raw.agences
    WHERE
    (
        NULLIF(TRIM(date_ouverture), N'') IS NOT NULL
        AND TRY_CONVERT(
                DATE,
                TRIM(date_ouverture),
                23
            ) IS NULL
    )
    OR
    (
        NULLIF(TRIM(effectif), N'') IS NOT NULL
        AND TRY_CONVERT(
                INT,
                TRIM(effectif)
            ) IS NULL
    )
);

SELECT
    @conversions_impossibles AS conversions_impossibles,

    CASE
        WHEN @conversions_impossibles = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Toutes les dates d’ouverture ',
            N'et tous les effectifs ont été correctement convertis.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @conversions_impossibles,
            N' agence(s) contiennent une conversion impossible.'
        )
    END AS conclusion;
GO


/* Affiche les éventuelles valeurs impossibles à convertir.

   Si seules les colonnes apparaissent, aucune erreur
   de conversion n’a été détectée. */
SELECT
    agence_id,
    date_ouverture AS date_source_invalide,
    effectif AS effectif_source_invalide
FROM raw.agences
WHERE
(
    NULLIF(TRIM(date_ouverture), N'') IS NOT NULL
    AND TRY_CONVERT(
            DATE,
            TRIM(date_ouverture),
            23
        ) IS NULL
)
OR
(
    NULLIF(TRIM(effectif), N'') IS NOT NULL
    AND TRY_CONVERT(
            INT,
            TRIM(effectif)
        ) IS NULL
);
GO


/* ============================================================
   6. CONTRÔLER LES DOUBLONS
   ============================================================ */

/* ------------------------------------------------------------
   GROUP BY regroupe les lignes ayant le même agence_id.

   HAVING COUNT(*) > 1 conserve uniquement les identifiants
   présents plusieurs fois.

   Le premier contrôle compte le nombre d’identifiants dupliqués.

   Le deuxième indique le nombre de lignes supplémentaires
   provoquées par ces doublons.
   ------------------------------------------------------------ */

DECLARE @identifiants_dupliques INT;
DECLARE @lignes_en_trop INT;

SELECT
    @identifiants_dupliques = COUNT(*),

    @lignes_en_trop =
        COALESCE(SUM(nombre_occurrences - 1), 0) -- Additionne toutes les lignes en trop dues aux doublons et renvoie 0 s’il n’y en a aucun

FROM
(
    SELECT
        agence_id,
        COUNT(*) AS nombre_occurrences
    FROM staging.agences
    WHERE agence_id IS NOT NULL
    GROUP BY agence_id
    HAVING COUNT(*) > 1
) AS doublons;

SELECT
    @identifiants_dupliques AS identifiants_dupliques,
    @lignes_en_trop AS lignes_en_trop,

    CASE
        WHEN @identifiants_dupliques = 0
        THEN N'CONCLUSION : OK. Aucun agence_id en double.'

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @identifiants_dupliques,
            N' identifiant(s) d’agence sont dupliqués, soit ',
            @lignes_en_trop,
            N' ligne(s) en trop.'
        )
    END AS conclusion;
GO


/* Affiche les éventuels identifiants dupliqués. */
SELECT
    agence_id,
    COUNT(*) AS nombre_occurrences
FROM staging.agences
WHERE agence_id IS NOT NULL
GROUP BY agence_id
HAVING COUNT(*) > 1
ORDER BY nombre_occurrences DESC, agence_id;
GO


/* ============================================================
   7. CONTRÔLER LES VALEURS ESSENTIELLES MANQUANTES
   ============================================================ */

/* ------------------------------------------------------------
   Champs considérés comme essentiels :

   - agence_id ;
   - nom_agence ;
   - ville ;
   - code_postal ;
   - région ;
   - catégorie de l’agence.

   Une agence n’est comptée qu’une seule fois, même si plusieurs
   champs sont manquants sur la même ligne.
   ------------------------------------------------------------ */
   
DECLARE @agences_incompletes INT =
(
    SELECT COUNT(*)
    FROM staging.agences
    WHERE agence_id IS NULL
       OR nom_agence IS NULL
       OR ville IS NULL
       OR code_postal IS NULL
       OR region IS NULL
       OR categorie_agence IS NULL
);

SELECT
    @agences_incompletes AS agences_incompletes,

    CASE
        WHEN @agences_incompletes = 0
        THEN N'CONCLUSION : OK. Aucun champ essentiel manquant.'

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @agences_incompletes,
            N' agence(s) ont au moins un champ essentiel manquant.'
        )
    END AS conclusion;
GO


/* Affiche les éventuelles agences incomplètes. */
SELECT
    agence_id,
    nom_agence,
    ville,
    code_postal,
    region,
    categorie_agence
FROM staging.agences
WHERE agence_id IS NULL
   OR nom_agence IS NULL
   OR ville IS NULL
   OR code_postal IS NULL
   OR region IS NULL
   OR categorie_agence IS NULL
ORDER BY agence_id;
GO


/* ============================================================
   8. CONTRÔLER LES CODES POSTAUX
   ============================================================ */

/* ------------------------------------------------------------
   LEN mesure le nombre de caractères.

   LIKE N'%[^0-9]%'
   → recherche au moins un caractère qui n’est pas un chiffre.

   Un code postal français doit normalement contenir
   exactement cinq chiffres.

   Résultat attendu : 0 code postal incorrect.
   ------------------------------------------------------------ */

DECLARE @codes_postaux_invalides INT =
(
    SELECT COUNT(*)
    FROM staging.agences
    WHERE code_postal IS NOT NULL
      AND
      (
          LEN(code_postal) <> 5
          OR code_postal LIKE N'%[^0-9]%'
      )
);

SELECT
    @codes_postaux_invalides AS codes_postaux_invalides,

    CASE
        WHEN @codes_postaux_invalides = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Les 25 codes postaux contiennent ',
            N'exactement cinq chiffres.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @codes_postaux_invalides,
            N' code(s) postal(aux) ont un format incorrect.'
        )
    END AS conclusion;
GO


/* Affiche les éventuels codes postaux incorrects. */
SELECT
    agence_id,
    ville,
    code_postal
FROM staging.agences
WHERE code_postal IS NOT NULL
  AND
  (
      LEN(code_postal) <> 5
      OR code_postal LIKE N'%[^0-9]%'
  )
ORDER BY agence_id;
GO


/* ============================================================
   9. CONTRÔLER LES EFFECTIFS
   ============================================================ */

/* ------------------------------------------------------------
   Un effectif nul ou négatif serait incohérent.

   Résultat attendu avec le fichier fourni :

   - 0 effectif incohérent ;
   - minimum : 7 salariés ;
   - maximum : 27 salariés.
   ------------------------------------------------------------ */

DECLARE @effectifs_invalides INT =
(
    SELECT COUNT(*)
    FROM staging.agences
    WHERE effectif IS NULL
       OR effectif <= 0
);

SELECT
    @effectifs_invalides AS effectifs_invalides,
    MIN(effectif) AS effectif_minimum,
    MAX(effectif) AS effectif_maximum,

    CASE
        WHEN @effectifs_invalides = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Tous les effectifs sont positifs. ',
            N'Ils sont compris entre ',
            MIN(effectif),
            N' et ',
            MAX(effectif),
            N' salariés.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @effectifs_invalides,
            N' agence(s) ont un effectif manquant, nul ou négatif.'
        )
    END AS conclusion

FROM staging.agences;
GO


/* Affiche les éventuels effectifs incohérents. */
SELECT
    agence_id,
    nom_agence,
    effectif
FROM staging.agences
WHERE effectif IS NULL
   OR effectif <= 0
ORDER BY agence_id;
GO


/* ============================================================
   10. CONTRÔLER LES DATES D’OUVERTURE
   ============================================================ */

/* ------------------------------------------------------------
   GETDATE() renvoie la date et l’heure actuelles.

   CAST(... AS DATE) conserve seulement la date.

   Une date d’ouverture future serait incohérente.

   MIN et MAX permettent également de connaître la période
   couverte par le fichier.
   ------------------------------------------------------------ */

DECLARE @dates_invalides INT =
(
    SELECT COUNT(*)
    FROM staging.agences
    WHERE date_ouverture IS NULL
       OR date_ouverture > CAST(GETDATE() AS DATE)
);

SELECT
    @dates_invalides AS dates_invalides,
    MIN(date_ouverture) AS premiere_date_ouverture,
    MAX(date_ouverture) AS derniere_date_ouverture,

    CASE
        WHEN @dates_invalides = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Toutes les dates sont valides. ',
            N'Les ouvertures vont du ',
            CONVERT(NVARCHAR(10), MIN(date_ouverture), 103),
            N' au ',
            CONVERT(NVARCHAR(10), MAX(date_ouverture), 103),
            N'.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @dates_invalides,
            N' agence(s) ont une date absente ou future.'
        )
    END AS conclusion

FROM staging.agences;
GO


/* Affiche les éventuelles dates incohérentes. */
SELECT
    agence_id,
    nom_agence,
    date_ouverture
FROM staging.agences
WHERE date_ouverture IS NULL
   OR date_ouverture > CAST(GETDATE() AS DATE)
ORDER BY agence_id;
GO


/* ============================================================
   11. CONTRÔLER LES CATÉGORIES D’AGENCE
   ============================================================ */

/* ------------------------------------------------------------
   Trois catégories sont attendues dans le fichier :

   - Urbaine ;
   - Périurbaine ;
   - Rurale.

   NOT IN recherche les valeurs qui ne font pas partie
   de cette liste.
   ------------------------------------------------------------ */

DECLARE @categories_inconnues INT =
(
    SELECT COUNT(*)
    FROM staging.agences
    WHERE categorie_agence IS NULL
       OR categorie_agence NOT IN
       (
           N'Urbaine',
           N'Périurbaine',
           N'Rurale'
       )
);

SELECT
    @categories_inconnues AS categories_inconnues,

    CASE
        WHEN @categories_inconnues = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Toutes les agences appartiennent ',
            N'à une catégorie connue.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @categories_inconnues,
            N' agence(s) ont une catégorie inconnue.'
        )
    END AS conclusion;
GO


/* Affiche la répartition des agences par catégorie. */
SELECT
    categorie_agence,
    COUNT(*) AS nombre_agences
FROM staging.agences
GROUP BY categorie_agence
ORDER BY categorie_agence;
GO


/* ============================================================
   12. CONTRÔLER LES CARACTÈRES MAL ENCODÉS
   ============================================================ */

/* ------------------------------------------------------------
   CONCAT assemble plusieurs colonnes textuelles.

   LIKE recherche les symboles associés aux problèmes
   d’encodage déjà rencontrés :

   ├
   √
   Ã

   Résultat attendu : 0 agence avec un caractère incorrect.
   ------------------------------------------------------------ */

DECLARE @encodages_incorrects INT =
(
    SELECT COUNT(*)
    FROM staging.agences
    WHERE CONCAT(
        nom_agence,
        ville,
        departement,
        region,
        categorie_agence
    ) LIKE N'%├%'

    OR CONCAT(
        nom_agence,
        ville,
        departement,
        region,
        categorie_agence
    ) LIKE N'%√%'

    OR CONCAT(
        nom_agence,
        ville,
        departement,
        region,
        categorie_agence
    ) LIKE N'%Ã%'
);

SELECT
    @encodages_incorrects AS agences_encodage_incorrect,

    CASE
        WHEN @encodages_incorrects = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Aucun caractère d’encodage ',
            N'incorrect connu ne reste dans staging.agences.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @encodages_incorrects,
            N' agence(s) contiennent encore un caractère incorrect.'
        )
    END AS conclusion;
GO


/* Affiche les éventuelles agences encore mal encodées. */
SELECT
    agence_id,
    nom_agence,
    ville,
    departement,
    region,
    categorie_agence
FROM staging.agences
WHERE CONCAT(
        nom_agence,
        ville,
        departement,
        region,
        categorie_agence
      ) LIKE N'%├%'

   OR CONCAT(
        nom_agence,
        ville,
        departement,
        region,
        categorie_agence
      ) LIKE N'%√%'

   OR CONCAT(
        nom_agence,
        ville,
        departement,
        region,
        categorie_agence
      ) LIKE N'%Ã%'

ORDER BY agence_id;
GO


/* ============================================================
   13. MESURER LES TEXTES MODIFIÉS
   ============================================================ */

/* ------------------------------------------------------------
   ISNULL remplace temporairement NULL par un texte vide.

   <> signifie « différent de ».

   Ce contrôle compte les agences pour lesquelles au moins
   une valeur textuelle a été modifiée pendant le nettoyage.

   Résultat attendu : 15 agences.
   ------------------------------------------------------------ */

DECLARE @agences_textes_modifies INT =
(
    SELECT COUNT(*)
    FROM raw.agences AS r

    INNER JOIN staging.agences AS s
        ON TRIM(r.agence_id) = s.agence_id

    WHERE
        ISNULL(NULLIF(TRIM(r.nom_agence), N''), N'')
            <> ISNULL(s.nom_agence, N'')

        OR ISNULL(NULLIF(TRIM(r.ville), N''), N'')
            <> ISNULL(s.ville, N'')

        OR ISNULL(NULLIF(TRIM(r.departement), N''), N'')
            <> ISNULL(s.departement, N'')

        OR ISNULL(NULLIF(TRIM(r.region), N''), N'')
            <> ISNULL(s.region, N'')

        OR ISNULL(NULLIF(TRIM(r.categorie_agence), N''), N'')
            <> ISNULL(s.categorie_agence, N'')
);

SELECT
    @agences_textes_modifies AS agences_textes_modifies,

    CASE
        WHEN @agences_textes_modifies = 0
        THEN N'CONCLUSION : aucune valeur textuelle n’a été modifiée.'

        ELSE CONCAT(
            N'CONCLUSION : ',
            @agences_textes_modifies,
            N' agence(s) ont au moins une valeur textuelle corrigée ',
            N'ou standardisée.'
        )
    END AS conclusion;
GO


/* ============================================================
   14. AFFICHER L’AVANT ET L’APRÈS
   ============================================================ */

/* ------------------------------------------------------------
   r représente raw.agences.
   s représente staging.agences.

   INNER JOIN associe les versions brute et nettoyée
   grâce à agence_id.

   Seules les agences réellement modifiées sont affichées.
   ------------------------------------------------------------ */

SELECT
    r.agence_id,

    r.nom_agence AS nom_avant,
    s.nom_agence AS nom_apres,

    r.ville AS ville_avant,
    s.ville AS ville_apres,

    r.departement AS departement_avant,
    s.departement AS departement_apres,

    r.region AS region_avant,
    s.region AS region_apres,

    r.categorie_agence AS categorie_avant,
    s.categorie_agence AS categorie_apres,

    r.date_ouverture AS date_avant_texte,
    s.date_ouverture AS date_apres_date,

    r.effectif AS effectif_avant_texte,
    s.effectif AS effectif_apres_entier

FROM raw.agences AS r

INNER JOIN staging.agences AS s
    ON TRIM(r.agence_id) = s.agence_id

WHERE
    ISNULL(NULLIF(TRIM(r.nom_agence), N''), N'')
        <> ISNULL(s.nom_agence, N'')

    OR ISNULL(NULLIF(TRIM(r.ville), N''), N'')
        <> ISNULL(s.ville, N'')

    OR ISNULL(NULLIF(TRIM(r.departement), N''), N'')
        <> ISNULL(s.departement, N'')

    OR ISNULL(NULLIF(TRIM(r.region), N''), N'')
        <> ISNULL(s.region, N'')

    OR ISNULL(NULLIF(TRIM(r.categorie_agence), N''), N'')
        <> ISNULL(s.categorie_agence, N'')

ORDER BY s.agence_id;
GO


/* ============================================================
   15. AFFICHER LA TABLE NETTOYÉE
   ============================================================ */

/* ------------------------------------------------------------
   SELECT * affiche toutes les colonnes.

   La table ne contient que 25 agences : il est donc pertinent
   de l’afficher entièrement pour une dernière vérification.
   ------------------------------------------------------------ */

SELECT *
FROM staging.agences
ORDER BY agence_id;
GO


/* ============================================================
   CONCLUSION DU NETTOYAGE DE staging.agences

   Résultats correspondant au fichier agences.csv fourni :

   1. Nombre de lignes
      - raw.agences contient 25 lignes.
      - staging.agences contient également 25 lignes.
      - Aucune agence n’a été perdue pendant le nettoyage.

   2. Conversions
      - 0 date d’ouverture impossible à convertir.
      - 0 effectif impossible à convertir.
      - date_ouverture est maintenant de type DATE.
      - effectif est maintenant de type INT.

   3. Doublons
      - 0 agence_id en double.
      - Les 25 agences possèdent un identifiant unique.

   4. Valeurs essentielles
      - 0 agence sans identifiant.
      - 0 agence sans nom.
      - 0 agence sans ville.
      - 0 agence sans code postal.
      - 0 agence sans région ou catégorie.

   5. Codes postaux
      - Les 25 codes postaux contiennent cinq chiffres.
      - Aucun format incorrect n’a été détecté.

   6. Effectifs
      - Aucun effectif nul ou négatif.
      - Les effectifs sont compris entre 7 et 27 salariés.

   7. Dates d’ouverture
      - Aucune date future ou manquante.
      - Les dates vont du 3 août 1995 au 8 juin 2017.

   8. Catégories
      - Toutes les agences appartiennent à une catégorie connue :
        Urbaine, Périurbaine ou Rurale.

   9. Correction des textes
      - 15 agences avaient au moins une valeur textuelle
        mal encodée ou à standardiser.
      - Les accents ont notamment été corrigés dans :

        Mérignac
        Pyrénées-Atlantiques
        Deux-Sèvres
        Corrèze
        Périgueux
        Périurbaine

      - Aucun caractère d’encodage incorrect connu ne reste.

   RÉSULTAT FINAL :

   staging.agences contient 25 agences uniques,
   correctement typées, nettoyées et prêtes à être utilisées
   pour les relations et les analyses suivantes.
   ============================================================ */