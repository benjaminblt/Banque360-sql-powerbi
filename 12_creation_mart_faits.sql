/* ============================================================
   PROJET : Banque 360
   FICHIER : 12_creation_mart_faits.sql

   ÉTAPE DU PROJET :

   Étape 7 sur 8, partie 2 sur 3
   Construire les tables de faits du modèle analytique.

   ORDRE D’EXÉCUTION :

   11_creation_mart_dimensions.sql
   → crée les dimensions ;

   12_creation_mart_faits.sql
   → crée les tables de faits ;

   13_controles_modele_mart.sql
   → contrôle le modèle complet.

   TABLES CRÉÉES :

   - mart.fact_transactions
   - mart.fact_credits
   - mart.fact_remboursements
   - mart.fact_objectifs_agences
   - mart.fact_entrees_clients

   Le script reste entièrement réexécutable :

   - les anciennes tables de faits sont supprimées ;
   - leurs contraintes et index disparaissent avec elles ;
   - les tables sont recréées proprement ;
   - les données sont rechargées depuis staging.

   Les dimensions ne sont jamais supprimées par ce fichier.
   ============================================================ */


/* ============================================================
   EN CAS DE PROBLÈME
   ============================================================ */

/* 1. Exécuter tout le fichier depuis la première ligne.
   2. Lire la première véritable erreur « Msg ».
   3. Ne pas exécuter le fichier 13 tant que le fichier 12
      n’est pas terminé sans erreur.
   4. Si le script fonctionne mais que VS Code reste rouge :
      ⌘ + ⇧ + P
      → MSSQL: Refresh IntelliSense Cache.
*/


/* ============================================================
   0. SÉLECTIONNER LA BASE
   ============================================================ */

/* USE sélectionne la base dans laquelle toutes les instructions
   suivantes seront exécutées. */
USE Banque360;
GO


/* SET NOCOUNT ON évite les messages répétitifs
   « X lignes affectées » après chaque instruction.

   Les tableaux de résultats restent visibles. */
SET NOCOUNT ON;
GO


/* ============================================================
   1. VÉRIFIER LES DIMENSIONS NÉCESSAIRES
   ============================================================ */

/* OBJECT_ID recherche un objet dans la base.

   N'U' signifie que l’objet attendu doit être une table
   utilisateur.

   THROW arrête immédiatement le script si une dimension manque.
   Cela évite ensuite une succession d’erreurs moins lisibles. */

IF OBJECT_ID(N'mart.dim_date', N'U') IS NULL
BEGIN
    ;THROW 52001,
           N'La table mart.dim_date est absente. Exécuter d’abord le fichier 11.',
           1;
END;

IF OBJECT_ID(N'mart.dim_agence', N'U') IS NULL
BEGIN
    ;THROW 52002,
           N'La table mart.dim_agence est absente. Exécuter d’abord le fichier 11.',
           1;
END;

IF OBJECT_ID(N'mart.dim_client', N'U') IS NULL
BEGIN
    ;THROW 52003,
           N'La table mart.dim_client est absente. Exécuter d’abord le fichier 11.',
           1;
END;

IF OBJECT_ID(N'mart.dim_produit', N'U') IS NULL
BEGIN
    ;THROW 52004,
           N'La table mart.dim_produit est absente. Exécuter d’abord le fichier 11.',
           1;
END;
GO


/* ============================================================
   1.1. VÉRIFIER LES TABLES STAGING NÉCESSAIRES
   ============================================================ */

/* Les tables staging constituent les sources propres du modèle.

   Le fichier 12 ne doit pas démarrer si l’une d’elles manque,
   car les faits seraient alors impossibles à alimenter. */

IF OBJECT_ID(N'staging.transactions', N'U') IS NULL
BEGIN
    ;THROW 52009,
           N'La table staging.transactions est absente. Terminer l’étape 6 avant de continuer.',
           1;
END;

IF OBJECT_ID(N'staging.credits', N'U') IS NULL
BEGIN
    ;THROW 52010,
           N'La table staging.credits est absente. Terminer l’étape 6 avant de continuer.',
           1;
END;

IF OBJECT_ID(N'staging.remboursements', N'U') IS NULL
BEGIN
    ;THROW 52011,
           N'La table staging.remboursements est absente. Terminer l’étape 6 avant de continuer.',
           1;
END;

IF OBJECT_ID(N'staging.objectifs_agences', N'U') IS NULL
BEGIN
    ;THROW 52012,
           N'La table staging.objectifs_agences est absente. Terminer l’étape 6 avant de continuer.',
           1;
END;

IF OBJECT_ID(N'staging.clients', N'U') IS NULL
BEGIN
    ;THROW 52013,
           N'La table staging.clients est absente. Terminer l’étape 6 avant de continuer.',
           1;
