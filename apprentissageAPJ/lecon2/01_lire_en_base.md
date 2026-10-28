# Leçon 2 : lire en base avec APJ (`AvoirFC` / `AvoirFCLib`, `setNomTable`, `CGenUtil`, `AdminGen`)

> Objectif : comprendre chaque morceau de la méthode `Vente.getMontantAvoirDisponible(...)` de l'étape 2 de la gestion d'avoir :
>
> ```java
> AvoirFCLib t = new AvoirFCLib();
> t.setNomTable("AVOIRFCLIB_CPL");
> AvoirFCLib[] avoirs = (AvoirFCLib[]) CGenUtil.rechercher(t,null,null,c," AND idClient='...' and resteapayerar > 0");
> return AdminGen.calculSommeDouble(avoirs,"resteapayerar");
> ```

## Comment j'ai obtenu ces informations

- `AvoirFC` et `AvoirFCLib` sont dans le projet : je les ai lus directement dans [arbiochem-ejb/src/java/avoir/](../../arbiochem-ejb/src/java/avoir/).
- `ClassMAPTable`, `CGenUtil` et `AdminGen` sont dans `build-file/lib/apj-core.jar`, sans code source. Je les ai **désassemblés** avec `javap`, comme dans la leçon 1 :

```bash
javap -cp build-file/lib/apj-core.jar bean.CGenUtil             # liste des méthodes
javap -c -cp build-file/lib/apj-core.jar bean.CGenUtil          # instructions de chaque méthode
javap -c -cp build-file/lib/apj-core.jar bean.ClassMAPTable
javap -c -cp build-file/lib/apj-core.jar bean.AdminGen
```

- J'ai demandé à Oracle le **type** de chaque objet (`select object_name, object_type from user_objects ...`).
- J'ai vérifié deux comportements par un petit test jetable (voir les règles d'or 4 et 5).

---

## 1. `AvoirFC` et `AvoirFCLib` : la table et la vue

### Ce qu'il y a en base

| nom | type Oracle | rôle |
|---|---|---|
| `AVOIRFC` | **TABLE** | les vraies données de l'avoir : on y **écrit** (`INSERT`, `UPDATE`) |
| `AVOIRFCLIB` | **VIEW** (vue) | `AVOIRFC` + les **libellés** (nom du client, du magasin, du motif…) + les **montants calculés** (HT, TVA, TTC) |
| `AVOIRFCLIB_CPL` | **VIEW** | `AVOIRFCLIB` + encore plus de calculs : montant déjà payé, **`RESTEAPAYERAR`**… |

Une **vue** est une requête `select` enregistrée sous un nom. On la lit comme une table, mais elle ne stocke rien : elle recalcule tout à chaque lecture, à partir des tables.

### Ce qu'il y a en Java

```java
public class AvoirFC extends ClassMere {          // AvoirFC.java:42
    public AvoirFC(){ this.setNomTable("AvoirFC"); }

public class AvoirFCLib extends AvoirFC {         // AvoirFCLib.java:18
    public AvoirFCLib(){ this.setNomTable("avoirFCLib"); }
    String clientlib;        // libellé du client
    String idMagasinLib;     // libellé du magasin
    double montantTTCAr;     // montant calculé
    double resteapayerar;    // reste utilisable
    ...
```

- **`AvoirFC`** correspond à la **table** `AVOIRFC`. Elle a seulement les colonnes stockées : id, date, idClient, idVente, état…
- **`AvoirFCLib`** **hérite** d'`AvoirFC` (elle a donc tout ce qu'a `AvoirFC`) et **ajoute** les attributs que seules les vues fournissent : les libellés (`...lib`) et les montants calculés.
- *Lib* veut dire **libellé** : c'est la version « lisible par un humain » de l'avoir.

### Pourquoi j'ai utilisé `AvoirFCLib` et pas `AvoirFC`

J'ai besoin de `resteapayerar`. Cette valeur **n'existe pas** dans la table `AVOIRFC` : seule la vue `AVOIRFCLIB_CPL` la calcule. Et seule la classe `AvoirFCLib` a un attribut pour la recevoir.

C'est la même organisation partout dans le projet : `Vente` / `VenteLib`, `AvoirFCFille` / `AvoirFCFilleLib`, `AvoirAchat` / `AvoirAchatLib`…

---

## 2. `setNomTable(...)` : dire à l'objet où il habite en base

Chaque objet APJ hérite de `bean.ClassMAPTable` (voir leçon 1) et transporte **le nom de sa table** dans deux attributs :

| attribut | sert à | lu par |
|---|---|---|
| `nomTable` | **écrire** (`INSERT`, `UPDATE`), et lire par défaut | `getNomTable()` |
| `nomTableSelect` | **lire** (`select`) dans un autre endroit, si on le précise | `getNomTableSelect()` |

Ce que montre le bytecode :

