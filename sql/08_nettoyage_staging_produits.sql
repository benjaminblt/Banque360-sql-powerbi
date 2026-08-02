/* ============================================================
   PROJET : Banque 360
   FICHIER : 08_nettoyage_staging_produits.sql

   ÉTAPE DU FICHIER :

   Étape 6 sur 8
   Nettoyer les données dans staging

   AVANCEMENT :

   Étapes 1 à 5 : TERMINÉES
   Étape 6 : EN COURS (partie 5/7)

   TABLE TRAITÉE :

   raw.produits → staging.produits

   GRAIN DE LA TABLE :

   Une ligne représente un produit bancaire.

   La clé métier est :

   produit_id

   OBJECTIF :

   - nettoyer les textes et les espaces ;
   - corriger les caractères mal encodés ;
   - convertir le niveau de complexité en nombre entier ;
   - standardiser les familles et univers produits ;
   - vérifier l’unicité des produits ;
   - contrôler les valeurs manquantes ;
   - vérifier le format des identifiants ;
   - contrôler les niveaux de complexité ;
   - conserver raw.produits intacte.

   RÉSULTATS ATTENDUS AVEC produits.csv :

   - 10 lignes dans raw.produits ;
   - 10 lignes dans staging.produits ;
   - 0 conversion impossible ;
   - 0 produit_id dupliqué ;
   - 0 valeur manquante ;
   - 0 identifiant incorrect ;
   - 5 familles de produits ;
   - 5 univers ;
   - niveaux de complexité compris entre 1 et 4.
   ============================================================ */


USE Banque360;
GO


/* ============================================================
   1. RECRÉER staging.produits
   ============================================================ */

/* Supprime uniquement l’ancienne table nettoyée.

   raw.produits reste intacte et conserve les données
   telles qu’elles ont été importées. */
DROP TABLE IF EXISTS staging.produits;
GO


/* ------------------------------------------------------------
   TYPES DES COLONNES :

   NVARCHAR
   → texte acceptant les accents et caractères Unicode.

   INT
   → nombre entier.
   ------------------------------------------------------------ */
CREATE TABLE staging.produits
(
    /* Identifiant unique du produit.

       Cette colonne servira de clé pour relier les produits
       aux futures tables de faits. */
    produit_id NVARCHAR(20) NULL,

    /* Nom commercial du produit bancaire. */
    nom_produit NVARCHAR(150) NULL,

    /* Grande famille à laquelle appartient le produit. */
    famille_produit NVARCHAR(100) NULL,

    /* Univers commercial ou métier du produit. */
    univers NVARCHAR(100) NULL,

    /* Niveau ordinal représentant la complexité du produit. */
    niveau_complexite INT NULL
);
GO


/* ============================================================
   2. NETTOYER ET CHARGER LES PRODUITS
   ============================================================ */

/* ------------------------------------------------------------
   staging.fn_nettoyer_texte :

   - supprime les espaces inutiles ;
   - transforme les textes vides en NULL ;
   - corrige les caractères accentués mal interprétés.

   UPPER :

   - transforme temporairement le texte en majuscules ;
   - permet de regrouper différentes écritures d’une catégorie.

   TRY_CONVERT :

   - tente de convertir le niveau de complexité en entier ;
   - renvoie NULL si la conversion est impossible.
   ------------------------------------------------------------ */
INSERT INTO staging.produits
(
    produit_id,
    nom_produit,
    famille_produit,
    univers,
    niveau_complexite
)
SELECT

    /* Nettoie et uniformise l’identifiant en majuscules. */
    UPPER(
        staging.fn_nettoyer_texte(produit_id)
    ) AS produit_id,

    /* Nettoie le nom du produit sans modifier son sens. */
    staging.fn_nettoyer_texte(nom_produit)
        AS nom_produit,

    /* Standardise les cinq familles de produits. */
    CASE UPPER(
        staging.fn_nettoyer_texte(famille_produit)
    )
        WHEN N'COMPTE'
            THEN N'Compte'

        WHEN N'CARTE'
            THEN N'Carte'

        WHEN N'ÉPARGNE'
            THEN N'Épargne'

        WHEN N'CRÉDIT'
            THEN N'Crédit'

        WHEN N'ASSURANCE'
            THEN N'Assurance'

        ELSE staging.fn_nettoyer_texte(famille_produit)
    END AS famille_produit,

    /* Standardise les cinq univers produits. */
    CASE UPPER(
        staging.fn_nettoyer_texte(univers)
    )
        WHEN N'ÉPARGNE ET FLUX'
            THEN N'Épargne et flux'

        WHEN N'MOYENS DE PAIEMENT'
            THEN N'Moyens de paiement'

        WHEN N'PLACEMENT'
            THEN N'Placement'

        WHEN N'FINANCEMENT'
            THEN N'Financement'

        WHEN N'PROTECTION'
            THEN N'Protection'

        ELSE staging.fn_nettoyer_texte(univers)
    END AS univers,

    /* Convertit le niveau de complexité en entier. */
    TRY_CONVERT(
        INT,
        NULLIF(TRIM(niveau_complexite), N'')
    ) AS niveau_complexite

