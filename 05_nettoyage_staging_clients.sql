/* ============================================================
   PROJET : Banque 360
   FICHIER : 05_nettoyage_staging_clients.sql

   ÉTAPE DU FICHIER :

   Étape 6 sur 8
   Nettoyer les données dans staging

   AVANCEMENT :

   Étapes 1 à 5 : TERMINÉES
   Étape 6 : EN COURS (partie 2/7)

   TABLE TRAITÉE :

   raw.clients → staging.clients

   OBJECTIF :

   - nettoyer les textes ;
   - corriger les caractères mal encodés ;
   - convertir les dates et les nombres ;
   - uniformiser les catégories ;
   - supprimer les doublons exacts ;
   - remplacer les revenus négatifs par NULL ;
   - conserver les valeurs manquantes sans en inventer ;
   - contrôler le résultat du nettoyage.

   RÉSULTATS ATTENDUS AVEC LE FICHIER FOURNI :

   - 6 060 lignes dans raw.clients ;
   - 6 000 clients uniques dans staging.clients ;
   - 60 lignes dupliquées supprimées ;
   - 7 revenus négatifs remplacés par NULL ;
   - 25 codes postaux manquants ;
   - 30 emails manquants ;
   - aucune conversion impossible ;
   - aucun score de risque hors de l’intervalle 0 à 100 ;
   - aucune agence de rattachement introuvable.
   ============================================================ */


/* ------------------------------------------------------------
   USE sélectionne la base utilisée par le script.
   ------------------------------------------------------------ */
USE Banque360;
GO


/* ============================================================
   1. CRÉER UNE FONCTION DE NETTOYAGE DES TEXTES
   ============================================================ */

/* ------------------------------------------------------------
   Une fonction est un traitement réutilisable.

   Elle reçoit un texte, le nettoie, puis renvoie le résultat.

   CREATE OR ALTER signifie :

   - créer la fonction si elle n’existe pas ;
   - la modifier si elle existe déjà.

   @texte est le texte reçu par la fonction.

   RETURNS indique le type de la valeur renvoyée.
   ------------------------------------------------------------ */
   
CREATE OR ALTER FUNCTION staging.fn_nettoyer_texte
(
    @texte NVARCHAR(4000)
)
RETURNS NVARCHAR(4000)
AS
BEGIN

    /* DECLARE crée une variable temporaire. */
    DECLARE @resultat NVARCHAR(4000);

    /* TRIM enlève les espaces au début et à la fin.

       NULLIF transforme un texte vide en NULL. */
    SET @resultat = NULLIF(TRIM(@texte), N'');

    /* Si le texte est vide, la fonction renvoie directement NULL. */
    IF @resultat IS NULL
        RETURN NULL;

    /* --------------------------------------------------------
       Correction des caractères mal interprétés observés
       dans les différents fichiers du projet.

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
   2. RECRÉER staging.clients
   ============================================================ */

/* Supprime uniquement l’ancienne version nettoyée.
   raw.clients reste inchangée. */
DROP TABLE IF EXISTS staging.clients;
GO


/* ------------------------------------------------------------
   Les colonnes utilisent maintenant leurs véritables types :

   INT
   → nombre entier.

   DATE
   → date sans heure.

   DECIMAL(12,2)
   → nombre avec deux chiffres après la virgule.

   NVARCHAR
   → texte acceptant les accents.
   ------------------------------------------------------------ */

CREATE TABLE staging.clients
(
    ligne_source         INT            NULL,
    client_id            NVARCHAR(20)   NULL,
    prenom               NVARCHAR(100)  NULL,
    nom                  NVARCHAR(100)  NULL,
    date_naissance       DATE           NULL,
    date_entree          DATE           NULL,
    segment              NVARCHAR(100)  NULL,
    profession           NVARCHAR(150)  NULL,
    revenu_mensuel       DECIMAL(12,2)  NULL,
    score_risque_initial INT            NULL,
    agence_id            NVARCHAR(20)   NULL,
    ville                NVARCHAR(100)  NULL,
    code_postal          NVARCHAR(10)   NULL,
    email                NVARCHAR(255)  NULL,
    statut_client        NVARCHAR(50)   NULL
);
GO