END;
GO


/* ============================================================
   1.2. VÉRIFIER LE GRAIN DES SOURCES AVANT RECRÉATION
   ============================================================ */

/* Ces contrôles sont exécutés AVANT la suppression des anciennes
   tables de faits.

   Ils vérifient que les clés métier censées être uniques ne sont
   ni absentes ni dupliquées dans staging.

   GROUP BY rassemble les lignes portant la même clé.

   HAVING COUNT_BIG(*) > 1 conserve uniquement les doublons. */

IF EXISTS
(
    SELECT transaction_id
    FROM staging.transactions
    GROUP BY transaction_id
    HAVING transaction_id IS NULL
        OR COUNT_BIG(*) > 1
)
BEGIN
    ;THROW 52014,
           N'staging.transactions contient un transaction_id NULL ou dupliqué.',
           1;
END;

IF EXISTS
(
    SELECT credit_id
    FROM staging.credits
    GROUP BY credit_id
    HAVING credit_id IS NULL
        OR COUNT_BIG(*) > 1
)
BEGIN
    ;THROW 52015,
           N'staging.credits contient un credit_id NULL ou dupliqué.',
           1;
END;

IF EXISTS
(
    SELECT remboursement_id
    FROM staging.remboursements
    GROUP BY remboursement_id
    HAVING remboursement_id IS NULL
        OR COUNT_BIG(*) > 1
)
BEGIN
    ;THROW 52016,
           N'staging.remboursements contient un remboursement_id NULL ou dupliqué.',
           1;
END;

IF EXISTS
(
    SELECT
        mois,
        agence_id
    FROM staging.objectifs_agences
    GROUP BY
        mois,
        agence_id
    HAVING mois IS NULL
        OR agence_id IS NULL
        OR COUNT_BIG(*) > 1
)
BEGIN
    ;THROW 52017,
           N'staging.objectifs_agences contient un couple mois-agence NULL ou dupliqué.',
           1;
END;

IF EXISTS
(
    SELECT client_id
    FROM staging.clients
    GROUP BY client_id
    HAVING client_id IS NULL
        OR COUNT_BIG(*) > 1
)
BEGIN
    ;THROW 52018,
           N'staging.clients contient un client_id NULL ou dupliqué.',
           1;
END;
GO


/* ============================================================
   2. VÉRIFIER LES MEMBRES INCONNUS
   ============================================================ */

/* Chaque dimension possède une ligne spéciale dont la clé vaut 0.

   Cette ligne représente une valeur absente ou invalide :

   - date impossible ;
   - agence inexistante ;
   - client introuvable ;
   - produit non renseigné.

   Les tables de faits pourront ainsi conserver les événements
   concernés sans casser les relations. */

IF NOT EXISTS
(
    SELECT 1
    FROM mart.dim_date
    WHERE date_key = 0
)
BEGIN
    ;THROW 52005,
           N'Le membre inconnu date_key = 0 est absent de mart.dim_date.',
           1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM mart.dim_agence
    WHERE agence_key = 0
)
BEGIN
    ;THROW 52006,
           N'Le membre inconnu agence_key = 0 est absent de mart.dim_agence.',
           1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM mart.dim_client
    WHERE client_key = 0
)
BEGIN
    ;THROW 52007,
           N'Le membre inconnu client_key = 0 est absent de mart.dim_client.',
           1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM mart.dim_produit
    WHERE produit_key = 0
)
BEGIN
    ;THROW 52008,
           N'Le membre inconnu produit_key = 0 est absent de mart.dim_produit.',
           1;
END;
GO


/* ============================================================
   3. SUPPRIMER LES ANCIENNES TABLES DE FAITS
   ============================================================ */

/* DROP TABLE IF EXISTS :

   - vérifie si la table existe ;
   - la supprime uniquement si elle existe ;
   - ne renvoie pas d’erreur si elle est absente.

   La suppression d’une table supprime automatiquement :

   - ses données ;
   - sa clé primaire ;
   - ses clés étrangères ;
   - ses contraintes UNIQUE ;
   - ses index.

   Les tables sont supprimées dans l’ordre inverse de leur
   création afin de conserver une logique claire. */

DROP TABLE IF EXISTS mart.fact_entrees_clients;
DROP TABLE IF EXISTS mart.fact_objectifs_agences;
DROP TABLE IF EXISTS mart.fact_remboursements;
DROP TABLE IF EXISTS mart.fact_credits;
DROP TABLE IF EXISTS mart.fact_transactions;
GO


/* ============================================================
   4. CRÉER mart.fact_transactions
   ============================================================ */