FROM raw.produits;
GO


/* ============================================================
   3. CONTRÔLER LE NOMBRE DE LIGNES
   ============================================================ */

DECLARE @lignes_raw INT =
(
    SELECT COUNT(*)
    FROM raw.produits
);

DECLARE @lignes_staging INT =
(
    SELECT COUNT(*)
    FROM staging.produits
);

SELECT
    @lignes_raw AS lignes_raw,
    @lignes_staging AS lignes_staging,

    CASE
        WHEN @lignes_raw = @lignes_staging
        THEN CONCAT(
            N'CONCLUSION : OK. Les ',
            @lignes_raw,
            N' produits ont été chargés dans staging.produits ',
            N'sans perte de ligne.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. Il existe une différence de ',
            ABS(@lignes_raw - @lignes_staging),
            N' ligne(s) entre raw.produits et staging.produits.'
        )
    END AS conclusion;
GO


/* ============================================================
   4. CONTRÔLER LA CONVERSION DU NIVEAU DE COMPLEXITÉ
   ============================================================ */

/* ------------------------------------------------------------
   Une valeur est considérée comme impossible à convertir si :

   - elle n’est pas vide dans raw ;
   - TRY_CONVERT ne parvient pas à la transformer en INT.
   ------------------------------------------------------------ */
DECLARE @conversions_impossibles INT =
(
    SELECT COUNT(*)
    FROM raw.produits
    WHERE NULLIF(TRIM(niveau_complexite), N'') IS NOT NULL

      AND TRY_CONVERT(
              INT,
              TRIM(niveau_complexite)
          ) IS NULL
);

SELECT
    @conversions_impossibles AS conversions_impossibles,

    CASE
        WHEN @conversions_impossibles = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Tous les niveaux de complexité ',
            N'ont été correctement convertis en nombres entiers.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @conversions_impossibles,
            N' produit(s) ont un niveau de complexité impossible ',
            N'à convertir.'
        )
    END AS conclusion;
GO


/* Affiche les éventuelles conversions impossibles.

   Si seules les colonnes apparaissent, aucune erreur
   de conversion n’a été détectée. */
SELECT
    produit_id,
    nom_produit,
    niveau_complexite AS valeur_source_invalide

FROM raw.produits

WHERE NULLIF(TRIM(niveau_complexite), N'') IS NOT NULL

  AND TRY_CONVERT(
          INT,
          TRIM(niveau_complexite)
      ) IS NULL

ORDER BY produit_id;
GO


/* ============================================================
   5. CONTRÔLER LES DOUBLONS
   ============================================================ */

/* ------------------------------------------------------------
   Un produit_id doit identifier un seul produit.

   nombre_occurrences - 1
   → calcule le nombre de lignes supplémentaires.

   COALESCE
   → renvoie 0 si aucun doublon n’existe.
   ------------------------------------------------------------ */
DECLARE @produits_dupliques INT;
DECLARE @lignes_dupliquees INT;

SELECT
    @produits_dupliques = COUNT(*),

    @lignes_dupliquees =
        COALESCE(SUM(nombre_occurrences - 1), 0)

FROM
(
    SELECT
        produit_id,
        COUNT(*) AS nombre_occurrences

    FROM staging.produits

    WHERE produit_id IS NOT NULL

    GROUP BY produit_id

    HAVING COUNT(*) > 1
) AS doublons;