```java
// ClassMAPTable.setNomTable
public void setNomTable(String nom) {
    if (nom != null && nom.compareTo("") != 0)   // un nom null ou vide est IGNORÉ
        this.nomTable = nom;
}

// ClassMAPTable.getNomTableSelect
public String getNomTableSelect() {
    if (nomTableSelect == null || nomTableSelect == "")
        return getNomTable();                    // pas de table de lecture précisée -> on lit dans nomTable
    return nomTableSelect;
}
```

Donc, dans ma méthode :

```java
AvoirFCLib t = new AvoirFCLib();     // le constructeur met nomTable = "avoirFCLib"
t.setNomTable("AVOIRFCLIB_CPL");     // je le remplace : je veux lire dans la vue la plus complète
```

**Le nom de la table n'est pas lié à la classe, il est lié à l'objet.** Une même classe `AvoirFCLib` peut lire `AVOIRFCLIB` ou `AVOIRFCLIB_CPL`, selon ce qu'on lui dit. C'est pratique, mais dangereux (règle d'or 2).

Le projet s'en sert aussi dans l'autre sens. [UpdateVente.java](../../arbiochem-ejb/src/java/vente/UpdateVente.java) lit dans `UPDATEVENTE`, mais remet `setNomTable("VENTE")` juste avant d'écrire :

```java
public int updateToTableWithHisto(String refUser, Connection c) throws Exception {
    setNomTable("VENTE");                         // on n'écrit jamais dans une vue
    return super.updateToTableWithHisto(refUser, c);
}
```

---

## 3. `CGenUtil` : l'outil qui transforme une requête en objets Java

**D'où il vient :** `bean.CGenUtil`, dans `apj-core.jar` (importé en haut de `Vente.java` : `import bean.CGenUtil;`). Le nom se lit probablement « **C**lasse **Gén**érique **Util**itaire ». Toutes ses méthodes sont `static` : on l'appelle par le nom de la classe, sans `new`.

« Générique » veut dire qu'il marche pour **n'importe quelle** classe APJ (Vente, Avoir, Client…). On ne lui écrit pas de SQL complet : il le fabrique à partir de l'objet qu'on lui donne.

### La méthode que j'utilise

```java
public static Object[] rechercher(ClassMAPTable modele, String[] colInt, String[] valInt, Connection c, String apresWhere)
```

| paramètre | dans mon appel | rôle |
|---|---|---|
| `modele` | `t` | un objet « exemple » : il donne la **table** et la **classe** des résultats, et ses attributs remplis deviennent des **filtres** |
| `colInt`, `valInt` | `null, null` | filtres par intervalle (« date entre … et … »), inutilisés ici |
| `c` | `c` | la connexion ; si `null`, `rechercher` ouvre la sienne et la referme |
| `apresWhere` | `" AND idClient='...' and resteapayerar > 0"` | du SQL ajouté **tel quel** à la fin du `where` |

### Ce qu'elle fait, étape par étape (d'après le bytecode)

1. **Construit le SQL** : `"select * from " + modele.getNomTableSelect() + " where " + makeWhere(modele) + intervalles + apresWhere`.
2. **`makeWhere(modele)`** commence par `1<2` (toujours vrai, pour pouvoir enchaîner des `and`). Puis, pour chaque attribut **rempli** du modèle, il ajoute un filtre. C'est comme ça que `Vente.getById` fonctionne : il fait `vtn.setId(id)` puis `rechercher(vtn, ...)`, et on voit dans le log `where 1<2 and id like 'VNT...'`.
3. **Affiche la requête** dans le log (`Requete select rechercher : ...`). C'est la ligne qu'on a vue 28 744 fois pendant le `StackOverflowError`.
4. **Exécute** la requête.
5. **`transformeDataReader`** : pour **chaque ligne**, il crée un **nouvel objet de la même classe que le modèle** (`Class.forName(modele.getClassName()).newInstance()`). Puis il recopie chaque colonne dans l'attribut Java **du même nom**.
6. **Renvoie** un tableau d'objets (`Object[]`). On le convertit avec `(AvoirFCLib[])`.
7. **Si elle a ouvert la connexion elle-même**, elle la ferme. Le framework applique lui aussi la règle d'or de la leçon 1.

Requête réellement exécutée pour ma méthode :

```sql
select * from AVOIRFCLIB_CPL where 1<2  AND idClient='CLIA0935' and resteapayerar > 0
```

### Autres méthodes de `CGenUtil` qu'on croise dans le projet

| méthode | rôle |
|---|---|
| `rechercher(...)` (plusieurs versions) | lire |
| `rechercherPage(...)` | lire avec pagination et sommes (utilisé par les pages « liste ») |
| `save(obj, c)` | insérer |
| `updateBatch(objs, c)` | mettre à jour plusieurs objets d'un coup |

---

## 4. `AdminGen` : les calculs sur un tableau d'objets

**D'où il vient :** `bean.AdminGen`, aussi dans `apj-core.jar` (`import bean.AdminGen;`). Le nom se lit probablement « **Admin**istration **Gén**érique ». C'est une boîte à outils de méthodes `static` qui travaillent sur des **tableaux d'objets APJ** : sommes, formatage…

### La méthode que j'utilise

```java
public static double calculSommeDouble(ClassMAPTable[] tableau, String nomAttribut)
```

Ce qu'elle fait (d'après le bytecode) :

