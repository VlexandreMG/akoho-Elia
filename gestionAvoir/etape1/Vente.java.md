# `arbiochem-ejb/src/java/vente/Vente.java` — Étape 1

Fichier : `arbiochem-ejb/src/java/vente/Vente.java`
Classe : `public class Vente extends FactureCF` (`FactureCF` hérite elle-même du framework APJ, `bean.ClassMere` → `bean.ClassEtat` → `bean.ClassMAPTable`)

Dans ce fichier, j'ai fait **deux** modifications :

1. **Ajout** de la méthode `updateToTableWithHisto(String u, Connection c)` : c'est le « trigger » métier (lignes 624 à 634).
2. **Modification** d'une ligne dans `genererAvoir2(...)` : le `commit()` (lignes 1378 et 1379).

Je n'ai ajouté **aucun import**. Tout ce que j'utilise est déjà importé ou se trouve dans le même package :
- `java.sql.Connection` est déjà importé (ligne 24) ;
- `Vente` est la classe elle-même ;
- `genererAvoir2` et `getById` sont des méthodes de cette même classe.

---

## Modification 1 — Ajout du trigger métier `updateToTableWithHisto`

**Emplacement :** juste après la méthode `controlerUpdate(Connection c)` (lignes 619 à 623), donc entre la ligne 623 et l'ancienne méthode `createMvtCaisses`.

**Pourquoi à cet endroit :** `controler` et `controlerUpdate` sont les méthodes du framework que `Vente` redéfinit déjà pour réagir à l'enregistrement. Je regroupe mon « hook » de modification avec elles : quelqu'un qui cherche « ce qui se passe quand on modifie une vente » trouve tout au même endroit.

### Avant

```java
    @Override
    public void controlerUpdate(Connection c) throws Exception {
        super.controlerUpdate(c);

    }

    public void createMvtCaisses(String u, Connection c) throws Exception {
```

### Après

```java
    @Override
    public void controlerUpdate(Connection c) throws Exception {
        super.controlerUpdate(c);

    }

    // Trigger métier : quand une vente passe de PROBLEME = 0 à PROBLEME = 1, je génère son avoir
    @Override
    public int updateToTableWithHisto(String u, Connection c) throws Exception {
        Vente ancienne = Vente.getById(c, this.getId());
        int retour = super.updateToTableWithHisto(u, c);
        if (this.getProbleme() == 1 && ancienne != null && ancienne.getProbleme() != 1) {
            Vente.genererAvoir2(u, c, this.getId());
        }
        return retour;
    }

    public void createMvtCaisses(String u, Connection c) throws Exception {
```

### Explication ligne par ligne

---

**Ligne 624 :** *(ligne vide)*

J'ai ajouté une ligne vide entre la fin de `controlerUpdate` (l'accolade `}` de la ligne 623) et ma nouvelle méthode. C'est la convention de tout le fichier : chaque méthode est séparée de la précédente par une ligne vide. Sans elle, les deux méthodes seraient collées et plus difficiles à distinguer à la lecture.

---

**Ligne 625 :**
```java
    // Trigger métier : quand une vente passe de PROBLEME = 0 à PROBLEME = 1, je génère son avoir
```
J'ai ajouté ce commentaire pour dire **en une phrase ce que fait la méthode et quand**.
- Le nom `updateToTableWithHisto` vient du framework et ne dit rien de mon intention : sans ce commentaire, on pourrait croire à une simple surcharge technique.
- J'emploie le mot « trigger » parce que c'est exactement le rôle de cette méthode : réagir automatiquement à une modification, comme un trigger SQL, mais côté Java.
- Les 4 espaces au début alignent le commentaire avec les méthodes de la classe (indentation du fichier).

---

**Ligne 626 :**
```java
    @Override
```
J'ai ajouté l'annotation `@Override` parce que je **redéfinis** une méthode qui existe déjà dans une classe parente : `updateToTableWithHisto(String, Connection)` est définie dans `bean.ClassMAPTable` (framework APJ, `apj-core.jar`).
- Elle demande au compilateur de **vérifier** que la méthode existe bien dans le parent avec exactement cette signature. Si je m'étais trompé (mauvais type de paramètre, faute de frappe dans le nom), la compilation échouerait au lieu de créer silencieusement une **nouvelle** méthode que personne n'appellerait jamais.
- C'est aussi la convention du fichier : `controler`, `controlerUpdate`, `createObject` et `validerObject` ont tous `@Override`.