SELECT
    @produits_dupliques AS identifiants_dupliques,
    @lignes_dupliquees AS lignes_dupliquees,

    CASE
        WHEN @produits_dupliques = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Aucun produit_id en double. ',
            N'Chaque produit possède un identifiant unique.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @produits_dupliques,
            N' produit_id sont dupliqués, soit ',
            @lignes_dupliquees,
            N' ligne(s) supplémentaire(s).'
        )
    END AS conclusion;
GO


/* Affiche les éventuels produits dupliqués. */
SELECT
    produit_id,
    COUNT(*) AS nombre_occurrences

FROM staging.produits

WHERE produit_id IS NOT NULL

GROUP BY produit_id

HAVING COUNT(*) > 1

ORDER BY
    nombre_occurrences DESC,
    produit_id;
GO


/* ============================================================
   6. CONTRÔLER LES VALEURS MANQUANTES
   ============================================================ */

/* ------------------------------------------------------------
   Toutes les colonnes sont nécessaires pour décrire
   correctement un produit.

   Une ligne n’est comptée qu’une seule fois, même si plusieurs
   colonnes sont manquantes.
   ------------------------------------------------------------ */
DECLARE @produits_incomplets INT =
(
    SELECT COUNT(*)
    FROM staging.produits
    WHERE produit_id IS NULL
       OR nom_produit IS NULL
       OR famille_produit IS NULL
       OR univers IS NULL
       OR niveau_complexite IS NULL
);

SELECT
    @produits_incomplets AS produits_incomplets,

    CASE
        WHEN @produits_incomplets = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Les 10 produits possèdent toutes ',
            N'leurs informations obligatoires.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @produits_incomplets,
            N' produit(s) ont au moins une valeur manquante.'
        )
    END AS conclusion;
GO


/* Affiche les éventuels produits incomplets. */
SELECT
    produit_id,
    nom_produit,
    famille_produit,
    univers,
    niveau_complexite

FROM staging.produits

WHERE produit_id IS NULL
   OR nom_produit IS NULL
   OR famille_produit IS NULL
   OR univers IS NULL
   OR niveau_complexite IS NULL

ORDER BY produit_id;
GO


/* ============================================================
   7. CONTRÔLER LE FORMAT DES IDENTIFIANTS
   ============================================================ */

/* ------------------------------------------------------------
   Format attendu :

   P suivi de trois chiffres.

   Exemples :

   P001
   P007
   P010

   LEN(produit_id) <> 4
   → vérifie la longueur.

   NOT LIKE N'P[0-9][0-9][0-9]'
   → vérifie la lettre P suivie de trois chiffres.
   ------------------------------------------------------------ */
DECLARE @identifiants_invalides INT =
(
    SELECT COUNT(*)
    FROM staging.produits
    WHERE produit_id IS NULL

       OR LEN(produit_id) <> 4

       OR produit_id NOT LIKE N'P[0-9][0-9][0-9]'
);

SELECT
    @identifiants_invalides AS identifiants_invalides,

    CASE
        WHEN @identifiants_invalides = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Tous les produit_id respectent ',
            N'le format P suivi de trois chiffres.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @identifiants_invalides,
            N' produit_id ont un format incorrect.'
        )
    END AS conclusion;
GO


/* Affiche les éventuels identifiants incorrects. */
SELECT
    produit_id,
    nom_produit

FROM staging.produits

WHERE produit_id IS NULL
   OR LEN(produit_id) <> 4
   OR produit_id NOT LIKE N'P[0-9][0-9][0-9]'

ORDER BY produit_id;
GO


/* ============================================================
   8. CONTRÔLER LES NIVEAUX DE COMPLEXITÉ
   ============================================================ */

/* ------------------------------------------------------------
   Dans ce référentiel, les niveaux observés vont de 1 à 4.

   1
   → produit simple.

   4
   → produit le plus complexe du catalogue actuel.
   ------------------------------------------------------------ */
DECLARE @niveaux_invalides INT =
(
    SELECT COUNT(*)
    FROM staging.produits
    WHERE niveau_complexite IS NULL
       OR niveau_complexite NOT BETWEEN 1 AND 4
);

