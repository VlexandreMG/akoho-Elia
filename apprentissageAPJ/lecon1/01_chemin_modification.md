# Leçon 1 : le chemin d'une modification dans APJ

> Objectif : comprendre ce qui se passe, étage par étage, entre le clic sur « Modifier » dans un écran et la requête `UPDATE` envoyée à Oracle. En particulier `updateObjectMultiple(mere, colonneMere, filles, c)` et `updateToTableWithHisto(u, c)`.

## Comment j'ai obtenu ces informations

- Les 3 premiers étages sont dans le code du projet. Je les ai lus directement :
  - [UserEJBBean.java](../../arbiochem-ejb/src/java/user/UserEJBBean.java)
  - [UpdateObject.java](../../arbiochem-ejb/src/java/user/UpdateObject.java)
- Les étages suivants (`bean.ClassEtat`, `bean.ClassMAPTable`) sont dans la bibliothèque `build-file/lib/apj-core.jar`, sans le code source. Je les ai **désassemblés** avec l'outil `javap -c` fourni avec Java. Il affiche les instructions compilées (le *bytecode*), et on peut y lire les méthodes appelées, les chaînes de caractères et les conditions :

```bash
javap -cp build-file/lib/apj-core.jar -c bean.ClassEtat
javap -cp build-file/lib/apj-core.jar -c bean.ClassMAPTable
```

- J'ai confirmé le tout avec les logs SQL qu'APJ affiche pendant un test réel (`Requete update : UPDATE VENTE SET ...`).

---

## Vue d'ensemble

Quand on clique sur « Modifier » dans `vente-modif.jsp`, l'appel traverse 6 étages :

```
apresMultiple.jsp                                    ← écran : lit le formulaire
 └─ UserEJBBean.updateObjectMultiple(mere, colonneMere, filles, c)   ← chef d'orchestre de la transaction
     ├─ updateObject(mere, c)                        ← droits de l'utilisateur
     │   └─ UpdateObject.updateObject(o, c, u, user) ← ajoute l'utilisateur
     │       └─ vente.updateObject(idUser, c)        ← ClassEtat : contrôle de l'état
     │           └─ updateToTableWithHisto(u, c)     ← historique, puis UPDATE  ← (trigger métier de l'étape 1)
     └─ updateObjectMultiple(filles, colonneMere, idMere, c)  ← les lignes, une par une
```

| Étage | Méthode | Où | Rôle en une phrase |
|---|---|---|---|
| 1 | `updateObjectMultiple(mere, colonneMere, filles, c)` | projet | ouvre la transaction, modifie la mère puis les filles, fait commit ou rollback |
| 2 | `updateObjectMultiple(filles[], colonneMere, idmere, c)` | projet | pour chaque ligne : la rattache à la mère, puis UPDATE ou INSERT |
| 3 | `UpdateObject.updateObject(o, c, u, user)` | projet | note l'utilisateur qui modifie (`iduser`) |
| 4 | `ClassEtat.updateObject(u, c)` | jar | refuse si le document est déjà validé |
| 5 | `updateToTableWithHisto(String u, Connection c)` | jar | prépare la ligne d'historique |
| 6 | `updateToTableWithHisto(ClassMAPTable h, Connection c)` | jar | exécute vraiment les requêtes : `INSERT` historique et `UPDATE` |

---

## Étage 1 : `updateObjectMultiple(mere, colonneMere, filles, c)`