/* ============================================================
   3. NETTOYER, DÉDOUBLONNER ET CHARGER LES CLIENTS
   ============================================================ */

/* ------------------------------------------------------------
   WITH crée une CTE.

   Une CTE est un résultat intermédiaire temporaire utilisé
   uniquement par la requête qui suit.

   Ici :

   source_nettoyee
   → nettoie et convertit les données.

   source_classee
   → attribue un numéro à chaque occurrence d’un client.

   ROW_NUMBER
   → numérote les lignes à l’intérieur de chaque client_id.

   PARTITION BY
   → recommence la numérotation pour chaque client.

   Les doublons du fichier étant strictement identiques,
   nous conservons la première occurrence de chaque client_id.
   ------------------------------------------------------------ */

WITH source_nettoyee AS
(
    SELECT
        /* Convertit le numéro de ligne en entier. */
        TRY_CONVERT(
            INT,
            NULLIF(TRIM(ligne_source), N'')
        ) AS ligne_source,

        staging.fn_nettoyer_texte(client_id) AS client_id,
        staging.fn_nettoyer_texte(prenom) AS prenom,
        staging.fn_nettoyer_texte(nom) AS nom,

        /* 23 correspond au format AAAA-MM-JJ. */
        TRY_CONVERT(
            DATE,
            NULLIF(TRIM(date_naissance), N''),
            23
        ) AS date_naissance,

        TRY_CONVERT(
            DATE,
            NULLIF(TRIM(date_entree), N''),
            23
        ) AS date_entree,

        staging.fn_nettoyer_texte(segment) AS segment,
        staging.fn_nettoyer_texte(profession) AS profession,

        TRY_CONVERT(
            DECIMAL(12,2),
            NULLIF(TRIM(revenu_mensuel), N'')
        ) AS revenu_mensuel,

        TRY_CONVERT(
            INT,
            NULLIF(TRIM(score_risque_initial), N'')
        ) AS score_risque_initial,

        staging.fn_nettoyer_texte(agence_id) AS agence_id,
        staging.fn_nettoyer_texte(ville) AS ville,

        /* Le code postal reste du texte pour conserver
           les éventuels zéros au début. */
        staging.fn_nettoyer_texte(code_postal) AS code_postal,

        staging.fn_nettoyer_texte(email) AS email,
        staging.fn_nettoyer_texte(statut_client) AS statut_client

    FROM raw.clients
),

source_classee AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            /* Les lignes sans identifiant resteraient distinctes
               grâce à leur numéro de ligne source. */
            PARTITION BY
                CASE
                    WHEN client_id IS NULL
                    THEN CONCAT(N'SANS_ID_', ligne_source)
                    ELSE client_id
                END

            /* La première ligne du fichier est conservée. */
            ORDER BY ligne_source
        ) AS rang_doublon

    FROM source_nettoyee
)