/* GRAIN :

   Une ligne représente une transaction bancaire unique.

   CLÉ TECHNIQUE :

   transaction_key est générée automatiquement par IDENTITY.

   CLÉ MÉTIER :

   transaction_id provient du fichier source et reste unique. */

CREATE TABLE mart.fact_transactions
(
    /* BIGINT permet de gérer un très grand nombre de lignes.

       IDENTITY(1,1) signifie :
       - première clé générée : 1 ;
       - incrément suivant : +1. */
    transaction_key BIGINT IDENTITY(1,1) NOT NULL,

    /* Identifiant métier unique de la transaction. */
    transaction_id NVARCHAR(20) NOT NULL,

    /* Clés étrangères vers les dimensions. */
    date_key INT NOT NULL,
    client_key INT NOT NULL,
    produit_key INT NOT NULL,
    agence_key INT NOT NULL,

    /* Nature de l’opération :
       Paiement carte, Prélèvement, Virement, etc. */
    type_transaction NVARCHAR(100) NULL,

    /* Montant original signé :
       débit négatif, crédit positif. */
    montant_signe DECIMAL(15,2) NULL,

    /* Mesure positive réservée aux débits. */
    montant_debit DECIMAL(15,2) NOT NULL,

    /* Mesure positive réservée aux crédits. */
    montant_credit DECIMAL(15,2) NOT NULL,

    /* Informations descriptives de l’événement. */
    sens NVARCHAR(20) NULL,
    canal NVARCHAR(100) NULL,
    statut NVARCHAR(50) NULL,
    frais DECIMAL(15,2) NULL,
    devise NVARCHAR(3) NULL,

    /* Chaque ligne vaut 1 afin de faciliter les comptages
       dans Power BI avec une simple somme. */
    nombre_transactions TINYINT NOT NULL,

    /* Clé primaire technique. */
    CONSTRAINT PK_fact_transactions
        PRIMARY KEY (transaction_key),

    /* La clé métier ne peut apparaître qu’une seule fois. */
    CONSTRAINT UQ_fact_transactions_transaction_id
        UNIQUE (transaction_id),

    /* Relations vers les dimensions du modèle en étoile. */
    CONSTRAINT FK_fact_transactions_date
        FOREIGN KEY (date_key)
        REFERENCES mart.dim_date(date_key),

    CONSTRAINT FK_fact_transactions_client
        FOREIGN KEY (client_key)
        REFERENCES mart.dim_client(client_key),

    CONSTRAINT FK_fact_transactions_produit
        FOREIGN KEY (produit_key)
        REFERENCES mart.dim_produit(produit_key),

    CONSTRAINT FK_fact_transactions_agence
        FOREIGN KEY (agence_key)
        REFERENCES mart.dim_agence(agence_key)
);
GO


/* ============================================================
   4.1. CHARGER mart.fact_transactions
   ============================================================ */

/* INSERT INTO indique la table de destination.

   SELECT lit les transactions propres de staging.

   Les LEFT JOIN conservent toutes les transactions, même
   lorsqu’une dimension correspondante n’est pas retrouvée.

   COALESCE(clé_trouvée, 0) remplace alors la clé manquante
   par le membre inconnu de la dimension. */

INSERT INTO mart.fact_transactions
(
    transaction_id,
    date_key,
    client_key,
    produit_key,
    agence_key,
    type_transaction,
    montant_signe,
    montant_debit,
    montant_credit,
    sens,
    canal,
    statut,
    frais,
    devise,
    nombre_transactions
)
SELECT
    t.transaction_id,

    /* Une date impossible ou absente reçoit date_key = 0. */
    COALESCE(d.date_key, 0) AS date_key,

    /* Un client introuvable reçoit client_key = 0. */
    COALESCE(c.client_key, 0) AS client_key,

    /* Un produit absent reçoit produit_key = 0. */
    COALESCE(p.produit_key, 0) AS produit_key,

    /* Une agence inexistante reçoit agence_key = 0. */
    COALESCE(a.agence_key, 0) AS agence_key,

    t.type_transaction,

    /* Montant original signé. */
    t.montant AS montant_signe,

    /* ABS transforme un montant négatif en valeur positive.

       Exemple :
       -100 € de débit devient 100 € dans montant_debit. */
    CASE
        WHEN t.sens = N'Débit'
            THEN COALESCE(ABS(t.montant), 0)
        ELSE 0
    END AS montant_debit,

    /* ABS garantit une mesure positive pour les crédits,
       tandis que montant_signe conserve le signe d’origine. */
    CASE
        WHEN t.sens = N'Crédit'
            THEN COALESCE(ABS(t.montant), 0)
        ELSE 0
    END AS montant_credit,

    t.sens,
    t.canal,
    t.statut,
    t.frais,
    t.devise,

    /* Une ligne représente une transaction. */
    1 AS nombre_transactions