SELECT
    @niveaux_invalides AS niveaux_invalides,
    MIN(niveau_complexite) AS niveau_minimum,
    MAX(niveau_complexite) AS niveau_maximum,

    CASE
        WHEN @niveaux_invalides = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Tous les niveaux de complexité ',
            N'sont compris entre ',
            MIN(niveau_complexite),
            N' et ',
            MAX(niveau_complexite),
            N'.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @niveaux_invalides,
            N' produit(s) possèdent un niveau de complexité ',
            N'en dehors de l’intervalle 1 à 4.'
        )
    END AS conclusion

FROM staging.produits;
GO


/* Affiche les éventuels niveaux incorrects. */
SELECT
    produit_id,
    nom_produit,
    niveau_complexite

FROM staging.produits

WHERE niveau_complexite IS NULL
   OR niveau_complexite NOT BETWEEN 1 AND 4

ORDER BY produit_id;
GO


/* ============================================================
   9. AFFICHER LA RÉPARTITION PAR NIVEAU DE COMPLEXITÉ
   ============================================================ */

SELECT
    niveau_complexite,
    COUNT(*) AS nombre_produits,

    CONCAT(
        N'CONCLUSION : ',
        COUNT(*),
        N' produit(s) possèdent le niveau de complexité ',
        niveau_complexite,
        N'.'
    ) AS conclusion

FROM staging.produits

GROUP BY niveau_complexite

ORDER BY niveau_complexite;
GO


/* ============================================================
   10. CONTRÔLER LES FAMILLES DE PRODUITS
   ============================================================ */

/* ------------------------------------------------------------
   Cinq familles sont attendues :

   - Compte ;
   - Carte ;
   - Épargne ;
   - Crédit ;
   - Assurance.
   ------------------------------------------------------------ */
DECLARE @familles_inconnues INT =
(
    SELECT COUNT(*)
    FROM staging.produits
    WHERE famille_produit IS NULL

       OR famille_produit NOT IN
       (
           N'Compte',
           N'Carte',
           N'Épargne',
           N'Crédit',
           N'Assurance'
       )
);

DECLARE @nombre_familles INT =
(
    SELECT COUNT(DISTINCT famille_produit)
    FROM staging.produits
);

SELECT
    @familles_inconnues AS familles_inconnues,
    @nombre_familles AS familles_distinctes,

    CASE
        WHEN @familles_inconnues = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Les produits sont répartis dans ',
            @nombre_familles,
            N' familles connues.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @familles_inconnues,
            N' produit(s) appartiennent à une famille inconnue.'
        )
    END AS conclusion;
GO


/* Affiche la répartition par famille. */
SELECT
    famille_produit,
    COUNT(*) AS nombre_produits,

    CONCAT(
        N'CONCLUSION : la famille ',
        famille_produit,
        N' contient ',
        COUNT(*),
        N' produit(s).'
    ) AS conclusion

FROM staging.produits

GROUP BY famille_produit

ORDER BY famille_produit;
GO


/* Affiche les éventuelles familles inconnues. */
SELECT
    produit_id,
    nom_produit,
    famille_produit

FROM staging.produits

WHERE famille_produit IS NULL

   OR famille_produit NOT IN
   (
       N'Compte',
       N'Carte',
       N'Épargne',
       N'Crédit',
       N'Assurance'
   )

ORDER BY produit_id;
GO


/* ============================================================
   11. CONTRÔLER LES UNIVERS PRODUITS
   ============================================================ */

/* ------------------------------------------------------------
   Cinq univers sont attendus :

   - Épargne et flux ;
   - Moyens de paiement ;
   - Placement ;
   - Financement ;
   - Protection.
   ------------------------------------------------------------ */
DECLARE @univers_inconnus INT =
(
    SELECT COUNT(*)
    FROM staging.produits
    WHERE univers IS NULL

       OR univers NOT IN
       (
           N'Épargne et flux',
           N'Moyens de paiement',
           N'Placement',
           N'Financement',
           N'Protection'
       )
);

DECLARE @nombre_univers INT =
(
    SELECT COUNT(DISTINCT univers)
    FROM staging.produits
);

SELECT
    @univers_inconnus AS univers_inconnus,
    @nombre_univers AS univers_distincts,

    CASE
        WHEN @univers_inconnus = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Les produits sont répartis dans ',
            @nombre_univers,
            N' univers connus.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @univers_inconnus,
            N' produit(s) appartiennent à un univers inconnu.'
        )
    END AS conclusion;
GO


