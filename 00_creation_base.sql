/* ============================================================
   PROJET : Banque 360
   FICHIER : 00_creation_base.sql

   ÉTAPE ACTUELLE DU PROJET :

   Étape 1 sur 8
   Créer la base Banque360

   ÉTAPES DU PROJET :

   1. Créer la base Banque360
   2. Créer les schémas de rangement
   3. Examiner les colonnes des 7 CSV à la main
   4. Créer les tables adaptées du schéma raw 
   5. Importer les données dans les tables raw
   6. Nettoyer les données dans staging
   7. Construire le modèle analytique dans mart
   8. Utiliser les résultats dans Power BI

   ORGANISATION DES DONNÉES :

   - raw :
     contient les données brutes importées depuis les CSV.
     Les valeurs sont conservées presque telles quelles.

   - staging :
     contient les données nettoyées, vérifiées et converties
     dans les bons types : DATE, INT, DECIMAL, etc.

   - mart :
     contient les données organisées pour l’analyse,
     avec les dimensions, les tables de faits et les relations.

   PARCOURS DES DONNÉES :

   CSV → raw → staging → mart → Power BI
         brut    propre     prêt à analyser

   OBJECTIF DE CE FICHIER :

   Créer la base de données Banque360 qui contiendra
   l’ensemble du projet.

   À QUOI SERT UNE BASE DE DONNÉES ?

   Une base de données est le contenant principal du projet.
   Elle regroupe :
   - les tables ;
   - les données importées depuis les CSV ;
   - les vues ;
   - les relations ;
   - les analyses SQL.

   Ici, nous créons la base Banque360 pour isoler ce projet
   des autres bases présentes sur SQL Server.

   IMPORTANT :

   - VS Code sert à écrire et à exécuter le code SQL.
   - SQL Server, lancé dans Docker, exécute réellement le code.
   - SQL Server crée et stocke la base Banque360.

   AVANCEMENT :

   Étape 1 - Créer la base Banque360 : EN COURS

   LOGIQUE DU SCRIPT :

   1. Se placer dans la base système master.
   2. Vérifier si Banque360 existe déjà.
   3. Créer Banque360 uniquement si elle n’existe pas.
   4. Activer Banque360 pour la suite du projet.
   5. Vérifier que Banque360 est bien la base active.
   ============================================================ */


/* ------------------------------------------------------------
   1. Se placer dans master

   USE choisit la base active.

   master est une base système créée automatiquement par
   SQL Server. Elle contient notamment les informations sur
   les bases présentes sur le serveur.
   ------------------------------------------------------------ */

USE master;
GO

/* ------------------------------------------------------------
   À quoi sert GO ?
   ------------------------------------------------------------

   GO marque la fin d'un lot d'instructions, appelé "batch".

   Il demande à l'outil utilisé, ici VS Code, d'envoyer toutes
   les instructions précédentes à SQL Server pour exécution.

   Important :

   GO n'est pas une instruction SQL exécutée par SQL Server.
   C'est un séparateur reconnu par les outils SQL, comme
   VS Code ou SQL Server Management Studio.
   ------------------------------------------------------------ */

/* ------------------------------------------------------------
   2. Créer Banque360 uniquement si elle n'existe pas

   DB_ID recherche l'identifiant interne d'une base.

   - Si DB_ID renvoie un nombre, Banque360 existe déjà.
   - Si DB_ID renvoie NULL, Banque360 n'existe pas.

   IF signifie "si".
   BEGIN et END délimitent le bloc exécuté si la condition
   est vraie.
   ------------------------------------------------------------ */

IF DB_ID(N'Banque360') IS NULL
BEGIN
    CREATE DATABASE Banque360;
END;
GO


/* ------------------------------------------------------------
   3. Activer Banque360

   À partir de cette ligne, SQL Server travaille dans la base
   du projet.

   Les futurs schémas, tables, vues et données seront créés
   à l'intérieur de Banque360.
   ------------------------------------------------------------ */

USE Banque360;
GO


/* ------------------------------------------------------------
   4. Vérifier la base active

   DB_NAME() renvoie le nom de la base actuellement utilisée.
   AS donne un nom lisible à la colonne du résultat.

   Résultat attendu : Banque360
   ------------------------------------------------------------ */

SELECT
    DB_NAME() AS base_active;
GO