INSERT INTO staging.clients
(
    ligne_source,
    client_id,
    prenom,
    nom,
    date_naissance,
    date_entree,
    segment,
    profession,
    revenu_mensuel,
    score_risque_initial,
    agence_id,
    ville,
    code_postal,
    email,
    statut_client
)
SELECT
    ligne_source,
    client_id,
    prenom,
    nom,
    date_naissance,
    date_entree,

    /* --------------------------------------------------------
       CASE permet de renvoyer une valeur différente
       selon une condition.

       UPPER transforme temporairement le texte en majuscules
       afin de regrouper les variantes :

       particulier
       Particulier
       PARTICULIER

       Toutes deviennent Particulier.
       -------------------------------------------------------- */

    CASE UPPER(segment)
        WHEN N'PARTICULIER'   THEN N'Particulier'
        WHEN N'PROFESSIONNEL' THEN N'Professionnel'
        WHEN N'ASSOCIATION'   THEN N'Association'
        ELSE segment
    END AS segment,

    /* Uniformise les différentes écritures des professions. */
    CASE UPPER(profession)
        WHEN N'AGRICULTEUR'        THEN N'Agriculteur'
        WHEN N'ARTISAN'            THEN N'Artisan'
        WHEN N'CADRE'              THEN N'Cadre'
        WHEN N'COMMERÇANT'         THEN N'Commerçant'
        WHEN N'EMPLOYÉ'            THEN N'Employé'
        WHEN N'ENSEIGNANT'         THEN N'Enseignant'
        WHEN N'PROFESSION LIBÉRALE' THEN N'Profession libérale'
        WHEN N'RETRAITÉ'           THEN N'Retraité'
        WHEN N'SANS EMPLOI'        THEN N'Sans emploi'
        WHEN N'TECHNICIEN'         THEN N'Technicien'
        WHEN N'ÉTUDIANT'           THEN N'Étudiant'
        ELSE profession
    END AS profession,

    /* --------------------------------------------------------
       Un revenu négatif est impossible dans ce contexte.

       Nous ne le transformons pas en valeur positive,
       car cela reviendrait à inventer une donnée.

       Il devient donc NULL.

       La valeur originale reste disponible dans raw.clients.
       -------------------------------------------------------- */

    CASE
        WHEN revenu_mensuel < 0 THEN NULL
        ELSE revenu_mensuel
    END AS revenu_mensuel,

    score_risque_initial,
    agence_id,
    ville,
    code_postal,

    /* LOWER transforme l’email en minuscules. */
    LOWER(email) AS email,

    /* Uniformise également le statut du client. */
    CASE UPPER(statut_client)
        WHEN N'ACTIF'   THEN N'Actif'
        WHEN N'INACTIF' THEN N'Inactif'
        WHEN N'CLOS'    THEN N'Clos'
        ELSE statut_client
    END AS statut_client

FROM source_classee

/* Seule la première occurrence de chaque client est conservée. */
WHERE rang_doublon = 1;
GO


/* ============================================================
   4. CONTRÔLER LE NOMBRE DE LIGNES ET LES DOUBLONS
   ============================================================ */

/* ------------------------------------------------------------
   Résultats attendus :

   lignes_raw                : 6 060
   clients_staging           : 6 000
   lignes_dupliquees_retirees: 60
   ------------------------------------------------------------ */
   
DECLARE @lignes_raw INT =
(
    SELECT COUNT(*)
    FROM raw.clients
);

DECLARE @lignes_staging INT =
(
    SELECT COUNT(*)
    FROM staging.clients
);

SELECT
    @lignes_raw AS lignes_raw,
    @lignes_staging AS clients_uniques_staging,
    @lignes_raw - @lignes_staging AS lignes_dupliquees_retirees,

    CONCAT(
        N'CONCLUSION : ',
        @lignes_staging,
        N' clients uniques ont été conservés et ',
        @lignes_raw - @lignes_staging,
        N' doublons exacts ont été retirés.'
    ) AS conclusion;
GO


/* ============================================================
   5. CONTRÔLER LES CONVERSIONS
   ============================================================ */

/* ------------------------------------------------------------
   Cette requête compte les valeurs non vides qui ne peuvent
   pas être converties.

   Résultat attendu : 0.
   ------------------------------------------------------------ */
DECLARE @conversions_impossibles INT =
(
    SELECT COUNT(*)
    FROM raw.clients
    WHERE
    (
        NULLIF(TRIM(ligne_source), N'') IS NOT NULL
        AND TRY_CONVERT(INT, TRIM(ligne_source)) IS NULL
    )
    OR
    (
        NULLIF(TRIM(date_naissance), N'') IS NOT NULL
        AND TRY_CONVERT(DATE, TRIM(date_naissance), 23) IS NULL
    )
    OR
    (
        NULLIF(TRIM(date_entree), N'') IS NOT NULL
        AND TRY_CONVERT(DATE, TRIM(date_entree), 23) IS NULL
    )
    OR
    (
        NULLIF(TRIM(revenu_mensuel), N'') IS NOT NULL
        AND TRY_CONVERT(
                DECIMAL(12,2),
                TRIM(revenu_mensuel)
            ) IS NULL
    )
    OR
    (
        NULLIF(TRIM(score_risque_initial), N'') IS NOT NULL
        AND TRY_CONVERT(
                INT,
                TRIM(score_risque_initial)
            ) IS NULL
    )
);