FROM staging.transactions AS t

/* CAST retire l’heure afin de relier la transaction
   à la journée correspondante dans dim_date. */
LEFT JOIN mart.dim_date AS d
    ON d.date_complete = CAST(t.date_transaction AS DATE)

LEFT JOIN mart.dim_client AS c
    ON c.client_id = t.client_id

LEFT JOIN mart.dim_produit AS p
    ON p.produit_id = t.produit_id

LEFT JOIN mart.dim_agence AS a
    ON a.agence_id = t.agence_id;
GO


/* ============================================================
   4.2. CRÉER LES INDEX DE fact_transactions
   ============================================================ */

/* Un index accélère principalement :

   - les jointures ;
   - les filtres ;
   - les recherches ;
   - le chargement des données dans Power BI.

   Les clés étrangères sont donc indexées. */

CREATE INDEX IX_fact_transactions_date
    ON mart.fact_transactions(date_key);

CREATE INDEX IX_fact_transactions_client
    ON mart.fact_transactions(client_key);

CREATE INDEX IX_fact_transactions_produit
    ON mart.fact_transactions(produit_key);

CREATE INDEX IX_fact_transactions_agence
    ON mart.fact_transactions(agence_key);
GO


/* ============================================================
   5. CRÉER mart.fact_credits
   ============================================================ */

/* GRAIN :

   Une ligne représente un contrat de crédit unique.

   Deux dates sont conservées :

   - date_octroi_key : date principale ;
   - date_fin_prevue_key : date secondaire.

   Dans Power BI, la relation sur la date d’octroi sera active
   et celle sur la date de fin prévue pourra rester inactive. */

CREATE TABLE mart.fact_credits
(
    credit_key BIGINT IDENTITY(1,1) NOT NULL,

    /* Identifiant métier du contrat. */
    credit_id NVARCHAR(20) NOT NULL,

    /* Clés vers la dimension Date. */
    date_octroi_key INT NOT NULL,
    date_fin_prevue_key INT NOT NULL,

    /* Clés vers Client et Agence. */
    client_key INT NOT NULL,
    agence_key INT NOT NULL,

    /* Informations et mesures du crédit. */
    type_credit NVARCHAR(100) NULL,
    montant_initial DECIMAL(15,2) NULL,
    taux_annuel DECIMAL(6,3) NULL,
    duree_mois INT NULL,
    mensualite_theorique DECIMAL(15,2) NULL,
    score_risque_octroi INT NULL,
    statut_credit NVARCHAR(50) NULL,

    /* Une ligne vaut un crédit. */
    nombre_credits TINYINT NOT NULL,

    CONSTRAINT PK_fact_credits
        PRIMARY KEY (credit_key),

    CONSTRAINT UQ_fact_credits_credit_id
        UNIQUE (credit_id),

    CONSTRAINT FK_fact_credits_date_octroi
        FOREIGN KEY (date_octroi_key)
        REFERENCES mart.dim_date(date_key),

    CONSTRAINT FK_fact_credits_date_fin
        FOREIGN KEY (date_fin_prevue_key)
        REFERENCES mart.dim_date(date_key),

    CONSTRAINT FK_fact_credits_client
        FOREIGN KEY (client_key)
        REFERENCES mart.dim_client(client_key),

    CONSTRAINT FK_fact_credits_agence
        FOREIGN KEY (agence_key)
        REFERENCES mart.dim_agence(agence_key)
);
GO


/* ============================================================
   5.1. CHARGER mart.fact_credits
   ============================================================ */

INSERT INTO mart.fact_credits
(
    credit_id,
    date_octroi_key,
    date_fin_prevue_key,
    client_key,
    agence_key,
    type_credit,
    montant_initial,
    taux_annuel,
    duree_mois,
    mensualite_theorique,
    score_risque_octroi,
    statut_credit,
    nombre_credits
)
SELECT
    cr.credit_id,

    /* Une date non retrouvée reçoit la clé 0. */
    COALESCE(d_octroi.date_key, 0) AS date_octroi_key,
    COALESCE(d_fin.date_key, 0) AS date_fin_prevue_key,

    /* Une référence inconnue reçoit la clé 0. */
    COALESCE(c.client_key, 0) AS client_key,
    COALESCE(a.agence_key, 0) AS agence_key,

    cr.type_credit,
    cr.montant_initial,
    cr.taux_annuel,
    cr.duree_mois,
    cr.mensualite_theorique,
    cr.score_risque_octroi,
    cr.statut_credit,

    1 AS nombre_credits

FROM staging.credits AS cr

LEFT JOIN mart.dim_date AS d_octroi
    ON d_octroi.date_complete = cr.date_octroi

LEFT JOIN mart.dim_date AS d_fin
    ON d_fin.date_complete = cr.date_fin_prevue

