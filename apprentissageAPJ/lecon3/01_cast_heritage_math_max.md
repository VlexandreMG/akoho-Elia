# Leçon 3 : le cast, l'héritage et `Math.max` (`getMontantAPayerApresAvoir`)

> Objectif : comprendre trois lignes de la méthode `Vente.getMontantAPayerApresAvoir(...)` de l'étape 2 de la gestion d'avoir :
>
> ```java
> VenteLib vente = (VenteLib) new VenteLib().getById(this.getId(), "", c);   // étape 2 : le cast
> double avoir = vente.getMontantAvoirDisponible(c);                          // étape 3 : l'héritage
> return Math.max(0, vente.getMontantreste() - avoir);                        // étape 4 : Math.max
> ```

## Comment j'ai obtenu ces informations

- J'ai désassemblé `getById` avec `javap`, comme dans les leçons 1 et 2 :

```bash
javap -c -cp build-file/lib/apj-core.jar bean.ClassMAPTable     # le code de getById
javap -cp build-file/lib/apj-core.jar bean.ClassMere bean.ClassEtat bean.ClassUser   # qui hérite de qui
```

- J'ai lancé un petit test jetable (hors projet, en lecture seule) qui affiche la **vraie** classe de l'objet renvoyé par `getById`, et le résultat de `Math.max` sur plusieurs cas. Les résultats sont recopiés plus bas.

---

## 1. Ce que renvoie vraiment `getById`

### Une idée fausse à corriger d'abord

On pourrait croire : « `getById` renvoie une `Vente`, et je la transforme en `VenteLib` avec le cast ». **Ce n'est pas ça.**

Deux choses sont vraies en même temps :
1. **Le type écrit** (ce que voit le compilateur) : `getById` est déclarée dans `bean.ClassMAPTable` comme ceci :
   ```java
   public ClassMAPTable getById(String id, String nomTable, Connection c)
   ```
   Elle renvoie donc officiellement un **`ClassMAPTable`**, la classe la plus générale d'APJ. Ni `Vente`, ni `VenteLib`.
2. **Le vrai objet** (ce qui existe en mémoire) : c'est déjà une **`VenteLib`**.

### Pourquoi c'est déjà une `VenteLib`

Dans le bytecode de `getById`, on voit qu'elle fait (en résumé) :

```java
this.setTuppleId(id);                                                      // je cherche cet id
ClassMAPTable[] res = (ClassMAPTable[]) CGenUtil.rechercher(this, null, null, c, "");   // "this" sert de modèle
return res.length > 0 ? res[0] : null;
```

Elle passe **`this`** comme modèle de recherche à `CGenUtil.rechercher`. Et `rechercher` fabrique des objets **de la même classe que le modèle** (elle fait `Class.forName(modele.getClassName()).newInstance()`, voir [leçon 2, partie 3](../lecon2/01_lire_en_base.md)).

Or, dans ma ligne, `this` à l'intérieur de `getById`, c'est l'objet créé par `new VenteLib()`. Donc :
- `rechercher` fabrique une **`VenteLib`** ;
- elle lit la table du modèle, `VENTE_CPL` (mise par le constructeur de `VenteLib`) ;
- elle la remplit avec la ligne trouvée, y compris `montantreste`.

**C'est le `new VenteLib()` qui décide de la vraie classe, pas le cast.**

### Ce que j'ai vérifié par le test

```
new VenteLib().getById(...)  -> Vraie classe : vente.VenteLib     | Table : VENTE_CPL
                                instanceof Vente ? true | instanceof VenteLib ? true
new Vente().getById(...)     -> Vraie classe : vente.Vente
(VenteLib) sur ce 2e objet   -> ClassCastException
```

Le dernier cas est important : si j'avais écrit `new Vente().getById(...)`, le vrai objet serait une simple `Vente`, et le cast `(VenteLib)` **planterait** à l'exécution.

### Alors, à quoi sert le cast `(VenteLib)` ?

Le cast **ne transforme rien**. Il ne crée pas d'objet, il ne copie rien, il n'ajoute aucun attribut.

Il sert seulement à **rassurer le compilateur** : « je sais que cet objet, déclaré `ClassMAPTable`, est en réalité une `VenteLib` ». Sans le cast :

```java
VenteLib vente = new VenteLib().getById(this.getId(), "", c);
// erreur de compilation : incompatible types: ClassMAPTable cannot be converted to VenteLib
```

Le compilateur ne regarde que le type **écrit** (`ClassMAPTable`). Il ne sait pas ce qui se passera à l'exécution, donc il refuse. Avec le cast, il accepte, et Java **vérifie à l'exécution** que l'objet est bien une `VenteLib`. Si ce n'est pas le cas : `ClassCastException`.