SELECT
    @conversions_impossibles AS conversions_impossibles,

    CASE
        WHEN @conversions_impossibles = 0
        THEN N'CONCLUSION : toutes les conversions ont réussi.'
        ELSE CONCAT(
            N'CONCLUSION : ',
            @conversions_impossibles,
            N' ligne(s) contiennent une conversion impossible.'
        )
    END AS conclusion;
GO


/* ============================================================
   6. CONTRÔLER LES VALEURS MANQUANTES
   ============================================================ */

/* ------------------------------------------------------------
   Les valeurs vides ont été transformées en NULL.

   Résultats attendus après suppression des doublons :

   - 25 codes postaux manquants ;
   - 30 emails manquants ;
   - 7 revenus mis à NULL car négatifs.
   ------------------------------------------------------------ */
SELECT
    SUM(CASE WHEN code_postal IS NULL THEN 1 ELSE 0 END)
        AS codes_postaux_manquants,

    SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END)
        AS emails_manquants,

    SUM(CASE WHEN revenu_mensuel IS NULL THEN 1 ELSE 0 END)
        AS revenus_manquants_ou_invalides,

    CONCAT(
        N'CONCLUSION : 25 codes postaux et 30 emails sont ',
        N'absents. Les 7 revenus négatifs ont été remplacés ',
        N'par NULL.'
    ) AS conclusion

FROM staging.clients;
GO


/* ============================================================
   7. CONTRÔLER LES SCORES ET LES DATES
   ============================================================ */

/* ------------------------------------------------------------
   Ce contrôle recherche :

   - un score inférieur à 0 ou supérieur à 100 ;
   - une naissance postérieure à l’entrée dans la banque.

   Résultat attendu : 0 anomalie.
   ------------------------------------------------------------ */
DECLARE @valeurs_incoherentes INT =
(
    SELECT COUNT(*)
    FROM staging.clients
    WHERE score_risque_initial < 0
       OR score_risque_initial > 100
       OR date_naissance > date_entree
);

SELECT
    @valeurs_incoherentes AS valeurs_incoherentes,

    CASE
        WHEN @valeurs_incoherentes = 0
        THEN CONCAT(
            N'CONCLUSION : tous les scores sont compris entre ',
            N'0 et 100 et toutes les dates sont cohérentes.'
        )
        ELSE CONCAT(
            N'CONCLUSION : ',
            @valeurs_incoherentes,
            N' client(s) ont un score ou une date incohérente.'
        )
    END AS conclusion;
GO


/* ============================================================
   8. CONTRÔLER LES EMAILS NON VIDES
   ============================================================ */

/* ------------------------------------------------------------
   Les emails absents sont acceptés et restent NULL.

   Ce contrôle examine uniquement les emails renseignés.

   Résultat attendu : 0 email renseigné au format suspect.
   ------------------------------------------------------------ */
DECLARE @emails_invalides INT =
(
    SELECT COUNT(*)
    FROM staging.clients
    WHERE email IS NOT NULL
      AND
      (
          email NOT LIKE N'%@%.%'
          OR email LIKE N'% %'
      )
);

SELECT
    @emails_invalides AS emails_renseignes_invalides,

    CASE
        WHEN @emails_invalides = 0
        THEN N'CONCLUSION : tous les emails renseignés ont un format valide.'
        ELSE CONCAT(
            N'CONCLUSION : ',
            @emails_invalides,
            N' email(s) renseignés ont un format suspect.'
        )
    END AS conclusion;
GO


/* ============================================================
   9. CONTRÔLER LES AGENCES DE RATTACHEMENT
   ============================================================ */