/* Affiche la répartition par univers. */
SELECT
    univers,
    COUNT(*) AS nombre_produits,

    CONCAT(
        N'CONCLUSION : l’univers ',
        univers,
        N' contient ',
        COUNT(*),
        N' produit(s).'
    ) AS conclusion

FROM staging.produits

GROUP BY univers

ORDER BY univers;
GO


/* Affiche les éventuels univers inconnus. */
SELECT
    produit_id,
    nom_produit,
    univers

FROM staging.produits

WHERE univers IS NULL

   OR univers NOT IN
   (
       N'Épargne et flux',
       N'Moyens de paiement',
       N'Placement',
       N'Financement',
       N'Protection'
   )

ORDER BY produit_id;
GO


/* ============================================================
   12. CONTRÔLER LES CARACTÈRES MAL ENCODÉS
   ============================================================ */

/* ------------------------------------------------------------
   Recherche les symboles déjà rencontrés lors de l’import :

   ├
   √
   Ã

   Résultat attendu : 0.
   ------------------------------------------------------------ */
DECLARE @encodages_incorrects INT =
(
    SELECT COUNT(*)
    FROM staging.produits
    WHERE CONCAT(
        nom_produit,
        famille_produit,
        univers
    ) LIKE N'%├%'

    OR CONCAT(
        nom_produit,
        famille_produit,
        univers
    ) LIKE N'%√%'

    OR CONCAT(
        nom_produit,
        famille_produit,
        univers
    ) LIKE N'%Ã%'
);

SELECT
    @encodages_incorrects AS produits_encodage_incorrect,

    CASE
        WHEN @encodages_incorrects = 0
        THEN CONCAT(
            N'CONCLUSION : OK. Aucun caractère mal encodé connu ',
            N'ne reste dans staging.produits.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @encodages_incorrects,
            N' produit(s) contiennent encore un caractère incorrect.'
        )
    END AS conclusion;
GO


/* Affiche les éventuels textes encore mal encodés. */
SELECT
    produit_id,
    nom_produit,
    famille_produit,
    univers

FROM staging.produits

WHERE CONCAT(
        nom_produit,
        famille_produit,
        univers
      ) LIKE N'%├%'

   OR CONCAT(
        nom_produit,
        famille_produit,
        univers
      ) LIKE N'%√%'

   OR CONCAT(
        nom_produit,
        famille_produit,
        univers
      ) LIKE N'%Ã%'

ORDER BY produit_id;
GO


/* ============================================================
   13. MESURER LES TEXTES MODIFIÉS
   ============================================================ */

/* ------------------------------------------------------------
   Ce contrôle compte les produits pour lesquels au moins
   une valeur textuelle a été corrigée ou standardisée.

   Les modifications concernent principalement les accents :

   Épargne
   Crédit
   Prêt
   réglementé
   ------------------------------------------------------------ */
DECLARE @produits_textes_modifies INT =
(
    SELECT COUNT(*)

    FROM raw.produits AS r

    INNER JOIN staging.produits AS s
        ON UPPER(NULLIF(TRIM(r.produit_id), N''))
           = s.produit_id

    WHERE
        ISNULL(
            staging.fn_nettoyer_texte(r.nom_produit),
            N''
        ) <> ISNULL(s.nom_produit, N'')

        OR ISNULL(
            staging.fn_nettoyer_texte(r.famille_produit),
            N''
        ) <> ISNULL(s.famille_produit, N'')

        OR ISNULL(
            staging.fn_nettoyer_texte(r.univers),
            N''
        ) <> ISNULL(s.univers, N'')
);

SELECT
    @produits_textes_modifies AS produits_textes_modifies,

    CASE
        WHEN @produits_textes_modifies = 0
        THEN N'CONCLUSION : aucune valeur textuelle n’a été modifiée.'

        ELSE CONCAT(
            N'CONCLUSION : ',
            @produits_textes_modifies,
            N' produit(s) ont au moins une valeur textuelle ',
            N'corrigée ou standardisée.'
        )
    END AS conclusion;
GO


/* ============================================================
   14. AFFICHER L’AVANT ET L’APRÈS
   ============================================================ */

/* ------------------------------------------------------------
   INNER JOIN associe chaque produit brut à sa version nettoyée.

   Seuls les produits ayant une différence textuelle
   sont affichés.
   ------------------------------------------------------------ */