LEFT JOIN mart.dim_client AS c
    ON c.client_id = cr.client_id

LEFT JOIN mart.dim_agence AS a
    ON a.agence_id = cr.agence_id;
GO


/* ============================================================
   5.2. CRÉER LES INDEX DE fact_credits
   ============================================================ */

CREATE INDEX IX_fact_credits_date_octroi
    ON mart.fact_credits(date_octroi_key);

CREATE INDEX IX_fact_credits_date_fin_prevue
    ON mart.fact_credits(date_fin_prevue_key);

CREATE INDEX IX_fact_credits_client
    ON mart.fact_credits(client_key);

CREATE INDEX IX_fact_credits_agence
    ON mart.fact_credits(agence_key);
GO


/* ============================================================
   6. CRÉER mart.fact_remboursements
   ============================================================ */

/* GRAIN :

   Une ligne représente une échéance de remboursement.

   credit_id reste directement dans la table de faits.

   On parle de dimension dégénérée :

   - l’identifiant métier reste utile pour filtrer et retrouver
     le crédit concerné ;
   - aucune dimension Crédit séparée n’est nécessaire.

   Le client et l’agence sont récupérés grâce au crédit
   afin d’éviter une relation directe entre deux tables de faits. */

CREATE TABLE mart.fact_remboursements
(
    remboursement_key BIGINT IDENTITY(1,1) NOT NULL,

    remboursement_id NVARCHAR(20) NOT NULL,

    /* Dimension dégénérée. */
    credit_id NVARCHAR(20) NULL,

    /* Date principale et date secondaire. */
    date_echeance_key INT NOT NULL,
    date_paiement_key INT NOT NULL,

    /* Dimensions partagées. */
    client_key INT NOT NULL,
    agence_key INT NOT NULL,

    /* Attributs récupérés du crédit. */
    type_credit NVARCHAR(100) NULL,
    statut_credit NVARCHAR(50) NULL,

    /* Mesures de remboursement. */
    montant_attendu DECIMAL(15,2) NULL,
    montant_paye DECIMAL(15,2) NULL,
    montant_non_paye DECIMAL(15,2) NULL,
    jours_retard INT NULL,

    /* Situation de l’échéance. */
    statut_remboursement NVARCHAR(50) NULL,

    /* Indicateurs binaires :
       1 = vrai, 0 = faux. */
    est_impaye BIT NOT NULL,
    est_en_retard BIT NOT NULL,

    /* Une ligne vaut une échéance. */
    nombre_echeances TINYINT NOT NULL,

    CONSTRAINT PK_fact_remboursements
        PRIMARY KEY (remboursement_key),

    CONSTRAINT UQ_fact_remboursements_id
        UNIQUE (remboursement_id),

    CONSTRAINT FK_fact_remboursements_date_echeance
        FOREIGN KEY (date_echeance_key)
        REFERENCES mart.dim_date(date_key),

    CONSTRAINT FK_fact_remboursements_date_paiement
        FOREIGN KEY (date_paiement_key)
        REFERENCES mart.dim_date(date_key),

    CONSTRAINT FK_fact_remboursements_client
        FOREIGN KEY (client_key)
        REFERENCES mart.dim_client(client_key),

    CONSTRAINT FK_fact_remboursements_agence
        FOREIGN KEY (agence_key)
        REFERENCES mart.dim_agence(agence_key)
);
GO


/* ============================================================
   6.1. CHARGER mart.fact_remboursements
   ============================================================ */

INSERT INTO mart.fact_remboursements
(
    remboursement_id,
    credit_id,
    date_echeance_key,
    date_paiement_key,
    client_key,
    agence_key,
    type_credit,
    statut_credit,
    montant_attendu,
    montant_paye,
    montant_non_paye,
    jours_retard,
    statut_remboursement,
    est_impaye,
    est_en_retard,
    nombre_echeances
)
SELECT
    r.remboursement_id,
    r.credit_id,

    /* Date d’échéance non retrouvée → clé 0. */
    COALESCE(d_echeance.date_key, 0) AS date_echeance_key,

    /* Une échéance impayée sans date de paiement reçoit
       naturellement date_paiement_key = 0. */
    COALESCE(d_paiement.date_key, 0) AS date_paiement_key,

    /* Si le crédit n’existe pas, aucun client ni aucune agence
       ne peuvent être récupérés : les clés deviennent 0. */
    COALESCE(dc.client_key, 0) AS client_key,
    COALESCE(da.agence_key, 0) AS agence_key,

    cr.type_credit,
    cr.statut_credit,

    r.montant_attendu,
    r.montant_paye,

    /* Calcul du montant non payé :

       - montant payé invalide et devenu NULL
         → résultat NULL, car on ne doit pas inventer une valeur ;

       - montant payé supérieur au montant attendu
         → résultat ramené à 0 ;

       - sinon :
         montant attendu - montant payé. */
    CASE
        WHEN r.montant_paye IS NULL
            THEN NULL

        WHEN r.montant_attendu - r.montant_paye < 0
            THEN 0

        ELSE r.montant_attendu - r.montant_paye
    END AS montant_non_paye,

    r.jours_retard,
    r.statut_remboursement,

    /* Indicateur d’impayé. */
    CASE
        WHEN r.statut_remboursement = N'Impayé'
            THEN 1
        ELSE 0
    END AS est_impaye,

    /* Indicateur de paiement en retard. */
    CASE
        WHEN r.statut_remboursement = N'Payé en retard'
            THEN 1
        ELSE 0
    END AS est_en_retard,

    1 AS nombre_echeances