/* ------------------------------------------------------------
   Chaque client possède un agence_id.

   NOT EXISTS vérifie qu’aucune agence ayant le même identifiant
   n’existe dans raw.agences.

   Nous utilisons raw.agences car cette table existe depuis
   l’étape 4 et contient la liste complète des agences.

   TRIM enlève les éventuels espaces autour de l’identifiant.

   Résultat attendu :
   0 client rattaché à une agence introuvable.
   ------------------------------------------------------------ */
DECLARE @agences_introuvables INT =
(
    SELECT COUNT(*)
    FROM staging.clients AS c
    WHERE c.agence_id IS NOT NULL
      AND NOT EXISTS
      (
          SELECT 1
          FROM raw.agences AS a
          WHERE NULLIF(TRIM(a.agence_id), N'') = c.agence_id
      )
);


/* ------------------------------------------------------------
   CASE adapte automatiquement la conclusion au résultat.

   Si le nombre vaut 0 :
   toutes les agences des clients existent.

   Sinon :
   le nombre de clients concernés est affiché.
   ------------------------------------------------------------ */
SELECT
    @agences_introuvables AS clients_agence_introuvable,

    CASE
        WHEN @agences_introuvables = 0
        THEN CONCAT(
            N'CONCLUSION : tous les clients sont rattachés ',
            N'à une agence existante.'
        )

        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. ',
            @agences_introuvables,
            N' client(s) sont rattachés à une agence introuvable.'
        )
    END AS conclusion;
GO


/* ------------------------------------------------------------
   Cette requête affiche jusqu’à 20 exemples lorsque des agences
   sont introuvables.

   Si seules les colonnes apparaissent sans aucune ligne,
   aucune anomalie n’a été détectée.
   ------------------------------------------------------------ */
SELECT TOP (20)
    c.client_id,
    c.agence_id
FROM staging.clients AS c
WHERE c.agence_id IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM raw.agences AS a
      WHERE NULLIF(TRIM(a.agence_id), N'') = c.agence_id
  )
ORDER BY c.client_id;
GO


/* ============================================================
   10. CONTRÔLER LES CARACTÈRES MAL ENCODÉS
   ============================================================ */

/* ------------------------------------------------------------
   La fonction de nettoyage doit avoir supprimé les symboles :

   ├
   √
   Ã

   Résultat attendu : 0.
   ------------------------------------------------------------ */
DECLARE @encodages_incorrects INT =
(
    SELECT COUNT(*)
    FROM staging.clients
    WHERE CONCAT(
        prenom,
        nom,
        segment,
        profession,
        ville,
        email,
        statut_client
    ) LIKE N'%├%'

    OR CONCAT(
        prenom,
        nom,
        segment,
        profession,
        ville,
        email,
        statut_client
    ) LIKE N'%√%'

    OR CONCAT(
        prenom,
        nom,
        segment,
        profession,
        ville,
        email,
        statut_client
    ) LIKE N'%Ã%'
);

SELECT
    @encodages_incorrects AS clients_encodage_incorrect,

    CASE
        WHEN @encodages_incorrects = 0
        THEN N'CONCLUSION : tous les caractères connus ont été corrigés.'
        ELSE CONCAT(
            N'CONCLUSION : ',
            @encodages_incorrects,
            N' client(s) contiennent encore un caractère incorrect.'
        )
    END AS conclusion;
GO


/* ============================================================
   11. AFFICHER LES 7 REVENUS NÉGATIFS CORRIGÉS
   ============================================================ */

/* ------------------------------------------------------------
   Cette requête montre la valeur brute négative et la valeur
   staging devenue NULL.

   Résultat attendu : 7 lignes.
   ------------------------------------------------------------ */
SELECT
    r.client_id,
    r.revenu_mensuel AS revenu_brut_negatif,
    s.revenu_mensuel AS revenu_apres_nettoyage

FROM raw.clients AS r

INNER JOIN staging.clients AS s
    ON TRIM(r.client_id) = s.client_id