SELECT
    r.produit_id,

    r.nom_produit AS nom_avant,
    s.nom_produit AS nom_apres,

    r.famille_produit AS famille_avant,
    s.famille_produit AS famille_apres,

    r.univers AS univers_avant,
    s.univers AS univers_apres,

    r.niveau_complexite AS complexite_avant_texte,
    s.niveau_complexite AS complexite_apres_entier

FROM raw.produits AS r

INNER JOIN staging.produits AS s
    ON UPPER(NULLIF(TRIM(r.produit_id), N''))
       = s.produit_id

WHERE
    ISNULL(
        staging.fn_nettoyer_texte(r.nom_produit),
        N''
    ) <> ISNULL(s.nom_produit, N'')

    OR ISNULL(
        staging.fn_nettoyer_texte(r.famille_produit),
        N''
    ) <> ISNULL(s.famille_produit, N'')

    OR ISNULL(
        staging.fn_nettoyer_texte(r.univers),
        N''
    ) <> ISNULL(s.univers, N'')

ORDER BY s.produit_id;
GO


/* ============================================================
   15. AFFICHER LE CATALOGUE FINAL
   ============================================================ */

/* La table ne contient que 10 produits.

   Elle peut donc être affichée entièrement pour effectuer
   une dernière vérification visuelle. */
SELECT
    produit_id,
    nom_produit,
    famille_produit,
    univers,
    niveau_complexite

FROM staging.produits

ORDER BY produit_id;
GO


/* ============================================================
   16. RÉSUMÉ FINAL
   ============================================================ */

DECLARE @total_produits INT =
(
    SELECT COUNT(*)
    FROM staging.produits
);

DECLARE @total_familles INT =
(
    SELECT COUNT(DISTINCT famille_produit)
    FROM staging.produits
);

DECLARE @total_univers INT =
(
    SELECT COUNT(DISTINCT univers)
    FROM staging.produits
);

SELECT
    @total_produits AS total_produits,
    @total_familles AS total_familles,
    @total_univers AS total_univers,

    CONCAT(
        N'CONCLUSION FINALE : staging.produits contient ',
        @total_produits,
        N' produits propres, répartis dans ',
        @total_familles,
        N' familles et ',
        @total_univers,
        N' univers.'
    ) AS conclusion;
GO


/* ============================================================
   CONCLUSION DU NETTOYAGE DE staging.produits

   Résultats correspondant à produits.csv :

   1. Nombre de lignes
      - raw.produits contient 10 lignes.
      - staging.produits contient 10 lignes.
      - Aucun produit n’a été perdu.

   2. Grain de la table
      - Une ligne représente un produit bancaire.
      - La clé métier est produit_id.

   3. Conversions
      - 0 conversion impossible.
      - niveau_complexite est maintenant de type INT.

   4. Doublons
      - 0 produit_id dupliqué.
      - Les 10 produits possèdent un identifiant unique.

   5. Valeurs manquantes
      - Aucun identifiant ne manque.
      - Aucun nom de produit ne manque.
      - Aucune famille ne manque.
      - Aucun univers ne manque.
      - Aucun niveau de complexité ne manque.

   6. Identifiants
      - Tous les identifiants respectent le format P000.
      - Les identifiants vont de P001 à P010.

   7. Familles de produits
      - 5 familles sont présentes :

        Compte : 1 produit
        Carte : 2 produits
        Épargne : 3 produits
        Crédit : 3 produits
        Assurance : 1 produit

   8. Univers
      - 5 univers sont présents :

        Épargne et flux : 2 produits
        Moyens de paiement : 2 produits
        Placement : 2 produits
        Financement : 3 produits
        Protection : 1 produit

   9. Niveaux de complexité
      - Les niveaux sont compris entre 1 et 4.

        Niveau 1 : 3 produits
        Niveau 2 : 2 produits
        Niveau 3 : 4 produits
        Niveau 4 : 1 produit

   10. Correction des textes
       - Les caractères accentués mal interprétés ont été corrigés.
       - Cela concerne notamment :

         Épargne
         Crédit
         Prêt
         réglementé

       - Aucun caractère d’encodage incorrect connu ne reste.

   RÉSULTAT FINAL :

   staging.produits contient 10 produits uniques,
   complets, correctement typés et standardisés.

   Cette table pourra ensuite devenir la future dimension
   Produit du modèle analytique.
   ============================================================ */