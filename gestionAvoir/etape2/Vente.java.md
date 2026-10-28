# `arbiochem-ejb/src/java/vente/Vente.java` — Étape 2

## Modification 1 : ajout de `getMontantAvoirDisponible(Connection c)`

**Où :** classe `vente.Vente`, lignes **1543 à 1564**. Je l'ai placée juste **avant** `genererPaiementFactureParAvoir(...)`, parce que cette méthode utilise la même vue (`AVOIRFCLIB_CPL`). Les deux sont ainsi rangées ensemble.

**Avant :** la méthode n'existait pas.

**Après :**

```java
    // Je calcule le montant d'avoir que le client de cette vente peut encore utiliser (0 s'il n'en a pas)
    public double getMontantAvoirDisponible(Connection c) throws Exception{
        // Étape 1 : sans client, il ne peut pas y avoir d'avoir
        if(this.getIdClient()==null || this.getIdClient().isEmpty()) return 0;
        boolean estOuvert = false;
        // Étape 2 : si on ne m'a pas donné de connexion, j'en ouvre une moi-même, sinon j'utilise celle de l'appelant
        if(c==null){
            c = new UtilDB().GetConn();
            estOuvert = true;
        }
        try {
            // Étape 3 : je cherche les avoirs du client qui ont encore un reste à utiliser
            AvoirFCLib t = new AvoirFCLib();
            t.setNomTable("AVOIRFCLIB_CPL");
            AvoirFCLib[] avoirs = (AvoirFCLib[]) CGenUtil.rechercher(t,null,null,c," AND idClient='"+this.getIdClient()+"' and resteapayerar > 0");
            // Étape 4 : je fais la somme de ces restes
            return AdminGen.calculSommeDouble(avoirs,"resteapayerar");
        } finally {
            // Je referme la connexion seulement si c'est moi qui l'ai ouverte
            if(estOuvert) c.close();
        }
    }
```

**Imports :** je n'en ai ajouté aucun. `AvoirFCLib` (ligne 11), `AdminGen` (ligne 12), `CGenUtil` (ligne 13), `Connection` (ligne 24) et `UtilDB` (ligne 59) étaient déjà importés en haut de `Vente.java`.

---

## Explication ligne par ligne

**Ligne 1543 :**
```java
    // Je calcule le montant d'avoir que le client de cette vente peut encore utiliser (0 s'il n'en a pas)
```
J'ai ajouté ce commentaire pour dire en une phrase **à quoi sert** la méthode, et surtout ce qu'elle renvoie quand il n'y a pas d'avoir (`0`).

---

**Ligne 1544 :**
```java
    public double getMontantAvoirDisponible(Connection c) throws Exception{
```
J'ai déclaré la méthode.
- **`public`** : elle doit pouvoir être appelée depuis une JSP ou une autre classe (par exemple la fiche de la vente).
- **pas de `static`** : c'est une méthode **d'instance**. Elle répond à une question sur **cette** vente (`this`) : « combien d'avoir a son client ? ». Je l'appellerai donc comme ça : `maVente.getMontantAvoirDisponible(c)`.
- **`double`** : elle renvoie un montant. J'utilise `double` comme le reste du projet (`getResteapayerar()` renvoie aussi un `double`).
- **`getMontantAvoirDisponible`** : le préfixe `get` dit qu'elle **lit** une information, sans rien modifier.
- **`Connection c`** : la connexion à utiliser. Si l'appelant est déjà dans une transaction, il me la passe ; sinon il passe `null` (voir lignes 1549-1552).
- **`throws Exception`** : si la base ne répond pas, je laisse l'erreur remonter à l'appelant. C'est à lui de décider quoi en faire.
- **`{`** : ouvre le corps de la méthode.

---

**Ligne 1545 :**
```java
        // Étape 1 : sans client, il ne peut pas y avoir d'avoir
```
J'ai ajouté ce commentaire pour expliquer le test de la ligne suivante.

---

