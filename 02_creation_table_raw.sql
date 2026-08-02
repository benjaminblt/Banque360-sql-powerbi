/* ============================================================
   PROJET : Banque 360
   FICHIER : 02_creation_tables_raw.sql

   ÉTAPE DU FICHIER :

   Étape 4 sur 8 -> L'étape 3 était à faire manuellement donc pas de code SQL pour cette partie
   Créer les tables adaptées

   AVANCEMENT :

   Étape 1 - Créer la base Banque360 : TERMINÉE
   Étape 2 - Créer les schémas de rangement : TERMINÉE
   Étape 3 - Examiner les colonnes des 7 fichiers CSV à la main : TERMINÉE
   Étape 4 - Créer les tables adaptées : EN COURS

   OBJECTIF :

   Créer les 7 tables du schéma raw correspondant exactement
   aux colonnes présentes dans les 7 fichiers CSV.

   TABLES CRÉÉES :

   - raw.agences
   - raw.clients
   - raw.credits
   - raw.objectifs_agences
   - raw.produits
   - raw.remboursements
   - raw.transactions

   POURQUOI LES COLONNES SONT-ELLES EN NVARCHAR ?

   La zone raw conserve les données telles qu'elles arrivent.

   Les dates, nombres et montants sont donc temporairement
   stockés comme du texte afin qu'une valeur incorrecte ne
   bloque pas l'import complet du fichier.

   Les conversions vers DATE, DATETIME2, INT et DECIMAL seront
   réalisées pendant l'étape 6 dans le schéma staging.
   ============================================================ */


/* ------------------------------------------------------------
   USE sélectionne la base active.

   Toutes les tables suivantes seront créées dans Banque360.
   ------------------------------------------------------------ */

USE Banque360;
GO

/* ============================================================
   1. TABLE raw.agences
   Source : agences.csv
   Nombre de colonnes : 9
   ============================================================ */

/* ------------------------------------------------------------
   OBJECT_ID recherche un objet dans SQL Server.

   N'raw.agences'
   → nom complet de la table recherchée.

   N'U'
   → précise que l'objet recherché est une table utilisateur.

   IS NULL
   → la table n'existe pas encore.

   La table est donc créée uniquement si elle est absente.
   ------------------------------------------------------------ */

IF OBJECT_ID(N'raw.agences', N'U') IS NULL
BEGIN
    CREATE TABLE raw.agences
    (
        /* Identifiant de l'agence. */
        agence_id NVARCHAR(20) NULL, -- Crée une colonne texte de 20 caractères maximum où la valeur peut être vide.

        /* Nom de l'agence bancaire. */
        nom_agence NVARCHAR(150) NULL, -- Crée une colonne texte de 150 caractères maximum où la valeur peut être vide.

        /* Ville dans laquelle se trouve l'agence. */
        ville NVARCHAR(100) NULL,

        /* Code postal conservé comme texte. */
        code_postal NVARCHAR(10) NULL,

        /* Département de l'agence. */
        departement NVARCHAR(100) NULL,

        /* Région de l'agence. */
        region NVARCHAR(100) NULL,

        /* Date d'ouverture.
           Type cible dans staging : DATE. */
        date_ouverture NVARCHAR(30) NULL,

        /* Nombre de salariés.
           Type cible dans staging : INT. */
        effectif NVARCHAR(20) NULL,

        /* Catégorie de l'agence. */
        categorie_agence NVARCHAR(100) NULL
    );
END;
GO

/* ============================================================
   2. TABLE raw.clients
   Source : clients_raw.csv
   Nombre de colonnes : 15
   ============================================================ */

