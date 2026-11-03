# `arbiochem-ejb/src/java/vente/Vente.java` — Étape 3

## Modification 1 : réécriture de `annulerFacture(String u, Connection c, String idVente)`

> **Ce que fait la fonction :** elle annule une vente en créant puis en validant son avoir, dans une seule transaction et une seule fois par vente.

**Où :** classe `vente.Vente`, lignes **1310 à 1339**.

**Avant :**

```java
    public static void annulerFacture(String u, Connection c, String idVente) throws SQLException, Exception{
        AvoirFC avoirFC = genererAvoir2(u, c, idVente);

        avoirFC.validerObject(u, c);
        System.out.println("avoir généré");
    }
```

**Après :**

```java
    // J'annule une vente en créant puis en validant son avoir, dans une seule transaction et une seule fois par vente
    public static void annulerFacture(String u, Connection c, String idVente) throws SQLException, Exception{
        boolean estOuvert = false;
        // Étape 1 : si on ne m'a pas donné de connexion, j'ouvre MA transaction, sinon j'utilise celle de l'appelant
        if(c==null){
            c = new UtilDB().GetConn();
            estOuvert = true;
            c.setAutoCommit(false);
        }
        try {
            // Étape 2 : je refuse d'annuler une vente qui a déjà un avoir (double clic, ou avoir déjà créé par le trigger)
            if(Vente.aDejaUnAvoir(c, idVente)) throw new Exception("La vente "+idVente+" a deja un avoir : elle ne peut pas etre annulee une deuxieme fois");
            // Étape 3 : je crée l'avoir dans MA transaction (genererAvoir2 ne fait donc pas de commit)
            AvoirFC avoirFC = genererAvoir2(u, c, idVente);
            // Étape 4 : je donne les lignes à l'avoir là où validerObject les cherche (getFille), sinon NullPointerException
            avoirFC.setFille(avoirFC.getAvoirDetails());
            // Étape 5 : je valide l'avoir dans la même transaction
            avoirFC.validerObject(u, c);
            // Étape 6 : tout s'est bien passé : je valide la création ET la validation ensemble
            if(estOuvert) c.commit();
            System.out.println("avoir généré");
        } catch (Exception e) {
            // En cas d'erreur : j'annule tout, l'avoir ne reste pas en base
            if(estOuvert) c.rollback();
            throw e;
        } finally {
            // Je referme la connexion seulement si c'est moi qui l'ai ouverte
            if(estOuvert) c.close();
        }
    }
```

### Explication ligne par ligne

**Ligne 1310 :**
```java
    // J'annule une vente en créant puis en validant son avoir, dans une seule transaction et une seule fois par vente
```
J'ai ajouté ce commentaire pour définir la fonction en une phrase. Il n'y en avait pas.

---

**Ligne 1311 :**
```java
    public static void annulerFacture(String u, Connection c, String idVente) throws SQLException, Exception{
```
Je n'ai **pas** changé la signature. `apres-annuler.jsp` l'appelle toujours de la même façon (`Vente.annulerFacture(idUser, null, id)`), donc la page n'a pas besoin d'être modifiée.
- **`static`** : on l'appelle par la classe (`Vente.annulerFacture`), sans objet `Vente`. Elle reçoit l'id de la vente en paramètre.
- **`u`** : l'utilisateur, transmis à `genererAvoir2` et `validerObject` pour l'historique.
- **`c`** : la connexion. La page passe `null`.
- **`idVente`** : la vente à annuler.

---

**Ligne 1312 :**
```java
        boolean estOuvert = false;
```
J'ai ajouté cette variable pour me souvenir si **c'est moi** qui ouvre la connexion. C'est le même modèle que dans `genererAvoir2` et `getMontantAvoirDisponible`.

---

**Ligne 1313 :**
```java
        // Étape 1 : si on ne m'a pas donné de connexion, j'ouvre MA transaction, sinon j'utilise celle de l'appelant
```
Commentaire ajouté pour expliquer le bloc suivant.

---

**Lignes 1314 à 1318 :**
```java
        if(c==null){
            c = new UtilDB().GetConn();
            estOuvert = true;
            c.setAutoCommit(false);
        }
```
J'ai ajouté ce bloc : **c'est le cœur de la correction**.
- **`if(c==null)`** : la page ne m'a pas donné de connexion.
- **`c = new UtilDB().GetConn();`** : j'en ouvre une.
- **`estOuvert = true;`** : je note que c'est la mienne. C'est donc moi qui ferai `commit`, `rollback` et `close`.
- **`c.setAutoCommit(false);`** : sans ça, Oracle validerait **chaque requête toute seule**, dès qu'elle est exécutée. Avec `false`, rien n'est enregistré tant que je n'ai pas fait `commit` : la création et la validation de l'avoir deviennent **un seul bloc**.