**Ligne 1546 :**
```java
        if(this.getIdClient()==null || this.getIdClient().isEmpty()) return 0;
```
J'ai ajouté cette ligne pour **sortir tout de suite** quand la vente n'a pas de client.
- **`this.getIdClient()`** : l'identifiant du client de cette vente (par exemple `CLIA2625`).
- **`== null`** : la vente n'a pas encore de client. Sans ce test, la requête deviendrait `idClient='null'`, ce qui est inutile.
- **`||`** (« ou ») : Java s'arrête au premier test vrai. Si `getIdClient()` est `null`, il **n'évalue pas** `.isEmpty()`, ce qui évite une `NullPointerException`. C'est la même idée que `ancienne != null && ...` dans l'exercice 3 de l'étape 1.
- **`.isEmpty()`** : le client est une chaîne vide `""`.
- **`return 0;`** : pas de client, donc pas d'avoir. Je renvoie `0` sans même ouvrir de connexion.

---

**Ligne 1547 :**
```java
        boolean estOuvert = false;
```
J'ai ajouté cette variable pour me souvenir si **c'est moi** qui ouvre la connexion. Elle vaut `false` au départ : par défaut, je suppose que la connexion vient de l'appelant. C'est le même nom et la même idée que dans `genererAvoir2` (règle d'or de l'exercice 5).

---

**Ligne 1548 :**
```java
        // Étape 2 : si on ne m'a pas donné de connexion, j'en ouvre une moi-même, sinon j'utilise celle de l'appelant
```
J'ai ajouté ce commentaire pour expliquer le bloc qui suit.

---

**Ligne 1549 :**
```java
        if(c==null){
```
J'ai ajouté ce test : l'appelant ne m'a pas donné de connexion. C'est le cas typique d'une JSP qui veut juste **afficher** le montant.

---

**Ligne 1550 :**
```java
            c = new UtilDB().GetConn();
```
J'ouvre ma propre connexion à Oracle, avec l'outil du projet `UtilDB`, comme partout ailleurs dans `Vente.java`.

**Pourquoi je ne fais pas `c.setAutoCommit(false);` ici, contrairement à `genererAvoir2` :** ma méthode ne fait **que lire** (`select`). Elle n'écrit rien, donc il n'y a rien à valider ni à annuler. Pas de `commit`, pas de `rollback`.

---

**Ligne 1551 :**
```java
            estOuvert = true;
```
Je note que **c'est moi** qui ai ouvert la connexion, donc **c'est moi** qui devrai la fermer (ligne 1562).

---

**Ligne 1552 :**
```java
        }
```
Fin du `if(c==null)`.

---

**Ligne 1553 :**
```java
        try {
```
J'ouvre un bloc `try`, pour être **sûre** que la connexion sera fermée dans le `finally` (ligne 1560), même si la requête plante.

Je n'ai **pas** mis de `catch` : je ne sais pas quoi faire d'une erreur ici, donc je la laisse remonter à l'appelant (grâce au `throws Exception` de la ligne 1544). Le `finally` s'exécute quand même avant.

---

**Ligne 1554 :**
```java
            // Étape 3 : je cherche les avoirs du client qui ont encore un reste à utiliser
```
J'ai ajouté ce commentaire pour expliquer les trois lignes suivantes.

---

**Ligne 1555 :**
```java
            AvoirFCLib t = new AvoirFCLib();
```
Je crée un objet `AvoirFCLib` **vide**. Il ne représente aucun avoir précis : il sert de **modèle de recherche** pour `CGenUtil.rechercher`, qui en déduit quelle table lire et quels objets fabriquer.

J'utilise `AvoirFCLib` (et pas `AvoirFC`) parce que c'est cette classe qui a l'attribut `resteapayerar` ([AvoirFCLib.java:35](../../arbiochem-ejb/src/java/avoir/AvoirFCLib.java#L35)).

---

**Ligne 1556 :**
```java
            t.setNomTable("AVOIRFCLIB_CPL");
```
Je dis à la recherche de lire la **vue** `AVOIRFCLIB_CPL`. C'est elle qui calcule la colonne `RESTEAPAYERAR`, ce qui reste vraiment utilisable dans chaque avoir (voir [00_vue_ensemble.md](00_vue_ensemble.md), partie 3). C'est la même vue que celle utilisée par `genererPaiementFactureParAvoirAutom` au moment de la consommation réelle : l'affichage et la consommation seront donc d'accord.

---