> Image : le cast, c'est mettre une étiquette sur une boîte fermée. L'étiquette ne change pas ce qu'il y a dedans. Si je colle « VenteLib » sur une boîte qui contient une simple `Vente`, Java ouvre la boîte, voit que c'est faux, et lève une `ClassCastException`.

---

## 2. Pourquoi je peux appeler `getMontantAvoirDisponible` sur une `VenteLib`

### Oui : c'est grâce à l'héritage

`getMontantAvoirDisponible` est écrite dans **`Vente`**. Je l'appelle pourtant sur une variable de type **`VenteLib`**. Ça marche parce que :

```java
public class VenteLib extends Vente implements ClassIA {   // VenteLib.java, ligne 17
```

`extends Vente` veut dire : **une `VenteLib` EST une `Vente`**, avec des choses en plus. Elle reçoit (hérite) **tous** les attributs et **toutes** les méthodes `public` et `protected` de `Vente`, dont :
- l'attribut `idClient` et sa méthode `getIdClient()` ;
- ma méthode `getMontantAvoirDisponible(Connection c)`.

Et elle ajoute ses propres attributs, calculés par la vue : `montantpaye`, `montantreste`, `montantTtcAr`…

### La chaîne d'héritage complète

```
bean.ClassMAPTable        <- getById, setNomTable          (APJ, dans apj-core.jar)
   └─ bean.ClassUser
        └─ bean.ClassEtat
             └─ bean.ClassMere
                  └─ vente.FactureCF        <- montantttc, daty...
                       └─ vente.Vente       <- idClient, getMontantAvoirDisponible, getMontantAPayerApresAvoir
                            └─ vente.VenteLib   <- montantreste, montantpaye   (table : VENTE_CPL)
```

Une classe hérite de **toute** la chaîne au-dessus d'elle. C'est pour ça que :
- `new VenteLib().getById(...)` marche : `getById` vient de `ClassMAPTable`, tout en haut ;
- `vente.getMontantAvoirDisponible(c)` marche : la méthode vient de `Vente`, juste au-dessus ;
- `vente.getMontantreste()` marche : la méthode est dans `VenteLib` elle-même.

L'inverse **ne marche pas** : une `Vente` n'a pas `getMontantreste()`. L'héritage descend, il ne remonte pas.

### Ce qui se passe quand j'appelle la méthode sur `vente`

Quand Java exécute `vente.getMontantAvoirDisponible(c)`, il exécute le code écrit dans `Vente`, mais **`this` désigne l'objet `vente`** (la `VenteLib` relue en base). Donc, dans la méthode :
- `this.getIdClient()` renvoie le client **lu en base** dans `VENTE_CPL` ;
- et non le client de l'objet de départ, qui pouvait être vide (par exemple si on avait juste fait `new Vente()` puis `setId(...)`).

C'est **la vraie raison** pour laquelle j'appelle la méthode sur `vente` et pas sur `this` : `vente` a des données complètes et sûres.

### Pourquoi ne pas avoir tout fait dans `Vente`, sans `VenteLib` ?

Parce que `montantreste` n'existe pas dans la **table** `VENTE`. Il est **calculé** par la **vue** `VENTE_CPL`, et seule `VenteLib` a l'attribut pour le recevoir. C'est la règle d'or 2 de la leçon 2 : **on lit avec la *Lib*, on écrit avec la table.**

---

## 3. `Math.max(a, b)` : garder le plus grand des deux

### Ce que fait la fonction

`Math.max(a, b)` renvoie **le plus grand** des deux nombres. C'est tout.

```java
Math.max(3, 7)     // 7
Math.max(7, 3)     // 7   (l'ordre ne compte pas)
Math.max(5, 5)     // 5
```

- **`Math`** : une classe de Java (`java.lang.Math`) qui regroupe des fonctions de calcul : `max`, `min`, `abs`, `round`, `sqrt`…
- `java.lang` est **toujours importé automatiquement** : je n'ai pas besoin d'écrire `import java.lang.Math;`.
- Ses méthodes sont **`static`** : je les appelle sur la classe (`Math.max(...)`), sans faire `new Math()`. D'ailleurs, on ne peut pas créer d'objet `Math`.

### Pourquoi je l'utilise ici : empêcher un montant négatif

```java
return Math.max(0, vente.getMontantreste() - avoir);
```

Je compare **`0`** avec **`reste - avoir`**, et je garde le plus grand :

| reste à payer | avoir | `reste - avoir` | `Math.max(0, ...)` | sens |
|---|---|---|---|---|
| 25 800 | 0 | 25 800 | **25 800** | pas d'avoir : achat normal |
| 25 800 | 25 440 | 360 | **360** | l'avoir couvre presque tout |
| 3 420 | 25 440 | −22 020 | **0** | l'avoir couvre tout, il reste du crédit |
| 25 440 | 25 440 | 0 | **0** | pile le même montant |

