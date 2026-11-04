# Gestion d'avoir — Défis

## Objectif

Mesurer ce que je sais faire seule et ce que je dois encore revoir, en modifiant le code avec la documentation comme seul repère.

## Règles

1. Je crée une branche Git dédiée avant de commencer.
2. Je lance le chrono au moment où je commence à lire le défi.
3. Je peux utiliser la documentation du projet et le code existant.
4. Claude ne donne pas la solution. Si je bloque, je demande « indice ». Claude donne seulement une piste ou une section à relire.
5. Je note l'heure de début, l'heure de fin et le nombre d'indices utilisés.
6. Quand le temps est écoulé, je m'arrête et je demande la correction, même si le défi n'est pas terminé.
7. Quand j'ai fini, je dis « j'ai fini ». Claude relit le code, vérifie qu'il compile, le teste si besoin avec un `ROLLBACK`, puis me pose 2 ou 3 questions.

| Défi | Niveau | Temps limite |
|---|---|---|
| 1. Protéger le trigger contre les doublons | Facile | 20 min |
| 2. Calculer le total des avoirs d'une vente | Facile à moyen | 30 min |
| 3. Afficher les montants sur la fiche | Moyen | 45 min |
| 4. Bloquer le dépassement | Difficile | 60 min |
| 5. Gérer le retour de 1 à 0 | Très difficile | 90 min |

**Temps total maximum : 4 h 05.** Je peux faire les défis sur plusieurs séances.

---

## Défi 1 : protéger le trigger contre les doublons

**Temps limite : 20 min**

**Problème :** si `probleme` passe de 1 à 0, puis de nouveau à 1, le trigger crée un 2e avoir.

**Travail demandé :** modifier le trigger pour qu'une vente qui a déjà un avoir non annulé n'en reçoive pas un autre.

**Le défi est réussi si :**
- le passage de 0 à 1 crée toujours un avoir sur une vente qui n'en a pas ;
- le passage 1 → 0 → 1 ne crée pas de 2e avoir ;
- une modification sans changement de `probleme` ne crée rien ;
- le code compile.

**Repères :** `gestionAvoir/etape1/` et `gestionAvoir/etape3/`

---

## Défi 2 : calculer le total des avoirs d'une vente

**Temps limite : 30 min**

**Travail demandé :** ajouter dans `Vente` la méthode `getMontantTotalAvoirs(Connection c)`.

Elle renvoie la somme TTC, en ariary, des avoirs non annulés de cette vente.

**Le défi est réussi si :**
- la méthode renvoie `0` si la vente n'a pas d'avoir ;
- un avoir annulé (`etat = 0`) n'est pas compté ;
- le résultat est identique à celui d'une requête SQL de contrôle ;
- la méthode fonctionne avec une connexion fournie et avec `null` ;
- une connexion fournie par l'appelant n'est pas fermée ;
- le code compile.

**Repères :** `apprentissageAPJ/lecon2/` et `gestionAvoir/etape2/`

---

## Défi 3 : afficher les montants sur la fiche

**Temps limite : 45 min**

**Travail demandé :** afficher dans `vente-arbiochem-fiche.jsp` :
- l'avoir disponible du client ;
- le reste à payer après utilisation de l'avoir.

**Le défi est réussi si :**
- les deux montants sont visibles sur la fiche ;
- ils sont justes pour un client sans avoir disponible ;
- ils sont justes pour un client qui a un avoir disponible ;
- le reste à payer affiché n'est jamais négatif ;
- l'application a été redéployée et vérifiée dans le navigateur ;
- aucune connexion ouverte par la page ne reste ouverte.

**Repères :** `gestionAvoir/etape2/` et `gestionAvoir/etape1/02_correction_stackoverflow.md`

---

## Défi 4 : bloquer le dépassement

**Temps limite : 60 min**

**Problème :** le total des avoirs d'une vente ne doit jamais dépasser son montant TTC.

**Travail demandé :** refuser la création d'un avoir si ce total serait dépassé, avec un message clair.

**Le défi est réussi si :**
- un avoir total accepté sur une vente sans avoir reste possible ;
- plusieurs avoirs partiels restent possibles tant que le total ne dépasse pas le TTC ;
- un avoir qui ferait dépasser le TTC est refusé ;
- un refus ne laisse ni en-tête ni ligne d'avoir en base ;
- je sais expliquer pourquoi j'ai choisi cet endroit du code.

**Repères :** `apprentissageAPJ/lecon1/`, `apprentissageAPJ/lecon3/` et `gestionAvoir/etape3/`

---

## Défi 5 : gérer le retour de 1 à 0

**Temps limite : 90 min**

**Problème :** quand `probleme` repasse de 1 à 0, l'avoir créé par le trigger reste actif.

**Travail demandé :** gérer ce retour :
- si l'avoir n'a pas été utilisé, il est annulé ;
- si l'avoir a déjà servi, la modification est refusée avec un message clair.

**Le défi est réussi si :**
- le passage de 1 à 0 annule un avoir non utilisé ;
- le passage de 1 à 0 est refusé si l'avoir a déjà servi ;
- après un refus, la vente garde `probleme = 1` et rien n'a changé en base ;
- la modification de la vente et l'annulation de l'avoir sont dans la même transaction ;
- je sais expliquer les risques de ma solution.

**Repères :** toute la documentation de `gestionAvoir/` et de `apprentissageAPJ/`

---

## Mon suivi

| Défi | Début | Fin | Temps utilisé | Indices | Terminé ? | Bilan de Claude |
|---|---|---|---|---|---|---|
| 1 | | | | solution expliquée sans code | oui | Réussi avec aide. Doublon bloqué et tests validés. À revoir : effet de l'exception sur la transaction. |
| 2 | | | | | | |
| 3 | | | | | | |
| 4 | | | | | | |
| 5 | | | | | | |