**Ligne 1557 :**
```java
            AvoirFCLib[] avoirs = (AvoirFCLib[]) CGenUtil.rechercher(t,null,null,c," AND idClient='"+this.getIdClient()+"' and resteapayerar > 0");
```
J'ai ajouté cette ligne pour **lire en base** les avoirs disponibles du client.
- **`CGenUtil.rechercher(...)`** : la méthode de recherche générique du framework APJ. Elle construit et exécute `select * from AVOIRFCLIB_CPL where 1<2 ...`.
- **`t`** : le modèle de recherche (lignes 1555-1556).
- **`null, null`** : je n'utilise pas les deux tableaux de critères (noms de colonnes et valeurs). Je donne mes conditions directement dans la chaîne SQL, à la fin.
- **`c`** : la connexion (celle de l'appelant, ou la mienne).
- **`" AND idClient='...'"`** : seulement les avoirs **de ce client**.
- **`" and resteapayerar > 0"`** : seulement ceux qui ont **encore un reste**. Un avoir déjà entièrement utilisé, ou qui ne fait qu'annuler une vente jamais payée, a un reste de `0` : il ne compte pas.
- **`(AvoirFCLib[])`** : `rechercher` renvoie un tableau générique `Object[]`, je le convertis en tableau d'`AvoirFCLib`.
- **`AvoirFCLib[] avoirs`** : le résultat, de 0 à plusieurs avoirs.

Requête réellement exécutée (vue dans le test) :
```sql
select * from AVOIRFCLIB_CPL where 1<2  AND idClient='CLIA0935' and resteapayerar > 0
```

---

**Ligne 1558 :**
```java
            // Étape 4 : je fais la somme de ces restes
```
J'ai ajouté ce commentaire pour expliquer la ligne suivante.

---

**Ligne 1559 :**
```java
            return AdminGen.calculSommeDouble(avoirs,"resteapayerar");
```
J'ai ajouté cette ligne pour **additionner** les restes de tous les avoirs trouvés et renvoyer le total.
- **`AdminGen.calculSommeDouble(tableau, "nomAttribut")`** : outil du framework qui parcourt le tableau et additionne l'attribut demandé de chaque objet. Le code existant l'utilise déjà de la même façon (`genererPaiementFactureParAvoir`). J'évite ainsi d'écrire une boucle `for` moi-même.
- **`"resteapayerar"`** : l'attribut à additionner.
- **Si le tableau est vide** (pas d'avoir disponible), la somme vaut **`0`**. C'est la route « pas d'avoir », sans cas particulier à écrire.
- **`return`** : je renvoie le total. Le `finally` s'exécute **avant** que la valeur arrive à l'appelant, donc la connexion est bien fermée.

---

**Ligne 1560 :**
```java
        } finally {
```
Fin du `try`, début du `finally`. Ce bloc s'exécute **dans tous les cas** : après le `return` de la ligne 1559, ou si une exception a été levée.

---

**Ligne 1561 :**
```java
            // Je referme la connexion seulement si c'est moi qui l'ai ouverte
```
J'ai ajouté ce commentaire pour rappeler la règle d'or d'APJ.

---

**Ligne 1562 :**
```java
            if(estOuvert) c.close();
```
Je ferme la connexion **seulement si c'est moi qui l'ai ouverte** (ligne 1551).
- Si je l'ai ouverte et que je ne la ferme pas, la connexion reste ouverte pour rien, et Oracle finit par refuser les nouvelles connexions.
- Si elle vient de l'appelant et que je la ferme, je casse sa transaction : il ne pourrait plus faire son `UPDATE`, son `commit`… C'est la même règle que l'exercice 5 de l'étape 1, mais pour `close` au lieu de `commit`.

---

**Ligne 1563 :**
```java
        }
```
Fin du `finally`.

---

**Ligne 1564 :**
```java
    }
```
Fin de la méthode `getMontantAvoirDisponible`.

---

## Comment l'utiliser

```java
Vente vente = Vente.getById(null, "VNT...");
double avoir = vente.getMontantAvoirDisponible(null);   // null : la méthode ouvre et ferme sa connexion
if (avoir == 0) {
    // route 1 : pas d'avoir -> achat normal
} else {
    // route 2 : le client a "avoir" de crédit à déduire de son reste à payer
}
```

---
---

## Modification 2 : ajout de `getMontantAPayerApresAvoir(Connection c)`

**Où :** classe `vente.Vente`, lignes **1565 à 1585**. Je l'ai placée juste **après** `getMontantAvoirDisponible(...)`, parce qu'elle l'utilise : les deux méthodes de l'étape 2 sont ainsi l'une sous l'autre.

**Avant :** la méthode n'existait pas.

**Après :**

```java
    // Je calcule ce que le client devra encore payer pour cette vente une fois son avoir utilisé (jamais négatif)
    public double getMontantAPayerApresAvoir(Connection c) throws Exception{
        boolean estOuvert = false;
        // Étape 1 : si on ne m'a pas donné de connexion, j'en ouvre une moi-même, sinon j'utilise celle de l'appelant
        if(c==null){
            c = new UtilDB().GetConn();
            estOuvert = true;
        }
        try {
            // Étape 2 : je relis cette vente dans la vue VENTE_CPL pour avoir son reste à payer à jour
            VenteLib vente = (VenteLib) new VenteLib().getById(this.getId(), "", c);
            if(vente==null) throw new Exception("La vente "+this.getId()+" n'existe pas");
            // Étape 3 : je récupère l'avoir disponible du client avec la première méthode, sur la même connexion
            double avoir = vente.getMontantAvoirDisponible(c);
            // Étape 4 : je retire l'avoir du reste à payer, sans descendre en dessous de 0
            return Math.max(0, vente.getMontantreste() - avoir);
        } finally {
            // Je referme la connexion seulement si c'est moi qui l'ai ouverte
            if(estOuvert) c.close();
        }
    }
```

**Imports :** je n'en ai ajouté aucun. `VenteLib` est dans le **même package** (`vente`) que `Vente` : Java la trouve sans `import`. `Connection` et `UtilDB` étaient déjà importés. `Math` fait partie de `java.lang`, qui est toujours importé automatiquement.

### Pourquoi le « reste à payer » et pas le « montant TTC »

Dans la vue d'ensemble, j'avais noté `max(0, montant TTC - avoir)`. En écrivant la méthode, j'ai choisi le **reste à payer** (`montantreste`) à la place :

| avec le montant TTC | avec le reste à payer |
|---|---|
| si le client a déjà payé une partie, je lui redemande **tout** | je ne compte que ce qu'il doit **encore** |
| ne correspond pas à ce que fera la validation | c'est exactement le montant que `genererPaiementFactureParAvoirAutom` utilise (`vente.getMontantreste()`) |

Pour une vente que personne n'a encore payée, les deux sont égaux. La différence n'apparaît que si un paiement partiel existe déjà.

> 📚 Le cast `(VenteLib)`, l'héritage et `Math.max` sont expliqués en détail dans [apprentissageAPJ/lecon3/01_cast_heritage_math_max.md](../../apprentissageAPJ/lecon3/01_cast_heritage_math_max.md).

---

## Explication ligne par ligne

**Ligne 1565 :**
```java
    // Je calcule ce que le client devra encore payer pour cette vente une fois son avoir utilisé (jamais négatif)
```
J'ai ajouté ce commentaire pour dire en une phrase **à quoi sert** la méthode, et préciser qu'elle ne renvoie **jamais** un nombre négatif.

---

**Ligne 1566 :**
```java
    public double getMontantAPayerApresAvoir(Connection c) throws Exception{
```
J'ai déclaré la méthode.
- **`public`** : comme la première méthode, elle doit pouvoir être appelée depuis une JSP (la fiche de la vente).
- **pas de `static`** : méthode **d'instance**. Elle répond à une question sur **cette** vente : « combien reste-t-il à payer une fois l'avoir utilisé ? ». Elle utilise `this.getId()`.
- **`double`** : elle renvoie un montant, comme `getMontantAvoirDisponible`.
- **`getMontantAPayerApresAvoir`** : le préfixe `get` dit qu'elle **lit** seulement, elle ne crée aucun paiement.
- **`Connection c`** : la connexion de l'appelant, ou `null` pour que la méthode ouvre la sienne.
- **`throws Exception`** : si la base ne répond pas ou si la vente n'existe pas (ligne 1576), l'erreur remonte à l'appelant.
- **`{`** : ouvre le corps de la méthode.

---

**Ligne 1567 :**
```java
        boolean estOuvert = false;
```
J'ai ajouté cette variable pour me souvenir si **c'est moi** qui ouvre la connexion. Même nom et même rôle que dans `getMontantAvoirDisponible` et `genererAvoir2`.

**Pourquoi je ne teste pas l'id du client ici, contrairement à la première méthode :** je ne connais le client qu'**après** avoir relu la vente (ligne 1575). Et de toute façon, c'est `getMontantAvoirDisponible` (ligne 1578) qui fait ce test : s'il n'y a pas de client, elle renvoie `0`, et le résultat est simplement le reste à payer.

---

**Ligne 1568 :**
```java
        // Étape 1 : si on ne m'a pas donné de connexion, j'en ouvre une moi-même, sinon j'utilise celle de l'appelant
```
J'ai ajouté ce commentaire pour expliquer le bloc qui suit.

---

**Ligne 1569 :**
```java
        if(c==null){
```
J'ai ajouté ce test : l'appelant ne m'a pas donné de connexion (cas typique d'une JSP qui veut juste afficher le montant).

---

**Ligne 1570 :**
```java
            c = new UtilDB().GetConn();
```
J'ouvre ma propre connexion à Oracle avec `UtilDB`.

Comme pour la première méthode, je ne fais **pas** `c.setAutoCommit(false);` : je ne fais que **lire**, il n'y a rien à valider ni à annuler.

---

**Ligne 1571 :**
```java
            estOuvert = true;
```
Je note que **c'est moi** qui ai ouvert la connexion, donc **c'est moi** qui la fermerai (ligne 1583).

---

**Ligne 1572 :**
```java
        }
```
Fin du `if(c==null)`.

---

**Ligne 1573 :**
```java
        try {
```
J'ouvre un bloc `try` pour être **sûre** que le `finally` (ligne 1581) ferme la connexion, même si une erreur arrive. Pas de `catch` : je laisse l'erreur remonter à l'appelant.

---

**Ligne 1574 :**
```java
            // Étape 2 : je relis cette vente dans la vue VENTE_CPL pour avoir son reste à payer à jour
```
J'ai ajouté ce commentaire pour expliquer les deux lignes suivantes.

---

**Ligne 1575 :**
```java
            VenteLib vente = (VenteLib) new VenteLib().getById(this.getId(), "", c);
```
J'ai ajouté cette ligne pour **relire la vente en base**, avec son reste à payer.
- **Pourquoi relire, alors que j'ai déjà `this` ?** Un objet `Vente` ne contient que les colonnes de la **table** `VENTE`. Le reste à payer (`montantreste`) n'est pas stocké dans la table : il est **calculé** par la **vue** `VENTE_CPL` (montant TTC − ce qui a déjà été payé). Il faut donc passer par cette vue.
- **`new VenteLib()`** : `VenteLib` est la classe qui a l'attribut `montantreste` ([VenteLib.java:51](../../arbiochem-ejb/src/java/vente/VenteLib.java#L51)). Son constructeur fait déjà `setNomTable("VENTE_CPL")` ([VenteLib.java:248](../../arbiochem-ejb/src/java/vente/VenteLib.java#L248)) : je n'ai pas besoin de l'écrire.
- **`.getById(this.getId(), "", c)`** : méthode du framework (héritée de `ClassMAPTable`) qui lit **une** ligne par son id.
  - `this.getId()` : l'id de cette vente.
  - `""` : nom de table vide, donc le framework garde celle de l'objet (`VENTE_CPL`). C'est exactement l'appel que fait déjà `VenteArbiochem.validerObject` ([VenteArbiochem.java:259](../../arbiochem-ejb/src/java/vente/VenteArbiochem.java#L259)).
  - `c` : la connexion.
- **`(VenteLib)`** : `getById` renvoie un objet générique, je le convertis en `VenteLib`.
- **`VenteLib vente`** : la vente relue, avec `montantreste` et `idClient` remplis.

---

**Ligne 1576 :**
```java
            if(vente==null) throw new Exception("La vente "+this.getId()+" n'existe pas");
```
J'ai ajouté cette ligne pour le cas où l'id ne correspond à **aucune** vente : `getById` renvoie alors `null`.
- Sans ce test, la ligne 1578 ferait `null.getMontantAvoirDisponible(c)` : une `NullPointerException`, avec un message incompréhensible.
- Avec ce test, l'appelant reçoit un message clair. Je l'ai vérifié : `La vente VNT_INEXISTANTE n'existe pas`.
- Je lance une **exception** plutôt que de renvoyer `0` : `0` voudrait dire « le client n'a rien à payer », ce qui serait **faux** et dangereux.

---

**Ligne 1577 :**
```java
            // Étape 3 : je récupère l'avoir disponible du client avec la première méthode, sur la même connexion
```
J'ai ajouté ce commentaire pour expliquer la ligne suivante.

---

**Ligne 1578 :**
```java
            double avoir = vente.getMontantAvoirDisponible(c);
```
J'ai ajouté cette ligne pour **réutiliser** la première méthode de l'étape 2, au lieu de réécrire la recherche des avoirs.
- **`vente.`** (et pas `this.`) : j'appelle la méthode sur la vente **relue en base**. Son `idClient` vient donc de la base. `this` pourrait n'avoir que l'id rempli (par exemple si on a fait `new Vente()` puis `setId(...)`), et son client serait `null`. Cela marche parce que `VenteLib` **hérite** de `Vente` : elle a donc la méthode `getMontantAvoirDisponible`.
- **`(c)`** : je passe **ma** connexion (celle de l'appelant, ou celle que j'ai ouverte). Comme elle n'est pas `null`, `getMontantAvoirDisponible` ne l'ouvre pas et **ne la ferme pas** (son `estOuvert` reste `false`). C'est la règle d'or : une seule connexion, fermée une seule fois, par celui qui l'a ouverte.
- **`double avoir`** : le total d'avoir disponible du client, `0` s'il n'en a pas.

---

**Ligne 1579 :**
```java
            // Étape 4 : je retire l'avoir du reste à payer, sans descendre en dessous de 0
```
J'ai ajouté ce commentaire pour expliquer la ligne suivante.

---

**Ligne 1580 :**
```java
            return Math.max(0, vente.getMontantreste() - avoir);
```
J'ai ajouté cette ligne pour calculer et **renvoyer** le montant final.
- **`vente.getMontantreste()`** : ce que le client doit encore sur cette vente.
- **`- avoir`** : je retire son avoir disponible.
- **`Math.max(0, ...)`** : je garde le plus grand des deux nombres. Si l'avoir est **plus grand** que le reste, la soustraction est négative, et je renvoie `0` : le client n'a plus rien à payer. Il ne faut pas renvoyer « −22 020 », ce n'est pas un montant à payer. Ce qui dépasse **reste dans l'avoir** pour un prochain achat : c'est la même logique que le `Math.min(montantTotalReste, montantFacture)` de `genererPaiementFactureParAvoirAutom`, qui ne consomme jamais plus que la facture.
- **Les deux routes de l'étape 2 :**
  - pas d'avoir : `avoir = 0`, le résultat est le reste à payer normal ;
  - avoir disponible : le résultat est diminué de l'avoir.
- **`return`** : le `finally` s'exécute avant que la valeur arrive à l'appelant.

---

**Ligne 1581 :**
```java
        } finally {
```
Fin du `try`, début du `finally` : il s'exécute **dans tous les cas** (après le `return`, ou après l'exception de la ligne 1576).