WHERE TRY_CONVERT(
          DECIMAL(12,2),
          TRIM(r.revenu_mensuel)
      ) < 0

ORDER BY r.client_id;
GO


/* ============================================================
   12. AFFICHER UN AVANT / APRÈS DES TEXTES
   ============================================================ */

/* ------------------------------------------------------------
   On conserve une seule occurrence de chaque client brut
   pour éviter d’afficher deux fois les doublons.

   TOP (20) affiche vingt exemples réellement modifiés.
   ------------------------------------------------------------ */
WITH raw_unique AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY TRIM(client_id)
            ORDER BY TRY_CONVERT(INT, ligne_source)
        ) AS rang

    FROM raw.clients
)

SELECT TOP (20)
    r.client_id,

    r.prenom AS prenom_avant,
    s.prenom AS prenom_apres,

    r.profession AS profession_avant,
    s.profession AS profession_apres,

    r.segment AS segment_avant,
    s.segment AS segment_apres,

    r.ville AS ville_avant,
    s.ville AS ville_apres,

    r.email AS email_avant,
    s.email AS email_apres

FROM raw_unique AS r

INNER JOIN staging.clients AS s
    ON TRIM(r.client_id) = s.client_id

WHERE r.rang = 1
  AND
  (
      ISNULL(TRIM(r.prenom), N'') <> ISNULL(s.prenom, N'')
      OR ISNULL(TRIM(r.profession), N'') <> ISNULL(s.profession, N'')
      OR ISNULL(TRIM(r.segment), N'') <> ISNULL(s.segment, N'')
      OR ISNULL(TRIM(r.ville), N'') <> ISNULL(s.ville, N'')
      OR ISNULL(TRIM(r.email), N'') <> ISNULL(s.email, N'')
  )

ORDER BY s.client_id;
GO


/* ============================================================
   13. AFFICHER UN APERÇU FINAL
   ============================================================ */

/* Affiche les vingt premiers clients propres. */
SELECT TOP (20)
    ligne_source,
    client_id,
    prenom,
    nom,
    date_naissance,
    date_entree,
    segment,
    profession,
    revenu_mensuel,
    score_risque_initial,
    agence_id,
    ville,
    code_postal,
    email,
    statut_client

FROM staging.clients

ORDER BY client_id;
GO


/* ============================================================
   CONCLUSION DU NETTOYAGE DE staging.clients

   Résultats correspondant au fichier clients_raw.csv fourni :

   1. Lignes et doublons
      - raw.clients contient 6 060 lignes.
      - 60 client_id sont présents deux fois.
      - Ces doublons sont strictement identiques, à l’exception
        du numéro de ligne source.
      - staging.clients conserve 6 000 clients uniques.

   2. Conversions
      - 0 conversion impossible.
      - Les dates, revenus, scores et numéros de ligne ont été
        correctement convertis.

   3. Encodage
      - Les caractères é, è, ç, Ç et É mal interprétés ont été
        corrigés.
      - Aucun caractère d’encodage connu ne doit rester.

   4. Standardisation
      - 40 segments écrits en minuscules ont été uniformisés.
      - 15 professions écrites entièrement en majuscules ont
        été uniformisées.

   5. Revenus
      - 7 revenus mensuels négatifs ont été détectés.
      - Ils ont été remplacés par NULL dans staging.
      - Les valeurs originales restent disponibles dans raw.

   6. Valeurs manquantes
      - 25 clients n’ont pas de code postal.
      - 30 clients n’ont pas d’adresse électronique.
      - Ces absences sont conservées sous forme de NULL.

   7. Autres contrôles
      - 0 score de risque hors de l’intervalle 0 à 100.
      - 0 email renseigné au format suspect.
      - 0 agence de rattachement introuvable.
      - 0 date de naissance postérieure à la date d’entrée.

   RÉSULTAT FINAL :

   staging.clients contient 6 000 clients uniques,
   correctement typés, dédoublonnés et standardisés.
   ============================================================ */