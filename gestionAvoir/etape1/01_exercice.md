# Gestion d'avoir — Étape 1 : exercice à trous

J'ai retiré de `arbiochem-ejb/src/java/vente/Vente.java` les 5 bouts de code sans lesquels l'étape 1 ne fonctionne pas. À leur place, il y a des commentaires `// EXERCICE n : ...`. À toi de les réécrire.

**Les réponses** se trouvent dans :
- [Vente.java.md](Vente.java.md) : l'explication de chaque ligne ;
- [apprentissageAPJ/lecon1/01_chemin_modification.md](../../apprentissageAPJ/lecon1/01_chemin_modification.md) : le fonctionnement d'APJ.

Essaie d'abord sans regarder, puis vérifie.

## Les 5 trous

| # | Où | Ce que tu dois écrire | Où est la réponse |
|---|---|---|---|
| 1 | `updateToTableWithHisto`, ligne 628 | lire l'**ancienne** vente en base, dans une variable `ancienne` | Vente.java.md → « Ligne 628 » |
| 2 | `updateToTableWithHisto`, ligne 629 | faire faire au framework la vraie modification, et garder le résultat dans `retour` | Vente.java.md → « Ligne 629 » ; leçon 1 → étages 5 et 6 |
| 3 | `updateToTableWithHisto`, ligne 630 | remplacer `false` par la condition « la vente vient de passer de 0 à 1 » | Vente.java.md → « Ligne 630 » |
| 4 | `updateToTableWithHisto`, ligne 631 | créer l'avoir en réutilisant une méthode existante de `Vente` | Vente.java.md → « Ligne 631 » |
| 5 | `genererAvoir2`, ligne 1379 | faire le `commit`, mais seulement quand c'est permis | Vente.java.md → « Modification 2 » ; leçon 1 → étage 1 (« La règle d'or d'APJ ») |

## Questions à te poser pendant l'exercice

1. Pourquoi l'exercice 1 doit-il être **avant** l'exercice 2 ? Que se passe-t-il si tu les inverses ?
2. Que se passe-t-il si tu oublies l'exercice 2 ? La vente est-elle encore modifiée en base ?
3. Dans l'exercice 3, pourquoi tester `ancienne != null` **avant** `ancienne.getProbleme()` ?
4. Dans l'exercice 3, pourquoi la condition « nouveau == 1 » toute seule ne suffit-elle pas ?
5. Dans l'exercice 4, quelle connexion passes-tu ? Que se passerait-il si tu passais `null` à la place ?
6. Dans l'exercice 5, que se passerait-il avec un simple `c.commit();` quand l'appel vient de l'écran de modification ?

## Vérifier ton travail

### 1. Compiler

Depuis la racine du projet :

```bash
mkdir -p /tmp/akoho-out
javac -nowarn -encoding UTF-8 -proc:none -d /tmp/akoho-out \
  -cp "build-file/arbiochem_jar:build-file/ear/arbiochem-ejb.jar:build-file/lib/*" \
  arbiochem-ejb/src/java/vente/Vente.java
```

- Dans l'état actuel (exercices non faits), tu obtiens `error: cannot find symbol ... variable retour`. C'est normal : c'est le trou de l'exercice 2.
- Quand tout est rempli, la commande ne doit afficher **aucune** erreur.

### 2. Tester sur la base (sans rien laisser en base)

Crée ce fichier **hors du projet**, par exemple `/tmp/akoho-test/TestTriggerAvoir.java`. Il ouvre une connexion, simule des modifications de vente, puis fait un **ROLLBACK** à la fin : rien ne reste en base.

```java
import java.sql.*;
import utilitaire.UtilDB;
import vente.Vente;

public class TestTriggerAvoir {
    static int compter(Connection c, String id) throws Exception {
        PreparedStatement ps = c.prepareStatement("select count(*) from avoirfc where idvente=?");
        ps.setString(1, id); ResultSet rs = ps.executeQuery(); rs.next(); return rs.getInt(1);
    }
    public static void main(String[] a) throws Exception {
        Connection c = new UtilDB().GetConn();
        c.setAutoCommit(false);
        try {
            ResultSet rs = c.createStatement().executeQuery("select id from (select v.id from vente v where v.probleme=0 and exists(select 1 from vente_details d where d.idvente=v.id) and not exists(select 1 from avoirfc f where f.idvente=v.id) order by v.id desc) where rownum=1");
            rs.next(); String id = rs.getString(1);
            System.out.println("Vente testee : " + id + " | avoirs avant : " + compter(c, id));
            Vente v = Vente.getById(c, id);
            v.updateToTableWithHisto("1", c);
            System.out.println("Modif sans probleme  -> avoirs : " + compter(c, id));
            v.setProbleme(1);
            v.updateToTableWithHisto("1", c);
            System.out.println("Passage 0 -> 1       -> avoirs : " + compter(c, id));
            v.updateToTableWithHisto("1", c);
            System.out.println("Re-modif deja a 1    -> avoirs : " + compter(c, id));
        } finally {
            c.rollback();
            c.close();
            System.out.println("ROLLBACK effectue");
        }
    }
}
```

Puis, depuis la racine du projet :

```bash
CP="/tmp/akoho-out:build-file/arbiochem_jar:build-file/ear/arbiochem-ejb.jar:build-file/lib/*:arbiochem-ejb/src/java"
javac -nowarn -proc:none -d /tmp/akoho-test -cp "$CP" /tmp/akoho-test/TestTriggerAvoir.java
java -cp "/tmp/akoho-test:$CP" TestTriggerAvoir 2>&1 | grep -E "Vente testee|->|ROLLBACK|Exception"
```

**Résultat attendu** si tes 5 réponses sont justes :

```
Vente testee : VNT... | avoirs avant : 0
Modif sans probleme  -> avoirs : 0
Passage 0 -> 1       -> avoirs : 1
Re-modif deja a 1    -> avoirs : 1
ROLLBACK effectue
```

| Si tu obtiens… | …regarde plutôt |
|---|---|
| `0` après « Passage 0 -> 1 » | l'exercice 3 (condition) ou l'exercice 4 (appel) |
| `2` après « Re-modif deja a 1 » | l'exercice 3 : la condition ne regarde pas l'**ancienne** valeur |
| `1` dès « Modif sans probleme » | l'exercice 3 : la condition ne regarde pas la **nouvelle** valeur |
| `NullPointerException` | l'ordre des conditions dans l'exercice 3 |

> Le test appelle `updateToTableWithHisto` **directement**. Il ne vérifie donc pas l'exercice 5 : avec une connexion fournie par l'appelant, le commit n'est pas censé avoir lieu, et le ROLLBACK final annule tout dans les deux cas. Pour l'exercice 5, compare ta réponse avec la doc.

### 3. Comparer avec ma solution

J'ai gardé une copie complète de la solution. Quand tu as fini, demande-moi de comparer ta version à la mienne : je ferai un `diff` et je te dirai ce qui diffère, et si c'est grave ou non.