FROM staging.remboursements AS r

/* Cette jointure enrichit le remboursement avec le crédit.
   Elle ne crée pas de relation entre deux faits dans Power BI. */
LEFT JOIN staging.credits AS cr
    ON cr.credit_id = r.credit_id

LEFT JOIN mart.dim_date AS d_echeance
    ON d_echeance.date_complete = r.date_echeance

LEFT JOIN mart.dim_date AS d_paiement
    ON d_paiement.date_complete = r.date_paiement

LEFT JOIN mart.dim_client AS dc
    ON dc.client_id = cr.client_id

LEFT JOIN mart.dim_agence AS da
    ON da.agence_id = cr.agence_id;
GO


/* ============================================================
   6.2. CRÉER LES INDEX DE fact_remboursements
   ============================================================ */

CREATE INDEX IX_fact_remboursements_date_echeance
    ON mart.fact_remboursements(date_echeance_key);

CREATE INDEX IX_fact_remboursements_date_paiement
    ON mart.fact_remboursements(date_paiement_key);

CREATE INDEX IX_fact_remboursements_client
    ON mart.fact_remboursements(client_key);

CREATE INDEX IX_fact_remboursements_agence
    ON mart.fact_remboursements(agence_key);

CREATE INDEX IX_fact_remboursements_credit_id
    ON mart.fact_remboursements(credit_id);
GO


/* ============================================================
   7. CRÉER mart.fact_objectifs_agences
   ============================================================ */

/* GRAIN :

   Une ligne représente les objectifs d’une agence pour un mois.

   La combinaison suivante doit être unique :

   date_key + agence_key.

   Exemple :

   agence A001 en janvier 2023
   → une seule ligne. */

CREATE TABLE mart.fact_objectifs_agences
(
    objectif_key BIGINT IDENTITY(1,1) NOT NULL,

    /* Le mois est représenté par son premier jour.

       Exemple :
       janvier 2023 → date_key 20230101. */
    date_key INT NOT NULL,

    agence_key INT NOT NULL,

    /* Mesures d’objectifs. */
    objectif_revenu DECIMAL(15,2) NULL,
    objectif_nouveaux_clients INT NULL,
    objectif_production_credit DECIMAL(15,2) NULL,
    seuil_taux_impaye_pct DECIMAL(5,2) NULL,

    /* Une ligne vaut un objectif agence-mois. */
    nombre_lignes_objectif TINYINT NOT NULL,

    CONSTRAINT PK_fact_objectifs_agences
        PRIMARY KEY (objectif_key),

    /* Garantit une seule ligne par agence et par mois. */
    CONSTRAINT UQ_fact_objectifs_agence_mois
        UNIQUE (date_key, agence_key),

    CONSTRAINT FK_fact_objectifs_date
        FOREIGN KEY (date_key)
        REFERENCES mart.dim_date(date_key),

    CONSTRAINT FK_fact_objectifs_agence
        FOREIGN KEY (agence_key)
        REFERENCES mart.dim_agence(agence_key)
);
GO


/* ============================================================
   7.1. CHARGER mart.fact_objectifs_agences
   ============================================================ */

INSERT INTO mart.fact_objectifs_agences
(
    date_key,
    agence_key,
    objectif_revenu,
    objectif_nouveaux_clients,
    objectif_production_credit,
    seuil_taux_impaye_pct,
    nombre_lignes_objectif
)
SELECT
    COALESCE(d.date_key, 0) AS date_key,
    COALESCE(a.agence_key, 0) AS agence_key,

    o.objectif_revenu,
    o.objectif_nouveaux_clients,
    o.objectif_production_credit,
    o.seuil_taux_impaye_pct,

    1 AS nombre_lignes_objectif

FROM staging.objectifs_agences AS o

LEFT JOIN mart.dim_date AS d -- A LEFT JOIN B : A est toujours la table de gauche (celle dont on garde absolument toutes les lignes)
    ON d.date_complete = o.mois