**Avant**, ce bloc n'existait pas : `c` restait `null` et était passé tel quel à `genererAvoir2`, qui ouvrait alors **sa propre** connexion et faisait **son propre** `commit`. L'avoir était enregistré avant même la validation.

---

**Ligne 1319 :**
```java
        try {
```
J'ai ajouté ce `try` pour pouvoir annuler (`catch`) et fermer (`finally`) quoi qu'il arrive.

---

**Ligne 1320 :**
```java
            // Étape 2 : je refuse d'annuler une vente qui a déjà un avoir (double clic, ou avoir déjà créé par le trigger)
```
Commentaire ajouté pour expliquer la ligne suivante.

---

**Ligne 1321 :**
```java
            if(Vente.aDejaUnAvoir(c, idVente)) throw new Exception("La vente "+idVente+" a deja un avoir : elle ne peut pas etre annulee une deuxieme fois");
```
J'ai ajouté ce **garde-fou** contre les doublons.
- **`Vente.aDejaUnAvoir(c, idVente)`** : ma nouvelle fonction (modification 2), qui dit si la vente a déjà un avoir non annulé. Je lui passe `c` pour lire dans la même transaction.
- **`throw new Exception("...")`** : si oui, j'arrête tout **avant** de créer quoi que ce soit. `apres-annuler.jsp` attrape l'exception et affiche son message dans une fenêtre `alert(...)`.
- **Sans accents dans le message** (`deja`, `etre`, `annulee`) : la page réencode le message (`new String(e.getMessage().getBytes(), "UTF-8")`), et des accents risqueraient de s'afficher mal.

---

**Ligne 1322 :**
```java
            // Étape 3 : je crée l'avoir dans MA transaction (genererAvoir2 ne fait donc pas de commit)
```
Commentaire ajouté.

---

**Ligne 1323 :**
```java
            AvoirFC avoirFC = genererAvoir2(u, c, idVente);
```
Cette ligne existait déjà, mais elle reçoit maintenant **ma** connexion `c` au lieu de `null`.

> **`genererAvoir2`** : elle crée en base un avoir (en-tête + lignes) qui reprend toute la vente.

Comme `c` n'est plus `null`, dans `genererAvoir2` `estOuvert` vaut `false`, donc **`if(estOuvert) c.commit();` ne fait rien** (c'est l'exercice 5 de l'étape 1). L'avoir est inséré, mais **pas encore validé en base** : il attend mon `commit` de la ligne 1329.

---

**Ligne 1324 :**
```java
            // Étape 4 : je donne les lignes à l'avoir là où validerObject les cherche (getFille), sinon NullPointerException
```
Commentaire ajouté.

---

**Ligne 1325 :**
```java
            avoirFC.setFille(avoirFC.getAvoirDetails());
```
J'ai ajouté cette ligne pour corriger le **`NullPointerException`**.

> **`setFille`** (héritée de `bean.ClassMere`, dans `apj-core.jar`) : elle range les lignes d'un objet mère à l'endroit où le framework les cherche (`getFille()`).

- **`avoirFC.getAvoirDetails()`** : les lignes de l'avoir, que `genererAvoir2` a rangées avec `setAvoirDetails(...)`.
- **`avoirFC.setFille(...)`** : je les range **aussi** dans `fille`, là où `AvoirFC.validerObject` les lit (`this.getFille()`, `AvoirFC.java:273`).
- **Avant**, `getFille()` renvoyait `null`, et `avoirFCFille.length` plantait à la ligne 275 de `AvoirFC.java`.
- `VenteArbiochem.java:232` fait déjà `avoir.setFille(...)` avant `avoir.validerObject(...)`. Je reprends la même habitude.

---

**Ligne 1326 :**
```java
            // Étape 5 : je valide l'avoir dans la même transaction
```
Commentaire ajouté.

---

**Ligne 1327 :**
```java
            avoirFC.validerObject(u, c);
```
Cette ligne existait déjà, mais elle reçoit maintenant **ma** connexion.

> **`AvoirFC.validerObject`** : elle valide un avoir (état 11) et génère ce qui va avec : mise à jour du plan de paiement, écriture comptable, lettrage.

Comme elle reçoit une connexion, elle **ne fait pas** de `commit` (`if(estOuvert==true)c.commit();` dans `AvoirFC.java`). Tout reste en attente de mon `commit`.

---

**Ligne 1328 :**
```java
            // Étape 6 : tout s'est bien passé : je valide la création ET la validation ensemble
```
Commentaire ajouté.

---

**Ligne 1329 :**
```java
            if(estOuvert) c.commit();
```
J'ai ajouté cette ligne : **un seul `commit`**, pour l'avoir, ses lignes, sa validation et son écriture comptable **ensemble**.
- **`if(estOuvert)`** : règle d'or. Si un appelant m'a donné sa connexion, c'est lui qui fera le `commit`.

---

