# Gestion d'avoir — Étape 1 : vue d'ensemble

## Objectif de l'étape

Quand une vente est marquée comme ayant un problème (sa colonne `PROBLEME` passe de `0` à `1`), je veux qu'un **avoir** soit créé automatiquement pour cette vente. L'avoir, c'est l'en-tête dans `AVOIRFC` plus ses lignes dans `AVOIRFCFILLE`.

Je fais ce « trigger » dans la **couche métier Java** (la classe `vente.Vente`), et **pas** dans la base de données. Toute la logique reste ainsi dans le code de l'application, au même endroit que le reste des règles de gestion.

## Fichiers touchés dans cette étape

| Fichier | Ce que j'ai fait | Documentation détaillée |
|---|---|---|
| `arbiochem-ejb/src/java/vente/Vente.java` | J'ai **ajouté** la méthode `updateToTableWithHisto(String u, Connection c)`, lignes 624 à 634. | [Vente.java.md](Vente.java.md) |
| `arbiochem-ejb/src/java/vente/Vente.java` | J'ai **modifié** une ligne de `genererAvoir2(...)` : le `commit()` (ligne 1379) et son commentaire (ligne 1378). | [Vente.java.md](Vente.java.md) |

Aucun autre fichier n'a été modifié : pas de JSP, pas de SQL, pas de trigger en base.

## Ce que j'ai analysé avant d'écrire le code (et pourquoi)

### 1. Où « accrocher » mon trigger métier ?

Un trigger de base de données s'exécute « quand la ligne est modifiée ». En Java, je dois trouver **la méthode par laquelle passe toute modification d'une Vente**. J'ai donc suivi le chemin réel d'une modification depuis l'écran :

```
vente-modif.jsp
  └─> apresMultiple.jsp                         (acte = "update" / "updateInsert")
        └─> UserEJBBean.updateObjectMultiple(mere, colonneMere, filles, c)
              └─> UserEJBBean.updateObject(mere, c)
                    └─> UpdateObject.updateObject(o, c, u, user)
                          └─> o.updateObject(idUser, c)             (framework APJ : bean.ClassEtat)
                                └─> o.updateToTableWithHisto(idUser, c)   <== ICI
                                      └─> UPDATE VENTE SET ... WHERE id = ...
```

- `apresMultiple.jsp`, `UserEJBBean.java` et `UpdateObject.java` sont dans le projet, donc je les ai lus directement.
- `bean.ClassEtat` et `bean.ClassMAPTable` sont dans `apj-core.jar`. Je les ai désassemblés avec `javap -c` pour savoir quelles méthodes ils appellent.

**Ce que j'ai découvert :**
- `controlerUpdate(Connection c)` (que la cheat-sheet présente comme « contrôle à la modification ») n'est appelé **que** dans `validerObject(...)`, c'est-à-dire **à la validation**, pas lors d'une simple modification. Ce n'est donc **pas** le bon endroit.
- `updateToTableWithHisto(String u, Connection c)` est appelé par **toutes** les opérations de modification de `ClassEtat` : `updateObject`, `validerObject`, `annuler`, `cloturerObject`, `updateEtat`. C'est le point de passage obligé : c'est l'équivalent Java d'un `AFTER UPDATE ON VENTE`.

Je **redéfinis** (`@Override`) donc `updateToTableWithHisto` dans `Vente`.

### 2. Comment créer l'avoir ?

Le projet a **déjà** une méthode qui crée un avoir complet à partir d'une vente : `Vente.genererAvoir2(String u, Connection c, String idVente)`. Elle :
- lit la vente et ses lignes ;
- construit l'en-tête de l'avoir : client, magasin, date, `etat = 1`, type `TYA0002` ;
- prend le numéro d'avoir dans la vue `V_NUMEROAVOIR_EN_COURS` ;
- crée une ligne d'avoir par ligne de vente, avec un prix unitaire net (après remise, ristourne et frais de livraison).

Je la **réutilise** plutôt que de réécrire la même chose : si un jour la règle de calcul change, elle ne change qu'à un seul endroit.

### 3. Le problème du `commit()` dans `genererAvoir2`