LEFT JOIN mart.dim_agence AS a
    ON a.agence_id = o.agence_id;
GO


/* ============================================================
   7.2. CRÉER LES INDEX DE fact_objectifs_agences
   ============================================================ */

CREATE INDEX IX_fact_objectifs_date
    ON mart.fact_objectifs_agences(date_key);

CREATE INDEX IX_fact_objectifs_agence
    ON mart.fact_objectifs_agences(agence_key);
GO


/* ============================================================
   8. CRÉER mart.fact_entrees_clients
   ============================================================ */

/* OBJECTIF :

   Cette table permettra de comparer dans Power BI :

   nombre réel de nouveaux clients
   contre
   objectif mensuel de nouveaux clients.

   GRAIN :

   Une ligne représente l’entrée d’un client dans la banque.

   client_key doit donc être unique dans cette table. */

CREATE TABLE mart.fact_entrees_clients
(
    entree_client_key BIGINT IDENTITY(1,1) NOT NULL,

    /* Dimensions utilisées pour analyser les entrées. */
    date_key INT NOT NULL,
    client_key INT NOT NULL,
    agence_key INT NOT NULL,

    /* Une ligne vaut un nouveau client. */
    nombre_nouveaux_clients TINYINT NOT NULL,

    CONSTRAINT PK_fact_entrees_clients
        PRIMARY KEY (entree_client_key),

    /* Un client ne peut être compté qu’une seule fois. */
    CONSTRAINT UQ_fact_entrees_clients_client
        UNIQUE (client_key),

    CONSTRAINT FK_fact_entrees_date
        FOREIGN KEY (date_key)
        REFERENCES mart.dim_date(date_key),

    CONSTRAINT FK_fact_entrees_client
        FOREIGN KEY (client_key)
        REFERENCES mart.dim_client(client_key),

    CONSTRAINT FK_fact_entrees_agence
        FOREIGN KEY (agence_key)
        REFERENCES mart.dim_agence(agence_key)
);
GO


/* ============================================================
   8.1. CHARGER mart.fact_entrees_clients
   ============================================================ */

INSERT INTO mart.fact_entrees_clients
(
    date_key,
    client_key,
    agence_key,
    nombre_nouveaux_clients
)
SELECT
    COALESCE(d.date_key, 0) AS date_key,
    COALESCE(dc.client_key, 0) AS client_key,
    COALESCE(da.agence_key, 0) AS agence_key,

    1 AS nombre_nouveaux_clients

FROM staging.clients AS c

LEFT JOIN mart.dim_date AS d
    ON d.date_complete = c.date_entree

LEFT JOIN mart.dim_client AS dc
    ON dc.client_id = c.client_id

LEFT JOIN mart.dim_agence AS da
    ON da.agence_id = c.agence_id;
GO


/* ============================================================
   8.2. CRÉER LES INDEX DE fact_entrees_clients
   ============================================================ */

CREATE INDEX IX_fact_entrees_date
    ON mart.fact_entrees_clients(date_key);

CREATE INDEX IX_fact_entrees_agence
    ON mart.fact_entrees_clients(agence_key);
GO


/* ============================================================
   9. CONTRÔLER LES NOMBRES DE LIGNES
   ============================================================ */

/* COUNT_BIG fonctionne comme COUNT, mais renvoie un BIGINT.

   Les contrôles comparent chaque table staging à sa table
   de faits correspondante.

   Aucune ligne ne doit être perdue pendant le chargement. */

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

DECLARE @clients_staging BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM staging.clients
);

DECLARE @entrees_clients_mart BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_entrees_clients
);


/* Tableau dynamique de contrôle. */
SELECT
    N'fact_transactions' AS table_faits,
    @transactions_staging AS lignes_staging,
    @transactions_mart AS lignes_mart,

    CASE
        WHEN @transactions_staging = @transactions_mart
            THEN N'CONCLUSION : OK. Une ligne par transaction unique.'
        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. Différence de ',
            ABS(@transactions_staging - @transactions_mart),
            N' ligne(s).'
        )
    END AS conclusion

UNION ALL

SELECT
    N'fact_credits',
    @credits_staging,
    @credits_mart,

    CASE
        WHEN @credits_staging = @credits_mart
            THEN N'CONCLUSION : OK. Une ligne par contrat de crédit.'
        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. Différence de ',
            ABS(@credits_staging - @credits_mart),
            N' ligne(s).'
        )
    END

UNION ALL

SELECT
    N'fact_remboursements',
    @remboursements_staging,
    @remboursements_mart,

    CASE
        WHEN @remboursements_staging = @remboursements_mart
            THEN N'CONCLUSION : OK. Une ligne par échéance.'
        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. Différence de ',
            ABS(@remboursements_staging - @remboursements_mart),
            N' ligne(s).'
        )
    END