IF OBJECT_ID(N'raw.clients', N'U') IS NULL
BEGIN
    CREATE TABLE raw.clients
    (
        /* Numéro de la ligne dans le fichier source.
           Type cible dans staging : INT. */
        ligne_source NVARCHAR(20) NULL,

        /* Identifiant unique du client. */
        client_id NVARCHAR(20) NULL,

        /* Prénom du client. */
        prenom NVARCHAR(100) NULL,

        /* Nom du client. */
        nom NVARCHAR(100) NULL,

        /* Date de naissance.
           Type cible dans staging : DATE. */
        date_naissance NVARCHAR(30) NULL,

        /* Date d'entrée dans la banque.
           Type cible dans staging : DATE. */
        date_entree NVARCHAR(30) NULL,

        /* Segment : Particulier, Professionnel... */
        segment NVARCHAR(100) NULL,

        /* Profession déclarée par le client. */
        profession NVARCHAR(150) NULL,

        /* Revenu mensuel.
           Type cible dans staging : DECIMAL. */
        revenu_mensuel NVARCHAR(30) NULL,

        /* Score de risque initial.
           Type cible dans staging : INT. */
        score_risque_initial NVARCHAR(20) NULL,

        /* Agence du client.
           Relation future avec agences.agence_id. */
        agence_id NVARCHAR(20) NULL,

        /* Ville du client. */
        ville NVARCHAR(100) NULL,

        /* Code postal conservé comme texte. */
        code_postal NVARCHAR(10) NULL,

        /* Adresse électronique du client. */
        email NVARCHAR(255) NULL,

        /* Statut actuel : Actif, Inactif... */
        statut_client NVARCHAR(50) NULL
    );
END;
GO

/* ============================================================
   3. TABLE raw.credits
   Source : credits_raw.csv
   Nombre de colonnes : 13
   ============================================================ */

IF OBJECT_ID(N'raw.credits', N'U') IS NULL
BEGIN
    CREATE TABLE raw.credits
    (
        /* Numéro de la ligne dans le fichier source.
           Type cible dans staging : INT. */
        ligne_source NVARCHAR(20) NULL,

        /* Identifiant unique du crédit. */
        credit_id NVARCHAR(20) NULL,

        /* Client ayant souscrit le crédit.
           Relation future avec clients.client_id. */
        client_id NVARCHAR(20) NULL,

        /* Agence ayant accordé le crédit.
           Relation future avec agences.agence_id. */
        agence_id NVARCHAR(20) NULL,

        /* Type de crédit : immobilier, personnel... */
        type_credit NVARCHAR(100) NULL,

        /* Date d'octroi du crédit.
           Type cible dans staging : DATE. */
        date_octroi NVARCHAR(30) NULL,

        /* Montant emprunté au départ.
           Type cible dans staging : DECIMAL. */
        montant_initial NVARCHAR(30) NULL,

        /* Taux d'intérêt annuel.
           Type cible dans staging : DECIMAL. */
        taux_annuel NVARCHAR(20) NULL,

        /* Durée totale en mois.
           Type cible dans staging : INT. */
        duree_mois NVARCHAR(20) NULL,

        /* Mensualité prévue par le contrat.
           Type cible dans staging : DECIMAL. */
        mensualite_theorique NVARCHAR(30) NULL,

        /* Score de risque lors de l'octroi.
           Type cible dans staging : INT. */
        score_risque_octroi NVARCHAR(20) NULL,

        /* Situation actuelle du crédit. */
        statut_credit NVARCHAR(50) NULL,

        /* Date théorique de fin.
           Type cible dans staging : DATE. */
        date_fin_prevue NVARCHAR(30) NULL
    );
END;
GO


/* ============================================================
   4. TABLE raw.objectifs_agences
   Source : objectifs_agences.csv
   Nombre de colonnes : 6
   ============================================================ */

IF OBJECT_ID(N'raw.objectifs_agences', N'U') IS NULL
BEGIN
    CREATE TABLE raw.objectifs_agences
    (
        /* Agence concernée par l'objectif.
           Relation future avec agences.agence_id. */
        agence_id NVARCHAR(20) NULL,

        /* Mois concerné au format AAAA-MM.
           Type cible dans staging : DATE. */
        mois NVARCHAR(10) NULL,

        /* Revenu mensuel visé.
           Type cible dans staging : DECIMAL. */
        objectif_revenu NVARCHAR(30) NULL,

        /* Nombre de nouveaux clients visé.
           Type cible dans staging : INT. */
        objectif_nouveaux_clients NVARCHAR(20) NULL,

        /* Montant de crédits à produire.
           Type cible dans staging : DECIMAL. */
        objectif_production_credit NVARCHAR(30) NULL,

        /* Seuil maximal du taux d'impayés.
           Type cible dans staging : DECIMAL. */
        seuil_taux_impaye_pct NVARCHAR(20) NULL
    );
END;
GO


/* ============================================================
   5. TABLE raw.produits
   Source : produits.csv
   Nombre de colonnes : 5
   ============================================================ */