---

**Ligne 1582 :**
```java
            // Je referme la connexion seulement si c'est moi qui l'ai ouverte
```
J'ai ajouté ce commentaire pour rappeler la règle d'or d'APJ.

---

**Ligne 1583 :**
```java
            if(estOuvert) c.close();
```
Je ferme la connexion **seulement si c'est moi qui l'ai ouverte** (ligne 1571). Même raisonnement que la ligne 1562 de la première méthode.

---

**Ligne 1584 :**
```java
        }
```
Fin du `finally`.

---

**Ligne 1585 :**
```java
    }
```
Fin de la méthode `getMontantAPayerApresAvoir`.

---

## Comment utiliser les deux méthodes ensemble

```java
Vente vente = new Vente();
vente.setId("VNT...");
double avoir = vente.getMontantAvoirDisponible(null);     // attention : ici le client doit être rempli (voir ci-dessous)
double aPayer = vente.getMontantAPayerApresAvoir(null);   // l'id suffit : la méthode relit la vente elle-même
```

> `getMontantAvoirDisponible` a besoin que `idClient` soit rempli dans l'objet. Si tu n'as que l'id, récupère d'abord la vente avec `Vente.getById(c, id)`. `getMontantAPayerApresAvoir`, elle, n'a besoin que de l'id.