---

**Ligne 627 :**
```java
    public int updateToTableWithHisto(String u, Connection c) throws Exception {
```
C'est la signature de ma méthode. Chaque élément est **imposé** par la méthode parente que je redéfinis :
- **`public`** : la méthode du parent est `public`. En Java, on ne peut pas réduire la visibilité d'une méthode redéfinie. Et le framework (`ClassEtat.updateObject`, `validerObject`, `annuler`…) doit pouvoir l'appeler.
- **`int`** : le parent renvoie un `int` (le nombre de lignes modifiées par l'UPDATE). Je dois renvoyer le même type.
- **`updateToTableWithHisto`** : c'est la méthode par laquelle passe **toute** modification d'un objet APJ (j'ai suivi le chemin depuis `vente-modif.jsp` jusqu'ici ; voir `00_vue_ensemble.md`). Elle fait l'`UPDATE` en base **et** écrit une ligne dans la table `historique`, d'où le « WithHisto ».
- **`String u`** : l'identifiant de l'utilisateur qui fait la modification. Le framework s'en sert pour l'historique (« Modification par 1 »). Moi, je le transmets à `genererAvoir2` pour que l'avoir soit lui aussi enregistré au nom du bon utilisateur.
- **`Connection c`** : la connexion à la base, avec la **transaction en cours**. En la réutilisant partout, la modification de la vente et la création de l'avoir font partie de **la même transaction**.
- **`throws Exception`** : le parent déclare `throws Exception`. Je le garde pour que toute erreur (de l'UPDATE ou de la création de l'avoir) remonte jusqu'à `UserEJBBean.updateObjectMultiple`, qui fera alors le `rollback` de tout.
- **`{`** : ouvre le corps de la méthode.

---

**Ligne 628 :**
```java
        Vente ancienne = Vente.getById(c, this.getId());
```
J'ai ajouté cette ligne pour **lire la vente telle qu'elle est encore en base, avant la modification**.
- C'est l'équivalent du `:OLD` d'un trigger SQL. À ce moment-là, l'objet `this` contient déjà les **nouvelles** valeurs venant du formulaire, mais l'`UPDATE` n'a **pas encore** été fait : la base contient donc toujours les **anciennes** valeurs.
- **`Vente ancienne`** : je déclare une variable de type `Vente`. Je la nomme `ancienne` pour qu'on comprenne tout de suite qu'il s'agit de l'**ancien état**, par opposition à `this`, le **nouvel état**.
- **`Vente.getById(c, ...)`** : je réutilise la méthode statique `getById` qui existe déjà dans cette classe (vers la ligne 1450). Elle fait `select * from VENTE where id like '...'` via `CGenUtil.rechercher` et renvoie la vente trouvée, ou `null`. Je lui passe `c` pour lire **dans la même transaction**.
- **`this.getId()`** : l'identifiant de la vente qu'on est en train de modifier (par exemple `VNT001699001012`).
- **Pourquoi avant le `super`** : si je lisais après, la base contiendrait déjà `PROBLEME = 1` et je ne pourrais plus savoir si la valeur **vient de passer** à 1 ou si elle **y était déjà**.

---

**Ligne 629 :**
```java
        int retour = super.updateToTableWithHisto(u, c);
```
J'ai ajouté cette ligne pour **faire la vraie modification**, exactement comme le framework l'aurait faite sans moi.
- **`super.updateToTableWithHisto(u, c)`** : j'appelle la version **du parent** (`bean.ClassMAPTable`). C'est elle qui exécute l'`UPDATE VENTE SET ... WHERE id = '...'` et qui insère la ligne d'historique. Sans cet appel, ma redéfinition **remplacerait** complètement le comportement d'origine, et la vente ne serait plus jamais modifiée en base.
- **`int retour =`** : je garde le résultat (le nombre de lignes modifiées) dans une variable pour le renvoyer à la fin, ligne 633. L'appelant reçoit ainsi exactement la même valeur qu'avant ma modification.
- **Pourquoi l'avoir n'est créé qu'après** : c'est un comportement « AFTER UPDATE ». Si l'`UPDATE` lève une exception, la méthode s'arrête ici et l'avoir n'est jamais créé. On ne crée pas d'avoir pour une modification qui a échoué.

---

**Ligne 630 :**
```java
        if (this.getProbleme() == 1 && ancienne != null && ancienne.getProbleme() != 1) {
```
J'ai ajouté cette condition pour ne créer l'avoir **que lorsque la vente vient de passer en problème**. Les trois conditions doivent être vraies en même temps (`&&` = ET) :
- **`this.getProbleme() == 1`** : la **nouvelle** valeur (celle qui vient d'être enregistrée) est `1`, donc la vente a un problème. En base, `PROBLEME` est un `NUMBER(1)` (Oracle 11g n'a pas de type booléen pour les colonnes). Dans la classe, c'est un `int probleme` (ligne 95) avec son getter `getProbleme()` (ligne 134). `1` veut dire « vrai », `0` veut dire « faux ».
- **`ancienne != null`** : je vérifie que l'ancienne vente a bien été trouvée. Si `getById` renvoie `null`, appeler `ancienne.getProbleme()` provoquerait une `NullPointerException`. Je mets ce test **avant** `ancienne.getProbleme()` parce que `&&` s'arrête dès qu'une condition est fausse : si `ancienne` est `null`, Java n'évalue jamais la troisième condition.
- **`ancienne.getProbleme() != 1`** : l'**ancienne** valeur n'était **pas** `1`. C'est ce qui évite les doublons : si on ré-enregistre une vente qui avait **déjà** un problème (par exemple pour corriger son lieu de livraison), on ne recrée pas un deuxième avoir. J'écris `!= 1` plutôt que `== 0` pour couvrir aussi toute autre valeur inattendue.
- **`{`** : ouvre le bloc exécuté seulement si la condition est vraie.

---

**Ligne 631 :**
```java
            Vente.genererAvoir2(u, c, this.getId());
```
J'ai ajouté cette ligne pour **créer l'avoir de la vente**.
- **`Vente.genererAvoir2(...)`** : je réutilise la méthode statique qui existe déjà dans cette classe (vers la ligne 1346). Elle fait tout le travail :
  - lire la vente et ses lignes (`VENTE_DETAILS`) ;
  - créer l'en-tête `AVOIRFC` (client, magasin, date, `etat = 1`, type `TYA0002`, numéro `0044/2026` via `V_NUMEROAVOIR_EN_COURS`, identifiant `AVRFC000xxx` via `GETSEQAVOIRFC`) ;
  - créer une ligne `AVOIRFCFILLE` par ligne de vente, avec le prix unitaire net.

  Je ne réécris pas cette logique : si elle évolue, mon trigger en profite automatiquement.
- **`u`** : l'utilisateur, pour que l'historique de l'avoir indique qui l'a créé.
- **`c`** : la **même** connexion, donc la même transaction. Si la création de l'avoir échoue, l'exception remonte et l'appelant annule **tout**, y compris la modification de la vente. Grâce à la modification 2 (plus bas), `genererAvoir2` ne fait **pas** de commit sur cette connexion qui ne lui appartient pas.
- **`this.getId()`** : l'identifiant de la vente pour laquelle on crée l'avoir. L'avoir sera lié à la vente par sa colonne `IDVENTE`.
- **La valeur de retour (l'objet `AvoirFC`)** n'est pas récupérée : mon trigger n'en a pas besoin, il doit seulement **créer** l'avoir.
- L'indentation de 12 espaces (un niveau de plus que le `if`) montre que la ligne est **dans** le bloc du `if`.

---

**Ligne 632 :**
```java
        }
```
J'ai ajouté cette accolade pour **fermer le bloc du `if`** ouvert à la ligne 630. Elle est alignée sur le `if` (8 espaces) pour qu'on voie tout de suite à quel `if` elle appartient.

---

**Ligne 633 :**
```java
        return retour;
```
J'ai ajouté cette ligne pour **renvoyer le résultat de l'UPDATE** obtenu à la ligne 629.
- La méthode doit renvoyer un `int` (signature imposée par le parent). Sans `return`, le code ne compilerait pas.
- Je renvoie **exactement** ce que le framework aurait renvoyé sans moi. Pour tous les appelants (`ClassEtat.updateObject`, `validerObject`…), rien ne change : mon trigger est **transparent**.
- Ce `return` est **en dehors** du `if` : on renvoie le résultat dans tous les cas, qu'un avoir ait été créé ou non.

---

**Ligne 634 :**
```java
    }
```
J'ai ajouté cette accolade pour **fermer le corps de la méthode** ouvert à la fin de la ligne 627. Elle est alignée sur la déclaration de la méthode (4 espaces), comme toutes les fins de méthode du fichier.

---

## Modification 2 — `commit()` conditionnel dans `genererAvoir2`

**Emplacement :** méthode `public static AvoirFC genererAvoir2(String u, Connection c, String idVente)`, dans le bloc `try`, juste après `avoirFC.setAvoirDetails(avoirFCFilles);`, lignes 1378 et 1379.

### Avant

```java
            avoirFC.setAvoirDetails(avoirFCFilles);
            // Étape 10 : je valide tout avec commit
            c.commit();
        } catch (Exception e) {
            // En cas d'erreur : rollback seulement si c'est moi qui ai ouvert la connexion
            if(estOuvert) c.rollback();
```

### Après

```java
            avoirFC.setAvoirDetails(avoirFCFilles);
            // Étape 10 : je valide tout avec commit, seulement si c'est moi qui ai ouvert la connexion
            if(estOuvert) c.commit();
        } catch (Exception e) {
            // En cas d'erreur : rollback seulement si c'est moi qui ai ouvert la connexion
            if(estOuvert) c.rollback();
```

### Explication ligne par ligne

---

**Ligne 1378 (modifiée) :**
```java
            // Étape 10 : je valide tout avec commit, seulement si c'est moi qui ai ouvert la connexion
```
J'ai complété le commentaire existant (« Étape 10 : je valide tout avec commit ») en ajoutant **« , seulement si c'est moi qui ai ouvert la connexion »**. Le commentaire doit décrire ce que fait **vraiment** la ligne en dessous : maintenant, le commit est conditionnel. J'ai repris mot pour mot la formulation du commentaire du `rollback` (ligne 1381, juste au-dessus du `if(estOuvert) c.rollback();` de la ligne 1382), pour qu'on voie que les deux suivent **la même règle**.

---

**Ligne 1379 (modifiée) :**
```java
            if(estOuvert) c.commit();
```
Avant, la ligne était `c.commit();`. J'ai ajouté **`if(estOuvert) `** devant.
- **`estOuvert`** est une variable `boolean` déjà déclarée au début de `genererAvoir2` (`boolean estOuvert = false;`). Elle passe à `true` uniquement si la méthode a reçu `c == null` et a donc ouvert **elle-même** sa connexion (`c = new UtilDB().GetConn();`).
- **Pourquoi c'était un problème** : mon trigger appelle `genererAvoir2` avec la connexion de l'appelant (`UserEJBBean.updateObjectMultiple`), **au milieu** de sa transaction. Un `commit()` à cet endroit aurait :
  - validé définitivement la vente modifiée **avant** que ses lignes (`VENTE_DETAILS`) ne soient mises à jour ;
  - empêché tout `rollback` si la suite de l'enregistrement échouait. On se serait retrouvé avec des données à moitié enregistrées.
- **La règle que j'applique** : celui qui **ouvre** la connexion est celui qui **commit**, **rollback** et **ferme**. C'était déjà la règle pour `c.rollback()` (ligne 1382) et `c.close()` (dans le `finally`). Le `commit()` était le seul à ne pas la suivre.
- **Pourquoi ça ne change rien pour l'existant** : les seuls appelants de `genererAvoir2` sont `genererAvoir(...)` (appelé par `apres-generation-avoir.jsp`) et `annulerFacture(...)` (appelé par `apres-annuler.jsp`). Tous les deux passent `null` comme connexion. Pour eux, `estOuvert` vaut `true`, donc le commit a lieu exactement comme avant.
- J'ai écrit `if(estOuvert)` sans espace après `if`, collé à l'instruction sur la même ligne, pour copier le style exact des lignes `if(estOuvert) c.rollback();` et `if(estOuvert) c.close();` de la même méthode.

---

## Vérification

- **Compilation** de `Vente.java` avec `javac` contre `build-file/lib/*` et les classes déjà compilées du projet : aucune erreur.
- **Test d'exécution** (programme jetable hors projet, transaction terminée par `ROLLBACK`) :
  - une modification sans changer `probleme` crée **0** avoir ;
  - le passage de `probleme` de 0 à 1 crée **1** avoir : `AVRFC000334`, numéro `0044/2026`, `etat = 1`, type `TYA0002`, et 1 ligne `INGR000001`, `qte = 10`, `pu = 2150` ;
  - une nouvelle modification avec `probleme` déjà à 1 laisse **toujours 1** avoir (pas de doublon) ;
  - après le `ROLLBACK`, la base est revenue à l'identique (0 avoir, `PROBLEME = 0`).