UNION ALL

SELECT
    N'fact_objectifs_agences',
    @objectifs_staging,
    @objectifs_mart,

    CASE
        WHEN @objectifs_staging = @objectifs_mart
            THEN N'CONCLUSION : OK. Une ligne par agence et par mois.'
        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. Différence de ',
            ABS(@objectifs_staging - @objectifs_mart),
            N' ligne(s).'
        )
    END

UNION ALL

SELECT
    N'fact_entrees_clients',
    @clients_staging,
    @entrees_clients_mart,

    CASE
        WHEN @clients_staging = @entrees_clients_mart
            THEN N'CONCLUSION : OK. Une ligne par nouveau client.'
        ELSE CONCAT(
            N'CONCLUSION : ATTENTION. Différence de ',
            ABS(@clients_staging - @entrees_clients_mart),
            N' ligne(s).'
        )
    END;
GO


/* ============================================================
   10. ARRÊTER LE SCRIPT SI UNE LIGNE A ÉTÉ PERDUE
   ============================================================ */

/* THROW déclenche une vraie erreur si un écart existe.

   Chaque bloc est séparé par GO, donc les variables précédentes
   n’existent plus ici. Les nombres sont recalculés directement. */

IF
(
    SELECT COUNT_BIG(*)
    FROM staging.transactions
)
<>
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_transactions
)
BEGIN
    ;THROW 52021,
           N'Le nombre de transactions diffère entre staging et mart.',
           1;
END;

IF
(
    SELECT COUNT_BIG(*)
    FROM staging.credits
)
<>
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_credits
)
BEGIN
    ;THROW 52022,
           N'Le nombre de crédits diffère entre staging et mart.',
           1;
END;

IF
(
    SELECT COUNT_BIG(*)
    FROM staging.remboursements
)
<>
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_remboursements
)
BEGIN
    ;THROW 52023,
           N'Le nombre de remboursements diffère entre staging et mart.',
           1;
END;

IF
(
    SELECT COUNT_BIG(*)
    FROM staging.objectifs_agences
)
<>
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_objectifs_agences
)
BEGIN
    ;THROW 52024,
           N'Le nombre d’objectifs diffère entre staging et mart.',
           1;
END;

IF
(
    SELECT COUNT_BIG(*)
    FROM staging.clients
)
<>
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_entrees_clients
)
BEGIN
    ;THROW 52025,
           N'Le nombre d’entrées clients diffère du nombre de clients.',
           1;
END;
GO


/* ============================================================
   11. CONCLUSION FINALE
   ============================================================ */

DECLARE @total_transactions BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_transactions
);

DECLARE @total_credits BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_credits
);

DECLARE @total_remboursements BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_remboursements
);

DECLARE @total_objectifs BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_objectifs_agences
);

DECLARE @total_entrees_clients BIGINT =
(
    SELECT COUNT_BIG(*)
    FROM mart.fact_entrees_clients
);


SELECT
    @total_transactions AS transactions,
    @total_credits AS credits,
    @total_remboursements AS remboursements,
    @total_objectifs AS objectifs_agences,
    @total_entrees_clients AS entrees_clients,

    CONCAT(
        N'CONCLUSION FINALE : les cinq tables de faits ont été ',
        N'recréées avec succès. Le modèle contient ',
        @total_transactions,
        N' transactions, ',
        @total_credits,
        N' crédits, ',
        @total_remboursements,
        N' échéances, ',
        @total_objectifs,
        N' objectifs mensuels et ',
        @total_entrees_clients,
        N' entrées clients. Le fichier 13 peut maintenant être exécuté.'
    ) AS conclusion_finale;
GO


/* ============================================================
   CONCLUSION DOCUMENTAIRE

   mart.fact_transactions
   → une ligne par transaction.

   mart.fact_credits
   → une ligne par crédit.

   mart.fact_remboursements
   → une ligne par échéance.

   mart.fact_objectifs_agences
   → une ligne par agence et par mois.

   mart.fact_entrees_clients
   → une ligne par entrée client.

   PRINCIPES RESPECTÉS :

   - tables recréées proprement à chaque exécution ;
   - lots séparés avec GO pour éviter les erreurs Msg 208 ;
   - grain clairement défini ;
   - clés techniques entières ;
   - clés étrangères vers les dimensions ;
   - membre inconnu représenté par la clé 0 ;
   - index sur les principales clés de jointure ;
   - contrôle du nombre de lignes ;
   - aucune relation directe entre deux tables de faits.

   PROCHAINE ACTION :

   Exécuter 13_controles_modele_mart.sql.
   ============================================================ */
