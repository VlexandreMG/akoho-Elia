# Gestion d'avoir — Étape 3 : correction du bouton « Annuler » d'une vente

## Objectif de l'étape

Le bouton rouge **« Annuler »** de la fiche d'une vente visée (`vente-arbiochem-fiche.jsp`) devait annuler la vente en lui créant un avoir. En pratique :
- il **plantait** avec un `NullPointerException` ;
- **malgré l'erreur**, l'avoir restait en base ;
- chaque clic créait **un avoir de plus**.

Je corrige ces trois problèmes.

## Le scénario qui a révélé le bug (données réelles du 03/11/2026, client CLIA2625)

| heure | action | effet |
|---|---|---|
| 01:13 | la vente `VNT001722011135` (51 600) est visée | le client doit 51 600 et n'a rien payé |
| 02:09:40 | clic sur **« Annuler »** | avoir `AVRFC000353` (51 600) créé et **enregistré**, puis 💥 `NullPointerException` |
| 02:09:46 | 2e clic sur **« Annuler »** | avoir `AVRFC000354` (51 600) créé et **enregistré**, puis 💥 `NullPointerException` |

Le 1er avoir annule la dette du client. Le 2e, la vue `AVOIRFCLIB_CPL` le considère comme **51 600 de crédit**, alors que le client n'a jamais rien payé. Ce crédit fantôme a ensuite payé `VNT001723021320` (20 640) et `VNT001724022344` (25 800).

Traces dans `wildfly-10.1.0.Final/standalone/log/server.log` :

```
02:09:40 INSERT INTO AvoirFC ( ... )
02:09:40 java.lang.NullPointerException
02:09:40     at avoir.AvoirFC.validerObject(AvoirFC.java:275)
02:09:40     at vente.Vente.annulerFacture(Vente.java:1313)
02:09:40     at org.apache.jsp.pages.vente.apres_002dannuler_jsp._jspService(...)
```

## Ce que j'ai analysé (et pourquoi)

Le chemin du bouton :

```
vente-arbiochem-fiche.jsp  (bouton rouge « Annuler »)
 └─ vente/apres-annuler.jsp
     └─ Vente.annulerFacture(u, null, id)        ← connexion null !
         ├─ Vente.genererAvoir2(u, null, id)     ← ouvre SA connexion, crée l'avoir, fait SON commit
         └─ avoirFC.validerObject(u, null)       ← 💥 NullPointerException
```

**Les fonctions concernées, en une phrase chacune :**

| fonction | ce qu'elle fait |
|---|---|
| `Vente.annulerFacture(u, c, idVente)` | annule une vente en créant puis en validant son avoir. |
| `Vente.genererAvoir2(u, c, idVente)` | crée en base un avoir (en-tête + lignes) qui reprend toute la vente. |
| `AvoirFC.validerObject(u, c)` | valide un avoir (état 11) et génère ce qui va avec : mise à jour du plan de paiement, écriture comptable, lettrage. |
| `ClassMere.setFille(filles)` | range les lignes d'un objet mère à l'endroit où le framework les cherche (`getFille()`). |

**Les 3 causes :**

1. **L'avoir restait malgré l'erreur.** `annulerFacture` passait `null` à `genererAvoir2`. Celle-ci ouvrait donc sa propre connexion et faisait **son propre `commit`** : l'avoir était enregistré **avant** la validation. Quand la validation plantait ensuite, il était trop tard pour l'annuler. C'est exactement la question n°5 de l'exercice de l'étape 1 : « que se passe-t-il si on passe `null` ? ».
2. **Le `NullPointerException`.** `genererAvoir2` range les lignes de l'avoir avec `setAvoirDetails(...)`, mais `AvoirFC.validerObject` les cherche avec `getFille()` (ligne 273). `getFille()` renvoyait `null`, et `avoirFCFille.length` plantait (ligne 275). Le code existant de `VenteArbiochem` fait bien `avoir.setFille(...)` avant `validerObject` : c'est ce qui manquait ici.
3. **Un avoir par clic.** Rien ne vérifiait si la vente avait déjà un avoir. Le bouton reste en plus affiché, parce que la fiche le montre tant que `montantttc > avoir`, et que la vue `VENTE_CPL` ne compte pas ces avoirs (état 1, `idOrigine` vide).

## Fichiers touchés dans cette étape