IF OBJECT_ID(N'raw.produits', N'U') IS NULL
BEGIN
    CREATE TABLE raw.produits
    (
        /* Identifiant unique du produit. */
        produit_id NVARCHAR(20) NULL,

        /* Nom du produit bancaire. */
        nom_produit NVARCHAR(150) NULL,

        /* Famille : Carte, Crédit, Épargne... */
        famille_produit NVARCHAR(100) NULL,

        /* Univers d'analyse du produit. */
        univers NVARCHAR(100) NULL,

        /* Niveau de complexité observé de 1 à 4.
           Type cible dans staging : INT. */
        niveau_complexite NVARCHAR(20) NULL
    );
END;
GO

/* ============================================================
   6. TABLE raw.remboursements
   Source : remboursements_raw.csv
   Nombre de colonnes : 8
   ============================================================ */

IF OBJECT_ID(N'raw.remboursements', N'U') IS NULL
BEGIN
    CREATE TABLE raw.remboursements
    (
        /* Identifiant unique du remboursement. */
        remboursement_id NVARCHAR(20) NULL,

        /* Crédit concerné.
           Relation future avec credits.credit_id. */
        credit_id NVARCHAR(20) NULL,

        /* Date prévue du paiement.
           Type cible dans staging : DATE. */
        date_echeance NVARCHAR(30) NULL,

        /* Date réelle du paiement.
           Type cible dans staging : DATE. */
        date_paiement NVARCHAR(30) NULL,

        /* Montant qui devait être payé.
           Type cible dans staging : DECIMAL. */
        montant_attendu NVARCHAR(30) NULL,

        /* Montant réellement payé.
           Type cible dans staging : DECIMAL. */
        montant_paye NVARCHAR(30) NULL,

        /* Nombre de jours de retard.
           Type cible dans staging : INT. */
        jours_retard NVARCHAR(20) NULL,

        /* Statut : payé à temps, en retard... */
        statut_remboursement NVARCHAR(100) NULL
    );
END;
GO

/* ============================================================
   7. TABLE raw.transactions
   Source : transactions_raw.csv
   Nombre de colonnes : 13
   ============================================================ */

IF OBJECT_ID(N'raw.transactions', N'U') IS NULL
BEGIN
    CREATE TABLE raw.transactions
    (
        /* Numéro de la ligne dans le fichier source.
           Type cible dans staging : INT. */
        ligne_source NVARCHAR(20) NULL,

        /* Identifiant unique de la transaction. */
        transaction_id NVARCHAR(30) NULL,

        /* Client concerné.
           Relation future avec clients.client_id. */
        client_id NVARCHAR(20) NULL,

        /* Date et heure de la transaction.
           Type cible dans staging : DATETIME2. */
        date_transaction NVARCHAR(30) NULL,

        /* Nature de l'opération bancaire. */
        type_transaction NVARCHAR(100) NULL,

        /* Montant signé de la transaction.
           Type cible dans staging : DECIMAL. */
        montant NVARCHAR(30) NULL,

        /* Sens de l'opération : Débit ou Crédit. */
        sens NVARCHAR(20) NULL,

        /* Produit bancaire associé.
           Relation future avec produits.produit_id. */
        produit_id NVARCHAR(20) NULL,

        /* Agence associée.
           Relation future avec agences.agence_id. */
        agence_id NVARCHAR(20) NULL,

        /* Canal utilisé : Web, application mobile... */
        canal NVARCHAR(100) NULL,

        /* Statut de la transaction. */
        statut NVARCHAR(50) NULL,

        /* Frais appliqués.
           Type cible dans staging : DECIMAL. */
        frais NVARCHAR(30) NULL,

        /* Devise utilisée, par exemple EUR. */
        devise NVARCHAR(10) NULL
    );
END;
GO

/* ============================================================
   VÉRIFICATION FINALE
   ============================================================ */

/* ------------------------------------------------------------
   Cette requête affiche le nombre de colonnes de chaque table.

   COUNT(*) compte les colonnes trouvées.

   GROUP BY rassemble les lignes ayant le même nom de table
   afin d'obtenir un résultat par table.

   IN permet de sélectionner plusieurs tables.

   ORDER BY trie les résultats par nom de table.
   ------------------------------------------------------------ */
   
SELECT
    TABLE_NAME AS table_raw,
    COUNT(*) AS nombre_colonnes
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = N'raw'
  AND TABLE_NAME IN
  (
      N'agences',
      N'clients',
      N'credits',
      N'objectifs_agences',
      N'produits',
      N'remboursements',
      N'transactions'
  )
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;
GO