1. Pour chaque objet du tableau, elle lit l'attribut **dont on lui donne le nom en texte** avec `CGenUtil.getValeurFieldByMethod(objet, "resteapayerar")`. Elle appelle donc `getResteapayerar()` par **réflexion** (Java cherche la méthode à partir de son nom, à l'exécution).
2. Elle additionne.
3. Elle **arrondit à 2 décimales** (`Math.round(x * 100) / 100`).
4. **Si quelque chose plante, elle affiche l'erreur dans le log et continue.** Elle ne la renvoie pas à l'appelant (règle d'or 5).

Avec un tableau vide, la somme vaut `0`. C'est pour ça que la route « pas d'avoir » ne demande aucun `if` dans ma méthode.

Autres variantes : `calculSommeDouble(tableau, new String[]{"montantht","montantttc"})` (plusieurs sommes d'un coup), `calculSommeDoubleSi(...)` (somme avec condition).

---

## Les nouvelles règles d'or

La règle d'or de la leçon 1 reste valable : **celui qui ouvre la connexion fait le `commit`, le `rollback` et le `close`.** En voici 5 nouvelles.

### Règle d'or 2 — On lit avec la *Lib*, on écrit avec la table

> **Pour lire des libellés ou des montants calculés : la classe `...Lib` sur une vue. Pour créer ou modifier : la classe de base sur la table.**

Une vue n'a pas de vraies lignes : un `INSERT` ou un `UPDATE` dessus échoue. Avant d'appeler `createObject`, `updateToTableWithHisto`, etc., vérifie que `getNomTable()` désigne une **table**. Un objet sorti d'une recherche sur une vue garde le nom de cette vue.

### Règle d'or 3 — Le modèle de recherche doit être neuf

> **Un attribut rempli dans le modèle devient un filtre.**

`makeWhere` ajoute un filtre pour chaque attribut rempli. Si je réutilise un objet qui a déjà un `id`, un `idClient`… comme modèle, ces valeurs filtrent la recherche sans que je le voie dans mon code. Je fais toujours `new X()`, je remplis **seulement** ce que je veux filtrer, et je mets le reste dans `apresWhere`.

### Règle d'or 4 — `setNomTable` ignore les noms vides

> **`setNomTable("")` et `setNomTable(null)` ne font rien, sans aucune erreur.**

Vérifié par le test : après `setNomTable("")`, `getNomTable()` vaut toujours `avoirFCLib`. Si je construis le nom de table dans une variable, je dois vérifier qu'elle n'est pas vide : sinon je lis en silence dans une autre table que prévu.

### Règle d'or 5 — Un nom d'attribut en texte doit être exact

> **Dans `AdminGen.calculSommeDouble(tableau, "nom")`, une faute de frappe renvoie `0`, sans planter.**

Vérifié par le test, sur les 3 avoirs du client `CLIA0935` :

```
calculSommeDouble(r, "resteapayerar")   -> 25440.0
calculSommeDouble(r, "resteapayer_ar")  -> 0.0      (une erreur dans le log, mais aucune exception)
```

Le compilateur ne peut pas vérifier un nom écrit entre guillemets. Je copie le nom depuis l'attribut Java (`double resteapayerar;` dans `AvoirFCLib.java`), et je teste toujours une fois avec un cas où je **connais** le résultat attendu.

### Règle d'or 6 — Colonne de la vue = attribut Java, même nom

> **`rechercher` remplit un attribut seulement si une colonne porte le même nom.**

`transformeDataReader` recopie chaque colonne dans l'attribut Java du même nom. Si une vue renomme une colonne (`RESTE_AR` au lieu de `RESTEAPAYERAR`), l'attribut reste à sa valeur par défaut (`0` pour un `double`, `null` pour un `String`), sans erreur. Quand j'ajoute une colonne dans une vue, j'ajoute l'attribut avec **exactement** le même nom dans la classe `...Lib`, plus son getter et son setter.

---

## Résumé en une image

```
        Java                                    Oracle
 ┌──────────────────┐   setNomTable("…")   ┌──────────────────────┐
 │ AvoirFC          │ ───────────────────▶ │ AVOIRFC       (TABLE)│  ◀── écrire : createObject, update…
 │  └ AvoirFCLib    │ ───────────────────▶ │ AVOIRFCLIB    (VUE)  │
 │     + libellés   │                      │ AVOIRFCLIB_CPL (VUE) │  ◀── lire : CGenUtil.rechercher
 │     + montants   │                      └──────────────────────┘
 └──────────────────┘
          │  CGenUtil.rechercher(modèle, …)  →  AvoirFCLib[]   (une ligne = un objet)
          ▼
   AdminGen.calculSommeDouble(tableau, "resteapayerar")  →  double
```