| Fichier | Ce que j'ai fait | Documentation détaillée |
|---|---|---|
| `arbiochem-ejb/src/java/vente/Vente.java` | J'ai **réécrit** `annulerFacture(...)` (lignes 1310 à 1339). | [Vente.java.md](Vente.java.md), modification 1 |
| `arbiochem-ejb/src/java/vente/Vente.java` | J'ai **ajouté** `aDejaUnAvoir(...)` (lignes 1341 à 1345). | [Vente.java.md](Vente.java.md), modification 2 |

Je n'ai touché ni à `apres-annuler.jsp`, ni à `genererAvoir2`, ni à `AvoirFC.java`.

## Les décisions que j'ai prises (et pourquoi)

| Décision | Pourquoi |
|---|---|
| `annulerFacture` ouvre **une seule transaction** et la passe à `genererAvoir2` et à `validerObject` | Créer l'avoir et le valider deviennent **un seul bloc** : soit tout est enregistré, soit rien (règle d'or de la leçon 1). |
| Je n'ai **pas** modifié `apres-annuler.jsp`, qui passe toujours `null` | C'est maintenant `annulerFacture` qui ouvre la transaction quand elle reçoit `null`. La page n'a pas besoin de changer. |
| `avoirFC.setFille(avoirFC.getAvoirDetails())` dans `annulerFacture`, et pas dans `genererAvoir2` | Je corrige là où le besoin existe (juste avant `validerObject`), sans changer le comportement de `genererAvoir2`, qu'utilise aussi le trigger de l'étape 1. |
| Refus si la vente a **déjà un avoir non annulé** (`etat <> 0`) | Ça bloque le double clic, et aussi l'annulation d'une vente qui a déjà reçu son avoir par le trigger (problème = Oui). Dans les deux cas, un 2e avoir serait un crédit fantôme. |
| Contrôle dans une fonction à part, `aDejaUnAvoir` | Elle pourra servir ailleurs, par exemple pour protéger aussi le trigger de l'étape 1 contre le cas « problème 1 → 0 → 1 ». |

## Comment je l'ai testé

1. **Compilation** de `Vente.java` : aucune erreur.
2. **Test réel sur la base**, avec un programme jetable qui donne sa propre connexion et termine par un **`ROLLBACK`** :

```
Vente testee : VNT001721222845 | avoirs avant : 0
1er clic  -> avoirs (id etat) : AVRFC000357:11      <- avoir créé ET validé (état 11), plus de NullPointerException
2e clic   -> refuse : La vente VNT001721222845 a deja un avoir : elle ne peut pas etre annulee une deuxieme fois
apres 2e  -> nb avoirs : 1                           <- pas de doublon
VNT001722011135 -> refuse : La vente VNT001722011135 a deja un avoir : ...   <- la vente du scénario est protégée
ROLLBACK effectue
```

3. **Vérifié en SQL après le test** : `0` avoir pour `VNT001721222845`, `0` avoir `AVRFC000357`, `0` écriture comptable `AVRFC000357`. La base est intacte.
4. **Redéployé** avec `ant` (`BUILD SUCCESSFUL`) et vérifié avec `javap` que le `.class` déployé contient bien `aDejaUnAvoir`.

> Limite du test : il passe sa propre connexion, donc il vérifie la logique mais pas le cas `c == null` de la page (ouverture, `commit`, `close`). Ce cas suit exactement le même modèle que `genererAvoir2` et `getMontantAvoirDisponible`. À vérifier une fois sur l'écran.

## Ce qui n'est pas encore fait

- **Les données de test déjà abîmées ne sont pas réparées** : les avoirs `AVRFC000353` / `AVRFC000354` et les paiements `LP000385`, `LP000387` faits avec le crédit fantôme sont toujours en base.
- **Une vente partiellement remboursée** (avoir partiel fait avec « Générer avoir ») ne peut plus être annulée par ce bouton. C'est volontaire pour rester simple : il faudrait sinon calculer le reste à rembourser.
- `AvoirFC.validerObject` fait `c.rollback()` dans son `catch` **même si la connexion ne lui appartient pas** (elle ne respecte pas la règle d'or). Ici, ce n'est pas gênant, puisqu'`annulerFacture` annule tout de toute façon en cas d'erreur, mais à garder en tête.
- Le trigger de l'étape 1 peut encore créer un 2e avoir si `probleme` passe 1 → 0 → 1. `aDejaUnAvoir` permettra de le corriger.
- Le bug B (`NullPointerException` en modifiant un mouvement de caisse, `UserEJBBean.updateObjectMultiple:378`) n'est pas traité ici.