`genererAvoir2` faisait `c.commit();` **même quand la connexion lui était fournie par l'appelant**. Or mon trigger l'appelle **au milieu** de la transaction de modification de la vente (dans `updateObjectMultiple`, les lignes de la vente sont mises à jour **après** la mère). Avec un commit à ce moment-là :
- la modification de la vente serait validée **à moitié** ;
- si la suite échouait, le `rollback` ne pourrait plus annuler ni la vente ni l'avoir.

J'ai donc changé `c.commit();` en `if(estOuvert) c.commit();`. Le commit n'a lieu que si c'est `genererAvoir2` qui a ouvert la connexion. C'est exactement la même règle que le `rollback` et le `close` déjà présents juste en dessous.

**J'ai vérifié que ça ne casse rien.** Les seuls appelants existants sont `genererAvoir(...)` (via `apres-generation-avoir.jsp`) et `annulerFacture(...)` (via `apres-annuler.jsp`), et ils passent tous `null` comme connexion. Pour eux, `estOuvert` vaut `true`, donc le commit a toujours lieu comme avant.

## Les décisions que j'ai prises (et pourquoi)

| Décision | Pourquoi |
|---|---|
| Je lis l'**ancienne** vente en base **avant** le `super.updateToTableWithHisto(...)` | C'est l'équivalent de `:OLD` dans un trigger SQL. Une fois l'UPDATE fait, la base contient déjà la nouvelle valeur, et je ne pourrais plus savoir si `PROBLEME` valait 0 avant. |
| Je crée l'avoir **après** le `super.updateToTableWithHisto(...)` | C'est un `AFTER UPDATE`. Si l'UPDATE de la vente échoue (exception), on ne va jamais jusqu'à la création de l'avoir. |
| Condition = transition **0 → 1** (`nouveau == 1` et `ancien != 1`) | Si on ré-enregistre une vente déjà à 1 (par exemple pour corriger une autre information), je ne veux pas créer un deuxième avoir. |
| Même connexion `c` partout | L'avoir et la modification de la vente sont dans **la même transaction** : soit tout est enregistré, soit rien. |

## Comment je l'ai testé

1. **Compilation** de `Vente.java` contre les bibliothèques du projet (`build-file/lib/*` et les classes déjà compilées) : aucune erreur.
2. **Test réel sur la base**, avec un petit programme Java jetable (hors projet) qui ouvre une connexion via `UtilDB`, désactive l'auto-commit et termine par un **`ROLLBACK`**. Rien n'est donc resté en base.

```
Vente testee : VNT001699001012 | avoirs avant : 0
Modif sans probleme  -> avoirs : 0      <- une modification normale ne crée rien
Passage 0 -> 1       -> avoirs : 1      <- le trigger métier crée l'avoir
   AVRFC000334 0044/2026 etat=1 TYA0002 | INGR000001 qte=10.0 pu=2150.0
Re-modif deja a 1    -> avoirs : 1      <- pas de doublon
ROLLBACK effectue
```

Après le test, j'ai vérifié en SQL : `0` avoir pour cette vente et `PROBLEME = 0`. La base est intacte.

> Remarque : même après un `ROLLBACK`, les séquences Oracle n'avancent jamais en arrière. Les tests ont donc « consommé » quelques numéros (`AVRFC000333`, `AVRFC000334`…). Les prochains avoirs auront des numéros un peu plus loin. C'est normal en Oracle et sans conséquence.

## Ce qui n'est pas encore géré (pour les prochaines étapes)

- **L'écran ne permet pas encore de cocher « Problème ».** Si le formulaire de modification n'envoie pas ce champ, la vente est enregistrée avec `probleme = 0` (valeur par défaut d'un `int` en Java).
- Si une vente passe de 1 à 0, puis de nouveau à 1, un **deuxième** avoir est créé : il n'y a pas encore de vérification « un avoir existe déjà pour cette vente ».
- Rien n'est fait quand `PROBLEME` repasse à 0 (par exemple annuler l'avoir).
- Dans une modification depuis l'écran, la mère est mise à jour **avant** ses lignes. L'avoir est donc calculé sur les lignes **telles qu'elles étaient en base** avant cette modification.