Sans `Math.max`, la 3ᵉ ligne renverrait **−22 020**. Ça voudrait dire « le magasin doit 22 020 au client sur cette vente », ce qui est faux : les 22 020 restent dans l'**avoir**, pour un prochain achat.

`Math.max(0, x)` est une façon très courante d'écrire « **x, mais pas en dessous de 0** » (un « plancher » à 0).

### La même chose avec un `if`

`Math.max` évite simplement d'écrire :

```java
double resultat = vente.getMontantreste() - avoir;
if (resultat < 0) {
    resultat = 0;
}
return resultat;
```

Les deux versions font exactement la même chose. `Math.max` tient en une ligne et se lit directement : « le plus grand entre 0 et le reste ».

### Sa petite sœur : `Math.min`

`Math.min(a, b)` renvoie le **plus petit**. Le projet l'utilise dans `genererPaiementFactureParAvoirAutom` ([VenteArbiochem.java](../../arbiochem-ejb/src/java/vente/VenteArbiochem.java)) :

```java
double montantPaiement = Math.min(montantTotalReste, montantFacture);
```

« J'utilise l'avoir, mais **jamais plus** que la facture. » C'est le **même raisonnement** que mon `Math.max`, vu de l'autre côté :

| | ce qui est calculé | formule |
|---|---|---|
| validation (code existant) | combien d'avoir je **consomme** | `min(avoir, reste)` |
| ma méthode | combien le client **paie encore** | `max(0, reste - avoir)` |

Et on a toujours : **consommé + payé encore = reste**. Exemple : `min(25 440, 25 800) = 25 440` et `max(0, 25 800 − 25 440) = 360`, et `25 440 + 360 = 25 800`. Mon affichage et la vraie consommation sont donc d'accord.

### Détails techniques (vérifiés par le test)

**a) Le `0` est un `int`, le reste est un `double` : est-ce grave ?**

Non. `Math.max` existe en plusieurs versions (on dit qu'elle est **surchargée**) :

```java
Math.max(int a, int b)
Math.max(long a, long b)
Math.max(float a, float b)
Math.max(double a, double b)
```

Java choisit la version selon les types. Ici j'ai un `int` (`0`) et un `double` (`reste - avoir`) : Java convertit automatiquement le `0` en `0.0` et prend la version `double`. Le résultat est un `double`, ce qui correspond au `double` que renvoie ma méthode.

```
Math.max(0, 360.0)    = 360.0
Math.max(0, -22020.0) = 0.0
Math.max(3, 7)        = 7       <- deux int : résultat int (pas de ".0")
```

**b) Le cas `NaN` (« Not a Number »)**

```
Math.max(0, NaN) = NaN
```

Si l'un des deux nombres est `NaN`, le résultat est `NaN`. Ça ne peut pas arriver ici : `montantreste` et l'avoir viennent de colonnes numériques de la base, et une colonne vide est lue comme `0`. Mais c'est bon à savoir : `Math.max` ne « répare » pas un calcul déjà faux.

---

## Les nouvelles règles d'or

### Règle d'or 7 — C'est le `new` qui décide de la classe, pas le cast

`new VenteLib().getById(...)` renvoie une vraie `VenteLib`, parce que `getById` utilise `this` comme modèle. Le cast `(VenteLib)` ne fait que dire au compilateur ce qu'est déjà l'objet. Si je fais `new Vente().getById(...)` puis `(VenteLib)`, ça plante (`ClassCastException`).

### Règle d'or 8 — Une sous-classe peut tout ce que peut sa mère

`VenteLib extends Vente` : toutes les méthodes de `Vente` (et de toute la chaîne jusqu'à `ClassMAPTable`) sont utilisables sur une `VenteLib`. Dans la méthode appelée, `this` est l'objet sur lequel on l'appelle.

### Règle d'or 9 — Un montant à payer ne descend jamais sous 0

Quand je soustrais un crédit d'un montant à payer : `Math.max(0, montant - credit)`. Quand je consomme un crédit : `Math.min(credit, montant)`.

---

## Résumé en une image

```
new VenteLib()                          -> objet VenteLib vide, table VENTE_CPL
   .getById(id, "", c)                  -> type écrit : ClassMAPTable  |  vrai objet : VenteLib remplie
(VenteLib) ...                          -> étiquette pour le compilateur (rien ne change en mémoire)

vente.getMontantAvoirDisponible(c)      -> méthode écrite dans Vente, héritée par VenteLib
                                           this = vente (client lu en base)

Math.max(0, reste - avoir)              -> le plus grand des deux = jamais négatif
```