**Ligne 1330 :**
```java
            System.out.println("avoir généré");
```
Ligne déjà présente. Je l'ai gardée, mais placée **après** le `commit` : le message n'apparaît dans le log que si tout a vraiment réussi.

---

**Lignes 1331 à 1334 :**
```java
        } catch (Exception e) {
            // En cas d'erreur : j'annule tout, l'avoir ne reste pas en base
            if(estOuvert) c.rollback();
            throw e;
```
J'ai ajouté ce bloc.
- **`catch (Exception e)`** : n'importe quelle erreur, que ce soit le garde-fou de la ligne 1321, une erreur dans `genererAvoir2` ou une erreur dans `validerObject`.
- **`if(estOuvert) c.rollback();`** : j'annule **tout** ce qui a été fait dans ma transaction. **Avant**, l'avoir restait en base après le `NullPointerException` ; maintenant, il disparaît.
- **`throw e;`** : je renvoie l'erreur à la page, pour qu'elle affiche le message à l'utilisateur.

---

**Lignes 1335 à 1338 :**
```java
        } finally {
            // Je referme la connexion seulement si c'est moi qui l'ai ouverte
            if(estOuvert) c.close();
        }
```
J'ai ajouté ce bloc. Il s'exécute dans tous les cas, succès ou erreur. Je ferme la connexion **seulement si c'est la mienne** (règle d'or).

---

**Ligne 1339 :**
```java
    }
```
Fin de la fonction.

---

## Modification 2 : ajout de `aDejaUnAvoir(Connection c, String idVente)`

> **Ce que fait la fonction :** elle dit si la vente a déjà au moins un avoir non annulé.

**Où :** classe `vente.Vente`, lignes **1341 à 1345**, juste après `annulerFacture`.

**Avant :** la fonction n'existait pas.

**Après :**

```java
    // Je dis si la vente a déjà au moins un avoir non annulé
    public static boolean aDejaUnAvoir(Connection c, String idVente) throws Exception{
        AvoirFC[] avoirs = (AvoirFC[]) CGenUtil.rechercher(new AvoirFC(), null, null, c, " and idVente='"+idVente+"' and etat <> 0");
        return avoirs.length > 0;
    }
```

### Explication ligne par ligne

**Ligne 1340 :** ligne vide, pour séparer les deux fonctions.

---

**Ligne 1341 :**
```java
    // Je dis si la vente a déjà au moins un avoir non annulé
```
J'ai ajouté ce commentaire pour définir la fonction en une phrase.

---

**Ligne 1342 :**
```java
    public static boolean aDejaUnAvoir(Connection c, String idVente) throws Exception{
```
J'ai déclaré la fonction.
- **`static`** : elle n'a besoin que de l'id de la vente, pas d'un objet `Vente`. C'est le même style qu'`annulerFacture`, qui l'appelle.
- **`boolean`** : la réponse est oui ou non.
- **`aDejaUnAvoir`** : le nom se lit comme une question (« a déjà un avoir ? »), ce qui rend le `if` de la ligne 1321 lisible.
- **`Connection c`** : je lis dans la transaction de l'appelant. Si `c` vaut `null`, `CGenUtil.rechercher` ouvre et ferme sa propre connexion (leçon 2). Je n'ai donc pas besoin de bloc `estOuvert` ici.

---

**Ligne 1343 :**
```java
        AvoirFC[] avoirs = (AvoirFC[]) CGenUtil.rechercher(new AvoirFC(), null, null, c, " and idVente='"+idVente+"' and etat <> 0");
```
Je cherche les avoirs de la vente.
- **`new AvoirFC()`** : un modèle **neuf** (règle d'or 3 de la leçon 2). Il lit la **table** `AVOIRFC`. Je n'ai pas besoin des montants calculés de la vue *Lib* : je veux seulement savoir s'il **existe** un avoir (règle d'or 2).
- **`" and idVente='...'"`** : les avoirs de **cette** vente.
- **`" and etat <> 0"`** : sauf les avoirs **annulés** (état 0). Un avoir annulé ne rembourse plus rien : il ne doit pas empêcher une nouvelle annulation.

---

**Ligne 1344 :**
```java
        return avoirs.length > 0;
```
S'il y a au moins un avoir, je renvoie `true`, sinon `false`.

---

**Ligne 1345 :**
```java
    }
```
Fin de la fonction.

---

## Résultat, vu depuis l'écran

| situation | avant | après |
|---|---|---|
| 1er clic sur « Annuler » | avoir enregistré, puis 💥 `NullPointerException` | avoir créé **et validé**, retour sur la fiche |
| 2e clic sur « Annuler » | un **2e avoir** (crédit fantôme), puis 💥 | message : « La vente … a deja un avoir : elle ne peut pas etre annulee une deuxieme fois » |
| erreur pendant la validation | l'avoir restait en base | **rien** ne reste en base |