Fichier : [UserEJBBean.java:295](../../arbiochem-ejb/src/java/user/UserEJBBean.java#L295)

Cette méthode modifie un **document complet** : la mère (l'en-tête, par exemple la `Vente`) et ses filles (les lignes, par exemple les `VenteDetails`).

### Les paramètres

| Paramètre | Exemple pour une vente | Rôle |
|---|---|---|
| `mere` | l'objet `Vente` rempli par le formulaire | l'en-tête à modifier |
| `colonneMere` | `"idVente"` | le nom de la colonne des filles qui pointe vers la mère |
| `filles` | tableau de `VenteDetails` | les lignes du document |
| `c` | souvent `null` quand on vient de l'écran | la connexion à la base, avec sa transaction |

### Le code

```java
public Object updateObjectMultiple(ClassMAPTable mere, String colonneMere, ClassMAPTable[] fille, Connection c) throws Exception {
    boolean in = false;
    Object ret = null;
    try {
        boolean estAutorise=ActionRole.estAutorise(this.getActionRole(),this.getuVue(),"update",mere);
        if(estAutorise==false)throw new Exception("Action de modification non autorise de "+...);
        if (c == null) {
            c = new UtilDB().GetConn();
            c.setAutoCommit(false);
            in = true;
        }
        Object idmere = updateObject(mere, c);
        ret = updateObjectMultiple(fille, colonneMere, ((ClassMAPTable) idmere).getTuppleID(), c);
        ret = idmere;
        if (in) {
            c.commit();
        }
    } catch (Exception ex) {
        ex.printStackTrace();
        if (in && c != null) {
            c.rollback();
        }
        throw ex;
    } finally {
        if (in && c != null) {
            c.close();
        }
    }
    ...
}
```

### Ce qu'elle fait, dans l'ordre

1. **Vérifier les droits** : `ActionRole.estAutorise(..., "update", mere)` vérifie que l'utilisateur connecté a le droit de modifier ce type d'objet. Sinon, elle lève l'exception « Action de modification non autorise ».
2. **Ouvrir la transaction si besoin** : si on ne lui donne pas de connexion (`c == null`), elle en ouvre une, coupe l'auto-commit (`setAutoCommit(false)`) pour pouvoir tout annuler en cas d'erreur, et note `in = true`, c'est-à-dire « c'est moi qui l'ai ouverte ».
3. **Modifier la mère d'abord** : `updateObject(mere, c)` (étages 3 à 6).
4. **Puis les filles** : `updateObjectMultiple(fille, colonneMere, idMere, c)` (étage 2). Elle passe l'id de la mère pour que chaque ligne y soit rattachée.
5. **Terminer** :
   - si tout s'est bien passé et que `in` vaut `true`, elle fait `commit` : tout est enregistré d'un coup ;
   - en cas d'exception, elle fait `rollback` : rien n'est enregistré, ni la mère ni les filles ;
   - dans le `finally`, elle ferme la connexion qu'elle a ouverte.

### La règle d'or d'APJ

> **Celui qui ouvre la connexion est celui qui fait le `commit`, le `rollback` et le `close`.**

Si une méthode **reçoit** une connexion déjà ouverte, elle l'utilise mais ne la valide pas et ne la ferme pas : c'est le travail de l'appelant. C'est la règle que j'ai appliquée à l'étape 1 de la gestion d'avoir, en corrigeant `c.commit()` en `if(estOuvert) c.commit()` dans `Vente.genererAvoir2`.

---

## Étage 2 : la version pour les filles, `updateObjectMultiple(filles[], colonneMere, idmere, c)`

Fichier : [UserEJBBean.java:374](../../arbiochem-ejb/src/java/user/UserEJBBean.java#L374)

Même nom, mais des **paramètres différents** : c'est une *surcharge* (overload) en Java. Celle-ci ne reçoit que les filles.

```java
public Object[] updateObjectMultiple(ClassMAPTable[] o, String colonneMere, String idmere, Connection c) throws Exception {
    try {
        Object[] ret = new Object[o.length];
        for (int i = 0; i < o.length; i++) {
            o[i].setValChamp(colonneMere, idmere);
            if (!o[i].getTuppleID().equals("")) {
                ret[i] = updateObject(o[i], c);
            } else {
                ret[i] = createObject(o[i], c);
            }
        }
        return ret;
    } catch (Exception ex) {
        ex.printStackTrace();
        c.rollback();
        throw ex;
    }
}
```

| Ligne | Ce qu'elle fait |
|---|---|
| `for (int i = 0; i < o.length; i++)` | parcourt chaque ligne du document |
| `o[i].setValChamp(colonneMere, idmere);` | rattache la ligne à la mère. Par exemple, elle met `idVente = 'VNT001699001012'` dans le `VenteDetails`. |
| `if (!o[i].getTuppleID().equals(""))` | la ligne a-t-elle déjà un identifiant ? |
| `ret[i] = updateObject(o[i], c);` | oui : elle existe déjà en base, donc **UPDATE** |
| `ret[i] = createObject(o[i], c);` | non : c'est une ligne ajoutée dans le formulaire, donc **INSERT** |

### À retenir

- **`setValChamp("idVente", valeur)`** remplit un attribut **par son nom**, grâce à la *réflexion* Java (le programme inspecte la classe pendant l'exécution). C'est comme ça qu'APJ peut manipuler **n'importe quelle** classe sans la connaître à l'avance.
- **`getTuppleID()`** renvoie la valeur de la clé primaire de l'objet (son `id`).
- Une ligne **supprimée** dans le formulaire n'est **pas** supprimée en base : cette méthode ne fait jamais de `DELETE`.

---

## Étage 3 : `UpdateObject.updateObject(o, c, u, user)`

Fichier : [UpdateObject.java:34](../../arbiochem-ejb/src/java/user/UpdateObject.java#L34)

```java
if (o instanceof bean.ClassEtat) {
    o.setValChamp("iduser", u.getTuppleID());
}
...
o.updateObject(u.getTuppleID(), c);
```

- Si l'objet est un `ClassEtat` (un objet qui a un `etat` : créé, validé, annulé…), elle note **qui** fait la modification dans son attribut `iduser`.
- Il y a aussi un cas particulier pour les utilisateurs (`MapUtilisateur`) : elle chiffre le mot de passe avant l'enregistrement.
- Ensuite elle appelle `o.updateObject(idUtilisateur, c)`. **À partir d'ici, on est dans le framework APJ** (`apj-core.jar`).

---

## Étage 4 : `ClassEtat.updateObject(String u, Connection c)` (dans le jar)

Le bytecode désassemblé :

```
0: aload_0
1: invokevirtual getEtat:()I
4: invokestatic  utilitaire/ConstanteEtat.getEtatValider:()I
7: if_icmplt     20
10: new           java/lang/Exception
14: ldc           "Impossible de modifier un objet deja valide"
19: athrow
20: ... invokevirtual updateToTableWithHisto:(Ljava/lang/String;Ljava/sql/Connection;)I
26: ireturn
```

Ce qui donne, en Java :

```java
public int updateObject(String u, Connection c) throws Exception {
    if (this.getEtat() >= ConstanteEtat.getEtatValider())   // getEtatValider() = 11
        throw new Exception("Impossible de modifier un objet deja valide");
    return updateToTableWithHisto(u, c);
}
```

**Comment lire le bytecode :** `if_icmplt 20` signifie « si le premier entier est plus petit (*less than*) que le second, saute à l'instruction 20 ». Donc si `etat < 11`, on saute directement à l'appel de `updateToTableWithHisto`. Sinon, on tombe sur le `throw`.

### Conséquence importante

Un document **visé** (validé, `etat = 11`) **ne peut plus être modifié** par ce chemin. L'exception est levée **avant** `updateToTableWithHisto`.

> ⚠ Ça concerne directement le trigger métier de l'étape 1 de la gestion d'avoir, qui est placé dans `updateToTableWithHisto`. **Depuis l'écran de modification, une vente validée ne déclenchera jamais la création de l'avoir**, puisque l'étage 4 refuse avant. Le test de l'étape 1 fonctionnait parce qu'il appelait `updateToTableWithHisto` directement, sans passer par ce contrôle. Il faudra une action dédiée, par exemple « Signaler un problème », qui ne passe pas par ce contrôle.

---

## Étage 5 : `updateToTableWithHisto(String u, Connection c)` (dans le jar)

Malgré son nom, elle ne fait **pas** l'`UPDATE` elle-même : elle prépare surtout l'**historique** (qui a modifié quoi, et quand).

Ce que montre le bytecode, dans l'ordre :

1. **Connexion** : si `c == null`, elle ouvre sa propre connexion (`new UtilDB().GetConn()`) et note qu'il faudra la fermer.
2. **Nettoyage de l'utilisateur** : si `u` contient un `/` (`u.contains("/")`), elle découpe la chaîne et ne garde que la partie avant le `/`.
3. **Libellé de l'action** : `"Modification"` par défaut. Si l'objet est un `ClassEtat` avec une action de validation en cours (`getActionValidation()` non vide), le libellé devient `"Validation"`.
4. **Ligne d'historique** : elle crée un `historique.MapHistorique(nomTable, "Modification par " + u, u, id, c)` et lui donne le nom de la classe Java (`setObjet("vente.Vente")`). C'est la ligne qui ira dans la table `historique`.
5. **Historique des valeurs** (seulement si la classe est « historisée », `getEstHistorise()`) : elle relit l'ancienne version en base (`CGenUtil.rechercher(... " and id = '...'")`) et sauvegarde ses anciennes valeurs (`genereHistorique` puis `Historique_valeur.insertToTable`). Si l'objet est un `ClassMere`, elle fait la même chose pour chacune de ses filles.
6. **Délégation** : elle appelle l'autre version, `updateToTableWithHisto(historique, c)` (étage 6).
7. **Fin** : si elle a ouvert la connexion, elle la ferme. En cas d'erreur, elle relance une exception avec le message `"ERREUR UPDATE 2 ..."`.

---

## Étage 6 : `updateToTableWithHisto(ClassMAPTable h, Connection c)` (dans le jar)

C'est ici que les requêtes partent **vraiment** vers Oracle. Voici ce qu'elle fait, avec les logs réels d'un test sur la vente `VNT001699001012` :

1. **`h.insertToTable(c)`** : insère la ligne d'historique.
   ```sql
   INSERT INTO historique ( idHistorique, dateHistorique, heure, objet, action, idUtilisateur, refObjet )
   values ( 'EX0000791143','27/10/2026','07:26:56','vente.Vente','Modification par 1','1','VNT001699001012' )
   ```
2. **`this.updateToTable(c)`** : la vraie modification.
   ```sql
   UPDATE VENTE SET id='VNT001699001012', designation='Elia cherie ', idMagasin='MAGA0004', daty='22/10/2026',
          remarque='Mlle Elia', etat=11, ..., montantDonne=0.0, idResponsable='', probleme=1
   WHERE id = 'VNT001699001012'
   ```
3. **Si l'objet est « indexable »** (`getEstIndexable()`) : elle récupère par réflexion la méthode `getIdUtilisateur`, relit la fiche `HISTOINSERT` de l'objet (sa fiche de traçabilité de création) et la met à jour.
   ```sql
   UPDATE HISTOINSERT SET ... WHERE idHistorique = 'EX0000012073001012'
   ```
4. En cas d'erreur, elle relance une exception avec le message `"ERREUR Modification table 3 ..."`.

### Point important sur `updateToTable`

Regarde l'`UPDATE` ci-dessus : il réécrit **toutes** les colonnes de la table (`id`, `designation`, `idMagasin`, `daty`…), pas seulement celles qui ont changé.

Conséquence : **un attribut qui n'est pas dans le formulaire est écrasé par sa valeur Java par défaut** (`0` pour un `int`, `null` pour un `String`). C'est pour ça que `probleme` doit figurer dans le formulaire de modification. Sinon, il repasse à `0` à chaque modification.

---

## Où se place le trigger métier de l'étape 1 (gestion d'avoir)

```java
@Override
public int updateToTableWithHisto(String u, Connection c) throws Exception {
    Vente ancienne = Vente.getById(c, this.getId());      // base pas encore modifiée → ancienne valeur (le :OLD)
    int retour = super.updateToTableWithHisto(u, c);      // étages 5 et 6 : historique + UPDATE
    if (this.getProbleme() == 1 && ancienne != null && ancienne.getProbleme() != 1) {
        Vente.genererAvoir2(u, c, this.getId());          // AFTER UPDATE, dans la même transaction
    }
    return retour;
}
```

- Je redéfinis l'**étage 5**. Mon code s'exécute donc pour **tout ce qui passe par cet étage** : `updateObject`, mais aussi `validerObject`, `annuler`, `cloturerObject`, `updateEtat` (j'ai vérifié dans le bytecode de `ClassEtat` : ils appellent tous `updateToTableWithHisto`).
- Il ne s'exécute **pas** si l'**étage 4** refuse avant, c'est-à-dire pour une vente déjà validée qu'on modifie depuis l'écran.
- `super.updateToTableWithHisto(u, c)` est l'appel indispensable aux étages 5 et 6 d'origine. Sans lui, la vente ne serait plus jamais modifiée en base.

---

## Résumé en 6 points

1. `updateObjectMultiple(mere, colonneMere, filles, c)` est le **chef d'orchestre** : droits, transaction, mère puis filles, commit ou rollback.
2. Pour chaque fille : **id présent → UPDATE**, **id vide → INSERT**, et **jamais de DELETE**.
3. **Celui qui ouvre la connexion fait le commit, le rollback et le close.**
4. `ClassEtat.updateObject` **refuse de modifier un objet validé** (`etat >= 11`).
5. `updateToTableWithHisto` écrit l'**historique**, puis fait l'`UPDATE` (étage 6).
6. L'`UPDATE` d'APJ réécrit **toutes les colonnes** : un champ absent du formulaire est remis à sa valeur par défaut.

---

## Prochaines leçons possibles

1. **`createObject`** : le chemin d'une création, et comment `construirePK` et `preparePk("AVRFC", "GETSEQAVOIRFC")` fabriquent les identifiants comme `AVRFC000334`.
2. **`validerObject`** : comment fonctionne le visa (`etat` passe à 11), et pourquoi lui appelle `controlerUpdate`.
3. **`CGenUtil.rechercher`** : comment APJ transforme un objet Java en `select * from ... where ...`.
4. **`ClassMAPTable`, `ClassEtat`, `ClassMere`, `ClassFille`** : à quoi sert chaque niveau de la hiérarchie.
